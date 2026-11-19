import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Subscriptions section permissions
class SubscriptionsPermissions implements SectionPermissions {
  @override
  String get sectionName => 'subscriptions';

  @override
  String get sectionDisplayName => 'الاشتراكات';

  @override
  String get sectionIcon => 'card_membership';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'subscriptions_view',
        name: 'subscriptions_view',
        displayName: 'عرض الاشتراكات',
        description: 'عرض قائمة الاشتراكات وتفاصيلها',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_create',
        name: 'subscriptions_create',
        displayName: 'إنشاء اشتراك',
        description: 'إنشاء اشتراكات جديدة للعملاء',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_edit',
        name: 'subscriptions_edit',
        displayName: 'تعديل الاشتراكات',
        description: 'تعديل تفاصيل الاشتراكات الموجودة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_delete',
        name: 'subscriptions_delete',
        displayName: 'حذف الاشتراكات',
        description: 'حذف الاشتراكات من النظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_settings_view',
        name: 'subscriptions_settings_view',
        displayName: 'عرض إعدادات الاشتراكات',
        description: 'عرض إعدادات قسم الاشتراكات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_settings_manage',
        name: 'subscriptions_settings_manage',
        displayName: 'إدارة إعدادات الاشتراكات',
        description: 'تعديل إعدادات قسم الاشتراكات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_logs_view',
        name: 'subscriptions_logs_view',
        displayName: 'عرض سجلات الاشتراكات',
        description: 'عرض سجل حركات الاشتراكات والتعديلات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscription_types_view',
        name: 'subscription_types_view',
        displayName: 'عرض أنواع الاشتراكات',
        description: 'عرض أنواع الاشتراكات المختلفة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_reports_view',
        name: 'subscriptions_reports_view',
        displayName: 'عرض تقارير الاشتراكات',
        description: 'عرض تقارير الاشتراكات والإيرادات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_renew',
        name: 'subscriptions_renew',
        displayName: 'تجديد الاشتراكات',
        description: 'تجديد الاشتراكات المنتهية أو النشطة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_suspend',
        name: 'subscriptions_suspend',
        displayName: 'تعليق الاشتراكات',
        description: 'إيقاف الاشتراكات مؤقتاً',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'subscriptions_plans',
        name: 'subscriptions_plans',
        displayName: 'إدارة أنواع الاشتراكات',
        description: 'إنشاء وتعديل وحذف أنواع الاشتراكات',
        category: sectionName,
      ),
    ];
  }
}
