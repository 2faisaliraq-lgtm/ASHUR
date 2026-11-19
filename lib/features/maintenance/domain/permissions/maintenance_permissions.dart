import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Maintenance section permissions
class MaintenancePermissions implements SectionPermissions {
  @override
  String get sectionName => 'maintenance';

  @override
  String get sectionDisplayName => 'الصيانة';

  @override
  String get sectionIcon => 'build';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'maintenance_view',
        name: 'maintenance_view',
        displayName: 'عرض طلبات الصيانة',
        description: 'عرض قائمة طلبات الصيانة وحالتها',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'maintenance_create',
        name: 'maintenance_create',
        displayName: 'إنشاء طلب صيانة',
        description: 'إنشاء طلبات صيانة جديدة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'maintenance_edit',
        name: 'maintenance_edit',
        displayName: 'تعديل طلبات الصيانة',
        description: 'تعديل تفاصيل طلبات الصيانة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'maintenance_delete',
        name: 'maintenance_delete',
        displayName: 'حذف طلبات الصيانة',
        description: 'حذف طلبات الصيانة من النظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'maintenance_settings_view',
        name: 'maintenance_settings_view',
        displayName: 'عرض إعدادات الصيانة',
        description: 'عرض إعدادات قسم الصيانة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'maintenance_settings_manage',
        name: 'maintenance_settings_manage',
        displayName: 'إدارة إعدادات الصيانة',
        description: 'تعديل إعدادات قسم الصيانة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'maintenance_logs_view',
        name: 'maintenance_logs_view',
        displayName: 'عرض سجلات الصيانة',
        description: 'عرض سجل حركات الصيانة والتعديلات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'maintenance_reports_view',
        name: 'maintenance_reports_view',
        displayName: 'عرض تقارير الصيانة',
        description: 'عرض تقارير الصيانة والأداء',
        category: sectionName,
      ),
    ];
  }
}
