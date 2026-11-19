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
import '../pages/subscription_quick_actions_settings_page.dart';

class SubscriptionQuickActions extends StatefulWidget {
  const SubscriptionQuickActions({
    super.key,
    this.onAddSubscription,
    this.onRefresh,
    this.onSettings,
  });

  final VoidCallback? onAddSubscription;
  final VoidCallback? onRefresh;
  final VoidCallback? onSettings;

  @override
  State<SubscriptionQuickActions> createState() =>
      _SubscriptionQuickActionsState();
}

class _SubscriptionQuickActionsState extends State<SubscriptionQuickActions> {
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
    if (_hasPermission('subscriptions_create')) count++;
    if (_hasPermission('subscriptions_view')) count++;
    if (_hasPermission('subscriptions_settings_manage')) count += 2;
    if (_hasPermission('reports_view')) count++;
    count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
        child: LoadingWidget(message: 'جاري التحميل...'),
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
                        builder: (context) => const SubscriptionQuickActionsSettingsPage(),
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
          SizedBox(height: 2.h),
          _buildActionsGrid(context),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final crossAxisCount = isMobile ? 2 : 4;

    return FutureBuilder<Map<String, bool>>(
      key: ValueKey('subscription_quick_actions_$_rebuildKey'),
      future: _loadSavedActionsSettings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final savedSettings = snapshot.data!;
        final allActions = <Widget>[];

        if (_hasPermission('subscriptions_create') &&
            (savedSettings['add_subscription'] ?? true)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.subscriptions_outlined,
              title: 'إضافة اشتراك',
              subtitle: 'اشتراك جديد',
              color: AssyrianTheme.primaryGold,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.createSubscription),
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
              color: Colors.teal,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.subscriptionsList),
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
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.subscriptionTypesList),
            ),
          );
        }

        if (_hasPermission('reports_view') &&
            (savedSettings['reports'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.analytics_outlined,
              title: 'التقارير',
              subtitle: 'إحصائيات مفصلة',
              color: Colors.blue,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.subscriptionsReports),
            ),
          );
        }

        if (_hasPermission('subscriptions_settings_manage') &&
            (savedSettings['settings'] ?? false)) {
          allActions.add(
            _buildActionCard(
              context,
              icon: Icons.settings_outlined,
              title: 'الإعدادات',
              subtitle: 'إعدادات الاشتراكات',
              color: Colors.orange,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.subscriptionsSettings),
            ),
          );
        }

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

        final displayedActions = allActions.take(2).toList();
        if (displayedActions.isEmpty) return const SizedBox.shrink();

        // تحديد نسبة الارتفاع حسب حجم الشاشة
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
    final savedActions = prefs.getString('subscription_quick_actions');

    if (savedActions != null) {
      final List<dynamic> decoded = jsonDecode(savedActions);
      final settings = <String, bool>{};
      for (var item in decoded) {
        settings[item['id'] as String] = item['enabled'] as bool;
      }
      return settings;
    }

    return {
      'add_subscription': false,
      'subscriptions_list': false,
      'subscription_types': false,
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



