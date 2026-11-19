import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/rental_log_entity.dart';
import '../repositories/rental_repository.dart';

/// حالة استخدام: جلب سجل نشاطات الإيجارات كـ Stream للتحديث الفوري
class GetRentalLogsStream
    implements
        StreamUseCase<List<RentalLogEntity>, GetRentalLogsStreamParams> {
  const GetRentalLogsStream(this.repository);

  final RentalRepository repository;

  @override
  Stream<Either<Failure, List<RentalLogEntity>>> call(
    GetRentalLogsStreamParams params,
  ) {
    return repository.getRentalLogsStream(
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

/// معاملات جلب سجل نشاطات الإيجارات كـ Stream
class GetRentalLogsStreamParams {
  const GetRentalLogsStreamParams({
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
