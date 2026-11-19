import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer_stats_entity.dart';
import '../repositories/customer_repository.dart';

class GetCustomerStats {

  GetCustomerStats(this.repository);
  final CustomerRepository repository;

  Future<Either<Failure, CustomerStatsEntity>> call(
    String organizationEmail,
  ) async {
    return repository.getCustomerStats(organizationEmail);
  }
}
