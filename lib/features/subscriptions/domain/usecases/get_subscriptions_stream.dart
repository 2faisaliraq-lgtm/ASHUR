import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

class GetSubscriptionsStreamParams {
  const GetSubscriptionsStreamParams({
    required this.organizationEmail,
    this.limit,
    this.searchQuery,
  });

  final String organizationEmail;
  final int? limit;
  final String? searchQuery;
}

class GetSubscriptionsStream {
  GetSubscriptionsStream(this.repository);
  final SubscriptionRepository repository;

  Stream<Either<Failure, List<SubscriptionEntity>>> call(
    GetSubscriptionsStreamParams params,
  ) {
    return repository.getSubscriptionsStream(
      params.organizationEmail,
      limit: params.limit,
      searchQuery: params.searchQuery,
    );
  }
}
