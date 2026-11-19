import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/reports/domain/entities/report_entity.dart';
import '../../../features/reports/injection_container.dart' show getIt;
import '../../../features/reports/presentation/bloc/cashbox_bloc.dart';
import '../../../features/reports/presentation/bloc/report_bloc.dart';
import '../../../features/reports/presentation/pages/cashbox_page.dart';
import '../../../features/reports/presentation/pages/cashbox_report_page.dart';
import '../../../features/reports/presentation/pages/create_report_page.dart';
import '../../../features/reports/presentation/pages/edit_report_page.dart';
import '../../../features/reports/presentation/pages/report_details_page.dart';
import '../../../features/reports/presentation/pages/reports_list_page.dart';
import '../../../features/reports/presentation/pages/reports_log_page.dart';
import '../../../features/reports/presentation/pages/reports_settings_page.dart';
import '../../../features/reports/report_feature.dart';
import '../route_guards/bloc_route_builder.dart';
import '../route_guards/permission_route_builder.dart';
import '../route_paths.dart';

/// مسارات التقارير
/// ⚠️ كل مسار ينشئ مثيلاً جديداً من ReportBloc عبر getIt().
/// هذا يضمن عزل الحالة بين المسارات، لكن قد يستهلك موارد إضافية
/// عند التنقل المتكرر بين الصفحات. يُنصح بمراجعة هذا النمط إذا
/// ظهرت مشاكل في حالة BLoC متضاربة.
Map<String, WidgetBuilder> get reportsRoutes => {
  RoutePaths.reportsList: (context) {
    final user = FirebaseAuth.instance.currentUser;
    final initialFilter = ModalRoute.of(context)?.settings.arguments as String?;
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    ReportFeature.ensureInitialized();

    return BlocProvider<ReportBloc>(
      create: (context) => ReportBloc(
        getReports: getIt(),
        getReportsStream: getIt(),
        getReportsStatsStream: getIt(),
        addReport: getIt(),
        updateReport: getIt(),
        deleteReport: getIt(),
        getReportStats: getIt(),
        getReportLogs: getIt(),
        repository: getIt(),
      )..add(LoadReportsEvent(user?.email ?? '')),
      child: ReportsListPage(initialFilter: initialFilter),
    );
  },
  RoutePaths.reportsSettings: (context) => const ReportsSettingsPage(),
  RoutePaths.reportsLog: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    ReportFeature.ensureInitialized();

    return BlocProvider<ReportBloc>(
      create: (context) => ReportBloc(
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
      child: const ReportsLogPage(),
    );
  },
  // مسارات الصندوق
  RoutePaths.cashbox: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    ReportFeature.ensureInitialized();

    return BlocProvider<CashboxBloc>(
      create: (context) => CashboxBloc(repository: getIt()),
      child: const CashboxPage(),
    );
  },
  RoutePaths.cashboxReport: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    ReportFeature.ensureInitialized();

    return BlocProvider<CashboxBloc>(
      create: (context) => CashboxBloc(repository: getIt()),
      child: const CashboxReportPage(),
    );
  },
};

/// مسارات التقارير الديناميكية (تتطلب arguments)
Route<dynamic>? buildReportRoute(String routeName, RouteSettings settings) {
  final user = FirebaseAuth.instance.currentUser;

  switch (routeName) {
    case RoutePaths.createReport:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      ReportFeature.ensureInitialized();

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'reports_create',
          bloc: ReportBloc(
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
          child: const CreateReportPage(),
        ),
        settings: settings,
      );

    case RoutePaths.reportDetails:
      final report = settings.arguments;
      if (report != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        ReportFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: ReportBloc(
              getReports: getIt(),
              getReportsStream: getIt(),
              getReportsStatsStream: getIt(),
              addReport: getIt(),
              updateReport: getIt(),
              deleteReport: getIt(),
              getReportStats: getIt(),
              getReportLogs: getIt(),
              repository: getIt(),
            )..add(LoadReportsEvent(user?.email ?? '')),
            child: ReportDetailsPage(report: report as ReportEntity),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.editReport:
      final report = settings.arguments;
      if (report != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        ReportFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'reports_edit',
            bloc: ReportBloc(
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
            child: EditReportPage(report: report as ReportEntity),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.reports:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      ReportFeature.ensureInitialized();

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'reports_view',
          bloc: ReportBloc(
            getReports: getIt(),
            getReportsStream: getIt(),
            getReportsStatsStream: getIt(),
            addReport: getIt(),
            updateReport: getIt(),
            deleteReport: getIt(),
            getReportStats: getIt(),
            getReportLogs: getIt(),
            repository: getIt(),
          )..add(LoadReportsEvent(user?.email ?? '')),
          child: const ReportsListPage(),
        ),
        settings: settings,
      );

    default:
      return null;
  }
}
