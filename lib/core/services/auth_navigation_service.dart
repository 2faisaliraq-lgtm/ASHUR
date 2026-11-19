import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../email/email_normalization_service.dart';
import '../middleware/admin_check_middleware.dart';
import 'role_request_settings_service.dart';

/// خدمة موحدة للتنقل في المصادقة
// ignore: avoid_classes_with_only_static_members
class AuthNavigationService {
  static const String _firstLoginKey = 'is_first_login_after_auth';

  /// نتيجة التحقق من حالة المصادقة
  static Future<AuthNavigationResult> checkAuthNavigation(
    UserEntity user,
  ) async {
    try {
      // التحقق من وجود مدير
      final hasAdmin = await AdminCheckMiddleware.checkAdminWithDetails();

      if (!hasAdmin.hasAdmin) {
        return AuthNavigationResult.needsAdminSetup();
      }

      if (hasAdmin.checkFailed) {
        return AuthNavigationResult.error('تعذر التحقق من حالة المستخدم حالياً.\nيرجى التحقق من الاتصال والمحاولة مرة أخرى.');
      }

      final hasValidRole = await _checkUserHasValidRole(user.email);

      // إذا لم يكن لدى المستخدم دور، يجب عرض شاشة رمز الوصول دائماً
      if (!hasValidRole) {
        return AuthNavigationResult.needsAccessCode(user);
      }

      // التحقق من تسجيل الدخول الأولي بعد المصادقة
      final isFirstLogin = await _isFirstLoginAfterAuth();

      if (isFirstLogin) {
        // أول تسجيل دخول بعد المصادقة - تظهر شاشة رمز الوصول دائماً
        await _setFirstLoginCompleted();
        return AuthNavigationResult.needsAccessCode(user);
      }

      // التحقق من تفعيل شاشة رمز الوصول (للمرات التالية)
      final isAccessCodeEnabled =
          await RoleRequestSettingsService.isAccessCodeScreenEnabled();

      // إذا كانت شاشة رمز الوصول مفعلة، اعرضها
      if (isAccessCodeEnabled) {
        return AuthNavigationResult.needsAccessCode(user);
      }

      // شاشة رمز الوصول معطلة - الانتقال للداشبورد مباشرة
      return AuthNavigationResult.navigateToMain();
    } on Exception catch (e) {
      return AuthNavigationResult.error('حدث خطأ أثناء التحقق من الحالة: $e');
    }
  }

  /// التحقق من تسجيل الدخول الأولي بعد المصادقة
  static Future<bool> _isFirstLoginAfterAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_firstLoginKey) ?? true;
    } on Exception catch (_) {
      return true; // في حالة الخطأ، نعتبر أنه تسجيل دخول أولي
    }
  }

  /// حفظ حالة إكمال تسجيل الدخول الأولي
  static Future<void> _setFirstLoginCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLoginKey, false);
    } on Exception catch (_) {
      // تجاهل الخطأ
    }
  }

  /// مسح حالة تسجيل الدخول الأولي (يستخدم عند تسجيل الخروج)
  static Future<void> clearFirstLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLoginKey, true);
    } on Exception catch (_) {
      // تجاهل الخطأ
    }
  }

  /// التحقق من وجود دور صحيح للمستخدم
  static Future<bool> _checkUserHasValidRole(String userEmail) async {
    try {
      final emailService = EmailNormalizationService();
      final organizationId = emailService.normalize(userEmail);

      final userQuery = await FirebaseFirestore.instance
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (userQuery.docs.isEmpty) {
        return false;
      }

      final userData = userQuery.docs.first.data();
      final roleIds = List<String>.from(userData['roleIds'] ?? []);

      if (roleIds.isEmpty) {
        return false;
      }

      final rolesQuery = await FirebaseFirestore.instance
          .collection(organizationId)
          .doc('users')
          .collection('roles')
          .where(FieldPath.documentId, whereIn: roleIds)
          .get()
          .timeout(const Duration(seconds: 10));

      return rolesQuery.docs.isNotEmpty;
    } on Exception catch (e) {
      throw Exception('فشل التحقق من دور المستخدم: $e');
    }
  }
}

/// نتيجة التحقق من التنقل
class AuthNavigationResult {
  const AuthNavigationResult._({
    required this.type,
    this.errorMessage,
    this.user,
  });

  factory AuthNavigationResult.needsAdminSetup() {
    return const AuthNavigationResult._(
      type: AuthNavigationType.needsAdminSetup,
    );
  }

  factory AuthNavigationResult.needsAccessCode(UserEntity user) {
    return AuthNavigationResult._(
      type: AuthNavigationType.needsAccessCode,
      user: user,
    );
  }

  factory AuthNavigationResult.navigateToMain() {
    return const AuthNavigationResult._(
      type: AuthNavigationType.navigateToMain,
    );
  }

  factory AuthNavigationResult.error(String message) {
    return AuthNavigationResult._(
      type: AuthNavigationType.error,
      errorMessage: message,
    );
  }
  final AuthNavigationType type;
  final String? errorMessage;
  final UserEntity? user;
}

enum AuthNavigationType {
  needsAdminSetup,
  needsAccessCode,
  navigateToMain,
  error,
}
