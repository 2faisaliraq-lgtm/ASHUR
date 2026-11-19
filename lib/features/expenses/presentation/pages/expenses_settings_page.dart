import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/module_enable_toggle.dart';

/// صفحة إعدادات قسم المصروفات
class ExpensesSettingsPage extends StatefulWidget {
  const ExpensesSettingsPage({super.key});

  @override
  State<ExpensesSettingsPage> createState() => _ExpensesSettingsPageState();
}

class _ExpensesSettingsPageState extends State<ExpensesSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // إعدادات المصروفات العامة
  bool _enableExpenseTracking = true;
  int _reminderDaysBefore = 7;
  List<int> _expensesWarningDays = [1, 2, 3];
  bool _requireApprovalForExpenses = true;
  double _maxExpenseWithoutApproval = 1000;
  bool _enableRecurringExpenses = true;
  bool _enableExpenseCategories = true;
  String _defaultExpenseCategory = 'عام';

  // إعدادات الموافقات والتفويض
  bool _enableMultiLevelApproval = false;
  int _approvalLevels = 2;
  bool _enableDelegatedApproval = true;
  bool _requireReceiptUpload = true;
  bool _enableBudgetChecking = true;
  bool _blockOverBudgetExpenses = false;

  // إعدادات التصنيفات والتتبع
  bool _enableProjectTracking = true;
  bool _enableDepartmentTracking = true;
  bool _enableVendorTracking = true;
  bool _enableTaxTracking = true;
  double _defaultTaxRate = 15;
  bool _enableMileageTracking = false;

  // إعدادات التقارير والتحليل
  bool _enableExpenseReports = true;
  String _reportingPeriod = 'شهري';
  bool _enableBudgetComparison = true;
  bool _enableTrendAnalysis = true;
  bool _enableCostCenterReporting = true;
  bool _enableVendorAnalysis = true;

  // إشعارات وتنبيهات قسم المصروفات (معطلة افتراضياً: false)
  bool _notifyNewExpense = false;
  bool _notifyUpdatedExpense = false;
  bool _notifyDeletedExpense = false;
  bool _alertPendingExpense = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canManageSettings = await _permissionChecker.hasPermission('expenses_settings_manage');

    if (mounted) {
      setState(() {
        _canManageSettings = canManageSettings;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getExpensesSettings();
      setState(() {
        _enableExpenseTracking = settings['enableExpenseTracking'] ?? true;
        _requireApprovalForExpenses =
            settings['requireApprovalForExpenses'] ?? true;
        _maxExpenseWithoutApproval =
            settings['maxExpenseWithoutApproval'] ?? 1000.0;
        _enableRecurringExpenses = settings['enableRecurringExpenses'] ?? true;
        _enableExpenseCategories = settings['enableExpenseCategories'] ?? true;

        // التأكد من أن القيمة موجودة في القائمة
        final loadedCategory = settings['defaultExpenseCategory'] ?? 'عام';
        final validCategories = [
          'عام',
          'مكتب',
          'سفر',
          'تسويق',
          'تقنية معلومات',
          'مرافق',
        ];
        _defaultExpenseCategory = validCategories.contains(loadedCategory)
            ? loadedCategory
            : 'عام';

        _enableMultiLevelApproval =
            settings['enableMultiLevelApproval'] ?? false;
        _approvalLevels = settings['approvalLevels'] ?? 2;
        _enableDelegatedApproval = settings['enableDelegatedApproval'] ?? true;
        _requireReceiptUpload = settings['requireReceiptUpload'] ?? true;
        _enableBudgetChecking = settings['enableBudgetChecking'] ?? true;
        _blockOverBudgetExpenses = settings['blockOverBudgetExpenses'] ?? false;
        _enableProjectTracking = settings['enableProjectTracking'] ?? true;
        _enableDepartmentTracking =
            settings['enableDepartmentTracking'] ?? true;
        _enableVendorTracking = settings['enableVendorTracking'] ?? true;
        _enableTaxTracking = settings['enableTaxTracking'] ?? true;
        _defaultTaxRate = settings['defaultTaxRate'] ?? 15.0;
        _enableMileageTracking = settings['enableMileageTracking'] ?? false;
        _enableExpenseReports = settings['enableExpenseReports'] ?? true;

        // التأكد من أن القيمة موجودة في القائمة
        final loadedPeriod = settings['reportingPeriod'] ?? 'شهري';
        final validPeriods = ['أسبوعي', 'شهري', 'ربع سنوي', 'سنوي'];
        _reportingPeriod = validPeriods.contains(loadedPeriod)
            ? loadedPeriod
            : 'شهري';

        _enableBudgetComparison = settings['enableBudgetComparison'] ?? true;
        _enableTrendAnalysis = settings['enableTrendAnalysis'] ?? true;
        _enableCostCenterReporting =
            settings['enableCostCenterReporting'] ?? true;
        _enableVendorAnalysis = settings['enableVendorAnalysis'] ?? true;
      });

      // تحميل إعدادات إشعارات المصروفات من إعدادات المستخدم الشخصية (معطلة افتراضياً: false)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(uid);
        if (mounted) {
          setState(() {
            _notifyNewExpense = userSettings['expenses_notify_new'] as bool? ?? false;
            _notifyUpdatedExpense = userSettings['expenses_notify_updated'] as bool? ?? false;
            _notifyDeletedExpense = userSettings['expenses_notify_deleted'] as bool? ?? false;
            _alertPendingExpense = userSettings['expenses_alert_pending'] as bool? ?? false;

            // ✅ قراءة reminderDaysBefore من الإعدادات الشخصية إذا كانت موجودة
            final personalReminderDays =
                userSettings['reminderDaysBefore'] as int?;
            if (personalReminderDays != null) {
              _reminderDaysBefore = personalReminderDays;
            }

            // ✅ قراءة warningDays من الإعدادات الشخصية إذا كانت موجودة
            final personalWarningDays = userSettings['warningDays'] as List<dynamic>?;
            if (personalWarningDays != null && personalWarningDays.isNotEmpty) {
              _expensesWarningDays =
                  personalWarningDays
                      .map((day) => int.tryParse(day.toString()) ?? 1)
                      .toList()
                    ..sort();
            }
          });
        }
      }
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
        'enableExpenseTracking': _enableExpenseTracking,
        'requireApprovalForExpenses': _requireApprovalForExpenses,
        'maxExpenseWithoutApproval': _maxExpenseWithoutApproval,
        'enableRecurringExpenses': _enableRecurringExpenses,
        'enableExpenseCategories': _enableExpenseCategories,
        'defaultExpenseCategory': _defaultExpenseCategory,
        'enableMultiLevelApproval': _enableMultiLevelApproval,
        'approvalLevels': _approvalLevels,
        'enableDelegatedApproval': _enableDelegatedApproval,
        'requireReceiptUpload': _requireReceiptUpload,
        'enableBudgetChecking': _enableBudgetChecking,
        'blockOverBudgetExpenses': _blockOverBudgetExpenses,
        'enableProjectTracking': _enableProjectTracking,
        'enableDepartmentTracking': _enableDepartmentTracking,
        'enableVendorTracking': _enableVendorTracking,
        'enableTaxTracking': _enableTaxTracking,
        'defaultTaxRate': _defaultTaxRate,
        'enableMileageTracking': _enableMileageTracking,
        'enableExpenseReports': _enableExpenseReports,
        'reportingPeriod': _reportingPeriod,
        'enableBudgetComparison': _enableBudgetComparison,
        'enableTrendAnalysis': _enableTrendAnalysis,
        'enableCostCenterReporting': _enableCostCenterReporting,
        'enableVendorAnalysis': _enableVendorAnalysis,
      };

      await SettingsService.saveExpensesSettings(settings);

      // حفظ تفضيلات إشعارات المصروفات
      await SettingsService.setNotificationTypeEnabled(
        'expenses_notify_new',
        _notifyNewExpense,
      );
      await SettingsService.setNotificationTypeEnabled(
        'expenses_notify_updated',
        _notifyUpdatedExpense,
      );
      await SettingsService.setNotificationTypeEnabled(
        'expenses_notify_deleted',
        _notifyDeletedExpense,
      );
      await SettingsService.setNotificationTypeEnabled(
        'expenses_alert_pending',
        _alertPendingExpense,
      );

      // ✅ حفظ أيام التنبيه والتذكير في الإعدادات الشخصية لكل مستخدم
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await SettingsService.saveUserNotificationSettings(uid, {
          'reminderDaysBefore': _reminderDaysBefore,
          'warningDays': _expensesWarningDays,
        });
      }

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
                'إعدادات المصروفات',
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
              heroTag: 'expenses_settings_save_fab',
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
              moduleId: 'expenses_view',
              moduleName: 'قسم المصروفات',
              moduleIcon: Icons.money_off,
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
                'إعدادات المصروفات',
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
                  _buildSectionHeader('الإعدادات العامة للمصروفات'),
                  _buildGeneralSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إشعارات وتنبيهات قسم المصروفات'),
                  _buildExpensesNotificationSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('الموافقات والتفويض'),
                  _buildApprovalSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('التصنيفات والتتبع'),
                  _buildTrackingSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('التقارير والتحليل'),
                  _buildReportingSettings(),
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
      _enableExpenseTracking = true;
      _requireApprovalForExpenses = true;
      _maxExpenseWithoutApproval = 1000.0;
      _enableRecurringExpenses = true;
      _enableExpenseCategories = true;
      _defaultExpenseCategory = 'عام';
      _enableMultiLevelApproval = false;
      _approvalLevels = 2;
      _enableDelegatedApproval = true;
      _requireReceiptUpload = true;
      _enableBudgetChecking = true;
      _blockOverBudgetExpenses = false;
      _enableProjectTracking = true;
      _enableDepartmentTracking = true;
      _enableVendorTracking = true;
      _enableTaxTracking = true;
      _defaultTaxRate = 15.0;
      _enableMileageTracking = false;
      _enableExpenseReports = true;
      _reportingPeriod = 'شهري';
      _enableBudgetComparison = true;
      _enableTrendAnalysis = true;
      _enableCostCenterReporting = true;
      _enableVendorAnalysis = true;
      // إعادة تعيين إعدادات الإشعارات إلى القيم الافتراضية (معطلة)
      _notifyNewExpense = false;
      _notifyUpdatedExpense = false;
      _notifyDeletedExpense = false;
      _alertPendingExpense = false;
    });
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
                'تفعيل تتبع المصروفات',
                'تسجيل ومتابعة جميع المصروفات',
                _enableExpenseTracking,
                (value) => setState(() => _enableExpenseTracking = value),
                Icons.track_changes,
              ),
              _buildSwitchTile(
                'تطلب موافقة على المصروفات',
                'موافقة مسبقة قبل تسجيل المصروفات',
                _requireApprovalForExpenses,
                (value) => setState(() => _requireApprovalForExpenses = value),
                Icons.approval,
              ),
              _buildSliderTile(
                'الحد الأقصى بدون موافقة',
                'أقصى مبلغ يمكن صرفه بدون موافقة',
                _maxExpenseWithoutApproval,
                100,
                10000,
                (value) => setState(() => _maxExpenseWithoutApproval = value),
                Icons.money_off,
              ),
              _buildSwitchTile(
                'تفعيل المصروفات المتكررة',
                'إمكانية إنشاء مصروفات دورية',
                _enableRecurringExpenses,
                (value) => setState(() => _enableRecurringExpenses = value),
                Icons.repeat,
              ),
              _buildSwitchTile(
                'تفعيل تصنيفات المصروفات',
                'تصنيف المصروفات حسب الفئات',
                _enableExpenseCategories,
                (value) => setState(() => _enableExpenseCategories = value),
                Icons.category,
              ),
              _buildDropdownTile(
                'التصنيف الافتراضي',
                'التصنيف المحدد تلقائياً للمصروفات الجديدة',
                _defaultExpenseCategory,
                ['عام', 'مكتب', 'سفر', 'تسويق', 'تقنية معلومات', 'مرافق'],
                ['عام', 'مكتب', 'سفر', 'تسويق', 'تقنية معلومات', 'مرافق'],
                (value) => setState(() => _defaultExpenseCategory = value!),
                Icons.label,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesNotificationSettings() {
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
                'إشعار تسجيل مصروف جديد',
                'تنبيه عند تسجيل سند صرف جديد في النظام',
                _notifyNewExpense,
                (value) => setState(() => _notifyNewExpense = value),
                Icons.attach_money,
              ),
              _buildSwitchTile(
                'إشعار تعديل مصروف',
                'تنبيه عند تعديل أي مصروف في النظام',
                _notifyUpdatedExpense,
                (value) => setState(() => _notifyUpdatedExpense = value),
                Icons.edit,
              ),
              _buildSwitchTile(
                'إشعار حذف مصروف',
                'تنبيه عند حذف أي مصروف من النظام',
                _notifyDeletedExpense,
                (value) => setState(() => _notifyDeletedExpense = value),
                Icons.delete,
              ),
              _buildSwitchTile(
                'تنبيه المصروفات المعلقة',
                'تنبيه بالمصروفات التي بانتظار المراجعة والاعتماد',
                _alertPendingExpense,
                (value) => setState(() => _alertPendingExpense = value),
                Icons.hourglass_top,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalSettings() {
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
                'موافقة متعددة المستويات',
                'تطلب موافقة من عدة مستويات إدارية',
                _enableMultiLevelApproval,
                (value) => setState(() => _enableMultiLevelApproval = value),
                Icons.layers,
              ),
              _buildSliderTile(
                'عدد مستويات الموافقة',
                'عدد المستويات الإدارية المطلوبة للموافقة',
                _approvalLevels.toDouble(),
                1,
                5,
                (value) => setState(() => _approvalLevels = value.round()),
                Icons.format_list_numbered,
              ),
              _buildSwitchTile(
                'تفعيل التفويض',
                'إمكانية تفويض صلاحيات الموافقة',
                _enableDelegatedApproval,
                (value) => setState(() => _enableDelegatedApproval = value),
                Icons.person_add,
              ),
              _buildSwitchTile(
                'تطلب رفع الإيصالات',
                'إجبارية رفع صور الإيصالات',
                _requireReceiptUpload,
                (value) => setState(() => _requireReceiptUpload = value),
                Icons.receipt,
              ),
              _buildSwitchTile(
                'تفعيل فحص الميزانية',
                'التحقق من توفر الميزانية قبل الموافقة',
                _enableBudgetChecking,
                (value) => setState(() => _enableBudgetChecking = value),
                Icons.account_balance,
              ),
              _buildSwitchTile(
                'منع المصروفات الزائدة عن الميزانية',
                'رفض المصروفات التي تتجاوز الميزانية المحددة',
                _blockOverBudgetExpenses,
                (value) => setState(() => _blockOverBudgetExpenses = value),
                Icons.block,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingSettings() {
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
                'تتبع المشاريع',
                'ربط المصروفات بالمشاريع المختلفة',
                _enableProjectTracking,
                (value) => setState(() => _enableProjectTracking = value),
                Icons.work,
              ),
              _buildSwitchTile(
                'تتبع الأقسام',
                'تصنيف المصروفات حسب الأقسام',
                _enableDepartmentTracking,
                (value) => setState(() => _enableDepartmentTracking = value),
                Icons.business_center,
              ),
              _buildSwitchTile(
                'تتبع الموردين',
                'تسجيل المصروفات حسب الموردين',
                _enableVendorTracking,
                (value) => setState(() => _enableVendorTracking = value),
                Icons.store,
              ),
              _buildSwitchTile(
                'تتبع الضرائب',
                'حساب وتتبع الضرائب على المصروفات',
                _enableTaxTracking,
                (value) => setState(() => _enableTaxTracking = value),
                Icons.calculate,
              ),
              _buildSliderTile(
                'معدل الضريبة الافتراضي (%)',
                'نسبة الضريبة المطبقة على المصروفات',
                _defaultTaxRate,
                0,
                30,
                (value) => setState(() => _defaultTaxRate = value),
                Icons.percent,
              ),
              _buildSwitchTile(
                'تتبع المسافات المقطوعة',
                'تسجيل المسافات لحساب مصروفات السفر',
                _enableMileageTracking,
                (value) => setState(() => _enableMileageTracking = value),
                Icons.directions_car,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportingSettings() {
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
                'تفعيل تقارير المصروفات',
                'إنشاء تقارير مفصلة عن المصروفات',
                _enableExpenseReports,
                (value) => setState(() => _enableExpenseReports = value),
                Icons.assessment,
              ),
              _buildDropdownTile(
                'فترة التقارير',
                'الفترة الزمنية الافتراضية للتقارير',
                _reportingPeriod,
                ['أسبوعي', 'شهري', 'ربع سنوي', 'سنوي'],
                ['أسبوعي', 'شهري', 'ربع سنوي', 'سنوي'],
                (value) => setState(() => _reportingPeriod = value!),
                Icons.date_range,
              ),
              _buildSwitchTile(
                'مقارنة الميزانية',
                'مقارنة المصروفات الفعلية مع الميزانية المخططة',
                _enableBudgetComparison,
                (value) => setState(() => _enableBudgetComparison = value),
                Icons.compare_arrows,
              ),
              _buildSwitchTile(
                'تحليل الاتجاهات',
                'تحليل اتجاهات المصروفات عبر الزمن',
                _enableTrendAnalysis,
                (value) => setState(() => _enableTrendAnalysis = value),
                Icons.trending_up,
              ),
              _buildSwitchTile(
                'تقارير مراكز التكلفة',
                'تقارير مفصلة حسب مراكز التكلفة',
                _enableCostCenterReporting,
                (value) => setState(() => _enableCostCenterReporting = value),
                Icons.account_tree,
              ),
              _buildSwitchTile(
                'تحليل الموردين',
                'تحليل المصروفات حسب الموردين',
                _enableVendorAnalysis,
                (value) => setState(() => _enableVendorAnalysis = value),
                Icons.analytics,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
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
                  value % 1 == 0
                      ? _formattingService.formatInteger(value.round())
                      : _formattingService.formatNumber(value),
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
                  'إعدادات المصروفات',
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
