import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/customers/customer_feature.dart';
import '../../../features/customers/injection_container.dart'
    as customer_injection;
import '../../../features/customers/presentation/bloc/customer_bloc.dart';
import '../../../features/subscriptions/domain/entities/subscription_entity.dart';
import '../../../features/subscriptions/domain/entities/subscription_type_entity.dart';
import '../../../features/subscriptions/injection_container.dart' show sl;
import '../../../features/subscriptions/presentation/bloc/subscription_bloc.dart';
import '../../../features/subscriptions/presentation/bloc/subscription_event.dart';
import '../../../features/subscriptions/presentation/pages/create_subscription_page.dart';
import '../../../features/subscriptions/presentation/pages/create_subscription_type_page.dart';
import '../../../features/subscriptions/presentation/pages/edit_subscription_page.dart';
import '../../../features/subscriptions/presentation/pages/edit_subscription_type_page.dart';
import '../../../features/subscriptions/presentation/pages/recharge_activations_page.dart';
import '../../../features/subscriptions/presentation/pages/subscription_details_page.dart';
import '../../../features/subscriptions/presentation/pages/subscription_type_details_page.dart';
import '../../../features/subscriptions/presentation/pages/subscription_types_list_page.dart';
import '../../../features/subscriptions/presentation/pages/subscriptions_list_page.dart';
import '../../../features/subscriptions/presentation/pages/subscriptions_log_page.dart';
import '../../../features/subscriptions/presentation/pages/subscriptions_reports_page.dart';
import '../../../features/subscriptions/presentation/pages/subscriptions_settings_page.dart';
import '../../../features/subscriptions/subscription_feature.dart';
import '../route_guards/bloc_route_builder.dart';
import '../route_guards/permission_route_builder.dart';
import '../route_paths.dart';

/// مسارات الاشتراكات
Map<String, WidgetBuilder> get subscriptionsRoutes => {
  RoutePaths.subscriptionsList: (context) {
    final user = FirebaseAuth.instance.currentUser;
    final initialFilter = ModalRoute.of(context)?.settings.arguments as String?;
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    SubscriptionFeature.ensureInitialized();

    return BlocProvider<SubscriptionBloc>(
      create: (context) => SubscriptionBloc(
        getSubscriptions: sl(),
        getSubscriptionsStream: sl(),
        getSubscriptionStatsStream: sl(),
        createSubscription: sl(),
        updateSubscriptionStatus: sl(),
        getSubscriptionTypes: sl(),
        getSubscriptionStats: sl(),
        repository: sl(),
      )..add(LoadSubscriptionsEvent(user?.email ?? '')),
      child: SubscriptionsListPage(initialFilter: initialFilter),
    );
  },
  RoutePaths.subscriptionTypesList: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    SubscriptionFeature.ensureInitialized();

    return BlocProvider<SubscriptionBloc>(
      create: (context) => SubscriptionBloc(
        getSubscriptions: sl(),
        getSubscriptionsStream: sl(),
        getSubscriptionStatsStream: sl(),
        createSubscription: sl(),
        updateSubscriptionStatus: sl(),
        getSubscriptionTypes: sl(),
        getSubscriptionStats: sl(),
        repository: sl(),
      ),
      child: const SubscriptionTypesListPage(),
    );
  },
  RoutePaths.subscriptionsSettings: (context) =>
      const SubscriptionsSettingsPage(),
  RoutePaths.subscriptionsLog: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    SubscriptionFeature.ensureInitialized();

    return BlocProvider<SubscriptionBloc>(
      create: (context) => SubscriptionBloc(
        getSubscriptions: sl(),
        getSubscriptionsStream: sl(),
        getSubscriptionStatsStream: sl(),
        createSubscription: sl(),
        updateSubscriptionStatus: sl(),
        getSubscriptionTypes: sl(),
        getSubscriptionStats: sl(),
        repository: sl(),
      ),
      child: const SubscriptionsLogPage(),
    );
  },
  RoutePaths.subscriptionsReports: (context) => buildPermissionRoute(
    permission: 'reports_view',
    blocProviders: [
      BlocProvider<SubscriptionBloc>(
        create: (context) {
          final user = FirebaseAuth.instance.currentUser;
          // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
          SubscriptionFeature.ensureInitialized();

          return SubscriptionBloc(
              getSubscriptions: sl(),
              getSubscriptionsStream: sl(),
              getSubscriptionStatsStream: sl(),
              createSubscription: sl(),
              updateSubscriptionStatus: sl(),
              getSubscriptionTypes: sl(),
              getSubscriptionStats: sl(),
              repository: sl(),
            )
            ..add(LoadSubscriptionsEvent(user?.email ?? ''))
            ..add(LoadSubscriptionStatsEvent(user?.email ?? ''));
        },
      ),
    ],
    child: const SubscriptionsReportsPage(),
  ),
};

