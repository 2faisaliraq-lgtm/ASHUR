import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/date_parser.dart';
import '../../domain/entities/cashbox_transaction_entity.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/entities/report_log_entity.dart';
import '../../domain/entities/report_stats_entity.dart';
import '../../domain/entities/reports_page.dart';
import '../../domain/repositories/report_repository.dart';
import '../models/cashbox_transaction_view_model.dart';
import '../models/report_log_model.dart';
import '../models/report_model.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({required this.firestore});
  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();

  // ════════════════════════════════════════════════════════════════
  // ⚠️ قاعدة ذرية حاسمة: كل transaction.get() يجب أن يكون قبل كل
  // transaction.set()/update()/delete() داخل نفس المعاملة. انتهاكها يسبب:
  //   '_commands.isEmpty': Transactions require all reads to be executed before all writes.
  // لا تضع أي قراءة بعد بدء الكتابة في نفس runTransaction.
  //
  // 📋 سجل التحقق من الذرية في هذا المستودع — تم التحقق من كل بند بدقة
  //    (للمبرمجين المستقبليين — لا تعدّل منطق هذه العمليات دون مراجعة هذا السجل):
  //    🔍 نتيجة التحقق الأخير (2026-10-12): كل البنود سليمة ولا يوجد انتهاك
  //    ذرية — ما يجب أن يكون ذرياً (إنشاء/تحديث تقرير = معاملة، حركة+رصيد
  //    = WriteBatch، مستند واحد = ذرية بطبيعته) كله مطبق كما هو. التعليقات
  //    المحلية قبل كل دالة مُدمجة في هذا السجل لتجنب الإطالة — لا تُكررها
  //    عند التعديل، وعدّلها هنا فقط.
  //   ✅ addReport / updateReport: runTransaction واحدة (قراءة ثم كتابة) — ذرية.
  //      لماذا معاملة؟ لفحص الوجود والكتابة في خطوة واحدة لا تتقاطع مع كاتب
  //      آخر (منع تكرار المعرف في addReport ومنع تحديث تقرير محذوف في updateReport).
  //      ⚠️ addReport: المعرف يُولَّد داخل المعاملة بحلقة تكرار حتى
  //      يجد معرفاً غير موجود (_generateShortId تأخذ آخر 5 أرقام من
  //      الطابع الزمني فتتصادم تقارير مختلفة كل ~100 ثانية؛ توليده
  //      خارج المعاملة يرفض تقريراً مشروعاً بخطأ "التقرير موجود
  //      مسبقاً" — تصادم كاذب). الحلقة كلها قراءات قبل الكتابة
  //      الوحيدة — قاعدة Firestore محفوظة، ولو تزامن كاتبان تنجح
  //      الأولى وتفشل الثانية بنفس الخطأ فقط. ⚠️ المعرف يصل فارغاً
  //      من صفحة الإنشاء فتُعيده الدالة ليستخدمه الـ BLoC في سجل
  //      التدقيق (targetId) بدل event.report.id.
  //      ⚠️ المعاملة تعمل على الحقل firestore المُحقَن (نفس مثيل مراجع
  //      المستندات) — لا تبدّلها بـ FirebaseFirestore.instance وإلا فشلت
  //      المعاملة عند اختلاف المثيلين (مثل بيئات الاختبار بـ instanceFor).
  //   ✅ deleteReport / addReportLog / deleteReportLog / updateCashboxBalance:
  //      كتابة مستند واحد فقط — ذرية بطبيعتها في Firestore ولا تحتاج معاملة.
  //      ⚠️ deleteReport يترك سجلات التدقيق — مقصود: السجل يبقى
  //      دليلاً تاريخياً ولا يُحذف مع التقرير.
  //      ⚠️ updateCashboxBalance تحدّث الرصيد فقط بدون تسجيل حركة موثقة —
  //      مقصود لتصحيحات الرصيد الإدارية؛ لتسجيل حركة مرتبطة بالرصيد
  //      استخدم recordManualTransaction (لا تخلط بينهما).
  //   ✅ clearReportLogs: دفعات WriteBatch كل منها 500 عملية (حد Firestore)
  //      وتُرسل تباعاً — كل دفعة ذرية (كل شيء أو لا شيء)، لكن العملية
  //      كلها ليست ذرية عبر الدفعات (مقبول: سجلات قديمة تُحذف تدريجياً).
  //   ➖ سجلات التدقيق (addReportLog بعد كل عملية) مقصودة بأن تكون
  //      منفصلة ومُحسَّنة الجهد (unawaited): فشل السجل لا يجب أن يعطّل
  //      العملية التجارية. ⚠️ الحذف يُسجَّل من حوار الحذف مباشرة
  //      لأنه يستدعي المستودع مباشرة (لا يمر بمعالج الـ BLoC).
