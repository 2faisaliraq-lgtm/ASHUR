import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/navigation/navigation_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../pages/dashboard_quick_actions_settings_page.dart';

class QuickActionsCard extends StatefulWidget {
  const QuickActionsCard({super.key});

  @override
  State<QuickActionsCard> createState() => _QuickActionsCardState();
}

class _QuickActionsCardState extends State<QuickActionsCard> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  Map<String, bool> _userPermissions = {};

  @override
  void initState() {
    super.initState();
    // تحميل مسبق للصلاحيات بشكل متزامن لتجنب الانتظار في build
    final syncPermissions = _permissionChecker.getCurrentPermissionsSync();
    _userPermissions = {};
    for (final p in syncPermissions) {
      _userPermissions[p] = true;
    }
    // تحديث الصلاحيات في الخلفية إذا تغيرت
    _loadUserPermissions();
  }

  Future<void> _loadUserPermissions() async {
    final permissions = await _permissionChecker.getUserPermissions();
    final permissionsMap = <String, bool>{};

    for (final permission in permissions) {
      permissionsMap[permission] = true;
    }

    if (mounted) {
      setState(() {
        _userPermissions = permissionsMap;
      });
    }
  }

  bool _hasPermission(String permission) {
    return _userPermissions[permission] ?? false;
  }

  /// التحقق من وجود أي صلاحية لإنشاء الفواتير
  bool _hasAnyInvoiceCreatePermission() {
    return _hasPermission('invoices_sales_manage') ||
        _hasPermission('invoices_purchase_manage') ||
        _hasPermission('invoices_cash_manage') ||
        _hasPermission('invoices_subscription_manage') ||
        _hasPermission('invoices_sales_return_manage');
  }

  /// حساب عدد الإجراءات المتاحة حسب الصلاحيات
  int _countAvailableActions() {
    int count = 0;

    // العملاء
    if (_hasPermission('customers_create')) count++;
    if (_hasPermission('customers_view')) count += 2;
    if (_hasPermission('customers_settings_manage')) count++;

    // المخزون
    if (_hasPermission('inventory_create')) count++;
    if (_hasPermission('inventory_view')) count += 2;
    if (_hasPermission('inventory_categories_manage')) count++;

    // الاشتراكات
    if (_hasPermission('subscriptions_create')) count++;
    if (_hasPermission('subscriptions_view')) count++;
    if (_hasPermission('subscriptions_settings_manage')) count++;

    // الصيانة
    if (_hasPermission('maintenance_create')) count++;
    if (_hasPermission('maintenance_view')) count++;

    // الإيجارات
    if (_hasPermission('rentals_create')) count++;
    if (_hasPermission('rentals_view')) count += 2;

    // الفواتير
    if (_hasAnyInvoiceCreatePermission()) count++;
    if (_hasAnyInvoiceCreatePermission()) count += 2; // قائمة + أرشيف

    // المصاريف
    if (_hasPermission('expenses_create')) count++;
    if (_hasPermission('expenses_view')) count++;

    // التقارير
    if (_hasPermission('reports_view')) count++;
    if (_hasPermission('reports_create')) count++;

    // الصندوق
    if (_hasPermission('cashbox_view')) count++;

    // المستخدمين
    if (_hasPermission('users_create')) count++;
    if (_hasPermission('users_view')) count++;
    if (_hasPermission('roles_manage')) count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final availableActionsCount = _countAvailableActions();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان وزر عرض الإعدادات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flash_on_outlined,
                    color: AssyrianTheme.primaryGold,
                    size: 24.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'الإجراءات السريعة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                ],
              ),
              if (availableActionsCount > 6)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const DashboardQuickActionsSettingsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    'عرض الكل',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontFamily: 'Cairo',
                      color: AssyrianTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AssyrianTheme.primaryGold,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildActionsGrid(context),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    // تحميل مسبق لإعدادات الإجراءات السريعة من NavigationService (محفوظة مسبقاً في شاشة السبلش)
    final savedSettings = NavigationService().quickActionsSettings.value;
    final allActions = <Widget>[];

    // === العملاء ===
    if (_hasPermission('customers_create') &&
        (savedSettings['add_customer'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.person_add_outlined,
          title: 'إضافة عميل',
          subtitle: 'عميل جديد',
          color: Colors.blue,
          onTap: () => Navigator.pushNamed(context, AppRoutes.createCustomer),
        ),
      );
    }

    if (_hasPermission('customers_view') &&
        (savedSettings['customers_list'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.list_alt_outlined,
          title: 'العملاء',
          subtitle: 'قائمة العملاء',
          color: Colors.blue,
          onTap: () => Navigator.pushNamed(context, AppRoutes.customersList),
        ),
      );
    }

    if (_hasPermission('customers_settings_manage') &&
        (savedSettings['customer_groups'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.groups_outlined,
          title: 'مجموعات العملاء',
          subtitle: 'إدارة المجموعات',
          color: Colors.blue,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.customerGroupsList),
        ),
      );
    }

    // === المخزون ===
    if (_hasPermission('inventory_create') &&
        (savedSettings['add_product'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.add_shopping_cart_outlined,
          title: 'إضافة منتج',
          subtitle: 'منتج جديد',
          color: Colors.orange,
          onTap: () => Navigator.pushNamed(context, AppRoutes.createProduct),
        ),
      );
    }

    if (_hasPermission('inventory_view') &&
        (savedSettings['products_list'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.inventory_2_outlined,
          title: 'المنتجات',
          subtitle: 'قائمة المنتجات',
          color: Colors.orange,
          onTap: () => Navigator.pushNamed(context, AppRoutes.productsList),
        ),
      );
    }

    if (_hasPermission('inventory_categories_manage') &&
        (savedSettings['categories'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.category_outlined,
          title: 'الفئات',
          subtitle: 'إدارة الفئات',
          color: Colors.orange,
          onTap: () => Navigator.pushNamed(context, AppRoutes.categoriesList),
        ),
      );
    }

    if (_hasPermission('inventory_view') &&
        (savedSettings['shelves'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.storage_outlined,
          title: 'الأرفف',
          subtitle: 'إدارة الأرفف',
          color: Colors.orange,
          onTap: () => Navigator.pushNamed(context, AppRoutes.shelvesList),
        ),
      );
    }

    // === الاشتراكات ===
    if (_hasPermission('subscriptions_create') &&
        (savedSettings['add_subscription'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.subscriptions_outlined,
          title: 'إضافة اشتراك',
          subtitle: 'اشتراك جديد',
          color: Colors.purple,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.createSubscription),
        ),
      );
    }

    if (_hasPermission('subscriptions_view') &&
        (savedSettings['subscriptions_list'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.list_alt_outlined,
          title: 'الاشتراكات',
          subtitle: 'قائمة الاشتراكات',
          color: Colors.purple,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.subscriptionsList),
        ),
      );
    }

    if (_hasPermission('subscriptions_settings_manage') &&
        (savedSettings['subscription_types'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.category_outlined,
          title: 'أنواع الاشتراكات',
          subtitle: 'إدارة الأنواع',
          color: Colors.purple,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.subscriptionTypesList),
        ),
      );
    }

    // === الصيانة ===
    if (_hasPermission('maintenance_create') &&
        (savedSettings['add_maintenance'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.build_circle_outlined,
          title: 'إضافة صيانة',
          subtitle: 'طلب جديد',
          color: Colors.teal,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.createMaintenanceRequest),
        ),
      );
    }

    if (_hasPermission('maintenance_view') &&
        (savedSettings['maintenance_list'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.list_alt_outlined,
          title: 'الصيانة',
          subtitle: 'قائمة الصيانة',
          color: Colors.teal,
          onTap: () => Navigator.pushNamed(context, AppRoutes.maintenanceList),
        ),
      );
    }

    // === الإيجارات ===
    if (_hasPermission('rentals_create') &&
        (savedSettings['add_rental'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.home_work_outlined,
          title: 'إضافة إيجار',
          subtitle: 'عقد جديد',
          color: Colors.green,
          onTap: () => Navigator.pushNamed(context, AppRoutes.createRental),
        ),
      );
    }

    if (_hasPermission('rentals_view') &&
        (savedSettings['rentals_list'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.list_alt_outlined,
          title: 'الإيجارات',
          subtitle: 'قائمة الإيجارات',
          color: Colors.green,
          onTap: () => Navigator.pushNamed(context, AppRoutes.rentalsList),
        ),
      );
    }

    if (_hasPermission('rentals_view') &&
        (savedSettings['rental_units'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.apartment_outlined,
          title: 'الوحدات',
          subtitle: 'الوحدات الإيجارية',
          color: Colors.green,
          onTap: () => Navigator.pushNamed(context, AppRoutes.rentalUnits),
        ),
      );
    }

    // === الفواتير ===
    if (_hasAnyInvoiceCreatePermission() &&
        (savedSettings['add_invoice'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.receipt_long_outlined,
          title: 'إضافة فاتورة',
          subtitle: 'فاتورة جديدة',
          color: Colors.indigo,
          onTap: () => Navigator.pushNamed(context, AppRoutes.createInvoice),
        ),
      );
    }

    if (_hasAnyInvoiceCreatePermission() &&
        (savedSettings['invoices_list'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.list_alt_outlined,
          title: 'الفواتير',
          subtitle: 'قائمة الفواتير',
          color: Colors.indigo,
          onTap: () => Navigator.pushNamed(context, AppRoutes.invoicesList),
        ),
      );
    }

    if (_hasAnyInvoiceCreatePermission() &&
        (savedSettings['archived_invoices'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.archive_outlined,
          title: 'الأرشيف',
          subtitle: 'الفواتير المؤرشفة',
          color: Colors.indigo,
          onTap: () => Navigator.pushNamed(context, AppRoutes.archivedInvoices),
        ),
      );
    }

    // === المصاريف ===
    if (_hasPermission('expenses_create') &&
        (savedSettings['add_expense'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.add_circle_outline,
          title: 'إضافة مصروف',
          subtitle: 'مصروف جديد',
          color: Colors.red,
          onTap: () => Navigator.pushNamed(context, AppRoutes.createExpense),
        ),
      );
    }

    if (_hasPermission('expenses_view') &&
        (savedSettings['expenses_list'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.list_alt_outlined,
          title: 'المصاريف',
          subtitle: 'قائمة المصاريف',
          color: Colors.red,
          onTap: () => Navigator.pushNamed(context, AppRoutes.expensesList),
        ),
      );
    }

    // === التقارير ===
    if (_hasPermission('reports_view') && (savedSettings['reports'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.analytics_outlined,
          title: 'التقارير',
          subtitle: 'عرض التقارير',
          color: Colors.brown,
          onTap: () => Navigator.pushNamed(context, AppRoutes.reports),
        ),
      );
    }

    if (_hasPermission('reports_create') &&
        (savedSettings['create_report'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.add_chart_outlined,
          title: 'إنشاء تقرير',
          subtitle: 'تقرير جديد',
          color: Colors.brown,
          onTap: () => Navigator.pushNamed(context, AppRoutes.createReport),
        ),
      );
    }

    // === الصندوق ===
    if (_hasPermission('cashbox_view') && (savedSettings['cashbox'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.payments_outlined,
          title: 'الصندوق',
          subtitle: 'تقرير الصندوق',
          color: const Color(0xFFD4AF37),
          onTap: () => Navigator.pushNamed(context, AppRoutes.cashbox),
        ),
      );
    }

    // === المستخدمين ===
    if (_hasPermission('users_create') &&
        (savedSettings['add_user'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.person_add_outlined,
          title: 'إضافة مستخدم',
          subtitle: 'مستخدم جديد',
          color: AssyrianTheme.primaryGold,
          onTap: () => Navigator.pushNamed(context, AppRoutes.createUser),
        ),
      );
    }

    if (_hasPermission('users_view') &&
        (savedSettings['users_list'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.list_alt_outlined,
          title: 'المستخدمين',
          subtitle: 'قائمة المستخدمين',
          color: AssyrianTheme.primaryGold,
          onTap: () => Navigator.pushNamed(context, AppRoutes.users),
        ),
      );
    }

    if (_hasPermission('roles_manage') &&
        (savedSettings['roles_management'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.security_outlined,
          title: 'الأدوار',
          subtitle: 'إدارة الأدوار',
          color: AssyrianTheme.primaryGold,
          onTap: () => Navigator.pushNamed(context, AppRoutes.rolesManagement),
        ),
      );
    }

    // === اختبار الإشعارات ===
    if (_hasPermission('settings_manage')) {
      // عرض جميع الإجراءات المتاحة (كل صف زرين)
      if (allActions.isEmpty && _userPermissions.isEmpty) {
        // قبل تحميل الصلاحيات، عرض إجراءات افتراضية لتجنب ظهور الشاشة فارغة
        return Column(
          children: [
            SizedBox(
              height: 200.h,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 4.w,
                  mainAxisSpacing: 4.h,
                  childAspectRatio: 3.5,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final icons = [
                    Icons.person_add_outlined,
                    Icons.list_alt_outlined,
                    Icons.add_shopping_cart_outlined,
                    Icons.inventory_2_outlined,
                    Icons.receipt_long_outlined,
                    Icons.analytics_outlined,
                  ];
                  final titles = [
                    'إضافة عميل',
                    'العملاء',
                    'إضافة منتج',
                    'المنتجات',
                    'إضافة فاتورة',
                    'التقارير',
                  ];
                  final colors = [
                    Colors.blue,
                    Colors.blue,
                    Colors.orange,
                    Colors.orange,
                    Colors.indigo,
                    Colors.brown,
                  ];
                  return _buildActionCard(
                    context,
                    icon: icons[index],
                    title: titles[index],
                    subtitle: 'جاري تحميل الصلاحيات...',
                    color: colors[index],
                    onTap: null,
                  );
                },
              ),
            ),
          ],
        );
      }

      if (allActions.isEmpty) {
        return const SizedBox.shrink();
      }

      // تحديد نسبة الارتفاع حسب حجم الشاشة
      final isMobile = ResponsiveHelper.isMobile(context);
      final childAspectRatio = isMobile ? 3.5 : 5.0;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4.w,
          mainAxisSpacing: 4.h,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: allActions.length,
        itemBuilder: (context, index) => allActions[index],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 9.sp, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 4.w),
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16.sp, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
