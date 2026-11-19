import 'package:hive/hive.dart';

/// خدمة إدارة إعدادات رمز الوصول للأدوار
// ignore: avoid_classes_with_only_static_members
class RoleRequestSettingsService {
  static const String _boxName = 'role_access_code_settings';
  static const String _enabledKey = 'access_code_enabled';

  static Box<bool>? _box;
  static bool _isInitialized = false;

  /// تهيئة الخدمة
  static Future<void> initialize() async {
    try {
      if (!_isInitialized) {
        _box = await Hive.openBox<bool>(_boxName);
        _isInitialized = true;
      }
    } on Exception catch (_) {
      _box = null;
      _isInitialized = false;
    }
  }

  /// التأكد من التهيئة
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized || _box == null) {
      await initialize();
    }
  }

  /// تفعيل شاشة رمز الوصول
  static Future<void> enableAccessCodeScreen() async {
    try {
      await _ensureInitialized();
      await _box?.put(_enabledKey, true);
    } on Exception catch (_) {
      rethrow;
    }
  }

  /// تعطيل شاشة رمز الوصول
  static Future<void> disableAccessCodeScreen() async {
    try {
      await _ensureInitialized();
      await _box?.put(_enabledKey, false);
    } on Exception catch (_) {
      rethrow;
    }
  }

  /// التحقق من حالة تفعيل شاشة رمز الوصول
  static Future<bool> isAccessCodeScreenEnabled() async {
    try {
      await _ensureInitialized();
      final result = _box?.get(_enabledKey, defaultValue: true) ?? true;
      return result;
    } on Exception catch (_) {
      return true; // القيمة الافتراضية
    }
  }

  /// التحقق من حالة تفعيل شاشة رمز الوصول (متزامن)
  static bool isAccessCodeScreenEnabledSync() {
    try {
      if (!_isInitialized || _box == null) {
        return true; // القيمة الافتراضية
      }
      final result = _box?.get(_enabledKey, defaultValue: true) ?? true;
      return result;
    } on Exception catch (_) {
      return true; // القيمة الافتراضية
    }
  }

  /// تبديل حالة شاشة رمز الوصول
  static Future<bool> toggleAccessCodeScreen() async {
    try {
      final currentState = await isAccessCodeScreenEnabled();

      if (currentState) {
        await disableAccessCodeScreen();
      } else {
        await enableAccessCodeScreen();
      }

      // التحقق من التغيير
      final newState = await isAccessCodeScreenEnabled();
      return newState;
    } on Exception catch (_) {
      rethrow;
    }
  }

  // الدوال القديمة للتوافق مع الإصدارات السابقة
  @Deprecated('استخدم enableAccessCodeScreen() بدلاً من ذلك')
  static Future<void> enableRoleRequest() => enableAccessCodeScreen();

  @Deprecated('استخدم disableAccessCodeScreen() بدلاً من ذلك')
  static Future<void> disableRoleRequest() => disableAccessCodeScreen();

  @Deprecated('استخدم isAccessCodeScreenEnabled() بدلاً من ذلك')
  static Future<bool> isRoleRequestEnabled() => isAccessCodeScreenEnabled();

  @Deprecated('استخدم isAccessCodeScreenEnabledSync() بدلاً من ذلك')
  static bool isRoleRequestEnabledSync() => isAccessCodeScreenEnabledSync();

  @Deprecated('استخدم toggleAccessCodeScreen() بدلاً من ذلك')
  static Future<bool> toggleRoleRequest() => toggleAccessCodeScreen();

  /// إغلاق الخدمة
  static Future<void> dispose() async {
    try {
      await _box?.close();
      _box = null;
      _isInitialized = false;
    } on Exception catch (_) {
      // تجاهل الأخطاء
    }
  }
}
