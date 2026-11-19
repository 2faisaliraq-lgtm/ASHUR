import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/expense_entity.dart';
import '../repositories/expense_repository.dart';

class GetExpenses {

  GetExpenses(this.repository);
  final ExpenseRepository repository;

  Future<Either<Failure, List<ExpenseEntity>>> call(
    String organizationEmail,
  ) async {
    return repository.getExpenses(organizationEmail);
  }
}
