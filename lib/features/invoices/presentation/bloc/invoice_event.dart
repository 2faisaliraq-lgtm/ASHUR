part of 'invoice_bloc.dart';

abstract class InvoiceEvent extends Equatable {
  const InvoiceEvent();

  @override
  List<Object?> get props => [];
}

class LoadInvoicesEvent extends InvoiceEvent {
  const LoadInvoicesEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث لتحميل الفواتير بشكل تدريجي (pagination)
class LoadInvoicesPaginatedEvent extends InvoiceEvent {
  const LoadInvoicesPaginatedEvent({
    required this.organizationEmail,
    this.isRefresh = false,
    this.customerId, // معرف العميل للفلترة
    this.searchQuery, // نص البحث
  });
  final String organizationEmail;
  final bool isRefresh;
  final String? customerId; // معرف العميل للفلترة
  final String? searchQuery; // نص البحث

  @override
  List<Object?> get props => [organizationEmail, isRefresh, customerId, searchQuery];
}

/// حدث لتحميل المزيد من الفواتير
class LoadMoreInvoicesEvent extends InvoiceEvent {
  const LoadMoreInvoicesEvent(this.organizationEmail, {this.customerId});
  final String organizationEmail;
  final String? customerId; // معرف العميل للفلترة

  @override
  List<Object?> get props => [organizationEmail, customerId];
}

/// حدث لبدء الاستماع للفواتير مع التحديث الفوري
class StartInvoicesStreamEvent extends InvoiceEvent {
  const StartInvoicesStreamEvent(this.organizationEmail, {this.limit, this.startDate, this.endDate, this.searchQuery});
  final String organizationEmail;
  final int? limit;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;

  @override
  List<Object?> get props => [organizationEmail, limit, startDate, endDate, searchQuery];
}

/// حدث لإيقاف الاستماع للفواتير
class StopInvoicesStreamEvent extends InvoiceEvent {
  const StopInvoicesStreamEvent();
}

/// حدث لبدء الاستماع لإحصائيات الفواتير مع التحديث الفوري
class StartInvoiceStatsStreamEvent extends InvoiceEvent {
  const StartInvoiceStatsStreamEvent(
    this.organizationEmail, {
    this.startDate,
    this.endDate,
    this.limit,
  });
  final String organizationEmail;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [organizationEmail, startDate, endDate, limit];
}

/// حدث لإيقاف الاستماع لإحصائيات الفواتير
class StopInvoiceStatsStreamEvent extends InvoiceEvent {
  const StopInvoiceStatsStreamEvent();
}

class AddInvoiceEvent extends InvoiceEvent {
  const AddInvoiceEvent(this.invoice, {this.skipCreditCheck = false});
  final InvoiceEntity invoice;
  final bool skipCreditCheck; // تخطي فحص حد الائتمان

  @override
  List<Object?> get props => [invoice, skipCreditCheck];
}

class UpdateInvoiceEvent extends InvoiceEvent {
  const UpdateInvoiceEvent(this.invoice, {this.previousInvoice});
  final InvoiceEntity invoice;
  final InvoiceEntity? previousInvoice; // الفاتورة الأصلية لحساب الفرق

  @override
  List<Object?> get props => [invoice, previousInvoice];
}

class DeleteInvoiceEvent extends InvoiceEvent {
  const DeleteInvoiceEvent(
    this.id,
    this.organizationEmail, {
    this.deletedInvoice,
  });
  final String id;
  final String organizationEmail;
  final InvoiceEntity? deletedInvoice; // الفاتورة المحذوفة لتحديث حساب العميل

