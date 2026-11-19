part of 'rental_bloc.dart';

abstract class RentalEvent extends Equatable {
  const RentalEvent();

  @override
  List<Object?> get props => [];
}

class LoadRentalsEvent extends RentalEvent {
  const LoadRentalsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث تحميل المزيد من عقود الإيجار (pagination)
class LoadMoreRentalsEvent extends RentalEvent {
  const LoadMoreRentalsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class CreateRentalEvent extends RentalEvent {
  const CreateRentalEvent(this.rental, {this.skipInvoiceCreditCheck = false});
  final RentalEntity rental;
  final bool skipInvoiceCreditCheck;

  @override
  List<Object?> get props => [rental, skipInvoiceCreditCheck];
}

class UpdateRentalEvent extends RentalEvent {
  const UpdateRentalEvent(this.rental);
  final RentalEntity rental;

  @override
  List<Object?> get props => [rental];
}

class DeleteRentalEvent extends RentalEvent {
  const DeleteRentalEvent(this.id, this.organizationEmail);
  final String id;
  final String organizationEmail;

  @override
  List<Object?> get props => [id, organizationEmail];
}

class SearchRentalsEvent extends RentalEvent {
  const SearchRentalsEvent(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class FilterRentalsEvent extends RentalEvent {
  const FilterRentalsEvent({this.status});
  final String? status;

  @override
  List<Object?> get props => [status];
}

class ToggleRentalViewModeEvent extends RentalEvent {
  const ToggleRentalViewModeEvent();
}

/// حدث إرجاع عقد إيجار
class ReturnRentalEvent extends RentalEvent {
  const ReturnRentalEvent(this.id, this.organizationEmail);
  final String id;
  final String organizationEmail;

  @override
  List<Object?> get props => [id, organizationEmail];
}

/// تحميل سجلات الإيجارات
class LoadRentalLogsEvent extends RentalEvent {
  const LoadRentalLogsEvent({
    required this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String userId;
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
class StartRentalsStreamEvent extends RentalEvent {
  const StartRentalsStreamEvent({
    required this.organizationEmail,
    this.limit,
    this.searchQuery,
    this.statusFilter,
    this.customerFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
  });

  final String organizationEmail;
  final int? limit;
  final String? searchQuery;
  final String? statusFilter;
  final String? customerFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [
    organizationEmail,
    limit,
    searchQuery,
    statusFilter,
    customerFilter,
    dateFilter,
    startDate,
    endDate,
  ];
}

class StopRentalsStreamEvent extends RentalEvent {
  const StopRentalsStreamEvent();
}

class StartRentalsStatsStreamEvent extends RentalEvent {
  const StartRentalsStatsStreamEvent({this.limit});
  final int? limit;

  @override
  List<Object?> get props => [limit];
}

class StopRentalsStatsStreamEvent extends RentalEvent {
  const StopRentalsStatsStreamEvent();
}

// Internal stream events
class RentalsStreamDataReceived extends RentalEvent {
  const RentalsStreamDataReceived(this.rentals);
  final List<RentalEntity> rentals;

  @override
  List<Object> get props => [rentals];
}

class RentalsStreamErrorReceived extends RentalEvent {
  const RentalsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object> get props => [error];
}

class RentalsStatsStreamDataReceived extends RentalEvent {
  const RentalsStatsStreamDataReceived(this.statistics);
  final Map<String, dynamic> statistics;

  @override
  List<Object> get props => [statistics];
}

// Logs Stream Events للتحديث الفوري لسجل نشاطات الإيجارات
class StartRentalLogsStreamEvent extends RentalEvent {
  const StartRentalLogsStreamEvent({
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

class StopRentalLogsStreamEvent extends RentalEvent {
  const StopRentalLogsStreamEvent();
}

class RentalLogsStreamDataReceived extends RentalEvent {
  const RentalLogsStreamDataReceived(this.logs);
  final List<RentalLogEntity> logs;

  @override
  List<Object> get props => [logs];
}
