import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/customer_log_entity.dart';
import '../repositories/customer_repository.dart';

/// Use case للحصول على سجل نشاطات العملاء
class GetCustomerLogs
    implements UseCase<List<CustomerLogEntity>, GetCustomerLogsParams> {
  const GetCustomerLogs(this.repository);

  final CustomerRepository repository;

  @override
  Future<Either<Failure, List<CustomerLogEntity>>> call(
    GetCustomerLogsParams params,
  ) async {
    return repository.getCustomerLogs(
      organizationEmail: params.organizationEmail,
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

/// معاملات الحصول على سجل نشاطات العملاء
class GetCustomerLogsParams {
  const GetCustomerLogsParams({
    required this.organizationEmail,
    this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String organizationEmail;
  final String? userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;
}
