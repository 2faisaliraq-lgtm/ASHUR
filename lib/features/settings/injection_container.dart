import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'data/repositories/setting_repository_impl.dart';
import 'domain/repositories/setting_repository.dart';
import 'domain/usecases/create_setting.dart';
import 'domain/usecases/delete_setting.dart';
import 'domain/usecases/get_setting_by_key.dart';
import 'domain/usecases/get_settings.dart';
import 'domain/usecases/get_settings_by_category.dart';
import 'domain/usecases/get_settings_stats_stream.dart';
import 'domain/usecases/get_settings_stream.dart';
import 'domain/usecases/update_setting.dart';
import 'presentation/bloc/setting_bloc.dart';

final sl = GetIt.instance;

Future<void> initSettingFeature() async {
  // BLoC
  sl.registerFactory(
    () => SettingBloc(
      getSettings: sl(),
      createSetting: sl(),
      updateSetting: sl(),
      deleteSetting: sl(),
      getSettingByKey: sl(),
      getSettingsByCategory: sl(),
      getSettingsStream: sl(),
      getSettingsStatsStream: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetSettings(sl()));
  sl.registerLazySingleton(() => CreateSetting(sl()));
  sl.registerLazySingleton(() => UpdateSetting(sl()));
  sl.registerLazySingleton(() => DeleteSetting(sl()));
  sl.registerLazySingleton(() => GetSettingByKey(sl()));
  sl.registerLazySingleton(() => GetSettingsByCategory(sl()));
  sl.registerLazySingleton(() => GetSettingsStream(sl()));
  sl.registerLazySingleton(() => GetSettingsStatsStream(sl()));

  // Repository
  sl.registerLazySingleton<SettingRepository>(
    () => SettingRepositoryImpl(firestore: sl<FirebaseFirestore>()),
  );
}
