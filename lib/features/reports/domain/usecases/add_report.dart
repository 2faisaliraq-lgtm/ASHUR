import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class AddReport {

  AddReport(this.repository);
  final ReportRepository repository;

  Future<Either<Failure, String>> call(ReportEntity report) async {
    return repository.addReport(report);
  }
}
