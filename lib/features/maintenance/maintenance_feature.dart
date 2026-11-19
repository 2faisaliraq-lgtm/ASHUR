import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'injection_container.dart';
import 'presentation/bloc/maintenance_bloc.dart';
import 'presentation/pages/maintenance_dashboard_page.dart';

/// ميزة الصيانة - مع التهيئة الكسولة
// ignore: avoid_classes_with_only_static_members
class MaintenanceFeature {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  static Future<void> init() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      await initMaintenanceDependencies();

      _isInitialized = true;
    } finally {
      _isInitializing = false;
    }
  }

  /// التأكد من تهيئة القسم - للتهيئة الكسولة
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await init();
  }

  static Future<Widget> getDashboardPage(String organizationEmail) async {
    await ensureInitialized();
    return BlocProvider(
      create: (context) => GetIt.instance<MaintenanceBloc>(),
      child: MaintenanceDashboardPage(organizationEmail: organizationEmail),
    );
  }

  /// هل القسم مهيأ؟
  static bool get isInitialized => _isInitialized;
}
