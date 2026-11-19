part of 'customer_bloc.dart';

abstract class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => [];
}

class LoadCustomersEvent extends CustomerEvent {
  const LoadCustomersEvent(this.organizationEmail, {this.forceRefresh = false});
  final String organizationEmail;
  final bool forceRefresh;

  @override
  List<Object?> get props => [organizationEmail, forceRefresh];
}

/// حدث لتحميل العملاء بشكل تدريجي (pagination)
class LoadCustomersPaginatedEvent extends CustomerEvent {
  const LoadCustomersPaginatedEvent({
    required this.organizationEmail,
    this.isRefresh = false,
    this.searchQuery,
  });
  final String organizationEmail;
  final bool isRefresh;
  final String? searchQuery;

  @override
  List<Object?> get props => [organizationEmail, isRefresh, searchQuery];
}

/// حدث لتحميل المزيد من العملاء
class LoadMoreCustomersEvent extends CustomerEvent {
  const LoadMoreCustomersEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث لبدء الاستماع للعملاء مع التحديث الفوري
class StartCustomersStreamEvent extends CustomerEvent {
  const StartCustomersStreamEvent(
    this.organizationEmail, {
    this.limit,
    this.searchQuery,
  });
  final String organizationEmail;
  final int? limit;
  final String? searchQuery;

  @override
  List<Object?> get props => [organizationEmail, limit, searchQuery];
}

/// حدث لإيقاف الاستماع للعملاء
class StopCustomersStreamEvent extends CustomerEvent {
  const StopCustomersStreamEvent();
}

/// حدث لبدء الاستماع لمجموعات العملاء مع التحديث الفوري
class StartCustomerGroupsStreamEvent extends CustomerEvent {
  const StartCustomerGroupsStreamEvent();
}

/// حدث لإيقاف الاستماع لمجموعات العملاء
class StopCustomerGroupsStreamEvent extends CustomerEvent {
  const StopCustomerGroupsStreamEvent();
}

/// حدث لبدء الاستماع لإحصائيات العملاء مع التحديث الفوري
class StartCustomerStatsStreamEvent extends CustomerEvent {
  const StartCustomerStatsStreamEvent(this.organizationEmail, {this.limit});
  final String organizationEmail;
  final int? limit;

  @override
  List<Object?> get props => [organizationEmail, limit];
}

/// حدث لإيقاف الاستماع لإحصائيات العملاء
class StopCustomerStatsStreamEvent extends CustomerEvent {
  const StopCustomerStatsStreamEvent();
}

class AddCustomerEvent extends CustomerEvent {
  const AddCustomerEvent(this.customer);
  final CustomerEntity customer;

  @override
  List<Object?> get props => [customer];
}

class UpdateCustomerEvent extends CustomerEvent {
  const UpdateCustomerEvent(this.customer);
  final CustomerEntity customer;

  @override
  List<Object?> get props => [customer];
}

class DeleteCustomerEvent extends CustomerEvent {
  const DeleteCustomerEvent(this.id, this.organizationEmail);
  final String id;
  final String organizationEmail;