  @override
  List<Object?> get props => [id, organizationEmail, deletedInvoice];
}

class LoadInvoiceStatsEvent extends InvoiceEvent {
  const LoadInvoiceStatsEvent(
    this.organizationEmail, {
    this.startDate,
    this.endDate,
  });
  final String organizationEmail;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [organizationEmail, startDate, endDate];
}

class FilterInvoicesEvent extends InvoiceEvent {
  const FilterInvoicesEvent(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
}

class SearchInvoicesEvent extends InvoiceEvent {
  const SearchInvoicesEvent(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class ToggleViewModeEvent extends InvoiceEvent {
  const ToggleViewModeEvent();
}

// ===== Invoice Logs Events =====

class LoadInvoiceLogsEvent extends InvoiceEvent {
  const LoadInvoiceLogsEvent({
    this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String? userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [
    userId,
    searchQuery,
    actionFilter,
    dateFilter,
    startDate,
    endDate,
    limit,
  ];
}

/// حدث لبدء الاستماع لسجل نشاطات الفواتير مع التحديث الفوري
class StartInvoiceLogsStreamEvent extends InvoiceEvent {
  const StartInvoiceLogsStreamEvent({
    this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String? userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [
    userId,
    searchQuery,
    actionFilter,
    dateFilter,
    startDate,
    endDate,
    limit,
  ];
}

/// حدث لإيقاف الاستماع لسجل نشاطات الفواتير
class StopInvoiceLogsStreamEvent extends InvoiceEvent {
  const StopInvoiceLogsStreamEvent();
}

/// حدث داخلي لاستلام البيانات من stream سجل النشاطات
class _InvoiceLogsStreamDataReceived extends InvoiceEvent {
  const _InvoiceLogsStreamDataReceived(this.result);
  final Either<Failure, List<InvoiceLogEntity>> result;

  @override
  List<Object?> get props => [result];
}

/// حدث داخلي لاستلام خطأ من stream سجل النشاطات
class _InvoiceLogsStreamErrorReceived extends InvoiceEvent {
  const _InvoiceLogsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

/// حدث داخلي لاستلام البيانات من stream الفواتير
class _InvoiceStreamDataReceived extends InvoiceEvent {
  const _InvoiceStreamDataReceived(this.result);
  final Either<Failure, List<InvoiceEntity>> result;

  @override
  List<Object?> get props => [result];
}

/// حدث داخلي لاستلام خطأ من stream الفواتير
class _InvoiceStreamErrorReceived extends InvoiceEvent {
  const _InvoiceStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

/// حدث داخلي لاستلام البيانات من stream الإحصائيات
class _InvoiceStatsStreamDataReceived extends InvoiceEvent {
  const _InvoiceStatsStreamDataReceived(this.result);
  final Either<Failure, InvoiceStatsEntity> result;

  @override
  List<Object?> get props => [result];
}

// ===== Invoice Template Events =====

/// حدث توليد PDF للفاتورة
class GenerateInvoicePdfEvent extends InvoiceEvent {
  const GenerateInvoicePdfEvent({
    required this.invoice,
    required this.organizationEmail,
    this.templateId,
  });

  final InvoiceEntity invoice;
  final String organizationEmail;
  final String? templateId; // معرّف القالب المحدد

  @override
  List<Object?> get props => [invoice, organizationEmail, templateId];
}

/// حدث تحميل قوالب الفواتير
class LoadInvoiceTemplatesEvent extends InvoiceEvent {
  const LoadInvoiceTemplatesEvent(this.organizationEmail);

  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث حفظ قالب فاتورة
class SaveInvoiceTemplateEvent extends InvoiceEvent {
  const SaveInvoiceTemplateEvent({
    required this.template,
    required this.organizationEmail,
  });

  final InvoiceTemplateEntity template;
  final String organizationEmail;

  @override
  List<Object?> get props => [template, organizationEmail];
}

/// حدث حذف قالب فاتورة
class DeleteInvoiceTemplateEvent extends InvoiceEvent {
  const DeleteInvoiceTemplateEvent({
    required this.templateId,
    required this.organizationEmail,
  });

  final String templateId;
  final String organizationEmail;

  @override
  List<Object?> get props => [templateId, organizationEmail];
}

/// حدث تحميل الفواتير المؤرشفة
class LoadArchivedInvoicesEvent extends InvoiceEvent {
  const LoadArchivedInvoicesEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث تصدير سجل الفواتير الكامل إلى PDF
class ExportInvoicesHistoryEvent extends InvoiceEvent {
  const ExportInvoicesHistoryEvent({
    required this.organizationEmail,
    this.customerId,
    this.customerName,
    this.templateId,
  });

  final String organizationEmail;
  final String? customerId; // معرف العميل للفلترة (اختياري)
  final String? customerName; // اسم العميل للعرض في الغلاف (اختياري)
  final String? templateId; // معرف القالب المختار (اختياري)

  @override
  List<Object?> get props => [organizationEmail, customerId, customerName, templateId];
}
