import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/expense_repository.dart';

class DeleteExpense {

  DeleteExpense(this.repository);
  final ExpenseRepository repository;

  Future<Either<Failure, void>> call(
    String id,
    String organizationEmail,
  ) async {
    return repository.deleteExpense(id, organizationEmail);
  }
}
