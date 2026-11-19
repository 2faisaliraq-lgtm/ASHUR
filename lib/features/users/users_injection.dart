import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

// Data Layer
import 'data/repositories/users_repository_impl.dart';
// Domain Layer
import 'domain/repositories/users_repository.dart';
import 'domain/usecases/create_user_usecase.dart';
import 'domain/usecases/delete_user_usecase.dart';
import 'domain/usecases/get_roles_stream.dart';
import 'domain/usecases/get_roles_usecase.dart';
import 'domain/usecases/get_user_logs.dart';
import 'domain/usecases/get_users_paginated.dart';
import 'domain/usecases/get_users_stats_stream.dart';
import 'domain/usecases/get_users_stream.dart';
import 'domain/usecases/get_users_usecase.dart';
import 'domain/usecases/update_user_usecase.dart';
// Presentation Layer
import 'presentation/bloc/users_bloc.dart';

final sl = GetIt.instance;

/// تهيئة حقن التبعيات لقسم المستخدمين
Future<void> initUsersInjection() async {
  // Bloc
  sl.registerFactory(
    () => UsersBloc(
      getUsersUseCase: sl(),
      getUsersPaginated: sl(),
      getUsersStream: sl(),
      getUsersStatsStream: sl(),
      getRolesStream: sl(),
      createUserUseCase: sl(),
      updateUserUseCase: sl(),
      deleteUserUseCase: sl(),
      getRolesUseCase: sl(),
      getUserLogs: sl(),
      repository: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetUsersUseCase(sl()));
  sl.registerLazySingleton(() => GetUsersPaginated(sl()));
  sl.registerLazySingleton(() => GetUsersStream(sl()));
  sl.registerLazySingleton(() => GetUsersStatsStream(sl()));
  sl.registerLazySingleton(() => GetRolesStream(sl()));
  sl.registerLazySingleton(() => CreateUserUseCase(sl()));
  sl.registerLazySingleton(() => UpdateUserUseCase(sl()));
  sl.registerLazySingleton(() => DeleteUserUseCase(sl()));
  sl.registerLazySingleton(() => GetRolesUseCase(sl()));
  sl.registerLazySingleton(() => GetUserLogs(sl()));

  // Repository
  sl.registerLazySingleton<UsersRepository>(
    () => UsersRepositoryImpl(
      firestore: sl<FirebaseFirestore>(),
      auth: sl<FirebaseAuth>(),
    ),
  );
}
