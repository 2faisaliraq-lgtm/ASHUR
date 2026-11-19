import 'package:material_ui/material_ui.dart';

/// عنصر التنقل في الشريط السفلي
class NavigationItem {
  const NavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.page,
    this.activeIcon,
    this.requiredPermissions,
    this.color,
  });
  final String id;
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final Widget page;
  final List<String>? requiredPermissions;
  final Color? color;

  /// التحقق من إمكانية الوصول لهذا العنصر
  bool canAccess(List<String> userPermissions) {
    if (requiredPermissions == null || requiredPermissions!.isEmpty) {
      return true;
    }

    return requiredPermissions!.any(
      (permission) => userPermissions.contains(permission),
    );
  }
}

/// عناصر التنقل الافتراضية
// ignore: avoid_classes_with_only_static_members
class DefaultNavigationItems {
  static const String dashboard = 'dashboard';
  static const String users = 'users';
  static const String customers = 'customers';
  static const String inventory = 'inventory';
  static const String subscriptions = 'subscriptions';
  static const String maintenance = 'maintenance';
  static const String rentals = 'rentals';
  static const String invoices = 'invoices';
  static const String expenses = 'expenses';
  static const String reports = 'reports';
  static const String settings = 'settings';
}
