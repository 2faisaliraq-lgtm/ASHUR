import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/rental_unit_entity.dart';
import '../repositories/rental_unit_repository.dart';

class UpdateRentalUnit implements UseCase<void, RentalUnitEntity> {
  UpdateRentalUnit(this.repository);
  final RentalUnitRepository repository;

  @override
  Future<Either<Failure, void>> call(RentalUnitEntity params) async {
    return repository.updateRentalUnit(params);
  }
}
