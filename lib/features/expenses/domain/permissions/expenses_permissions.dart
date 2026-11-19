import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Expenses section permissions
class ExpensesPermissions implements SectionPermissions {
  @override
  String get sectionName => 'expenses';

  @override
  String get sectionDisplayName => 'المصروفات';

  @override
  String get sectionIcon => 'money_off';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'expenses_view',
        name: 'expenses_view',
        displayName: 'عرض المصروفات',
        description: 'عرض قائمة المصروفات والنفقات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'expenses_create',
        name: 'expenses_create',
        displayName: 'إضافة مصروف',
        description: 'إضافة مصروفات ونفقات جديدة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'expenses_edit',
        name: 'expenses_edit',
        displayName: 'تعديل المصروفات',
        description: 'تعديل المصروفات الموجودة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'expenses_delete',
        name: 'expenses_delete',
        displayName: 'حذف المصروفات',
        description: 'حذف المصروفات من النظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'expenses_settings_view',
        name: 'expenses_settings_view',
        displayName: 'عرض إعدادات المصروفات',
        description: 'عرض إعدادات قسم المصروفات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'expenses_settings_manage',
        name: 'expenses_settings_manage',
        displayName: 'إدارة إعدادات المصروفات',
        description: 'تعديل إعدادات قسم المصروفات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'expenses_types_view',
        name: 'expenses_types_view',
        displayName: 'عرض أنواع المصروفات',
        description: 'عرض أنواع المصروفات المختلفة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'expenses_analysis_view',
        name: 'expenses_analysis_view',
        displayName: 'عرض تحليلات المصروفات',
        description: 'عرض تحليلات المصروفات والإحصائيات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'expenses_reports_view',
        name: 'expenses_reports_view',
        displayName: 'عرض تقارير المصروفات',
        description: 'عرض تقارير المصروفات والتحليلات',
        category: sectionName,
      ),
    ];
  }
}
