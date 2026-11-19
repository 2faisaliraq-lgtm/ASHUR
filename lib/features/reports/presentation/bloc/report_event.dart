part of 'report_bloc.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class LoadReportsEvent extends ReportEvent {
  const LoadReportsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث تحميل تقارير إضافية (تمرير)
class LoadMoreReportsEvent extends ReportEvent {
  const LoadMoreReportsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class AddReportEvent extends ReportEvent {
  const AddReportEvent(this.report);
  final ReportEntity report;

  @override
  List<Object?> get props => [report];
}

class UpdateReportEvent extends ReportEvent {
  const UpdateReportEvent(this.report);
  final ReportEntity report;

  @override
  List<Object?> get props => [report];
}

class DeleteReportEvent extends ReportEvent {
  const DeleteReportEvent(this.id, this.organizationEmail);
  final String id;
  final String organizationEmail;

  @override
  List<Object?> get props => [id, organizationEmail];
}

class LoadReportStatsEvent extends ReportEvent {
  const LoadReportStatsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class FilterReportsEvent extends ReportEvent {
  const FilterReportsEvent(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
}

class SearchReportsEvent extends ReportEvent {
  const SearchReportsEvent(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class ToggleViewModeEvent extends ReportEvent {
  const ToggleViewModeEvent();
}

class LoadReportLogsEvent extends ReportEvent {
  const LoadReportLogsEvent({
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
  });

  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [
    searchQuery,
    actionFilter,
    dateFilter,
    startDate,
    endDate,
  ];
}

// Stream Events للتحديث الفوري
class StartReportsStreamEvent extends ReportEvent {
  const StartReportsStreamEvent({
    required this.organizationEmail,
    this.limit,
    this.searchQuery,
    this.typeFilter,
    this.statusFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
  });

  final String organizationEmail;
  final int? limit;
  final String? searchQuery;
  final String? typeFilter;
  final String? statusFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [
    organizationEmail,
    limit,
    searchQuery,
    typeFilter,
    statusFilter,
    dateFilter,
    startDate,
    endDate,
  ];
}

class StopReportsStreamEvent extends ReportEvent {
  const StopReportsStreamEvent();
}

class StartReportsStatsStreamEvent extends ReportEvent {
  const StartReportsStatsStreamEvent({this.limit});
  final int? limit;

  @override
  List<Object?> get props => [limit];
}

class StopReportsStatsStreamEvent extends ReportEvent {
  const StopReportsStatsStreamEvent();
}

// Internal stream events
class ReportsStreamDataReceived extends ReportEvent {
  const ReportsStreamDataReceived(this.reports);
  final List<ReportEntity> reports;

  @override
  List<Object> get props => [reports];
}

class ReportsStreamErrorReceived extends ReportEvent {
  const ReportsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object> get props => [error];
}

class ReportsStatsStreamDataReceived extends ReportEvent {
  const ReportsStatsStreamDataReceived(this.statistics);
  final Map<String, int> statistics;

  @override
  List<Object> get props => [statistics];
}
