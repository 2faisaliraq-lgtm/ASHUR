part of 'report_bloc.dart';

abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportLoaded extends ReportState {
  const ReportLoaded({
    required this.reports,
    required this.filteredReports,
    required this.selectedFilter,
    required this.searchQuery,
    required this.isGridView,
    this.stats,
    this.statistics,
    this.hasMoreReportsData = true,
    this.isLoadingMoreReports = false,
    this.lastDocumentReports,
  });
  final List<ReportEntity> reports;
  final List<ReportEntity> filteredReports;
  final String selectedFilter;
  final String searchQuery;
  final ReportStatsEntity? stats;
  final Map<String, int>? statistics;
  final bool isGridView;
  final bool hasMoreReportsData;
  final bool isLoadingMoreReports;
  final dynamic lastDocumentReports;

  ReportLoaded copyWith({
    List<ReportEntity>? reports,
    List<ReportEntity>? filteredReports,
    String? selectedFilter,
    String? searchQuery,
    ReportStatsEntity? stats,
    Map<String, int>? statistics,
    bool? isGridView,
    bool? hasMoreReportsData,
    bool? isLoadingMoreReports,
    dynamic lastDocumentReports,
  }) {
    return ReportLoaded(
      reports: reports ?? this.reports,
      filteredReports: filteredReports ?? this.filteredReports,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      stats: stats ?? this.stats,
      statistics: statistics ?? this.statistics,
      isGridView: isGridView ?? this.isGridView,
      hasMoreReportsData: hasMoreReportsData ?? this.hasMoreReportsData,
      isLoadingMoreReports: isLoadingMoreReports ?? this.isLoadingMoreReports,
      lastDocumentReports: lastDocumentReports ?? this.lastDocumentReports,
    );
  }

  @override
  List<Object?> get props => [
    reports,
    filteredReports,
    selectedFilter,
    searchQuery,
    stats,
    statistics,
    isGridView,
    hasMoreReportsData,
    isLoadingMoreReports,
    lastDocumentReports,
    // typeFilter, statusFilter, dateFilter, startDate, endDate غير مضمنين في ReportLoaded
  ];
}

class ReportError extends ReportState {
  const ReportError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class ReportOperationSuccess extends ReportState {
  const ReportOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class ReportLogsLoaded extends ReportState {
  const ReportLogsLoaded(this.logs);

  final List<ReportLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}

/// حالة التقارير النشطة مع التحديث الفوري
class ReportsStreamActive extends ReportState {
  const ReportsStreamActive({
    required this.reports,
    required this.filteredReports,
    this.stats,
    this.statistics,
    this.searchQuery = '',
    this.selectedFilter = 'all',
    this.typeFilter,
    this.statusFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.isGridView = false,
    this.hasMoreReportsData = true,
    this.isLoadingMoreReports = false,
    this.lastDocumentReports,
  });

  final List<ReportEntity> reports;
  final List<ReportEntity> filteredReports;
  final ReportStatsEntity? stats;
  final Map<String, int>? statistics;
  final String searchQuery;
  final String selectedFilter;
  final String? typeFilter;
  final String? statusFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isGridView;
  final bool hasMoreReportsData;
  final bool isLoadingMoreReports;
  final dynamic lastDocumentReports;

  ReportsStreamActive copyWith({
    List<ReportEntity>? reports,
    List<ReportEntity>? filteredReports,
    ReportStatsEntity? stats,
    Map<String, int>? statistics,
    String? searchQuery,
    String? selectedFilter,
    String? typeFilter,
    String? statusFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool? isGridView,
    bool? hasMoreReportsData,
    bool? isLoadingMoreReports,
    dynamic lastDocumentReports,
  }) {
    return ReportsStreamActive(
      reports: reports ?? this.reports,
      filteredReports: filteredReports ?? this.filteredReports,
      stats: stats ?? this.stats,
      statistics: statistics ?? this.statistics,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      typeFilter: typeFilter ?? this.typeFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isGridView: isGridView ?? this.isGridView,
      hasMoreReportsData: hasMoreReportsData ?? this.hasMoreReportsData,
      isLoadingMoreReports: isLoadingMoreReports ?? this.isLoadingMoreReports,
      lastDocumentReports: lastDocumentReports ?? this.lastDocumentReports,
    );
  }

  @override
  List<Object?> get props => [
    reports,
    filteredReports,
    stats,
    statistics,
    searchQuery,
    selectedFilter,
    typeFilter,
    statusFilter,
    dateFilter,
    startDate,
    endDate,
    isGridView,
    hasMoreReportsData,
    isLoadingMoreReports,
    lastDocumentReports,
  ];
}
