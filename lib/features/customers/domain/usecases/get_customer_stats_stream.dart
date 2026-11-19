import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/customer_stats_entity.dart';
import '../repositories/customer_repository.dart';

class GetCustomerStatsStream
    implements StreamUseCase<CustomerStatsEntity, String> {
  GetCustomerStatsStream(this.repository);
  final CustomerRepository repository;

  @override
  Stream<Either<Failure, CustomerStatsEntity>> call(String organizationEmail,
      {int? limit}) {
    return repository.getCustomerStatsStream(organizationEmail, limit: limit);
  }
}
