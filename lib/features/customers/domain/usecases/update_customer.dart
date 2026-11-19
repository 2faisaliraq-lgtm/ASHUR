import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class UpdateCustomer {

  UpdateCustomer(this.repository);
  final CustomerRepository repository;

  Future<Either<Failure, void>> call(CustomerEntity customer) async {
    return repository.updateCustomer(customer);
  }
}
