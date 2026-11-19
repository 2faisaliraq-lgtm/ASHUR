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
import '../pages/customer_quick_actions_settings_page.dart';

class CustomerQuickActions extends StatefulWidget {
  const CustomerQuickActions({
    super.key,
    this.onAddCustomer,
    this.onRefresh,
    this.onSettings,
  });

  final VoidCallback? onAddCustomer;
  final VoidCallback? onRefresh;
  final VoidCallback? onSettings;

  @override
  State<CustomerQuickActions> createState() => _CustomerQuickActionsState();
}

class _CustomerQuickActionsState extends State<CustomerQuickActions> {
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

  int _countAvailableActions() {
    int count = 0;
    if (_hasPermission('customers_create')) count++;
    if (_hasPermission('customers_view')) count++;
    if (_hasPermission('customers_settings_manage')) count += 2;
    if (_hasPermission('reports_view')) count++;
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
                  Icon(Icons.flash_on_outlined, color: AssyrianTheme.primaryGold, size: 20.sp),
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
                        builder: (context) => const CustomerQuickActionsSettingsPage(),
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
    final isMobile = ResponsiveHelper.isMobile(context);
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;

    return FutureBuilder<Map<String, bool>>(
      key: ValueKey('customer_quick_actions_$_rebuildKey'),
      future: _loadSavedActionsSettings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final savedSettings = snapshot.data!;
        final allActions = <Widget>[];

        // إضافة عميل - يتطلب صلاحية customers_create
        if (_hasPermission('customers_create') &&
            (savedSettings['add_customer'] ?? true)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.person_add_outlined,
              title: 'إضافة عميل',
              subtitle: 'عميل جديد',
              color: AssyrianTheme.primaryGold,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.createCustomer),
            ),
          );
        }

        // قائمة العملاء - يتطلب صلاحية customers_view
        if (_hasPermission('customers_view') &&
            (savedSettings['customers_list'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.list_alt_outlined,
              title: 'العملاء',
              subtitle: 'قائمة العملاء',
              color: Colors.teal,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.customersList),
            ),
          );
        }

        // مجموعات العملاء - يتطلب صلاحية customers_settings_manage
        if (_hasPermission('customers_settings_manage') &&
            (savedSettings['customer_groups'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.groups_outlined,
              title: 'مجموعات العملاء',
              subtitle: 'إدارة المجموعات',
              color: Colors.purple,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerGroupsList),
            ),
          );
        }

        // التقارير - يتطلب صلاحية reports_view
        if (_hasPermission('reports_view') &&
            (savedSettings['reports'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.analytics_outlined,
              title: 'التقارير',
              subtitle: 'إحصائيات مفصلة',
              color: Colors.blue,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.customersReports),
            ),
          );
        }

        // الإعدادات - يتطلب صلاحية customers_settings_manage
        if (_hasPermission('customers_settings_manage') &&
            (savedSettings['settings'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.settings_outlined,
              title: 'الإعدادات',
              subtitle: 'إعدادات العملاء',
              color: Colors.orange,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.customersSettings),
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

        if (allActions.isEmpty) return const SizedBox.shrink();

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

  Future<Map<String, bool>> _loadSavedActionsSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedActions = prefs.getString('customer_quick_actions');

    if (savedActions != null) {
      final List<dynamic> decoded = jsonDecode(savedActions);
      final settings = <String, bool>{};
      for (var item in decoded) {
        settings[item['id'] as String] = item['enabled'] as bool;
      }
      return settings;
    }

    return {
      'add_customer': false,
      'customers_list': false,
      'customer_groups': false,
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



