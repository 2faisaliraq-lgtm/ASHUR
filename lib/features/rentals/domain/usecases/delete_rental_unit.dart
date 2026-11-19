import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/rental_unit_repository.dart';

class DeleteRentalUnit implements UseCase<void, String> {
  DeleteRentalUnit(this.repository);
  final RentalUnitRepository repository;

  @override
  Future<Either<Failure, void>> call(String params) async {
    return repository.deleteRentalUnit(params);
  }
}
