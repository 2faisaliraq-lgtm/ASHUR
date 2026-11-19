import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/rental_unit_entity.dart';
import '../repositories/rental_unit_repository.dart';

class GetRentalUnitsStream {
  GetRentalUnitsStream(this.repository);
  final RentalUnitRepository repository;

  Stream<Either<Failure, List<RentalUnitEntity>>> call(
    String organizationEmail,
  ) {
    return repository.getRentalUnitsStream(organizationEmail);
  }
}
