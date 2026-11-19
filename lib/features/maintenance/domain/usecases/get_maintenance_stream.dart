import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/maintenance_request_entity.dart';
import '../repositories/maintenance_repository.dart';

class GetMaintenanceStreamParams {
  const GetMaintenanceStreamParams({
    this.limit,
    this.searchQuery,
    this.statusFilter,
    this.priorityFilter,
    this.equipmentFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
  });

  final int? limit;
  final String? searchQuery;
  final String? statusFilter;
  final String? priorityFilter;
  final String? equipmentFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
}

class GetMaintenanceStream
    implements
        StreamUseCase<
          List<MaintenanceRequestEntity>,
          GetMaintenanceStreamParams
        > {
  GetMaintenanceStream(this.repository);
  final MaintenanceRepository repository;

  @override
  Stream<Either<Failure, List<MaintenanceRequestEntity>>> call(
    GetMaintenanceStreamParams params,
  ) {
    return repository.getMaintenanceRequestsStream(
      limit: params.limit,
      searchQuery: params.searchQuery,
      statusFilter: params.statusFilter,
      priorityFilter: params.priorityFilter,
      equipmentFilter: params.equipmentFilter,
      dateFilter: params.dateFilter,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
