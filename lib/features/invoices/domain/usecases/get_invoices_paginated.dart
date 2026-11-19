import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/invoice_entity.dart';
import '../entities/invoices_page.dart';
import '../repositories/invoice_repository.dart';

class GetInvoicesPaginated {
  GetInvoicesPaginated(this.repository);
  final InvoiceRepository repository;

  Future<Either<Failure, InvoicesPage>> call({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot? lastDocument,
    String? customerId,
    String? searchQuery,
  }) {
    return repository.getInvoicesPaginated(
      organizationEmail: organizationEmail,
      limit: limit,
      lastDocument: lastDocument,
      customerId: customerId,
      searchQuery: searchQuery,
    );
  }
}
