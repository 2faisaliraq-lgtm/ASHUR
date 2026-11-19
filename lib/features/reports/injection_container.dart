import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'data/repositories/report_repository_impl.dart';
import 'domain/repositories/report_repository.dart';
import 'domain/usecases/add_report.dart';
import 'domain/usecases/delete_report.dart';
import 'domain/usecases/get_report_logs.dart';
import 'domain/usecases/get_report_stats.dart';
import 'domain/usecases/get_reports.dart';
import 'domain/usecases/get_reports_stats_stream.dart';
import 'domain/usecases/get_reports_stream.dart';
import 'domain/usecases/update_report.dart';
import 'presentation/bloc/cashbox_bloc.dart';
import 'presentation/bloc/report_bloc.dart';

final getIt = GetIt.instance;

Future<void> initReports() async {
  // Repository
  getIt.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(firestore: getIt<FirebaseFirestore>()),
  );

  // Use Cases
  getIt.registerLazySingleton(() => GetReports(getIt()));
  getIt.registerLazySingleton(() => GetReportsStream(getIt()));
  getIt.registerLazySingleton(() => GetReportsStatsStream(getIt()));
  getIt.registerLazySingleton(() => AddReport(getIt()));
  getIt.registerLazySingleton(() => UpdateReport(getIt()));
  getIt.registerLazySingleton(() => DeleteReport(getIt()));
  getIt.registerLazySingleton(() => GetReportStats(getIt()));
  getIt.registerLazySingleton(() => GetReportLogs(getIt()));

  // BLoC
  getIt.registerFactory(
    () => ReportBloc(
      getReports: getIt(),
      getReportsStream: getIt(),
      getReportsStatsStream: getIt(),
      addReport: getIt(),
      updateReport: getIt(),
      deleteReport: getIt(),
      getReportStats: getIt(),
      getReportLogs: getIt(),
      repository: getIt(),
    ),
  );

  // Cashbox BLoC
  getIt.registerFactory(() => CashboxBloc(repository: getIt()));
}
