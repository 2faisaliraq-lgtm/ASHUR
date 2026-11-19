import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Dashboard section permissions
class DashboardPermissions implements SectionPermissions {
  @override
  String get sectionName => 'dashboard';

  @override
  String get sectionDisplayName => 'لوحة التحكم';

  @override
  String get sectionIcon => 'dashboard';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'dashboard_view',
        name: 'dashboard_view',
        displayName: 'عرض لوحة التحكم',
        description: 'الوصول إلى لوحة التحكم الرئيسية',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'role_switch',
        name: 'role_switch',
        displayName: 'تبديل الأدوار',
        description: 'القدرة على التبديل بين الأدوار المختلفة',
        category: sectionName,
      ),
    ];
  }
}
