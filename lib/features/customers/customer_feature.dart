import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'injection_container.dart';
import 'presentation/bloc/customer_bloc.dart';
import 'presentation/pages/customer_dashboard_page.dart';

/// نقطة دخول ميزة العملاء - مع التهيئة الكسولة
// ignore: avoid_classes_with_only_static_members
class CustomerFeature {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// تهيئة القسم - تُستدعى مرة واحدة فقط
  static Future<void> init() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    await initCustomers();

    _isInitialized = true;
    _isInitializing = false;
  }

  /// التأكد من تهيئة القسم - للتهيئة الكسولة
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await init();
  }

  /// الحصول على صفحة الداشبورد مع التهيئة الكسولة
  static Future<Widget> getDashboardPage(String organizationEmail) async {
    await ensureInitialized();
    return BlocProvider(
      create: (context) => getIt<CustomerBloc>(),
      child: CustomerDashboardPage(organizationEmail: organizationEmail),
    );
  }

  /// هل القسم مهيأ؟
  static bool get isInitialized => _isInitialized;
}
