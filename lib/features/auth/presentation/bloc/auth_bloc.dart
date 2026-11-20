import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/middleware/admin_check_middleware.dart';
import '../../../../core/services/admin_check_service.dart';
import '../../../../core/services/auth_navigation_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/session_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/check_if_account_exists_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/google_sign_in_usecase.dart';
import '../../domain/usecases/reset_password_by_email_usecase.dart';
import '../../domain/usecases/reset_password_by_phone_usecase.dart';
import '../../domain/usecases/send_email_otp_usecase.dart';
import '../../domain/usecases/send_phone_otp_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/verify_email_otp_usecase.dart';
import '../../domain/usecases/verify_phone_otp_usecase.dart';

// ════════════════════════════════════════════════════════════════
// 🔒 ملاحظة التحقق اليدوي من الذريّة والأداء في قسم الأوث
// ════════════════════════════════════════════════════════════════
// ⚠️ للمبرمجين المستقبليين: يوثّق هذا الملف ما هو ذري ولماذا،
// بدقة فائقة لتجنب التعديلات الغير صحيحة. لا تُغيّر أي منطق
// أدناه دون قراءة هذا التحقق أولاً.
//
// 🔒 العمليات الذرية (معاملة واحدة all-or-nothing) موثّقة
// بالتفصيل في الملاحظة العليا في auth_repository_impl.dart
// (① استهلاك OTP ② دور المدير) وفي functions/index.js
// (استهلاك OTP على الخادم). هذا الملف لا يحتوي معاملات —
// كل ما فيه قراءات مستقلة لا تُجزَّأ.
//
// ⚡ الأداء (مستقلات بالتوازي دون تغيير النتائج):
// التحقق من المدير + دور المستخدم في _onSignInRequested و
// _onGoogleSignInRequested و _onCheckAuthStatus (قراءتان
// مستقلتان — يوفر جولة شبكة واحدة في المسار العادي) •
// مسح الجلسة + حالة تسجيل الدخول الأولي في _onSignOutRequested.
//
// ⚠️ سياسة فشل التحقق من المدير (تُطبَّق في كل المسارات):
// فشل التحقق (مثل ضعف الإنترنت) لا يعني عدم وجود مدير —
// لا ننتقل لشاشة إنشاء المدير بل نكمل الدخول بشكل طبيعي
// (نعتبر hasAdmin = true). لا تُغيّر هذه السياسة أبداً.
// ════════════════════════════════════════════════════════════════

// Events
abstract class AuthEvent {}

class SignInRequested extends AuthEvent {
  SignInRequested({required this.email, required this.password});
  final String email;
  final String password;
}

class SignUpRequested extends AuthEvent {
  SignUpRequested({required this.email, required this.password, this.name});
  final String email;
  final String password;
  final String? name;
}

class GoogleSignInRequested extends AuthEvent {}

class SignOutRequested extends AuthEvent {}

class CheckAuthStatus extends AuthEvent {}

class CheckAdminStatus extends AuthEvent {}

class SwitchUserRequested extends AuthEvent {
  SwitchUserRequested({required this.user});
  final UserEntity user;
}

class _AuthStateChanged extends AuthEvent {
  _AuthStateChanged(this.state);
  final AuthState state;
}

// Events - Phone OTP
class SendPhoneOTPRequested extends AuthEvent {
  SendPhoneOTPRequested({required this.phoneNumber, this.isSignup = true});
  final String phoneNumber;
  final bool isSignup;
}

class VerifyPhoneOTPRequested extends AuthEvent {
  VerifyPhoneOTPRequested({
    required this.verificationId,
    required this.smsCode,
    this.name,
  });
  final String verificationId;
  final String smsCode;
  final String? name;
}

class ResetPasswordByPhoneRequested extends AuthEvent {
  ResetPasswordByPhoneRequested({
    required this.verificationId,
    required this.smsCode,
    required this.newPassword,
  });
  final String verificationId;
  final String smsCode;
  final String newPassword;
}

