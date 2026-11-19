import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Settings section permissions
class SettingsPermissions implements SectionPermissions {
  @override
  String get sectionName => 'settings';

  @override
  String get sectionDisplayName => 'الإعدادات';

  @override
  String get sectionIcon => 'settings';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'settings_view',
        name: 'settings_view',
        displayName: 'عرض الإعدادات',
        description: 'عرض إعدادات النظام العامة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'settings_manage',
        name: 'settings_manage',
        displayName: 'إدارة الإعدادات',
        description: 'إدارة شاملة لإعدادات النظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'formatting_settings_view',
        name: 'formatting_settings_view',
        displayName: 'عرض إعدادات التنسيق',
        description: 'عرض إعدادات تنسيق النظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'backup_settings_view',
        name: 'backup_settings_view',
        displayName: 'عرض إعدادات النسخ الاحتياطي',
        description: 'عرض إعدادات النسخ الاحتياطي والاستعادة',
        category: sectionName,
      ),
    ];
  }
}
