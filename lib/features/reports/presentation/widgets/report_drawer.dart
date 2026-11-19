import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/assyrian_theme.dart';

/// الشريط الجانبي الموحد لقسم التقارير
class ReportDrawer extends StatelessWidget {
  const ReportDrawer({
    super.key,
    this.currentRoute,
    this.onAddReport,
    this.onViewReports,
    this.onViewFinancialReports,
    this.onViewInventoryReports,
    this.onViewSalesReports,
    this.onViewExpenseReports,
    this.onSettings,
  });
  final String? currentRoute;
  final VoidCallback? onAddReport;
  final VoidCallback? onViewReports;
  final VoidCallback? onViewFinancialReports;
  final VoidCallback? onViewInventoryReports;
  final VoidCallback? onViewSalesReports;
  final VoidCallback? onViewExpenseReports;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
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
              title: 'التقارير الرئيسية',
              items: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'لوحة التحكم',
                  isSelected: currentRoute == 'dashboard',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.assessment_outlined,
                  title: 'جميع التقارير',
                  isSelected: currentRoute == 'reports',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.pushNamed(context, '/reports/list');
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.add_box_outlined,
                  title: 'إنشاء تقرير',
                  isSelected: currentRoute == 'add_report',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (onAddReport != null) {
                      onAddReport!();
                    }
                  },
                ),
              ],
            ),
            _buildDrawerSection(
              context,
              title: 'أنواع التقارير',
              items: [
                _buildDrawerItem(
                  context,
                  icon: Icons.attach_money_outlined,
                  title: 'التقارير المالية',
                  isSelected: currentRoute == 'financial',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (onViewFinancialReports != null) {
                      onViewFinancialReports!();
                    } else {
                      // ⚠️ وظيفة تقارير المالية غير منفذة بعد — يحتاج إضافة مسار وصفحة
                    }
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.inventory_outlined,
                  title: 'تقارير المخزون',
                  isSelected: currentRoute == 'inventory',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (onViewInventoryReports != null) {
                      onViewInventoryReports!();
                    } else {
                      // ⚠️ وظيفة تقارير المخزون غير منفذة بعد — يحتاج إضافة مسار وصفحة
                    }
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.shopping_cart_outlined,
                  title: 'تقارير المبيعات',
                  isSelected: currentRoute == 'sales',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (onViewSalesReports != null) {
                      onViewSalesReports!();
                    } else {
                      // ⚠️ وظيفة تقارير المبيعات غير منفذة بعد — يحتاج إضافة مسار وصفحة
                    }
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'تقارير المصاريف',
                  isSelected: currentRoute == 'expenses',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (onViewExpenseReports != null) {
                      onViewExpenseReports!();
                    } else {
                      // ⚠️ وظيفة تقارير المصاريف غير منفذة بعد — يحتاج إضافة مسار وصفحة
                    }
                  },
                ),
              ],
            ),
            _buildDrawerSection(
              context,
              title: 'الإعدادات',
              items: [
                _buildDrawerItem(
                  context,
                  icon: Icons.payments_outlined,
                  title: 'الصندوق',
                  isSelected: currentRoute == '/reports/cashbox',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.pushNamed(context, '/reports/cashbox');
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.history_outlined,
                  title: 'سجل التقارير',
                  isSelected: currentRoute == '/reports/log',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.pushNamed(context, '/reports/log');
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'إعدادات التقارير',
                  isSelected: currentRoute == 'settings',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (onSettings != null) {
                      onSettings!();
                    } else {
                      // ⚠️ وظيفة الإعدادات غير منفذة بعد — يحتاج إضافة مسار وصفحة
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
                  'إدارة التقارير',
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
