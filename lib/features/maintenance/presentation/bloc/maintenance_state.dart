part of 'maintenance_bloc.dart';

/// حالات BLoC الصيانة
abstract class MaintenanceState extends Equatable {
  const MaintenanceState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class MaintenanceInitial extends MaintenanceState {}

/// حالة التحميل
class MaintenanceLoading extends MaintenanceState {}

/// حالة تحميل البيانات بنجاح
class MaintenanceLoaded extends MaintenanceState {
  const MaintenanceLoaded({
    required this.requests,
    required this.filteredRequests,
    required this.equipment,
    required this.stats,
    this.isGridView = false,
    this.currentPage = 1,
    this.hasMoreData = true,
    this.isLoadingMore = false,
    this.lastDocument,
  });
  final List<MaintenanceRequestEntity> requests;
  final List<MaintenanceRequestEntity> filteredRequests;
  final List<EquipmentEntity> equipment;
  final Map<String, dynamic> stats;
  final bool isGridView;
  final int currentPage;
  final bool hasMoreData;
  final bool isLoadingMore;
  final dynamic lastDocument;

  MaintenanceLoaded copyWith({
    List<MaintenanceRequestEntity>? requests,
    List<MaintenanceRequestEntity>? filteredRequests,
    List<EquipmentEntity>? equipment,
    Map<String, dynamic>? stats,
    bool? isGridView,
    int? currentPage,
    bool? hasMoreData,
    bool? isLoadingMore,
    dynamic lastDocument,
  }) {
    return MaintenanceLoaded(
      requests: requests ?? this.requests,
      filteredRequests: filteredRequests ?? this.filteredRequests,
      equipment: equipment ?? this.equipment,
      stats: stats ?? this.stats,
      isGridView: isGridView ?? this.isGridView,
      currentPage: currentPage ?? this.currentPage,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }

  @override
  List<Object?> get props => [
    requests,
    filteredRequests,
    equipment,
    stats,
    isGridView,
    currentPage,
    hasMoreData,
    isLoadingMore,
    lastDocument,
  ];
}

/// حالة إنشاء طلب صيانة
class MaintenanceCreating extends MaintenanceState {}

/// حالة تحديث طلب صيانة
class MaintenanceUpdating extends MaintenanceState {}

/// حالة حذف طلب صيانة
class MaintenanceDeleting extends MaintenanceState {}

/// حالة تحميل المزيد من البيانات
class MaintenanceLoadingMore extends MaintenanceState {
  const MaintenanceLoadingMore(this.currentData);
  final MaintenanceLoaded currentData;

  @override
  List<Object?> get props => [currentData];
}

/// حالة الخطأ
class MaintenanceError extends MaintenanceState {
  const MaintenanceError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// حالة نجاح العملية
class MaintenanceOperationSuccess extends MaintenanceState {
  const MaintenanceOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// حالة تحميل سجلات الصيانة
class MaintenanceLogsLoaded extends MaintenanceState {
  const MaintenanceLogsLoaded(this.logs);

  final List<MaintenanceLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}

/// حالة طلبات الصيانة النشطة مع التحديث الفوري
class MaintenanceStreamActive extends MaintenanceState {
  const MaintenanceStreamActive({
    required this.requests,
    required this.filteredRequests,
    this.equipment = const [],
    this.stats = const {},
    this.statistics,
    this.searchQuery = '',
    this.statusFilter,
    this.priorityFilter,
    this.equipmentFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.isGridView = false,
    this.hasMoreData = true,
    this.isLoadingMore = false,
    this.lastDocument,
  });

  final List<MaintenanceRequestEntity> requests;
  final List<MaintenanceRequestEntity> filteredRequests;
  final List<EquipmentEntity> equipment;
  final Map<String, dynamic> stats;
  final Map<String, dynamic>? statistics;
  final String searchQuery;
  final String? statusFilter;
  final String? priorityFilter;
  final String? equipmentFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isGridView;
  final bool hasMoreData;
  final bool isLoadingMore;
  final dynamic lastDocument;

  MaintenanceStreamActive copyWith({
    List<MaintenanceRequestEntity>? requests,
    List<MaintenanceRequestEntity>? filteredRequests,
    List<EquipmentEntity>? equipment,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? statistics,
    String? searchQuery,
    String? statusFilter,
    String? priorityFilter,
    String? equipmentFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool? isGridView,
    bool? hasMoreData,
    bool? isLoadingMore,
    dynamic lastDocument,
  }) {
    return MaintenanceStreamActive(
      requests: requests ?? this.requests,
      filteredRequests: filteredRequests ?? this.filteredRequests,
      equipment: equipment ?? this.equipment,
      stats: stats ?? this.stats,
      statistics: statistics ?? this.statistics,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      equipmentFilter: equipmentFilter ?? this.equipmentFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isGridView: isGridView ?? this.isGridView,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }

  @override
  List<Object?> get props => [
        requests,
        filteredRequests,
        equipment,
        stats,
        statistics,
        searchQuery,
        statusFilter,
        priorityFilter,
        equipmentFilter,
        dateFilter,
        startDate,
        endDate,
        isGridView,
        hasMoreData,
        isLoadingMore,
        lastDocument,
      ];
}
