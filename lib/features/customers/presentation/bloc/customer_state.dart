part of 'customer_bloc.dart';

abstract class CustomerState extends Equatable {
  const CustomerState();

  @override
  List<Object?> get props => [];
}

class CustomerInitial extends CustomerState {}

class CustomerLoading extends CustomerState {}

class CustomerLoaded extends CustomerState {
  const CustomerLoaded({
    required this.customers,
    required this.filteredCustomers,
    required this.selectedFilter,
    required this.searchQuery,
    required this.isGridView,
    this.stats,
    this.customerGroups = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.lastDocument,
  });
  final List<CustomerEntity> customers;
  final List<CustomerEntity> filteredCustomers;
  final String selectedFilter;
  final String searchQuery;
  final CustomerStatsEntity? stats;
  final List<CustomerGroupEntity> customerGroups;
  final bool isGridView;
  final bool hasMore;
  final bool isLoadingMore;
  final dynamic lastDocument;

  CustomerLoaded copyWith({
    List<CustomerEntity>? customers,
    List<CustomerEntity>? filteredCustomers,
    String? selectedFilter,
    String? searchQuery,
    CustomerStatsEntity? stats,
    List<CustomerGroupEntity>? customerGroups,
    bool? isGridView,
    bool? hasMore,
    bool? isLoadingMore,
    dynamic lastDocument,
  }) {
    return CustomerLoaded(
      customers: customers ?? this.customers,
      filteredCustomers: filteredCustomers ?? this.filteredCustomers,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      stats: stats ?? this.stats,
      customerGroups: customerGroups ?? this.customerGroups,
      isGridView: isGridView ?? this.isGridView,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }

  @override
  List<Object?> get props => [
    customers,
    filteredCustomers,
    selectedFilter,
    searchQuery,
    stats,
    customerGroups,
    isGridView,
    hasMore,
    isLoadingMore,
    lastDocument,
  ];
}

/// حالة الاستماع للعملاء مع التحديث الفوري
class CustomerStreamActive extends CustomerState {
  const CustomerStreamActive({
    required this.customers,
    required this.filteredCustomers,
    required this.selectedFilter,
    required this.searchQuery,
    required this.isGridView,
    this.stats,
  });

  final List<CustomerEntity> customers;
  final List<CustomerEntity> filteredCustomers;
  final String selectedFilter;
  final String searchQuery;
  final bool isGridView;
  final CustomerStatsEntity? stats;

  CustomerStreamActive copyWith({
    List<CustomerEntity>? customers,
    List<CustomerEntity>? filteredCustomers,
    String? selectedFilter,
    String? searchQuery,
    bool? isGridView,
    CustomerStatsEntity? stats,
  }) {
    return CustomerStreamActive(
      customers: customers ?? this.customers,
      filteredCustomers: filteredCustomers ?? this.filteredCustomers,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isGridView: isGridView ?? this.isGridView,
      stats: stats ?? this.stats,
    );
  }

  @override
  List<Object?> get props => [
    customers,
    filteredCustomers,
    selectedFilter,
    searchQuery,
    isGridView,
    stats,
  ];
}

class CustomerError extends CustomerState {
  const CustomerError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class CustomerOperationSuccess extends CustomerState {
  const CustomerOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class CustomerCreated extends CustomerState {
  const CustomerCreated();
}

// ===== Customer Groups States =====

class CustomerGroupsLoaded extends CustomerState {
  const CustomerGroupsLoaded({
    required this.groups,
    this.customers = const [],
    this.filteredCustomers = const [],
    this.selectedFilter = 'all',
    this.searchQuery = '',
    this.isGridView = false,
    this.stats,
    this.hasMoreGroupsData = true,
    this.isLoadingMoreGroups = false,
    this.lastDocumentGroups,
  });
  final List<CustomerGroupEntity> groups;
  final List<CustomerEntity> customers;
  final List<CustomerEntity> filteredCustomers;
  final String selectedFilter;
  final String searchQuery;
  final bool isGridView;
  final CustomerStatsEntity? stats;
  final bool hasMoreGroupsData;
  final bool isLoadingMoreGroups;
  final dynamic lastDocumentGroups;

  CustomerGroupsLoaded copyWith({
    List<CustomerGroupEntity>? groups,
    List<CustomerEntity>? customers,
    List<CustomerEntity>? filteredCustomers,
    String? selectedFilter,
    String? searchQuery,
    bool? isGridView,
    CustomerStatsEntity? stats,
    bool? hasMoreGroupsData,
    bool? isLoadingMoreGroups,
    dynamic lastDocumentGroups,
  }) {
    return CustomerGroupsLoaded(
      groups: groups ?? this.groups,
      customers: customers ?? this.customers,
      filteredCustomers: filteredCustomers ?? this.filteredCustomers,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isGridView: isGridView ?? this.isGridView,
      stats: stats ?? this.stats,
      hasMoreGroupsData: hasMoreGroupsData ?? this.hasMoreGroupsData,
      isLoadingMoreGroups: isLoadingMoreGroups ?? this.isLoadingMoreGroups,
      lastDocumentGroups: lastDocumentGroups ?? this.lastDocumentGroups,
    );
  }

  @override
  List<Object?> get props => [
    groups,
    customers,
    filteredCustomers,
    selectedFilter,
    searchQuery,
    isGridView,
    stats,
    hasMoreGroupsData,
    isLoadingMoreGroups,
    lastDocumentGroups,
  ];
}

class CustomerGroupOperationSuccess extends CustomerState {
  const CustomerGroupOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

// ===== Customer Logs States =====

class CustomerLogsLoaded extends CustomerState {
  const CustomerLogsLoaded(this.logs);
  final List<CustomerLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}