  @override
  List<Object?> get props => [id, organizationEmail];
}

class LoadCustomerStatsEvent extends CustomerEvent {
  const LoadCustomerStatsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class FilterCustomersEvent extends CustomerEvent {
  const FilterCustomersEvent(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
}

class SearchCustomersEvent extends CustomerEvent {
  const SearchCustomersEvent(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class ToggleViewModeEvent extends CustomerEvent {
  const ToggleViewModeEvent();
}

class CreateCustomerEvent extends CustomerEvent {
  const CreateCustomerEvent({
    required this.name,
    required this.email,
    required this.phone,
    required this.organizationEmail,
    this.address,
    this.customerGroupId,
    this.customerGroupName,
    this.creditLimit,
    this.openingBalance,
    this.notes,
    this.createdBy,
  });
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? customerGroupId;
  final String? customerGroupName;
  final double? creditLimit;
  final double? openingBalance;
  final String? notes;
  final String organizationEmail;
  final String? createdBy;

  @override
  List<Object?> get props => [
    name,
    email,
    phone,
    address,
    customerGroupId,
    customerGroupName,
    creditLimit,
    openingBalance,
    notes,
    organizationEmail,
    createdBy,
  ];
}

// ===== Customer Groups Events =====

class LoadCustomerGroupsEvent extends CustomerEvent {
  const LoadCustomerGroupsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث تحميل المزيد من مجموعات العملاء (pagination)
class LoadMoreCustomerGroupsEvent extends CustomerEvent {
  const LoadMoreCustomerGroupsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class CreateCustomerGroupEvent extends CustomerEvent {
  const CreateCustomerGroupEvent(this.group);
  final CustomerGroupEntity group;

  @override
  List<Object?> get props => [group];
}

class UpdateCustomerGroupEvent extends CustomerEvent {
  const UpdateCustomerGroupEvent(this.group);
  final CustomerGroupEntity group;

  @override
  List<Object?> get props => [group];
}

class DeleteCustomerGroupEvent extends CustomerEvent {
  const DeleteCustomerGroupEvent(this.groupId, this.organizationEmail);
  final String groupId;
  final String organizationEmail;

  @override
  List<Object?> get props => [groupId, organizationEmail];
}

// ===== Customer Logs Events =====

class LoadCustomerLogsEvent extends CustomerEvent {
  const LoadCustomerLogsEvent({
    required this.organizationEmail,
    this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String organizationEmail;
  final String? userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [
    organizationEmail,
    userId,
    searchQuery,
    actionFilter,
    dateFilter,
    startDate,
    endDate,
    limit,
  ];
}

/// حدث لبدء الاستماع لسجل نشاطات العملاء مع التحديث الفوري
/// يحمل نفس فلاتر LoadCustomerLogsEvent — عند تغيير أي فلتر
/// يُعاد تشغيل الاشتراك بفلاتر جديدة
class StartCustomerLogsStreamEvent extends CustomerEvent {
  const StartCustomerLogsStreamEvent({
    required this.organizationEmail,
    this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String organizationEmail;
  final String? userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [
    organizationEmail,
    userId,
    searchQuery,
    actionFilter,
    dateFilter,
    startDate,
    endDate,
    limit,
  ];
}

/// حدث لإيقاف الاستماع لسجل نشاطات العملاء
class StopCustomerLogsStreamEvent extends CustomerEvent {
  const StopCustomerLogsStreamEvent();
}

/// حدث داخلي لاستلام البيانات من stream العملاء
class _CustomerStreamDataReceived extends CustomerEvent {
  const _CustomerStreamDataReceived(this.result);
  final Either<Failure, List<CustomerEntity>> result;

  @override
  List<Object?> get props => [result];
}

/// حدث داخلي لاستلام خطأ من stream العملاء
class _CustomerStreamErrorReceived extends CustomerEvent {
  const _CustomerStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

/// حدث داخلي لاستلام البيانات من stream الإحصائيات
class _CustomerStatsStreamDataReceived extends CustomerEvent {
  const _CustomerStatsStreamDataReceived(this.result);
  final Either<Failure, CustomerStatsEntity> result;

  @override
  List<Object?> get props => [result];
}

class _CustomerGroupsStreamDataReceived extends CustomerEvent {
  const _CustomerGroupsStreamDataReceived(this.groups);
  final List<CustomerGroupEntity> groups;

  @override
  List<Object?> get props => [groups];
}

/// حدث داخلي لاستلام البيانات من stream سجلات العملاء
class _CustomerLogsStreamDataReceived extends CustomerEvent {
  const _CustomerLogsStreamDataReceived(this.result);
  final Either<Failure, List<CustomerLogEntity>> result;

  @override
  List<Object?> get props => [result];
}