// Events - Email OTP
class SendEmailOTPRequested extends AuthEvent {
  SendEmailOTPRequested({required this.email, this.isSignup = true});
  final String email;
  final bool isSignup;
}

class VerifyEmailOTPRequested extends AuthEvent {
  VerifyEmailOTPRequested({
    required this.email,
    required this.otpCode,
    required this.name,
    required this.password,
  });
  final String email;
  final String otpCode;
  final String name;
  final String password;
}

class ResetPasswordByEmailRequested extends AuthEvent {
  ResetPasswordByEmailRequested({
    required this.email,
    required this.otpCode,
    required this.newPassword,
  });
  final String email;
  final String otpCode;
  final String newPassword;
}

// New events for password reset with OTP verification
class VerifyEmailOTPAndResetPasswordRequested extends AuthEvent {
  VerifyEmailOTPAndResetPasswordRequested({
    required this.email,
    required this.otpCode,
    required this.newPassword,
  });
  final String email;
  final String otpCode;
  final String newPassword;
}

class VerifyPhoneOTPAndResetPasswordRequested extends AuthEvent {
  VerifyPhoneOTPAndResetPasswordRequested({
    required this.verificationId,
    required this.smsCode,
    required this.newPassword,
  });
  final String verificationId;
  final String smsCode;
  final String newPassword;
}

// Events - Check Account Exists
class CheckAccountExistsRequested extends AuthEvent {
  CheckAccountExistsRequested({this.email, this.phoneNumber});
  final String? email;
  final String? phoneNumber;
}

// States
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  AuthAuthenticated({required this.user});
  final UserEntity user;
}

class AuthUnauthenticated extends AuthState {}

class AuthNeedsAdminSetup extends AuthState {
  AuthNeedsAdminSetup({this.message = 'لا يوجد مدير في النظام'});
  final String message;
}

class AuthError extends AuthState {
  AuthError({required this.message});
  final String message;
}

// States - Check Account Exists
class AccountExistsError extends AuthState {}

class AccountNotExistsState extends AuthState {}

