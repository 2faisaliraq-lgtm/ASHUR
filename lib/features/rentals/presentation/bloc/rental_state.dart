part of 'rental_bloc.dart';

abstract class RentalState extends Equatable {
  const RentalState();

  @override
  List<Object?> get props => [];
}

class RentalInitial extends RentalState {}

class RentalLoading extends RentalState {}

class RentalLoaded extends RentalState {
  const RentalLoaded({
    required this.rentals,
    required this.filteredRentals,
    required this.stats,
    this.isGridView = false,
  });
  final List<RentalEntity> rentals;
  final List<RentalEntity> filteredRentals;
  final Map<String, dynamic> stats;
  final bool isGridView;

  RentalLoaded copyWith({
    List<RentalEntity>? rentals,
    List<RentalEntity>? filteredRentals,
    Map<String, dynamic>? stats,
    bool? isGridView,
  }) {
    return RentalLoaded(
      rentals: rentals ?? this.rentals,
      filteredRentals: filteredRentals ?? this.filteredRentals,
      stats: stats ?? this.stats,
      isGridView: isGridView ?? this.isGridView,
    );
  }

  @override
  List<Object?> get props => [rentals, filteredRentals, stats, isGridView];
}

class RentalError extends RentalState {
  const RentalError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class RentalOperationSuccess extends RentalState {
  const RentalOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// حالة تحميل سجلات الإيجارات
class RentalLogsLoaded extends RentalState {
  const RentalLogsLoaded(this.logs);

  final List<RentalLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}

/// حالة الإيجارات النشطة مع التحديث الفوري
class RentalsStreamActive extends RentalState {
  const RentalsStreamActive({
    required this.rentals,
    required this.filteredRentals,
    this.stats = const {},
    this.statistics,
    this.searchQuery = '',
    this.statusFilter,
    this.customerFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.isGridView = false,
    this.hasMoreData = false,
    this.isLoadingMore = false,
  });

  final List<RentalEntity> rentals;
  final List<RentalEntity> filteredRentals;
  final Map<String, dynamic> stats;
  final Map<String, dynamic>? statistics;
  final String searchQuery;
  final String? statusFilter;
  final String? customerFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isGridView;
  final bool hasMoreData;
  final bool isLoadingMore;

  RentalsStreamActive copyWith({
    List<RentalEntity>? rentals,
    List<RentalEntity>? filteredRentals,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? statistics,
    String? searchQuery,
    String? statusFilter,
    String? customerFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool? isGridView,
    bool? hasMoreData,
    bool? isLoadingMore,
  }) {
    return RentalsStreamActive(
      rentals: rentals ?? this.rentals,
      filteredRentals: filteredRentals ?? this.filteredRentals,
      stats: stats ?? this.stats,
      statistics: statistics ?? this.statistics,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      customerFilter: customerFilter ?? this.customerFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isGridView: isGridView ?? this.isGridView,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    rentals,
    filteredRentals,
    stats,
    statistics,
    searchQuery,
    statusFilter,
    customerFilter,
    dateFilter,
    startDate,
    endDate,
    isGridView,
    hasMoreData,
    isLoadingMore,
  ];
}
