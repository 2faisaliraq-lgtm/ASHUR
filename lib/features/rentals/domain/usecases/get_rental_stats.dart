import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/rental_repository.dart';

class GetRentalStats {
  GetRentalStats(this.repository);
  final RentalRepository repository;

  Future<Either<Failure, Map<String, dynamic>>> call(
    String organizationEmail,
  ) async {
    return repository.getRentalStats(organizationEmail);
  }
}
