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

/// صفحة إعدادات قسم المخزون
class InventorySettingsPage extends StatefulWidget {
  const InventorySettingsPage({super.key});

  @override
  State<InventorySettingsPage> createState() => _InventorySettingsPageState();
}

class _InventorySettingsPageState extends State<InventorySettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // إعدادات المخزون العامة
  bool _enableStockTracking = true;
  int _reminderDaysBefore = 7;
  List<int> _inventoryWarningDays = [1, 2, 3];
  bool _allowNegativeStock = false;
  bool _enableBarcodeScanning = true;
  bool _enableBatchTracking = true;
  bool _enableExpiryDateTracking = true;
  bool _enableSerialNumberTracking = false;

  // إعدادات التنبيهات والحد الأدنى
  bool _enableLowStockAlerts = true;
  int _defaultMinStockLevel = 10;
  int _criticalStockLevel = 5;
  bool _enableExpiryAlerts = true;
  int _expiryAlertDays = 30;
  bool _enableOverstockAlerts = false;

  // إعدادات التقييم والتسعير
  String _valuationMethod = 'FIFO'; // FIFO, LIFO, Average
  bool _enableAutomaticReorder = false;
  int _defaultReorderQuantity = 50;
  bool _enableDynamicPricing = false;
  double _markupPercentage = 25;
  bool _enableBulkDiscounts = true;

  // إعدادات المواقع والمستودعات
  bool _enableMultipleLocations = true;
  bool _enableLocationTransfers = true;
  bool _requireTransferApproval = true;
  bool _enableZoneManagement = false;
  int _maxLocationsPerItem = 10;
  bool _enableLocationRestrictions = false;

  // إشعارات وتنبيهات قسم المخزون (معطلة افتراضياً: false)
  bool _notifyNewProduct = false;
  bool _alertOutOfStock = false;
  bool _alertLowStock = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canManageSettings = await _permissionChecker.hasPermission('inventory_settings_manage');

    if (mounted) {
      setState(() {
        _canManageSettings = canManageSettings;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getInventorySettings();
      setState(() {
        _enableStockTracking = settings['enableStockTracking'] ?? true;
        _allowNegativeStock = settings['allowNegativeStock'] ?? false;
        _enableBarcodeScanning = settings['enableBarcodeScanning'] ?? true;
        _enableBatchTracking = settings['enableBatchTracking'] ?? true;
        _enableExpiryDateTracking =
            settings['enableExpiryDateTracking'] ?? true;
        _enableSerialNumberTracking =
            settings['enableSerialNumberTracking'] ?? false;
        _enableLowStockAlerts = settings['enableLowStockAlerts'] ?? true;
        _defaultMinStockLevel = settings['defaultMinStockLevel'] ?? 10;
        _criticalStockLevel = settings['criticalStockLevel'] ?? 5;
        _enableExpiryAlerts = settings['enableExpiryAlerts'] ?? true;
        _expiryAlertDays = settings['expiryAlertDays'] ?? 30;
        _enableOverstockAlerts = settings['enableOverstockAlerts'] ?? false;
        _valuationMethod = settings['valuationMethod'] ?? 'FIFO';
        _enableAutomaticReorder = settings['enableAutomaticReorder'] ?? false;
        _defaultReorderQuantity = settings['defaultReorderQuantity'] ?? 50;
        _enableDynamicPricing = settings['enableDynamicPricing'] ?? false;
        _markupPercentage = settings['markupPercentage'] ?? 25.0;
        _enableBulkDiscounts = settings['enableBulkDiscounts'] ?? true;
        _enableMultipleLocations = settings['enableMultipleLocations'] ?? true;
        _enableLocationTransfers = settings['enableLocationTransfers'] ?? true;
        _requireTransferApproval = settings['requireTransferApproval'] ?? true;
        _enableZoneManagement = settings['enableZoneManagement'] ?? false;
        _maxLocationsPerItem = settings['maxLocationsPerItem'] ?? 10;
        _enableLocationRestrictions =
            settings['enableLocationRestrictions'] ?? false;
      });

      // تحميل إعدادات إشعارات المخزون من إعدادات المستخدم الشخصية (معطلة افتراضياً: false)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(uid);
        if (mounted) {
          setState(() {
            _notifyNewProduct = userSettings['inventory_notify_new'] as bool? ?? false;
            _alertOutOfStock = userSettings['inventory_alert_out_of_stock'] as bool? ?? false;
            _alertLowStock = userSettings['inventory_alert_low_stock'] as bool? ?? false;

            // ✅ قراءة reminderDaysBefore من الإعدادات الشخصية إذا كانت موجودة
            final personalReminderDays =
                userSettings['reminderDaysBefore'] as int?;
            if (personalReminderDays != null) {
              _reminderDaysBefore = personalReminderDays;
            }

            // ✅ قراءة warningDays من الإعدادات الشخصية إذا كانت موجودة
            final personalWarningDays = userSettings['warningDays'] as List<dynamic>?;
            if (personalWarningDays != null && personalWarningDays.isNotEmpty) {
              _inventoryWarningDays =
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
        'enableStockTracking': _enableStockTracking,
        'allowNegativeStock': _allowNegativeStock,
        'enableBarcodeScanning': _enableBarcodeScanning,
        'enableBatchTracking': _enableBatchTracking,
        'enableExpiryDateTracking': _enableExpiryDateTracking,
        'enableSerialNumberTracking': _enableSerialNumberTracking,
        'enableLowStockAlerts': _enableLowStockAlerts,
        'defaultMinStockLevel': _defaultMinStockLevel,
        'criticalStockLevel': _criticalStockLevel,
        'enableExpiryAlerts': _enableExpiryAlerts,
        'expiryAlertDays': _expiryAlertDays,
        'enableOverstockAlerts': _enableOverstockAlerts,
        'valuationMethod': _valuationMethod,
        'enableAutomaticReorder': _enableAutomaticReorder,
        'defaultReorderQuantity': _defaultReorderQuantity,
        'enableDynamicPricing': _enableDynamicPricing,
        'markupPercentage': _markupPercentage,
        'enableBulkDiscounts': _enableBulkDiscounts,
        'enableMultipleLocations': _enableMultipleLocations,
        'enableLocationTransfers': _enableLocationTransfers,
        'requireTransferApproval': _requireTransferApproval,
        'enableZoneManagement': _enableZoneManagement,
        'maxLocationsPerItem': _maxLocationsPerItem,
        'enableLocationRestrictions': _enableLocationRestrictions,
      };

      await SettingsService.saveInventorySettings(settings);

      // ⚠️ ملاحظة اعتماد الإشعارات (توحيد مع SectionNotificationService):
    // مفتاح 'inventoryAlertsEnabled' لا يُحفظ مباشرة في هذه الصفحة، بل يُحسب
    // في SettingsService.getInventorySettings من
    // (enableLowStockAlerts || enableExpiryAlerts). أي تغيير على هذين
    // المفتاحين يغيّر إشعارات قسم المخزون بأكملها، بما فيها إشعارات
    // "إضافة مادة جديدة" (inventory_notify_new)، لأن
    // isSectionNotificationsEnabled('inventory') يتحقق من
    // inventoryAlerts_enabled. إذا احتاج النظام فصل تنبيه المنتجات الجديدة
    // عن تنبيهات المخزون المنخفض/المنتهي، عدل
    // SectionNotificationService.isSectionNotificationsEnabled لل_section
    // 'inventory' ليتحقق من inventory_notify_new أو inventoryAlertsEnabled.
    //
    // ⚠️ ملاحظة مفاتيح الإشعارات: هذه الصفحة تستخدم
    // 'inventory_notify_new'، 'inventory_alert_out_of_stock'، و
    // 'inventory_alert_low_stock'. البلوك في inventory_bloc.dart يستخدم
    // 'inventory_notify_new' و 'inventory_notify_deleted' و
    // 'inventory_notify_quantity_update'. SectionNotificationService يستخدم
    // 'inventory_alert_out_of_stock' و 'inventory_alert_low_stock'. يجب
    // تأمين توافق هذه المفاتيح عبر جميع الملفات عند أي تعديل مستقبلي.

      // حفظ تفضيلات إشعارات المخزون
      await SettingsService.setNotificationTypeEnabled(
        'inventory_notify_new',
        _notifyNewProduct,
      );
      await SettingsService.setNotificationTypeEnabled(
        'inventory_alert_out_of_stock',
        _alertOutOfStock,
      );
      await SettingsService.setNotificationTypeEnabled(
        'inventory_alert_low_stock',
        _alertLowStock,
      );

      // ✅ حفظ أيام التنبيه والتذكير في الإعدادات الشخصية لكل مستخدم
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await SettingsService.saveUserNotificationSettings(uid, {
          'reminderDaysBefore': _reminderDaysBefore,
          'warningDays': _inventoryWarningDays,
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
                'إعدادات المخزون',
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
              heroTag: 'inventory_settings_save_fab',
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
              moduleId: 'inventory_view',
              moduleName: 'قسم المخزون',
              moduleIcon: Icons.inventory_2,
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
                'إعدادات المخزون',
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
                  _buildSectionHeader('إعدادات المخزون العامة'),
                  _buildGeneralSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات التنبيهات والحد الأدنى'),
                  _buildAlertSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إشعارات وتنبيهات قسم المخزون'),
                  _buildInventoryNotificationSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات التقييم والتسعير'),
                  _buildPricingSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات المواقع والمستودعات'),
                  _buildLocationSettings(),
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
      _enableStockTracking = true;
      _allowNegativeStock = false;
      _enableBarcodeScanning = true;
      _enableBatchTracking = true;
      _enableExpiryDateTracking = true;
      _enableSerialNumberTracking = false;
      _enableLowStockAlerts = true;
      _defaultMinStockLevel = 10;
      _criticalStockLevel = 5;
      _enableExpiryAlerts = true;
      _expiryAlertDays = 30;
      _enableOverstockAlerts = false;
      _valuationMethod = 'FIFO';
      _enableAutomaticReorder = false;
      _defaultReorderQuantity = 50;
      _enableDynamicPricing = false;
      _markupPercentage = 25.0;
      _enableBulkDiscounts = true;
      _enableMultipleLocations = true;
      _enableLocationTransfers = true;
      _requireTransferApproval = true;
      _enableZoneManagement = false;
      _maxLocationsPerItem = 10;
      _enableLocationRestrictions = false;
    });
    // ⚠️ ملاحظة للمبرمجين المستقبليين: _resetToDefaults يُعيد إعدادات المخزون
    // العامة فقط، ولا يعيد إعدادات الإشعارات (_notifyNewProduct، _alertOutOfStock،
    // _alertLowStock) إلى قيمها الافتراضية. يُنصح بإضافة إعادة تعيين لهذه
    // المتغيرات أيضًا إذا كان المقصود إعادة جميع الإعدادات إلى defaults.
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
                'تفعيل تتبع المخزون',
                'تتبع كميات المنتجات في المخزون',
                _enableStockTracking,
                (value) => setState(() => _enableStockTracking = value),
                Icons.inventory,
              ),
              _buildSwitchTile(
                'السماح بالمخزون السالب',
                'إمكانية بيع منتجات غير متوفرة في المخزون',
                _allowNegativeStock,
                (value) => setState(() => _allowNegativeStock = value),
                Icons.remove_circle_outline,
              ),
              _buildSwitchTile(
                'تفعيل مسح الباركود',
                'استخدام الباركود لإدارة المنتجات',
                _enableBarcodeScanning,
                (value) => setState(() => _enableBarcodeScanning = value),
                Icons.qr_code_scanner,
              ),
              _buildSwitchTile(
                'تتبع الدفعات',
                'تتبع دفعات المنتجات وتواريخ الإنتاج',
                _enableBatchTracking,
                (value) => setState(() => _enableBatchTracking = value),
                Icons.batch_prediction,
              ),
              _buildSwitchTile(
                'تتبع تاريخ الانتهاء',
                'مراقبة تواريخ انتهاء صلاحية المنتجات',
                _enableExpiryDateTracking,
                (value) => setState(() => _enableExpiryDateTracking = value),
                Icons.schedule,
              ),
              _buildSwitchTile(
                'تتبع الأرقام التسلسلية',
                'تتبع الأرقام التسلسلية للمنتجات',
                _enableSerialNumberTracking,
                (value) => setState(() => _enableSerialNumberTracking = value),
                Icons.confirmation_number,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertSettings() {
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
                'تنبيهات نقص المخزون',
                'إرسال تنبيهات عند انخفاض المخزون',
                _enableLowStockAlerts,
                (value) => setState(() => _enableLowStockAlerts = value),
                Icons.warning_amber,
              ),
              _buildSliderTile(
                'الحد الأدنى الافتراضي للمخزون',
                'الكمية التي يتم إرسال تنبيه عندها',
                _defaultMinStockLevel.toDouble(),
                1,
                100,
                (value) =>
                    setState(() => _defaultMinStockLevel = value.round()),
                Icons.low_priority,
              ),
              _buildSliderTile(
                'مستوى المخزون الحرج',
                'الكمية الحرجة التي تتطلب تدخل فوري',
                _criticalStockLevel.toDouble(),
                1,
                50,
                (value) => setState(() => _criticalStockLevel = value.round()),
                Icons.priority_high,
              ),
              _buildSwitchTile(
                'تنبيهات انتهاء الصلاحية',
                'إرسال تنبيهات قبل انتهاء صلاحية المنتجات',
                _enableExpiryAlerts,
                (value) => setState(() => _enableExpiryAlerts = value),
                Icons.event_busy,
              ),
              _buildSliderTile(
                'أيام التنبيه قبل الانتهاء',
                'عدد الأيام قبل انتهاء الصلاحية لإرسال التنبيه',
                _expiryAlertDays.toDouble(),
                1,
                90,
                (value) => setState(() => _expiryAlertDays = value.round()),
                Icons.calendar_today,
              ),
              _buildSwitchTile(
                'تنبيهات فائض المخزون',
                'إرسال تنبيهات عند زيادة المخزون عن الحد المطلوب',
                _enableOverstockAlerts,
                (value) => setState(() => _enableOverstockAlerts = value),
                Icons.trending_up,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryNotificationSettings() {
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
                'إشعار إضافة مادة جديدة',
                'تنبيه عند إدخال منتج جديد إلى المخزون',
                _notifyNewProduct,
                (value) => setState(() => _notifyNewProduct = value),
                Icons.add_box_outlined,
              ),
              _buildSwitchTile(
                'تنبيه نفاد كمية مادة بالكامل',
                'تنبيه عاجل عند وصول كمية أي مادة إلى 0',
                _alertOutOfStock,
                (value) => setState(() => _alertOutOfStock = value),
                Icons.remove_shopping_cart,
              ),
              _buildSwitchTile(
                'تنبيه المخزون المنخفض',
                'تنبيه عند انخفاض كمية المادة إلى الحد الأدنى المحدد',
                _alertLowStock,
                (value) => setState(() => _alertLowStock = value),
                Icons.production_quantity_limits,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingSettings() {
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
              _buildDropdownTile(
                'طريقة تقييم المخزون',
                'الطريقة المستخدمة لحساب تكلفة المنتجات',
                _valuationMethod,
                ['FIFO', 'LIFO', 'Average'],
                [
                  'الوارد أولاً صادر أولاً',
                  'الوارد أخيراً صادر أولاً',
                  'المتوسط المرجح',
                ],
                (value) => setState(() => _valuationMethod = value!),
                Icons.calculate,
              ),
              _buildSwitchTile(
                'إعادة الطلب التلقائي',
                'طلب منتجات جديدة تلقائياً عند نقص المخزون',
                _enableAutomaticReorder,
                (value) => setState(() => _enableAutomaticReorder = value),
                Icons.autorenew,
              ),
              _buildSliderTile(
                'كمية إعادة الطلب الافتراضية',
                'الكمية التي يتم طلبها تلقائياً',
                _defaultReorderQuantity.toDouble(),
                10,
                500,
                (value) =>
                    setState(() => _defaultReorderQuantity = value.round()),
                Icons.shopping_cart,
              ),
              _buildSwitchTile(
                'التسعير الديناميكي',
                'تعديل الأسعار تلقائياً حسب العرض والطلب',
                _enableDynamicPricing,
                (value) => setState(() => _enableDynamicPricing = value),
                Icons.trending_up,
              ),
              _buildSliderTile(
                'نسبة الربح الافتراضية (%)',
                'نسبة الربح المضافة على تكلفة المنتج',
                _markupPercentage,
                0,
                100,
                (value) => setState(() => _markupPercentage = value),
                Icons.percent,
              ),
              _buildSwitchTile(
                'خصومات الكميات الكبيرة',
                'تطبيق خصومات عند شراء كميات كبيرة',
                _enableBulkDiscounts,
                (value) => setState(() => _enableBulkDiscounts = value),
                Icons.discount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSettings() {
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
                'مواقع متعددة',
                'إمكانية تخزين المنتجات في مواقع مختلفة',
                _enableMultipleLocations,
                (value) => setState(() => _enableMultipleLocations = value),
                Icons.location_on,
              ),
              _buildSwitchTile(
                'نقل بين المواقع',
                'إمكانية نقل المنتجات بين المواقع المختلفة',
                _enableLocationTransfers,
                (value) => setState(() => _enableLocationTransfers = value),
                Icons.swap_horiz,
              ),
              _buildSwitchTile(
                'موافقة على النقل',
                'تطلب موافقة مدير قبل نقل المنتجات',
                _requireTransferApproval,
                (value) => setState(() => _requireTransferApproval = value),
                Icons.approval,
              ),
              _buildSwitchTile(
                'إدارة المناطق',
                'تقسيم المستودعات إلى مناطق مختلفة',
                _enableZoneManagement,
                (value) => setState(() => _enableZoneManagement = value),
                Icons.map,
              ),
              _buildSliderTile(
                'أقصى عدد مواقع للمنتج الواحد',
                'العدد الأقصى من المواقع التي يمكن تخزين المنتج فيها',
                _maxLocationsPerItem.toDouble(),
                1,
                50,
                (value) => setState(() => _maxLocationsPerItem = value.round()),
                Icons.storage,
              ),
              _buildSwitchTile(
                'قيود المواقع',
                'تطبيق قيود على الوصول لمواقع معينة',
                _enableLocationRestrictions,
                (value) => setState(() => _enableLocationRestrictions = value),
                Icons.lock_outline,
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
                  'إعدادات المخزون',
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
