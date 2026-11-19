import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/enabled_modules_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../widgets/settings_drawer.dart';

/// صفحة إعدادات الأقسام (تمكين/إيقاف)
class ModulesSettingsPage extends StatefulWidget {
  const ModulesSettingsPage({super.key});

  @override
  State<ModulesSettingsPage> createState() => _ModulesSettingsPageState();
}

class _ModulesSettingsPageState extends State<ModulesSettingsPage> {
  final _service = EnabledModulesService();
  final PermissionChecker _permissionChecker = PermissionChecker();
  final ScrollController _scrollController = ScrollController();
  bool _canManageSettings = false;
  Map<String, bool> _modules = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadModules();
  }

  /// إعادة تعيين الإعدادات إلى الافتراضية
  void _resetToDefaults() {
    setState(() {
      _modules = {
        'invoices_sales_manage': true,
        'invoices_purchase_manage': true,
        'invoices_cash_manage': true,
        'invoices_subscription_manage': true,
        'invoices_sales_return_manage': true,
        'customers_view': true,
        'inventory_view': true,
        'subscriptions_view': true,
        'expenses_view': true,
        'rentals_view': true,
        'maintenance_view': true,
        'reports_view': true,
        'users_view': true,
      };
    });
  }

  Future<void> _loadPermissions() async {
    final canManageSettings = await _permissionChecker.hasPermission(
      'settings_manage',
    );

    if (mounted) {
      setState(() {
        _canManageSettings = canManageSettings;
      });
    }
  }

  Future<void> _loadModules() async {
    setState(() => _isLoading = true);
    final modules = await _service.getEnabledModules();
    setState(() {
      _modules = modules;
      _isLoading = false;
    });
  }

  Future<void> _saveModules() async {
    setState(() => _isSaving = true);

    final success = await _service.saveEnabledModules(_modules);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'تم حفظ الإعدادات بنجاح' : 'فشل حفظ الإعدادات',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        // إعادة تحميل التطبيق لتطبيق التغييرات
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: const SettingsDrawer(currentRoute: '/settings/modules'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: _isLoading
          ? LoadingWidget(message: 'جاري التحميل...')
          : _buildSettingsContent(context),
      floatingActionButton: _canManageSettings
          ? FloatingActionButton(
              heroTag: 'settings_modules_save_fab',
              onPressed: _isSaving ? null : _saveModules,
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: _isSaving
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: LoadingWidget(),
                    )
                  : Icon(Icons.save, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
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
      ),
      title: Row(
        children: [
          AssyrianTheme.getLamassuForBackground(
            isDarkBackground: true,
            hasCircularBackground: false,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة الأقسام',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                    ),
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'نظام إدارة المتاجر الآشوري',
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 10,
                    ),
                    color: AssyrianTheme.ivoryWhite,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _isSaving ? null : _saveModules,
          icon: Icon(Icons.save, color: AssyrianTheme.primaryGold, size: 24.sp),
          tooltip: 'حفظ الإعدادات',
        ),
        IconButton(
          onPressed: _loadModules,
          icon: Icon(
            Icons.refresh,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _loadModules(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // أزرار الإجراءات السريعة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: _buildQuickActions(),
            ),
          ),

          // عنوان الصفحة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Text(
                'إدارة الأقسام',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ),
          ),

          // رسالة توضيحية
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 24.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'يمكنك تمكين أو إيقاف الأقسام حسب احتياجك. الأقسام المعطلة لن تظهر في التطبيق.',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // قائمة الأقسام
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  SizedBox(height: 16.h),
                  ...EnabledModulesService.availableModules.entries.map((
                    entry,
                  ) {
                    final moduleId = entry.key;
                    final moduleName = entry.value;
                    final isCore = EnabledModulesService.coreModules.contains(
                      moduleId,
                    );
                    final isEnabled = _modules[moduleId] ?? true;

                    return Card(
                      margin: EdgeInsets.only(bottom: 12.h),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: SwitchListTile(
                        value: isEnabled,
                        onChanged: isCore
                            ? null
                            : (value) {
                                setState(() {
                                  _modules[moduleId] = value;
                                });
                              },
                        title: Text(
                          moduleName,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          isCore
                              ? 'قسم أساسي - لا يمكن إيقافه'
                              : 'يمكن تمكين أو إيقاف هذا القسم',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        secondary: Icon(
                          _getModuleIcon(moduleId),
                          color: isEnabled
                              ? AssyrianTheme.primaryGold
                              : Colors.grey,
                          size: 24.sp,
                        ),
                        activeTrackColor: AssyrianTheme.primaryGold.withValues(
                          alpha: 0.5,
                        ),
                        activeThumbColor: AssyrianTheme.primaryGold,
                      ),
                    );
                  }),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AssyrianTheme.ivoryWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(
            icon: Icons.save,
            label: 'حفظ الإعدادات',
            onTap: _saveModules,
            color: AssyrianTheme.primaryGold,
          ),
          _buildQuickActionButton(
            icon: Icons.refresh,
            label: 'إعادة تحميل',
            onTap: _loadModules,
            color: AssyrianTheme.deepBlue,
          ),
          _buildQuickActionButton(
            icon: Icons.restore,
            label: 'الإعدادات الافتراضية',
            onTap: _resetToDefaults,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22.sp),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.sp,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModuleIcon(String moduleId) {
    switch (moduleId) {
      case 'dashboard_view':
        return Icons.dashboard;
      case 'users_view':
        return Icons.people;
      case 'customers_view':
        return Icons.person;
      case 'inventory_view':
        return Icons.inventory_2;
      case 'subscriptions_view':
        return Icons.subscriptions;
      case 'maintenance_view':
        return Icons.build;
      case 'rentals_view':
        return Icons.home_work;
      case 'invoices_sales_manage':
      case 'invoices_purchase_manage':
      case 'invoices_cash_manage':
      case 'invoices_subscription_manage':
      case 'invoices_sales_return_manage':
        return Icons.receipt_long;
      case 'expenses_view':
        return Icons.money_off;
      case 'reports_view':
        return Icons.analytics;
      case 'settings_view':
        return Icons.settings;
      default:
        return Icons.extension;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}




