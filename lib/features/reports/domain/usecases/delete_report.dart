import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/report_repository.dart';

class DeleteReport {

  DeleteReport(this.repository);
  final ReportRepository repository;

  Future<Either<Failure, void>> call(
    String id,
    String organizationEmail,
  ) async {
    return repository.deleteReport(id, organizationEmail);
  }
}
