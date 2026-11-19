import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'injection_container.dart' as di;
import 'presentation/bloc/expense_bloc.dart';
import 'presentation/pages/expense_dashboard_page.dart';

/// ميزة المصاريف - مع التهيئة الكسولة
// ignore: avoid_classes_with_only_static_members
class ExpenseFeature {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// تهيئة ميزة المصاريف
  static Future<void> init() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    await di.initExpenses();

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
          GetIt.instance<ExpenseBloc>()
            ..add(LoadExpensesEvent(organizationEmail)),
      child: ExpenseDashboardPage(organizationEmail: organizationEmail),
    );
  }

  /// هل القسم مهيأ؟
  static bool get isInitialized => _isInitialized;
}
