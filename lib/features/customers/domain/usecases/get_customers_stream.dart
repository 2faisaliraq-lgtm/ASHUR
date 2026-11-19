import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class GetCustomersStreamParams {
  const GetCustomersStreamParams({
    required this.organizationEmail,
    this.limit,
    this.searchQuery,
  });

  final String organizationEmail;
  final int? limit;
  final String? searchQuery;
}

class GetCustomersStream
    implements StreamUseCase<List<CustomerEntity>, GetCustomersStreamParams> {
  GetCustomersStream(this.repository);
  final CustomerRepository repository;

  @override
  Stream<Either<Failure, List<CustomerEntity>>> call(
    GetCustomersStreamParams params,
  ) {
    return repository.getCustomersStream(
      params.organizationEmail,
      limit: params.limit,
      searchQuery: params.searchQuery,
    );
  }
}
