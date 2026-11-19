import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/invoice_entity.dart';
import '../entities/invoice_log_entity.dart';
import '../entities/invoice_stats_entity.dart';
import '../entities/invoice_template_entity.dart';
import '../entities/invoices_page.dart';

/// مستودع الفواتير
abstract class InvoiceRepository {
  Future<Either<Failure, List<InvoiceEntity>>> getInvoices(
    String organizationEmail, {
    int? limit,
  });

  /// الحصول على الفواتير المؤرشفة فقط
  Future<Either<Failure, List<InvoiceEntity>>> getArchivedInvoices(
    String organizationEmail,
  );

  /// الحصول على الفواتير مع pagination
  Future<Either<Failure, InvoicesPage>> getInvoicesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
    String? customerId, // معرف العميل للفلترة
    String? searchQuery, // نص البحث
  });

  /// الحصول على DocumentSnapshot لفاتورة محددة
  Future<DocumentSnapshot<Object?>?> getInvoiceDocument(
    String organizationEmail,
    String invoiceId,
  );

  // الطرق الجديدة للـ streams
  Stream<Either<Failure, List<InvoiceEntity>>> getInvoicesStream(
    String organizationEmail, {
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  });
  Stream<Either<Failure, InvoiceStatsEntity>> getInvoiceStatsStream(
    String organizationEmail, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  Future<Either<Failure, InvoiceEntity>> getInvoiceById(
    String id,
    String organizationEmail,
  );
  Future<Either<Failure, void>> addInvoice(InvoiceEntity invoice);
  Future<Either<Failure, void>> updateInvoice(InvoiceEntity invoice);
  Future<Either<Failure, void>> deleteInvoice(
    String id,
    String organizationEmail,
  );
  Future<Either<Failure, InvoiceStatsEntity>> getInvoiceStats(
    String organizationEmail, {
    DateTime? startDate,
    DateTime? endDate,
  });

  // ===== Invoice Logs Methods =====

  /// الحصول على سجل نشاطات الفواتير
  Future<Either<Failure, List<InvoiceLogEntity>>> getInvoiceLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// الحصول على سجل نشاطات الفواتير مع التحديث الفوري
  Stream<Either<Failure, List<InvoiceLogEntity>>> getInvoiceLogsStream({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// إضافة سجل نشاط جديد للفواتير
  Future<Either<Failure, InvoiceLogEntity>> addInvoiceLog({
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
  Future<Either<Failure, void>> deleteInvoiceLog(String logId);

  /// مسح سجلات النشاطات
  Future<Either<Failure, void>> clearInvoiceLogs({
    String? userId,
    DateTime? beforeDate,
  });

  // ===== Customer Account Methods =====

  /// أرشفة جميع فواتير العميل بشكل ذري
  Future<Either<Failure, void>> archiveCustomerInvoices({
    required String organizationEmail,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String createdBy,
  });

  /// تصفير حساب العميل وإنشاء فاتورة التصفير بشكل ذري
  Future<Either<Failure, Map<String, dynamic>>> clearCustomerAccount({
    required String organizationEmail,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String createdBy,
    required double debtAmount,
  });

  // ===== Invoice Template Methods =====

  /// الحصول على قوالب الفواتير
  Future<Either<Failure, List<InvoiceTemplateEntity>>> getInvoiceTemplates(
    String organizationEmail,
  );

  /// الحصول على قالب فاتورة حسب النوع
  Future<Either<Failure, InvoiceTemplateEntity>> getTemplateByType(
    String organizationEmail,
    String type,
  );

  /// الحصول على قالب فاتورة حسب المعرف
  Future<Either<Failure, InvoiceTemplateEntity>> getTemplateById(
    String organizationEmail,
    String templateId,
  );

  /// حفظ قالب فاتورة
  Future<Either<Failure, void>> saveInvoiceTemplate(
    InvoiceTemplateEntity template,
    String organizationEmail,
  );

  /// حذف قالب فاتورة
  Future<Either<Failure, void>> deleteInvoiceTemplate(
    String templateId,
    String organizationEmail,
  );
}
