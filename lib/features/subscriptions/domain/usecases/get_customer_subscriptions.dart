import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

/// حالة استخدام للحصول على اشتراكات عميل محدد
class GetCustomerSubscriptions {
  GetCustomerSubscriptions(this.repository);
  final SubscriptionRepository repository;

  Future<Either<Failure, List<SubscriptionEntity>>> call({
    required String customerId,
    required String organizationEmail,
    String? status,
  }) async {
    return repository.getCustomerSubscriptions(
      customerId: customerId,
      organizationEmail: organizationEmail,
      status: status,
    );
  }
}
