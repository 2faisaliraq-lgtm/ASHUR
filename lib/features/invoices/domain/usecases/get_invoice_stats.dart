import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/invoice_stats_entity.dart';
import '../repositories/invoice_repository.dart';

class GetInvoiceStatsParams {
  const GetInvoiceStatsParams({
    required this.organizationEmail,
    this.startDate,
    this.endDate,
  });

  final String organizationEmail;
  final DateTime? startDate;
  final DateTime? endDate;
}

class GetInvoiceStats {
  GetInvoiceStats(this.repository);
  final InvoiceRepository repository;

  Future<Either<Failure, InvoiceStatsEntity>> call(
    GetInvoiceStatsParams params,
  ) async {
    return repository.getInvoiceStats(
      params.organizationEmail,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
