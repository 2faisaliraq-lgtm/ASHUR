import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'injection_container.dart' as di;
import 'presentation/bloc/report_bloc.dart';
import 'presentation/pages/report_dashboard_page.dart';

/// ميزة التقارير - مع التهيئة الكسولة
// ignore: avoid_classes_with_only_static_members
class ReportFeature {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// تهيئة ميزة التقارير
  static Future<void> init() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    await di.initReports();

    _isInitialized = true;
    _isInitializing = false;
  }

  /// التأكد من تهيئة القسم - للتهيئة الكسولة
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await init();
  }

  /// إنشاء صفحة لوحة التحكم مع التهيئة الكسولة
  // ignore: cascade_invitations
  static Future<Widget> createDashboard(String organizationEmail) async {
    await ensureInitialized();
    return BlocProvider(
      create: (context) =>
          GetIt.instance<ReportBloc>()
            ..add(LoadReportsEvent(organizationEmail)),
      child: ReportDashboardPage(organizationEmail: organizationEmail),
    );
  }

  /// هل القسم مهيأ؟
  static bool get isInitialized => _isInitialized;
}
