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

/// صفحة إعدادات قسم الإيجارات
class RentalsSettingsPage extends StatefulWidget {
  const RentalsSettingsPage({super.key});

  @override
  State<RentalsSettingsPage> createState() => _RentalsSettingsPageState();
}

class _RentalsSettingsPageState extends State<RentalsSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // إعدادات الإيجارات العامة
  bool _enableRentalTracking = true;
  bool _requireDeposit = true;
  bool _enableRentalContracts = true;
  bool _enableRentalCategories = true;
  bool _enableRentalScheduling = true;
  bool _allowPartialPayments = true;
  int _defaultRentalPeriodDays = 30;
  double _defaultDepositPercentage = 20;
  int _reminderDaysBefore = 7;
  List<int> _rentalWarningDays = [1, 2, 3];

  // إعدادات الدفع والفواتير
  bool _enableAutomaticBilling = true;
  bool _enableLateFees = true;
  bool _enableRentalDiscounts = true;
  bool _enableSeasonalPricing = false;
  double _lateFeePercentage = 5;
  int _gracePeriodDays = 3;
  int _maxDiscountPercentage = 25;

  // إعدادات الإشعارات والتذكيرات
  bool _enableEmailNotifications = true;
  bool _enableSMSNotifications = false;
  bool _sendRenewalReminders = true;
  bool _sendPaymentReminders = true;
  bool _sendExpiryNotifications = true;
  int _renewalReminderDays = 7;
  int _paymentReminderDays = 3;

