import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/report_log_entity.dart';
import '../repositories/report_repository.dart';

/// Use case للحصول على سجل نشاطات التقارير
class GetReportLogs
    implements UseCase<List<ReportLogEntity>, GetReportLogsParams> {
  const GetReportLogs(this.repository);

  final ReportRepository repository;

  @override
  Future<Either<Failure, List<ReportLogEntity>>> call(
    GetReportLogsParams params,
  ) async {
    return repository.getReportLogs(
      userId: params.userId,
      searchQuery: params.searchQuery,
      actionFilter: params.actionFilter,
      dateFilter: params.dateFilter,
      startDate: params.startDate,
      endDate: params.endDate,
      limit: params.limit,
    );
  }
}

/// معاملات الحصول على سجل نشاطات التقارير
class GetReportLogsParams {
  const GetReportLogsParams({
    this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String? userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;
}
