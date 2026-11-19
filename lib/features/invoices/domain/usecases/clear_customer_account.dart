import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice_entity.dart';
import '../repositories/invoice_repository.dart';

class ClearCustomerAccount {
  ClearCustomerAccount(this.repository);
  final InvoiceRepository repository;

  Future<Either<Failure, Map<String, dynamic>>> call({
    required String organizationEmail,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String createdBy,
    required double debtAmount,
  }) {
    return repository.clearCustomerAccount(
      organizationEmail: organizationEmail,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      createdBy: createdBy,
      debtAmount: debtAmount,
    );
  }
}
