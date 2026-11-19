import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/rental_entity.dart';
import '../repositories/rental_repository.dart';

class CreateRental {
  CreateRental(this.repository);
  final RentalRepository repository;

  Future<Either<Failure, void>> call(RentalEntity rental) async {
    return repository.createRental(rental);
  }
}