// تم حذف AuthEmailAlreadyInUse - لم تعد هناك حاجة لها

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _emailService = EmailNormalizationService();

  AuthBloc({
    required this.signInUseCase,
    required this.signUpUseCase,
    required this.signOutUseCase,
    required this.getCurrentUserUseCase,
    required this.googleSignInUseCase,
    required this.sendPhoneOTPUseCase,
    required this.verifyPhoneOTPUseCase,
    required this.resetPasswordByPhoneUseCase,
    required this.sendEmailOTPUseCase,
    required this.verifyEmailOTPUseCase,
    required this.resetPasswordByEmailUseCase,
    required this.checkIfAccountExistsUseCase,
  }) : super(AuthInitial()) {
    on<SignInRequested>(_onSignInRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<CheckAdminStatus>(_onCheckAdminStatus);
    on<SwitchUserRequested>(_onSwitchUserRequested);
    on<_AuthStateChanged>(_onAuthStateChanged);

    // Phone OTP
    on<SendPhoneOTPRequested>(_onSendPhoneOTPRequested);
    on<VerifyPhoneOTPRequested>(_onVerifyPhoneOTPRequested);
    on<ResetPasswordByPhoneRequested>(_onResetPasswordByPhoneRequested);

    // Email OTP
    on<SendEmailOTPRequested>(_onSendEmailOTPRequested);
    on<VerifyEmailOTPRequested>(_onVerifyEmailOTPRequested);
    on<ResetPasswordByEmailRequested>(_onResetPasswordByEmailRequested);
    on<VerifyEmailOTPAndResetPasswordRequested>(
      _onVerifyEmailOTPAndResetPasswordRequested,
    );
    on<VerifyPhoneOTPAndResetPasswordRequested>(
      _onVerifyPhoneOTPAndResetPasswordRequested,
    );

    // Check Account Exists
    on<CheckAccountExistsRequested>(_onCheckAccountExistsRequested);
  }
  final SignInUseCase signInUseCase;
  final SignUpUseCase signUpUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final GoogleSignInUseCase googleSignInUseCase;

  // Phone OTP Use Cases
  final SendPhoneOTPUseCase sendPhoneOTPUseCase;
  final VerifyPhoneOTPUseCase verifyPhoneOTPUseCase;
  final ResetPasswordByPhoneUseCase resetPasswordByPhoneUseCase;

  // Email OTP Use Cases
  final SendEmailOTPUseCase sendEmailOTPUseCase;
  final VerifyEmailOTPUseCase verifyEmailOTPUseCase;
  final ResetPasswordByEmailUseCase resetPasswordByEmailUseCase;
  final CheckIfAccountExistsUseCase checkIfAccountExistsUseCase;

  // منع التحقق المتكرر
  bool _isCheckingAuth = false;
  DateTime? _lastAuthCheck;

  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Prevent multiple simultaneous sign-in attempts
    if (state is AuthLoading) {
      return;
    }

    // التحقق من الاتصال بالإنترنت أولاً
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!hasConnection) {
        emit(
          AuthError(
            message:
                'لا يوجد اتصال بالإنترنت.\n\nيرجى التحقق من اتصالك والمحاولة مرة أخرى.',
          ),
        );
        return;
      }
    } on Exception {
      // في حالة فشل التحقق من الاتصال، نكمل العملية
    }

    emit(AuthLoading());
    try {
      final result = await signInUseCase(event.email, event.password);
      await result.fold(
        (failure) async => emit(AuthError(message: failure.message)),
        (user) async {
          // التحقق من المدير + دور المستخدم بالتوازي +
          // سياسة فشل التحقق — انظر الملاحظة العليا.
          final hasAdminFuture = () async {
            try {
              final adminCheckService = AdminCheckService();
              return await adminCheckService.hasAdminUser();
            } on Exception {
              return true; // ⚠️ سياسة الفشل — انظر الملاحظة العليا.
            }
          }();

          // التحقق من وجود دور صحيح للمستخدم قبل السماح بالدخول
          final hasValidRole = await _checkUserHasValidRole(user.email);
          final hasAdmin = await hasAdminFuture;

          if (!hasAdmin) {
            // لا يوجد مدير - الانتقال لشاشة إنشاء المدير
            emit(
              AuthNeedsAdminSetup(
                message: 'لا يوجد مدير في النظام، يرجى إنشاء المدير الأول',
              ),
            );
            return;
          }

          if (!hasValidRole) {
            // المستخدم ليس له دور صحيح
            // لكن نسمح له بالمرور إلى AuthAuthenticated
            // حيث سيتم توجيهه إلى شاشة رمز الوصول إذا كانت مفعلة
            emit(AuthAuthenticated(user: user));
          } else {
            emit(AuthAuthenticated(user: user));
          }
        },
      );
    } on Exception catch (e) {
      // معالجة أخطاء الشبكة بناءً على نوع الخطأ
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('network') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('connection')) {
        emit(
          AuthError(
            message:
                'خطأ في الاتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
          ),
        );
      } else {
        emit(AuthError(message: 'حدث خطأ غير متوقع'));
      }
    }
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Prevent multiple simultaneous sign-up attempts
    if (state is AuthLoading) {
      return;
    }

    emit(AuthLoading());
    try {
      final result = await signUpUseCase(
        event.email,
        event.password,
        name: event.name,
      );
      result.fold((failure) => emit(AuthError(message: failure.message)), (
        user,
      ) async {
        // التحقق من وجود مدير في النظام
        try {
          final adminCheckService = AdminCheckService();
          final hasAdmin = await adminCheckService.hasAdminUser();

          if (!hasAdmin) {
            // لا يوجد مدير - الانتقال لشاشة إنشاء المدير
            emit(
              AuthNeedsAdminSetup(
                message: 'لا يوجد مدير في النظام، يرجى إنشاء المدير الأول',
              ),
            );
            return;
          }
        } on Exception catch (_) {
          // ⚠️ سياسة فشل التحقق من المدير — انظر الملاحظة العليا.
        }

        // يوجد مدير - تسجيل الدخول مباشرة
        emit(AuthAuthenticated(user: user));
      });
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Prevent multiple simultaneous Google sign-in attempts
    if (state is AuthLoading) {
      return;
    }

    // التحقق من الاتصال بالإنترنت أولاً
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!hasConnection) {
        emit(
          AuthError(
            message:
                'لا يوجد اتصال بالإنترنت.\n\nيرجى التحقق من اتصالك والمحاولة مرة أخرى.',
          ),
        );
        return;
      }
    } on Exception {
      // في حالة فشل التحقق من الاتصال، نكمل العملية
    }

    emit(AuthLoading());
    try {
      final result = await googleSignInUseCase();
      await result.fold(
        (failure) async {
          // إذا كان الخطأ هو إلغاء من المستخدم، لا نعرض رسالة خطأ
          if (failure.message.contains('تم إلغاء') ||
              failure.message.toLowerCase().contains('cancel')) {
            emit(AuthUnauthenticated());
          } else {
            emit(AuthError(message: failure.message));
          }
        },
        (user) async {
          // التحقق من المدير + دور المستخدم بالتوازي +
          // سياسة فشل التحقق — انظر الملاحظة العليا.
          final hasAdminFuture = () async {
            try {
              final adminCheckService = AdminCheckService();
              return await adminCheckService.hasAdminUser();
            } on Exception {
              return true; // ⚠️ سياسة الفشل — انظر الملاحظة العليا.
            }
          }();

          // التحقق من وجود دور صحيح للمستخدم قبل السماح بالدخول
          final hasValidRole = await _checkUserHasValidRole(user.email);
          final hasAdmin = await hasAdminFuture;

          if (!hasAdmin) {
            // لا يوجد مدير - الانتقال لشاشة إنشاء المدير
            emit(
              AuthNeedsAdminSetup(
                message: 'لا يوجد مدير في النظام، يرجى إنشاء المدير الأول',
              ),
            );
            return;
          }

          if (!hasValidRole) {
            // المستخدم ليس له دور صحيح
            // لكن نسمح له بالمرور إلى AuthAuthenticated
            // حيث سيتم توجيهه إلى شاشة رمز الوصول إذا كانت مفعلة
            // Emit AuthAuthenticated immediately for instant navigation
            emit(AuthAuthenticated(user: user));
          } else {
            // Emit AuthAuthenticated immediately for instant navigation
            emit(AuthAuthenticated(user: user));
          }
        },
      );
    } on Exception catch (e) {
      // معالجة ذكية لأخطاء تسجيل الدخول عبر جوجل
      var errorMessage = e.toString();

      // معالجة إغلاق المستخدم للنافذة (ليس خطأ)
      if (errorMessage.toLowerCase().contains('popup_closed') ||
          errorMessage.toLowerCase().contains('user_canceled') ||
          errorMessage.toLowerCase().contains('sign_in_canceled')) {
        // المستخدم ألغى العملية - العودة لحالة غير مسجل دخول بدون رسالة خطأ
        emit(AuthUnauthenticated());
        return;
      }

      // معالجة أخطاء الشبكة بناءً على محتوى الخطأ
      if (errorMessage.toLowerCase().contains('network') ||
          errorMessage.toLowerCase().contains('timeout') ||
          errorMessage.toLowerCase().contains('connection')) {
        emit(
          AuthError(
            message:
                'خطأ في الشبكة أثناء تسجيل الدخول عبر جوجل. تحقق من اتصالك وحاول مرة أخرى.',
          ),
        );
        return;
      }

      // معالجة أخطاء إعداد تسجيل الدخول عبر جوجل
      if (errorMessage.contains('ClientID not set') ||
          errorMessage.contains('Google Sign-In غير مُعدّ')) {
        emit(
          AuthError(
            message:
                'خدمة تسجيل الدخول عبر جوجل غير مُعدّة بشكل صحيح للويب. يرجى استخدام تسجيل الدخول بالبريد الإلكتروني كبديل.',
          ),
        );
        return;
      }

      // معالجة أخطاء بيانات المصادقة
      if (errorMessage.contains('credential') &&
          (errorMessage.contains('incorrect') ||
              errorMessage.contains('malformed') ||
              errorMessage.contains('expired'))) {
        emit(
          AuthError(
            message:
                'حدث خطأ في بيانات المصادقة من جوجل. يرجى المحاولة مرة أخرى أو استخدام البريد الإلكتروني وكلمة المرور.',
          ),
        );
        return;
      }

      // معالجة أخطاء إعدادات تسجيل الدخول عبر جوجل للويب
      if (errorMessage.toLowerCase().contains('storagerelay') ||
          errorMessage.toLowerCase().contains('native_android') ||
          errorMessage.toLowerCase().contains('client type') ||
          errorMessage.toLowerCase().contains('access blocked') ||
          errorMessage.toLowerCase().contains('authorization error')) {
        emit(
          AuthError(
            message:
                'خدمة تسجيل الدخول عبر جوجل غير مُعدّة بشكل صحيح للويب حالياً.\n\nيرجى استخدام تسجيل الدخول بالبريد الإلكتروني وكلمة المرور كبديل موثوق.',
          ),
        );
        return;
      }

      // معالجة أخطاء الشبكة
      if (errorMessage.contains('network') ||
          errorMessage.contains('timeout')) {
        emit(
          AuthError(
            message:
                'خطأ في الشبكة أثناء تسجيل الدخول عبر جوجل. تحقق من اتصالك وحاول مرة أخرى.',
          ),
        );
        return;
      }

      // التحقق من وجود مستخدم مسجل دخول رغم الخطأ
      try {
        final currentUser = await getCurrentUserUseCase();
        await currentUser.fold(
          (failure) async {
            // فشل في الحصول على المستخدم الحالي
            emit(
              AuthError(
                message:
                    'فشل تسجيل الدخول عبر جوجل. يرجى المحاولة مرة أخرى أو استخدام البريد الإلكتروني.',
              ),
            );
          },
          (user) async {
            if (user != null) {
              // السماح بالمرور إلى AuthAuthenticated
              // حيث سيتم توجيهه إلى شاشة رمز الوصول إذا كانت مفعلة
              emit(AuthAuthenticated(user: user));
            } else {
              // لا يوجد مستخدم مسجل دخول
              emit(
                AuthError(
                  message:
                      'فشل تسجيل الدخول عبر جوجل. يرجى المحاولة مرة أخرى أو استخدام البريد الإلكتروني وكلمة المرور.',
                ),
              );
            }
          },
        );
      } on Exception catch (_) {
        // خطأ في التحقق من المستخدم الحالي
        emit(
          AuthError(
            message:
                'حدث خطأ غير متوقع. يرجى استخدام تسجيل الدخول بالبريد الإلكتروني وكلمة المرور.',
          ),
        );
      }
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      try {
        await PushNotificationService.unregisterCurrentUserToken();
      } on Exception {
        // تجاهل أخطاء إلغاء التسجيل لضمان تسجيل الخروج
      }

      // مسح بيانات الجلسة نهائياً (بما في ذلك الجلسة الدائمة)
      // + مسح حالة تسجيل الدخول الأولي بالتوازي — انظر
      // الملاحظة العليا (الأداء).
      await Future.wait([
        SessionService.clearAll(),
        AuthNavigationService.clearFirstLoginState(),
      ]);

      // إغلاق الـ Stream وتنظيف الموارد لتجنب تسرب الذاكرة
      SessionService.dispose();

      final result = await signOutUseCase();
      result.fold(
        (failure) => emit(AuthError(message: failure.message)),
        (_) => emit(AuthUnauthenticated()),
      );
    // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    // منع التحقق المتكرر
    final now = DateTime.now();
    if (_isCheckingAuth ||
        (_lastAuthCheck != null &&
            now.difference(_lastAuthCheck!).inSeconds < 2)) {
      return;
    }

    _isCheckingAuth = true;
    _lastAuthCheck = now;

    emit(AuthLoading());

    try {
      // الخطوة الأولى: التحقق من تسجيل الدخول أولاً
      final userResult = await getCurrentUserUseCase().timeout(
        const Duration(seconds: 5),
      );

      await userResult.fold(
        (failure) async {
          // لا يوجد مستخدم مسجل دخول - الانتقال لشاشة تسجيل الدخول
          if (!emit.isDone) emit(AuthUnauthenticated());
        },
        (user) async {
          if (user == null) {
            // لا يوجد مستخدم مسجل دخول - الانتقال لشاشة تسجيل الدخول
            if (!emit.isDone) emit(AuthUnauthenticated());
          } else {
            // يوجد مستخدم مسجل دخول - المتابعة للتحقق من المدير
            // التحقق من المدير + دور المستخدم بالتوازي +
            // سياسة فشل التحقق — انظر الملاحظة العليا.
            final hasAdminFuture = () async {
              try {
                // استخدام AdminCheckService للتحقق من وجود المدير أولاً
                final adminCheckService = AdminCheckService();
                return await adminCheckService.hasAdminUser().timeout(
                  const Duration(seconds: 10),
                );
              } on Exception {
                return true; // ⚠️ سياسة الفشل — انظر الملاحظة العليا.
              }
            }();

            // التحقق من دور المستخدم الحالي
            final hasValidRole = await _checkUserHasValidRole(user.email);
            final hasAdmin = await hasAdminFuture;

            if (!hasAdmin) {
              // لا يوجد مدير - الانتقال لشاشة إنشاء المدير
              if (!emit.isDone) {
                emit(
                  AuthNeedsAdminSetup(
                    message:
                        'لا يوجد مدير في النظام، يرجى إنشاء المدير الأول',
                  ),
                );
              }
              return;
            }

            if (!hasValidRole) {
              // المستخدم الحالي ليس له دور
              // لكن نسمح له بالمرور إلى AuthAuthenticated
              // حيث سيتم توجيهه إلى شاشة رمز الوصول إذا كانت مفعلة
              if (!emit.isDone) emit(AuthAuthenticated(user: user));
            } else {
              // المستخدم له دور صحيح - الانتقال للداشبورد
              if (!emit.isDone) emit(AuthAuthenticated(user: user));
            }
          }
        },
      );
    } on Exception catch (_) {
      // خطأ في التحقق من تسجيل الدخول - الانتقال لشاشة تسجيل الدخول
      if (!emit.isDone) {
        emit(AuthUnauthenticated());
      }
    } finally {
      _isCheckingAuth = false;
    }
  }

  Future<void> _onCheckAdminStatus(
    CheckAdminStatus event,
    Emitter<AuthState> emit,
  ) async {
    // تجنب التحقق المتكرر إذا كانت الحالة الحالية صحيحة
    if (state is AuthNeedsAdminSetup || state is AuthLoading) {
      return;
    }

    emit(AuthLoading());
    try {
      final adminCheckResult =
          await AdminCheckMiddleware.checkAdminWithDetails();

      if (adminCheckResult.hasAdmin) {
        // يوجد مدير، التحقق من حالة المصادقة
        final result = await getCurrentUserUseCase();
        await result.fold(
          (failure) async {
            if (!emit.isDone) emit(AuthUnauthenticated());
          },
          (user) async {
            if (user != null) {
              if (!emit.isDone) emit(AuthAuthenticated(user: user));
            } else {
              if (!emit.isDone) emit(AuthUnauthenticated());
            }
          },
        );
      } else {
        // لا يوجد مدير
        if (!emit.isDone) {
          emit(
            AuthNeedsAdminSetup(
              message: adminCheckResult.hasAnyUsers
                  ? 'يوجد ${adminCheckResult.usersCount} مستخدم لكن لا يوجد مدير'
                  : 'لا يوجد مستخدمين في النظام، يرجى إنشاء المدير الأول',
            ),
          );
        }
      }
    } on Exception catch (_) {
      if (!emit.isDone) emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onSwitchUserRequested(
    SwitchUserRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // مسح cache التحقق من المدير أولاً
      AdminCheckMiddleware.clearCache();

      // تبديل المستخدم مباشرة بدون تحقق إضافي
      emit(AuthAuthenticated(user: event.user));

      // التحقق من وجود مدير في الخلفية للتأكد
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          final adminCheckResult =
              await AdminCheckMiddleware.checkAdminWithDetails();
          if (!adminCheckResult.hasAdmin && !isClosed) {
            // لا يوجد مدير، العودة لشاشة إنشاء المدير
            add(CheckAdminStatus());
          }
        } on Exception {
          // تجاهل الأخطاء في التحقق الخلفي
        }
      });
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onAuthStateChanged(
    _AuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    emit(event.state);
  }

  /// التحقق من وجود دور صحيح للمستخدم
  Future<bool> _checkUserHasValidRole(String userEmail) async {
    try {
      // تطبيع البريد الإلكتروني
      final organizationId = _emailService.normalize(userEmail);

      // البحث عن المستخدم في قاعدة البيانات مع timeout أطول
      final userQuery = await FirebaseFirestore.instance
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (userQuery.docs.isEmpty) {
        // البحث البديل بمعرف Firebase Auth
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userByUid = await FirebaseFirestore.instance
              .collection(organizationId)
              .doc('users')
              .collection('users')
              .doc(currentUser.uid)
              .get()
              .timeout(const Duration(seconds: 10));

          if (!userByUid.exists) {
            // المستخدم غير موجود في قاعدة البيانات
            return false;
          }

          final userData = userByUid.data()!;
          final roleIds = List<String>.from(userData['roleIds'] ?? []);

          if (roleIds.isEmpty) {
            // المستخدم ليس له أدوار
            return false;
          }

          // التحقق من وجود الأدوار في قاعدة البيانات
          final rolesQuery = await FirebaseFirestore.instance
              .collection(organizationId)
              .doc('users')
              .collection('roles')
              .where(FieldPath.documentId, whereIn: roleIds)
              .get()
              .timeout(const Duration(seconds: 10));

          // التأكد من وجود دور واحد على الأقل صالح
          return rolesQuery.docs.isNotEmpty;
        }

        return false;
      }

      final userData = userQuery.docs.first.data();
      final roleIds = List<String>.from(userData['roleIds'] ?? []);

      if (roleIds.isEmpty) {
        // المستخدم ليس له أدوار
        return false;
      }

      // التحقق من وجود الأدوار في قاعدة البيانات مع timeout أطول
      final rolesQuery = await FirebaseFirestore.instance
          .collection(organizationId)
          .doc('users')
          .collection('roles')
          .where(FieldPath.documentId, whereIn: roleIds)
          .get()
          .timeout(const Duration(seconds: 10));

      // التأكد من وجود دور واحد على الأقل صالح
      return rolesQuery.docs.isNotEmpty;
    } on Exception catch (_) {
      // في حالة الخطأ، محاولة أخيرة باستخدام AdminCheckService
      try {
        final adminCheckService = AdminCheckService();
        return await adminCheckService.hasAdminUser();
      } on Exception {
        // في حالة فشل جميع المحاولات، نعتبر أن المستخدم ليس له دور صحيح
        return false;
      }
    }
  }

  // ==================== Phone OTP Handlers ====================

  Future<void> _onSendPhoneOTPRequested(
    SendPhoneOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // استخدام isSignup: false لأن هذا للتحقق من وجود الحساب في نسيان كلمة المرور
      final result = await sendPhoneOTPUseCase(
        event.phoneNumber,
        isSignup: event.isSignup,
      );
      result.fold(
        (failure) => emit(AuthError(message: failure.message)),
        (verificationId) => emit(PhoneOTPSent(verificationId: verificationId)),
      );
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onVerifyPhoneOTPRequested(
    VerifyPhoneOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await verifyPhoneOTPUseCase(
        event.verificationId,
        event.smsCode,
        name: event.name,
      );
      result.fold(
        (failure) => emit(AuthError(message: failure.message)),
        (user) => emit(AuthAuthenticated(user: user)),
      );
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onResetPasswordByPhoneRequested(
    ResetPasswordByPhoneRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await resetPasswordByPhoneUseCase(
        event.verificationId,
        event.smsCode,
        event.newPassword,
      );
      result.fold(
        (failure) => emit(AuthError(message: failure.message)),
        (_) => emit(PasswordResetSuccessfully()),
      );
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  // ==================== Email OTP Handlers ====================

  Future<void> _onSendEmailOTPRequested(
    SendEmailOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await sendEmailOTPUseCase(
        event.email,
        isSignup: event.isSignup,
      );
      result.fold((failure) {
        emit(AuthError(message: failure.message));
      }, (_) => emit(EmailOTPSent(email: event.email)));
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onVerifyEmailOTPRequested(
    VerifyEmailOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await verifyEmailOTPUseCase(
        event.email,
        event.otpCode,
        name: event.name,
        password: event.password,
      );
      result.fold(
        (failure) => emit(AuthError(message: failure.message)),
        (user) => emit(AuthAuthenticated(user: user)),
      );
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onResetPasswordByEmailRequested(
    ResetPasswordByEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await resetPasswordByEmailUseCase(
        event.email,
        event.otpCode,
        event.newPassword,
      );
      result.fold(
        (failure) => emit(AuthError(message: failure.message)),
        (_) => emit(PasswordResetSuccessfully()),
      );
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  // ==================== Verify OTP and Reset Password Handlers ====================

  Future<void> _onVerifyEmailOTPAndResetPasswordRequested(
    VerifyEmailOTPAndResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await resetPasswordByEmailUseCase(
        event.email,
        event.otpCode,
        event.newPassword,
      );
      result.fold(
        (failure) => emit(AuthError(message: failure.message)),
        (_) => emit(PasswordResetSuccessfully()),
      );
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onVerifyPhoneOTPAndResetPasswordRequested(
    VerifyPhoneOTPAndResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await resetPasswordByPhoneUseCase(
        event.verificationId,
        event.smsCode,
        event.newPassword,
      );
      result.fold(
        (failure) => emit(AuthError(message: failure.message)),
        (_) => emit(PasswordResetSuccessfully()),
      );
    } on Exception catch (_) {
      emit(AuthError(message: 'حدث خطأ غير متوقع'));
    }
  }

  // ==================== Check Account Exists Handler ====================

  Future<void> _onCheckAccountExistsRequested(
    CheckAccountExistsRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await checkIfAccountExistsUseCase(
        email: event.email,
        phoneNumber: event.phoneNumber,
      );
      result.fold(
        (failure) {
          // فشل التحقق - نسمح بإنشاء الحساب
          emit(AccountNotExistsState());
        },
        (exists) {
          if (exists) {
            // الحساب موجود
            emit(AccountExistsError());
          } else {
            // الحساب غير موجود - نسمح بإنشاء الحساب
            emit(AccountNotExistsState());
          }
        },
      );
    } on Exception {
      // فشل التحقق - نسمح بإنشاء الحساب
      emit(AccountNotExistsState());
    }
  }
}

// States - Phone OTP
class PhoneOTPSent extends AuthState {
  PhoneOTPSent({required this.verificationId});
  final String verificationId;
}

class PhoneOTPVerified extends AuthState {}

// States - Email OTP
class EmailOTPSent extends AuthState {
  EmailOTPSent({required this.email});
  final String email;
}

class EmailOTPVerified extends AuthState {}

// State - Password Reset
class PasswordResetSuccessfully extends AuthState {}
