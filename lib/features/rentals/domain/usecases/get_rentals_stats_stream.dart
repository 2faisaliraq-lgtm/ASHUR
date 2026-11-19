import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/rental_repository.dart';

class GetRentalsStatsStream
    implements StreamUseCase<Map<String, dynamic>, NoParams> {
  GetRentalsStatsStream(this.repository);
  final RentalRepository repository;

  @override
  Stream<Either<Failure, Map<String, dynamic>>> call(NoParams params,
      {int? limit}) {
    return repository.getRentalsStatisticsStream(limit: limit);
  }
}
