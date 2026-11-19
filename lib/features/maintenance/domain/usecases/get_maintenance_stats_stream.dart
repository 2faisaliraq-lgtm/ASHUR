import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/maintenance_repository.dart';

class GetMaintenanceStatsStream
    implements StreamUseCase<Map<String, dynamic>, NoParams> {
  GetMaintenanceStatsStream(this.repository);
  final MaintenanceRepository repository;

  @override
  Stream<Either<Failure, Map<String, dynamic>>> call(NoParams params,
      {int? limit}) {
    return repository.getMaintenanceStatisticsStream(limit: limit);
  }
}
