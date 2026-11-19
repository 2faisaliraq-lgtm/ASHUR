import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/expense_stats_entity.dart';
import '../repositories/expense_repository.dart';

class GetExpenseStats {

  GetExpenseStats(this.repository);
  final ExpenseRepository repository;

  Future<Either<Failure, ExpenseStatsEntity>> call(
    String organizationEmail,
  ) async {
    return repository.getExpenseStats(organizationEmail);
  }
}
