import '../../domain/entities/subscription_type_entity.dart';
import '../../domain/repositories/subscription_repository.dart';

/// خدمة التخزين المؤقت لأنواع الاشتراكات
///
/// تقوم بحفظ أنواع الاشتراكات في الذاكرة لتحسين الأداء
/// وتقليل عدد قراءات Firestore
class SubscriptionTypeCache {
  // Singleton instance
  static final SubscriptionTypeCache _instance =
      SubscriptionTypeCache._internal();

  factory SubscriptionTypeCache() => _instance;

  SubscriptionTypeCache._internal();

  // عدد العناصر الأقصى في الذاكرة المؤقتة لمنع النمو غير المحدود
  static const _maxCacheSize = 100;

  // الذاكرة المؤقتة - مفتاحها organizationEmail:typeId
  final Map<String, SubscriptionTypeEntity> _cache = {};

  // وقت انتهاء الصلاحية لكل عنصر (بالمللي ثانية)
  static const _cacheExpiryMs = 5 * 60 * 1000; // 5 دقائق

  final Map<String, int> _cacheTimestamps = {};

  /// الحصول على أنواع الاشتراكات مع caching
  Future<List<SubscriptionTypeEntity>> getSubscriptionTypes({
    required String organizationEmail,
    required SubscriptionRepository repository,
  }) async {
    final cacheKey = '$organizationEmail:all';

    // التحقق من الذاكرة المؤقتة
    if (_isValidCache(cacheKey)) {
      return _getTypesFromCache(organizationEmail);
    }

    // جلب البيانات من repository
    final result = await repository.getSubscriptionTypes(organizationEmail);

    return result.fold(
      (failure) {
        return <SubscriptionTypeEntity>[];
      },
      (types) {
        _cacheTypes(organizationEmail, types);
        return types;
      },
    );
  }

  /// الحصول على نوع اشتراك محدد مع caching
  Future<SubscriptionTypeEntity?> getSubscriptionType({
    required String organizationEmail,
    required String typeId,
    required SubscriptionRepository repository,
  }) async {
    final cacheKey = '$organizationEmail:$typeId';

    // التحقق من الذاكرة المؤقتة
    if (_isValidCache(cacheKey)) {
      return _cache[cacheKey];
    }

    // جلب البيانات من repository
    final types = await getSubscriptionTypes(
      organizationEmail: organizationEmail,
      repository: repository,
    );

    final type = types.firstWhere(
      (t) => t.id == typeId,
      orElse: () => throw Exception('نوع الاشتراك غير موجود'),
    );

    return type;
  }

  /// تحديث الذاكرة المؤقتة عند تعديل نوع الاشتراك
  void updateSubscriptionType({
    required String organizationEmail,
    required SubscriptionTypeEntity type,
  }) {
    final allCacheKey = '$organizationEmail:all';
    final typeCacheKey = '$organizationEmail:${type.id}';

    // تحديث النوع في قائمة الكل
    if (_cache.containsKey(allCacheKey)) {
      final types = _getTypesFromCache(organizationEmail);
      final index = types.indexWhere((t) => t.id == type.id);
      if (index != -1) {
        types[index] = type;
        _cache[typeCacheKey] = type;
      }
    }

    // تحديث النوع المنفرد
    _cache[typeCacheKey] = type;
    _cacheTimestamps[typeCacheKey] = DateTime.now().millisecondsSinceEpoch;
  }

  /// مسح الذاكرة المؤقتة لمؤسسة معينة
  void clearCache(String organizationEmail) {
    final keysToRemove = _cache.keys
        .where((key) => key.startsWith('$organizationEmail:'))
        .toList();

    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// التحقق من صحة الذاكرة المؤقتة
  bool _isValidCache(String cacheKey) {
    if (!_cache.containsKey(cacheKey)) return false;

    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - timestamp;

    return age < _cacheExpiryMs;
  }

  /// الحصول على الأنواع من الذاكرة المؤقتة
  List<SubscriptionTypeEntity> _getTypesFromCache(String organizationEmail) {
    final prefix = '$organizationEmail:';
    final allKey = '$organizationEmail:all';
    return _cache.entries
        .where((entry) => entry.key.startsWith(prefix) && entry.key != allKey)
        .map((entry) => entry.value)
        .toList();
  }

  /// حفظ الأنواع في الذاكرة المؤقتة
  void _cacheTypes(
    String organizationEmail,
    List<SubscriptionTypeEntity> types,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // إذا تجاوز العدد الأقصى، احذف الأقدم أولاً
    if (_cache.length + types.length > _maxCacheSize) {
      final sortedKeys = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final toRemove = _cache.length + types.length - _maxCacheSize;
      for (int i = 0; i < toRemove && i < sortedKeys.length; i++) {
        _cache.remove(sortedKeys[i].key);
        _cacheTimestamps.remove(sortedKeys[i].key);
      }
    }

    for (final type in types) {
      final cacheKey = '$organizationEmail:${type.id}';
      _cache[cacheKey] = type;
      _cacheTimestamps[cacheKey] = now;
    }
  }

  /// الحصول على إحصائيات الذاكرة المؤقتة
  Map<String, dynamic> getCacheStats() {
    return {'totalItems': _cache.length, 'keys': _cache.keys.toList()};
  }
}
