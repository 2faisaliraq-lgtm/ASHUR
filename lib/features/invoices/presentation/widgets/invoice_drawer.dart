import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../injection_container.dart';
import '../bloc/invoice_bloc.dart';
import '../pages/invoices_log_page.dart';

/// الشريط الجانبي الموحد لقسم الفواتير
class InvoiceDrawer extends StatefulWidget {
  const InvoiceDrawer({
    super.key,
    this.currentRoute,
    this.onAddInvoice,
    this.onViewInvoices,
    this.onViewReports,
    this.onViewPayments,
    this.onSettings,
  });
  final String? currentRoute;
  final VoidCallback? onAddInvoice;
  final VoidCallback? onViewInvoices;
  final VoidCallback? onViewReports;
  final VoidCallback? onViewPayments;
  final VoidCallback? onSettings;

  @override
  State<InvoiceDrawer> createState() => _InvoiceDrawerState();
}

class _InvoiceDrawerState extends State<InvoiceDrawer> {
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

  /// التحقق من وجود أي صلاحية لإنشاء الفواتير
  bool _hasAnyCreatePermission() {
    return _hasPermission('invoices_sales_manage') ||
        _hasPermission('invoices_purchase_manage') ||
        _hasPermission('invoices_cash_manage') ||
        _hasPermission('invoices_subscription_manage') ||
        _hasPermission('invoices_sales_return_manage');
  }

  /// التحقق من وجود أي صلاحية لعرض الفواتير (قائمة أو أرشيف)
  bool _hasAnyViewPermission() {
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
            _buildDrawerHeader(context),
            _buildDrawerSection(
              context,
              title: 'الفواتير الرئيسية',
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
                if (_hasAnyViewPermission())
                  _buildDrawerItem(
                    context,
                    icon: Icons.list_alt_outlined,
                    title: 'قائمة الفواتير',
                    isSelected: widget.currentRoute == 'invoices',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, '/invoices/list');
                    },
                  ),
                if (_hasAnyViewPermission())
                  _buildDrawerItem(
                    context,
                    icon: Icons.archive_outlined,
                    title: 'الفواتير المؤرشفة',
                    isSelected: widget.currentRoute == 'archived_invoices',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, AppRoutes.archivedInvoices);
                    },
                  ),
                if (_hasAnyCreatePermission())
                  _buildDrawerItem(
                    context,
                    icon: Icons.add_box_outlined,
                    title: 'إضافة فاتورة',
                    isSelected: widget.currentRoute == 'add_invoice',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onAddInvoice != null) {
                        widget.onAddInvoice!();
                      } else {
                        Navigator.pushNamed(context, AppRoutes.createInvoice);
                      }
                    },
                  ),
              ],
            ),
            if (_hasPermission('invoices_types_view'))
              _buildDrawerSection(
                context,
                title: 'أنواع الفواتير',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.shopping_cart_outlined,
                    title: 'فواتير المبيعات',
                    isSelected: widget.currentRoute == 'sales',
                    onTap: () {
                      Navigator.of(context).pop();
                      // Sales invoices functionality placeholder
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    title: 'فواتير المشتريات',
                    isSelected: widget.currentRoute == 'purchases',
                    onTap: () {
                      Navigator.of(context).pop();
                      // Purchase invoices functionality placeholder
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.assignment_return_outlined,
                    title: 'فواتير المرتجعات',
                    isSelected: widget.currentRoute == 'returns',
                    onTap: () {
                      Navigator.of(context).pop();
                      // Return invoices functionality placeholder
                    },
                  ),
                ],
              ),
            if (_hasPermission('invoices_reports_view'))
              _buildDrawerSection(
                context,
                title: 'التقارير والتحليل',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'التقارير',
                    isSelected: widget.currentRoute == '/invoices/reports',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onViewReports != null) {
                        widget.onViewReports!();
                      } else {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.invoicesReports);
                      }
                    },
                  ),
                  if (_hasPermission('invoices_payments_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.payment_outlined,
                      title: 'سجل المدفوعات',
                      isSelected: widget.currentRoute == 'payments',
                      onTap: () {
                        Navigator.of(context).pop();
                        if (widget.onViewPayments != null) {
                          widget.onViewPayments!();
                        } else {
                          // Payment history functionality placeholder
                        }
                      },
                    ),
                  if (_hasPermission('invoices_logs_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_outlined,
                      title: 'سجل الفواتير',
                      isSelected: widget.currentRoute == 'history',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (_) => getIt<InvoiceBloc>(),
                              child: const InvoicesLogPage(),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (_hasPermission('invoices_settings_view'))
              _buildDrawerSection(
                context,
                title: 'الإعدادات',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'إعدادات الفواتير',
                    isSelected: widget.currentRoute == 'settings',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onSettings != null) {
                        widget.onSettings!();
                      } else {
                        // Settings functionality placeholder
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
                  'إدارة الفواتير',
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



