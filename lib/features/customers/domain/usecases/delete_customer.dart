import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/customer_repository.dart';

class DeleteCustomer {

  DeleteCustomer(this.repository);
  final CustomerRepository repository;

  Future<Either<Failure, void>> call(
    String id,
    String organizationEmail,
  ) async {
    return repository.deleteCustomer(id, organizationEmail);
  }
}
