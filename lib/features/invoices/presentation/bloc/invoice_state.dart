part of 'invoice_bloc.dart';

abstract class InvoiceState extends Equatable {
  const InvoiceState();

  @override
  List<Object?> get props => [];
}

class InvoiceInitial extends InvoiceState {}

class InvoiceLoading extends InvoiceState {}

class InvoiceLoaded extends InvoiceState {
  const InvoiceLoaded({
    required this.invoices,
    required this.filteredInvoices,
    required this.selectedFilter,
    required this.searchQuery,
    required this.isGridView,
    this.stats,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.lastDocument,
  });
  final List<InvoiceEntity> invoices;
  final List<InvoiceEntity> filteredInvoices;
  final String selectedFilter;
  final String searchQuery;
  final InvoiceStatsEntity? stats;
  final bool isGridView;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Object?>? lastDocument;

  InvoiceLoaded copyWith({
    List<InvoiceEntity>? invoices,
    List<InvoiceEntity>? filteredInvoices,
    String? selectedFilter,
    String? searchQuery,
    InvoiceStatsEntity? stats,
    bool? isGridView,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Object?>? lastDocument,
  }) {
    return InvoiceLoaded(
      invoices: invoices ?? this.invoices,
      filteredInvoices: filteredInvoices ?? this.filteredInvoices,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      stats: stats ?? this.stats,
      isGridView: isGridView ?? this.isGridView,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }

  @override
  List<Object?> get props => [
    invoices,
    filteredInvoices,
    selectedFilter,
    searchQuery,
    stats,
    isGridView,
    hasMore,
    isLoadingMore,
    lastDocument,
  ];
}

/// حالة الاستماع للفواتير مع التحديث الفوري
class InvoiceStreamActive extends InvoiceState {
  const InvoiceStreamActive({
    required this.invoices,
    required this.filteredInvoices,
    required this.selectedFilter,
    required this.searchQuery,
    required this.isGridView,
    this.stats,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.lastDocument,
  });

  final List<InvoiceEntity> invoices;
  final List<InvoiceEntity> filteredInvoices;
  final String selectedFilter;
  final String searchQuery;
  final bool isGridView;
  final InvoiceStatsEntity? stats;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot<Object?>? lastDocument;

  InvoiceStreamActive copyWith({
    List<InvoiceEntity>? invoices,
    List<InvoiceEntity>? filteredInvoices,
    String? selectedFilter,
    String? searchQuery,
    bool? isGridView,
    InvoiceStatsEntity? stats,
    bool? hasMore,
    bool? isLoadingMore,
    DocumentSnapshot<Object?>? lastDocument,
  }) {
    return InvoiceStreamActive(
      invoices: invoices ?? this.invoices,
      filteredInvoices: filteredInvoices ?? this.filteredInvoices,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isGridView: isGridView ?? this.isGridView,
      stats: stats ?? this.stats,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }

  @override
  List<Object?> get props => [
    invoices,
    filteredInvoices,
    selectedFilter,
    searchQuery,
    isGridView,
    stats,
    hasMore,
    isLoadingMore,
    lastDocument,
  ];
}

class InvoiceError extends InvoiceState {
  const InvoiceError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// حالة تحذير من تجاوز حد الائتمان
class InvoiceCreditLimitWarning extends InvoiceState {
  const InvoiceCreditLimitWarning({
    required this.invoice,
    required this.customerName,
    required this.currentDebt,
    required this.creditLimit,
    required this.newDebt,
  });

  final InvoiceEntity invoice;
  final String customerName;
  final double currentDebt;
  final double creditLimit;
  final double newDebt;

  @override
  List<Object?> get props => [
    invoice,
    customerName,
    currentDebt,
    creditLimit,
    newDebt,
  ];
}

class InvoiceOperationSuccess extends InvoiceState {
  const InvoiceOperationSuccess(
    this.message, {
    this.invoiceId,
    this.operationType,
  });

  final String message;
  final String? invoiceId;
  final String? operationType;

  @override
  List<Object?> get props => [message, invoiceId, operationType];
}
// ===== Invoice Logs States =====

class InvoiceLogsLoaded extends InvoiceState {
  const InvoiceLogsLoaded(this.logs);
  final List<InvoiceLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}

// ===== Invoice Template States =====

/// حالة توليد PDF
class InvoicePdfGenerated extends InvoiceState {
  const InvoicePdfGenerated(this.pdfFile);

  final File pdfFile;

  @override
  List<Object?> get props => [pdfFile];
}

/// حالة تحميل القوالب
class InvoiceTemplatesLoaded extends InvoiceState {
  const InvoiceTemplatesLoaded(this.templates);

  final List<InvoiceTemplateEntity> templates;

  @override
  List<Object?> get props => [templates];
}

/// حالة حفظ القالب بنجاح
class InvoiceTemplateSaved extends InvoiceState {
  const InvoiceTemplateSaved();

  @override
  List<Object?> get props => [];
}

/// حالة حذف القالب بنجاح
class InvoiceTemplateDeleted extends InvoiceState {
  const InvoiceTemplateDeleted();

  @override
  List<Object?> get props => [];
}

/// حالة جاري تصدير سجل الفواتير إلى PDF
class InvoiceExportingHistory extends InvoiceState {
  const InvoiceExportingHistory();

  @override
  List<Object?> get props => [];
}

/// حالة اكتمال تصدير سجل الفواتير إلى PDF
class InvoiceHistoryExported extends InvoiceState {
  const InvoiceHistoryExported(this.pdfFile);

  final File pdfFile;

  @override
  List<Object?> get props => [pdfFile];
}
