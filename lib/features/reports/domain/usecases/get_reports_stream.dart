import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class GetReportsStreamParams {
  const GetReportsStreamParams({
    this.limit,
    this.searchQuery,
    this.typeFilter,
    this.statusFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
  });

  final int? limit;
  final String? searchQuery;
  final String? typeFilter;
  final String? statusFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
}

class GetReportsStream
    implements StreamUseCase<List<ReportEntity>, GetReportsStreamParams> {
  GetReportsStream(this.repository);
  final ReportRepository repository;

  @override
  Stream<Either<Failure, List<ReportEntity>>> call(
    GetReportsStreamParams params,
  ) {
    return repository.getReportsStream(
      limit: params.limit,
      searchQuery: params.searchQuery,
      typeFilter: params.typeFilter,
      statusFilter: params.statusFilter,
      dateFilter: params.dateFilter,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
