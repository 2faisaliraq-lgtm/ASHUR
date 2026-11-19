import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/report_stats_entity.dart';
import '../repositories/report_repository.dart';

class GetReportStats {

  GetReportStats(this.repository);
  final ReportRepository repository;

  Future<Either<Failure, ReportStatsEntity>> call(
    String organizationEmail,
  ) async {
    return repository.getReportStats(organizationEmail);
  }
}
