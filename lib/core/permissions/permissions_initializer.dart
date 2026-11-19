import 'permissions_manager.dart';

/// مهيئ الصلاحيات
/// يقوم بتهيئة جميع صلاحيات التطبيق عند البدء
// ignore: avoid_classes_with_only_static_members
class PermissionsInitializer {
  static bool _initialized = false;

  /// تهيئة نظام الصلاحيات
  static void initialize() {
    if (_initialized) return;

    // تهيئة مدير الصلاحيات
    final permissionsManager = PermissionsManager();
    permissionsManager.initialize();

    _initialized = true;
  }

  /// التحقق من حالة التهيئة
  static bool get isInitialized => _initialized;

  /// إعادة تعيين حالة التهيئة (للاختبار)
  static void reset() {
    _initialized = false;
    PermissionsManager().reset();
  }
}
