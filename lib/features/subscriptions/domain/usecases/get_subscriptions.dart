import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

/// حالة استخدام للحصول على الاشتراكات
class GetSubscriptions {
  GetSubscriptions(this.repository);
  final SubscriptionRepository repository;

  Future<Either<Failure, List<SubscriptionEntity>>> call(
    String organizationEmail,
  ) async {
    return repository.getSubscriptions(organizationEmail);
  }
}
