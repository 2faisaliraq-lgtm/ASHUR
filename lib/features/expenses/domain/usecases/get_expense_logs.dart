import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/expense_log_entity.dart';
import '../repositories/expense_repository.dart';

/// Use case للحصول على سجل نشاطات المصاريف
class GetExpenseLogs
    implements UseCase<List<ExpenseLogEntity>, GetExpenseLogsParams> {
  const GetExpenseLogs(this.repository);

  final ExpenseRepository repository;

  @override
  Future<Either<Failure, List<ExpenseLogEntity>>> call(
    GetExpenseLogsParams params,
  ) async {
    return repository.getExpenseLogs(
      userId: params.userId,
      searchQuery: params.searchQuery,
      actionFilter: params.actionFilter,
      dateFilter: params.dateFilter,
      startDate: params.startDate,
      endDate: params.endDate,
      limit: params.limit,
    );
  }
}

/// معاملات الحصول على سجل نشاطات المصاريف
class GetExpenseLogsParams {
  const GetExpenseLogsParams({
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
}
