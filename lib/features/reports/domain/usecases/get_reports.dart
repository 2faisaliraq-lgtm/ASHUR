import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class GetReports {

  GetReports(this.repository);
  final ReportRepository repository;

  Future<Either<Failure, List<ReportEntity>>> call(
    String organizationEmail,
  ) async {
    return repository.getReports(organizationEmail);
  }
}
