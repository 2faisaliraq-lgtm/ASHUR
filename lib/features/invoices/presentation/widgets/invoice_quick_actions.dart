import 'dart:convert';

import '../../../../core/widgets/loading_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/navigation/navigation_service.dart';
import '../pages/invoice_quick_actions_settings_page.dart';

class InvoiceQuickActions extends StatefulWidget {
  const InvoiceQuickActions({
    super.key,
    this.onAddInvoice,
    this.onRefresh,
    this.onSettings,
  });

  final VoidCallback? onAddInvoice;
  final VoidCallback? onRefresh;
  final VoidCallback? onSettings;

  @override
  State<InvoiceQuickActions> createState() => _InvoiceQuickActionsState();
}

class _InvoiceQuickActionsState extends State<InvoiceQuickActions> {
  late Future<Map<String, dynamic>> _dataFuture;
  int _rebuildKey = 0;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAllData();
    NavigationService().quickActionsSettingsNotifier.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        _rebuildKey++;
        _dataFuture = _loadAllData();
      });
    }
  }

  @override
  void dispose() {
    NavigationService().quickActionsSettingsNotifier.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// تحميل الإعدادات والصلاحيات مرة واحدة فقط في Future
  /// لتجنب عدة setState وإعادة بناء متعددة للواجهة
  Future<Map<String, dynamic>> _loadAllData() async {
    final result = <String, dynamic>{};

    // 1. تحميل الإعدادات (أسرع)
    final prefs = await SharedPreferences.getInstance();
    final savedActions = prefs.getString('invoice_quick_actions');
    final Map<String, bool> settings = <String, bool>{
      'add_invoice': false,
      'invoices_list': false,
      'archived_invoices': false,
      'templates': false,
      'settings': false,
      'reports': false,
      'refresh': false,
    };
    if (savedActions != null) {
      final decoded = await Future.value(jsonDecode(savedActions))
          .catchError((_) => <dynamic>[]) as List<dynamic>;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as String?;
          final enabled = item['enabled'] as bool?;
          if (id != null && enabled != null) {
            settings[id] = enabled;
          }
        }
      }
    }
    result['settings'] = settings;

    // 2. تحميل الصلاحيات (أبطأ)
    List<String> permissions = await PermissionChecker()
        .getUserPermissions()
        .timeout(const Duration(seconds: 2), onTimeout: () => <String>[])
        .catchError((_) => <String>[]);
    result['permissions'] = permissions;

    return result;
  }

  bool _hasPermission(Map<String, dynamic> data, String permission) {
    final permissions = data['permissions'] as List<dynamic>? ?? <dynamic>[];
    return permissions.contains(permission);
  }

  bool _hasAnyCreatePermission(Map<String, dynamic> data) {
    return _hasPermission(data, 'invoices_sales_manage') ||
        _hasPermission(data, 'invoices_purchase_manage') ||
        _hasPermission(data, 'invoices_cash_manage') ||
        _hasPermission(data, 'invoices_subscription_manage') ||
        _hasPermission(data, 'invoices_sales_return_manage');
  }

  bool _hasAnyViewPermission(Map<String, dynamic> data) {
    return _hasPermission(data, 'invoices_sales_manage') ||
        _hasPermission(data, 'invoices_purchase_manage') ||
        _hasPermission(data, 'invoices_cash_manage') ||
        _hasPermission(data, 'invoices_subscription_manage') ||
        _hasPermission(data, 'invoices_sales_return_manage');
  }

  int _countAvailableActions(Map<String, dynamic> data) {
    int count = 0;

    if (_hasAnyCreatePermission(data)) {
      count++;
    }
    if (_hasAnyViewPermission(data)) {
      count += 2; // قائمة الفواتير + الأرشيف
    }
    if (_hasPermission(data, 'invoices_settings_manage')) count += 2;
    if (_hasPermission(data, 'reports_view')) count++;
    // Refresh button - always available
    count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('invoice_quick_actions_$_rebuildKey'),
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
            child: const SizedBox(
              height: 60,
              child: Center(child: LoadingWidget(message: 'جاري التحميل...')),
            ),
          );
        }

        final data = snapshot.data ?? <String, dynamic>{};
        final settings = (data['settings'] as Map<String, bool>?) ?? <String, bool>{
          'add_invoice': false,
          'invoices_list': false,
          'archived_invoices': false,
          'templates': false,
          'settings': false,
          'reports': false,
          'refresh': false,
        };
        final availableActionsCount = _countAvailableActions(data);

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
                      Icon(
                        Icons.flash_on_outlined,
                        color: AssyrianTheme.primaryGold,
                        size: 20.sp,
                      ),
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
                            builder: (context) =>
                                const InvoiceQuickActionsSettingsPage(),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6.h),
              _buildActionsGrid(context, data, settings),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionsGrid(
      BuildContext context, Map<String, dynamic> data, Map<String, bool> settings) {
    final isMobile = ResponsiveHelper.isMobile(context);

    // بناء قائمة الإجراءات بناءً على الصلاحيات والإعدادات المحفوظة
    final allActions = <Widget>[];

    // إضافة الإجراءات حسب الترتيب والإعدادات المحفوظة
    if (_hasAnyCreatePermission(data) &&
        (settings['add_invoice'] ?? true)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.receipt_long_outlined,
          title: 'إضافة فاتورة',
          subtitle: 'فاتورة جديدة',
          color: AssyrianTheme.primaryGold,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.createInvoice),
        ),
      );
    }

    if (_hasAnyViewPermission(data) &&
        (settings['invoices_list'] ?? true)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.list_alt_outlined,
          title: 'قائمة الفواتير',
          subtitle: 'عرض جميع الفواتير',
          color: Colors.teal,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.invoicesList),
        ),
      );
    }

    if (_hasAnyViewPermission(data) &&
        (settings['archived_invoices'] ?? true)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.archive_outlined,
          title: 'الفواتير المؤرشفة',
          subtitle: 'الفواتير القديمة',
          color: Colors.brown,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.archivedInvoices),
        ),
      );
    }

    if (_hasPermission(data, 'invoices_settings_manage') &&
        (settings['templates'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.description_outlined,
          title: 'قوالب الفواتير',
          subtitle: 'تخصيص القوالب',
          color: Colors.purple,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.invoiceTemplates),
        ),
      );
    }

    if (_hasPermission(data, 'invoices_settings_manage') &&
        (settings['settings'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.settings_outlined,
          title: 'الإعدادات',
          subtitle: 'إعدادات الفواتير',
          color: Colors.orange,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.invoicesSettings),
        ),
      );
    }

    if (_hasPermission(data, 'reports_view') &&
        (settings['reports'] ?? false)) {
      allActions.add(
        _buildActionCard(
          context,
          icon: Icons.analytics_outlined,
          title: 'التقارير',
          subtitle: 'إحصائيات مفصلة',
          color: Colors.blue,
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.invoicesReports),
        ),
      );
    }

    // Refresh button - available but not forced
    if (settings['refresh'] ?? true) {
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

        // عرض جميع الإجراءات المتاحة (كل صف زرين)
        if (allActions.isEmpty) {
          return const SizedBox.shrink();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 4.w,
            mainAxisSpacing: 4.h,
            childAspectRatio: 3.5,
          ),
          itemCount: allActions.length,
          itemBuilder: (context, index) => allActions[index],
        );
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
                  SizedBox(height: 2.h),
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
