import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class UpdateReport {

  UpdateReport(this.repository);
  final ReportRepository repository;

  Future<Either<Failure, void>> call(ReportEntity report) async {
    return repository.updateReport(report);
  }
}
