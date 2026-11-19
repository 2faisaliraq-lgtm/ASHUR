import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/theme/assyrian_theme.dart';

/// الشريط الجانبي الموحد لقسم الاشتراكات
class SubscriptionDrawer extends StatefulWidget {
  const SubscriptionDrawer({
    super.key,
    this.currentRoute,
    this.onAddSubscription,
    this.onViewReports,
    this.onViewHistory,
    this.onSettings,
  });
  final String? currentRoute;
  final VoidCallback? onAddSubscription;
  final VoidCallback? onViewReports;
  final VoidCallback? onViewHistory;
  final VoidCallback? onSettings;

  @override
  State<SubscriptionDrawer> createState() => _SubscriptionDrawerState();
}

class _SubscriptionDrawerState extends State<SubscriptionDrawer> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  Map<String, bool> _userPermissions = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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
        _isLoading = false;
      });
    }
  }

  bool _hasPermission(String permission) {
    return _userPermissions[permission] ?? false;
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
            _buildDrawerHeader(context),
            _buildDrawerSection(
              context,
              title: 'الاشتراكات الرئيسية',
              items: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'لوحة التحكم',
                  isSelected: widget.currentRoute == 'dashboard',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                if (_hasPermission('subscriptions_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.subscriptions_outlined,
                    title: 'جميع الاشتراكات',
                    isSelected: widget.currentRoute == 'subscriptions',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.subscriptionsList);
                    },
                  ),
                if (_hasPermission('subscriptions_create'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.add_box_outlined,
                    title: 'إضافة اشتراك',
                    isSelected: widget.currentRoute == 'add_subscription',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onAddSubscription != null) {
                        widget.onAddSubscription!();
                      } else {
                        Navigator.pushNamed(context, '/subscriptions/create');
                      }
                    },
                  ),
                if (_hasPermission('subscription_types_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.category_outlined,
                    title: 'أنواع الاشتراكات',
                    isSelected: widget.currentRoute == 'subscription_types',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.subscriptionTypesList);
                    },
                  ),
              ],
            ),
            if (_hasPermission('subscriptions_reports_view'))
              _buildDrawerSection(
                context,
                title: 'التقارير والتحليل',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'تقارير الاشتراكات',
                    isSelected: widget.currentRoute == 'reports',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.subscriptionsReports);
                    },
                  ),
                  if (_hasPermission('subscriptions_logs_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_outlined,
                      title: 'سجل الاشتراكات',
                      isSelected: widget.currentRoute == 'history',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed(AppRoutes.subscriptionsLog);
                      },
                    ),
                ],
              ),
            if (_hasPermission('subscriptions_settings_view'))
              _buildDrawerSection(
                context,
                title: 'الأدوات',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'إعدادات الاشتراكات',
                    isSelected: widget.currentRoute == 'settings',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onSettings != null) {
                        widget.onSettings!();
                      }
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
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
                  'إدارة الاشتراكات',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 16.sp,
                    color: AssyrianTheme.primaryGold,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Text(
                  'نظام إدارة المتاجر',
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

  Widget _buildDrawerSection(
    BuildContext context, {
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AssyrianTheme.primaryGold : AssyrianTheme.deepBlue,
        size: 20.sp,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14.sp,
          color: isSelected
              ? AssyrianTheme.primaryGold
              : AssyrianTheme.deepBlue,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      dense: true,
    );
  }
}



