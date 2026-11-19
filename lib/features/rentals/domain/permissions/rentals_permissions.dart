import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Rentals section permissions
class RentalsPermissions implements SectionPermissions {
  @override
  String get sectionName => 'rentals';

  @override
  String get sectionDisplayName => 'الإيجارات';

  @override
  String get sectionIcon => 'home_work';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'rentals_view',
        name: 'rentals_view',
        displayName: 'عرض الإيجارات',
        description: 'عرض قائمة عقود الإيجار والوحدات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'rentals_create',
        name: 'rentals_create',
        displayName: 'إنشاء عقد إيجار',
        description: 'إنشاء عقود إيجار جديدة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'rentals_edit',
        name: 'rentals_edit',
        displayName: 'تعديل الإيجارات',
        description: 'تعديل عقود الإيجار الموجودة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'rentals_delete',
        name: 'rentals_delete',
        displayName: 'حذف الإيجارات',
        description: 'حذف عقود الإيجار',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'rentals_settings_view',
        name: 'rentals_settings_view',
        displayName: 'عرض إعدادات الإيجارات',
        description: 'عرض إعدادات قسم الإيجارات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'rentals_settings_manage',
        name: 'rentals_settings_manage',
        displayName: 'إدارة إعدادات الإيجارات',
        description: 'تعديل إعدادات قسم الإيجارات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'rentals_units_view',
        name: 'rentals_units_view',
        displayName: 'عرض الوحدات',
        description: 'عرض الوحدات المؤجرة وتفاصيلها',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'rentals_payments_view',
        name: 'rentals_payments_view',
        displayName: 'عرض مدفوعات الإيجار',
        description: 'عرض مدفوعات الإيجار والتحصيلات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'rentals_logs_view',
        name: 'rentals_logs_view',
        displayName: 'عرض سجلات الإيجارات',
        description: 'عرض سجل حركات الإيجارات والتعديلات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'rentals_reports_view',
        name: 'rentals_reports_view',
        displayName: 'عرض تقارير الإيجارات',
        description: 'عرض تقارير الإيجارات والإيرادات',
        category: sectionName,
      ),
    ];
  }
}
