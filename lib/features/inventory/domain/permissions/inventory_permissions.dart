import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Inventory section permissions
class InventoryPermissions implements SectionPermissions {
  @override
  String get sectionName => 'inventory';

  @override
  String get sectionDisplayName => 'المخزون';

  @override
  String get sectionIcon => 'inventory';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'inventory_view',
        name: 'inventory_view',
        displayName: 'عرض المخزون',
        description: 'عرض قائمة المنتجات والمخزون',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_create',
        name: 'inventory_create',
        displayName: 'إضافة منتج',
        description: 'إضافة منتجات جديدة للمخزون',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_edit',
        name: 'inventory_edit',
        displayName: 'تعديل المنتجات',
        description: 'تعديل بيانات المنتجات والمخزون',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_delete',
        name: 'inventory_delete',
        displayName: 'حذف المنتجات',
        description: 'حذف المنتجات من المخزون',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_settings_view',
        name: 'inventory_settings_view',
        displayName: 'عرض إعدادات المخزون',
        description: 'عرض إعدادات قسم المخزون',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_settings_manage',
        name: 'inventory_settings_manage',
        displayName: 'إدارة إعدادات المخزون',
        description: 'تعديل إعدادات قسم المخزون',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_categories_view',
        name: 'inventory_categories_view',
        displayName: 'عرض فئات المخزون',
        description: 'عرض فئات وتصنيفات المخزون',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_shelves_view',
        name: 'inventory_shelves_view',
        displayName: 'عرض الأرفف',
        description: 'عرض أرفف المخزون ومواقع المنتجات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_logs_view',
        name: 'inventory_logs_view',
        displayName: 'عرض سجلات المخزون',
        description: 'عرض سجل حركات المخزون والتعديلات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_tools_view',
        name: 'inventory_tools_view',
        displayName: 'عرض أدوات المخزون',
        description: 'عرض أدوات المخزون المساعدة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_barcode_scan',
        name: 'inventory_barcode_scan',
        displayName: 'مسح الباركود',
        description: 'استخدام قارئ الباركود للمنتجات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'inventory_reports_view',
        name: 'inventory_reports_view',
        displayName: 'عرض تقارير المخزون',
        description: 'عرض تقارير المخزون والإحصائيات',
        category: sectionName,
      ),
    ];
  }
}
