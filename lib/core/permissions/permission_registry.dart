import '../../features/users/domain/entities/permission_entity.dart';

/// سجل الصلاحيات المركزي
/// يجمع جميع الصلاحيات من أقسام التطبيق المختلفة
class PermissionRegistry {
  factory PermissionRegistry() => _instance;
  PermissionRegistry._internal();
  static final PermissionRegistry _instance = PermissionRegistry._internal();

  final Map<String, List<PermissionEntity>> _permissions = {};

  /// تسجيل صلاحيات قسم معين
  void registerPermissions(String section, List<PermissionEntity> permissions) {
    _permissions[section] = permissions;
  }

  /// الحصول على جميع الصلاحيات
  List<PermissionEntity> getAllPermissions() {
    final allPermissions = <PermissionEntity>[];
    for (final permissions in _permissions.values) {
      allPermissions.addAll(permissions);
    }
    return allPermissions;
  }

  /// الحصول على صلاحيات قسم معين
  List<PermissionEntity> getPermissionsBySection(String section) {
    return _permissions[section] ?? [];
  }

  /// الحصول على جميع الأقسام
  List<String> getSections() {
    return _permissions.keys.toList();
  }

  /// مسح جميع الصلاحيات (للاختبار)
  void clear() {
    _permissions.clear();
  }
}
