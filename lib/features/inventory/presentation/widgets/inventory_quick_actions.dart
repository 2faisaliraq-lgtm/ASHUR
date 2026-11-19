import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/navigation/navigation_service.dart';
import '../pages/inventory_quick_actions_settings_page.dart';

class InventoryQuickActions extends StatefulWidget {
  const InventoryQuickActions({
    super.key,
    this.onAddProduct,
    this.onManageCategories,
    this.onViewReports,
    this.onScanBarcode,
    this.onSettings,
    this.onRefresh,
  });

  final VoidCallback? onAddProduct;
  final VoidCallback? onManageCategories;
  final VoidCallback? onViewReports;
  final VoidCallback? onScanBarcode;
  final VoidCallback? onSettings;
  final VoidCallback? onRefresh;

  @override
  State<InventoryQuickActions> createState() => _InventoryQuickActionsState();
}

class _InventoryQuickActionsState extends State<InventoryQuickActions> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  Map<String, bool> _userPermissions = {};
  bool _isLoading = true;
  int _rebuildKey = 0;

  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
    NavigationService().quickActionsSettingsNotifier.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() => _rebuildKey++);
    }
  }

  @override
  void dispose() {
    NavigationService().quickActionsSettingsNotifier.removeListener(_onSettingsChanged);
    super.dispose();
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
        _isLoading = false;
      });
    }
  }

  bool _hasPermission(String permission) {
    return _userPermissions[permission] ?? false;
  }

  /// حساب عدد الإجراءات المتاحة حسب الصلاحيات (بغض النظر عن التفعيل)
  int _countAvailableActions() {
    int count = 0;

    if (_hasPermission('inventory_create')) count++;
    if (_hasPermission('inventory_view')) count += 2; // products_list + shelves
    if (_hasPermission('inventory_categories_manage')) count++;
    // ⚠️ ملاحظة للمبرمجين المستقبليين: يجب أن يطابق هذا المفتاح ما هو معرّف
    // في inventory_permissions.dart ('inventory_reports_view'). استخدام
    // مفتاح مختلف مثل 'reports_view' سيجعل العداد والتقارير غير متطابقة.
    if (_hasPermission('inventory_reports_view')) count++;
    if (_hasPermission('inventory_settings_manage')) count++;
    // Refresh button - always available
    count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: const LoadingWidget(message: 'جاري التحميل...'),
      );
    }

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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flash_on_outlined,
                    color: AssyrianTheme.primaryGold,
                    size: 20.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'الإجراءات السريعة',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
              if (availableActionsCount > 2)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const InventoryQuickActionsSettingsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(
                    'عرض جميع الإجراءات',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontFamily: 'Cairo',
                      color: AssyrianTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AssyrianTheme.primaryGold,
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          _buildActionsGrid(context),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    // بناء قائمة الإجراءات بناءً على الصلاحيات والإعدادات المحفوظة
    return FutureBuilder<Map<String, bool>>(
      key: ValueKey('inventory_quick_actions_$_rebuildKey'),
      future: _loadSavedActionsSettings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // عرض Grid فارغ أثناء التحميل
          return const SizedBox.shrink();
        }

        final savedSettings = snapshot.data!;
        final allActions = <Widget>[];

        // إضافة منتج - يتطلب صلاحية inventory_create
        if (_hasPermission('inventory_create') &&
            (savedSettings['add_product'] ?? true)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.add_shopping_cart_outlined,
              title: 'إضافة منتج',
              subtitle: 'منتج جديد',
              color: AssyrianTheme.primaryGold,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.createProduct);
              },
            ),
          );
        }

        // قائمة المنتجات - يتطلب صلاحية inventory_view
        if (_hasPermission('inventory_view') &&
            (savedSettings['products_list'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'المنتجات',
              subtitle: 'قائمة المنتجات',
              color: Colors.teal,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.productsList);
              },
            ),
          );
        }

        // الفئات - يتطلب صلاحية inventory_categories_manage
        if (_hasPermission('inventory_categories_manage') &&
            (savedSettings['categories'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.category_outlined,
              title: 'الفئات',
              subtitle: 'إدارة الفئات',
              color: Colors.indigo,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.categoriesList);
              },
            ),
          );
        }

        // الأرفف - يتطلب صلاحية inventory_view
        if (_hasPermission('inventory_view') &&
            (savedSettings['shelves'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.storage_outlined,
              title: 'الأرفف',
              subtitle: 'إدارة الأرفف',
              color: Colors.brown,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.shelvesList);
              },
            ),
          );
        }

        // التقارير - يتطلب صلاحية inventory_reports_view
        if (_hasPermission('inventory_reports_view') &&
            (savedSettings['reports'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.analytics_outlined,
              title: 'التقارير',
              subtitle: 'إحصائيات مفصلة',
              color: Colors.blue,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.inventoryReports);
              },
            ),
          );
        }

        // الإعدادات - يتطلب صلاحية inventory_settings_manage
        if (_hasPermission('inventory_settings_manage') &&
            (savedSettings['settings'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.settings_outlined,
              title: 'الإعدادات',
              subtitle: 'إعدادات المخزون',
              color: Colors.orange,
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.inventorySettings);
              },
            ),
          );
        }

        // تحديث - متاح للجميع
        if (savedSettings['refresh'] ?? true) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.refresh_outlined,
              title: 'تحديث',
              subtitle: 'تحديث البيانات',
              color: Colors.green,
              onTap: widget.onRefresh,
            ),
          );
        }

        // عرض جميع الإجراءات المتاحة (كل صف زرين)
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
      },
    );
  }

  /// تحميل إعدادات الإجراءات المحفوظة
  Future<Map<String, bool>> _loadSavedActionsSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedActions = prefs.getString('inventory_quick_actions');

    if (savedActions != null) {
      final List<dynamic> decoded = jsonDecode(savedActions);
      final settings = <String, bool>{};
      for (var item in decoded) {
        settings[item['id'] as String] = item['enabled'] as bool;
      }
      return settings;
    }

    // لا توجد إعدادات افتراضية - المستخدم يختار بحرية
    return {
      'add_product': false,
      'products_list': false,
      'categories': false,
      'shelves': false,
      'reports': false,
      'settings': false,
      'refresh': false,
    };
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
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10.r),
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
                  SizedBox(height: 6.h),
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



