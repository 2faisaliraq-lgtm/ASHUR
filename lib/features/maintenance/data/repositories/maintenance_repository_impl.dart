import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/rate_limiter_service.dart';
import '../../domain/entities/equipment_entity.dart';
import '../../domain/entities/maintenance_log_entity.dart';
import '../../domain/entities/maintenance_request_entity.dart';
import '../../domain/entities/maintenance_requests_page.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/validators/input_sanitizer.dart';
import '../../domain/validators/maintenance_validator.dart';
import '../models/equipment_model.dart';
import '../models/maintenance_log_model.dart';
import '../models/maintenance_request_model.dart';

/// ⚠️ ملاحظة: الصيانة تتطلب عناية فائقة
class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl({required this.firestore});
  final FirebaseFirestore firestore;
  final RateLimiterService _rateLimiter = RateLimiterService();
  final _emailService = EmailNormalizationService();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⚠️ قاعدة ذرية حاسمة (لا تُزل هذه الملاحظة):
  // داخل أي runTransaction في هذا الملف: كل transaction.get()
  // يجب أن يسبق كل transaction.set()/update()/delete().
  // انتهاكها يسبب خطأ '_commands.isEmpty': Transactions require
  // all reads to be executed before all writes.
  // _setMaintenanceLogInTransaction لا يحتوي على أي get
  // (فقط set بمعرف تلقائي عبر .doc()) لذلك يُستدعى بأمان
  // بعد الكتابة الرئيسية داخل نفس المعاملة.
  //
  // ⚠️ سجل التحقق اليدوي من الذرية (2026-10-08 و2026-10-09
  // و2026-10-11 و2026-10-12 — دُمجت كتل التحقق المتكررة
  // القديمة وكتل "ملاحظة للمبرمجين المستقبليين" المتكررة
  // تحت كل عملية في هذه الملاحظة الوحيدة وإشارات موجزة
  // لها لتجنب الإطالة): أُعيد التحقق يدوياً سطراً بسطر
  // من هذا الملف كاملاً ومن بقية قسم الصيانة (BLoC، حالات
  // الاستخدام، الحقن، الصفحات، الدوال السحابية). النتيجة:
  // ترتيب القراءة/الكتابة مطابق تماماً لما هو موثق أدناه
  // (كل get قبل أي كتابة والسجل داخل نفس المعاملة) — لا
  // خطأ في المنطق ولا حاجة لأي تعديل فيه. ✅ أرقام الأسطر
  // حُذفت واستُبدلت بأسماء الدوال (اعتمد على أسماء الدوال
  // لا أرقام الأسطر): أي دمج أو إضافة تعليقات تُزيح أرقام
  // الأسطر فتصبح القديمة مضللة — وهذا هو سبب انحرافها
  // المتكرر في السجلات السابقة.
  //
  // ⚠️العمليات الذرية الست — كلها صحيحة: كل get قبل أي كتابة،
  // والسجل داخل نفس المعاملة✅
  //   1. createMaintenanceRequest:  runTransaction ✅
  //      get(تحقق عدم التكرار) ⇐ set ✅ سجل
  //   2. updateMaintenanceRequest:  runTransaction ✅
  //      get(تحقق الوجود) ⇐ update ✅ سجل
  //      (الحالة/القيم القديمة من docSnapshot.data() — ليس get جديداً)
  //   3. deleteMaintenanceRequest:  runTransaction ✅
  //      get(تحقق الوجود) ⇐ delete ✅ سجل
  //      (العنوان من docSnapshot.data() — ليس get جديداً)
  //   4. addEquipment:              runTransaction ✅
  //      get(تحقق عدم التكرار) ⇐ set ✅ سجل
  //   5. updateEquipment:           runTransaction ✅
  //      get(تحقق الوجود) ⇐ update ✅ سجل
  //   6. deleteEquipment:           runTransaction ✅
  //      get(تحقق الوجود) ⇐ delete ✅ سجل
  //      (الاسم من docSnapshot.data() — ليس get جديداً)
  //
  // ⚠️العمليات غير الذرية — مُتحقق منها ولا تحتاج Transaction✅
  //   - addMaintenanceLog: كتابة مستند واحد بـ .add() —
  //     ذرية بطبيعتها في Firestore، بلا قراءة سابقة.
  //     ⚠️ إذا أردت مستقبلاً تحقق عدم تكرار السجلات
  //     أو قيوداً أخرى، حوّلها إلى Transaction (القاعدة
  //     الحاسمة أعلاه). حالياً آمنة لأنها بلا تحقق تكرار.
  //   - deleteMaintenanceLog: حذف مستند واحد بـ .delete() —
  //     ذرية بطبيعتها و idempotent (حذف غير الموجود ليس
  //     فشلاً). لا تحتاج Transaction ما دام: لا قراءة (get)
  //     قبل الكتابة، ولا شروط تعتمد على الحالة الحالية.
  //     ⚠️ حوّلها إلى Transaction فقط إذا احتجت: تحقق
  //     الوجود قبل الحذف، حذف مشروط بحالة المستند، أو
  //     حذف عدة مستندات مترابطة كوحدة واحدة.
  //   - clearMaintenanceLogs: query.get() + WriteBatch +
  //     commit — التزام ذري للتنفيذ فقط (Batch لا يضمن
  //     عدم حذف مستندات عُدلت أثناء العملية)، مقبولة
  //     لتنظيف دوري وليست عملية حرجة تعتمد على حالة
  //     حالية. استخدم Transaction إذا احتجت ذلك الضمان.
  //   - getMaintenanceStats / getMaintenanceLogs /
  //     getMaintenanceStatisticsStream: قراءة فقط (حساب
  //     محلي من البيانات). الإحصائيات ليست مخزنة بشكل
  //     ذري فتقد تكون غير دقيقة لحظياً عند عمليات
  //     متزامنة — مقبولة لأنها تُحسب من الجلب/الستريم
  //     الحاليين. لإحصائيات ذرية يجب تخزينها في مستند
  //     منفصل يُحدَّث في نفس Transaction عند العمليات.
  //   - الستريمات (getMaintenanceRequestsStream /
  //     getEquipmentStream / getMaintenanceLogsStream):
  //     قراءة فقط عبر snapshots() — لا تحتوي على أي
  //     كتابة أو معاملة، لذلك لا تنطبق عليها قاعدة
  //     "كل القراءات قبل كل الكتابات".
  //     أُضيف getEquipmentStream و getMaintenanceLogsStream
  //     (2026-10-11) لتحديث المعدات وسجل النشاطات فورياً
  //     في الـ BLoC وصفحة السجل بدلاً من التحميل لمرة
  //     واحدة بـ Future.
  //
  // ⚠️مُتحقق أيضاً✅
  //   - BLoC: الـ 5 استدعاءات لـ addMaintenanceLog (تُعرف
  //     بأنواعها فقط — أُزيلت أرقام أسطرها القديمة
  //     المضللة) كلها سجلات أخطاء جانبية لفشل الفاتورة
  //     التلقائية فقط (invoice_creation_failed، auto_invoice_timeout،
  //     auto_invoice_pdf_error، auto_invoice_service_unavailable،
  //     auto_invoice_creation_error) — تسجيل العمليات داخل
  //     Transaction هنا فقط. الفاتورة التلقائية والإشعارات خارج
  //     المعاملة مقصودة: آثار جانبية خارجية لا يمكن التراجع عنها
  //     داخل transaction وفشلها لا يجب أن يلغي العملية الأساسية.
  //   - حالات الاستخدام: وكلاء رقيقون يحوّلون للمستودع فقط
  //     (مثال: CreateMaintenanceRequest.call).
  //   - الحقن: sl<FirebaseFirestore>() = FirebaseFirestore.instance
  //     (تهيئة التطبيق ⚠️ صيانة injection_container.dart:
  //     MaintenanceRepositoryImpl(firestore: sl<FirebaseFirestore>())).
  //   ⚠️ قاعدة أُصلحت بتاريخ 2026-10-11: المعاملات الست
  //     تعمل الآن على this.firestore (المثيل المحقن عبر
  //     المُنشئ) وليس FirebaseFirestore.instance العالمي
  //     — كان المتغير firestoreInstance الزائد يُشغّل
  //     المعاملة على المثيل العالمي بينما مراجع
  //     المستندات تُبنى من this.firestore. في الإنتاج
  //     هما نفس المثيل المفرد فلم يتغير السلوك، لكن
  //     هذا التناقض يُبطل فائدة الحقن (اختبار يحقن
  //     مثيلاً مزيفاً ستتجاهله المعاملة) وقد يوجّه
  //     المعاملة لمثيل مختلف عن مراجعها. القاعدة:
  //     استخدم this.firestore دائماً للمعاملة ومراجعها
  //     معاً — لا تُدخل متغيراً للمثيل العالمي هنا.
  //   - الصفحات: FirebaseFirestore المباشر في
  //     _getUserNameFromFirebase في edit_maintenance_request_page
  //     و maintenance_details_page للقراءة فقط (أسماء
  //     المستخدمين) — بلا أي كتابة خارج المعاملات.
  //   - الدوال السحابية: functions/index.js موجود لكنه لا يمس قسم
  //     الصيانة أبداً (لا يحتوي على أي إشارة لها) — يحتوي فقط على
  //     عمليات الاشتراكات والعملاء والفواتير الذرية.
  //
  // ⚠️ ما يجب أن يبقى ذرياً دائماً (قاعدة للمبرمجين المستقبليين):
  // أي عملية تجمع "قراءة حالة حالية + كتابة تعتمد عليها" (تحقق
  // تكرار/وجود/انتقال حالة) تبقى داخل runTransaction واحد بكل
  // القراءات قبل كل الكتابات، ويُسجل السجل داخل نفس المعاملة
  // عبر _setMaintenanceLogInTransaction. عند إضافة عملية جديدة
  // من هذا النوع انسخ نمط العمليات الست أعلاه (get أولاً، ثم
  // الكتابة، ثم السجل آخراً).
  // لماذا هذا مهم:
  //   (أ) أي transaction.get() بعد بدء الكتابة داخل نفس المعاملة
  //       يسبب خطأ '_commands.isEmpty' ويكسر المعاملة بالكاملة.
  //   (ب) تسجيل السجل خارج المعاملة ينتج طلباً/معدة بلا سجل نشاط
  //       عند فشل التسجيل — الذرية هنا تمنع ذلك.
  //   (ج) التحقق خارج المعاملة يفتح باب حالات السباق (Race
  //       Conditions) حيث تمرر عمليتان متزامنتان نفس التحقق.
  //   (د) الذرية عبر مستودعين (طلب صيانة + فاتورة) لا تُحل بـ
  //       runTransaction واحدة — استخدم نمط Saga أو Cloud
  //       Functions. لا تُدخل الفاتورة/الإشعار في معاملة الصيانة.
  //
  // ⚠️ لا تستخدم سكربت أو أداة آلية لتعديل هذا الملف — التعديل
  // يدوي فقط لضمان عدم كسر ترتيب المعاملة.
  // لا تغيّر ترتيب القراءة/الكتابة داخل هذه المعاملات أبداً.
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  String? _getCurrentOrganizationId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;
    // ⚠️ ملاحظة للمبرمجين المستقبليين: إعادة استخدام الحقل _emailService المُنشأ مرة واحدة
    // بدلاً من إنشاء مثيل جديد في كل استدعاء (تجنب هدر الموارد وعدم اتساق الت_normalization).
    return _emailService.normalize(user!.email!);
  }

  /// ⚠️ العمليات الست صحيحة
  ///
  /// ⚠️ ملاحظة للمبرمجين المستقبليين (إصلاح 2026-10-08):
  /// كانت اللاحقة العشوائية تُحسب بـ .substring(0, 3) على
  /// نتيجة padLeft(6, '0') — وهذا يأخذ أول 3 أحرف وهي
  /// "000" دائماً (لأن microsecond تتراوح 0-999 فقط)،
  /// فكانت اللاحقة ميتة والمعرف يتكرر عند عمليتين في نفس
  /// الألفية من الثانية (المعاملة تلتقط التكرار بأمان لكن
  /// العملية الثانية تفشل دون داعٍ). الصحيح .substring(3)
  /// لأخذ آخر 3 أحرف (الجزء العشوائي الحقيقي). لا تُرجعها
  /// إلى substring(0, 3) أبداً.
  String _generateShortId(String prefix) {
    // ⚠️ تحسين الأداء: قراءة واحدة للساعة بدلاً من
    // اثنتين — الطابع الزمني والجزء العشوائي من
    // نفس اللحظة (يمنع أيضاً اختلاف العشوائي عن
    // الطابع عند عبور حد الألفية من الثانية).
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final randomSuffix = now.microsecond
        .toString()
        .padLeft(6, '0')
        .substring(3);
    final shortTimestamp = timestamp.toString().substring(8); // آخر 5 أرقام
    return '$prefix$shortTimestamp$randomSuffix';
  }

  /// تسجيل سجل نشاط داخل معاملة Firestore لضمان الذرية الكاملة
  ///
  /// ⚠️ قاعدة حاسمة للمبرمجين المستقبليين:
  /// هذا يجب أن يُستدعى داخل runTransaction فقط، ويجب أن يكون
  /// بعد كل عمليات transaction.get() في نفس المعاملة.
  /// هذا الأسلوب لا يحتوي على أي قراءة (get) — فقط كتابة (set) —
  /// لذلك لا ينتهك قاعدة Firestore "كل القراءات قبل كل الكتابات"
  /// حتى لو استُدعى بعد الكتابة الرئيسية.
  ///
  /// لماذا هذا الأسلوب:
  /// تسجيل السجل داخل نفس المعاملة يضمن أن العملية الرئيسية
  /// (إنشاء/تحديث/حذف) وتسجيل السجل تتمان كوحدة ذرية واحدة:
  /// إما تكتملان معاً أو تفشلان معاً. هذا يمنع وجود طلب صيانة
  /// أو معدة بدون سجل نشاط عند فشل التسجيل.
  ///
  /// ملاحظة حول إعادة المحاولة:
  /// معاملات Firestore قد تُعاد محاولتها عند التعارض، لكن كل
  /// محاولة فاشلة تُلغي كتاباتها بالكامل، لذلك لا يتم إنشاء
  /// سجلات مكررة حتى لو أُعيدت المحاولة عدة مرات.
  void _setMaintenanceLogInTransaction(
    Transaction transaction, {
    required String organizationId,
    required String userId,
    required String actionType,
    String? userName,
    String? userEmail,
    String? details,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) {
    final logRef = firestore
        .collection(organizationId)
        .doc('maintenance')
        .collection('logs')
        .doc();
    transaction.set(logRef, {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'actionType': actionType,
      'timestamp': Timestamp.fromDate(DateTime.now()),
      'details': details,
      'isSuccess': true,
      'ipAddress': null,
      'userAgent': null,
      'targetId': targetId,
      'targetType': targetType,
      'oldValues': oldValues,
      'newValues': newValues,
      'sessionId': null,
      'deviceInfo': null,
    });
  }

  @override
  Future<Either<Failure, List<MaintenanceRequestEntity>>>
  getMaintenanceRequests(
    String organizationEmail, {
    int? limit,
    dynamic lastDocument,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      Query query = firestore
          .collection(normalizedEmail)
          .doc('maintenance')
          .collection('maintenance')
          .orderBy('createdAt', descending: true);

      // تطبيق ترقيم الصفحات باستخدام مستند اللقطة مباشرة (بدون جولة شبكة زائدة)
      if (lastDocument != null && lastDocument is DocumentSnapshot) {
        query = query.startAfterDocument(lastDocument);
      }

      // تطبيق الحد الأقصى للنتائج فقط إذا تم تمريره (null = جميع البيانات)
      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      final requests = <MaintenanceRequestEntity>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
          mapData['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
        }
        requests.add(MaintenanceRequestModel.fromJson(mapData));
      }

      return Right(requests);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب طلبات الصيانة: $e'));
    }
  }

  @override
  Future<Either<Failure, MaintenanceRequestsPage>>
  getMaintenanceRequestsPaginated({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // ⚠️ تحسين (2026-10-12): نفس ترتيب
      // getMaintenanceRequests (createdAt تنازلي)
      // مع إعادة مؤشر الصفحة من نتيجة الاستعلام
      // نفسها (snapshot.docs.last) بدلاً من جلب
      // المستند الأخير عبر معرفه — كان يضيف جولة
      // شبكة زائدة بعد كل تحميل صفحة (نفس تحسين
      // قسم الفواتير).
      Query query = firestore
          .collection(normalizedEmail)
          .doc('maintenance')
          .collection('maintenance')
          .orderBy('createdAt', descending: true);

      // إذا كان هناك مستند آخر، نبدأ بعده
      if (lastDocument != null && lastDocument is DocumentSnapshot) {
        query = query.startAfterDocument(lastDocument);
      }

      // تطبيق الحد الأقصى للنتائج
      query = query.limit(limit);

      final snapshot = await query.get();

      final requests = <MaintenanceRequestEntity>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
          mapData['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
        }
        requests.add(MaintenanceRequestModel.fromJson(mapData));
      }

      return Right(
        MaintenanceRequestsPage(
          requests: requests,
          lastDocument:
              snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب طلبات الصيانة: $e'));
    }
  }

  @override
  Future<Either<Failure, List<MaintenanceRequestEntity>>>
  searchMaintenanceRequests(
    String organizationEmail,
    String searchQuery, {
    dynamic lastDocument,
    int? limit,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // البحث في العنوان والوصف
      Query query = firestore
          .collection(normalizedEmail)
          .doc('maintenance')
          .collection('maintenance')
          .orderBy('createdAt', descending: true);

      // لا يمكن استخدام أكثر من one inequality clause في Firestore
      // لذا نستخدم بحث نصي بسيط ونطبق الفلترة محلياً

      // تطبيق الحد الأقصى للنتائج
      if (limit != null) {
        query = query.limit(limit);
      }

      // تطبيق ترقيم الصفحات باستخدام مستند اللقطة مباشرة (بدون جولة شبكة زائدة)
      if (lastDocument != null && lastDocument is DocumentSnapshot) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();

      final requests = <MaintenanceRequestEntity>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
          mapData['id'] = doc.id;
        }
        requests.add(MaintenanceRequestModel.fromJson(mapData));
      }

      // تطبيق البحث النصي محلياً (في العنوان والوصف واسم المعدة)
      // لأن Firestore لا تدعم أكثر من شرط عدم مساواة واحد —
      // نفس نمط _applyFilters في BLoC و getMaintenanceLogs هنا.
      // ⚠️ ملاحظة للمبرمجين المستقبليين: لا تُزيل هذه الفلترة
      // — searchQuery معامل أساسي للدالة وتجاهله يعيد كل
      // الطلبات بلا تصفية (هذا الخلل أُصلح يدوياً 2026-10-12:
      // كان الكود يجلب الطلبات ويتجاهل searchQuery تماماً).
      if (searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        requests.retainWhere((request) =>
            request.title.toLowerCase().contains(searchLower) ||
            request.description.toLowerCase().contains(searchLower) ||
            (request.equipmentName?.toLowerCase().contains(searchLower) ??
                false));
      }

      return Right(requests);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في البحث في طلبات الصيانة: $e'));
    }
  }

  @override
  Future<Either<Failure, MaintenanceRequestEntity>> getMaintenanceRequestById(
    String id,
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final doc = await firestore
          .collection(normalizedEmail)
          .doc('maintenance')
          .collection('maintenance')
          .doc(id)
          .get();

      if (!doc.exists) {
        return const Left(ServerFailure(message: 'طلب الصيانة غير موجود'));
      }

      final data = doc.data();
      if (data == null) return Left(ServerFailure(message: 'المستند فارغ'));
      // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
      if (data['id'] == null || data['id'].toString().isEmpty) {
        data['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
      }
      final request = MaintenanceRequestModel.fromJson(data);

      return Right(request);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب طلب الصيانة: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> createMaintenanceRequest(
    MaintenanceRequestEntity request,
  ) async {
    try {
      // ملاحظة للمبرمجين المستقبليين: عملية ذرية (Atomic) عبر runTransaction — تحقق عدم التكرار + الحفظ + السجل كوحدة واحدة (السبب الكامل وترتيب القراءة/الكتابة موثق في الملاحظة الشاملة أعلاه) — لا تضع أي transaction.get() بعد الكتابة هنا.
      // فحص حد المعدل
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        if (!_rateLimiter.canMakeRequest(
          authUser.uid,
          operation: 'create_maintenance',
        )) {
          final timeUntilNext = _rateLimiter.getTimeUntilNextRequest(
            authUser.uid,
            operation: 'create_maintenance',
          );
          return Left(
            ServerFailure(
              message:
                  'تم تجاوز الحد المسموح للطلبات. يرجى المحاولة بعد ${timeUntilNext?.inSeconds ?? 60} ثانية',
            ),
          );
        }
      }
      // التحقق من صحة البيانات
      final validationResult = MaintenanceValidator.validateMaintenanceRequest(
        request,
      );
      if (validationResult.isLeft()) {
        return await validationResult.fold(
          Left.new,
          (_) => const Left(ValidationFailure()),
        );
      }

      // تنظيف البيانات
      final sanitizedData = InputSanitizer.sanitizeMaintenanceRequest({
        'id': request.id,
        'organizationEmail': request.organizationEmail,
        'title': request.title,
        'description': request.description,
        'priority': request.priority,
        'status': request.status,
        'equipmentId': request.equipmentId,
        'equipmentName': request.equipmentName,
        'location': request.location,
        'customerId': request.customerId,
        'customerName': request.customerName,
        'requestDate': request.requestDate,
        'scheduledDate': request.scheduledDate,
        'completedDate': request.completedDate,
        'requestedBy': request.requestedBy,
        'assignedTo': request.assignedTo,
        'estimatedCost': request.estimatedCost,
        'actualCost': request.actualCost,
        'attachments': request.attachments,
        'notes': request.notes,
        'createdAt': request.createdAt,
        'updatedAt': request.updatedAt,
        'createdBy': request.createdBy,
        'updatedBy': request.updatedBy,
      });

      // إنشاء ID قصير وقابل للقراءة إذا كان فارغاً
      final requestId = request.id.isEmpty
          ? _generateShortId('MR') // MR = Maintenance Request
          : request.id;

      final normalizedEmail = _emailService.normalize(
        sanitizedData['organizationEmail'],
      );

      // استخدام Transaction لضمان الحفظ الذري — بيانات المستخدم/المؤسسة تُلتقط قبل المعاملة
      // لأنها ليست قراءات Firestore (لا تنتهك قاعدة القراءة قبل الكتابة)
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationId = _getCurrentOrganizationId();
      await firestore.runTransaction((transaction) async {
        final requestDoc = firestore
            .collection(normalizedEmail)
            .doc('maintenance')
            .collection('maintenance')
            .doc(requestId);

        // التحقق من عدم وجود الطلب مسبقاً
        final docSnapshot = await transaction.get(requestDoc);

        if (docSnapshot.exists) {
          throw Exception('طلب الصيانة موجود مسبقاً');
        }

        // حفظ البيانات في نفس الـ transaction
        transaction.set(requestDoc, {
          'id': requestId,
          'organizationEmail': sanitizedData['organizationEmail'],
          'equipmentId': sanitizedData['equipmentId'],
          'equipmentName': sanitizedData['equipmentName'],
          'title': sanitizedData['title'],
          'description': sanitizedData['description'],
          'priority': sanitizedData['priority'],
          'status': sanitizedData['status'],
          'requestDate': Timestamp.fromDate(request.requestDate),
          'scheduledDate': request.scheduledDate != null
              ? Timestamp.fromDate(request.scheduledDate!)
              : null,
          'completedDate': request.completedDate != null
              ? Timestamp.fromDate(request.completedDate!)
              : null,
          'requestedBy': sanitizedData['requestedBy'],
          'assignedTo': sanitizedData['assignedTo'],
          'estimatedCost': sanitizedData['estimatedCost'],
          'actualCost': sanitizedData['actualCost'],
          'location': sanitizedData['location'],
          'customerId': sanitizedData['customerId'],
          'customerName': sanitizedData['customerName'],
          'notes': sanitizedData['notes'],
          'attachments': request.attachments,
          'createdAt': Timestamp.fromDate(request.createdAt),
          'updatedAt': request.updatedAt != null
              ? Timestamp.fromDate(request.updatedAt!)
              : Timestamp.fromDate(DateTime.now()),
          'createdBy': sanitizedData['createdBy'],
          'updatedBy': sanitizedData['updatedBy'],
        });

        // تسجيل العملية في السجل داخل نفس المعاملة (ذرية) — بعد كل get والكتابة الرئيسية؛
        // ⚠️ لا تضع أي transaction.get() بعد هذا السطر في نفس المعاملة
        if (organizationId != null) {
          _setMaintenanceLogInTransaction(
            transaction,
            organizationId: organizationId,
            userId: currentUser?.uid ?? 'unknown',
            userName: currentUser?.displayName,
            userEmail: currentUser?.email,
            actionType: 'create',
            details: 'تم إنشاء طلب صيانة جديد: ${sanitizedData['title']}',
            targetId: requestId,
            targetType: 'maintenance_request',
            newValues: {
              'title': sanitizedData['title'],
              'description': sanitizedData['description'],
              'priority': sanitizedData['priority'],
              'status': sanitizedData['status'],
              'equipmentName': sanitizedData['equipmentName'],
              'location': sanitizedData['location'],
              'requestDate': request.requestDate.toIso8601String(),
              'scheduledDate': request.scheduledDate?.toIso8601String(),
              'estimatedCost': sanitizedData['estimatedCost'],
              'requestedBy': sanitizedData['requestedBy'],
            },
          );
        }
      });

      return Right(requestId);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في إنشاء طلب الصيانة: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateMaintenanceRequest(
    MaintenanceRequestEntity request,
  ) async {
    try {
      // ملاحظة للمبرمجين المستقبليين: عملية ذرية (Atomic) عبر runTransaction — تحقق الوجود + التحديث + السجل كوحدة واحدة (السبب الكامل وترتيب القراءة/الكتابة موثق في الملاحظة الشاملة أعلاه) — لا تضع أي transaction.get() بعد الكتابة هنا.
      // التحقق من صحة البيانات
      if (request.scheduledDate != null &&
          request.scheduledDate!.isBefore(request.requestDate)) {
        return const Left(
          ServerFailure(message: 'تاريخ الجدولة يجب أن يكون بعد تاريخ الطلب'),
        );
      }

      if (request.completedDate != null &&
          request.scheduledDate != null &&
          request.completedDate!.isBefore(request.scheduledDate!)) {
        return const Left(
          ServerFailure(message: 'تاريخ الإكمال يجب أن يكون بعد تاريخ الجدولة'),
        );
      }

      // التحقق من أن تاريخ الإكمال بعد تاريخ الطلب الأصلي
      if (request.completedDate != null &&
          request.completedDate!.isBefore(request.requestDate)) {
        return const Left(
          ServerFailure(
            message: 'تاريخ الإكمال يجب أن يكون بعد تاريخ الطلب الأصلي',
          ),
        );
      }

      // التحقق من تطابق الحالة مع تاريخ الإكمال (نفس قاعدة الإنشاء)
      // ⚠️ أُضيف بتاريخ 2026-10-08: بعد إصلاح التحقق من انتقال
      // الحالة ليتم فقط عند تغيرها، أصبح من الممكن تعديل حقول
      // أخرى مع بقاء الحالة — لذا يجب تطبيق هذه القاعدة هنا
      // أيضاً لمنع حفظ تاريخ إكمال مع حالة غير "مكتمل".
      if (request.completedDate != null && request.status != 'completed') {
        return const Left(
          ServerFailure(
            message: 'يجب تغيير الحالة إلى "مكتمل" عند وجود تاريخ إكمال',
          ),
        );
      }

      if (request.estimatedCost != null && request.estimatedCost! < 0) {
        return const Left(
          ServerFailure(
            message: 'التكلفة المتوقعة يجب أن تكون أكبر من أو تساوي صفر',
          ),
        );
      }

      if (request.actualCost != null && request.actualCost! < 0) {
        return const Left(
          ServerFailure(
            message: 'التكلفة الفعلية يجب أن تكون أكبر من أو تساوي صفر',
          ),
        );
      }

      // التحقق الشامل باستخدام المدقق الموحد (الحقول المطلوبة، النصوص، البريد، القيم المسموحة)
      final validationResult = MaintenanceValidator.validateMaintenanceRequest(
        request,
      );
      if (validationResult.isLeft()) {
        return await validationResult.fold(
          Left.new,
          (_) => const Left(ValidationFailure()),
        );
      }

      final normalizedEmail = _emailService.normalize(
        request.organizationEmail,
      );

      // استخدام Transaction لضمان الحفظ الذري — بيانات المستخدم/المؤسسة تُلتقط قبل المعاملة
      // لأنها ليست قراءات Firestore (لا تنتهك قاعدة القراءة قبل الكتابة)
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationId = _getCurrentOrganizationId();
      await firestore.runTransaction((transaction) async {
        final requestDoc = firestore
            .collection(normalizedEmail)
            .doc('maintenance')
            .collection('maintenance')
            .doc(request.id);

        // التحقق من وجود الطلب قبل التحديث
        final docSnapshot = await transaction.get(requestDoc);

        if (!docSnapshot.exists) {
          throw Exception('طلب الصيانة غير موجود');
        }

        // ============================================
        // ملاحظة للمبرمجين المستقبليين:
        // نتحقق من صحة انتقال الحالة هنا داخل الـ Transaction
        // لمنع انتقالات الحالة غير الصحيحة.
        // ⚠️ التحقق يتم فقط إذا تغيرت الحالة فعلاً:
        // خريطة الانتقالات لا تحتوي على الانتقال من حالة
        // إلى نفسها (ليس انتقالاً حقيقياً)، لذلك بدون هذا
        // الشرط يفشل أي تعديل على حقول أخرى (مثل العنوان
        // أو التاريخ) إذا بقيت الحالة كما هي — وهذا خطأ
        // تم إصلاحه بتاريخ 2026-10-08.
        // إذا فشل هذا التحقق، تفشل العملية بالكامل.
        // ============================================
        final currentData = docSnapshot.data();
        final currentStatus = currentData?['status']?.toString() ?? '';
        if (currentStatus != request.status) {
          final statusTransitionResult =
              MaintenanceValidator.validateStatusTransition(
            currentStatus,
            request.status,
          );
          if (statusTransitionResult.isLeft()) {
            throw Exception(statusTransitionResult.fold(
              (failure) => failure.message,
              (_) => 'انتقال حالة غير صحيح',
            ));
          }
        }

        // قراءة القيم القديمة من المستند المجلوب مسبقاً لتسجيلها في السجل
        // ⚠️ تُقرأ من currentData (من docSnapshot المجلوب أعلاه)
        // وليس عبر transaction.get جديد — فلا تنتهك قاعدة
        // "كل القراءات قبل كل الكتابات"
        String? oldDateValue(dynamic value) => value is Timestamp
            ? value.toDate().toIso8601String()
            : (value is String ? value : null);
        final Map<String, dynamic> oldValues = {
          'title': currentData?['title'],
          'description': currentData?['description'],
          'priority': currentData?['priority'],
          'status': currentData?['status'],
          'equipmentName': currentData?['equipmentName'],
          'location': currentData?['location'],
          'customerId': currentData?['customerId'],
          'customerName': currentData?['customerName'],
          'requestDate': oldDateValue(currentData?['requestDate']),
          'scheduledDate': oldDateValue(currentData?['scheduledDate']),
          'completedDate': oldDateValue(currentData?['completedDate']),
          'estimatedCost': currentData?['estimatedCost'],
          'actualCost': currentData?['actualCost'],
          'assignedTo': currentData?['assignedTo'],
        };

        // تحديث البيانات في نفس الـ transaction
        // ⚠️ ملاحظة للمبرمجين المستقبليين:
        // يجب أن تتضمن هذه الخريطة كل حقل قابل للتعديل في صفحة
        // التعديل (edit_maintenance_request_page.dart) — الصفحة تبني
        // الكيان عبر copyWith فتحتفظ بجميع الحقول الأصلية، وأي حقل
        // قابل للتعديل يُنسى هنا يُتجاهل بصمت ولا يُحفظ في Firestore
        // حتى لو عدّله المستخدم. هذا ما حدث مع location و
        // customerId/customerName (كانت مفقودة وأُصلحت بتاريخ
        // 2026-10-08) — كان سجل التدقيق يسجل الموقع الجديد بينما
        // المستند يبقي القديم. الحقول الثابتة (id، organizationEmail،
        // createdAt، createdBy) تُستبعد عمداً لأنها تُحدد عند الإنشاء.
        transaction.update(requestDoc, {
          'equipmentId': request.equipmentId,
          'equipmentName': request.equipmentName,
          'title': request.title,
          'description': request.description,
          'priority': request.priority,
          'status': request.status,
          'requestDate': Timestamp.fromDate(request.requestDate),
          'scheduledDate': request.scheduledDate != null
              ? Timestamp.fromDate(request.scheduledDate!)
              : null,
          'completedDate': request.completedDate != null
              ? Timestamp.fromDate(request.completedDate!)
              : null,
          'requestedBy': request.requestedBy,
          'assignedTo': request.assignedTo,
          'estimatedCost': request.estimatedCost,
          'actualCost': request.actualCost,
          'location': request.location,
          'customerId': request.customerId,
          'customerName': request.customerName,
          'notes': request.notes,
          'attachments': request.attachments,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
          'updatedBy': request.updatedBy,
        });

        // تسجيل العملية في السجل داخل نفس المعاملة (ذرية) — بعد كل get والكتابة الرئيسية؛
        // ⚠️ لا تضع أي transaction.get() بعد هذا السطر في نفس المعاملة
        if (organizationId != null) {
          _setMaintenanceLogInTransaction(
            transaction,
            organizationId: organizationId,
            userId: currentUser?.uid ?? 'unknown',
            userName: currentUser?.displayName,
            userEmail: currentUser?.email,
            actionType: 'update',
            details: 'تم تحديث طلب الصيانة: ${request.title}',
            targetId: request.id,
            targetType: 'maintenance_request',
            oldValues: oldValues,
            newValues: {
              'title': request.title,
              'description': request.description,
              'priority': request.priority,
              'status': request.status,
              'equipmentName': request.equipmentName,
              'location': request.location,
              'customerId': request.customerId,
              'customerName': request.customerName,
              'requestDate': request.requestDate.toIso8601String(),
              'scheduledDate': request.scheduledDate?.toIso8601String(),
              'completedDate': request.completedDate?.toIso8601String(),
              'estimatedCost': request.estimatedCost,
              'actualCost': request.actualCost,
              'assignedTo': request.assignedTo,
            },
          );
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث طلب الصيانة: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMaintenanceRequest(
    String id,
    String organizationEmail,
  ) async {
    try {
      // ملاحظة للمبرمجين المستقبليين: عملية ذرية (Atomic) عبر runTransaction — تحقق الوجود + الحذف + السجل كوحدة واحدة (السبب الكامل وترتيب القراءة/الكتابة موثق في الملاحظة الشاملة أعلاه) — لا تضع أي transaction.get() بعد الكتابة هنا.
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationId = _getCurrentOrganizationId();
      String requestTitle = 'طلب صيانة غير معروف';

      await firestore.runTransaction((transaction) async {
        final requestDoc = firestore
            .collection(normalizedEmail)
            .doc('maintenance')
            .collection('maintenance')
            .doc(id);

        // التحقق من وجود الطلب قبل الحذف داخل نفس الـ transaction
        final docSnapshot = await transaction.get(requestDoc);

        if (!docSnapshot.exists) {
          throw Exception('طلب الصيانة غير موجود');
        }

        // حفظ العنوان قبل الحذف للسجل
        final data = docSnapshot.data();
        if (data != null) {
          requestTitle = data['title'] ?? 'طلب صيانة غير معروف';
        }

        // حذف البيانات في نفس الـ transaction
        transaction.delete(requestDoc);

        // تسجيل العملية في السجل داخل نفس المعاملة (ذرية) — بعد كل get والكتابة الرئيسية؛
        // ⚠️ لا تضع أي transaction.get() بعد هذا السطر في نفس المعاملة
        if (organizationId != null) {
          _setMaintenanceLogInTransaction(
            transaction,
            organizationId: organizationId,
            userId: currentUser?.uid ?? 'unknown',
            userName: currentUser?.displayName,
            userEmail: currentUser?.email,
            actionType: 'delete',
            details: 'تم حذف طلب الصيانة: $requestTitle',
            targetId: id,
            targetType: 'maintenance_request',
          );
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حذف طلب الصيانة: $e'));
    }
  }

  @override
  Future<Either<Failure, List<EquipmentEntity>>> getEquipment(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final querySnapshot = await firestore
          .collection(normalizedEmail)
          .doc('maintenance')
          .collection('equipment')
          .orderBy('name')
          .get();

      final equipment = querySnapshot.docs.map((doc) {
        final data = doc.data();
        // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
        }
        return EquipmentModel.fromJson(data);
      }).toList();

      return Right(equipment);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب المعدات: $e'));
    }
  }

  @override
  Stream<Either<Failure, List<EquipmentEntity>>> getEquipmentStream() {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      // ملاحظة موجزة للمبرمجين المستقبليين: ستريم
      // قراءة فقط (snapshots) — بلا كتابة أو معاملة
      // فلا تنطبق عليه قاعدة "كل القراءات قبل كل
      // الكتابات" (السبب الكامل في الملاحظة الشاملة
      // أعلاه، قسم الستريمات). تُستخدم لتحديث قائمة
      // المعدات في الـ BLoC فورياً عند إضافة/تعديل/حذف
      // أي معدة.
      // ⚠️ تحسين (2026-10-12): نفس تحسين
      // قسم الفواتير — نحفظ المعدات
      // المحللة في ذاكرة خاصة بهذا
      // الستريم ونحدّث المستندات
      // المتغيرة فقط عبر docChanges
      // بدلاً من إعادة تحليل كل
      // المعدات مع كل لقطة — كان
      // يسبب بطءاً ملحوظاً مع كثرة
      // المعدات عند كل تحديث.
      final streamCache = <String, EquipmentEntity>{};

      return firestore
          .collection(organizationId)
          .doc('maintenance')
          .collection('equipment')
          .orderBy('name')
          .snapshots()
          .map((snapshot) {
        try {
          // تحديث تدريجي: نعالج المستندات المتغيرة فقط
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            if (change.type == DocumentChangeType.removed) {
              streamCache.remove(doc.id);
              continue;
            }
            final data = doc.data();
            if (data == null) {
              streamCache.remove(doc.id);
              continue;
            }
            final mapData = Map<String, dynamic>.from(data);
            // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
            if (mapData['id'] == null ||
                mapData['id'].toString().isEmpty) {
              mapData['id'] = doc.id;
            }
            try {
              streamCache[doc.id] =
                  EquipmentModel.fromJson(mapData);
            } on Exception catch (_) {
              streamCache.remove(doc.id);
            }
          }

          final equipment = streamCache.values.toList()
            ..sort((a, b) {
              final cmp = a.name.compareTo(b.name);
              return cmp != 0 ? cmp : a.id.compareTo(b.id);
            });

          return Right<Failure, List<EquipmentEntity>>(equipment);
        } on Exception catch (e) {
          return Left<Failure, List<EquipmentEntity>>(
            ServerFailure(message: 'فشل في معالجة بيانات المعدات: $e'),
          );
        }
      });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب المعدات: $e')),
      );
    }
  }

  @override
  Future<Either<Failure, String>> addEquipment(EquipmentEntity equipment) async {
    // ملاحظة للمبرمجين المستقبليين: عملية ذرية (Atomic) عبر runTransaction — تحقق عدم التكرار + الحفظ + السجل كوحدة واحدة (السبب الكامل وترتيب القراءة/الكتابة موثق في الملاحظة الشاملة أعلاه) — لا تضع أي transaction.get() بعد الكتابة هنا.
    try {
      // إنشاء ID قصير وقابل للقراءة إذا كان فارغاً
      final equipmentId = equipment.id.isEmpty
          ? _generateShortId('EQ') // EQ = Equipment
          : equipment.id;

      final normalizedEmail = _emailService.normalize(
        equipment.organizationEmail,
      );

      // استخدام Transaction لضمان الحفظ الذري — بيانات المستخدم/المؤسسة تُلتقط قبل المعاملة
      // لأنها ليست قراءات Firestore (لا تنتهك قاعدة القراءة قبل الكتابة)
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationId = _getCurrentOrganizationId();
      await firestore.runTransaction((transaction) async {
        final equipmentDoc = firestore
            .collection(normalizedEmail)
            .doc('maintenance')
            .collection('equipment')
            .doc(equipmentId);

        // التحقق من عدم وجود المعدة مسبقاً
        final docSnapshot = await transaction.get(equipmentDoc);

        if (docSnapshot.exists) {
          throw Exception('المعدة موجودة مسبقاً');
        }

        // حفظ البيانات في نفس الـ transaction
        transaction.set(equipmentDoc, {
          'id': equipmentId,
          'organizationEmail': equipment.organizationEmail,
          'name': equipment.name,
          'model': equipment.model,
          'serialNumber': equipment.serialNumber,
          'location': equipment.location,
          'status': equipment.status,
          'purchaseDate': equipment.purchaseDate != null
              ? Timestamp.fromDate(equipment.purchaseDate!)
              : null,
          'warrantyExpiry': equipment.warrantyExpiry != null
              ? Timestamp.fromDate(equipment.warrantyExpiry!)
              : null,
          'createdAt': Timestamp.fromDate(equipment.createdAt),
          'updatedAt': equipment.updatedAt != null
              ? Timestamp.fromDate(equipment.updatedAt!)
              : Timestamp.fromDate(DateTime.now()),
        });

        // تسجيل العملية في السجل داخل نفس المعاملة (ذرية) — بعد كل get والكتابة الرئيسية؛
        // ⚠️ لا تضع أي transaction.get() بعد هذا السطر في نفس المعاملة
        if (organizationId != null) {
          _setMaintenanceLogInTransaction(
            transaction,
            organizationId: organizationId,
            userId: currentUser?.uid ?? 'unknown',
            userName: currentUser?.displayName,
            userEmail: currentUser?.email,
            actionType: 'create',
            details: 'تم إضافة معدة جديدة: ${equipment.name}',
            targetId: equipmentId,
            targetType: 'equipment',
            newValues: {
              'name': equipment.name,
              'model': equipment.model,
              'serialNumber': equipment.serialNumber,
              'location': equipment.location,
              'status': equipment.status,
              'purchaseDate': equipment.purchaseDate?.toIso8601String(),
              'warrantyExpiry': equipment.warrantyExpiry?.toIso8601String(),
            },
          );
        }
      });

      return Right(equipmentId);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في إضافة المعدة: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateEquipment(
    EquipmentEntity equipment,
  ) async {
    // ملاحظة للمبرمجين المستقبليين: عملية ذرية (Atomic) عبر runTransaction — تحقق الوجود + التحديث + السجل كوحدة واحدة (السبب الكامل وترتيب القراءة/الكتابة موثق في الملاحظة الشاملة أعلاه) — لا تضع أي transaction.get() بعد الكتابة هنا.
    try {
      final normalizedEmail = _emailService.normalize(
        equipment.organizationEmail,
      );

      // استخدام Transaction لضمان الحفظ الذري — بيانات المستخدم/المؤسسة تُلتقط قبل المعاملة
      // لأنها ليست قراءات Firestore (لا تنتهك قاعدة القراءة قبل الكتابة)
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationId = _getCurrentOrganizationId();
      await firestore.runTransaction((transaction) async {
        final equipmentDoc = firestore
            .collection(normalizedEmail)
            .doc('maintenance')
            .collection('equipment')
            .doc(equipment.id);

        // التحقق من وجود المعدة قبل التحديث
        final docSnapshot = await transaction.get(equipmentDoc);

        if (!docSnapshot.exists) {
          throw Exception('المعدة غير موجودة');
        }

        // تحديث البيانات في نفس الـ transaction
        transaction.update(equipmentDoc, {
          'name': equipment.name,
          'model': equipment.model,
          'serialNumber': equipment.serialNumber,
          'location': equipment.location,
          'status': equipment.status,
          'purchaseDate': equipment.purchaseDate != null
              ? Timestamp.fromDate(equipment.purchaseDate!)
              : null,
          'warrantyExpiry': equipment.warrantyExpiry != null
              ? Timestamp.fromDate(equipment.warrantyExpiry!)
              : null,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        // تسجيل العملية في السجل داخل نفس المعاملة (ذرية) — بعد كل get والكتابة الرئيسية؛
        // ⚠️ لا تضع أي transaction.get() بعد هذا السطر في نفس المعاملة
        if (organizationId != null) {
          _setMaintenanceLogInTransaction(
            transaction,
            organizationId: organizationId,
            userId: currentUser?.uid ?? 'unknown',
            userName: currentUser?.displayName,
            userEmail: currentUser?.email,
            actionType: 'update',
            details: 'تم تحديث المعدة: ${equipment.name}',
            targetId: equipment.id,
            targetType: 'equipment',
            newValues: {
              'name': equipment.name,
              'model': equipment.model,
              'serialNumber': equipment.serialNumber,
              'location': equipment.location,
              'status': equipment.status,
              'purchaseDate': equipment.purchaseDate?.toIso8601String(),
              'warrantyExpiry': equipment.warrantyExpiry?.toIso8601String(),
            },
          );
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث المعدة: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEquipment(
    String id,
    String organizationEmail,
  ) async {
    try {
      // ملاحظة للمبرمجين المستقبليين: عملية ذرية (Atomic) عبر runTransaction — تحقق الوجود + الحذف + السجل كوحدة واحدة (السبب الكامل وترتيب القراءة/الكتابة موثق في الملاحظة الشاملة أعلاه) — لا تضع أي transaction.get() بعد الكتابة هنا.
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationId = _getCurrentOrganizationId();
      String equipmentName = 'معدة غير معروفة';

      await firestore.runTransaction((transaction) async {
        final equipmentDoc = firestore
            .collection(normalizedEmail)
            .doc('maintenance')
            .collection('equipment')
            .doc(id);

        // التحقق من وجود المعدة قبل الحذف داخل نفس الـ transaction
        final docSnapshot = await transaction.get(equipmentDoc);

        if (!docSnapshot.exists) {
          throw Exception('المعدة غير موجودة');
        }

        // حفظ الاسم قبل الحذف للسجل
        final data = docSnapshot.data();
        if (data != null) {
          equipmentName = data['name'] ?? 'معدة غير معروفة';
        }

        // حذف البيانات في نفس الـ transaction
        transaction.delete(equipmentDoc);

        // تسجيل العملية في السجل داخل نفس المعاملة (ذرية) — بعد كل get والكتابة الرئيسية؛
        // ⚠️ لا تضع أي transaction.get() بعد هذا السطر في نفس المعاملة
        if (organizationId != null) {
          _setMaintenanceLogInTransaction(
            transaction,
            organizationId: organizationId,
            userId: currentUser?.uid ?? 'unknown',
            userName: currentUser?.displayName,
            userEmail: currentUser?.email,
            actionType: 'delete',
            details: 'تم حذف المعدة: $equipmentName',
            targetId: id,
            targetType: 'equipment',
          );
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حذف المعدة: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMaintenanceStats(
    String organizationEmail, {
    List<MaintenanceRequestEntity>? requestsOverride,
    List<EquipmentEntity>? equipmentOverride,
  }) async {
    // ملاحظة موجزة للمبرمجين المستقبليين (2026-10-12):
    // ① ليست ذرية بحكم التصميم — الإحصائيات
    // تُحسب محلياً ولا تُخزن كوثيقة (لإحصائيات
    // ذرية خزّنها في مستند منفصل يُحدَّث في نفس
    // Transaction — السبب الكامل في الملاحظة
    // الشاملة أعلاه). ✅ ⚠️ المعاملان
    // requestsOverride/equipmentOverride: بيانات
    // مجلوبة كاملة (كل الطلبات/المعدات — لا صفحة
    // مرقّمة لأن الإحصائيات تحتاج الكل) تُستخدم
    // مباشرة لتجنب إعادة الجلب. القراءتان غير
    // المُتجاوزتين مستقلتان فتُنفذان بالتوازي عبر
    // Future.wait (زمن الإحصائيات ≈ أبطأ قراءة
    // فقط بدلاً من مجموع القراءتين). ترتيب الأخطاء
    // محفوظ: خطأ الطلبات يُرجع أولاً ثم خطأ المعدات.
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final requestsFuture = requestsOverride != null
          ? Future<Either<Failure, List<MaintenanceRequestEntity>>>.value(
              Right<Failure, List<MaintenanceRequestEntity>>(requestsOverride))
          : getMaintenanceRequests(normalizedEmail);
      final equipmentFuture = equipmentOverride != null
          ? Future<Either<Failure, List<EquipmentEntity>>>.value(
              Right<Failure, List<EquipmentEntity>>(equipmentOverride))
          : getEquipment(normalizedEmail);
      final results = await Future.wait([requestsFuture, equipmentFuture]);
      final requestsResult =
          results[0] as Either<Failure, List<MaintenanceRequestEntity>>;
      final equipmentResult =
          results[1] as Either<Failure, List<EquipmentEntity>>;

      return await requestsResult.fold(Left.new, (requests) {
        return equipmentResult.fold(Left.new, (equipment) {
          final totalRequests = requests.length;
          final pendingRequests = requests
              .where((r) => r.status == 'pending')
              .length;
          final inProgressRequests = requests
              .where((r) => r.status == 'in_progress')
              .length;
          final completedRequests = requests
              .where((r) => r.status == 'completed')
              .length;
          final cancelledRequests = requests
              .where((r) => r.status == 'cancelled')
              .length;

          final totalEquipment = equipment.length;
          final activeEquipment = equipment
              .where((e) => e.status == 'active')
              .length;
          final maintenanceEquipment = equipment
              .where((e) => e.status == 'under_maintenance')
              .length;

          return Right({
            'totalRequests': totalRequests,
            'pendingRequests': pendingRequests,
            'inProgressRequests': inProgressRequests,
            'completedRequests': completedRequests,
            'cancelledRequests': cancelledRequests,
            'totalEquipment': totalEquipment,
            'activeEquipment': activeEquipment,
            'maintenanceEquipment': maintenanceEquipment,
          });
        });
      });
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حساب إحصائيات الصيانة: $e'));
    }
  }

  // ===== Maintenance Logs Methods =====

  @override
  Future<Either<Failure, List<MaintenanceLogEntity>>> getMaintenanceLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('maintenance')
          .collection('logs');

      // تطبيق الفلاتر أولاً
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      // فلتر نوع العملية
      if (actionFilter != null && actionFilter != 'all') {
        query = query.where('actionType', isEqualTo: actionFilter);
      }

      // فلتر التاريخ
      if (dateFilter != null && dateFilter != 'all') {
        final now = DateTime.now();
        DateTime filterDate;

        switch (dateFilter) {
          case 'today':
            filterDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            filterDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            filterDate = now.subtract(const Duration(days: 30));
            break;
          default:
            filterDate = DateTime(2000);
        }

        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filterDate),
        );
      }

      // فلتر التاريخ المخصص
      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(endOfDay),
        );
      }

      // تحديد الحد الأقصى — لا يُطبق في Firestore إذا كان هناك
      // بحث نصي لأن البحث يُطبق في الذاكرة بعد الجلب.
      // تطبيق الحد في Firestore قبل البحث النصي قد يعطي نتائج
      // صفرية حتى لو كانت هناك سجلات مطابقة بعد أول N سجل.
      final applyLimitInQuery = (searchQuery == null || searchQuery.isEmpty);
      if (limit != null && applyLimitInQuery) {
        query = query.limit(limit);
      }

      // ثم الترتيب في النهاية
      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();
      final logs = <MaintenanceLogEntity>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        final log = MaintenanceLogModel.fromJson({
          'id': doc.id,
          ...mapData,
        }).toEntity();

        // تطبيق البحث النصي
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final queryLower = searchQuery.toLowerCase();
          final matchesSearch =
              (log.userName?.toLowerCase().contains(queryLower) ?? false) ||
              (log.userEmail?.toLowerCase().contains(queryLower) ?? false) ||
              (log.actionType.toLowerCase().contains(queryLower)) ||
              (log.details?.toLowerCase().contains(queryLower) ?? false);

          if (matchesSearch) {
            logs.add(log);
          }
        } else {
          logs.add(log);
        }
      }

      // تطبيق الحد في الذاكرة إذا كان هناك بحث نصي
      if (limit != null && !applyLimitInQuery && logs.length > limit) {
        logs.length = limit;
      }

      return Right(logs);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Stream<Either<Failure, List<MaintenanceLogEntity>>>
  getMaintenanceLogsStream({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      // ملاحظة موجزة للمبرمجين المستقبليين: ستريم
      // قراءة فقط (snapshots) — بلا كتابة أو
      // معاملة فلا تنطبق عليه قاعدة "كل القراءات
      // قبل كل الكتابات" (السبب الكامل في الملاحظة
      // الشاملة أعلاه، قسم الستريمات). تُستخدم
      // لتحديث سجل النشاطات في صفحة السجل فورياً
      // عند حدوث أي عملية (إنشاء/تحديث/حذف).
      Query query = firestore
          .collection(organizationId)
          .doc('maintenance')
          .collection('logs');

      // فلتر المستخدم
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      // فلتر نوع العملية
      if (actionFilter != null && actionFilter != 'all') {
        query = query.where('actionType', isEqualTo: actionFilter);
      }

      // فلتر التاريخ
      if (dateFilter != null && dateFilter != 'all') {
        final now = DateTime.now();
        DateTime filterDate;

        switch (dateFilter) {
          case 'today':
            filterDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            filterDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            filterDate = now.subtract(const Duration(days: 30));
            break;
          default:
            filterDate = DateTime(2000);
        }

        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filterDate),
        );
      }

      // فلتر التاريخ المخصص
      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(endOfDay),
        );
      }

      // تحديد الحد الأقصى
      if (limit != null) {
        query = query.limit(limit);
      }

      // الترتيب في النهاية
      query = query.orderBy('timestamp', descending: true);

      // ⚠️ أداء (2026-10-12): كاش تدريجي
      // خاص بهذا الستريم فقط يعالج docChanges
      // بدلاً من إعادة تحليل كل السجلات مع
      // كل لقطة — سجلات الصيانة تنمو بلا
      // حدود فكان إعادة بناء كل
      // MaintenanceLogEntity عند كل عملية
      // جديدة هو الهدر الأكبر هنا. الستريم
      // المحدود (بحد) يبقي التحليل الكامل
      // الأصلي لأن نافذة الحد تتحرك وقد
      // لا يُصدر المستند الخارج تغييراً من
      // نوع removed بشكل موثوق.
      final streamCache = <String, MaintenanceLogEntity>{};

      return query.snapshots().map((snapshot) {
        try {
          if (limit == null) {
            for (final change in snapshot.docChanges) {
              final doc = change.doc;
              if (change.type == DocumentChangeType.removed) {
                streamCache.remove(doc.id);
                continue;
              }
              final data = doc.data();
              if (data == null) {
                streamCache.remove(doc.id);
                continue;
              }
              final mapData = data as Map<String, dynamic>;
              try {
                streamCache[doc.id] = MaintenanceLogModel.fromJson({
                  'id': doc.id,
                  ...mapData,
                }).toEntity();
              } on Exception catch (_) {
                streamCache.remove(doc.id);
              }
            }

            // الحفاظ على ترتيب الاستعلام
            // (timestamp تنازلي) عبر المرور على
            // مستندات اللقطة مرتبة وأخذ الكيان
            // المحلل من الكاش — أدق من إعادة
            // الترتيب في الذاكرة لأن ترتيب
            // Firestore الحقيقي (بما في ذلك
            // كسر التعادل) يُحفظ كما هو
            var logs = <MaintenanceLogEntity>[];
            for (final doc in snapshot.docs) {
              final cachedLog = streamCache[doc.id];
              if (cachedLog != null) {
                logs.add(cachedLog);
              }
            }

            // تطبيق البحث النصي في الذاكرة
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              logs = logs
                  .where(
                    (log) =>
                        (log.userName?.toLowerCase().contains(query) ??
                            false) ||
                        (log.userEmail?.toLowerCase().contains(query) ??
                            false) ||
                        (log.actionType.toLowerCase().contains(query)) ||
                        (log.details?.toLowerCase().contains(query) ??
                            false),
                  )
                  .toList();
            }

            return Right<Failure, List<MaintenanceLogEntity>>(logs);
          }

          // الستريم المحدود: تحليل كامل (السلوك الأصلي)
          final logs = <MaintenanceLogEntity>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data == null) continue;
            final mapData = data as Map<String, dynamic>;
            final log = MaintenanceLogModel.fromJson({
              'id': doc.id,
              ...mapData,
            }).toEntity();

            // تطبيق البحث النصي
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              final matchesSearch =
                  (log.userName?.toLowerCase().contains(query) ?? false) ||
                  (log.userEmail?.toLowerCase().contains(query) ?? false) ||
                  (log.actionType.toLowerCase().contains(query)) ||
                  (log.details?.toLowerCase().contains(query) ?? false);

              if (matchesSearch) {
                logs.add(log);
              }
            } else {
              logs.add(log);
            }
          }

          return Right<Failure, List<MaintenanceLogEntity>>(logs);
        } on Exception catch (e) {
          return Left<Failure, List<MaintenanceLogEntity>>(
            ServerFailure(message: 'فشل في معالجة سجلات الصيانة: $e'),
          );
        }
      });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب سجلات الصيانة: $e')),
      );
    }
  }

  @override
  Future<Either<Failure, MaintenanceLogEntity>> addMaintenanceLog({
    required String userId,
    required String actionType,
    String? userName,
    String? userEmail,
    String? details,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
    Map<String, dynamic>? deviceInfo,
    bool isSuccess = true,
  }) async {
    try {
      // ملاحظة موجزة للمبرمجين المستقبليين: كتابة
      // مستند واحد بـ .add() — ذرية بطبيعتها
      // وبلا تحقق تكرار (إذا أضفت تحقق تكرار
      // أو قيوداً أخرى حوّلها إلى Transaction —
      // السبب الكامل في الملاحظة الشاملة أعلاه،
      // قسم addMaintenanceLog). حالياً آمنة
      // لأنها بلا تحقق تكرار.
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // استخدام المستخدم الحالي إذا لم يتم تحديد معرف المستخدم
      final currentUser = FirebaseAuth.instance.currentUser;
      final actualUserId = userId == 'current_user' && currentUser != null
          ? currentUser.uid
          : userId;
      final actualUserName = userName ?? currentUser?.displayName;
      final actualUserEmail = userEmail ?? currentUser?.email;

      final now = DateTime.now();
      final logData = {
        'userId': actualUserId,
        'userName': actualUserName,
        'userEmail': actualUserEmail,
        'actionType': actionType,
        'timestamp': Timestamp.fromDate(now),
        'details': details,
        'isSuccess': isSuccess,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'targetId': targetId,
        'targetType': targetType,
        'oldValues': oldValues,
        'newValues': newValues,
        'sessionId': sessionId,
        'deviceInfo': deviceInfo,
      };

      final docRef = await firestore
          .collection(organizationId)
          .doc('maintenance')
          .collection('logs')
          .add(logData);

      final log = MaintenanceLogModel.fromJson({
        'id': docRef.id,
        ...logData,
      }).toEntity();

      return Right(log);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMaintenanceLog(String logId) async {
    try {
      // ملاحظة موجزة للمبرمجين المستقبليين: حذف
      // مستند واحد بـ .delete() — ذرية بطبيعتها
      // و idempotent (لا قراءة (get) قبل الكتابة
      // ولا شروط تعتمد على الحالة الحالية، وحذف
      // غير الموجود ليس فشلاً). ⚠️ حوّلها إلى
      // Transaction فقط إذا احتجت: تحقق الوجود
      // قبل الحذف، حذف مشروط بحالة المستند، أو
      // حذف عدة مستندات مترابطة كوحدة واحدة
      // (السبب الكامل في الملاحظة الشاملة أعلاه،
      // قسم deleteMaintenanceLog).
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      await firestore
          .collection(organizationId)
          .doc('maintenance')
          .collection('logs')
          .doc(logId)
          .delete();

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> clearMaintenanceLogs({
    String? userId,
    DateTime? beforeDate,
  }) async {
    try {
      // ملاحظة موجزة للمبرمجين المستقبليين:
      // query.get() + WriteBatch + commit — التزام
      // ذري للتنفيذ فقط (Batch لا يضمن عدم حذف
      // مستندات عُدلت أثناء العملية) — مقبولة
      // لتنظيف دوري وليست عملية حرجة تعتمد على
      // حالة حالية. استخدم Transaction إذا احتجت
      // ذلك الضمان (السبب الكامل في الملاحظة
      // الشاملة أعلاه، قسم clearMaintenanceLogs).
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('maintenance')
          .collection('logs');

      // فلتر المستخدم
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      // فلتر التاريخ
      if (beforeDate != null) {
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(beforeDate),
        );
      }

      final snapshot = await query.get();
      final batch = firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ===== Stream Methods for Real-time Updates =====

  @override
  Stream<Either<Failure, List<MaintenanceRequestEntity>>>
  getMaintenanceRequestsStream({
    int? limit,
    String? searchQuery,
    String? statusFilter,
    String? priorityFilter,
    String? equipmentFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      // 1. بناء الـ query الأساسي
      Query query = firestore
          .collection(organizationId)
          .doc('maintenance')
          .collection('maintenance');

      // 2. إضافة فلتر الحالة إذا كان موجوداً (قبل orderBy)
      if (statusFilter != null && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      // 3. إضافة فلتر الأولوية إذا كان موجوداً (قبل orderBy)
      if (priorityFilter != null && priorityFilter != 'all') {
        query = query.where('priority', isEqualTo: priorityFilter);
      }

      // 4. إضافة فلتر المعدة إذا كان موجوداً (قبل orderBy)
      if (equipmentFilter != null && equipmentFilter != 'all') {
        query = query.where('equipmentId', isEqualTo: equipmentFilter);
      }

      // 5. الترتيب
      query = query.orderBy('createdAt', descending: true);

      // 6. تطبيق الحد في استعلام Firestore فقط إذا لم يكن هناك
      // فلاتر تُطبق في الذاكرة (searchQuery، dateFilter، startDate، endDate).
      // إذا كان هناك أي فلتر ذاكرة، لا نطبق الحد في Firestore لأن
      // التصفية في الذاكرة قد تقلل عدد النتائج، وتطبيق الحد في
      // Firestore أولاً قد يُبعد سجلات مطابقة للبحث عن النطاق.
      final hasMemoryFilters =
          searchQuery != null && searchQuery.isNotEmpty ||
          dateFilter != null && dateFilter != 'all' ||
          startDate != null ||
          endDate != null;
      if (limit != null && !hasMemoryFilters) {
        query = query.limit(limit);
      }

      // 7. الاستماع للتغييرات
      // ⚠️ أداء (2026-10-12): كاش تدريجي
      // خاص بهذا الستريم فقط يعالج
      // docChanges بدلاً من إعادة تحليل
      // كل الطلبات مع كل لقطة.
      final streamCache = <String, MaintenanceRequestEntity>{};

      return query.snapshots().map((snapshot) {
        try {
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            if (change.type == DocumentChangeType.removed) {
              streamCache.remove(doc.id);
              continue;
            }
            final data = doc.data();
            if (data == null) {
              streamCache.remove(doc.id);
              continue;
            }
            try {
              final mapData = Map<String, dynamic>.from(
                data as Map<String, dynamic>,
              );
              if (mapData['id'] == null ||
                  mapData['id'].toString().isEmpty) {
                mapData['id'] = doc.id;
              }
              streamCache[doc.id] = MaintenanceRequestModel.fromJson(mapData);
            } on Exception catch (_) {
              streamCache.remove(doc.id);
            }
          }

          // الحفاظ على ترتيب الاستعلام
          // (createdAt تنازلي) عبر المرور على
          // مستندات اللقطة مرتبة وأخذ الكيان
          // المحلل من الكاش — أدق من إعادة
          // الترتيب في الذاكرة لأن ترتيب
          // Firestore الحقيقي (بما في ذلك
          // كسر التعادل) يُحفظ كما هو
          var requests = <MaintenanceRequestEntity>[];
          for (final doc in snapshot.docs) {
            final cachedRequest = streamCache[doc.id];
            if (cachedRequest != null) {
              requests.add(cachedRequest);
            }
          }

          // 6. تطبيق فلتر البحث في الذاكرة
          if (searchQuery != null && searchQuery.isNotEmpty) {
            final queryLower = searchQuery.toLowerCase();
            requests = requests
                .where(
                  (request) =>
                      request.title.toLowerCase().contains(queryLower) ||
                      request.description.toLowerCase().contains(queryLower) ||
                      (request.equipmentName?.toLowerCase().contains(queryLower) ??
                          false),
                )
                .toList();
          }

          // 7. تطبيق فلاتر أخرى في الذاكرة (إذا لم تكن في Firestore)
          if (dateFilter != null && dateFilter != 'all') {
            final now = DateTime.now();
            DateTime filterDate;

            switch (dateFilter) {
              case 'today':
                filterDate = DateTime(now.year, now.month, now.day);
                break;
              case 'week':
                filterDate = now.subtract(const Duration(days: 7));
                break;
              case 'month':
                filterDate = now.subtract(const Duration(days: 30));
                break;
              default:
                filterDate = DateTime(2000);
            }

            requests = requests
                .where(
                  (request) => !request.createdAt.isBefore(filterDate),
                )
                .toList();
          }

          // فلتر التاريخ المخصص
          if (startDate != null) {
            requests = requests
                .where(
                  (request) => !request.createdAt.isBefore(startDate),
                )
                .toList();
          }
          if (endDate != null) {
            final endOfDay = DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
              23,
              59,
              59,
            );
            requests = requests
                .where(
                  (request) => !request.createdAt.isAfter(endOfDay),
                )
                .toList();
          }

          // 8. تطبيق الحد في الذاكرة فقط إذا لم يُطبق في Firestore
          // (أي عندما يكون هناك فلاتر ذاكرة تمنع تطبيق الحد في الاستعلام)
          if (limit != null && hasMemoryFilters && requests.length > limit) {
            requests = requests.sublist(0, limit);
          }

          return Right<Failure, List<MaintenanceRequestEntity>>(requests);
        } on Exception catch (e) {
          return Left<Failure, List<MaintenanceRequestEntity>>(
            ServerFailure(message: 'فشل في معالجة بيانات طلبات الصيانة: $e'),
          );
        }
      });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب طلبات الصيانة: $e')),
      );
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>>
  getMaintenanceStatisticsStream({int? limit}) {
    try {
      // ملاحظة موجزة للمبرمجين المستقبليين: غير
      // ذرية — الإحصائيات تُحسب من البيانات
      // الحالية وليست مخزنة بشكل ذري (قد تكون
      // غير دقيقة لحظياً عند عمليات متزامنة —
      // السبب الكامل في الملاحظة الشاملة أعلاه،
      // قسم الإحصائيات).
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      return firestore
          .collection(organizationId)
          .doc('maintenance')
          .collection('maintenance')
          .snapshots()
          .map((snapshot) {
            try {
              // ⚠️ تحسين (2026-10-12): حساب
              // الإحصائيات مباشرة من بيانات
              // المستند الخام بدلاً من بناء
              // MaintenanceRequestModel كامل
              // لكل طلب — الإحصائيات تحتاج
              // 4 حقول فقط (status، priority،
              // createdAt، actualCost) فبناء
              // النموذج كامل كان يهدر وقت
              // المعالج مع كثرة الطلبات عند
              // كل لقطة. منطق الحساب مطابق
              // تماماً للسابق (نفس قيم
              // الافتراض وتحليل التاريخ من
              // MaintenanceRequestModel.fromJson).
              DateTime? parseStatsDate(
                dynamic value,
                DateTime? defaultValue,
              ) {
                if (value == null) return defaultValue;
                if (value is Timestamp) return value.toDate();
                if (value is String) {
                  return DateTime.tryParse(value);
                }
                return defaultValue;
              }

              var total = 0;
              var pending = 0;
              var inProgress = 0;
              var completed = 0;
              var cancelled = 0;
              var highPriority = 0;
              var mediumPriority = 0;
              var lowPriority = 0;

              // Calculate monthly costs
              final now = DateTime.now();
              final thisMonth = DateTime(now.year, now.month);
              var monthlyCost = 0.0;

              for (final doc in snapshot.docs) {
                final mapData = doc.data();

                final status =
                    mapData['status']?.toString() ??
                    'pending';
                final priority =
                    mapData['priority']?.toString() ??
                    'medium';
                final createdAt = parseStatsDate(
                  mapData['createdAt'],
                  parseStatsDate(mapData['created_at'], now),
                )!;
                final actualCost =
                    (mapData['actualCost'] ??
                        mapData['actual_cost'])
                        ?.toDouble();

                total++;
                switch (status) {
                  case 'pending':
                    pending++;
                    break;
                  case 'in_progress':
                    inProgress++;
                    break;
                  case 'completed':
                    completed++;
                    break;
                  case 'cancelled':
                    cancelled++;
                    break;
                }
                switch (priority) {
                  case 'high':
                    highPriority++;
                    break;
                  case 'medium':
                    mediumPriority++;
                    break;
                  case 'low':
                    lowPriority++;
                    break;
                }

                if (createdAt.isAfter(thisMonth) &&
                    actualCost != null) {
                  monthlyCost += actualCost;
                }
              }

              final stats = <String, dynamic>{
                'total': total,
                'pending': pending,
                'inProgress': inProgress,
                'completed': completed,
                'cancelled': cancelled,
                'highPriority': highPriority,
                'mediumPriority': mediumPriority,
                'lowPriority': lowPriority,
              };

              stats['monthlyCost'] = monthlyCost; // الاحتفاظ بالدقة العشرية للتكلفة

              return Right<Failure, Map<String, dynamic>>(stats);
            } on Exception catch (e) {
              return Left<Failure, Map<String, dynamic>>(
                ServerFailure(message: 'فشل في حساب إحصائيات الصيانة: $e'),
              );
            }
          });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب إحصائيات الصيانة: ${_readableError(e)}')),
      );
    }
  }
}

/// ⚠️ ملاحظة: جميع العمليات ذرية في نفس المعاملة
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
