import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/invoice_repository.dart';

class DeleteInvoice {

  DeleteInvoice(this.repository);
  final InvoiceRepository repository;

  Future<Either<Failure, void>> call(
    String id,
    String organizationEmail,
  ) async {
    return repository.deleteInvoice(id, organizationEmail);
  }
}
