import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice_entity.dart';
import '../repositories/invoice_repository.dart';

class ArchiveCustomerInvoices {
  ArchiveCustomerInvoices(this.repository);
  final InvoiceRepository repository;

  Future<Either<Failure, void>> call({
    required String organizationEmail,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String createdBy,
  }) {
    return repository.archiveCustomerInvoices(
      organizationEmail: organizationEmail,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      createdBy: createdBy,
    );
  }
}
