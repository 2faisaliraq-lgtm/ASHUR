import '../../../../core/permissions/section_permissions.dart';
import '../entities/permission_entity.dart';

/// صلاحيات قسم المستخدمين
class UsersPermissions implements SectionPermissions {
  @override
  String get sectionName => 'users';

  @override
  String get sectionDisplayName => 'المستخدمين';

  @override
  String get sectionIcon => 'people';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'users_view',
        name: 'users_view',
        displayName: 'عرض المستخدمين',
        description: 'عرض قائمة المستخدمين وتفاصيلهم',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'users_create',
        name: 'users_create',
        displayName: 'إنشاء مستخدم',
        description: 'إضافة مستخدمين جدد للنظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'users_edit',
        name: 'users_edit',
        displayName: 'تعديل المستخدمين',
        description: 'تعديل بيانات المستخدمين الموجودين',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'users_delete',
        name: 'users_delete',
        displayName: 'حذف المستخدمين',
        description: 'حذف المستخدمين من النظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'users_manage_status',
        name: 'users_manage_status',
        displayName: 'إدارة حالة المستخدم',
        description: 'تفعيل وإلغاء تفعيل المستخدمين',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'users_reports_view',
        name: 'users_reports_view',
        displayName: 'عرض تقارير المستخدمين',
        description: 'عرض تقارير وإحصائيات المستخدمين',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'users_logs_view',
        name: 'users_logs_view',
        displayName: 'عرض سجل النشاطات',
        description: 'عرض سجل نشاطات وتحركات المستخدمين',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'users_settings_view',
        name: 'users_settings_view',
        displayName: 'عرض إعدادات المستخدمين',
        description: 'عرض إعدادات قسم المستخدمين',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'users_settings_manage',
        name: 'users_settings_manage',
        displayName: 'إدارة إعدادات المستخدمين',
        description: 'تعديل إعدادات قسم المستخدمين',
        category: sectionName,
      ),
      // Role permissions
      PermissionEntity(
        id: 'roles_view',
        name: 'roles_view',
        displayName: 'عرض الأدوار',
        description: 'عرض قائمة الأدوار وتفاصيلها',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'roles_create',
        name: 'roles_create',
        displayName: 'إنشاء الأدوار',
        description: 'إنشاء أدوار جديدة وتحديد صلاحياتها',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'roles_edit',
        name: 'roles_edit',
        displayName: 'تعديل الأدوار',
        description: 'تعديل الأدوار الموجودة وصلاحياتها',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'roles_delete',
        name: 'roles_delete',
        displayName: 'حذف الأدوار',
        description: 'حذف الأدوار من النظام',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'roles_manage',
        name: 'roles_manage',
        displayName: 'إدارة الأدوار',
        description: 'إدارة شاملة للأدوار (عرض، إنشاء، تعديل، حذف)',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'permissions_view',
        name: 'permissions_view',
        displayName: 'عرض الصلاحيات',
        description: 'عرض قائمة جميع الصلاحيات المتاحة في النظام',
        category: sectionName,
      ),
    ];
  }
}
