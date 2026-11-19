import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/maintenance_log_entity.dart';
import '../repositories/maintenance_repository.dart';

/// حالة استخدام: جلب سجل نشاطات الصيانة كـ Stream للتحديث الفوري
class GetMaintenanceLogsStream
    implements
        StreamUseCase<List<MaintenanceLogEntity>, GetMaintenanceLogsStreamParams> {
  GetMaintenanceLogsStream(this.repository);
  final MaintenanceRepository repository;

  @override
  Stream<Either<Failure, List<MaintenanceLogEntity>>> call(
    GetMaintenanceLogsStreamParams params,
  ) {
    return repository.getMaintenanceLogsStream(
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

class GetMaintenanceLogsStreamParams {
  const GetMaintenanceLogsStreamParams({
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
