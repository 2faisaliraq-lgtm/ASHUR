import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice_entity.dart';
import '../repositories/invoice_repository.dart';

class GetArchivedInvoices {

  GetArchivedInvoices(this.repository);
  final InvoiceRepository repository;

  Future<Either<Failure, List<InvoiceEntity>>> call(
    String organizationEmail,
  ) async {
    return repository.getArchivedInvoices(organizationEmail);
  }
}