// ⚠️ ملاحظة للمبرمجين المستقبليين: الإعدادات التالية تُحمَّل وتُحفظ لكنها غير مستخدمة في أي منطق إيجار (إعدادات ميتة):
// enableLateFees، lateFeePercentage، gracePeriodDays، maxDiscountPercentage، enableSeasonalPricing، enableRentalDiscounts، enableAutomaticBilling.
// كما أن مفاتيح الإشعارات في هذه الصفحة (rental_alert_expired، rental_alert_expiring_soon) تختلف عن المفاتيح التي تقرأها rental_notification_service.dart
// (rentalAlertOverdueEnabled، rentalAlertUpcomingEnabled، rentalAlertExpiringEnabled) — يجب توحيد المفاتيح.
  // إشعارات وتنبيهات قسم التأجير (معطلة افتراضياً: false)
  bool _notifyNewRental = false;
  bool _notifyReturnedRental = false;
  bool _alertExpiredRental = false;
  bool _alertExpiringSoonRental = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canManageSettings = await _permissionChecker.hasPermission('rentals_settings_manage');

    if (mounted) {
      setState(() {
        _canManageSettings = canManageSettings;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getRentalSettings();
      setState(() {
        _enableRentalTracking = settings['enableRentalTracking'] ?? true;
        _requireDeposit = settings['requireDeposit'] ?? true;
        _enableRentalContracts = settings['enableRentalContracts'] ?? true;
        _enableRentalCategories = settings['enableRentalCategories'] ?? true;
        _enableRentalScheduling = settings['enableRentalScheduling'] ?? true;
        _allowPartialPayments = settings['allowPartialPayments'] ?? true;
        _defaultRentalPeriodDays = settings['defaultRentalPeriodDays'] ?? 30;
        _defaultDepositPercentage =
            settings['defaultDepositPercentage'] ?? 20.0;
      });

      // تحميل إعدادات إشعارات التأجير من إعدادات المستخدم الشخصية (معطلة افتراضياً: false)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(uid);
        if (mounted) {
          setState(() {
            _notifyNewRental = userSettings['rental_notify_new'] as bool? ?? false;
            _notifyReturnedRental = userSettings['rental_notify_returned'] as bool? ?? false;
            _alertExpiredRental = userSettings['rental_alert_expired'] as bool? ?? false;
            _alertExpiringSoonRental =
                userSettings['rental_alert_expiring_soon'] as bool? ?? false;

            // ✅ قراءة reminderDaysBefore من الإعدادات الشخصية إذا كانت موجودة
            final personalReminderDays =
                userSettings['reminderDaysBefore'] as int?;
            if (personalReminderDays != null) {
              _reminderDaysBefore = personalReminderDays;
            }

            // ✅ قراءة warningDays من الإعدادات الشخصية إذا كانت موجودة
            final personalWarningDays = userSettings['warningDays'] as List<dynamic>?;
            if (personalWarningDays != null && personalWarningDays.isNotEmpty) {
              _rentalWarningDays =
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
        'enableRentalTracking': _enableRentalTracking,
        'requireDeposit': _requireDeposit,
        'enableRentalContracts': _enableRentalContracts,
        'enableRentalCategories': _enableRentalCategories,
        'enableRentalScheduling': _enableRentalScheduling,
        'allowPartialPayments': _allowPartialPayments,
        'defaultRentalPeriodDays': _defaultRentalPeriodDays,
        'defaultDepositPercentage': _defaultDepositPercentage,
        'enableAutomaticBilling': _enableAutomaticBilling,
        'enableLateFees': _enableLateFees,
        'enableRentalDiscounts': _enableRentalDiscounts,
        'enableSeasonalPricing': _enableSeasonalPricing,
        'lateFeePercentage': _lateFeePercentage,
        'gracePeriodDays': _gracePeriodDays,
        'maxDiscountPercentage': _maxDiscountPercentage,
        'enableEmailNotifications': _enableEmailNotifications,
        'enableSMSNotifications': _enableSMSNotifications,
        'sendRenewalReminders': _sendRenewalReminders,
        'sendPaymentReminders': _sendPaymentReminders,
        'sendExpiryNotifications': _sendExpiryNotifications,
        'renewalReminderDays': _renewalReminderDays,
        'paymentReminderDays': _paymentReminderDays,
      };

      await SettingsService.saveRentalSettings(settings);

      // حفظ تفضيلات إشعارات التأجير
      await SettingsService.setNotificationTypeEnabled(
        'rental_notify_new',
        _notifyNewRental,
      );
      await SettingsService.setNotificationTypeEnabled(
        'rental_notify_returned',
        _notifyReturnedRental,
      );
      await SettingsService.setNotificationTypeEnabled(
        'rental_alert_expired',
        _alertExpiredRental,
      );
      await SettingsService.setNotificationTypeEnabled(
        'rental_alert_expiring_soon',
        _alertExpiringSoonRental,
      );

      // ✅ حفظ أيام التنبيه والتذكير في الإعدادات الشخصية لكل مستخدم
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await SettingsService.saveUserNotificationSettings(uid, {
          'reminderDaysBefore': _reminderDaysBefore,
          'warningDays': _rentalWarningDays,
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
                'إعدادات الإيجارات',
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
              heroTag: 'rentals_settings_save_fab',
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
              moduleId: 'rentals_view',
              moduleName: 'قسم الإيجارات',
              moduleIcon: Icons.home_work,
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
                'إعدادات الإيجارات',
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
                  _buildSectionHeader('الإعدادات العامة للإيجارات'),
                  _buildGeneralSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات الدفع والفواتير'),
                  _buildPaymentSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات الإشعارات والتذكيرات'),
                  _buildNotificationSettings(),
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
      _enableRentalTracking = true;
      _requireDeposit = true;
      _enableRentalContracts = true;
      _enableRentalCategories = true;
      _enableRentalScheduling = true;
      _allowPartialPayments = true;
      _defaultRentalPeriodDays = 30;
      _defaultDepositPercentage = 20.0;
      _enableAutomaticBilling = true;
      _enableLateFees = true;
      _enableRentalDiscounts = true;
      _enableSeasonalPricing = false;
      _lateFeePercentage = 5.0;
      _gracePeriodDays = 3;
      _maxDiscountPercentage = 25;
      _enableEmailNotifications = true;
      _enableSMSNotifications = false;
      _sendRenewalReminders = true;
      _sendPaymentReminders = true;
      _sendExpiryNotifications = true;
      _renewalReminderDays = 7;
      _paymentReminderDays = 3;
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
                'تفعيل تتبع الإيجارات',
                'تتبع جميع عقود وعمليات الإيجار',
                _enableRentalTracking,
                (value) => setState(() => _enableRentalTracking = value),
                Icons.track_changes,
              ),
              _buildSwitchTile(
                'تطلب تأمين',
                'طلب مبلغ تأمين عند بداية الإيجار',
                _requireDeposit,
                (value) => setState(() => _requireDeposit = value),
                Icons.security,
              ),
              _buildSwitchTile(
                'تفعيل عقود الإيجار',
                'إنشاء عقود رسمية للإيجارات',
                _enableRentalContracts,
                (value) => setState(() => _enableRentalContracts = value),
                Icons.description,
              ),
              _buildSwitchTile(
                'تفعيل فئات الإيجار',
                'تصنيف العقارات والأصول المؤجرة',
                _enableRentalCategories,
                (value) => setState(() => _enableRentalCategories = value),
                Icons.category,
              ),
              _buildSwitchTile(
                'تفعيل جدولة الإيجارات',
                'جدولة مواعيد بداية ونهاية الإيجارات',
                _enableRentalScheduling,
                (value) => setState(() => _enableRentalScheduling = value),
                Icons.schedule,
              ),
              _buildSwitchTile(
                'السماح بالدفعات الجزئية',
                'تقسيط مبلغ الإيجار على دفعات',
                _allowPartialPayments,
                (value) => setState(() => _allowPartialPayments = value),
                Icons.payments,
              ),
              _buildSliderTile(
                'فترة الإيجار الافتراضية (يوم)',
                'المدة الافتراضية لعقود الإيجار',
                _defaultRentalPeriodDays.toDouble(),
                1,
                365,
                (value) =>
                    setState(() => _defaultRentalPeriodDays = value.round()),
                Icons.date_range,
              ),
              _buildSliderTile(
                'نسبة التأمين الافتراضية (%)',
                'نسبة مبلغ التأمين من قيمة الإيجار',
                _defaultDepositPercentage,
                5,
                50,
                (value) =>
                    setState(() => _defaultDepositPercentage = value),
                Icons.percent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSettings() {
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
                'تفعيل الفوترة التلقائية',
                'إنشاء فواتير تلقائياً للإيجارات',
                _enableAutomaticBilling,
                (value) => setState(() => _enableAutomaticBilling = value),
                Icons.receipt_long,
              ),
              _buildSwitchTile(
                'تفعيل رسوم التأخير',
                'فرض رسوم إضافية على المدفوعات المتأخرة',
                _enableLateFees,
                (value) => setState(() => _enableLateFees = value),
                Icons.money_off,
              ),
              _buildSwitchTile(
                'تفعيل خصومات الإيجار',
                'السماح بتطبيق خصومات على الإيجارات',
                _enableRentalDiscounts,
                (value) => setState(() => _enableRentalDiscounts = value),
                Icons.discount,
              ),
              _buildSwitchTile(
                'تفعيل التسعير الموسمي',
                'تغيير الأسعار حسب المواسم',
                _enableSeasonalPricing,
                (value) => setState(() => _enableSeasonalPricing = value),
                Icons.wb_sunny,
              ),
              _buildSliderTile(
                'نسبة رسوم التأخير (%)',
                'نسبة الرسوم الإضافية للدفع المتأخر',
                _lateFeePercentage,
                1,
                20,
                (value) => setState(() => _lateFeePercentage = value),
                Icons.percent,
              ),
              _buildSliderTile(
                'أيام فترة السماح',
                'عدد الأيام المسموحة قبل فرض رسوم التأخير',
                _gracePeriodDays.toDouble(),
                0,
                14,
                (value) => setState(() => _gracePeriodDays = value.round()),
                Icons.schedule,
              ),
              _buildSliderTile(
                'أقصى نسبة خصم (%)',
                'أقصى نسبة خصم يمكن تطبيقها',
                _maxDiscountPercentage.toDouble(),
                5,
                50,
                (value) =>
                    setState(() => _maxDiscountPercentage = value.round()),
                Icons.percent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
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
                'إشعار عقد تأجير جديد',
                'تنبيه عند إبرام عقد تأجير جديد',
                _notifyNewRental,
                (value) => setState(() => _notifyNewRental = value),
                Icons.vpn_key_outlined,
              ),
              _buildSwitchTile(
                'إشعار إرجاع التأجير',
                'تنبيه عند تأكيد إرجاع المواد المؤجرة بنجاح',
                _notifyReturnedRental,
                (value) => setState(() => _notifyReturnedRental = value),
                Icons.assignment_turned_in,
              ),
              _buildSwitchTile(
                'تنبيه عقود التأجير المتأخرة',
                'تنبيه بالعقود التي تجاوزت موعد الإرجاع المحدد',
                _alertExpiredRental,
                (value) => setState(() => _alertExpiredRental = value),
                Icons.history_toggle_off,
              ),
              _buildSwitchTile(
                'تنبيه قرب انتهاء عقد التأجير',
                'تنبيه استباقي قبل انتهاء العقد',
                _alertExpiringSoonRental,
                (value) => setState(() => _alertExpiringSoonRental = value),
                Icons.access_time,
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
                  'إعدادات الإيجارات',
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
