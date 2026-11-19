import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense_log_entity.dart';
import '../repositories/expense_repository.dart';
import 'get_expense_logs.dart';

/// Use case للحصول على سجل نشاطات المصاريف مع التحديث الفوري
class GetExpenseLogsStream {
  const GetExpenseLogsStream(this.repository);

  final ExpenseRepository repository;

  Stream<Either<Failure, List<ExpenseLogEntity>>> call(
    GetExpenseLogsParams params,
  ) {
    return repository.getExpenseLogsStream(
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
