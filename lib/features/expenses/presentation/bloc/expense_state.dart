part of 'expense_bloc.dart';

abstract class ExpenseState extends Equatable {
  const ExpenseState();

  @override
  List<Object?> get props => [];
}

class ExpenseInitial extends ExpenseState {}

class ExpenseLoading extends ExpenseState {}

class ExpenseLoaded extends ExpenseState {
  const ExpenseLoaded({
    required this.expenses,
    required this.filteredExpenses,
    required this.selectedFilter,
    required this.searchQuery,
    required this.isGridView,
    this.stats,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.lastDocument,
  });
  final List<ExpenseEntity> expenses;
  final List<ExpenseEntity> filteredExpenses;
  final String selectedFilter;
  final String searchQuery;
  final ExpenseStatsEntity? stats;
  final bool isGridView;
  final bool hasMore;
  final bool isLoadingMore;
  final dynamic lastDocument;

  ExpenseLoaded copyWith({
    List<ExpenseEntity>? expenses,
    List<ExpenseEntity>? filteredExpenses,
    String? selectedFilter,
    String? searchQuery,
    ExpenseStatsEntity? stats,
    bool? isGridView,
    bool? hasMore,
    bool? isLoadingMore,
    dynamic lastDocument,
  }) {
    return ExpenseLoaded(
      expenses: expenses ?? this.expenses,
      filteredExpenses: filteredExpenses ?? this.filteredExpenses,
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
    expenses,
    filteredExpenses,
    selectedFilter,
    searchQuery,
    stats,
    isGridView,
    hasMore,
    isLoadingMore,
    lastDocument,
  ];
}

class ExpenseError extends ExpenseState {
  const ExpenseError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class ExpenseOperationSuccess extends ExpenseState {
  const ExpenseOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class ExpenseLogsLoaded extends ExpenseState {
  const ExpenseLogsLoaded(this.logs);

  final List<ExpenseLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}

// Stream State
class ExpenseStreamActive extends ExpenseState {
  const ExpenseStreamActive({
    required this.expenses,
    required this.filteredExpenses,
    required this.selectedFilter,
    required this.searchQuery,
    required this.isGridView,
    this.stats,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.lastDocument,
  });

  final List<ExpenseEntity> expenses;
  final List<ExpenseEntity> filteredExpenses;
  final String selectedFilter;
  final String searchQuery;
  final ExpenseStatsEntity? stats;
  final bool isGridView;
  final bool hasMore;
  final bool isLoadingMore;
  final dynamic lastDocument;

  ExpenseStreamActive copyWith({
    List<ExpenseEntity>? expenses,
    List<ExpenseEntity>? filteredExpenses,
    String? selectedFilter,
    String? searchQuery,
    ExpenseStatsEntity? stats,
    bool? isGridView,
    bool? hasMore,
    bool? isLoadingMore,
    dynamic lastDocument,
  }) {
    return ExpenseStreamActive(
      expenses: expenses ?? this.expenses,
      filteredExpenses: filteredExpenses ?? this.filteredExpenses,
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
    expenses,
    filteredExpenses,
    selectedFilter,
    searchQuery,
    stats,
    isGridView,
    hasMore,
    isLoadingMore,
    lastDocument,
  ];
}
