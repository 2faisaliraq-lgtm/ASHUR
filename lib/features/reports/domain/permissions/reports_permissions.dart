import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Reports section permissions
class ReportsPermissions implements SectionPermissions {
  @override
  String get sectionName => 'reports';

  @override
  String get sectionDisplayName => 'التقارير';

  @override
  String get sectionIcon => 'assessment';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'reports_view',
        name: 'reports_view',
        displayName: 'عرض التقارير',
        description: 'عرض التقارير والإحصائيات المختلفة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'reports_create',
        name: 'reports_create',
        displayName: 'إنشاء التقارير',
        description: 'إنشاء تقارير مخصصة جديدة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'reports_edit',
        name: 'reports_edit',
        displayName: 'تعديل التقارير',
        description: 'تعديل التقارير المخصصة الموجودة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'reports_delete',
        name: 'reports_delete',
        displayName: 'حذف التقارير',
        description: 'حذف التقارير المخصصة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'reports_export',
        name: 'reports_export',
        displayName: 'تصدير التقارير',
        description: 'تصدير التقارير بصيغ مختلفة (PDF وجداول البيانات)',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'reports_settings_view',
        name: 'reports_settings_view',
        displayName: 'عرض إعدادات التقارير',
        description: 'عرض إعدادات قسم التقارير',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'reports_settings_manage',
        name: 'reports_settings_manage',
        displayName: 'إدارة إعدادات التقارير',
        description: 'تعديل إعدادات قسم التقارير',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'reports_download',
        name: 'reports_download',
        displayName: 'تحميل التقارير',
        description: 'تحميل التقارير على الجهاز',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'reports_share',
        name: 'reports_share',
        displayName: 'مشاركة التقارير',
        description: 'مشاركة التقارير مع الآخرين',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'reports_print',
        name: 'reports_print',
        displayName: 'طباعة التقارير',
        description: 'طباعة التقارير',
        category: sectionName,
      ),
      // صلاحيات الصندوق
      PermissionEntity(
        id: 'cashbox_view',
        name: 'cashbox_view',
        displayName: 'عرض الصندوق',
        description: 'عرض شاشة الصندوق والتقارير',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'cashbox_manage',
        name: 'cashbox_manage',
        displayName: 'إدارة الصندوق',
        description: 'إضافة وسحب مبالغ من الصندوق',
        category: sectionName,
      ),
    ];
  }
}
