import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/invoice_stats_entity.dart';
import '../repositories/invoice_repository.dart';

class GetInvoiceStatsStreamParams {
  const GetInvoiceStatsStreamParams({
    required this.organizationEmail,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String organizationEmail;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;
}

class GetInvoiceStatsStream {
  GetInvoiceStatsStream(this.repository);
  final InvoiceRepository repository;

  Stream<Either<Failure, InvoiceStatsEntity>> call(
    GetInvoiceStatsStreamParams params,
  ) {
    return repository.getInvoiceStatsStream(
      params.organizationEmail,
      startDate: params.startDate,
      endDate: params.endDate,
      limit: params.limit,
    );
  }
}
