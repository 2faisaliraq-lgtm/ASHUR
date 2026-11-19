import 'package:material_ui/material_ui.dart';


import '../../core/widgets/loading_widget.dart';
import '../services/admin_check_service.dart';

/// Middleware للتحقق من وجود مدير قبل الدخول للتطبيق
// ignore: avoid_classes_with_only_static_members
class AdminCheckMiddleware {
  static final AdminCheckService _adminCheckService = AdminCheckService();

  // Cache للنتائج لتجنب التحقق المتكرر
  static AdminCheckResult? _cachedResult;
  static DateTime? _lastCheckTime;
  static const Duration _cacheTimeout = Duration(
    seconds: 5,
  ); // timeout أقصر جداً

  /// مسح الـ cache (يستخدم بعد إنشاء مدير جديد)
  static void clearCache() {
    _cachedResult = null;
    _lastCheckTime = null;
  }

  /// إجبار إعادة التحقق من المدير (بدون cache)
  static Future<bool> forceCheckAdmin() async {
    clearCache();
    try {
      return await _adminCheckService.hasAdminUser();
    } on Exception catch (_) {
      return false;
    }
  }

  /// إجبار النظام على إظهار شاشة إنشاء المدير
  static Future<void> forceAdminSetup() async {
    // Force system to show admin creation screen
    clearCache();

    // إعادة تعيين النتيجة المحفوظة لإجبار النظام على إظهار شاشة إنشاء المدير
    _cachedResult = const AdminCheckResult(
      hasAdmin: false,
      hasAnyUsers: false,
      usersCount: 0,
      adminsCount: 0,
      recommendedRoute: '/create-admin',
    );
    _lastCheckTime = DateTime.now();
  }

  /// التحقق من صحة الـ cache
  static bool _isCacheValid() {
    if (_cachedResult == null || _lastCheckTime == null) return false;

    final now = DateTime.now();
    final timeDiff = now.difference(_lastCheckTime!);
    return timeDiff < _cacheTimeout;
  }

  /// التحقق من وجود مدير وتوجيه المستخدم للشاشة المناسبة
  static Future<String> checkAdminAndGetRoute() async {
    try {
      // التحقق من وجود مدير
      final hasAdmin = await _adminCheckService.hasAdminUser();

      if (hasAdmin) {
        // يوجد مدير، الانتقال للداشبورد
        return '/dashboard';
      } else {
        // لا يوجد مدير، الانتقال لشاشة إنشاء المدير
        return '/create-admin';
      }
    } on Exception catch (_) {
      // في حالة الخطأ، لا ننتقل مباشرة لشاشة إنشاء المدير
      // بل نرجع مسار خطأ لمعالجته
      return '/check-error';
    }
  }

  /// التحقق من وجود مدير مع معلومات إضافية
  static Future<AdminCheckResult> checkAdminWithDetails() async {
    try {
      // التحقق من الـ cache أولاً
      if (_isCacheValid()) {
        return _cachedResult!;
      }

      // مسح الـ cache القديم
      clearCache();

      // التحقق السريع من وجود مدير مع timeout قصير جداً
      // محاولة أولى
      bool hasAdmin;
      try {
        hasAdmin = await _adminCheckService.hasAdminUser().timeout(
          const Duration(seconds: 5),
        );
      } on Exception catch (_) {
        // محاولة ثانية بعد انتظار قصير (في حالة ضعف الإنترنت)
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          hasAdmin = await _adminCheckService.hasAdminUser().timeout(
            const Duration(seconds: 8),
          );
        } on Exception catch (_) {
          // محاولة ثالثة وأخيرة
          await Future.delayed(const Duration(milliseconds: 1000));
          hasAdmin = await _adminCheckService.hasAdminUser().timeout(
            const Duration(seconds: 10),
          );
        }
      }

      // إذا لم يوجد مدير، إرجاع النتيجة فوراً بدون تحقق إضافي
      if (!hasAdmin) {
        const result = AdminCheckResult(
          hasAdmin: false,
          hasAnyUsers: false,
          usersCount: 0,
          adminsCount: 0,
          recommendedRoute: '/create-admin',
        );

        _cachedResult = result;
        _lastCheckTime = DateTime.now();

        return result;
      }

      // يوجد مدير، جلب باقي البيانات بسرعة
      final futures = await Future.wait([
        _adminCheckService.hasAnyUsers().timeout(const Duration(seconds: 2)),
        _adminCheckService.getUsersCount().timeout(const Duration(seconds: 2)),
        _adminCheckService.getAdminsCount().timeout(const Duration(seconds: 2)),
      ]);

      final result = AdminCheckResult(
        hasAdmin: hasAdmin,
        hasAnyUsers: futures[0] as bool,
        usersCount: futures[1] as int,
        adminsCount: futures[2] as int,
        recommendedRoute: '/dashboard',
      );

      _cachedResult = result;
      _lastCheckTime = DateTime.now();

      return result;
    } on Exception catch (_) {
      if (_isCacheValid()) {
        return _cachedResult!;
      }

      final errorResult = AdminCheckResult(
        hasAdmin: false,
        hasAnyUsers: false,
        usersCount: 0,
        adminsCount: 0,
        recommendedRoute: '/check-error',
        error: 'حدث خطأ في التحقق من صلاحيات المسؤول',
        checkFailed: true,
      );

      return errorResult;
    }
  }

  /// Widget wrapper للتحقق من المدير
  static Widget buildAdminCheckWrapper({
    required Widget child,
    required VoidCallback onNoAdmin,
    Widget? loadingWidget,
  }) {
    return FutureBuilder<bool>(
      future: _adminCheckService.hasAdminUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ??
              const Scaffold(body: LoadingWidget(message: 'جاري التحميل...'));
        }

        if (snapshot.hasError || !(snapshot.data ?? false)) {
          // لا يوجد مدير أو حدث خطأ
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onNoAdmin();
          });
          return const SizedBox.shrink();
        }

        // يوجد مدير، عرض المحتوى
        return child;
      },
    );
  }
}

/// نتيجة فحص المدير
class AdminCheckResult {
  const AdminCheckResult({
    required this.hasAdmin,
    required this.hasAnyUsers,
    required this.usersCount,
    required this.adminsCount,
    required this.recommendedRoute,
    this.error,
    this.checkFailed = false,
  });
  final bool hasAdmin;
  final bool hasAnyUsers;
  final int usersCount;
  final int adminsCount;
  final String recommendedRoute;
  final String? error;

  /// هل فشل التحقق من الاتصال؟ (مهم للتعامل مع ضعف الاتصال)
  final bool checkFailed;

  /// هل النتيجة مؤكدة أم لا
  bool get isCertain => !checkFailed;

  /// هل يجب إعادة المحاولة؟
  bool get shouldRetry => checkFailed;

  bool get isHealthy => hasAdmin && adminsCount > 0;
  bool get needsSetup => !hasAdmin && !checkFailed;

  @override
  String toString() {
    return 'AdminCheckResult(hasAdmin: $hasAdmin, usersCount: $usersCount, adminsCount: $adminsCount, checkFailed: $checkFailed)';
  }
}




