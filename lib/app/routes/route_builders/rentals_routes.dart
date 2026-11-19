import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../features/customers/customer_feature.dart';
import '../../../features/customers/injection_container.dart'
    as customer_injection;
import '../../../features/customers/presentation/bloc/customer_bloc.dart';
import '../../../features/rentals/domain/entities/rental_entity.dart';
import '../../../features/rentals/presentation/bloc/rental_bloc.dart';
import '../../../features/rentals/presentation/bloc/rental_unit_bloc.dart';
import '../../../features/rentals/presentation/pages/create_rental_page.dart';
import '../../../features/rentals/presentation/pages/create_rental_unit_page.dart';
import '../../../features/rentals/presentation/pages/edit_rental_page.dart';
import '../../../features/rentals/presentation/pages/rental_details_page.dart';
import '../../../features/rentals/presentation/pages/rental_units_list_page.dart';
import '../../../features/rentals/presentation/pages/rentals_list_page.dart';
import '../../../features/rentals/presentation/pages/rentals_reports_page.dart';
import '../../../features/rentals/presentation/pages/rentals_settings_page.dart';
import '../../../features/rentals/rental_feature.dart';
import '../route_guards/bloc_route_builder.dart';
import '../route_guards/permission_route_builder.dart';
import '../route_paths.dart';

/// مسارات الإيجارات
Map<String, WidgetBuilder> get rentalsRoutes => {
  RoutePaths.rentalsList: (context) {
    final user = FirebaseAuth.instance.currentUser;
    final initialFilter = ModalRoute.of(context)?.settings.arguments as String?;
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    RentalFeature.ensureInitialized();

    return BlocProvider<RentalBloc>(
      create: (context) => RentalBloc(
        getRentals: GetIt.instance(),
        getRentalsStream: GetIt.instance(),
        getRentalsStatsStream: GetIt.instance(),
        createRental: GetIt.instance(),
        updateRental: GetIt.instance(),
        getRentalStats: GetIt.instance(),
        getRentalLogsStream: GetIt.instance(),
        repository: GetIt.instance(),
      )..add(LoadRentalsEvent(user?.email ?? '')),
      child: RentalsListPage(initialFilter: initialFilter),
    );
  },
  RoutePaths.rentalUnits: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    RentalFeature.ensureInitialized();

    return BlocProvider<RentalUnitBloc>(
      create: (context) => RentalUnitBloc(
        getRentalUnits: GetIt.instance(),
        getRentalUnitsStream: GetIt.instance(),
        getAvailableRentalUnits: GetIt.instance(),
        createRentalUnit: GetIt.instance(),
        updateRentalUnit: GetIt.instance(),
        deleteRentalUnit: GetIt.instance(),
        repository: GetIt.instance(),
      ),
      child: const RentalUnitsListPage(),
    );
  },
  RoutePaths.rentalsSettings: (context) => const RentalsSettingsPage(),
  RoutePaths.rentalsReports: (context) => buildPermissionRoute(
    permission: 'reports_view',
    blocProviders: [
      BlocProvider<RentalBloc>(
        create: (context) {
          final user = FirebaseAuth.instance.currentUser;
          // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
          RentalFeature.ensureInitialized();

          return RentalBloc(
            getRentals: GetIt.instance(),
            getRentalsStream: GetIt.instance(),
            getRentalsStatsStream: GetIt.instance(),
            createRental: GetIt.instance(),
            updateRental: GetIt.instance(),
            getRentalStats: GetIt.instance(),
            getRentalLogsStream: GetIt.instance(),
            repository: GetIt.instance(),
          )..add(LoadRentalsEvent(user?.email ?? ''));
        },
      ),
    ],
    child: const RentalsReportsPage(),
  ),
};

/// مسارات الإيجارات الديناميكية (تتطلب arguments)
Route<dynamic>? buildRentalRoute(String routeName, RouteSettings settings) {
  final user = FirebaseAuth.instance.currentUser;

  switch (routeName) {
    case RoutePaths.createRental:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      RentalFeature.ensureInitialized();
      // CustomerFeature already initialized at app startup

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithMultiBloc(
          permission: 'rentals_create',
          blocProviders: [
            BlocProvider<RentalBloc>(
              create: (context) => RentalBloc(
                getRentals: GetIt.instance(),
                getRentalsStream: GetIt.instance(),
                getRentalsStatsStream: GetIt.instance(),
                createRental: GetIt.instance(),
                updateRental: GetIt.instance(),
                getRentalStats: GetIt.instance(),
                getRentalLogsStream: GetIt.instance(),
                repository: GetIt.instance(),
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
              )..add(LoadCustomersEvent(user?.email ?? '')),
            ),
            BlocProvider<RentalUnitBloc>(
              create: (context) => RentalUnitBloc(
                getRentalUnits: GetIt.instance(),
                getRentalUnitsStream: GetIt.instance(),
                getAvailableRentalUnits: GetIt.instance(),
                createRentalUnit: GetIt.instance(),
                updateRentalUnit: GetIt.instance(),
                deleteRentalUnit: GetIt.instance(),
                repository: GetIt.instance(),
              ),
            ),
          ],
          child: const CreateRentalPage(),
        ),
        settings: settings,
      );

    case RoutePaths.createRentalUnit:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      RentalFeature.ensureInitialized();

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'rentals_create',
          bloc: RentalUnitBloc(
            getRentalUnits: GetIt.instance(),
            getRentalUnitsStream: GetIt.instance(),
            getAvailableRentalUnits: GetIt.instance(),
            createRentalUnit: GetIt.instance(),
            updateRentalUnit: GetIt.instance(),
            deleteRentalUnit: GetIt.instance(),
            repository: GetIt.instance(),
          ),
          child: const CreateRentalUnitPage(),
        ),
        settings: settings,
      );

    case RoutePaths.editRental:
      final rental = settings.arguments;
      if (rental != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        RentalFeature.ensureInitialized();
        // CustomerFeature already initialized at app startup

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithMultiBloc(
            permission: 'rentals_edit',
            blocProviders: [
              BlocProvider<RentalBloc>(
                create: (context) => RentalBloc(
                  getRentals: GetIt.instance(),
                  getRentalsStream: GetIt.instance(),
                  getRentalsStatsStream: GetIt.instance(),
                  createRental: GetIt.instance(),
                  updateRental: GetIt.instance(),
                  getRentalStats: GetIt.instance(),
                  getRentalLogsStream: GetIt.instance(),
                  repository: GetIt.instance(),
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
                )..add(LoadCustomersEvent(user?.email ?? '')),
              ),
            ],
            child: EditRentalPage(rental: rental as RentalEntity),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.rentalDetails:
      final rental = settings.arguments;
      if (rental != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        RentalFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: RentalBloc(
              getRentals: GetIt.instance(),
              getRentalsStream: GetIt.instance(),
              getRentalsStatsStream: GetIt.instance(),
              createRental: GetIt.instance(),
              updateRental: GetIt.instance(),
              getRentalStats: GetIt.instance(),
              getRentalLogsStream: GetIt.instance(),
              repository: GetIt.instance(),
            )..add(LoadRentalsEvent(user?.email ?? '')),
            child: RentalDetailsPage(rental: rental as RentalEntity),
          ),
          settings: settings,
        );
      }
      return null;

    default:
      return null;
  }
}
