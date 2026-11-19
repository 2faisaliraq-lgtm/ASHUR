import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice_entity.dart';
import '../repositories/invoice_repository.dart';

class AddInvoice {

  AddInvoice(this.repository);
  final InvoiceRepository repository;

  Future<Either<Failure, void>> call(InvoiceEntity invoice) async {
    return repository.addInvoice(invoice);
  }
}
