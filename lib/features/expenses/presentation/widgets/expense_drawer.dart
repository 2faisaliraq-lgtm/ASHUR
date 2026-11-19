import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/theme/assyrian_theme.dart';

/// الشريط الجانبي الموحد لقسم المصاريف
class ExpenseDrawer extends StatefulWidget {
  const ExpenseDrawer({
    super.key,
    this.currentRoute,
    this.onAddExpense,
    this.onViewExpenses,
    this.onViewReports,
    this.onViewHistory,
    this.onSettings,
  });
  final String? currentRoute;
  final VoidCallback? onAddExpense;
  final VoidCallback? onViewExpenses;
  final VoidCallback? onViewReports;
  final VoidCallback? onViewHistory;
  final VoidCallback? onSettings;

  @override
  State<ExpenseDrawer> createState() => _ExpenseDrawerState();
}

class _ExpenseDrawerState extends State<ExpenseDrawer> {
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
              title: 'المصاريف الرئيسية',
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
                if (_hasPermission('expenses_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: 'جميع المصاريف',
                    isSelected: widget.currentRoute == 'expenses',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, '/expenses/list');
                    },
                  ),
                if (_hasPermission('expenses_create'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.add_box_outlined,
                    title: 'إضافة مصروف',
                    isSelected: widget.currentRoute == 'add_expense',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onAddExpense != null) {
                        widget.onAddExpense!();
                      } else {
                        Navigator.pushNamed(context, AppRoutes.createExpense);
                      }
                    },
                  ),
              ],
            ),
            if (_hasPermission('expenses_types_view'))
              _buildDrawerSection(
                context,
                title: 'أنواع المصاريف',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.business_outlined,
                    title: 'مصاريف تشغيلية',
                    isSelected: widget.currentRoute == 'operational',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('صفحة المصاريف التشغيلية قيد التطوير'),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.build_outlined,
                    title: 'مصاريف صيانة',
                    isSelected: widget.currentRoute == 'maintenance',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('صفحة مصاريف الصيانة قيد التطوير'),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people_outlined,
                    title: 'مصاريف الموظفين',
                    isSelected: widget.currentRoute == 'employees',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('صفحة مصاريف الموظفين قيد التطوير'),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.more_horiz_outlined,
                    title: 'مصاريف أخرى',
                    isSelected: widget.currentRoute == 'other',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('صفحة المصاريف الأخرى قيد التطوير'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            if (_hasPermission('expenses_reports_view'))
              _buildDrawerSection(
                context,
                title: 'التقارير والتحليل',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'التقارير',
                    isSelected: widget.currentRoute == '/expenses/reports',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(AppRoutes.expensesReports);
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.history_outlined,
                    title: 'سجل المصاريف',
                    isSelected: widget.currentRoute == '/expenses/log',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, '/expenses/log');
                    },
                  ),
                  if (_hasPermission('expenses_analysis_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.pie_chart_outline,
                      title: 'تحليل المصاريف',
                      isSelected: widget.currentRoute == 'analysis',
                      onTap: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('صفحة تحليل المصاريف قيد التطوير'),
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (_hasPermission('expenses_settings_view'))
              _buildDrawerSection(
                context,
                title: 'الإعدادات',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.category_outlined,
                    title: 'فئات المصاريف',
                    isSelected: widget.currentRoute == 'categories',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('صفحة فئات المصاريف قيد التطوير'),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'إعدادات المصاريف',
                    isSelected: widget.currentRoute == 'settings',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onSettings != null) {
                        widget.onSettings!();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('صفحة الإعدادات قيد التطوير'),
                          ),
                        );
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
                  'إدارة المصاريف',
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



