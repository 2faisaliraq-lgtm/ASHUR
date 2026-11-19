import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../bloc/customer_bloc.dart';
import '../pages/customers_log_page.dart';

/// الشريط الجانبي الموحد لقسم العملاء
class CustomerDrawer extends StatefulWidget {
  const CustomerDrawer({
    super.key,
    this.currentRoute,
    this.onAddCustomer,
    this.onViewCustomers,
    this.onViewReports,
    this.onSettings,
  });
  final String? currentRoute;
  final VoidCallback? onAddCustomer;
  final VoidCallback? onViewCustomers;
  final VoidCallback? onViewReports;
  final VoidCallback? onSettings;

  @override
  State<CustomerDrawer> createState() => _CustomerDrawerState();
}

class _CustomerDrawerState extends State<CustomerDrawer> {
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
              title: 'العملاء الرئيسية',
              items: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'لوحة التحكم',
                  isSelected: widget.currentRoute == 'dashboard',
                  onTap: () => Navigator.of(context).pop(),
                ),
                if (_hasPermission('customers_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.people_outline,
                    title: 'جميع العملاء',
                    isSelected: widget.currentRoute == AppRoutes.customersList,
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onViewCustomers != null) {
                        widget.onViewCustomers!();
                      } else {
                        Navigator.of(context).pushNamed(AppRoutes.customersList);
                      }
                    },
                  ),
                if (_hasPermission('customers_create'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.person_add_outlined,
                    title: 'إضافة عميل',
                    isSelected: widget.currentRoute == AppRoutes.createCustomer,
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onAddCustomer != null) {
                        widget.onAddCustomer!();
                      } else {
                        Navigator.of(context).pushNamed(AppRoutes.createCustomer);
                      }
                    },
                  ),
              ],
            ),
            if (_hasPermission('customers_groups_view'))
              _buildDrawerSection(
                context,
                title: 'إدارة المجموعات',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.group_outlined,
                    title: 'مجموعات العملاء',
                    isSelected: widget.currentRoute == 'customer_groups',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.customerGroupsList);
                    },
                  ),
                  if (_hasPermission('customers_groups_create'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.group_add_outlined,
                      title: 'إضافة مجموعة',
                      isSelected: widget.currentRoute == 'create_customer_group',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.createCustomerGroup);
                      },
                    ),
                ],
              ),
            if (_hasPermission('customers_reports_view'))
              _buildDrawerSection(
                context,
                title: 'التقارير والتحليل',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'تقارير العملاء',
                    isSelected: widget.currentRoute == AppRoutes.customersReports,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(AppRoutes.customersReports);
                    },
                  ),
                  if (_hasPermission('customers_logs_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_outlined,
                      title: 'سجل العملاء',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (context) => GetIt.instance<CustomerBloc>(),
                              child: const CustomersLogPage(),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (_hasPermission('customers_settings_view'))
              _buildDrawerSection(
                context,
                title: 'الإعدادات',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'إعدادات العملاء',
                    isSelected: widget.currentRoute == 'settings',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onSettings != null) widget.onSettings!();
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
                  'إدارة العملاء',
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



