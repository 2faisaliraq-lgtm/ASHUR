import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/expense_stats_entity.dart';
import '../repositories/expense_repository.dart';

class GetExpenseStatsStream
    implements StreamUseCase<ExpenseStatsEntity, String> {
  GetExpenseStatsStream(this.repository);
  final ExpenseRepository repository;

  @override
  Stream<Either<Failure, ExpenseStatsEntity>> call(String organizationEmail,
      {int? limit}) {
    return repository.getExpenseStatsStream(organizationEmail, limit: limit);
  }
}
