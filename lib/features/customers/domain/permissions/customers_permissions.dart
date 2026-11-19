import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Customers section permissions
class CustomersPermissions implements SectionPermissions {
  @override
  String get sectionName => 'customers';

  @override
  String get sectionDisplayName => 'العملاء';

  @override
  String get sectionIcon => 'person_outline';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'customers_view',
        name: 'customers_view',
        displayName: 'عرض العملاء',
        description: 'عرض قائمة العملاء وتفاصيلهم',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_create',
        name: 'customers_create',
        displayName: 'إضافة عميل',
        description: 'إضافة عملاء جدد للنظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_edit',
        name: 'customers_edit',
        displayName: 'تعديل العملاء',
        description: 'تعديل بيانات العملاء الموجودين',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_delete',
        name: 'customers_delete',
        displayName: 'حذف العملاء',
        description: 'حذف العملاء من النظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_manage_status',
        name: 'customers_manage_status',
        displayName: 'إدارة حالة العميل',
        description: 'تفعيل وإلغاء تفعيل العملاء',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_settings_view',
        name: 'customers_settings_view',
        displayName: 'عرض إعدادات العملاء',
        description: 'عرض إعدادات قسم العملاء',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_settings_manage',
        name: 'customers_settings_manage',
        displayName: 'إدارة إعدادات العملاء',
        description: 'تعديل إعدادات قسم العملاء',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_groups_view',
        name: 'customers_groups_view',
        displayName: 'عرض مجموعات العملاء',
        description: 'عرض مجموعات وتصنيفات العملاء',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_groups_create',
        name: 'customers_groups_create',
        displayName: 'إنشاء مجموعات العملاء',
        description: 'إنشاء مجموعات عملاء جديدة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_logs_view',
        name: 'customers_logs_view',
        displayName: 'عرض سجلات العملاء',
        description: 'عرض سجل حركات العملاء والأنشطة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_reports_view',
        name: 'customers_reports_view',
        displayName: 'عرض تقارير العملاء',
        description: 'عرض تقارير وإحصائيات العملاء',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'customers_send_messages',
        name: 'customers_send_messages',
        displayName: 'إرسال رسائل للعملاء',
        description: 'إرسال رسائل وتنبيهات للعملاء',
        category: sectionName,
      ),
    ];
  }
}
