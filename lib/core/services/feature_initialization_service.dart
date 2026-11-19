/// خدمة إدارة تهيئة الأقسام (Lazy Initialization)
class FeatureInitializationService {
  static final FeatureInitializationService _instance =
      FeatureInitializationService._internal();
  factory FeatureInitializationService() => _instance;
  FeatureInitializationService._internal();

  // حالة التهيئة لكل قسم
  final Map<String, bool> _initializationState = {};
  final Map<String, Future<void> Function()> _initializers = {};
  final Map<String, bool> _isInitializing = {};

  /// تسجيل مهيئ القسم
  void registerInitializer(
    String featureName,
    Future<void> Function() initializer,
  ) {
    _initializers[featureName] = initializer;
    _initializationState[featureName] = false;
    _isInitializing[featureName] = false;
  }

  /// التحقق من تهيئة القسم وتهيئته إذا لزم الأمر
  Future<void> ensureInitialized(String featureName) async {
    // إذا كان القسم مهيأ بالفعل، لا تفعل شيئاً
    if (_initializationState[featureName] == true) {
      return;
    }

    // إذا كان القسم قيد التهيئة حالياً، انتظر
    if (_isInitializing[featureName] == true) {
      // انتظار بسيط لتجنب التهيئة المزدوجة
      while (_isInitializing[featureName] == true) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    // بدء التهيئة
    _isInitializing[featureName] = true;

    try {
      final initializer = _initializers[featureName];
      if (initializer != null) {
        await initializer();
        _initializationState[featureName] = true;
      }
    } on Exception {
      _initializationState[featureName] = false;
      rethrow;
    } finally {
      _isInitializing[featureName] = false;
    }
  }

  /// التحقق مما إذا كان القسم مهيأ
  bool isInitialized(String featureName) {
    return _initializationState[featureName] ?? false;
  }

  /// التحقق مما إذا كان القسم قيد التهيئة
  bool isInitializing(String featureName) {
    return _isInitializing[featureName] ?? false;
  }

  /// إعادة تعيين حالة التهيئة (للاختبار أو إعادة التحميل)
  void reset(String featureName) {
    _initializationState[featureName] = false;
    _isInitializing[featureName] = false;
  }

  /// إعادة تعيين جميع الأقسام
  void resetAll() {
    for (final key in _initializationState.keys) {
      reset(key);
    }
  }

  /// الحصول على حالة جميع الأقسام
  Map<String, bool> get initializationState =>
      Map.unmodifiable(_initializationState);
}

/// أسماء الأقسام
class FeatureNames {
  static const String auth = 'auth';
  static const String users = 'users';
  static const String customers = 'customers';
  static const String inventory = 'inventory';
  static const String invoices = 'invoices';
  static const String expenses = 'expenses';
  static const String subscriptions = 'subscriptions';
  static const String maintenance = 'maintenance';
  static const String rentals = 'rentals';
  static const String reports = 'reports';
  static const String settings = 'settings';
}
