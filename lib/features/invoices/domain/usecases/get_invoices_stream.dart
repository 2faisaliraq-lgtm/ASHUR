import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/invoice_entity.dart';
import '../repositories/invoice_repository.dart';

class GetInvoicesStream {
  GetInvoicesStream(this.repository);
  final InvoiceRepository repository;

  Stream<Either<Failure, List<InvoiceEntity>>> call(
    String organizationEmail, {
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    return repository.getInvoicesStream(
      organizationEmail,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
  }
}
