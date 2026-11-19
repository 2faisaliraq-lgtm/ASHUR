import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/inventory_log_entity.dart';
import '../repositories/product_repository.dart';

/// Use case للحصول على سجل نشاطات المخزون
class GetInventoryLogs
    implements UseCase<List<InventoryLogEntity>, GetInventoryLogsParams> {
  const GetInventoryLogs(this.repository);

  final ProductRepository repository;

  @override
  Future<Either<Failure, List<InventoryLogEntity>>> call(
    GetInventoryLogsParams params,
  ) async {
    return repository.getInventoryLogs(
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

/// معاملات الحصول على سجل نشاطات المخزون
class GetInventoryLogsParams {
  const GetInventoryLogsParams({
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
