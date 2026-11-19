part of 'expense_bloc.dart';

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();

  @override
  List<Object?> get props => [];
}

class LoadExpensesEvent extends ExpenseEvent {
  const LoadExpensesEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث لتحميل المصاريف بشكل تدريجي (pagination)
class LoadExpensesPaginatedEvent extends ExpenseEvent {
  const LoadExpensesPaginatedEvent({
    required this.organizationEmail,
    this.isRefresh = false,
  });
  final String organizationEmail;
  final bool isRefresh;

  @override
  List<Object?> get props => [organizationEmail, isRefresh];
}

/// حدث لتحميل المزيد من المصاريف
class LoadMoreExpensesEvent extends ExpenseEvent {
  const LoadMoreExpensesEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class AddExpenseEvent extends ExpenseEvent {
  const AddExpenseEvent(this.expense);
  final ExpenseEntity expense;

  @override
  List<Object?> get props => [expense];
}

class UpdateExpenseEvent extends ExpenseEvent {
  const UpdateExpenseEvent(this.expense);
  final ExpenseEntity expense;

  @override
  List<Object?> get props => [expense];
}

class DeleteExpenseEvent extends ExpenseEvent {
  const DeleteExpenseEvent(this.id, this.organizationEmail);
  final String id;
  final String organizationEmail;

  @override
  List<Object?> get props => [id, organizationEmail];
}

class LoadExpenseStatsEvent extends ExpenseEvent {
  const LoadExpenseStatsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

class FilterExpensesEvent extends ExpenseEvent {
  const FilterExpensesEvent(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
}

class SearchExpensesEvent extends ExpenseEvent {
  const SearchExpensesEvent(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class ToggleViewModeEvent extends ExpenseEvent {
  const ToggleViewModeEvent();
}

class LoadExpenseLogsEvent extends ExpenseEvent {
  const LoadExpenseLogsEvent({
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

/// حدث لبدء الاستماع لسجل نشاطات المصاريف مع التحديث الفوري
class StartExpenseLogsStreamEvent extends ExpenseEvent {
  const StartExpenseLogsStreamEvent({
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

/// حدث لإيقاف الاستماع لسجل نشاطات المصاريف
class StopExpenseLogsStreamEvent extends ExpenseEvent {
  const StopExpenseLogsStreamEvent();
}

// Stream Events
class StartExpensesStreamEvent extends ExpenseEvent {
  const StartExpensesStreamEvent(this.organizationEmail, {this.limit, this.searchQuery});
  final String organizationEmail;
  final int? limit;
  final String? searchQuery;

  @override
  List<Object?> get props => [organizationEmail, limit, searchQuery];
}

class StopExpensesStreamEvent extends ExpenseEvent {
  const StopExpensesStreamEvent();
}

class StartExpenseStatsStreamEvent extends ExpenseEvent {
  const StartExpenseStatsStreamEvent(this.organizationEmail, {this.limit});
  final String organizationEmail;
  final int? limit;

  @override
  List<Object?> get props => [organizationEmail, limit];
}

class StopExpenseStatsStreamEvent extends ExpenseEvent {
  const StopExpenseStatsStreamEvent();
}

// Internal Stream Events
class _ExpenseStreamDataReceived extends ExpenseEvent {
  const _ExpenseStreamDataReceived(this.result);
  final Either<Failure, List<ExpenseEntity>> result;

  @override
  List<Object?> get props => [result];
}

class _ExpenseStreamErrorReceived extends ExpenseEvent {
  const _ExpenseStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

class _ExpenseStatsStreamDataReceived extends ExpenseEvent {
  const _ExpenseStatsStreamDataReceived(this.result);
  final Either<Failure, ExpenseStatsEntity> result;

  @override
  List<Object?> get props => [result];
}

/// حدث داخلي لاستلام البيانات من stream سجل النشاطات
class _ExpenseLogsStreamDataReceived extends ExpenseEvent {
  const _ExpenseLogsStreamDataReceived(this.result);
  final Either<Failure, List<ExpenseLogEntity>> result;

  @override
  List<Object?> get props => [result];
}

/// حدث داخلي لاستلام خطأ من stream سجل النشاطات
class _ExpenseLogsStreamErrorReceived extends ExpenseEvent {
  const _ExpenseLogsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}
