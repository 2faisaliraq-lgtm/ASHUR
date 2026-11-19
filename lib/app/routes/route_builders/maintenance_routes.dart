import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../features/customers/customer_feature.dart';
import '../../../features/customers/injection_container.dart'
    as customer_injection;
import '../../../features/customers/presentation/bloc/customer_bloc.dart';
import '../../../features/maintenance/domain/entities/maintenance_request_entity.dart';
import '../../../features/maintenance/maintenance_feature.dart';
import '../../../features/maintenance/presentation/bloc/maintenance_bloc.dart';
import '../../../features/maintenance/presentation/pages/create_maintenance_request_page.dart';
import '../../../features/maintenance/presentation/pages/edit_maintenance_request_page.dart';
import '../../../features/maintenance/presentation/pages/maintenance_details_page.dart';
import '../../../features/maintenance/presentation/pages/maintenance_list_page.dart';
import '../../../features/maintenance/presentation/pages/maintenance_log_page.dart';
import '../../../features/maintenance/presentation/pages/maintenance_reports_page.dart';
import '../../../features/maintenance/presentation/pages/maintenance_settings_page.dart';
import '../route_guards/bloc_route_builder.dart';
import '../route_guards/permission_route_builder.dart';
import '../route_paths.dart';

/// مسارات الصيانة
Map<String, WidgetBuilder> get maintenanceRoutes => {
  RoutePaths.maintenanceList: (context) {
    final initialStatusFilter =
        ModalRoute.of(context)?.settings.arguments as String?;
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    MaintenanceFeature.ensureInitialized();

    return BlocProvider<MaintenanceBloc>(
      create: (context) => GetIt.instance<MaintenanceBloc>(),
      child: MaintenanceListPage(initialStatusFilter: initialStatusFilter),
    );
  },
  RoutePaths.maintenanceSettings: (context) => const MaintenanceSettingsPage(),
  RoutePaths.maintenanceReports: (context) => buildPermissionRoute(
    permission: 'maintenance_reports_view',
    blocProviders: [
      BlocProvider<MaintenanceBloc>(
        create: (context) {
          final user = FirebaseAuth.instance.currentUser;
          // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
          MaintenanceFeature.ensureInitialized();

          final bloc = GetIt.instance<MaintenanceBloc>();
          bloc.add(LoadMaintenanceRequestsEvent(user?.email ?? ''));
          return bloc;
        },
      ),
    ],
    child: const MaintenanceReportsPage(),
  ),
  RoutePaths.maintenanceLog: (context) {
    MaintenanceFeature.ensureInitialized();
    return BlocProvider<MaintenanceBloc>(
      create: (context) => GetIt.instance<MaintenanceBloc>(),
      child: const MaintenanceLogPage(),
    );
  },
};

/// مسارات الصيانة الديناميكية (تتطلب arguments)
Route<dynamic>? buildMaintenanceRoute(
  String routeName,
  RouteSettings settings,
) {
  final user = FirebaseAuth.instance.currentUser;

  switch (routeName) {
    case RoutePaths.createMaintenanceRequest:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      MaintenanceFeature.ensureInitialized();
      // CustomerFeature already initialized at app startup

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithMultiBloc(
          permission: 'maintenance_create',
          blocProviders: [
            BlocProvider<MaintenanceBloc>(
              create: (context) => GetIt.instance<MaintenanceBloc>(),
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
              )..add(LoadCustomersEvent(user?.email ?? '')),
            ),
          ],
          child: const CreateMaintenanceRequestPage(),
        ),
        settings: settings,
      );

    case RoutePaths.editMaintenanceRequest:
      final maintenanceRequest = settings.arguments;
      if (maintenanceRequest != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        MaintenanceFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'maintenance_edit',
            bloc: GetIt.instance<MaintenanceBloc>(),
            child: EditMaintenanceRequestPage(
              maintenanceRequest:
                  maintenanceRequest as MaintenanceRequestEntity,
            ),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.maintenanceDetails:
      final maintenance = settings.arguments;
      if (maintenance != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        MaintenanceFeature.ensureInitialized();

        final bloc = GetIt.instance<MaintenanceBloc>();
        bloc.add(LoadMaintenanceRequestsEvent(user?.email ?? ''));

        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: bloc,
            child: MaintenanceDetailsPage(
              maintenance: maintenance as MaintenanceRequestEntity,
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
