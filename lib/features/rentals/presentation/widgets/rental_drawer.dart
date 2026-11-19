import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../bloc/rental_bloc.dart';
import '../pages/rentals_log_page.dart';

/// الشريط الجانبي الموحد لقسم الإيجارات
class RentalDrawer extends StatefulWidget {
  const RentalDrawer({
    super.key,
    this.currentRoute,
    this.onAddRental,
    this.onViewContracts,
    this.onViewReports,
    this.onViewPayments,
    this.onSettings,
  });
  final String? currentRoute;
  final VoidCallback? onAddRental;
  final VoidCallback? onViewContracts;
  final VoidCallback? onViewReports;
  final VoidCallback? onViewPayments;
  final VoidCallback? onSettings;

  @override
  State<RentalDrawer> createState() => _RentalDrawerState();
}

class _RentalDrawerState extends State<RentalDrawer> {
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
              title: 'الإيجارات الرئيسية',
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
                if (_hasPermission('rentals_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.description_outlined,
                    title: 'جميع العقود',
                    isSelected: widget.currentRoute == 'contracts',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, AppRoutes.rentalsList);
                    },
                  ),
                if (_hasPermission('rentals_create'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.add_box_outlined,
                    title: 'عقد جديد',
                    isSelected: widget.currentRoute == 'add_rental',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onAddRental != null) {
                        widget.onAddRental!();
                      } else {
                        Navigator.pushNamed(context, AppRoutes.createRental);
                      }
                    },
                  ),
              ],
            ),
            if (_hasPermission('rentals_units_view'))
              _buildDrawerSection(
                context,
                title: 'الوحدات المؤجرة',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.category,
                    title: 'الأشياء القابلة للإيجار',
                    isSelected: widget.currentRoute == 'rental_units',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, AppRoutes.rentalUnits);
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people_outline,
                    title: 'المستأجرين',
                    isSelected: widget.currentRoute == 'tenants',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('صفحة المستأجرين قيد التطوير'),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.apartment_outlined,
                    title: 'الوحدات المؤجرة',
                    isSelected: widget.currentRoute == 'units',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('صفحة الوحدات المؤجرة قيد التطوير'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            if (_hasPermission('rentals_reports_view'))
              _buildDrawerSection(
                context,
                title: 'التقارير والتحليل',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'التقارير',
                    isSelected: widget.currentRoute == '/rentals/reports',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(AppRoutes.rentalsReports);
                    },
                  ),
                  if (_hasPermission('rentals_payments_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.payment_outlined,
                      title: 'سجل الدفعات',
                      isSelected: widget.currentRoute == 'payments',
                      onTap: () {
                        Navigator.of(context).pop();
                        if (widget.onViewPayments != null) {
                          widget.onViewPayments!();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('صفحة سجل الدفعات قيد التطوير'),
                            ),
                          );
                        }
                      },
                    ),
                  if (_hasPermission('rentals_logs_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_outlined,
                      title: 'سجل الإيجارات',
                      isSelected: widget.currentRoute == 'rentals_log',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (context) => GetIt.instance<RentalBloc>(),
                              child: const RentalsLogPage(),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (_hasPermission('rentals_settings_view'))
              _buildDrawerSection(
                context,
                title: 'الإعدادات',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'إعدادات الإيجارات',
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
                  'إدارة الإيجارات',
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



