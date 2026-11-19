import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// خدمة التخزين المؤقت المحلي
class LocalCacheService {
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  static final LocalCacheService _instance = LocalCacheService._internal();

  SharedPreferences? _prefs;

  /// تهيئة الخدمة
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// حفظ البيانات في التخزين المؤقت
  Future<bool> setCache(String key, dynamic data, {Duration? expiry}) async {
    await init();

    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };

    return _prefs!.setString(key, jsonEncode(cacheData));
  }

  /// استرجاع البيانات من التخزين المؤقت
  Future<T?> getCache<T>(String key) async {
    await init();

    final cacheString = _prefs!.getString(key);
    if (cacheString == null) return null;

    try {
      final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final expiry = cacheData['expiry'] as int?;

      // التحقق من انتهاء الصلاحية
      if (expiry != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp + expiry,
        );
        if (DateTime.now().isAfter(expiryTime)) {
          await removeCache(key);
          return null;
        }
      }

      return cacheData['data'] as T;
    } on Exception catch (_) {
      // إزالة البيانات التالفة
      await removeCache(key);
      return null;
    }
  }

  /// إزالة البيانات من التخزين المؤقت
  Future<bool> removeCache(String key) async {
    await init();
    return _prefs!.remove(key);
  }

  /// مسح جميع البيانات المؤقتة
  Future<bool> clearCache() async {
    await init();
    return _prefs!.clear();
  }

  /// التحقق من وجود البيانات في التخزين المؤقت
  Future<bool> hasCache(String key) async {
    await init();
    return _prefs!.containsKey(key);
  }

  /// الحصول على جميع مفاتيح التخزين المؤقت
  Future<Set<String>> getAllKeys() async {
    await init();
    return _prefs!.getKeys();
  }

  /// مسح البيانات المنتهية الصلاحية
  Future<void> cleanExpiredCache() async {
    await init();

    final keys = await getAllKeys();
    final now = DateTime.now();

    for (final key in keys) {
      final cacheString = _prefs!.getString(key);
      if (cacheString == null) continue;

      try {
        final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
        final timestamp = cacheData['timestamp'] as int;
        final expiry = cacheData['expiry'] as int?;

        if (expiry != null) {
          final expiryTime = DateTime.fromMillisecondsSinceEpoch(
            timestamp + expiry,
          );
          if (now.isAfter(expiryTime)) {
            await removeCache(key);
          }
        }
      } on Exception catch (_) {
        // إزالة البيانات التالفة
        await removeCache(key);
      }
    }
  }

  /// إنشاء مفتاح تخزين مؤقت للصيانة
  static String maintenanceKey(String organizationEmail, {String? suffix}) {
    return 'maintenance_$organizationEmail${suffix != null ? '_$suffix' : ''}';
  }

  /// إنشاء مفتاح تخزين مؤقت للمعدات
  static String equipmentKey(String organizationEmail) {
    return 'equipment_$organizationEmail';
  }

  /// إنشاء مفتاح تخزين مؤقت للإحصائيات
  static String statsKey(String organizationEmail) {
    return 'stats_$organizationEmail';
  }
}
