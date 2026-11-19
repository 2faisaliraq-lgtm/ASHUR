import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense_entity.dart';
import '../repositories/expense_repository.dart';

class GetExpensesStream {
  GetExpensesStream(this.repository);
  final ExpenseRepository repository;

  Stream<Either<Failure, List<ExpenseEntity>>> call(
    String organizationEmail, {
    int? limit,
    String? searchQuery,
  }) {
    return repository.getExpensesStream(organizationEmail, limit: limit, searchQuery: searchQuery);
  }
}
