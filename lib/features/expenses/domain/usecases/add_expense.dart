import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/expense_entity.dart';
import '../repositories/expense_repository.dart';

class AddExpense {

  AddExpense(this.repository);
  final ExpenseRepository repository;

  Future<Either<Failure, void>> call(ExpenseEntity expense) async {
    return repository.addExpense(expense);
  }
}
