import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/rental_entity.dart';
import '../repositories/rental_repository.dart';

class GetRentals {
  GetRentals(this.repository);
  final RentalRepository repository;

  Future<Either<Failure, List<RentalEntity>>> call(
    String organizationEmail,
  ) async {
    return repository.getRentals(organizationEmail);
  }
}
