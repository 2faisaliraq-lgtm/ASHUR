import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/permissions/permission_checker.dart';
import 'data/repositories/subscription_repository_impl.dart';
// Domain
import 'domain/repositories/subscription_repository.dart';
import 'domain/usecases/create_subscription.dart';
import 'domain/usecases/get_subscription_stats_simple.dart';
import 'domain/usecases/get_subscription_stats_stream.dart';
import 'domain/usecases/get_subscription_types_simple.dart';
import 'domain/usecases/get_subscriptions.dart';
import 'domain/usecases/get_subscriptions_stream.dart';
import 'domain/usecases/update_subscription_status.dart';
// Presentation
import 'presentation/bloc/subscription_bloc.dart';

final sl = GetIt.instance;

/// إعداد حقن التبعيات لميزة الاشتراكات
Future<void> initSubscriptionDependencies() async {
  // External
  if (!sl.isRegistered<FirebaseFirestore>()) {
    sl.registerLazySingleton<FirebaseFirestore>(
      () => FirebaseFirestore.instance,
    );
  }

  // Permission Checker
  if (!sl.isRegistered<PermissionChecker>()) {
    sl.registerLazySingleton<PermissionChecker>(() => PermissionChecker());
  }

  // Repositories
  if (!sl.isRegistered<SubscriptionRepository>()) {
    sl.registerLazySingleton<SubscriptionRepository>(
      () => SubscriptionRepositoryImpl(firestore: sl()),
    );
  }

  // Use cases
  if (!sl.isRegistered<GetSubscriptions>()) {
    sl.registerLazySingleton(() => GetSubscriptions(sl()));
  }
  if (!sl.isRegistered<GetSubscriptionsStream>()) {
    sl.registerLazySingleton(() => GetSubscriptionsStream(sl()));
  }
  if (!sl.isRegistered<GetSubscriptionStatsStream>()) {
    sl.registerLazySingleton(() => GetSubscriptionStatsStream(sl()));
  }
  if (!sl.isRegistered<CreateSubscription>()) {
    sl.registerLazySingleton(() => CreateSubscription(sl()));
  }
  if (!sl.isRegistered<UpdateSubscriptionStatus>()) {
    sl.registerLazySingleton(() => UpdateSubscriptionStatus(sl()));
  }
  if (!sl.isRegistered<GetSubscriptionTypesSimple>()) {
    sl.registerLazySingleton(GetSubscriptionTypesSimple.new);
  }
  if (!sl.isRegistered<GetSubscriptionStatsSimple>()) {
    sl.registerLazySingleton(() => GetSubscriptionStatsSimple(sl()));
  }

  // BLoC
  if (!sl.isRegistered<SubscriptionBloc>()) {
    sl.registerFactory(
      () => SubscriptionBloc(
        getSubscriptions: sl(),
        getSubscriptionsStream: sl(),
        getSubscriptionStatsStream: sl(),
        createSubscription: sl(),
        updateSubscriptionStatus: sl(),
        getSubscriptionTypes: sl(),
        getSubscriptionStats: sl(),
        repository: sl(),
      ),
    );
  }
}
