part of 'maintenance_bloc.dart';

/// أحداث BLoC الصيانة
abstract class MaintenanceEvent extends Equatable {
  const MaintenanceEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل طلبات الصيانة
class LoadMaintenanceRequestsEvent extends MaintenanceEvent {
  const LoadMaintenanceRequestsEvent(
    this.organizationEmail, {
    this.limit,
    this.refresh = false,
  });
  final String organizationEmail;
  final int? limit;
  final bool refresh;

  @override
  List<Object?> get props => [organizationEmail, limit, refresh];
}

/// تحميل المزيد من طلبات الصيانة
class LoadMoreMaintenanceRequestsEvent extends MaintenanceEvent {
  const LoadMoreMaintenanceRequestsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// البحث في طلبات الصيانة من الخادم
class ServerSearchMaintenanceRequestsEvent extends MaintenanceEvent {
  const ServerSearchMaintenanceRequestsEvent(
    this.organizationEmail,
    this.query, {
    this.limit = 10,
  });
  final String organizationEmail;
  final String query;
  final int limit;

  @override
  List<Object?> get props => [organizationEmail, query, limit];
}

/// إنشاء طلب صيانة
class CreateMaintenanceRequestEvent extends MaintenanceEvent {
  const CreateMaintenanceRequestEvent(
    this.request, {
    this.skipInvoiceCreditCheck = false,
  });
  final MaintenanceRequestEntity request;
  final bool skipInvoiceCreditCheck;

  @override
  List<Object?> get props => [request, skipInvoiceCreditCheck];
}

/// تحديث طلب صيانة
class UpdateMaintenanceRequestEvent extends MaintenanceEvent {
  const UpdateMaintenanceRequestEvent(this.request);
  final MaintenanceRequestEntity request;

  @override
  List<Object?> get props => [request];
}

/// حذف طلب صيانة
class DeleteMaintenanceRequestEvent extends MaintenanceEvent {
  const DeleteMaintenanceRequestEvent(this.id, this.organizationEmail);
  final String id;
  final String organizationEmail;

  @override
  List<Object?> get props => [id, organizationEmail];
}

/// البحث في طلبات الصيانة
class SearchMaintenanceRequestsEvent extends MaintenanceEvent {
  const SearchMaintenanceRequestsEvent(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

/// فلترة طلبات الصيانة
class FilterMaintenanceRequestsEvent extends MaintenanceEvent {
  const FilterMaintenanceRequestsEvent({this.status, this.priority});
  final String? status;
  final String? priority;

  @override
  List<Object?> get props => [status, priority];
}

/// تبديل نوع العرض
class ToggleMaintenanceViewModeEvent extends MaintenanceEvent {
  const ToggleMaintenanceViewModeEvent();
}

/// تحميل سجلات الصيانة
class LoadMaintenanceLogsEvent extends MaintenanceEvent {
  const LoadMaintenanceLogsEvent({
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

// Stream Events للتحديث الفوري
class StartMaintenanceStreamEvent extends MaintenanceEvent {
  const StartMaintenanceStreamEvent({
    this.organizationEmail,
    this.limit,
    this.searchQuery,
    this.statusFilter,
    this.priorityFilter,
    this.equipmentFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
  });

  final String? organizationEmail;
  final int? limit;
  final String? searchQuery;
  final String? statusFilter;
  final String? priorityFilter;
  final String? equipmentFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [
    organizationEmail,
    limit,
    searchQuery,
    statusFilter,
    priorityFilter,
    equipmentFilter,
    dateFilter,
    startDate,
    endDate,
  ];
}

class StopMaintenanceStreamEvent extends MaintenanceEvent {
  const StopMaintenanceStreamEvent();
}

class StartMaintenanceStatsStreamEvent extends MaintenanceEvent {
  const StartMaintenanceStatsStreamEvent({this.limit});
  final int? limit;

  @override
  List<Object?> get props => [limit];
}

class StopMaintenanceStatsStreamEvent extends MaintenanceEvent {
  const StopMaintenanceStatsStreamEvent();
}

// Internal stream events
class MaintenanceStreamDataReceived extends MaintenanceEvent {
  const MaintenanceStreamDataReceived(this.requests);
  final List<MaintenanceRequestEntity> requests;

  @override
  List<Object> get props => [requests];
}

class MaintenanceStreamErrorReceived extends MaintenanceEvent {
  const MaintenanceStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object> get props => [error];
}

class MaintenanceStatsStreamDataReceived extends MaintenanceEvent {
  const MaintenanceStatsStreamDataReceived(this.statistics);
  final Map<String, dynamic> statistics;

  @override
  List<Object> get props => [statistics];
}

// Equipment Stream Events للتحديث الفوري للمعدات
class StartEquipmentStreamEvent extends MaintenanceEvent {
  const StartEquipmentStreamEvent();
}

class StopEquipmentStreamEvent extends MaintenanceEvent {
  const StopEquipmentStreamEvent();
}

class MaintenanceEquipmentStreamDataReceived extends MaintenanceEvent {
  const MaintenanceEquipmentStreamDataReceived(this.equipment);
  final List<EquipmentEntity> equipment;

  @override
  List<Object> get props => [equipment];
}

// Logs Stream Events للتحديث الفوري لسجل النشاطات
class StartMaintenanceLogsStreamEvent extends MaintenanceEvent {
  const StartMaintenanceLogsStreamEvent({
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

class StopMaintenanceLogsStreamEvent extends MaintenanceEvent {
  const StopMaintenanceLogsStreamEvent();
}

class MaintenanceLogsStreamDataReceived extends MaintenanceEvent {
  const MaintenanceLogsStreamDataReceived(this.logs);
  final List<MaintenanceLogEntity> logs;

  @override
  List<Object> get props => [logs];
}
