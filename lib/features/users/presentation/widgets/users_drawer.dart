import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../bloc/users_bloc.dart';
import '../pages/users_log_page.dart';

/// الشريط الجانبي الموحد لقسم المستخدمين
class UsersDrawer extends StatefulWidget {
  const UsersDrawer({super.key, this.currentRoute});
  final String? currentRoute;

  @override
  State<UsersDrawer> createState() => _UsersDrawerState();
}

class _UsersDrawerState extends State<UsersDrawer> {
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
              title: 'قسم المستخدمين',
              items: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'لوحة التحكم',
                  route: AppRoutes.dashboard,
                  isSelected: widget.currentRoute == AppRoutes.dashboard,
                ),
                if (_hasPermission('users_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.people_outline,
                    title: 'جميع المستخدمين',
                    route: AppRoutes.users,
                    isSelected: widget.currentRoute == AppRoutes.users,
                  ),
                if (_hasPermission('users_create'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.person_add_outlined,
                    title: 'إضافة مستخدم',
                    route: AppRoutes.createUser,
                    isSelected: widget.currentRoute == AppRoutes.createUser,
                  ),
              ],
            ),
            if (_hasPermission('roles_view') || _hasPermission('roles_manage'))
              _buildDrawerSection(
                context,
                title: 'الإدارة',
                items: [
                  if (_hasPermission('roles_manage'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'إدارة الأدوار',
                      route: AppRoutes.rolesManagement,
                      isSelected:
                          widget.currentRoute == AppRoutes.rolesManagement,
                    ),
                  if (_hasPermission('roles_create'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.add_moderator_outlined,
                      title: 'إضافة دور',
                      route: AppRoutes.createRole,
                      isSelected: widget.currentRoute == AppRoutes.createRole,
                    ),
                  if (_hasPermission('permissions_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.security_outlined,
                      title: 'الصلاحيات',
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            if (_hasPermission('users_reports_view'))
              _buildDrawerSection(
                context,
                title: 'التقارير والتحليل',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'تقارير المستخدمين',
                    route: AppRoutes.usersReports,
                    isSelected: widget.currentRoute == AppRoutes.usersReports,
                  ),
                  if (_hasPermission('users_logs_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_outlined,
                      title: 'سجل النشاطات',
                      isSelected: widget.currentRoute == AppRoutes.usersLog,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => BlocProvider<UsersBloc>.value(
                                value: GetIt.instance<UsersBloc>(),
                                child: const UsersLogPage(),
                              ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (_hasPermission('users_settings_view'))
              _buildDrawerSection(
                context,
                title: 'الإعدادات',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'إعدادات المستخدمين',
                    route: AppRoutes.usersSettings,
                    isSelected: widget.currentRoute == AppRoutes.usersSettings,
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
                  'إدارة المستخدمين',
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
    String? route,
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
      onTap:
          onTap ??
          () {
            Navigator.of(context).pop();
            if (route != null && !isSelected) {
              Navigator.of(context).pushNamed(route);
            }
          },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      dense: true,
    );
  }
}



