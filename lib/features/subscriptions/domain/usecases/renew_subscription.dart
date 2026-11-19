import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

/// حالة استخدام لتجديد الاشتراك
class RenewSubscription {
  RenewSubscription(this.repository);
  final SubscriptionRepository repository;

  Future<Either<Failure, SubscriptionEntity>> call({
    required String subscriptionId,
    required String organizationEmail,
    DateTime? customStartDate,
    bool? isAutoRenew,
    bool? isPaid,
    InvoiceEntity Function(SubscriptionEntity renewedSubscription)?
        invoiceBuilder,
  }) async {
    return repository.renewSubscription(
      subscriptionId: subscriptionId,
      organizationEmail: organizationEmail,
      customStartDate: customStartDate,
      isAutoRenew: isAutoRenew,
      isPaid: isPaid,
      invoiceBuilder: invoiceBuilder,
    );
  }
}
