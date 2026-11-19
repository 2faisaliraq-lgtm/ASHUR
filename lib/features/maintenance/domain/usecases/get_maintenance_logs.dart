import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/maintenance_log_entity.dart';
import '../repositories/maintenance_repository.dart';

/// Use case للحصول على سجل نشاطات الصيانة
class GetMaintenanceLogs
    implements UseCase<List<MaintenanceLogEntity>, GetMaintenanceLogsParams> {
  const GetMaintenanceLogs(this.repository);

  final MaintenanceRepository repository;

  @override
  Future<Either<Failure, List<MaintenanceLogEntity>>> call(
    GetMaintenanceLogsParams params,
  ) async {
    return repository.getMaintenanceLogs(
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

/// معاملات الحصول على سجل نشاطات الصيانة
class GetMaintenanceLogsParams {
  const GetMaintenanceLogsParams({
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
