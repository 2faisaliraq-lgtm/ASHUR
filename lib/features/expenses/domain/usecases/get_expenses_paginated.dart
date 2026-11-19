import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense_entity.dart';
import '../repositories/expense_repository.dart';

class GetExpensesPaginated {
  GetExpensesPaginated(this.repository);
  final ExpenseRepository repository;

  Future<Either<Failure, ExpensePage>> call({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot? lastDocument,
  }) {
    return repository.getExpensesPaginated(
      organizationEmail: organizationEmail,
      limit: limit,
      lastDocument: lastDocument,
    );
  }
}
