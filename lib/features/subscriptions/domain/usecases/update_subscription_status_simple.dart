import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/subscription_repository.dart';

/// حالة استخدام بسيطة لتحديث حالة الاشتراك
class UpdateSubscriptionStatusSimple {
  UpdateSubscriptionStatusSimple(this.repository);
  final SubscriptionRepository repository;

  Future<Either<Failure, void>> call({
    required String subscriptionId,
    required String status,
    required String organizationEmail,
    String? reason,
    String? updatedBy,
  }) async {
    // ملاحظة: هذه الحالة البسيطة تهدف لتحديث الحالة فقط
    // دون العمليات الإضافية التي قد تنفذها الحالات الأخرى
    return repository.updateSubscriptionStatus(
      subscriptionId: subscriptionId,
      status: status,
      organizationEmail: organizationEmail,
      reason: reason,
      updatedBy: updatedBy,
    );
  }
}
