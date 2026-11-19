import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'data/repositories/customer_repository_impl.dart';
import 'domain/repositories/customer_repository.dart';
import 'domain/usecases/add_customer.dart';
import 'domain/usecases/add_customer_with_opening_balance.dart';
import 'domain/usecases/delete_customer.dart';
import 'domain/usecases/get_customer_logs.dart';
import 'domain/usecases/get_customer_stats.dart';
import 'domain/usecases/get_customer_stats_stream.dart';
import 'domain/usecases/get_customers.dart';
import 'domain/usecases/get_customers_paginated.dart';
import 'domain/usecases/get_customers_stream.dart';
import 'domain/usecases/update_customer.dart';
import 'presentation/bloc/customer_bloc.dart';

final getIt = GetIt.instance;

Future<void> initCustomers() async {
  // Repository
  getIt.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(firestore: getIt<FirebaseFirestore>()),
  );

  // Use Cases
  getIt.registerLazySingleton(() => GetCustomers(getIt()));
  getIt.registerLazySingleton(() => GetCustomersPaginated(getIt()));
  getIt.registerLazySingleton(() => GetCustomersStream(getIt())); // جديد
  getIt.registerLazySingleton(() => GetCustomerStatsStream(getIt())); // جديد
  getIt.registerLazySingleton(() => AddCustomer(getIt()));
  getIt.registerLazySingleton(() => AddCustomerWithOpeningBalance(getIt()));
  getIt.registerLazySingleton(() => UpdateCustomer(getIt()));
  getIt.registerLazySingleton(() => DeleteCustomer(getIt()));
  getIt.registerLazySingleton(() => GetCustomerStats(getIt()));
  getIt.registerLazySingleton(() => GetCustomerLogs(getIt()));

  // BLoC
  getIt.registerFactory(
    () => CustomerBloc(
      getCustomers: getIt(),
      getCustomersPaginated: getIt(),
      getCustomersStream: getIt(), // جديد
      getCustomerStatsStream: getIt(), // جديد
      addCustomer: getIt(),
      addCustomerWithOpeningBalance: getIt(),
      updateCustomer: getIt(),
      deleteCustomer: getIt(),
      getCustomerStats: getIt(),
      getCustomerLogs: getIt(),
      repository: getIt(),
    ),
  );
}
