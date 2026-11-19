import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/module_enable_toggle.dart';

/// صفحة إعدادات قسم التقارير
class ReportsSettingsPage extends StatefulWidget {
  const ReportsSettingsPage({super.key});

  @override
  State<ReportsSettingsPage> createState() => _ReportsSettingsPageState();
}

class _ReportsSettingsPageState extends State<ReportsSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // ⚠️ ملاحظة للمبرمجين المستقبليين: الإعدادات تُخزَّن وتُحمل عبر SettingsService.
  // بعض الإعدادات تُطبَّق الآن في منطق العمل:
  // - _reportRetentionDays يُستخدم في clearReportLogs للمستودع
  // - _enableAutoGeneration يمكن استخدامه عند تنفيذ التوليد التلقائي
   // - باقي الإعدادات تُحفظ للاستخدام المستقبلي عند تنفيذ ميزات التلقائية.
  bool _enableAutoGeneration = true;
  String _defaultReportFormat = 'PDF';
  bool _includeCompanyLogo = true;
  bool _showReportTimestamp = true;
  bool _enableReportScheduling = true;
  int _reportRetentionDays = 365;

  // إعدادات تقارير المبيعات
  bool _enableSalesReports = true;
  bool _includeTaxInSalesReports = true;
  bool _showCustomerDetails = true;
  bool _showProductDetails = true;
  String _salesReportPeriod = 'شهري';
  bool _enableSalesComparison = true;

  // إعدادات تقارير المخزون
  bool _enableInventoryReports = true;
  bool _showStockLevels = true;
  bool _showValuation = true;
  bool _includeExpiredItems = true;
  bool _showLocationBreakdown = true;
  int _lowStockThreshold = 10;

  // إعدادات تقارير العملاء
  bool _enableCustomerReports = true;
  bool _showCustomerBalance = true;
  bool _includePaymentHistory = true;
  bool _showLoyaltyPoints = true;
  bool _enableCustomerSegmentation = true;
  String _customerReportGrouping = 'المجموعة';

  // إعدادات تقارير المالية
  bool _enableFinancialReports = true;
  bool _showProfitLoss = true;
  bool _includeCashFlow = true;
  bool _showExpenseBreakdown = true;
  String _financialReportCurrency = 'IQD';
  bool _enableBudgetComparison = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canManageSettings = await _permissionChecker.hasPermission(
      'reports_settings_manage',
    );

    if (mounted) {
      setState(() {
        _canManageSettings = canManageSettings;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getReportsSettings();
      setState(() {
        _enableAutoGeneration = settings['enableAutoGeneration'] ?? true;
        _defaultReportFormat = settings['defaultReportFormat'] ?? 'PDF';
        _includeCompanyLogo = settings['includeCompanyLogo'] ?? true;
        _showReportTimestamp = settings['showReportTimestamp'] ?? true;
        _enableReportScheduling = settings['enableReportScheduling'] ?? true;
        _reportRetentionDays = settings['reportRetentionDays'] ?? 365;
        _enableSalesReports = settings['enableSalesReports'] ?? true;
        _includeTaxInSalesReports =
            settings['includeTaxInSalesReports'] ?? true;
        _showCustomerDetails = settings['showCustomerDetails'] ?? true;
        _showProductDetails = settings['showProductDetails'] ?? true;
        _salesReportPeriod = settings['salesReportPeriod'] ?? 'شهري';
        _enableSalesComparison = settings['enableSalesComparison'] ?? true;
        _enableInventoryReports = settings['enableInventoryReports'] ?? true;
        _showStockLevels = settings['showStockLevels'] ?? true;
        _showValuation = settings['showValuation'] ?? true;
        _includeExpiredItems = settings['includeExpiredItems'] ?? true;
        _showLocationBreakdown = settings['showLocationBreakdown'] ?? true;
        _lowStockThreshold = settings['lowStockThreshold'] ?? 10;
        _enableCustomerReports = settings['enableCustomerReports'] ?? true;
        _showCustomerBalance = settings['showCustomerBalance'] ?? true;
        _includePaymentHistory = settings['includePaymentHistory'] ?? true;
        _showLoyaltyPoints = settings['showLoyaltyPoints'] ?? true;
        _enableCustomerSegmentation =
            settings['enableCustomerSegmentation'] ?? true;
        _customerReportGrouping = settings['customerReportGrouping'] ?? 'المجموعة';
        _enableFinancialReports = settings['enableFinancialReports'] ?? true;
        _showProfitLoss = settings['showProfitLoss'] ?? true;
        _includeCashFlow = settings['includeCashFlow'] ?? true;
        _showExpenseBreakdown = settings['showExpenseBreakdown'] ?? true;
        _financialReportCurrency = settings['financialReportCurrency'] ?? 'IQD';
        _enableBudgetComparison = settings['enableBudgetComparison'] ?? false;
      });
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الإعدادات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    // عرض نافذة التحميل فوراً
    if (mounted) {
      LoadingWidget.showLoadingDialog(
        context,
        message: 'جاري حفظ الإعدادات...',
        subtitle: 'الرجاء الانتظار...',
        icon: Icons.save,
      );
    }

    try {
      final settings = {
        'enableAutoGeneration': _enableAutoGeneration,
        'defaultReportFormat': _defaultReportFormat,
        'includeCompanyLogo': _includeCompanyLogo,
        'showReportTimestamp': _showReportTimestamp,
        'enableReportScheduling': _enableReportScheduling,
        'reportRetentionDays': _reportRetentionDays,
        'enableSalesReports': _enableSalesReports,
        'includeTaxInSalesReports': _includeTaxInSalesReports,
        'showCustomerDetails': _showCustomerDetails,
        'showProductDetails': _showProductDetails,
        'salesReportPeriod': _salesReportPeriod,
        'enableSalesComparison': _enableSalesComparison,
        'enableInventoryReports': _enableInventoryReports,
        'showStockLevels': _showStockLevels,
        'showValuation': _showValuation,
        'includeExpiredItems': _includeExpiredItems,
        'showLocationBreakdown': _showLocationBreakdown,
        'lowStockThreshold': _lowStockThreshold,
        'enableCustomerReports': _enableCustomerReports,
        'showCustomerBalance': _showCustomerBalance,
        'includePaymentHistory': _includePaymentHistory,
        'showLoyaltyPoints': _showLoyaltyPoints,
        'enableCustomerSegmentation': _enableCustomerSegmentation,
        'customerReportGrouping': _customerReportGrouping,
        'enableFinancialReports': _enableFinancialReports,
        'showProfitLoss': _showProfitLoss,
        'includeCashFlow': _includeCashFlow,
        'showExpenseBreakdown': _showExpenseBreakdown,
        'financialReportCurrency': _financialReportCurrency,
        'enableBudgetComparison': _enableBudgetComparison,
      };

      await SettingsService.saveReportsSettings(settings);

      if (mounted) {
        // إغلاق نافذة التحميل
        try {
          Navigator.of(context).pop();
        } on Exception {
          // تجاهل الأخطاء
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        // إغلاق نافذة التحميل
        try {
          Navigator.of(context).pop();
        } on Exception {
          // تجاهل الأخطاء
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الإعدادات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: AssyrianTheme.backgroundGradient,
              ),
              child: Text(
                'إعدادات التقارير',
                style: TextStyle(
                  color: AssyrianTheme.primaryGold,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('الإعدادات العامة'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: _buildSettingsContent(context),
      floatingActionButton: _canManageSettings
          ? FloatingActionButton(
              heroTag: 'reports_settings_save_fab',
              onPressed: _saveSettings,
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.save, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _loadSettings(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // زر تمكين/إيقاف القسم
          const SliverToBoxAdapter(
            child: ModuleEnableToggle(
              moduleId: 'reports_view',
              moduleName: 'قسم التقارير',
              moduleIcon: Icons.analytics,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: _buildQuickActions(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Text(
                'إعدادات التقارير',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('الإعدادات العامة للتقارير'),
                  _buildGeneralSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('تقارير المبيعات'),
                  _buildSalesReportsSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('تقارير المخزون'),
                  _buildInventoryReportsSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('تقارير العملاء'),
                  _buildCustomerReportsSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('التقارير المالية'),
                  _buildFinancialReportsSettings(),
                  const SizedBox(height: 20),
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
            onTap: _saveSettings,
            color: AssyrianTheme.primaryGold,
          ),
          _buildQuickActionButton(
            icon: Icons.refresh,
            label: 'إعادة تحميل',
            onTap: _loadSettings,
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

  void _resetToDefaults() {
    setState(() {
      _enableAutoGeneration = true;
      _defaultReportFormat = 'PDF';
      _includeCompanyLogo = true;
      _showReportTimestamp = true;
      _enableReportScheduling = true;
      _reportRetentionDays = 365;
      _enableSalesReports = true;
      _includeTaxInSalesReports = true;
      _showCustomerDetails = true;
      _showProductDetails = true;
      _salesReportPeriod = 'شهري';
      _enableSalesComparison = true;
      _enableInventoryReports = true;
      _showStockLevels = true;
      _showValuation = true;
      _includeExpiredItems = true;
      _showLocationBreakdown = true;
      _lowStockThreshold = 10;
      _enableCustomerReports = true;
      _showCustomerBalance = true;
      _includePaymentHistory = true;
      _showLoyaltyPoints = true;
      _enableCustomerSegmentation = true;
      _customerReportGrouping = 'المجموعة';
      _enableFinancialReports = true;
      _showProfitLoss = true;
      _includeCashFlow = true;
      _showExpenseBreakdown = true;
      _financialReportCurrency = 'IQD';
      _enableBudgetComparison = false;
    });
    // ⚠️ الحفظ يتم عبر _saveSettings مباشرة. نافذة التحميل تظهر وتختفي بسرعة،
    // يُنصح بفصل منطق الحفظ عن عرض نافذة التحميل في إصدار قادم.
    _saveSettings();
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AssyrianTheme.backgroundGradient,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        title,
        style: AssyrianTheme.titleStyle.copyWith(
          fontSize: 16.sp,
          color: AssyrianTheme.primaryGold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildSwitchTile(
                'إنشاء التقارير تلقائياً',
                'إنشاء التقارير الدورية تلقائياً',
                _enableAutoGeneration,
                (value) => setState(() => _enableAutoGeneration = value),
                Icons.auto_awesome,
              ),
              _buildDropdownTile(
                'تنسيق التقرير الافتراضي',
                'التنسيق المستخدم لحفظ التقارير',
                _defaultReportFormat,
                ['PDF', 'Excel', 'Word', 'CSV'],
                ['ملف PDF', 'جدول بيانات', 'مستند نصي', 'ملف بيانات مفصول بفواصل'],
                (value) => setState(() => _defaultReportFormat = value!),
                Icons.description,
              ),
              _buildSwitchTile(
                'تضمين شعار الشركة',
                'إظهار شعار الشركة في التقارير',
                _includeCompanyLogo,
                (value) => setState(() => _includeCompanyLogo = value),
                Icons.business,
              ),
              _buildSwitchTile(
                'إظهار وقت إنشاء التقرير',
                'عرض تاريخ ووقت إنشاء التقرير',
                _showReportTimestamp,
                (value) => setState(() => _showReportTimestamp = value),
                Icons.access_time,
              ),
              _buildSwitchTile(
                'تفعيل جدولة التقارير',
                'إمكانية جدولة التقارير لإنشائها تلقائياً',
                _enableReportScheduling,
                (value) => setState(() => _enableReportScheduling = value),
                Icons.schedule,
              ),
              _buildSliderTile(
                'مدة الاحتفاظ بالتقارير (أيام)',
                'عدد الأيام للاحتفاظ بالتقارير المحفوظة',
                _reportRetentionDays.toDouble(),
                30,
                1095,
                (value) => setState(() => _reportRetentionDays = value.round()),
                Icons.storage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesReportsSettings() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildSwitchTile(
                'تفعيل تقارير المبيعات',
                'إنشاء تقارير مفصلة عن المبيعات',
                _enableSalesReports,
                (value) => setState(() => _enableSalesReports = value),
                Icons.trending_up,
              ),
              _buildSwitchTile(
                'تضمين الضرائب في تقارير المبيعات',
                'إظهار الضرائب في تفاصيل المبيعات',
                _includeTaxInSalesReports,
                (value) => setState(() => _includeTaxInSalesReports = value),
                Icons.calculate,
              ),
              _buildSwitchTile(
                'إظهار تفاصيل العملاء',
                'عرض معلومات مفصلة عن العملاء',
                _showCustomerDetails,
                (value) => setState(() => _showCustomerDetails = value),
                Icons.person,
              ),
              _buildSwitchTile(
                'إظهار تفاصيل المنتجات',
                'عرض معلومات مفصلة عن المنتجات المباعة',
                _showProductDetails,
                (value) => setState(() => _showProductDetails = value),
                Icons.inventory,
              ),
              _buildDropdownTile(
                'فترة تقرير المبيعات',
                'الفترة الزمنية الافتراضية للتقرير',
                _salesReportPeriod,
                ['يومي', 'أسبوعي', 'شهري', 'ربع سنوي', 'سنوي'],
                ['يومي', 'أسبوعي', 'شهري', 'ربع سنوي', 'سنوي'],
                (value) => setState(() => _salesReportPeriod = value!),
                Icons.date_range,
              ),
              _buildSwitchTile(
                'تفعيل مقارنة المبيعات',
                'مقارنة المبيعات مع الفترات السابقة',
                _enableSalesComparison,
                (value) => setState(() => _enableSalesComparison = value),
                Icons.compare_arrows,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryReportsSettings() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildSwitchTile(
                'تفعيل تقارير المخزون',
                'إنشاء تقارير مفصلة عن المخزون',
                _enableInventoryReports,
                (value) => setState(() => _enableInventoryReports = value),
                Icons.warehouse,
              ),
              _buildSwitchTile(
                'إظهار مستويات المخزون',
                'عرض الكميات المتوفرة لكل منتج',
                _showStockLevels,
                (value) => setState(() => _showStockLevels = value),
                Icons.inventory_2,
              ),
              _buildSwitchTile(
                'إظهار تقييم المخزون',
                'عرض القيمة المالية للمخزون',
                _showValuation,
                (value) => setState(() => _showValuation = value),
                Icons.monetization_on,
              ),
              _buildSwitchTile(
                'تضمين المنتجات منتهية الصلاحية',
                'إظهار المنتجات المنتهية الصلاحية في التقارير',
                _includeExpiredItems,
                (value) => setState(() => _includeExpiredItems = value),
                Icons.event_busy,
              ),
              _buildSwitchTile(
                'إظهار تفصيل المواقع',
                'تفصيل المخزون حسب المواقع المختلفة',
                _showLocationBreakdown,
                (value) => setState(() => _showLocationBreakdown = value),
                Icons.location_on,
              ),
              _buildSliderTile(
                'حد المخزون المنخفض للتقارير',
                'الحد الذي يعتبر فيه المخزون منخفضاً',
                _lowStockThreshold.toDouble(),
                1,
                100,
                (value) => setState(() => _lowStockThreshold = value.round()),
                Icons.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerReportsSettings() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildSwitchTile(
                'تفعيل تقارير العملاء',
                'إنشاء تقارير مفصلة عن العملاء',
                _enableCustomerReports,
                (value) => setState(() => _enableCustomerReports = value),
                Icons.people,
              ),
              _buildSwitchTile(
                'إظهار حسابات العملاء',
                'عرض الحسابات المستحقة للعملاء',
                _showCustomerBalance,
                (value) => setState(() => _showCustomerBalance = value),
                Icons.account_balance_wallet,
              ),
              _buildSwitchTile(
                'تضمين تاريخ المدفوعات',
                'إظهار تاريخ مدفوعات العملاء',
                _includePaymentHistory,
                (value) => setState(() => _includePaymentHistory = value),
                Icons.payment,
              ),
              _buildSwitchTile(
                'إظهار نقاط الولاء',
                'عرض نقاط الولاء المتراكمة للعملاء',
                _showLoyaltyPoints,
                (value) => setState(() => _showLoyaltyPoints = value),
                Icons.loyalty,
              ),
              _buildSwitchTile(
                'تفعيل تقسيم العملاء',
                'تقسيم العملاء حسب فئات مختلفة',
                _enableCustomerSegmentation,
                (value) => setState(() => _enableCustomerSegmentation = value),
                Icons.segment,
              ),
              _buildDropdownTile(
                'تجميع تقارير العملاء',
                'طريقة تجميع العملاء في التقارير',
                _customerReportGrouping,
                ['المجموعة', 'المنطقة', 'النوع', 'القيمة'],
                ['المجموعة', 'المنطقة', 'النوع', 'القيمة'],
                (value) => setState(() => _customerReportGrouping = value!),
                Icons.group_work,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialReportsSettings() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildSwitchTile(
                'تفعيل التقارير المالية',
                'إنشاء تقارير مالية مفصلة',
                _enableFinancialReports,
                (value) => setState(() => _enableFinancialReports = value),
                Icons.account_balance,
              ),
              _buildSwitchTile(
                'إظهار الأرباح والخسائر',
                'عرض بيان الأرباح والخسائر',
                _showProfitLoss,
                (value) => setState(() => _showProfitLoss = value),
                Icons.trending_up,
              ),
              _buildSwitchTile(
                'تضمين التدفق النقدي',
                'إظهار تقرير التدفق النقدي',
                _includeCashFlow,
                (value) => setState(() => _includeCashFlow = value),
                Icons.water_drop,
              ),
              _buildSwitchTile(
                'إظهار تفصيل المصروفات',
                'تفصيل المصروفات حسب الفئات',
                _showExpenseBreakdown,
                (value) => setState(() => _showExpenseBreakdown = value),
                Icons.pie_chart,
              ),
              _buildDropdownTile(
                'عملة التقارير المالية',
                'العملة المستخدمة في التقارير المالية',
                _financialReportCurrency,
                ['USD', 'EUR', 'IQD', 'SAR', 'AED'],
                [
                  'دولار أمريكي',
                  'يورو',
                  'دينار عراقي',
                  'ريال سعودي',
                  'درهم إماراتي',
                ],
                (value) => setState(() => _financialReportCurrency = value!),
                Icons.currency_exchange,
              ),
              _buildSwitchTile(
                'تفعيل مقارنة الميزانية',
                'مقارنة النتائج الفعلية مع الميزانية المخططة',
                _enableBudgetComparison,
                (value) => setState(() => _enableBudgetComparison = value),
                Icons.compare,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.5),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AssyrianTheme.primaryGold,
        activeTrackColor: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          secondary: Icon(icon, color: AssyrianTheme.deepBlue, size: 20.sp),
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.5),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AssyrianTheme.deepBlue, size: 18.sp),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _formattingService.formatInteger(value.round()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AssyrianTheme.primaryGold,
              inactiveTrackColor: AssyrianTheme.primaryGold.withValues(
                alpha: 0.25,
              ),
              thumbColor: AssyrianTheme.primaryGold,
              overlayColor: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    List<String> displayNames,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.5),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AssyrianTheme.deepBlue, size: 18.sp),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: options.asMap().entries.map((entry) {
                  var index = entry.key;
                  var option = entry.value;
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      displayNames[index],
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
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
                  'إعدادات التقارير',
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
          onPressed: _saveSettings,
          icon: Icon(Icons.save, color: AssyrianTheme.primaryGold, size: 24.sp),
          tooltip: 'حفظ الإعدادات',
        ),
        IconButton(
          onPressed: _loadSettings,
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
}
