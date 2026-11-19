import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

// ════════════════════════════════════════════════════════════════
// 🔒 التحقق اليدوي من الذريّة في قسم الأوث (مع الإصلاحات المُنفَّذة)
// ════════════════════════════════════════════════════════════════
// ⚠️ للمبرمجين المستقبليين: يوثّق هذا الملف ما هو ذري فعلاً ولماذا،
// بدقة فائقة لتجنب التعديلات الغير صحيحة. لا تُغيّر أي منطق أدناه
// دون قراءة هذا التحقق أولاً. التعليقات داخل الدوال مؤشرات قصيرة
// مدمجة (لتجنب الاطالة) — التفاصيل الكاملة هنا فقط.
//
// ✅ ذري تلقائياً (set واحد على مستند واحد — Firestore يضمنها):
// حفظ OTP في _saveEmailOTPToFirestore • ملف المستخدم في
// signInWithGoogle و create_admin_page (set بدمج) • ملف المستخدم
// في signUpWithEmail و verifyEmailOTP.
//
// ✅ ذري عبر runTransaction واحدة (all-or-nothing، كل القراءات قبل
//    كل الكتابات): ① استهلاك OTP في verifyEmailOTP و
//    resetPasswordByEmail (get + تحقق used/expiresAt/otpCode +
//    update used:true) قبل أي أثر جانبي — يمنع الاستهلاك المزدوج
//    لطلبين متزامنين (TOCTOU) ② إنشاء دور المدير + تحديث roleIds
//    في _createAdminRoleForCurrentUser (create_admin_page.dart).
//
// ⚠️ عبر خدمتين (Auth + Firestore) لا يمكن أن تكونا في معاملة واحدة:
//    إنشاء المستخدم + حفظ ملفه في signUpWithEmail و verifyEmailOTP —
//    إجراء تعويضي كامل: فشل حفظ Firestore أو تحديث الاسم ⇒ حذف
//    ملف Firestore (أفضل جهد) + حذف مستخدم Auth لمنع أي يتيم
//    (ملف بلا مستخدم يطابق استعلام البريد في _checkUserHasValidRole
//    فيعيد المستخدم لشاشة رمز الوصول عند إعادة التسجيل).
// ⚠️ استهلاك OTP يسبق الأثر الجانبي: إذا فشل الأثر يبقى الرمز مستهلكاً
//    ويُطلب رمز جديد — ثمن منع الاستهلاك المزدوج، لا تُعيد ترتيبهما.
// ⚠️ resetPasswordByPhone سلسلة متتابعة (signIn → updatePassword →
//    signOut): فشل signOut يُتجاهل — كلمة المرور تغيرت فعلاً
//    والمستخدم يُسجّل خروجه لاحقاً.
//
// ✅ دوال Cloud Functions مُنفَّذة في functions/index.js:
//    sendEmailOTP (إرسال بريد الرمز عبر SMTP — تتحقق أن
//    الرمز محفوظ قبل الإرسال) و resetPasswordWithOTP
//    (استهلاك الرمز ذرياً على الخادم + إعادة تعيين كلمة
//    المرور عبر Firebase Auth — التحقق على الخادم لا يثق
//    بالعميل لأمان). resetPasswordByEmail يرسل otpCode
//    للدالة ولا يستهلك الرمز محلياً (الدالة تفعل ذلك).
//
// ⚡ الأداء (مستقلات بالتوازي دون تغيير النتائج): تحديث الاسم + حفظ
//    الملف في signUpWithEmail و verifyEmailOTP • إرسال البريد في
//    sendEmailOTP في الخلفية • التحقق من المدير + دور المستخدم في
//    AuthBloc • مسح الجلسة + حالة تسجيل الدخول الأولي عند الخروج.
//
// 🔒 القاعدة الذهبية: أي عملية تقرأ ثم تكتب نفس المستند بناءً على
//    القيمة المقروءة يجب أن تكون في معاملة واحدة — لا تُجزّئها أبداً.
// ════════════════════════════════════════════════════════════════

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required FirebaseAuth firebaseAuth})
    : _firebaseAuth = firebaseAuth;
  final FirebaseAuth _firebaseAuth;

  // خدمة تطبيع البريد الإلكتروني
  final _emailService = EmailNormalizationService();

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(email);

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      if (credential.user != null) {
        final userModel = UserModel(
          id: credential.user!.uid,
          email: credential.user!.email ?? '',
          name: credential.user!.displayName ?? '',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          provider: 'email',
        );
        return Right(userModel);
      }
      return const Left(AuthFailure('فشل في تسجيل الدخول'));
    } on FirebaseAuthException catch (e) {
      // معالجة أخطاء الشبكة بشكل خاص
      if (e.code == 'network-request-failed') {
        return const Left(
          AuthFailure(
            'خطأ في الاتصال بالإنترنت.\n\nتحقق من اتصالك وحاول مرة أخرى.',
          ),
        );
      }
      return Left(AuthFailure('فشل في تسجيل الدخول'));
    } on Exception catch (e) {
      final errorMessage = e.toString().toLowerCase();
      // معالجة أخطاء الشبكة
      if (errorMessage.contains('network') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('unable to resolve host') ||
          errorMessage.contains('socket')) {
        return const Left(
          AuthFailure(
            'خطأ في الاتصال بالإنترنت.\n\nتحقق من اتصالك وحاول مرة أخرى.',
          ),
        );
      }
      return Left(AuthFailure('فشل في تسجيل الدخول: $_readableError(e)'));
    }
  }

  // ⚠️ عبر خدمتين + إجراء تعويضي + تحديث الاسم وحفظ الملف
  // بالتوازي (مستقلتان) — انظر الملاحظة العليا.
  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(email);

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      if (credential.user != null) {
        final displayNameFuture = name != null
            ? credential.user!.updateDisplayName(name)
            : Future<void>.value();
        try {
          await FirebaseFirestore.instance
              .collection(normalizedEmail)
              .doc('users')
              .collection('users')
              .doc(credential.user!.uid)
              .set({
                'email': normalizedEmail,
                'name': name ?? '',
                'phoneNumber': null,
                'photoUrl': null,
                'createdAt': FieldValue.serverTimestamp(),
                'lastLoginAt': FieldValue.serverTimestamp(),
                'provider': 'email',
              });
          // انتظار تحديث الاسم داخل الحماية — فشله
          // يُعالج كفشل حفظ (يُحذف المستخدم أدناه)
          await displayNameFuture;
        } on Exception {
          // انتظار تحديث الاسم مع تجاهل خطئه أثناء التعويض
          await displayNameFuture.catchError((Object _) {});
          // تعويض كامل (أفضل جهد) لمنع مستند يتيم يطابق
          // استعلام البريد — السبب الكامل في الملاحظة العليا.
          await FirebaseFirestore.instance
              .collection(normalizedEmail)
              .doc('users')
              .collection('users')
              .doc(credential.user!.uid)
              .delete()
              .catchError((Object _) {});
          await credential.user!.delete();
          return const Left(
            AuthFailure('فشل في حفظ بيانات المستخدم، حاول مرة أخرى'),
          );
        }

        final userModel = UserModel(
          id: credential.user!.uid,
          email: normalizedEmail,
          name: name ?? '',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          provider: 'email',
        );
        return Right(userModel);
      }
      return const Left(AuthFailure('فشل في إنشاء الحساب'));
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_readableError(e)));
    } on Exception catch (e) {
      return Left(AuthFailure('فشل في إنشاء الحساب: ${_readableError(e)}'));
    }
  }

  // ✅ ذري: set واحد بدمج على مستند واحد — انظر الملاحظة العليا.
  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      // استخدام GoogleSignIn.instance (الطريقة الوحيدة في v7.2.0)
      final googleSignIn = GoogleSignIn.instance;

      // تهيئة مع clientId الصحيح من google-services.json
      await googleSignIn.initialize(
        clientId:
            '489543846229-sqh0k9anpes949llm76j9bvh006510ug.apps.googleusercontent.com',
      );

      // تسجيل الدخول - استخدام authenticate() فقط
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      // الحصول على idToken مباشرة من googleUser.authentication
      final googleAuth = googleUser.authentication;

      // التحقق من وجود idToken
      if (googleAuth.idToken == null) {
        return const Left(
          GoogleSignInFailure('فشل في الحصول على رموز المصادقة من Google'),
        );
      }

      // إنشاء Firebase Credential باستخدام idToken
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // تسجيل الدخول إلى Firebase
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user != null) {
        // حفظ بيانات المستخدم في Firestore داخل مجموعة البريد المطبّع
        final normalizedEmail = _emailService.normalize(user.email!);
        await FirebaseFirestore.instance
            .collection(normalizedEmail)
            .doc('users')
            .collection('users')
            .doc(user.uid)
            .set({
              'email': user.email ?? '',
              'name': user.displayName ?? '',
              'photoUrl': user.photoURL,
              'createdAt': FieldValue.serverTimestamp(),
              'lastLoginAt': FieldValue.serverTimestamp(),
              'provider': 'google',
            }, SetOptions(merge: true));

        final userModel = UserModel(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          provider: 'google',
        );
        return Right(userModel);
      }

      return const Left(GoogleSignInFailure('فشل في تسجيل الدخول بـ Google'));
    } on GoogleSignInException catch (e) {
      // معالجة خطأ SHA-1/Developer Error
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError ||
          e.code == GoogleSignInExceptionCode.canceled) {
        if (e.description?.contains('DEVELOPER_ERROR') == true ||
            e.description?.contains('Unknown calling package') == true ||
            e.description?.contains('Account reauth failed') == true) {
          return const Left(
            GoogleSignInFailure(
              'خطأ في الاتصال بالإنترنت.\n\nيرجى التحقق من اتصالك والمحاولة مرة أخرى.\n\nملاحظة: هذا الخطأ قد يظهر بشكل خاطئ عند ضعف الاتصال.',
            ),
          );
        }

        if (e.description?.contains('Account reauth failed') == true ||
            e.description?.contains('16') == true) {
          return const Left(
            GoogleSignInFailure(
              'لا يوجد حساب Google مسجل في الجهاز.\n'
              'يرجى:\n'
              '• إضافة حساب Google من إعدادات الجهاز، أو\n'
              '• الاختبار على جهاز حقيقي',
            ),
          );
        }

        return const Left(GoogleSignInFailure('تم إلغاء تسجيل الدخول'));
      }

      return Left(
        GoogleSignInFailure('فشل في تسجيل الدخول بـ Google: ${e.description}'),
      );
    } on PlatformException catch (e) {
      // معالجة خطأ SHA-1/Developer Error
      if (e.code == 'DEVELOPER_ERROR' ||
          e.message?.contains('DEVELOPER_ERROR') == true ||
          e.message?.contains('Unknown calling package') == true) {
        return const Left(
          GoogleSignInFailure(
            'خطأ في الاتصال بالإنترنت.\n\nيرجى التحقق من اتصالك والمحاولة مرة أخرى.\n\nملاحظة: هذا الخطأ قد يظهر بشكل خاطئ عند ضعف الاتصال.',
          ),
        );
      }

      if (e.code == 'sign_in_canceled' || e.code == 'canceled') {
        if (e.message?.contains('Account reauth failed') == true ||
            e.message?.contains('16') == true) {
          return const Left(
            GoogleSignInFailure(
              'لا يوجد حساب Google مسجل في الجهاز.\n'
              'يرجى:\n'
              '• إضافة حساب Google من إعدادات الجهاز، أو\n'
              '• الاختبار على جهاز حقيقي',
            ),
          );
        }
        return const Left(GoogleSignInFailure('تم إلغاء تسجيل الدخول'));
      }

      if (e.code == 'network_error') {
        return const Left(
          GoogleSignInFailure('خطأ في الاتصال بالإنترنت، تحقق من اتصالك'),
        );
      }

      return Left(
        GoogleSignInFailure('فشل في تسجيل الدخول بـ Google: ${e.message}'),
      );
    } on FirebaseAuthException catch (e) {
      return Left(GoogleSignInFailure(_readableError(_handleAuthException(e))));
    } on Exception catch (e) {
      final errorMessage = e.toString().toLowerCase();

      // معالجة خطأ SHA-1
      if (errorMessage.contains('developer_error') ||
          errorMessage.contains('unknown calling package')) {
        return const Left(
          GoogleSignInFailure(
            'خطأ في الاتصال بالإنترنت.\n\nيرجى التحقق من اتصالك والمحاولة مرة أخرى.\n\nملاحظة: هذا الخطأ قد يظهر بشكل خاطئ عند ضعف الاتصال.',
          ),
        );
      }

      // معالجة خاصة لخطأ عدم وجود حساب
      if (errorMessage.contains('account reauth failed') ||
          errorMessage.contains('[16]')) {
        return const Left(
          GoogleSignInFailure(
            'لا يوجد حساب Google مسجل في الجهاز.\n'
            'يرجى:\n'
            '• إضافة حساب Google من إعدادات الجهاز، أو\n'
            '• الاختبار على جهاز حقيقي',
          ),
        );
      }

      if (errorMessage.contains('popup_closed') ||
          errorMessage.contains('user_canceled') ||
          errorMessage.contains('sign_in_canceled')) {
        return const Left(
          GoogleSignInFailure('تم إلغاء تسجيل الدخول بـ Google'),
        );
      }

      if (errorMessage.contains('storagerelay') ||
          errorMessage.contains('native_android') ||
          errorMessage.contains('client type') ||
          errorMessage.contains('access blocked') ||
          errorMessage.contains('authorization error')) {
        return const Left(
          GoogleSignInFailure(
            'خدمة تسجيل الدخول عبر جوجل غير مُعدّة بشكل صحيح للويب حالياً. يرجى استخدام تسجيل الدخول بالبريد الإلكتروني وكلمة المرور.',
          ),
        );
      }

      return Left(
        GoogleSignInFailure('فشل في تسجيل الدخول بـ Google: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      // تسجيل الخروج من Google Sign-In
      try {
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.signOut();
      } on Exception catch (_) {
        // تجاهل أخطاء Google Sign-In عند تسجيل الخروج
      }

      // تسجيل الخروج من Firebase
      await _firebaseAuth.signOut();
      return const Right(null);
    } on Exception catch (e) {
      return Left(AuthFailure('فشل في تسجيل الخروج: ${_readableError(e)}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final user = _firebaseAuth.currentUser;

      if (user != null) {
        final userModel = UserModel(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          provider: 'firebase',
        );
        return Right(userModel);
      }

      return const Right(null);
    } on Exception catch (e) {
      return Left(
        AuthFailure('فشل في الحصول على بيانات المستخدم: ${_readableError(e)}'),
      );
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user != null) {
        return UserModel(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          provider: 'firebase',
        );
      }
      return null;
    });
  }

  // ==================== طرق الهاتف (OTP) ====================

  @override
  Future<Either<Failure, String>> sendPhoneOTP(String phoneNumber) async {
    try {
      // ⚠️ مكمّل محلي لكل مكالمة (لا مشترك بين المكالمات):
      // المستودع singleton — كان المجال المشترك يُفسد
      // المكالمة الأولى عند مكالمتين متزامنتين (إعادة
      // إرسال سريعة) لأن الاستدعاءات المرتجعة تشير
      // لأحدث مكمّل. المحلي يضمن حصول كل مكالمة على
      // معرّف التحقق الخاص بها.
      final completer = Completer<String>();

      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // التحقق التلقائي (بعض الأجهزة)
          await _firebaseAuth.signInWithCredential(credential);
          if (!completer.isCompleted) {
            completer.complete('auto-verified');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
      );

      // انتظار حتى يتم إرسال الرمز (مع مهلة 60 ثانية)
      String verificationId;
      try {
        verificationId = await completer.future.timeout(
          const Duration(seconds: 60),
        );
      } on TimeoutException {
        return const Left(
          AuthFailure('انتهت مهلة الانتظار، يرجى المحاولة مرة أخرى'),
        );
      }

      if (verificationId == 'auto-verified') {
        return const Right('auto-verified');
      }

      if (verificationId.isNotEmpty) {
        return Right(verificationId);
      } else {
        return const Left(AuthFailure('فشل في إرسال رمز التحقق'));
      }
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_readableError(_handlePhoneAuthException(e))));
    } on Exception catch (e) {
      return Left(AuthFailure('فشل في إرسال رمز التحقق: ${_readableError(e)}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> verifyPhoneOTP(
    String verificationId,
    String smsCode, {
    String? name,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        final user = userCredential.user!;

        final userModel = UserModel(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? name ?? '',
          phoneNumber: user.phoneNumber,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          provider: 'phone',
        );

        return Right(userModel);
      }

      return const Left(AuthFailure('فشل في التحقق من رمز الهاتف'));
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_readableError(_handlePhoneAuthException(e))));
    } on Exception catch (e) {
      return Left(AuthFailure('فشل في التحقق: ${_readableError(e)}'));
    }
  }

  // ⚠️ سلسلة Auth متتابعة — انظر الملاحظة العليا.
  @override
  Future<Either<Failure, void>> resetPasswordByPhone(
    String verificationId,
    String smsCode,
    String newPassword,
  ) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await _firebaseAuth.signInWithCredential(credential);

      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        // ⚠️ فشل signOut يُتجاهل — كلمة المرور تغيرت فعلاً
        // (السبب في الملاحظة العليا)
        await _firebaseAuth.signOut().catchError((Object _) {});
        return const Right(null);
      }

      return const Left(AuthFailure('فشل في إعادة تعيين كلمة المرور'));
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_readableError(_handlePhoneAuthException(e))));
    } on Exception catch (e) {
      return Left(AuthFailure('فشل في إعادة التعيين: ${_readableError(e)}'));
    }
  }

  // ==================== طرق البريد الإلكتروني (OTP) ====================

  // ✅ ذري: set واحد على مستند واحد — انظر الملاحظة العليا.
  @override
  Future<Either<Failure, void>> sendEmailOTP(String email) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(email);

      // توليد رمز OTP عشوائي
      final otpCode = _generateOTP();

      // حفظ الرمز في Firestore
      await _saveEmailOTPToFirestore(
        email: normalizedEmail,
        otpCode: otpCode,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      // إرسال البريد في الخلفية (يوفر وقت الإرسال من
      // المسار الحرج) — فشله يُتجاهل (السبب في الملاحظة العليا)
      () async {
        try {
          await FirebaseFunctions.instance
              .httpsCallable('sendEmailOTP')
              .call({'email': normalizedEmail, 'otpCode': otpCode});
        } on Exception {
          // تجاهل فشل الإرسال — الرمز محفوظ ويُتحقق منه يدوياً
        }
      }();

      return const Right(null);
    } on Exception catch (e) {
      return Left(AuthFailure('فشل في إرسال رمز التحقق: ${_readableError(e)}'));
    }
  }

  // ✅ ذري: استهلاك الرمز في runTransaction واحدة قبل إنشاء
  // المستخدم + تحديث الاسم وحفظ الملف بالتوازي (مستقلتان) —
  // انظر الملاحظة العليا (البند ①).
  @override
  Future<Either<Failure, UserEntity>> verifyEmailOTP(
    String email,
    String otpCode, {
    required String name,
    required String password,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(email);

      // 1. استهلاك رمز OTP ذرياً في معاملة واحدة قبل إنشاء المستخدم
      final otpRef = FirebaseFirestore.instance
          .collection(normalizedEmail)
          .doc('otp_codes');

      Failure? otpFailure;

      try {
        await FirebaseFirestore.instance.runTransaction(
          (transaction) async {
            final snapshot = await transaction.get(otpRef);
            if (!snapshot.exists) {
              otpFailure = const AuthFailure(
                'رمز التحقق غير موجود أو منتهي الصلاحية',
              );
              return;
            }
            final otpData = snapshot.data()!;
            final storedOTP = otpData['otpCode'] as String;
            final expiresAt = (otpData['expiresAt'] as Timestamp).toDate();
            final used = otpData['used'] as bool? ?? false;

            // التحقق من صلاحية الرمز
            if (used) {
              otpFailure = const AuthFailure('تم استخدام هذا الرمز مسبقاً');
              return;
            }

            if (DateTime.now().isAfter(expiresAt)) {
              otpFailure = const AuthFailure('انتهت صلاحية رمز التحقق');
              return;
            }

            if (storedOTP != otpCode) {
              otpFailure = const AuthFailure('رمز التحقق غير صحيح');
              return;
            }

            transaction.update(otpRef, {'used': true});
          },
        );
      } on FirebaseException {
        // فشل المعاملة (تعارض متزامن أو خطأ شبكة) — لا تُنشئ المستخدم
        return const Left(
          AuthFailure('فشل في التحقق من رمز التحقق، حاول مرة أخرى'),
        );
      }

      if (otpFailure != null) {
        return Left(otpFailure!);
      }

      // 2. إنشاء الحساب في Firebase Auth
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      if (credential.user == null) {
        return const Left(AuthFailure('فشل في إنشاء الحساب'));
      }

      // 3. تحديث الاسم + حفظ الملف بالتوازي (مستقلتان) — ⚠️ عبر
      //    خدمتين مع إجراء تعويضي، انظر الملاحظة العليا
      final displayNameFuture = credential.user!.updateDisplayName(name);

      try {
        await FirebaseFirestore.instance
            .collection(normalizedEmail)
            .doc('users')
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'email': normalizedEmail,
              'name': name,
              'phoneNumber': null,
              'photoUrl': null,
              'createdAt': FieldValue.serverTimestamp(),
              'lastLoginAt': FieldValue.serverTimestamp(),
              'provider': 'email',
            });
        await displayNameFuture;
      } on Exception {
        // انتظار تحديث الاسم مع تجاهل خطئه أثناء التعويض
        await displayNameFuture.catchError((Object _) {});
        // تعويض كامل (أفضل جهد) — نفس سبب signUpWithEmail
        // في الملاحظة العليا.
        await FirebaseFirestore.instance
            .collection(normalizedEmail)
            .doc('users')
            .collection('users')
            .doc(credential.user!.uid)
            .delete()
            .catchError((Object _) {});
        await credential.user!.delete();
        return const Left(
          AuthFailure('فشل في حفظ بيانات المستخدم، حاول مرة أخرى'),
        );
      }

      // 4. إرجاع بيانات المستخدم
      final userModel = UserModel(
        id: credential.user!.uid,
        email: normalizedEmail,
        name: name,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        provider: 'email',
      );

      return Right(userModel);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_readableError(e)));
    } on Exception catch (e) {
      return Left(AuthFailure('فشل في التحقق: ${_readableError(e)}'));
    }
  }

  // ✅ ذري: استهلاك الرمز + إعادة تعيين كلمة المرور في Cloud
  // Function واحدة (runTransaction على الخادم قبل تغيير كلمة
  // المرور — يمنع الاستهلاك المزدوج TOCTOU) — انظر الملاحظة
  // العليا (البند ①).
  @override
  Future<Either<Failure, void>> resetPasswordByEmail(
    String email,
    String otpCode,
    String newPassword,
  ) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(email);

      // ⚠️ التحقق على الخادم لا يُثق بالعميل (أمان) — لا تُزل
      // هذا التحقق أبداً. انظر الملاحظة العليا.
      final callable = FirebaseFunctions.instance.httpsCallable(
        'resetPasswordWithOTP',
      );

      await callable.call({
        'email': normalizedEmail,
        'otpCode': otpCode,
        'newPassword': newPassword,
      });

      return const Right(null);
    } on FirebaseFunctionsException catch (e) {
      // الدالة تُرجع رسالة الخطأ العربية مباشرة
      final message = e.message;
      if (message != null && message.isNotEmpty) {
        return Left(AuthFailure(message));
      }
      return const Left(
        AuthFailure(
          'فشل في تحديث كلمة المرور.\n\n'
          'يرجى المحاولة مرة أخرى لاحقاً أو الاتصال بالدعم.',
        ),
      );
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_readableError(e)));
    } on Exception catch (e) {
      return Left(AuthFailure('فشل في إعادة التعيين: ${_readableError(e)}'));
    }
  }

  // ==================== دوال مساعدة ====================

  String _generateOTP({int length = 6}) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(10)).join();
  }

  // ✅ ذري: كتابة واحدة (set) على مستند واحد — Firestore يضمن ذريتها.
  Future<void> _saveEmailOTPToFirestore({
    required String email,
    required String otpCode,
    required DateTime expiresAt,
  }) async {
    // تطبيع البريد الإلكتروني
    final normalizedEmail = _emailService.normalize(email);

    // حفظ OTP في مستند واحد تحت البريد الإلكتروني مباشرة
    // البنية: المستند 'otp_codes' في مجموعة {normalizedEmail}
    await FirebaseFirestore.instance
        .collection(normalizedEmail)
        .doc('otp_codes')
        .set({
          'otpCode': otpCode,
          'expiresAt': Timestamp.fromDate(expiresAt),
          'createdAt': FieldValue.serverTimestamp(),
          'used': false,
          'email': normalizedEmail,
        });
  }

  Exception _handlePhoneAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return Exception('رقم الهاتف غير صحيح، يرجى التحقق منه');
      case 'missing-phone-number':
        return Exception('رقم الهاتف مطلوب');
      case 'invalid-verification-code':
        return Exception('رمز التحقق غير صحيح');
      case 'invalid-verification-id':
        return Exception('معرف التحقق غير صحيح');
      case 'session-expired':
        return Exception('انتهت صلاحية الجلسة، يرجى المحاولة مرة أخرى');
      case 'quota-exceeded':
        return Exception('تم تجاوز عدد المحاولات المسموح، حاول لاحقاً');
      case 'network-request-failed':
        return Exception('خطأ في الاتصال بالإنترنت، تحقق من اتصالك');
      case 'operation-not-allowed':
        return Exception(
          'خدمة تسجيل الدخول بالهاتف غير متاحة حالياً.\n\nيرجى استخدام طريقة تسجيل دخول أخرى.',
        );
      case 'captcha-check-failed':
        return Exception('فشل التحقق من الأمان، يرجى المحاولة مرة أخرى');
      case 'app-not-verified':
        return Exception(
          'حدث خطأ في التطبيق.\n\nيرجى إعادة تشغيل التطبيق والمحاولة مرة أخرى.',
        );
      default:
        return Exception('حدث خطأ في المصادقة: ${e.code}\n${e.message}');
    }
  }

  Future<bool> _checkIfAccountExists({
    String? email,
    String? phoneNumber,
  }) async {
    try {
      if (email != null && email.isNotEmpty) {
        final normalizedEmail = _emailService.normalize(email);

        final querySnapshot = await FirebaseFirestore.instance
            .collection(normalizedEmail)
            .doc('users')
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();

        return querySnapshot.docs.isNotEmpty;
      }

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        return false;
      }

      return false;
    } on Exception {
      return false;
    }
  }

  @override
  Future<Either<Failure, bool>> checkIfAccountExists({
    String? email,
    String? phoneNumber,
  }) async {
    try {
      final exists = await _checkIfAccountExists(
        email: email,
        phoneNumber: phoneNumber,
      );
      return Right(exists);
    } on Exception catch (e) {
      return Left(AuthFailure('فشل في التحقق من وجود الحساب: ${_readableError(e)}'));
    }
  }

  // Helper method
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('لا يوجد مستخدم بهذا البريد الإلكتروني');
      case 'wrong-password':
        return Exception('كلمة المرور غير صحيحة');
      case 'email-already-in-use':
        return Exception('البريد الإلكتروني مستخدم بالفعل');
      case 'weak-password':
        return Exception('كلمة المرور ضعيفة جداً');
      case 'invalid-email':
        return Exception('البريد الإلكتروني غير صحيح');
      case 'user-disabled':
        return Exception('تم تعطيل هذا الحساب');
      case 'too-many-requests':
        return Exception('تم تجاوز عدد المحاولات المسموح، حاول لاحقاً');
      case 'network-request-failed':
        return Exception('خطأ في الاتصال بالإنترنت');
      case 'invalid-credential':
        return Exception('بيانات المصادقة غير صحيحة أو منتهية الصلاحية');
      case 'credential-already-in-use':
        return Exception('هذا الحساب مستخدم بالفعل مع طريقة تسجيل دخول أخرى');
      case 'account-exists-with-different-credential':
        return Exception('يوجد حساب بهذا البريد مع طريقة تسجيل دخول مختلفة');
      case 'operation-not-allowed':
        return Exception('طريقة تسجيل الدخول هذه غير مفعلة');
      default:
        return Exception('حدث خطأ في المصادقة: ${e.code}');
    }
  }
}

/// استخراج رسالة خطأ مفهومة للمستخدم من أي استثناء.
String _readableError(dynamic e) {
  final message = (e as dynamic).message;
  if (message is String && message.isNotEmpty) {
    return message;
  }
  final errorString = e.toString();
  if (errorString.startsWith('Exception: ')) {
    return errorString.substring('Exception: '.length);
  }
  return 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى';
}
