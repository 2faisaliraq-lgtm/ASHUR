import '../../../../core/widgets/loading_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/services/enabled_modules_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class DashboardDrawer extends StatefulWidget {
  const DashboardDrawer({super.key});

  @override
  State<DashboardDrawer> createState() => _DashboardDrawerState();
}

class _DashboardDrawerState extends State<DashboardDrawer> {
  final _modulesService = EnabledModulesService();
  final PermissionChecker _permissionChecker = PermissionChecker();
  Map<String, bool> _enabledModules = {};
  Map<String, bool> _userPermissions = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEnabledModules();
    _loadUserPermissions();
  }

  Future<void> _loadEnabledModules() async {
    try {
      final modules = await _modulesService.getEnabledModules();
      if (mounted) {
        setState(() {
          _enabledModules = modules;
        });
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserPermissions() async {
    try {
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
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isModuleEnabled(String moduleId) {
    return _enabledModules[moduleId] ?? false;
  }

  bool _hasPermission(String permission) {
    return _userPermissions[permission] ?? false;
  }

  /// التحقق من وجود أي قسم فواتير مفعل
  /// ⚠️ ملاحظة: هذه الدالة مكررة في quick_actions_card.dart (_hasAnyInvoiceCreatePermission / _hasAnyInvoiceViewPermission)
  /// يُفضل تجميعها في موقع واحد (مثل core/permissions) لتجنب التكرار المستقبلي.
  bool _hasAnyInvoiceModuleEnabled() {
    return _isModuleEnabled('invoices_sales_manage') ||
        _isModuleEnabled('invoices_purchase_manage') ||
        _isModuleEnabled('invoices_cash_manage') ||
        _isModuleEnabled('invoices_subscription_manage') ||
        _isModuleEnabled('invoices_sales_return_manage');
  }

  /// التحقق من وجود أي صلاحية لعرض الفواتير
  /// ⚠️ ملاحظة: هذه الدالة مكررة في quick_actions_card.dart - يُفضل تجميعها في موقع واحد.
  bool _hasAnyInvoicePermission() {
    return _hasPermission('invoices_sales_manage') ||
        _hasPermission('invoices_purchase_manage') ||
        _hasPermission('invoices_cash_manage') ||
        _hasPermission('invoices_subscription_manage') ||
        _hasPermission('invoices_sales_return_manage');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Drawer(
        backgroundColor: AssyrianTheme.ivoryWhite,
        child: LoadingWidget(message: 'جاري التحميل...'),
      );
    }

    return Drawer(
      backgroundColor: AssyrianTheme.ivoryWhite,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AssyrianTheme.ivoryWhite,
              AssyrianTheme.ivoryWhite.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildDrawerHeader(),
            _buildDrawerItem(
              context,
              Icons.dashboard,
              'الصفحة الرئيسية',
              () => Navigator.pop(context),
              isSelected: true,
            ),
            if (_isModuleEnabled('users_view') && _hasPermission('users_view'))
              _buildDrawerItem(context, Icons.people, 'إدارة المستخدمين', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/users/list');
              }),
            if (_isModuleEnabled('customers_view') &&
                _hasPermission('customers_view'))
              _buildDrawerItem(
                context,
                Icons.people_outline,
                'إدارة العملاء',
                () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/customers/list');
                },
              ),
            if (_isModuleEnabled('inventory_view') &&
                _hasPermission('inventory_view'))
              _buildDrawerItem(context, Icons.inventory_2, 'إدارة المخزون', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/inventory/list');
              }),
            if (_isModuleEnabled('subscriptions_view') &&
                _hasPermission('subscriptions_view'))
              _buildDrawerItem(
                context,
                Icons.subscriptions,
                'إدارة الاشتراكات',
                () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/subscriptions/list');
                },
              ),
            if (_hasAnyInvoiceModuleEnabled() && _hasAnyInvoicePermission())
              _buildDrawerItem(
                context,
                Icons.receipt_long,
                'إدارة الفواتير',
                () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/invoices/list');
                },
              ),
            if (_isModuleEnabled('rentals_view') &&
                _hasPermission('rentals_view'))
              _buildDrawerItem(context, Icons.home_work, 'إدارة الإيجارات', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/rentals/list');
              }),
            if (_isModuleEnabled('maintenance_view') &&
                _hasPermission('maintenance_view'))
              _buildDrawerItem(context, Icons.build, 'إدارة الصيانة', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/maintenance/list');
              }),
            if (_isModuleEnabled('expenses_view') &&
                _hasPermission('expenses_view'))
              _buildDrawerItem(context, Icons.money_off, 'إدارة المصروفات', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/expenses/list');
              }),
            if (_isModuleEnabled('reports_view') &&
                _hasPermission('reports_view'))
              _buildDrawerItem(
                context,
                Icons.analytics,
                'التقارير والإحصائيات',
                () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/reports/list');
                },
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Divider(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                thickness: 1,
              ),
            ),
            if (_isModuleEnabled('settings_view') &&
                _hasPermission('settings_view'))
              _buildDrawerItem(context, Icons.settings, 'الإعدادات', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings/list');
              }),
            _buildDrawerItem(context, Icons.logout, 'تسجيل الخروج', () {
              Navigator.pop(context);
              _confirmLogout(context);
            }, isLogout: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 3,
            child: AssyrianTheme.getLamassuForBackground(
              isDarkBackground: true,
            ),
          ),
          SizedBox(height: 4.h),
          Flexible(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'آشور',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 18.sp,
                    color: AssyrianTheme.primaryGold,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Text(
                  'نظام إدارة المستخدمين',
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: 9.sp,
                    color: AssyrianTheme.ivoryWhite,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isSelected = false,
    bool isLogout = false,
  }) {
    final color = isLogout
        ? AssyrianTheme.crimsonRed
        : isSelected
        ? AssyrianTheme.primaryGold
        : AssyrianTheme.deepBlue;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                  AssyrianTheme.bronzeBrown.withValues(alpha: 0.05),
                ],
              )
            : null,
        border: isSelected
            ? Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          title: Text(
            title,
            style: AssyrianTheme.bodyStyle.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 16.sp,
            ),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    );
  }

  /// تأكيد تسجيل الخروج قبل التنفيذ لتجنب الخروج العرضي
  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.crimsonRed,
            ),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      context.read<AuthBloc>().add(SignOutRequested());
    }
  }
}
