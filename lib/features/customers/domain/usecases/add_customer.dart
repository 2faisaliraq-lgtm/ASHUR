import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class AddCustomer {
  AddCustomer(this.repository);
  final CustomerRepository repository;

  Future<Either<Failure, CustomerEntity>> call(CustomerEntity customer) async {
    return repository.addCustomer(customer);
  }
}
