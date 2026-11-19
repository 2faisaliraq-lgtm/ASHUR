import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'data/repositories/rental_repository_impl.dart';
import 'data/repositories/rental_unit_repository_impl.dart';
import 'domain/repositories/rental_repository.dart';
import 'domain/repositories/rental_unit_repository.dart';
import 'domain/usecases/create_rental.dart';
import 'domain/usecases/create_rental_unit.dart';
import 'domain/usecases/delete_rental_unit.dart';
import 'domain/usecases/get_available_rental_units.dart';
import 'domain/usecases/get_rental_logs_stream.dart';
import 'domain/usecases/get_rental_stats.dart';
import 'domain/usecases/get_rental_units.dart';
import 'domain/usecases/get_rental_units_stream.dart';
import 'domain/usecases/get_rentals.dart';
import 'domain/usecases/get_rentals_stats_stream.dart';
import 'domain/usecases/get_rentals_stream.dart';
import 'domain/usecases/update_rental.dart';
import 'domain/usecases/update_rental_unit.dart';
import 'presentation/bloc/rental_bloc.dart';
import 'presentation/bloc/rental_unit_bloc.dart';

Future<void> initRentalDependencies() async {
  final sl = GetIt.instance;

  if (!sl.isRegistered<RentalBloc>()) {
    sl.registerFactory(
      () => RentalBloc(
        getRentals: sl(),
        getRentalsStream: sl(),
        getRentalsStatsStream: sl(),
        createRental: sl(),
        updateRental: sl(),
        getRentalStats: sl(),
        getRentalLogsStream: sl(),
        repository: sl(),
      ),
    );
  }

  if (!sl.isRegistered<RentalUnitBloc>()) {
    sl.registerFactory(
      () => RentalUnitBloc(
        getRentalUnits: sl(),
        getRentalUnitsStream: sl(),
        getAvailableRentalUnits: sl(),
        createRentalUnit: sl(),
        updateRentalUnit: sl(),
        deleteRentalUnit: sl(),
        repository: sl(),
      ),
    );
  }

  if (!sl.isRegistered<GetRentals>()) {
    sl.registerLazySingleton(() => GetRentals(sl()));
  }
  if (!sl.isRegistered<GetRentalsStream>()) {
    sl.registerLazySingleton(() => GetRentalsStream(sl()));
  }
  if (!sl.isRegistered<GetRentalsStatsStream>()) {
    sl.registerLazySingleton(() => GetRentalsStatsStream(sl()));
  }
  if (!sl.isRegistered<CreateRental>()) {
    sl.registerLazySingleton(() => CreateRental(sl()));
  }
  if (!sl.isRegistered<UpdateRental>()) {
    sl.registerLazySingleton(() => UpdateRental(sl()));
  }
  if (!sl.isRegistered<GetRentalStats>()) {
    sl.registerLazySingleton(() => GetRentalStats(sl()));
  }
  if (!sl.isRegistered<GetRentalLogsStream>()) {
    sl.registerLazySingleton(() => GetRentalLogsStream(sl()));
  }

  if (!sl.isRegistered<GetRentalUnits>()) {
    sl.registerLazySingleton(() => GetRentalUnits(sl()));
  }
  if (!sl.isRegistered<GetRentalUnitsStream>()) {
    sl.registerLazySingleton(() => GetRentalUnitsStream(sl()));
  }
  if (!sl.isRegistered<GetAvailableRentalUnits>()) {
    sl.registerLazySingleton(() => GetAvailableRentalUnits(sl()));
  }
  if (!sl.isRegistered<CreateRentalUnit>()) {
    sl.registerLazySingleton(() => CreateRentalUnit(sl()));
  }
  if (!sl.isRegistered<UpdateRentalUnit>()) {
    sl.registerLazySingleton(() => UpdateRentalUnit(sl()));
  }
  if (!sl.isRegistered<DeleteRentalUnit>()) {
    sl.registerLazySingleton(() => DeleteRentalUnit(sl()));
  }

  if (!sl.isRegistered<RentalRepository>()) {
    sl.registerLazySingleton<RentalRepository>(
      () => RentalRepositoryImpl(firestore: sl<FirebaseFirestore>()),
    );
  }

  if (!sl.isRegistered<RentalUnitRepository>()) {
    sl.registerLazySingleton<RentalUnitRepository>(
      () => RentalUnitRepositoryImpl(firestore: sl<FirebaseFirestore>()),
    );
  }
}
