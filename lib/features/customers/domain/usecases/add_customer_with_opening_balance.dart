import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class AddCustomerWithOpeningBalance {
  AddCustomerWithOpeningBalance(this.repository);
  final CustomerRepository repository;

  Future<Either<Failure, CustomerEntity>> call({
    required CustomerEntity customer,
    required double openingBalance,
    required String createdBy,
  }) {
    return repository.addCustomerWithOpeningBalance(
      customer: customer,
      openingBalance: openingBalance,
      createdBy: createdBy,
    );
  }
}
