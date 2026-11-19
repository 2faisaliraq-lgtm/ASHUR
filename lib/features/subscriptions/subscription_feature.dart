import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'injection_container.dart' as di;
import 'presentation/bloc/subscription_bloc.dart';
import 'presentation/pages/subscription_dashboard_page.dart';

/// نقطة دخول ميزة الاشتراكات - مع التهيئة الكسولة
// ignore: avoid_classes_with_only_static_members
class SubscriptionFeature {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// تهيئة ميزة الاشتراكات
  static Future<void> init() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    await di.initSubscriptionDependencies();

    _isInitialized = true;
    _isInitializing = false;
  }

  /// التأكد من تهيئة القسم - للتهيئة الكسولة
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await init();
  }

  /// الحصول على صفحة لوحة تحكم الاشتراكات مع التهيئة الكسولة
  static Future<Widget> getDashboardPage({
    required String organizationEmail,
  }) async {
    await ensureInitialized();
    return BlocProvider(
      create: (context) => GetIt.instance<SubscriptionBloc>(),
      child: SubscriptionDashboardPage(organizationEmail: organizationEmail),
    );
  }

  /// هل القسم مهيأ؟
  static bool get isInitialized => _isInitialized;
}
