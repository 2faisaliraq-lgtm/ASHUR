import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/customers_page.dart';
import '../repositories/customer_repository.dart';

class GetCustomersPaginated {
  GetCustomersPaginated(this.repository);
  final CustomerRepository repository;

  Future<Either<Failure, CustomersPage>> call({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
    String? searchQuery,
  }) async {
    return repository.getCustomersPaginated(
      organizationEmail: organizationEmail,
      limit: limit,
      lastDocument: lastDocument,
      searchQuery: searchQuery,
    );
  }
}
