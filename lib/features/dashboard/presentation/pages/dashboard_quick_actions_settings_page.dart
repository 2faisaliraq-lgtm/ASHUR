import 'dart:convert';


import '../../../../core/widgets/loading_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';

/// صفحة إعدادات الإجراءات السريعة للداشبورد الرئيسي
class DashboardQuickActionsSettingsPage extends StatefulWidget {
  const DashboardQuickActionsSettingsPage({super.key});

  @override
  State<DashboardQuickActionsSettingsPage> createState() =>
      _DashboardQuickActionsSettingsPageState();
}

class _DashboardQuickActionsSettingsPageState
    extends State<DashboardQuickActionsSettingsPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  Map<String, bool> _userPermissions = {};
  bool _isLoading = true;

  // قائمة جميع الإجراءات المتاحة من جميع الأقسام
  final List<Map<String, dynamic>> _allActions = [
    // العملاء
    {
      'id': 'add_customer',
      'title': 'إضافة عميل',
      'subtitle': 'عميل جديد',
      'icon': Icons.person_add_outlined,
      'color': Colors.blue,
      'permission': 'customers_create',
      'section': 'العملاء',
      'enabled': false,
    },
    {
      'id': 'customers_list',
      'title': 'قائمة العملاء',
      'subtitle': 'عرض العملاء',
      'icon': Icons.list_alt_outlined,
      'color': Colors.blue,
      'permission': 'customers_view',
      'section': 'العملاء',
      'enabled': false,
    },
    {
      'id': 'customer_groups',
      'title': 'مجموعات العملاء',
      'subtitle': 'إدارة المجموعات',
      'icon': Icons.groups_outlined,
      'color': Colors.blue,
      'permission': 'customers_settings_manage',
      'section': 'العملاء',
      'enabled': false,
    },
    // المخزون
    {
      'id': 'add_product',
      'title': 'إضافة منتج',
      'subtitle': 'منتج جديد',
      'icon': Icons.add_shopping_cart_outlined,
      'color': Colors.orange,
      'permission': 'inventory_create',
      'section': 'المخزون',
      'enabled': false,
    },
    {
      'id': 'products_list',
      'title': 'المنتجات',
      'subtitle': 'قائمة المنتجات',
      'icon': Icons.inventory_2_outlined,
      'color': Colors.orange,
      'permission': 'inventory_view',
      'section': 'المخزون',
      'enabled': false,
    },
    {
      'id': 'categories',
      'title': 'الفئات',
      'subtitle': 'إدارة الفئات',
      'icon': Icons.category_outlined,
      'color': Colors.orange,
      'permission': 'inventory_categories_manage',
      'section': 'المخزون',
      'enabled': false,
    },
    {
      'id': 'shelves',
      'title': 'الأرفف',
      'subtitle': 'إدارة الأرفف',
      'icon': Icons.storage_outlined,
      'color': Colors.orange,
      'permission': 'inventory_view',
      'section': 'المخزون',
      'enabled': false,
    },
    // الاشتراكات
    {
      'id': 'add_subscription',
      'title': 'إضافة اشتراك',
      'subtitle': 'اشتراك جديد',
      'icon': Icons.subscriptions_outlined,
      'color': Colors.purple,
      'permission': 'subscriptions_create',
      'section': 'الاشتراكات',
      'enabled': false,
    },
    {
      'id': 'subscriptions_list',
      'title': 'الاشتراكات',
      'subtitle': 'قائمة الاشتراكات',
      'icon': Icons.list_alt_outlined,
      'color': Colors.purple,
      'permission': 'subscriptions_view',
      'section': 'الاشتراكات',
      'enabled': false,
    },
    {
      'id': 'subscription_types',
      'title': 'أنواع الاشتراكات',
      'subtitle': 'إدارة الأنواع',
      'icon': Icons.category_outlined,
      'color': Colors.purple,
      'permission': 'subscriptions_settings_manage',
      'section': 'الاشتراكات',
      'enabled': false,
    },
    // الصيانة
    {
      'id': 'add_maintenance',
      'title': 'إضافة طلب صيانة',
      'subtitle': 'طلب جديد',
      'icon': Icons.build_circle_outlined,
      'color': Colors.teal,
      'permission': 'maintenance_create',
      'section': 'الصيانة',
      'enabled': false,
    },
    {
      'id': 'maintenance_list',
      'title': 'قائمة الصيانة',
      'subtitle': 'عرض الطلبات',
      'icon': Icons.list_alt_outlined,
      'color': Colors.teal,
      'permission': 'maintenance_view',
      'section': 'الصيانة',
      'enabled': false,
    },
    // الإيجارات
    {
      'id': 'add_rental',
      'title': 'إضافة عقد إيجار',
      'subtitle': 'عقد جديد',
      'icon': Icons.home_work_outlined,
      'color': Colors.green,
      'permission': 'rentals_create',
      'section': 'الإيجارات',
      'enabled': false,
    },
    {
      'id': 'rentals_list',
      'title': 'قائمة الإيجارات',
      'subtitle': 'عرض العقود',
      'icon': Icons.list_alt_outlined,
      'color': Colors.green,
      'permission': 'rentals_view',
      'section': 'الإيجارات',
      'enabled': false,
    },
    {
      'id': 'rental_units',
      'title': 'الوحدات الإيجارية',
      'subtitle': 'إدارة الوحدات',
      'icon': Icons.apartment_outlined,
      'color': Colors.green,
      'permission': 'rentals_view',
      'section': 'الإيجارات',
      'enabled': false,
    },
    // الفواتير
    {
      'id': 'add_invoice',
      'title': 'إضافة فاتورة',
      'subtitle': 'فاتورة جديدة',
      'icon': Icons.receipt_long_outlined,
      'color': Colors.indigo,
      'permission': 'invoices_sales_manage',
      'alternativePermissions': [
        'invoices_purchase_manage',
        'invoices_cash_manage',
        'invoices_subscription_manage',
        'invoices_sales_return_manage',
      ],
      'section': 'الفواتير',
      'enabled': false,
    },
    {
      'id': 'invoices_list',
      'title': 'قائمة الفواتير',
      'subtitle': 'عرض الفواتير',
      'icon': Icons.list_alt_outlined,
      'color': Colors.indigo,
      'permission': 'invoices_sales_manage',
      'alternativePermissions': [
        'invoices_purchase_manage',
        'invoices_cash_manage',
        'invoices_subscription_manage',
        'invoices_sales_return_manage',
      ],
      'section': 'الفواتير',
      'enabled': false,
    },
    {
      'id': 'archived_invoices',
      'title': 'الفواتير المؤرشفة',
      'subtitle': 'الأرشيف',
      'icon': Icons.archive_outlined,
      'color': Colors.indigo,
      'permission': 'invoices_sales_manage',
      'alternativePermissions': [
        'invoices_purchase_manage',
        'invoices_cash_manage',
        'invoices_subscription_manage',
        'invoices_sales_return_manage',
      ],
      'section': 'الفواتير',
      'enabled': false,
    },
    // المصاريف
    {
      'id': 'add_expense',
      'title': 'إضافة مصروف',
      'subtitle': 'مصروف جديد',
      'icon': Icons.add_circle_outline,
      'color': Colors.red,
      'permission': 'expenses_create',
      'section': 'المصاريف',
      'enabled': false,
    },
    {
      'id': 'expenses_list',
      'title': 'قائمة المصاريف',
      'subtitle': 'عرض المصاريف',
      'icon': Icons.list_alt_outlined,
      'color': Colors.red,
      'permission': 'expenses_view',
      'section': 'المصاريف',
      'enabled': false,
    },
    // التقارير
    {
      'id': 'reports',
      'title': 'التقارير',
      'subtitle': 'عرض التقارير',
      'icon': Icons.analytics_outlined,
      'color': Colors.brown,
      'permission': 'reports_view',
      'section': 'التقارير',
      'enabled': false,
    },
    {
      'id': 'create_report',
      'title': 'إنشاء تقرير',
      'subtitle': 'تقرير جديد',
      'icon': Icons.add_chart_outlined,
      'color': Colors.brown,
      'permission': 'reports_create',
      'section': 'التقارير',
      'enabled': false,
    },
    {
      'id': 'cashbox',
      'title': 'الصندوق',
      'subtitle': 'تقرير الصندوق',
      'icon': Icons.payments_outlined,
      'color': const Color(0xFFD4AF37),
      'permission': 'cashbox_view',
      'section': 'التقارير',
      'enabled': false,
    },
    // المستخدمين
    {
      'id': 'add_user',
      'title': 'إضافة مستخدم',
      'subtitle': 'مستخدم جديد',
      'icon': Icons.person_add_outlined,
      'color': AssyrianTheme.primaryGold,
      'permission': 'users_create',
      'section': 'المستخدمين',
      'enabled': false,
    },
    {
      'id': 'users_list',
      'title': 'قائمة المستخدمين',
      'subtitle': 'عرض المستخدمين',
      'icon': Icons.list_alt_outlined,
      'color': AssyrianTheme.primaryGold,
      'permission': 'users_view',
      'section': 'المستخدمين',
      'enabled': false,
    },
    {
      'id': 'roles_management',
      'title': 'إدارة الأدوار',
      'subtitle': 'الصلاحيات',
      'icon': Icons.security_outlined,
      'color': AssyrianTheme.primaryGold,
      'permission': 'roles_manage',
      'section': 'المستخدمين',
      'enabled': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
  }

  /// تحميل صلاحيات المستخدم
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
    await _loadSavedActions();
  }

  /// التحقق من وجود صلاحية للإجراء
  bool _hasPermissionForAction(Map<String, dynamic> action) {
    final permission = action['permission'] as String?;
    final alternativePermissions =
        action['alternativePermissions'] as List<String>?;

    if (permission == null) return true; // لا توجد صلاحية مطلوبة

    // التحقق من الصلاحية الأساسية
    if (_userPermissions[permission] == true) return true;

    // التحقق من الصلاحيات البديلة
    if (alternativePermissions != null) {
      for (final altPermission in alternativePermissions) {
        if (_userPermissions[altPermission] == true) return true;
      }
    }

    return false;
  }

  Future<void> _loadSavedActions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedActions = prefs.getString('dashboard_quick_actions');

    if (savedActions != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedActions);
        setState(() {
          for (var action in _allActions) {
            final savedAction = decoded.cast<Map<String, dynamic>>().firstWhere(
              (a) => a['id'] == action['id'],
              orElse: () => {},
            );
            if (savedAction.isNotEmpty) {
              action['enabled'] = savedAction['enabled'] ?? false;
            }
          }
          _isLoading = false;
        });
      } on Exception catch (_) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في تحميل الإعدادات المحفوظة'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveActions() async {
    final enabledCount = _allActions.where((a) => a['enabled'] as bool).length;

    if (enabledCount > 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'يمكنك اختيار 6 إجراءات فقط',
              style: TextStyle(fontSize: 14.sp, fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final actionsData = _allActions
        .map((a) => {'id': a['id'], 'enabled': a['enabled']})
        .toList();
    await prefs.setString('dashboard_quick_actions', jsonEncode(actionsData));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ الإعدادات بنجاح',
            style: TextStyle(fontSize: 14.sp, fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _resetToDefaults() async {
    setState(() {
      for (var action in _allActions) {
        action['enabled'] = false;
      }
    });
    await _saveActions();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AssyrianTheme.backgroundGradient,
            boxShadow: [
              BoxShadow(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            AssyrianTheme.getLamassuForBackground(
              isDarkBackground: true,
              hasCircularBackground: false,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'إعدادات الإجراءات السريعة',
                    style: AssyrianTheme.titleStyle.copyWith(
                      fontSize: 18.sp,
                      color: AssyrianTheme.primaryGold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'اختر الإجراءات للداشبورد الرئيسي',
                    style: AssyrianTheme.subtitleStyle.copyWith(
                      fontSize: 10.sp,
                      color: AssyrianTheme.ivoryWhite,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _resetToDefaults,
            icon: Icon(
              Icons.restore,
              color: AssyrianTheme.primaryGold,
              size: 20.sp,
            ),
            label: Text(
              'افتراضي',
              style: TextStyle(
                fontSize: 12.sp,
                fontFamily: 'Cairo',
                color: AssyrianTheme.primaryGold,
              ),
            ),
          ),
          IconButton(
            onPressed: _saveActions,
            icon: Icon(
              Icons.save_outlined,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: _isLoading
          ? LoadingWidget(message: 'جاري التحميل...')
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    // حساب الإجراءات المتاحة وعدد المفعلة مرة واحدة قبل بناء الواجهة
    final availableActions = _allActions
        .where((action) => _hasPermissionForAction(action))
        .toList();
    final enabledCount = availableActions
        .where((action) => action['enabled'] as bool)
        .length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AssyrianTheme.primaryGold,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإجراءات السريعة',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          color: AssyrianTheme.deepBlue,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'يمكنك اختيار 6 إجراءات فقط للعرض في الداشبورد الرئيسي. قم بتفعيل الإجراءات التي تريدها.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontFamily: 'Cairo',
                          color: AssyrianTheme.deepBlue.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'الإجراءات المتاحة',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 16.h),
          if (availableActions.isNotEmpty) ...[
            // قائمة الإجراءات
            ...availableActions
                .map((action) => _buildActionTile(action, enabledCount)),
          ] else ...[
            // لا توجد إجراءات متاحة
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 48.sp,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'لا توجد إجراءات متاحة',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: Colors.grey.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'ليس لديك صلاحية لأي من الإجراءات المتاحة',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontFamily: 'Cairo',
                      color: Colors.grey.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveActions,
              icon: Icon(Icons.save, size: 20.sp),
              label: Text(
                'حفظ التغييرات',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(Map<String, dynamic> action, int enabledCount) {
    final isEnabled = action['enabled'] as bool;
    final isMaxReached = enabledCount >= 6 && !isEnabled;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isMaxReached
              ? null
              : () {
                  setState(() => action['enabled'] = !isEnabled);
                },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action['icon'] as IconData,
                    size: 24.sp,
                    color: action['color'] as Color,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action['title'] as String,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          color: isEnabled
                              ? AssyrianTheme.deepBlue
                              : Colors.grey,
                          decoration: isEnabled
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: (action['color'] as Color).withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              action['section'] as String,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontFamily: 'Cairo',
                                color: action['color'] as Color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              action['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontFamily: 'Cairo',
                                color: isEnabled
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: isEnabled,
                    onChanged: isMaxReached
                        ? null
                        : (value) {
                            setState(() => action['enabled'] = value);
                          },
                    activeThumbColor: AssyrianTheme.primaryGold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



