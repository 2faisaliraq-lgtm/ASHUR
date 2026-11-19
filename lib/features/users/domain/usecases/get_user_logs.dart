import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_log_entity.dart';
import '../repositories/users_repository.dart';

/// Use case للحصول على سجل نشاطات المستخدمين
class GetUserLogs implements UseCase<List<UserLogEntity>, GetUserLogsParams> {
  const GetUserLogs(this.repository);

  final UsersRepository repository;

  @override
  Future<Either<Failure, List<UserLogEntity>>> call(
    GetUserLogsParams params,
  ) async {
    return repository.getUserLogs(
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

/// معاملات الحصول على سجل نشاطات المستخدمين
class GetUserLogsParams {
  const GetUserLogsParams({
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
