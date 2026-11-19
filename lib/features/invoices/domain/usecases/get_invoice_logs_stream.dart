import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/invoice_log_entity.dart';
import '../repositories/invoice_repository.dart';
import 'get_invoice_logs.dart';

/// Use case للحصول على سجل نشاطات الفواتير مع التحديث الفوري
class GetInvoiceLogsStream {
  const GetInvoiceLogsStream(this.repository);

  final InvoiceRepository repository;

  Stream<Either<Failure, List<InvoiceLogEntity>>> call(
    GetInvoiceLogsParams params,
  ) {
    return repository.getInvoiceLogsStream(
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
