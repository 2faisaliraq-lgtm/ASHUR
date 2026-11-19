import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/rental_unit_entity.dart';
import '../repositories/rental_unit_repository.dart';

class GetAvailableRentalUnits
    implements UseCase<List<RentalUnitEntity>, String> {
  GetAvailableRentalUnits(this.repository);
  final RentalUnitRepository repository;

  @override
  Future<Either<Failure, List<RentalUnitEntity>>> call(String params) async {
    return repository.getAvailableRentalUnits(params);
  }
}