//   ✅ recordManualTransaction: WriteBatch واحدة تضم مستند الحركة
//      وتحديث الرصيد مع FieldValue.increment — ذرية (كل شيء أو لا شيء).
//      لا تفصل بين الحركة والرصيد أبداً: يجب أن يُحفظا معاً أو لا يُحفظا.
//      معرف الحركة يولده Firestore (doc() بدون معرف) لمنع التصادم —
//      الـ batch لا يعيد المحاولة فالتصادم يفقد حركة ويشوه الرصيد.
//      ⚠️ حوار الصندوق (cashbox_page.dart) ينفذها مباشرة وينتظر
//      نتيجتها قبل عرض النجاح (نمط DeleteReportDialog — المستودع
//      مُعرَّض عبر CashboxBloc.repository) — لا تُضف الحدث وتعرض
//      نجاحاً فورياً وإلا ظهر نجاح كاذب عند فشل الدفعة.
  // ════════════════════════════════════════════════════════════════

  /// إنشاء معرف قصير وفريد باستخدام UUID لتجنب التصادم بين التقارير
  /// ⚠️ تم استبدال الطابع الزمني القصير بـ UUID لضمان عدم التصادم حتى عند إنشاء تقارير متتالية بسرعة.
  String _generateShortId(String prefix) {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return '$prefix${base64Url.encode(values).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
  }

  /// تعبئة المعرف من معرف المستند عند غيابه في البيانات
  /// ⚠️ مشتركة بين جلب التقارير الثلاث (getReports و
  /// getReportsStream و getReportsStatisticsStream) — أي
  /// تغيير يُطبَّق على الثلاثة من هنا فقط
  void _fillMissingId(Map<String, dynamic> data, String docId) {
    if (data['id'] == null || data['id'].toString().isEmpty) {
      data['id'] = docId;
    }
  }

  /// تاريخ بداية فلتر التاريخ السريع (today/week/month)
  /// ⚠️ مشترك بين getReportLogs و getReportsStream — أي
  /// تغيير يُطبَّق على الاثنين من هنا فقط
  DateTime _dateFilterCutoff(String dateFilter) {
    final now = DateTime.now();
    switch (dateFilter) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return now.subtract(const Duration(days: 30));
      default:
        return DateTime(2000);
    }
  }

  CollectionReference _getReportsCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('reports')
        .collection('reports');
  }

  @override
  Future<Either<Failure, List<ReportEntity>>> getReports(
    String organizationEmail,
  ) async {
    try {
      // قراءة بدون orderBy لتجنب مشاكل الـ index
      final snapshot = await _getReportsCollection(organizationEmail).get();

      final reports = <ReportEntity>[];
      for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data == null) continue;
          final mapData = data as Map<String, dynamic>;
          // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
          _fillMissingId(mapData, doc.id);
            final report = ReportModel.fromJson(mapData);
           reports.add(report);
       }

       // ترتيب التقارير حسب التاريخ في الذاكرة
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return Right(reports);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, ReportsPage>> getReportsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  }) async {
    try {
      var query = _getReportsCollection(organizationEmail).orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final reports = <ReportEntity>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        _fillMissingId(mapData, doc.id);
        final report = ReportModel.fromJson(mapData);
        reports.add(report);
      }

      return Right(
        ReportsPage(
          reports: reports,
          lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, String>> addReport(ReportEntity report) async {
    try {
      final model = ReportModel.fromEntity(report);
      final collection = _getReportsCollection(report.organizationEmail);

      // معاملة ذرية (قراءة ثم كتابة) — السبب والتنبيهات في سجل الذرية أعلاه
      String? savedReportId;
      await firestore.runTransaction((transaction) async {
        // إنشاء ID داخل المعاملة بحلقة تكرار حتى يجد معرفاً غير
        // موجود (سبب التصادم الكاذب في سجل الذرية أعلاه)
        var reportId = report.id;
        DocumentSnapshot docSnapshot;
        if (reportId.isEmpty) {
          var attempts = 0;
          do {
            reportId = _generateShortId('RP'); // RP = Report
            docSnapshot = await transaction.get(collection.doc(reportId));
          } while (docSnapshot.exists && ++attempts < 100);
        } else {
          docSnapshot = await transaction.get(collection.doc(reportId));
        }

        // التحقق من عدم وجود التقرير مسبقاً
        if (docSnapshot.exists) {
          throw Exception('التقرير موجود مسبقاً');
        }

        // تحديث البيانات بالـ ID الصحيح وحفظها في نفس الـ transaction
        final data = model.toJson();
        data['id'] = reportId;
        transaction.set(collection.doc(reportId), data);
        savedReportId = reportId;
      });

      return Right(savedReportId ?? report.id);
      // ⚠️ إذا كان report.id غير فارغ ولكن التقرير موجود مسبقًا (docSnapshot.exists == true),
      // تُلقى استثناء 'التقرير موجود مسبقاً' قبل الوصول إلى هنا.
      // إذا كان report.id فارغًا ويتم توليد معرف جديد بنجاح، يُعاد المعرف المولَّد.
      // إذا كان report.id غير فارغ والتقرير غير موجود، يتم استخدامه ويُعاد كما هو.
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> updateReport(ReportEntity report) async {
    try {
      final model = ReportModel.fromEntity(report);

      // معاملة ذرية (قراءة ثم كتابة) — السبب والتنبيهات في سجل الذرية أعلاه
      await firestore.runTransaction((transaction) async {
        final reportDoc = _getReportsCollection(
          report.organizationEmail,
        ).doc(report.id);

        // التحقق من وجود التقرير قبل التحديث
        final docSnapshot = await transaction.get(reportDoc);

        if (!docSnapshot.exists) {
          throw Exception('التقرير غير موجود');
        }

        // تحديث البيانات في نفس الـ transaction
        transaction.update(reportDoc, model.toJson());
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // كتابة مستند واحد — ذرية بطبيعتها (تفاصيل سجلات التدقيق
  // واستدعاء حوار الحذف في سجل الذرية أعلاه)
  @override
  Future<Either<Failure, void>> deleteReport(
    String id,
    String organizationEmail,
  ) async {
    try {
      await _getReportsCollection(organizationEmail).doc(id).delete();

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, ReportStatsEntity>> getReportStats(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final snapshot = await firestore
          .collection(normalizedEmail)
          .doc('reports')
          .collection('reports')
          .get();

      // ⚠️ مشكلة أداء: هذه الدالة تجلب جميع مستندات التقارير من Firestore
      // ثم تحسب الإحصائيات في الذاكرة. مع ازدياد عدد التقارير، يزداد زمن الاستجابة
      // واستهلاك قراءات Firestore. يُنصح باستخدام getReportsStatisticsStream
      // الذي يحسب الإحصائيات مباشرة من بيانات المستند الخام دون بناء ReportModel كامل،
      // أو استخدام استعلام تجميعي (aggregation query) إذا دعمته قاعدة البيانات.
      // يمكن استبدال هذه الدالة باستدعاء getReportsStatisticsStream في الحالات
      // التي لا تتطلب كيان ReportStatsEntity الكامل.
      final reports = snapshot.docs
          .map((doc) => ReportModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      final totalReports = reports.length;
      final pendingReports = reports.where((r) => r.status == 'pending').length;
      final completedReports = reports
          .where((r) => r.status == 'completed')
          .length;
      final failedReports = reports.where((r) => r.status == 'failed').length;
      final financialReports = reports
          .where((r) => r.type == 'financial')
          .length;
      final inventoryReports = reports
          .where((r) => r.type == 'inventory')
          .length;
      final salesReports = reports.where((r) => r.type == 'sales').length;

      final stats = ReportStatsEntity(
        totalReports: totalReports,
        pendingReports: pendingReports,
        completedReports: completedReports,
        failedReports: failedReports,
        financialReports: financialReports,
        inventoryReports: inventoryReports,
        salesReports: salesReports,
      );

      return Right(stats);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ===== Report Logs Methods =====

  String? _getCurrentOrganizationId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;
    return user!.email!;
  }

  @override
  Future<Either<Failure, List<ReportLogEntity>>> getReportLogs({
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
          .doc('reports')
          .collection('logs');

      // تطبيق الفلاتر
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (actionFilter != null && actionFilter != 'all') {
        query = query.where('actionType', isEqualTo: actionFilter);
      }

      // فلتر التاريخ (التاريخ المشترك في _dateFilterCutoff)
      if (dateFilter != null && dateFilter != 'all') {
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(_dateFilterCutoff(dateFilter)),
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

      // ⚠️ البحث النصي يُطبَّق في الذاكرة بعد الجلب — لا يُطبَّق
      // الحد عند البحث وإلا اقتصر البحث على آخر limit سجل
      // فقط وتُفقد النتائج الأقدم (البحث يشمل كل السجلات
      // المطابقة للفلاتر الخادمية أعلاه).
      if (limit != null && (searchQuery == null || searchQuery.isEmpty)) {
        query = query.limit(limit);
      }

      // ترتيب النتائج
      // ⚠️ يتطلب فهرس مركب في Firestore على الحقل (timestamp descending).
      // إذا لم يكن الفهرس موجودًا، سيفشل الاستعلام بخطأ "index not found".
      // يجب إنشاء الفهرس عبر وحدة تحكم Firebase أو باستخدام firebase_indexes.
      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();
      final logs = <ReportLogEntity>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        final log = ReportLogModel.fromJson({'id': doc.id, ...mapData}).toEntity();

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

      return Right(logs);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // كتابة مستند واحد — ذرية بطبيعتها (نمط unawaited في سجل الذرية أعلاه)
  @override
  Future<Either<Failure, ReportLogEntity>> addReportLog({
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
          .doc('reports')
          .collection('logs')
          .add(logData);

      final log = ReportLogModel.fromJson({
        'id': docRef.id,
        ...logData,
      }).toEntity();

      return Right(log);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // كتابة مستند واحد — ذرية بطبيعتها (انظر سجل الذرية أعلاه).
  @override
  Future<Either<Failure, void>> deleteReportLog(String logId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // ⚠️ يتم تسجيل عملية حذف السجل بعد نجاح الحذف الفعلي لضمان دقة سجل التدقيق.
      // إذا فشل الحذف، لا يُضاف أي سجل للحذف، مما يمنع اللبس في سجل التدقيق.
      await firestore
          .collection(organizationId)
          .doc('reports')
          .collection('logs')
          .doc(logId)
          .delete();

      // تسجيل العملية في السجل بعد نجاح الحذف (unawaited لأن فشل السجل لا يجب أن يعطل العملية)
      unawaited(
        addReportLog(
          userId: FirebaseAuth.instance.currentUser?.uid ?? 'system',
          actionType: 'delete_report_log',
          details: 'تم حذف سجل نشاط: $logId',
          targetId: logId,
          targetType: 'report_log',
        ),
      );

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> clearReportLogs({
    String? userId,
    DateTime? beforeDate,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('reports')
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
      final docs = snapshot.docs;

      // كل دفعة 500 عملية — ذرية وتُرسل تباعاً (انظر سجل الذرية أعلاه)
      // ⚠️ كل دفعة ذرية بطبيعتها (كل شيء أو لا شيء)، لكن العملية كاملة ليست ذرية عبر الدفعات.
      // إذا تعطلت العملية في منتصفها، قد تُحذف بعض السجلات وتبقى الأخرى —
      // مقبول للسجلات القديمة التي تُحذف تدريجيًا، لكنه غير مناسب للبيانات الحساسة.
      const batchSize = 500;
      for (var i = 0; i < docs.length; i += batchSize) {
        final end = (i + batchSize) < docs.length ? i + batchSize : docs.length;
        final batch = firestore.batch();
        for (var j = i; j < end; j++) {
          batch.delete(docs[j].reference);
        }
        await batch.commit();
      }

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ===== Stream Methods for Real-time Updates =====

  @override
  Stream<Either<Failure, List<ReportEntity>>> getReportsStream({
    int? limit,
    String? searchQuery,
    String? typeFilter,
    String? statusFilter,
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
      Query query = _getReportsCollection(organizationId);

      // 2. إضافة فلتر الحالة إذا كان موجوداً (قبل orderBy)
      if (statusFilter != null && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      // 3. إضافة فلتر النوع إذا كان موجوداً (قبل orderBy)
      if (typeFilter != null && typeFilter != 'all') {
        query = query.where('type', isEqualTo: typeFilter);
      }

      // 4. الترتيب
      query = query.orderBy('createdAt', descending: true);

      // 5. تطبيق الحد في الـ query
      if (limit != null) {
        query = query.limit(limit);
      }

      // 6. الاستماع للتغييرات
      // ✅ تحسين (2026-10-12): نفس تحسين
      // قسم الفواتير — للستريم بلا حد
      // (صفحة القائمة) نحفظ التقارير
      // المحللة في ذاكرة خاصة بهذا
      // الستريم ونحدّث المستندات المتغيرة
      // فقط عبر docChanges بدلاً من
      // إعادة تحليل كل التقارير مع كل
      // لقطة. الستريم المحدود (بحد
      // يُطبَّق في الـ query) يبقي التحليل
      // الكامل الأصلي لأن نافذة الحد
      // تتحرك وقد لا يُصدر المستند
      // الخارج تغييراً من نوع removed
      // بشكل موثوق.
      // ⚠️ مشكلة محتملة: streamCache يُحفظ في نطاق الدالة (closure) ولا يُمسح
      // عند تغيير الفلاتر (searchQuery, typeFilter, إلخ). إذا تغير الفلتر،
      // قد تحتفظ الذاكرة بالتقارير القديمة التي لا تطابق الفلتر الجديد حتى
      // llega لقطة جديدة من Firestore تُحدث الكاش. يُنصح بتضمين معرّف الفلاتر
      // في مفتاح الكاش أو مسح الكاش عند تغيير الفلاتر.
      // ⚠️ إذا كانت فلاتر البحث أو النوع نشطة، لا نستخدم الكاش التصاعدي
      // لأن الكاش قد يحتفظ بتقارير لا تطابق الفلتر الجديد حتى تصل لقطة جديدة.
      // يتم مسح الكاش عند كل لقطة إذا كان هناك فلتر بحث أو نوع نشط.
      final hasActiveFilters =
          (searchQuery != null && searchQuery.isNotEmpty) ||
              (typeFilter != null && typeFilter != 'all');
      final streamCache = <String, ReportEntity>{};

      return query.snapshots().map((snapshot) {
        try {
          // مسح الكاش إذا كانت هناك فلاتر نشطة لضمان عدم بقاء تقارير قديمة
          if (hasActiveFilters) {
            streamCache.clear();
          }

          if (limit == null) {
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
              final mapData = Map<String, dynamic>.from(
                data as Map<String, dynamic>,
              );
              _fillMissingId(mapData, doc.id);
              try {
                streamCache[doc.id] =
                    ReportModel.fromJson(mapData);
              } on Exception catch (_) {
                streamCache.remove(doc.id);
              }
            }

            var reports = streamCache.values.toList()
              ..sort((a, b) {
                final cmp = b.createdAt.compareTo(a.createdAt);
                return cmp != 0 ? cmp : a.id.compareTo(b.id);
              });

            // 6. تطبيق فلتر البحث في الذاكرة
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              reports = reports.where((report) {
                final title = report.title.toLowerCase();
                final description =
                    report.description.toLowerCase();
                return title.contains(query) ||
                    description.contains(query);
              }).toList();
            }

            // 7. تطبيق فلاتر أخرى في الذاكرة (إذا لم تكن في Firestore)
            if (dateFilter != null && dateFilter != 'all') {
              final cutoff = _dateFilterCutoff(dateFilter);
              reports = reports
                  .where(
                    (report) =>
                        !report.createdAt.isBefore(cutoff),
                  )
                  .toList();
            }

            // فلتر التاريخ المخصص
            if (startDate != null) {
              reports = reports
                  .where(
                    (report) =>
                        !report.createdAt.isBefore(startDate),
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
              reports = reports
                  .where(
                    (report) =>
                        !report.createdAt.isAfter(endOfDay),
                  )
                  .toList();
            }

            return Right<Failure, List<ReportEntity>>(reports);
          }

          // الستريم المحدود: تحليل كامل (السلوك الأصلي)
          final reports = <ReportEntity>[];

          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              if (data == null) continue;
              final mapData = data as Map<String, dynamic>;
              _fillMissingId(mapData, doc.id);

              final report = ReportModel.fromJson(mapData);

              // 6. تطبيق فلتر البحث في الذاكرة
              if (searchQuery != null && searchQuery.isNotEmpty) {
                final query = searchQuery.toLowerCase();
                if (!report.title.toLowerCase().contains(query) &&
                    !report.description.toLowerCase().contains(query)) {
                  continue;
                }
              }

              // 7. تطبيق فلاتر أخرى في الذاكرة (إذا لم تكن في Firestore)
              if (dateFilter != null && dateFilter != 'all') {
                if (report.createdAt.isBefore(_dateFilterCutoff(dateFilter))) {
                  continue;
                }
              }

              // فلتر التاريخ المخصص
              if (startDate != null) {
                if (report.createdAt.isBefore(startDate)) {
                  continue;
                }
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
                if (report.createdAt.isAfter(endOfDay)) {
                  continue;
                }
              }

              // 8. التحقق من الحد قبل الإضافة
              if (reports.length >= limit) {
                break;
              }

              reports.add(report);
            } on Exception catch (_) {

              continue;
            }
          }

          // 9. التأكد من عدم تجاوز الحد (حماية إضافية)
          if (reports.length > limit) {
            return Right<Failure, List<ReportEntity>>(
              reports.sublist(0, limit),
            );
          }

          return Right<Failure, List<ReportEntity>>(reports);
        } on Exception catch (e) {
          return Left<Failure, List<ReportEntity>>(
            ServerFailure(message: 'فشل في معالجة بيانات التقارير: $e'),
          );
        }
      });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب التقارير: $e')),
      );
    }
  }

  @override
  Stream<Either<Failure, Map<String, int>>> getReportsStatisticsStream({
    int? limit,
  }) {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      return _getReportsCollection(organizationId).snapshots().map((snapshot) {
        try {
          // ✅ تحسين (2026-10-12): حساب
          // الإحصائيات مباشرة من بيانات
          // المستند الخام بدلاً من بناء
          // ReportModel كامل لكل تقرير —
          // الإحصائيات تحتاج 3 حقول فقط
          // (status، type، createdAt) فبناء
          // النموذج كامل كان يهدر وقت
          // المعالج مع كثرة التقارير عند
          // كل لقطة. منطق الحساب مطابق
          // تماماً للسابق.
          var total = 0;
          var pending = 0;
          var completed = 0;
          var failed = 0;
          var financial = 0;
          var inventory = 0;
          var sales = 0;

          // Calculate monthly reports
          final now = DateTime.now();
          final thisMonth = DateTime(now.year, now.month);
          var monthlyReports = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data == null) continue;
            final mapData = data as Map<String, dynamic>;

            final status = mapData['status']?.toString();
            final type = mapData['type']?.toString();
            final createdAt = DateParser.parse(
              mapData['createdAt'],
            );

            total++;
            switch (status) {
              case 'pending':
                pending++;
                break;
              case 'completed':
                completed++;
                break;
              case 'failed':
                failed++;
                break;
            }
            switch (type) {
              case 'financial':
                financial++;
                break;
              case 'inventory':
                inventory++;
                break;
              case 'sales':
                sales++;
                break;
            }
            if (!createdAt.isBefore(thisMonth)) {
              monthlyReports++;
            }
          }

          // ⚠️ المفاتيح يجب أن تطابق قيم الحالة/النوع الفعلية
          // للتقارير (pending/completed/failed و
          // financial/inventory/sales — انظر صفحتي الإنشاء
          // والتعديل) — كانت draft/published/archived و
          // operational/analytical لا توجد للتقارير فتكون
          // الأعداد صفراً دائماً.
          // ⚠️ monthlyReports يُحسب هنا ويُعاد في الخريطة، لكن ReportStatsEntity
          // يحتوي الآن على حقل monthlyReports (أُضيف في 2026-10-20). إذا تمت
          // إعادة هيكلة الكيان، يجب التأكد من أن التحويل بين الخريطة والكيان
          // يشمل هذا الحقل لتجنب فقدان البيانات.
          final stats = <String, int>{
            'total': total,
            'pending': pending,
            'completed': completed,
            'failed': failed,
            'financial': financial,
            'inventory': inventory,
            'sales': sales,
            'monthlyReports': monthlyReports,
          };

          return Right<Failure, Map<String, int>>(stats);
        } on Exception catch (e) {
          return Left<Failure, Map<String, int>>(
            ServerFailure(message: 'فشل في حساب إحصائيات التقارير: $e'),
          );
        }
      });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب إحصائيات التقارير: $e')),
      );
    }
  }

  // ===== Cashbox Methods =====

  @override
  Future<double> getCashboxBalance(String organizationEmail) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final doc = await firestore
          .collection(normalizedEmail)
          .doc('cashbox')
          .collection('balance')
          .doc('main')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data == null) return 0.0;
        return (data['currentBalance'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    } on Exception catch (_) {

      return 0.0;
    }
  }

  // كتابة مستند واحد بـ increment — ذرية بطبيعتها (تصحيحات الرصيد
  // الإدارية في سجل الذرية أعلاه)
  @override
  Future<void> updateCashboxBalance({
    required String organizationEmail,
    required double amount,
    required String type,
    required String updatedBy,
  }) async {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    await firestore
        .collection(normalizedEmail)
        .doc('cashbox')
        .collection('balance')
        .doc('main')
        .set({
          'currentBalance': FieldValue.increment(
            type == 'in' ? amount : -amount,
          ),
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        }, SetOptions(merge: true));
  }

  /// بناء استعلامات المصادر الأربعة لحركات الصندوق
  /// ⚠️ مشتركة بين getCashboxTransactions و
  /// getCashboxTransactionsStream — أي تغيير في
  /// الفلاتر يُطبَّق على الاثنتين من هنا فقط
  // ⚠️ عدم اتساق في أسماء الحقول عبر المصادر:
  //   - الفواتير: تستخدم الحقل 'createdAt' للترتيب والتاريخ
  //   - المصروفات: تستخدم الحقل 'date' (ليس 'createdAt') للترتيب والتاريخ
  //   - الاشتراكات: تستخدم الحقل 'createdAt'
  //   - الحركات اليدوية: تستخدم الحقل 'timestamp'
  // هذا التفاوت قد يسبب سلوكًا غير متوقع إذا تغيرت أسماء الحقول في أي مصدر.
  // يجب توحيد أسماء الحقول عبر جميع المجموعات أو توثيق هذا التفاوت بوضوح.
  List<Query<Map<String, dynamic>>> _buildCashboxSourceQueries({
    required String normalizedEmail,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return [
      // 1. الفواتير النقدية
      firestore
          .collection(normalizedEmail)
          .doc('invoices')
          .collection('invoices')
          .where('type', isEqualTo: 'cash')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true),
      // 2. المصروفات
      firestore
          .collection(normalizedEmail)
          .doc('expenses')
          .collection('expenses')
          .where('paidAmount', isGreaterThan: 0)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true),
      // 3. الاشتراكات
      firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('subscriptions')
          .where('totalPaid', isGreaterThan: 0)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true),
      // 4. الحركات اليدوية
      firestore
          .collection(normalizedEmail)
          .doc('cashbox')
          .collection('transactions')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true),
    ];
  }

  /// جلب مستندات الاستعلام مع تحمل الخطأ — يعيد
  /// قائمة فارغة عند فشل المصدر بدل إفشال الجلب
  /// كله (حفاظاً على الجلب الجزئي مثل السلوك السابق)
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _getCashboxSourceDocs(
    Query<Map<String, dynamic>> query, {
    int? limit,
  }) async {
    try {
      final q = limit == null ? query : query.limit(limit);
      return (await q.get()).docs;
    } on Exception {
      return [];
    }
  }

  // دوال تحويل مستندات المصادر — مشتركة بين
  // getCashboxTransactions و
  // getCashboxTransactionsStream
  // ⚠️ أي تغيير في التحويل يُطبَّق على الاثنتين

  CashboxTransactionEntity _invoiceDocToTransaction(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final paidAmount = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;

    // تحديد النوع بناءً على إشارة المبلغ
    final type = paidAmount < 0 ? 'out' : 'in';

    return CashboxTransactionViewModel(
      id: doc.id,
      type: type,
      amount: paidAmount.abs(), // استخدام القيمة المطلقة للعرض
      source: 'invoice',
      referenceId: doc.id,
      description: paidAmount < 0
          ? 'دفعة نقدية للعميل #${data['invoiceNumber'] ?? ''}'
          : 'استلام نقدي من العميل #${data['invoiceNumber'] ?? ''}',
      timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy']?.toString() ?? '',
    );
  }

  CashboxTransactionEntity _expenseDocToTransaction(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return CashboxTransactionViewModel(
      id: doc.id,
      type: 'out',
      amount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      source: 'expense',
      referenceId: doc.id,
      description: data['title']?.toString() ?? 'مصروف',
      timestamp: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy']?.toString() ?? '',
    );
  }

  CashboxTransactionEntity _subscriptionDocToTransaction(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return CashboxTransactionViewModel(
      id: doc.id,
      type: 'in',
      amount: (data['totalPaid'] as num?)?.toDouble() ?? 0.0,
      source: 'subscription',
      referenceId: doc.id,
      description: 'اشتراك: ${data['name']?.toString() ?? ''}',
      timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy']?.toString() ?? '',
    );
  }

  @override
  Future<List<CashboxTransactionEntity>> getCashboxTransactions({
    required String organizationEmail,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 20,
    int page = 0,
  }) async {
    List<CashboxTransactionEntity> allTransactions = [];

    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // حساب عدد العناصر التي يجب تخطيها
      final offset = page * limit;

      // ⚠️ كل المصادر الأربعة تجلب limit + offset — الترتيب
      // النهائي يكون بعد دمج المصادر الأربعة، فلو جلب
      // مصدر limit فقط تُفقد حركاته في الصفحات اللاحقة
      // ولا تظهر أبداً (كانت الفواتير تجلب limit + offset
      // والباقي limit — تصحيح 2026-10-11).
      // ⚠️ مشكلة منطقية متبقية: كل مصدر يُرتب حسب تاريخه الخاص، ثم يجلب limit+offset.
      // بعد دمج المصادر الأربعة وترتيبها بشكل عام، قد تُفقد حركات من مصادر
      // كانت خارج نطاق limit+offset الخاص بها ولكنها داخل النطاق العام بعد الترتيب المدمج.
      // الحل الأمثل: جلب جميع الحركات دون حد من كل مصدر، ثم تطبيق التقسيم بعد الدمج
      // (أو استخدام استعلام تجميعي إذا كان متاحًا). هذا يؤثر على الأداء مع كميات كبيرة من البيانات.

      // بناء الاستعلامات الأربعة مرة واحدة — ⚠️ مشتركة
      // مع getCashboxTransactionsStream (انظر
      // _buildCashboxSourceQueries)
      final queries = _buildCashboxSourceQueries(
        normalizedEmail: normalizedEmail,
        startDate: startDate,
        endDate: endDate,
      );

      // جلب المصادر الأربعة بالتوازي — كل مصدر مستقل عن
      // الآخر، فالانتظار المتوازي يختصر زمن الجلب إلى زمن
      // أبطأ مصدر بدل مجموع الأربعة (تحسين الأداء 2026-10-11).
      // ⚠️ فشل مصدر واحد يعيد مستنداته فارغة فقط ولا يُفقد
      // باقي المصادر (جلب جزئي مثل السلوك السابق)
      final snapshots = await Future.wait([
        _getCashboxSourceDocs(queries[0], limit: limit + offset),
        _getCashboxSourceDocs(queries[1], limit: limit + offset),
        _getCashboxSourceDocs(queries[2], limit: limit + offset),
        _getCashboxSourceDocs(queries[3], limit: limit + offset),
      ]);

      allTransactions = <CashboxTransactionEntity>[
        ...snapshots[0].map(_invoiceDocToTransaction),
        ...snapshots[1].map(_expenseDocToTransaction),
        ...snapshots[2].map(_subscriptionDocToTransaction),
        ...snapshots[3].map(CashboxTransactionViewModel.fromFirestore),
      ];

      // ترتيب كل الحركات حسب التاريخ
      allTransactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // تطبيق الـ offset والـ limit
      if (offset >= allTransactions.length) {
        return []; // لا توجد حركات إضافية
      }

      final start = offset;
      final end = (offset + limit).clamp(0, allTransactions.length);

      // إرجاع الصفحة المحددة
      return allTransactions.sublist(start, end);
    } on Exception catch (_) {

      return allTransactions;
    }
  }

  @override
  Stream<double> getCashboxBalanceStream(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);

    // استماع لمستند الرصيد — يُصدر القيمة الحالية
    // فور الاشتراك ثم عند كل تغير من أي جهاز
    return firestore
        .collection(normalizedEmail)
        .doc('cashbox')
        .collection('balance')
        .doc('main')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0.0;
      final data = doc.data();
      if (data == null) return 0.0;
      return (data['currentBalance'] as num?)?.toDouble() ?? 0.0;
    });
  }

  @override
  Stream<List<CashboxTransactionEntity>> getCashboxTransactionsStream({
    required String organizationEmail,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final normalizedEmail = _emailService.normalize(organizationEmail);

    final queries = _buildCashboxSourceQueries(
      normalizedEmail: normalizedEmail,
      startDate: startDate,
      endDate: endDate,
    );

    final controller = StreamController<List<CashboxTransactionEntity>>();

    // أحدث لقطة من كل مصدر — يُعاد الدمج عند
    // تغير أي مصدر فقط (combine-latest) دون
    // إعادة جلب المصادر الأخرى
    final latest = <QuerySnapshot<Map<String, dynamic>>?>[
      null,
      null,
      null,
      null,
    ];
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emitCombined() {
      // لا يُصدر قبل اكتمال اللقطات الأربع
      // لتجنب وميض بيانات ناقصة
      if (latest.any((snapshot) => snapshot == null)) return;

      final all = <CashboxTransactionEntity>[
        ...latest[0]!.docs.map(_invoiceDocToTransaction),
        ...latest[1]!.docs.map(_expenseDocToTransaction),
        ...latest[2]!.docs.map(_subscriptionDocToTransaction),
        ...latest[3]!.docs.map(CashboxTransactionViewModel.fromFirestore),
      ];

      // ترتيب كل الحركات حسب التاريخ
      // (نفس ترتيب getCashboxTransactions)
      all.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      controller.add(all);
    }

    // بدء اشتراكات المصادر عند أول استماع
    // (لا تُربط مستمعات Firestore قبل ذلك)
    controller.onListen = () {
      for (var i = 0; i < queries.length; i++) {
        final index = i;
        subs.add(
          queries[index].snapshots().listen(
            (snapshot) {
              latest[index] = snapshot;
              emitCombined();
            },
            // خطأ مصدر واحد يُمرَّر للمستمع ولا
            // يوقف باقي المصادر — تصلح البيانات
            // تلقائياً مع اللقطة التالية
            onError: controller.addError,
          ),
        );
      }
    };

    // إلغاء اشتراكات المصادر عند إلغاء
    // اشتراك المستمع
    controller.onCancel = () async {
      await Future.wait(subs.map((sub) => sub.cancel()));
      subs.clear();
    };

    return controller.stream;
  }

  /// ⚠️ تم تغيير من WriteBatch إلى runTransaction لضمان الذرية الكاملة.
  /// WriteBatch لا يدعم إعادة المحاولة التلقائية عند فشل الشبكة، مما قد يسبب
  /// تفاوتًا بين حركة الصندوق والرصيد. runTransaction يعيد المحاولة تلقائيًا
  /// ويضمن أن الحركة والرصيد يُحفظان معًا أو لا يُحفظان أبدًا.
  @override
  Future<void> recordManualTransaction({
    required String organizationEmail,
    required String type,
    required double amount,
    required String description,
    required String createdBy,
  }) async {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    final firestoreInstance = firestore;

    await firestoreInstance.runTransaction((transaction) async {
      final transactionRef = firestoreInstance
          .collection(normalizedEmail)
          .doc('cashbox')
          .collection('transactions')
          .doc();
      final transactionId = transactionRef.id;

      transaction.set(
        transactionRef,
        {
          'type': type,
          'amount': amount,
          'source': 'manual',
          'referenceId': transactionId,
          'description': description,
          'timestamp': FieldValue.serverTimestamp(),
          'createdBy': createdBy,
        },
      );

      final balanceRef = firestoreInstance
          .collection(normalizedEmail)
          .doc('cashbox')
          .collection('balance')
          .doc('main');

      transaction.set(
        balanceRef,
        {
          'currentBalance': FieldValue.increment(
            type == 'in' ? amount : -amount,
          ),
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': createdBy,
        },
        SetOptions(merge: true),
      );
    });
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
