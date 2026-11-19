import '../../features/customers/domain/permissions/customers_permissions.dart';
import '../../features/dashboard/domain/permissions/dashboard_permissions.dart';
import '../../features/expenses/domain/permissions/expenses_permissions.dart';
import '../../features/inventory/domain/permissions/inventory_permissions.dart';
import '../../features/invoices/domain/permissions/invoices_permissions.dart';
import '../../features/maintenance/domain/permissions/maintenance_permissions.dart';
import '../../features/rentals/domain/permissions/rentals_permissions.dart';
import '../../features/reports/domain/permissions/reports_permissions.dart';
import '../../features/settings/domain/permissions/settings_permissions.dart';
import '../../features/subscriptions/domain/permissions/subscriptions_permissions.dart';
import '../../features/users/domain/entities/permission_entity.dart';
// استيراد جميع صلاحيات الأقسام
import '../../features/users/domain/permissions/users_permissions.dart';
import 'permission_registry.dart';

/// مدير الصلاحيات المركزي
/// يقوم بتسجيل وإدارة جميع صلاحيات أقسام التطبيق
class PermissionsManager {
  factory PermissionsManager() => _instance;
  PermissionsManager._internal();
  static final PermissionsManager _instance = PermissionsManager._internal();

  final PermissionRegistry _registry = PermissionRegistry();
  bool _initialized = false;

  /// تهيئة جميع صلاحيات الأقسام
  void initialize() {
    if (_initialized) return;

    // قائمة جميع أقسام التطبيق
    final sections = [
      UsersPermissions(),
      DashboardPermissions(),
      CustomersPermissions(),
      InventoryPermissions(),
      InvoicesPermissions(),
      RentalsPermissions(),
      ExpensesPermissions(),
      MaintenancePermissions(),
      SubscriptionsPermissions(),
      ReportsPermissions(),
      SettingsPermissions(),
    ];

    // تسجيل صلاحيات كل قسم
    for (final section in sections) {
      _registry.registerPermissions(
        section.sectionName,
        section.getPermissions(),
      );
    }

    _initialized = true;
  }

  /// الحصول على جميع الصلاحيات
  List<PermissionEntity> getAllPermissions() {
    initialize();
    return _registry.getAllPermissions();
  }

  /// الحصول على صلاحيات قسم معين
  List<PermissionEntity> getPermissionsBySection(String section) {
    initialize();
    return _registry.getPermissionsBySection(section);
  }

  /// الحصول على جميع الأقسام
  List<String> getSections() {
    initialize();
    return _registry.getSections();
  }

  /// البحث عن صلاحية بالمعرف
  PermissionEntity? getPermissionById(String id) {
    initialize();
    final allPermissions = _registry.getAllPermissions();
    try {
      return allPermissions.firstWhere((p) => p.id == id);
    } on Exception catch (_) {
      return null;
    }
  }

  /// البحث عن صلاحيات بالاسم أو الوصف
  List<PermissionEntity> searchPermissions(String query) {
    initialize();
    final allPermissions = _registry.getAllPermissions();
    final lowerQuery = query.toLowerCase();

    return allPermissions.where((permission) {
      return permission.displayName.toLowerCase().contains(lowerQuery) ||
          (permission.description?.toLowerCase().contains(lowerQuery) ??
              false) ||
          permission.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// الحصول على إحصائيات الصلاحيات
  Map<String, int> getPermissionsStatistics() {
    initialize();
    final sections = _registry.getSections();
    final stats = <String, int>{};

    for (final section in sections) {
      stats[section] = _registry.getPermissionsBySection(section).length;
    }

    return stats;
  }

  /// التحقق من وجود صلاحية
  bool hasPermission(String permissionId) {
    return getPermissionById(permissionId) != null;
  }

  /// إعادة تعيين المدير (للاختبار)
  void reset() {
    _registry.clear();
    _initialized = false;
  }
}
