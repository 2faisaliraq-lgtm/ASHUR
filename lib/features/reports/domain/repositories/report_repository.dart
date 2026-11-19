import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/cashbox_transaction_entity.dart';
import '../entities/report_entity.dart';
import '../entities/report_log_entity.dart';
import '../entities/report_stats_entity.dart';
import '../entities/reports_page.dart';

/// واجهة مستودع التقارير
abstract class ReportRepository {
  /// الحصول على جميع التقارير
  Future<Either<Failure, List<ReportEntity>>> getReports(
    String organizationEmail,
  );

  /// الحصول على التقارير بشكل تدريجي (pagination)
  Future<Either<Failure, ReportsPage>> getReportsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  });

  /// إضافة تقرير جديد
  /// ⚠️ تُعيد معرف التقرير الفعلي — يُولَّد داخل المعاملة الذرية
  /// (السبب في سجل الذرية بمستودع التنفيذ) لأنه يصل فارغاً من
  /// صفحة الإنشاء، ويُستخدم في سجل التدقيق (targetId).
  Future<Either<Failure, String>> addReport(ReportEntity report);

  /// تحديث تقرير
  Future<Either<Failure, void>> updateReport(ReportEntity report);

  /// حذف تقرير
  Future<Either<Failure, void>> deleteReport(
    String id,
    String organizationEmail,
  );

  /// الحصول على إحصائيات التقارير
  Future<Either<Failure, ReportStatsEntity>> getReportStats(
    String organizationEmail,
  );

  // ===== Stream Methods for Real-time Updates =====

  /// جلب التقارير كـ Stream للتحديث الفوري
  Stream<Either<Failure, List<ReportEntity>>> getReportsStream({
    int? limit,
    String? searchQuery,
    String? typeFilter,
    String? statusFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// جلب إحصائيات التقارير كـ Stream للتحديث الفوري
  Stream<Either<Failure, Map<String, int>>> getReportsStatisticsStream({
    int? limit,
  });

  // ===== Report Logs Methods =====

  /// الحصول على سجل نشاطات التقارير
  Future<Either<Failure, List<ReportLogEntity>>> getReportLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// إضافة سجل نشاط جديد للتقارير
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
  });

  /// حذف سجل نشاط محدد
  Future<Either<Failure, void>> deleteReportLog(String logId);

  /// مسح سجلات النشاطات
  Future<Either<Failure, void>> clearReportLogs({
    String? userId,
    DateTime? beforeDate,
  });

  // ===== Cashbox Methods =====

  /// الحصول على حساب الصندوق
  Future<double> getCashboxBalance(String organizationEmail);

  /// الحصول على حساب الصندوق كـ Stream للتحديث الفوري
  /// ⚠️ يُحدَّث تلقائياً عند تغير مستند الرصيد من أي جهاز
  Stream<double> getCashboxBalanceStream(String organizationEmail);

  /// تحديث حساب الصندوق
  Future<void> updateCashboxBalance({
    required String organizationEmail,
    required double amount,
    required String type, // 'in' أو 'out'
    required String updatedBy,
  });

  /// الحصول على حركات الصندوق من جميع المصادر
  Future<List<CashboxTransactionEntity>> getCashboxTransactions({
    required String organizationEmail,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 20,
    int page = 0,
  });

  /// الحصول على حركات الصندوق كـ Stream للتحديث الفوري
  /// ⚠️ تُدمج المصادر الأربعة (فواتير/مصروفات/اشتراكات/يدوية)
  /// وتُعاد الإصدار عند تغير أي مصدر — تجلب كل الحركات
  /// المطابقة للفترة بدون تقسيم صفحات (التقسيم في الـ BLoC)
  Stream<List<CashboxTransactionEntity>> getCashboxTransactionsStream({
    required String organizationEmail,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// تسجيل حركة صندوق يدوية
  Future<void> recordManualTransaction({
    required String organizationEmail,
    required String type,
    required double amount,
    required String description,
    required String createdBy,
  });
}
