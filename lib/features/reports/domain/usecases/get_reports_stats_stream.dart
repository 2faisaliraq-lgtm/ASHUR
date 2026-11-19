import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/report_repository.dart';

class GetReportsStatsStream
    implements StreamUseCase<Map<String, int>, NoParams> {
  GetReportsStatsStream(this.repository);
  final ReportRepository repository;

  @override
  Stream<Either<Failure, Map<String, int>>> call(NoParams params,
      {int? limit}) {
    return repository.getReportsStatisticsStream(limit: limit);
  }
}
