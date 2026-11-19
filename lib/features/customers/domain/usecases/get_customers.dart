import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class GetCustomers {
  GetCustomers(this.repository);
  final CustomerRepository repository;

  Future<Either<Failure, List<CustomerEntity>>> call(
    String organizationEmail, {
    bool forceRefresh = false,
  }) async {
    return repository.getCustomers(
      organizationEmail,
      forceRefresh: forceRefresh,
    );
  }
}
