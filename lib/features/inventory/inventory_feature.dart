import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'injection_container.dart' as di;
import 'presentation/bloc/inventory_bloc.dart';
import 'presentation/pages/inventory_dashboard_page.dart';

/// نقطة دخول ميزة المخزون - مع التهيئة الكسولة
// ignore: avoid_classes_with_only_static_members
class InventoryFeature {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// تهيئة ميزة المخزون
  static Future<void> init() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    await di.initInventoryDependencies();

    _isInitialized = true;
    _isInitializing = false;
  }

  /// التأكد من تهيئة القسم - للتهيئة الكسولة
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await init();
  }

  /// الحصول على صفحة لوحة تحكم المخزون مع التهيئة الكسولة
  static Future<Widget> getDashboardPage({
    required String organizationEmail,
  }) async {
    await ensureInitialized();
    return BlocProvider(
      create: (context) => di.sl<InventoryBloc>(),
      child: InventoryDashboardPage(organizationEmail: organizationEmail),
    );
  }

  /// هل القسم مهيأ؟
  static bool get isInitialized => _isInitialized;
}