/// مسارات الاشتراكات الديناميكية (تتطلب arguments)
Route<dynamic>? buildSubscriptionRoute(
  String routeName,
  RouteSettings settings,
) {
  final user = FirebaseAuth.instance.currentUser;

  switch (routeName) {
    case RoutePaths.createSubscription:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      SubscriptionFeature.ensureInitialized();
      // CustomerFeature already initialized at app startup

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithMultiBloc(
          permission: 'subscriptions_create',
          blocProviders: [
            BlocProvider<SubscriptionBloc>(
              create: (context) => SubscriptionBloc(
                getSubscriptions: sl(),
                getSubscriptionsStream: sl(),
                getSubscriptionStatsStream: sl(),
                createSubscription: sl(),
                updateSubscriptionStatus: sl(),
                getSubscriptionTypes: sl(),
                getSubscriptionStats: sl(),
                repository: sl(),
              ),
            ),
            BlocProvider<CustomerBloc>(
              create: (context) => CustomerBloc(
                getCustomers: customer_injection.getIt(),
                getCustomersPaginated: customer_injection.getIt(),
                getCustomersStream: customer_injection.getIt(),
                getCustomerStatsStream: customer_injection.getIt(),
                addCustomer: customer_injection.getIt(),
                addCustomerWithOpeningBalance: customer_injection.getIt(),
                updateCustomer: customer_injection.getIt(),
                deleteCustomer: customer_injection.getIt(),
                getCustomerStats: customer_injection.getIt(),
                getCustomerLogs: customer_injection.getIt(),
                repository: customer_injection.getIt(),
              ),
            ),
          ],
          child: const CreateSubscriptionPage(),
        ),
        settings: settings,
      );

    case RoutePaths.editSubscription:
      final subscription = settings.arguments;
      if (subscription != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        SubscriptionFeature.ensureInitialized();
        // CustomerFeature already initialized at app startup

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithMultiBloc(
            permission: 'subscriptions_edit',
            blocProviders: [
              BlocProvider<SubscriptionBloc>(
                create: (context) => SubscriptionBloc(
                  getSubscriptions: sl(),
                  getSubscriptionsStream: sl(),
                  getSubscriptionStatsStream: sl(),
                  createSubscription: sl(),
                  updateSubscriptionStatus: sl(),
                  getSubscriptionTypes: sl(),
                  getSubscriptionStats: sl(),
                  repository: sl(),
                ),
              ),
              BlocProvider<CustomerBloc>(
                create: (context) => CustomerBloc(
                  getCustomers: customer_injection.getIt(),
                  getCustomersPaginated: customer_injection.getIt(),
                  getCustomersStream: customer_injection.getIt(),
                  getCustomerStatsStream: customer_injection.getIt(),
                  addCustomer: customer_injection.getIt(),
                  addCustomerWithOpeningBalance: customer_injection.getIt(),
                  updateCustomer: customer_injection.getIt(),
                  deleteCustomer: customer_injection.getIt(),
                  getCustomerStats: customer_injection.getIt(),
                  getCustomerLogs: customer_injection.getIt(),
                  repository: customer_injection.getIt(),
                ),
              ),
            ],
            child: EditSubscriptionPage(subscription: subscription as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.createSubscriptionType:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      SubscriptionFeature.ensureInitialized();

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'subscriptions_create',
          bloc: SubscriptionBloc(
            getSubscriptions: sl(),
            getSubscriptionsStream: sl(),
            getSubscriptionStatsStream: sl(),
            createSubscription: sl(),
            updateSubscriptionStatus: sl(),
            getSubscriptionTypes: sl(),
            getSubscriptionStats: sl(),
            repository: sl(),
          ),
          child: const CreateSubscriptionTypePage(),
        ),
        settings: settings,
      );

    case RoutePaths.editSubscriptionType:
      final type = settings.arguments;
      if (type != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        SubscriptionFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'subscriptions_edit',
            bloc: SubscriptionBloc(
              getSubscriptions: sl(),
              getSubscriptionsStream: sl(),
              getSubscriptionStatsStream: sl(),
              createSubscription: sl(),
              updateSubscriptionStatus: sl(),
              getSubscriptionTypes: sl(),
              getSubscriptionStats: sl(),
              repository: sl(),
            ),
            child: EditSubscriptionTypePage(type: type as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.subscriptionDetails:
      final subscription = settings.arguments;
      if (subscription != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        SubscriptionFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: SubscriptionBloc(
              getSubscriptions: sl(),
              getSubscriptionsStream: sl(),
              getSubscriptionStatsStream: sl(),
              createSubscription: sl(),
              updateSubscriptionStatus: sl(),
              getSubscriptionTypes: sl(),
              getSubscriptionStats: sl(),
              repository: sl(),
            )..add(LoadSubscriptionsEvent(user?.email ?? '')),
            child: SubscriptionDetailsPage(
              subscription: subscription as SubscriptionEntity,
            ),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.subscriptionTypeDetails:
      final subscriptionType = settings.arguments;
      if (subscriptionType != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        SubscriptionFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: SubscriptionBloc(
              getSubscriptions: sl(),
              getSubscriptionsStream: sl(),
              getSubscriptionStatsStream: sl(),
              createSubscription: sl(),
              updateSubscriptionStatus: sl(),
              getSubscriptionTypes: sl(),
              getSubscriptionStats: sl(),
              repository: sl(),
            ),
            child: SubscriptionTypeDetailsPage(
              subscriptionType: subscriptionType as SubscriptionTypeEntity,
            ),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.rechargeActivations:
      final subscriptionType = settings.arguments;
      if (subscriptionType != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        SubscriptionFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'subscriptions_edit',
            bloc: SubscriptionBloc(
              getSubscriptions: sl(),
              getSubscriptionsStream: sl(),
              getSubscriptionStatsStream: sl(),
              createSubscription: sl(),
              updateSubscriptionStatus: sl(),
              getSubscriptionTypes: sl(),
              getSubscriptionStats: sl(),
              repository: sl(),
            ),
            child: RechargeActivationsPage(
              subscriptionType: subscriptionType as SubscriptionTypeEntity,
            ),
          ),
          settings: settings,
        );
      }
      return null;

    default:
      return null;
  }
}
