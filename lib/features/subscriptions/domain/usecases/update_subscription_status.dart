import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/subscription_repository.dart';

/// حالة استخدام لتحديث حالة الاشتراك
class UpdateSubscriptionStatus {
  UpdateSubscriptionStatus(this.repository);
  final SubscriptionRepository repository;

  Future<Either<Failure, void>> call({
    required String subscriptionId,
    required String status,
    required String organizationEmail,
    String? reason,
    String? updatedBy,
  }) async {
    return repository.updateSubscriptionStatus(
      subscriptionId: subscriptionId,
      status: status,
      organizationEmail: organizationEmail,
      reason: reason,
      updatedBy: updatedBy,
    );
  }
}
