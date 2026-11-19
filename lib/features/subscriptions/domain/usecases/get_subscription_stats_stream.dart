import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/subscription_repository.dart';

class GetSubscriptionStatsStream
    implements StreamUseCase<Map<String, dynamic>, String> {
  GetSubscriptionStatsStream(this.repository);
  final SubscriptionRepository repository;

  @override
  Stream<Either<Failure, Map<String, dynamic>>> call(String organizationEmail,
      {int? limit}) {
    return repository.getSubscriptionStatsStream(organizationEmail, limit: limit);
  }
}
