import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/rental_log_entity.dart';
import '../repositories/rental_repository.dart';

/// Use case للحصول على سجل نشاطات الإيجارات
class GetRentalLogs
    implements UseCase<List<RentalLogEntity>, GetRentalLogsParams> {
  const GetRentalLogs(this.repository);

  final RentalRepository repository;

  @override
  Future<Either<Failure, List<RentalLogEntity>>> call(
    GetRentalLogsParams params,
  ) async {
    return repository.getRentalLogs(
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

/// معاملات الحصول على سجل نشاطات الإيجارات
class GetRentalLogsParams {
  const GetRentalLogsParams({
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
