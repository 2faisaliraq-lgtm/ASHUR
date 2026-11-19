import '../../../../core/permissions/section_permissions.dart';
import '../../../users/domain/entities/permission_entity.dart';

/// Invoices section permissions
class InvoicesPermissions implements SectionPermissions {
  @override
  String get sectionName => 'invoices';

  @override
  String get sectionDisplayName => 'الفواتير';

  @override
  String get sectionIcon => 'receipt';

  @override
  List<PermissionEntity> getPermissions() {
    return [
      PermissionEntity(
        id: 'invoices_sales_manage',
        name: 'invoices_sales_manage',
        displayName: 'إدارة فواتير المبيعات',
        description: 'إنشاء وعرض وتعديل وحذف فواتير المبيعات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_purchase_manage',
        name: 'invoices_purchase_manage',
        displayName: 'إدارة فواتير المشتريات',
        description: 'إنشاء وعرض وتعديل وحذف فواتير المشتريات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_cash_manage',
        name: 'invoices_cash_manage',
        displayName: 'إدارة الفواتير النقدية',
        description: 'إنشاء وعرض وتعديل وحذف الفواتير النقدية والإيصالات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_subscription_manage',
        name: 'invoices_subscription_manage',
        displayName: 'إدارة فواتير الاشتراكات',
        description: 'إنشاء وعرض وتعديل وحذف فواتير الاشتراكات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_sales_return_manage',
        name: 'invoices_sales_return_manage',
        displayName: 'إدارة فواتير مرجع البيع',
        description: 'إنشاء وعرض وتعديل وحذف فواتير مرجع البيع (الإرجاع)',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_settings_view',
        name: 'invoices_settings_view',
        displayName: 'عرض إعدادات الفواتير',
        description: 'عرض إعدادات قسم الفواتير',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_settings_manage',
        name: 'invoices_settings_manage',
        displayName: 'إدارة إعدادات الفواتير',
        description: 'تعديل إعدادات قسم الفواتير',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_types_view',
        name: 'invoices_types_view',
        displayName: 'عرض أنواع الفواتير',
        description: 'عرض أنواع الفواتير المختلفة',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_payments_view',
        name: 'invoices_payments_view',
        displayName: 'عرض مدفوعات الفواتير',
        description: 'عرض مدفوعات وتحصيلات الفواتير',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_logs_view',
        name: 'invoices_logs_view',
        displayName: 'عرض سجلات الفواتير',
        description: 'عرض سجل حركات الفواتير والتعديلات',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_reports_view',
        name: 'invoices_reports_view',
        displayName: 'عرض تقارير الفواتير',
        description: 'عرض تقارير الفواتير والمبيعات',
        category: sectionName,
      ),
      // 🔧 إضافة الصلاحيات المفقودة لضمان عمل الصفحات correctamente:
      // invoices_delete تُستخدم في invoice_bloc.dart للتحقق من صلاحية الحذف.
      // invoices_archive_view تُستخدم في invoices_list_page.dart لعرض زر الأرشفة.
      // invoices_view_logs كانت تُستخدم خطأً في invoices_log_page.dart بدلاً من invoices_logs_view.
      // 🔧 إضافة صلاحيات العرض المنفصلة لكل نوع لتمكين المستخدمين من عرض الفواتير
      // دون الحاجة لصلاحية الإدارة الكاملة لكل نوع.
      PermissionEntity(
        id: 'invoices_delete',
        name: 'invoices_delete',
        displayName: 'حذف الفواتير',
        description: 'حذف فواتير من أي نوع',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_archive_view',
        name: 'invoices_archive_view',
        displayName: 'عرض أرشيف الفواتير',
        description: 'عرض الفواتير المؤرشفة',
        category: sectionName,
      ),
      // صلاحيات العرض المنفصلة لكل نوع (للتمييز بين العرض والإدارة)
      PermissionEntity(
        id: 'invoices_sales_view',
        name: 'invoices_sales_view',
        displayName: 'عرض فواتير المبيعات',
        description: 'عرض فواتير المبيعات فقط',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_purchase_view',
        name: 'invoices_purchase_view',
        displayName: 'عرض فواتير المشتريات',
        description: 'عرض فواتير المشتريات فقط',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_cash_view',
        name: 'invoices_cash_view',
        displayName: 'عرض الفواتير النقدية',
        description: 'عرض الفواتير النقدية فقط',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_subscription_view',
        name: 'invoices_subscription_view',
        displayName: 'عرض فواتير الاشتراكات',
        description: 'عرض فواتير الاشتراكات فقط',
        category: sectionName,
      ),
      PermissionEntity(
        id: 'invoices_sales_return_view',
        name: 'invoices_sales_return_view',
        displayName: 'عرض فواتير مرجع البيع',
        description: 'عرض فواتير مرجع البيع فقط',
        category: sectionName,
      ),
    ];
  }
}
