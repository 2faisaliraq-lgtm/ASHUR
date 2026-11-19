import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'data/repositories/maintenance_repository_impl.dart';
import 'domain/repositories/maintenance_repository.dart';
import 'domain/usecases/check_maintenance_permission.dart';
import 'domain/usecases/create_maintenance_request.dart';
import 'domain/usecases/get_equipment.dart';
import 'domain/usecases/get_equipment_stream.dart';
import 'domain/usecases/get_maintenance_logs_stream.dart';
import 'domain/usecases/get_maintenance_requests.dart';
import 'domain/usecases/get_maintenance_stats.dart';
import 'domain/usecases/get_maintenance_stats_stream.dart';
import 'domain/usecases/get_maintenance_stream.dart';
import 'domain/usecases/update_maintenance_request.dart';
import 'presentation/bloc/maintenance_bloc.dart';

/// تهيئة حاوية الحقن للصيانة
Future<void> initMaintenanceDependencies() async {
  final sl = GetIt.instance;

  // BLoC
  if (!sl.isRegistered<MaintenanceBloc>()) {
    sl.registerFactory(
      () => MaintenanceBloc(
        getMaintenanceRequests: sl(),
        getMaintenanceStream: sl(),
        getMaintenanceStatsStream: sl(),
        createMaintenanceRequest: sl(),
        updateMaintenanceRequest: sl(),
        getEquipment: sl(),
        getEquipmentStream: sl(),
        getMaintenanceLogsStream: sl(),
        getMaintenanceStats: sl(),
        checkPermission: sl(),
        repository: sl(),
      ),
    );
  }

  // Use cases
  if (!sl.isRegistered<GetMaintenanceRequests>()) {
    sl.registerLazySingleton(() => GetMaintenanceRequests(sl()));
  }
  if (!sl.isRegistered<GetMaintenanceStream>()) {
    sl.registerLazySingleton(() => GetMaintenanceStream(sl()));
  }
  if (!sl.isRegistered<GetMaintenanceStatsStream>()) {
    sl.registerLazySingleton(() => GetMaintenanceStatsStream(sl()));
  }
  if (!sl.isRegistered<CreateMaintenanceRequest>()) {
    sl.registerLazySingleton(() => CreateMaintenanceRequest(sl()));
  }
  if (!sl.isRegistered<UpdateMaintenanceRequest>()) {
    sl.registerLazySingleton(() => UpdateMaintenanceRequest(sl()));
  }
  if (!sl.isRegistered<GetEquipment>()) {
    sl.registerLazySingleton(() => GetEquipment(sl()));
  }
  if (!sl.isRegistered<GetEquipmentStream>()) {
    sl.registerLazySingleton(() => GetEquipmentStream(sl()));
  }
  if (!sl.isRegistered<GetMaintenanceLogsStream>()) {
    sl.registerLazySingleton(() => GetMaintenanceLogsStream(sl()));
  }
  if (!sl.isRegistered<GetMaintenanceStats>()) {
    sl.registerLazySingleton(() => GetMaintenanceStats(sl()));
  }
  if (!sl.isRegistered<CheckMaintenancePermission>()) {
    sl.registerLazySingleton(CheckMaintenancePermission.new);
  }

  // Repository
  if (!sl.isRegistered<MaintenanceRepository>()) {
    sl.registerLazySingleton<MaintenanceRepository>(
      () => MaintenanceRepositoryImpl(firestore: sl<FirebaseFirestore>()),
    );
  }
}
