import 'package:material_ui/material_ui.dart';

import '../theme/assyrian_theme.dart';

/// مساعد لمعالجة وعرض الأخطاء
// ignore: avoid_classes_with_only_static_members
class ErrorHandler {
  /// عرض رسالة خطأ مع إرشادات للمستخدم
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    String? actionText,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: AssyrianTheme.ivoryWhite,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AssyrianTheme.ivoryWhite,
                  fontSize: 14,
                  fontFamily: 'Amiri',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AssyrianTheme.crimsonRed,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: actionText != null && onAction != null
            ? SnackBarAction(
                label: actionText,
                textColor: AssyrianTheme.ivoryWhite,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// عرض رسالة نجاح
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AssyrianTheme.ivoryWhite,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AssyrianTheme.ivoryWhite,
                  fontSize: 14,
                  fontFamily: 'Amiri',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// عرض رسالة تحذير
  static void showWarningSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_outlined,
              color: AssyrianTheme.deepBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AssyrianTheme.deepBlue,
                  fontSize: 14,
                  fontFamily: 'Amiri',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AssyrianTheme.primaryGold,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// معالجة أخطاء المصادقة وإرجاع رسالة مناسبة
  static String getAuthErrorMessage(String error) {
    final errorLower = error.toLowerCase();

    // إخفاء المعلومات الحساسة (Firebase Console, SHA, إلخ)
    if (errorLower.contains('firebase console') ||
        errorLower.contains('firebaseconsole') ||
        errorLower.contains('cloud functions') ||
        errorLower.contains('deploy_instructions') ||
        errorLower.contains('sha-1') ||
        errorLower.contains('sha1') ||
        errorLower.contains('sha-256') ||
        errorLower.contains('sha256') ||
        errorLower.contains('certificate') ||
        errorLower.contains('b2:f3:') ||
        errorLower.contains('developer_error')) {
      return 'خطأ في الاتصال بالإنترنت.\n\nيرجى التحقق من اتصالك والمحاولة مرة أخرى.\n\nملاحظة: هذا الخطأ قد يظهر بشكل خاطئ عند ضعف الاتصال.';
    }

    // أخطاء تسجيل الدخول عبر جوجل
    if (errorLower.contains('google')) {
      // خطأ إعدادات تسجيل الدخول عبر جوجل للويب
      if (errorLower.contains('storagerelay') ||
          errorLower.contains('native_android') ||
          errorLower.contains('client type') ||
          errorLower.contains('access blocked') ||
          errorLower.contains('authorization error')) {
        return 'خدمة تسجيل الدخول عبر جوجل غير مُعدّة بشكل صحيح للويب حالياً.\n\nالحل: استخدم تسجيل الدخول بالبريد الإلكتروني وكلمة المرور.';
      } else if (errorLower.contains('credential') &&
          (errorLower.contains('incorrect') ||
              errorLower.contains('malformed') ||
              errorLower.contains('expired'))) {
        return 'فشل تسجيل الدخول عبر جوجل.\n\nبيانات الاعتماد غير صحيحة أو منتهية الصلاحية.\n\nيرجى المحاولة مرة أخرى أو استخدام البريد الإلكتروني وكلمة المرور.';
      } else if (errorLower.contains('clientid')) {
        return 'تسجيل الدخول عبر جوجل غير متاح حالياً على الويب.\n\nيرجى استخدام تسجيل الدخول بالبريد الإلكتروني وكلمة المرور.';
      } else if (errorLower.contains('network')) {
        return 'حدث خطأ في الشبكة أثناء تسجيل الدخول عبر جوجل.\n\nتحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
      }
    }

    // أخطاء الشبكة والاتصال
    if (errorLower.contains('network') ||
        errorLower.contains('timeout') ||
        errorLower.contains('connection') ||
        errorLower.contains('unable to resolve host') ||
        errorLower.contains('socket') ||
        errorLower.contains('connection refused') ||
        errorLower.contains('connection reset') ||
        errorLower.contains('network_error')) {
      return 'خطأ في الاتصال بالإنترنت.\n\nتحقق من اتصالك وحاول مرة أخرى.';
    }

    // أخطاء بيانات المصادقة العامة
    if (errorLower.contains('credential')) {
      return 'بيانات الاعتماد غير صحيحة.\n\nيرجى التحقق من البيانات والمحاولة مرة أخرى.';
    }

    // أخطاء كلمة المرور
    if (errorLower.contains('password')) {
      return 'كلمة المرور غير صحيحة.\n\nيرجى التحقق من كلمة المرور والمحاولة مرة أخرى.';
    }

    // أخطاء البريد الإلكتروني
    if (errorLower.contains('email') || errorLower.contains('user-not-found')) {
      return 'لا يوجد حساب بهذا البريد الإلكتروني.\n\nيرجى التحقق من البريد أو إنشاء حساب جديد.';
    }

    // خطأ بيانات اعتماد غير صالحة (invalid-credential)
    if (errorLower.contains('invalid-credential') ||
        errorLower.contains('invalid credential')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.\n\nيرجى التحقق من البيانات والمحاولة مرة أخرى.';
    }

    // خطأ wrong-password
    if (errorLower.contains('wrong-password')) {
      return 'كلمة المرور غير صحيحة.\n\nيرجى التحقق من كلمة المرور والمحاولة مرة أخرى.';
    }

    // الرسالة الأصلية إذا لم تطابق أي نمط
    return error;
  }

  /// عرض حوار خطأ مع خيارات
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? primaryButtonText,
    VoidCallback? onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
  }) async {
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AssyrianTheme.crimsonRed,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Amiri',
              color: AssyrianTheme.deepBlue,
            ),
          ),
          actions: [
            if (secondaryButtonText != null)
              TextButton(
                onPressed: () {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  onSecondaryPressed?.call();
                },
                child: Text(
                  secondaryButtonText,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                onPrimaryPressed?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                primaryButtonText ?? 'موافق',
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  color: AssyrianTheme.ivoryWhite,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
