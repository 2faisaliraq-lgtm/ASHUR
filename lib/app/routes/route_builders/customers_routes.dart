import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/navigation/main_navigation_page.dart';
import '../../../features/customers/customer_feature.dart';
import '../../../features/customers/injection_container.dart' show getIt;
import '../../../features/customers/presentation/bloc/customer_bloc.dart';
import '../../../features/customers/presentation/pages/create_customer_group_page.dart';
import '../../../features/customers/presentation/pages/create_customer_page.dart';
import '../../../features/customers/presentation/pages/customer_details_page.dart';
import '../../../features/customers/presentation/pages/customer_groups_list_page.dart';
import '../../../features/customers/presentation/pages/customers_list_page.dart';
import '../../../features/customers/presentation/pages/customers_reports_page.dart';
import '../../../features/customers/presentation/pages/customers_settings_page.dart';
import '../../../features/customers/presentation/pages/edit_customer_group_page.dart';
import '../../../features/customers/presentation/pages/edit_customer_page.dart'
    as edit;
import '../route_guards/bloc_route_builder.dart';
import '../route_guards/permission_route_builder.dart';
import '../route_paths.dart';

/// مسارات العملاء
Map<String, WidgetBuilder> get customersRoutes => {
  RoutePaths.customers: (context) => const MainNavigationPage(),
  RoutePaths.customersList: (context) {
    final user = FirebaseAuth.instance.currentUser;
    final initialFilter = ModalRoute.of(context)?.settings.arguments as String?;
    // CustomerFeature already initialized at app startup

    return BlocProvider<CustomerBloc>(
      create: (context) => CustomerBloc(
        getCustomers: getIt(),
        getCustomersPaginated: getIt(),
        getCustomersStream: getIt(),
        getCustomerStatsStream: getIt(),
        addCustomer: getIt(),
        addCustomerWithOpeningBalance: getIt(),
        updateCustomer: getIt(),
        deleteCustomer: getIt(),
        getCustomerStats: getIt(),
        getCustomerLogs: getIt(),
        repository: getIt(),
      )..add(LoadCustomersEvent(user?.email ?? '')),
      child: CustomersListPage(initialFilter: initialFilter),
    );
  },
  RoutePaths.customerGroupsList: (context) {
    final user = FirebaseAuth.instance.currentUser;
    return buildBlocRouteWithEvent(
      bloc: GetIt.instance<CustomerBloc>(),
      event: LoadCustomerGroupsEvent(user?.email ?? ''),
      child: const CustomerGroupsListPage(),
    );
  },
  RoutePaths.customersSettings: (context) => const CustomersSettingsPage(),
  RoutePaths.customersReports: (context) => buildPermissionRoute(
    permission: 'reports_view',
    blocProviders: [
      BlocProvider<CustomerBloc>(
        create: (context) {
          final user = FirebaseAuth.instance.currentUser;
          return GetIt.instance<CustomerBloc>()
            ..add(LoadCustomersEvent(user?.email ?? ''))
            ..add(LoadCustomerGroupsEvent(user?.email ?? ''))
            ..add(LoadCustomerStatsEvent(user?.email ?? ''));
        },
      ),
    ],
    child: const CustomersReportsPage(),
  ),
};

/// مسارات العملاء الديناميكية (تتطلب arguments)
Route<dynamic>? buildCustomerRoute(String routeName, RouteSettings settings) {
  switch (routeName) {
    case RoutePaths.createCustomer:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      // CustomerFeature already initialized at app startup

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'customers_create',
          bloc: GetIt.instance<CustomerBloc>(),
          child: const CreateCustomerPage(),
        ),
        settings: settings,
      );

    case RoutePaths.createCustomerGroup:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      // CustomerFeature already initialized at app startup

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'customers_create',
          bloc: GetIt.instance<CustomerBloc>(),
          child: const CreateCustomerGroupPage(),
        ),
        settings: settings,
      );

    case RoutePaths.editCustomerGroup:
      final group = settings.arguments;
      if (group != null) {
        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'customers_edit',
            bloc: GetIt.instance<CustomerBloc>(),
            child: EditCustomerGroupPage(group: group as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.editCustomer:
      final customer = settings.arguments;
      if (customer != null) {
        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'customers_edit',
            bloc: GetIt.instance<CustomerBloc>(),
            child: edit.EditCustomerPage(customer: customer as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.customerDetails:
      final customer = settings.arguments;
      if (customer != null) {
        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: GetIt.instance<CustomerBloc>()
              ..add(
                LoadCustomersEvent((customer as dynamic).organizationEmail),
              ),
            child: CustomerDetailsPage(customer: customer as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    default:
      return null;
  }
}
