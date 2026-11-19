import '../../../../core/permissions/permission_checker.dart';

/// Mixin للتحقق من صلاحيات الاشتراكات
mixin SubscriptionPermissionsMixin {
  /// فحص الصلاحيات الفعلي باستخدام PermissionChecker
  Future<bool> hasSubscriptionPermission(String permission) async {
    try {
      final checker = PermissionChecker();
      return await checker.hasPermission(permission);
    } on Exception {
      // إذا تعطل فحص الصلاحيات، نمنع العملية افتراضياً للأمان
      return false;
    }
  }

  /// فحص صلاحية عرض الاشتراكات
  Future<bool> canViewSubscriptions() =>
      hasSubscriptionPermission('subscriptions_view');

  /// فحص صلاحية إنشاء الاشتراكات
  Future<bool> canCreateSubscriptions() =>
      hasSubscriptionPermission('subscriptions_create');

  /// فحص صلاحية تعديل الاشتراكات
  Future<bool> canEditSubscriptions() =>
      hasSubscriptionPermission('subscriptions_edit');

  /// فحص صلاحية حذف الاشتراكات
  Future<bool> canDeleteSubscriptions() =>
      hasSubscriptionPermission('subscriptions_delete');

  /// فحص صلاحية تجديد الاشتراكات
  Future<bool> canRenewSubscriptions() =>
      hasSubscriptionPermission('subscriptions_renew');

  /// فحص صلاحية تعليق الاشتراكات
  Future<bool> canSuspendSubscriptions() =>
      hasSubscriptionPermission('subscriptions_suspend');

  /// فحص صلاحية إدارة أنواع الاشتراكات
  Future<bool> canManageSubscriptionPlans() =>
      hasSubscriptionPermission('subscriptions_plans');

  /// فحص صلاحية عرض تقارير الاشتراكات
  /// ⚠️ ملاحظة توثيقية للمبرمجين المستقبليين: هذا يتحقق من صلاحية
  /// 'subscriptions_reports' بينما الصلاحية المعرفة في
  /// subscriptions_permissions.dart هي 'subscriptions_reports_view'.
  /// هذا عدم توافق قد يؤدي إلى رفض الوصول خاطئاً. يُنصح بتوحيد الاسم
  /// ليكون 'subscriptions_reports_view' في كلا الملفين.
  Future<bool> canViewSubscriptionReports() =>
      hasSubscriptionPermission('subscriptions_reports');
}
