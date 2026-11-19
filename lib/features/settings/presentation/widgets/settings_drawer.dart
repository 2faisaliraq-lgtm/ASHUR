import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/theme/assyrian_theme.dart';

/// الشريط الجانبي الموحد لقسم الإعدادات
class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key, this.currentRoute});

  final String? currentRoute;

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
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

  void _navigateToPage(BuildContext context, String route) {
    if (widget.currentRoute == route) {
      Navigator.of(context).pop();
      return;
    }

    // Close drawer first
    Navigator.of(context).pop();

    // Use pushNamed instead of pushReplacementNamed for better tablet compatibility
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pushNamed(route);
      }
    });
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
              title: 'الإعدادات الرئيسية',
              icon: Icons.settings,
              items: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'لوحة التحكم',
                  isSelected: widget.currentRoute == '/settings/dashboard',
                  onTap: () => _navigateToPage(context, AppRoutes.settingsList),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'الإعدادات العامة',
                  isSelected: widget.currentRoute == '/settings',
                  onTap: () => _navigateToPage(context, AppRoutes.settings),
                ),
              ],
            ),
            _buildDrawerSection(
              context,
              title: 'إعدادات النظام',
              icon: Icons.tune,
              items: [
                _buildDrawerItem(
                  context,
                  icon: Icons.view_module_outlined,
                  title: 'إدارة الأقسام',
                  isSelected: widget.currentRoute == '/settings/modules',
                  onTap: () =>
                      _navigateToPage(context, AppRoutes.systemSettings),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.format_paint_outlined,
                  title: 'التنسيق والعرض',
                  isSelected: widget.currentRoute == '/settings/formatting',
                  onTap: () =>
                      _navigateToPage(context, AppRoutes.formattingSettings),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.notifications_outlined,
                  title: 'الإشعارات',
                  isSelected: widget.currentRoute == '/settings/notifications',
                  onTap: () =>
                      _navigateToPage(context, AppRoutes.notificationSettings),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'إعدادات PDF',
                  isSelected: widget.currentRoute == '/settings/pdf',
                  onTap: () => _navigateToPage(context, AppRoutes.pdfSettings),
                ),
              ],
            ),
            _buildDrawerSection(
              context,
              title: 'إعدادات الأقسام',
              icon: Icons.category,
              items: [
                if (_hasPermission('invoices_settings_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: 'الفواتير',
                    isSelected: widget.currentRoute == '/invoices/settings',
                    onTap: () => _navigateToPage(context, '/invoices/settings'),
                  ),
                if (_hasPermission('customers_settings_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.people_outlined,
                    title: 'العملاء',
                    isSelected: widget.currentRoute == '/customers/settings',
                    onTap: () =>
                        _navigateToPage(context, '/customers/settings'),
                  ),
                if (_hasPermission('inventory_settings_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.inventory_2_outlined,
                    title: 'المخزون',
                    isSelected: widget.currentRoute == '/inventory/settings',
                    onTap: () =>
                        _navigateToPage(context, '/inventory/settings'),
                  ),
                if (_hasPermission('subscriptions_settings_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.subscriptions_outlined,
                    title: 'الاشتراكات',
                    isSelected:
                        widget.currentRoute == '/subscriptions/settings',
                    onTap: () =>
                        _navigateToPage(context, '/subscriptions/settings'),
                  ),
                if (_hasPermission('maintenance_settings_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.build_outlined,
                    title: 'الصيانة',
                    isSelected: widget.currentRoute == '/maintenance/settings',
                    onTap: () =>
                        _navigateToPage(context, '/maintenance/settings'),
                  ),
                if (_hasPermission('rentals_settings_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.car_rental_outlined,
                    title: 'الإيجارات',
                    isSelected: widget.currentRoute == '/rentals/settings',
                    onTap: () => _navigateToPage(context, '/rentals/settings'),
                  ),
                if (_hasPermission('expenses_settings_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.money_off_outlined,
                    title: 'المصاريف',
                    isSelected: widget.currentRoute == '/expenses/settings',
                    onTap: () => _navigateToPage(context, '/expenses/settings'),
                  ),
                if (_hasPermission('reports_settings_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.assessment_outlined,
                    title: 'التقارير',
                    isSelected: widget.currentRoute == '/reports/settings',
                    onTap: () => _navigateToPage(context, '/reports/settings'),
                  ),
                if (_hasPermission('users_settings_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'المستخدمين',
                    isSelected: widget.currentRoute == '/users/settings',
                    onTap: () => _navigateToPage(context, '/users/settings'),
                  ),
              ],
            ),
            _buildDrawerSection(
              context,
              title: 'أدوات متقدمة',
              icon: Icons.construction,
              items: [
                if (_hasPermission('settings_advanced'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.swap_horiz_outlined,
                    title: 'ترحيل المعرفات',
                    isSelected: widget.currentRoute == '/settings/id-migration',
                    onTap: () {
                      Navigator.of(context).pop();
                      // Add ID migration route when available
                    },
                  ),
                if (_hasPermission('settings_advanced'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.backup_outlined,
                    title: 'النسخ الاحتياطي',
                    isSelected: widget.currentRoute == '/settings/backup',
                    onTap: () {
                      Navigator.of(context).pop();
                      // Add backup route when available
                    },
                  ),
                if (_hasPermission('settings_advanced'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.security_outlined,
                    title: 'الأمان والصلاحيات',
                    isSelected: widget.currentRoute == '/settings/security',
                    onTap: () {
                      Navigator.of(context).pop();
                      // Add security route when available
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
                  'الإعدادات',
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
    required IconData icon,
    required List<Widget> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AssyrianTheme.primaryGold.withValues(alpha: 0.15),
                AssyrianTheme.primaryGold.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16.sp, color: AssyrianTheme.deepBlue),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        ...items,
        const SizedBox(height: 4),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected
            ? AssyrianTheme.primaryGold.withValues(alpha: 0.15)
            : Colors.transparent,
        border: isSelected
            ? Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected
                ? AssyrianTheme.primaryGold.withValues(alpha: 0.2)
                : AssyrianTheme.deepBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: isSelected
                ? AssyrianTheme.primaryGold
                : AssyrianTheme.deepBlue,
            size: 18.sp,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13.sp,
            color: isSelected
                ? AssyrianTheme.primaryGold
                : AssyrianTheme.deepBlue,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.arrow_forward_ios,
                size: 14.sp,
                color: AssyrianTheme.primaryGold,
              )
            : null,
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}



