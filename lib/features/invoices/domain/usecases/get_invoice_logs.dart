import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/invoice_log_entity.dart';
import '../repositories/invoice_repository.dart';

/// Use case للحصول على سجل نشاطات الفواتير
class GetInvoiceLogs
    implements UseCase<List<InvoiceLogEntity>, GetInvoiceLogsParams> {
  const GetInvoiceLogs(this.repository);

  final InvoiceRepository repository;

  @override
  Future<Either<Failure, List<InvoiceLogEntity>>> call(
    GetInvoiceLogsParams params,
  ) async {
    return repository.getInvoiceLogs(
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

/// معاملات الحصول على سجل نشاطات الفواتير
class GetInvoiceLogsParams {
  const GetInvoiceLogsParams({
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
