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

/// صفحة إعدادات قسم الاشتراكات
class SubscriptionsSettingsPage extends StatefulWidget {
  const SubscriptionsSettingsPage({super.key});

  @override
  State<SubscriptionsSettingsPage> createState() =>
      _SubscriptionsSettingsPageState();
}

class _SubscriptionsSettingsPageState extends State<SubscriptionsSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // إعدادات الاشتراكات العامة
  bool _enableAutoRenewal = true;
  bool _requirePaymentConfirmation = true;
  bool _enableTrialPeriods = true;
  bool _allowSubscriptionUpgrade = true;
  bool _enableProrationCalculation = true;
  bool _sendRenewalReminders = true;
  int _reminderDaysBefore = 7;
  int _defaultTrialDays = 14;
  int _subscriptionDefaultHour = 0;
  int _subscriptionDefaultMinute = 0;

  // إعدادات الفواتير والدفع
  bool _enableAutomaticBilling = true;
  bool _allowPartialPayments = false;
  bool _enableRefunds = true;
  String _defaultPaymentMethod = 'credit_card';
  int _gracePeriodDays = 3;
  double _lateFeePercentage = 5;

  // إعدادات الإشعارات (معطلة افتراضياً: false)
  bool _subscriptionAlertsEnabled = false;
  bool _enableEmailNotifications = true;
  bool _enableSMSNotifications = false;
  bool _sendWelcomeEmails = true;
  bool _sendCancellationEmails = true;
  bool _sendUpgradeNotifications = true;
  bool _subscriptionAlertRenewalEnabled = false;
  bool _subscriptionAlertNewEnabled = false;
  bool _subscriptionAlertExpiredEnabled = false;
  bool _subscriptionAlertLocalEnabled = true;
  bool _subscriptionAlertPushEnabled = true;
  final List<int> _warningDays = [1, 2, 3];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canManageSettings = await _permissionChecker.hasPermission(
      'subscriptions_settings_manage',
    );

    if (mounted) {
      setState(() {
        _canManageSettings = canManageSettings;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getSubscriptionSettings();
      final warningDays = settings['subscriptionWarningDays'] is List
          ? ((settings['subscriptionWarningDays'] as List)
                .map((day) => int.tryParse(day.toString()) ?? 1)
                .toSet()
                .toList()
              ..sort())
          : [1, 2, 3, 7];

      setState(() {
        _subscriptionAlertsEnabled =
            settings['subscriptionAlertsEnabled'] ?? false;
        _enableAutoRenewal = settings['enableAutoRenewal'] ?? true;
        _requirePaymentConfirmation =
            settings['requirePaymentConfirmation'] ?? true;
        _enableTrialPeriods = settings['enableTrialPeriods'] ?? true;
        _allowSubscriptionUpgrade =
            settings['allowSubscriptionUpgrade'] ?? true;
        _enableProrationCalculation =
            settings['enableProrationCalculation'] ?? true;
        _sendRenewalReminders = settings['sendRenewalReminders'] ?? true;
        _reminderDaysBefore = settings['reminderDaysBefore'] ?? 7;
        _defaultTrialDays = settings['defaultTrialDays'] ?? 14;
        _subscriptionDefaultHour = settings['subscriptionDefaultHour'] ?? 0;
        _subscriptionDefaultMinute = settings['subscriptionDefaultMinute'] ?? 0;
      });

      // تحميل تفضيلات إشعارات الاشتراكات من إعدادات المستخدم الشخصية (معطلة افتراضياً: false)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(uid);
        if (mounted) {
          setState(() {
            _subscriptionAlertRenewalEnabled =
                userSettings['subscription_notify_new'] as bool? ?? false;
            _subscriptionAlertNewEnabled =
                userSettings['subscription_notify_new'] as bool? ?? false;
            _subscriptionAlertExpiredEnabled =
                userSettings['subscription_alert_expiring_soon'] as bool? ?? false;
            _subscriptionAlertLocalEnabled =
                userSettings['enablePushNotifications'] as bool? ?? true;
            _subscriptionAlertPushEnabled =
                userSettings['enablePushNotifications'] as bool? ?? true;

            // ✅ قراءة أيام التنبيه من الإعدادات الشخصية إذا كانت موجودة
            final personalWarningDays = userSettings['warningDays'] as List<dynamic>?;
            if (personalWarningDays != null && personalWarningDays.isNotEmpty) {
              _warningDays.clear();
              _warningDays.addAll(
                personalWarningDays
                    .map((day) => int.tryParse(day.toString()) ?? 1)
                    .toList()
                  ..sort(),
              );
            } else {
              _warningDays.clear();
              _warningDays.addAll(warningDays);
            }

            // ✅ قراءة reminderDaysBefore من الإعدادات الشخصية إذا كانت موجودة
            final personalReminderDays =
                userSettings['reminderDaysBefore'] as int?;
            if (personalReminderDays != null) {
              _reminderDaysBefore = personalReminderDays;
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
        'enableAutoRenewal': _enableAutoRenewal,
        'requirePaymentConfirmation': _requirePaymentConfirmation,
        'enableTrialPeriods': _enableTrialPeriods,
        'allowSubscriptionUpgrade': _allowSubscriptionUpgrade,
        'enableProrationCalculation': _enableProrationCalculation,
        'sendRenewalReminders': _sendRenewalReminders,
        'reminderDaysBefore': _reminderDaysBefore,
        'defaultTrialDays': _defaultTrialDays,
        'subscriptionDefaultHour': _subscriptionDefaultHour,
        'subscriptionDefaultMinute': _subscriptionDefaultMinute,
        'enableAutomaticBilling': _enableAutomaticBilling,
        'allowPartialPayments': _allowPartialPayments,
        'enableRefunds': _enableRefunds,
        'defaultPaymentMethod': _defaultPaymentMethod,
        'gracePeriodDays': _gracePeriodDays,
        'lateFeePercentage': _lateFeePercentage,
        'subscriptionAlertsEnabled': _subscriptionAlertsEnabled,
        'subscriptionWarningDays': _warningDays,
        'subscriptionAlertRenewalEnabled': _subscriptionAlertRenewalEnabled,
        'subscriptionAlertNewEnabled': _subscriptionAlertNewEnabled,
        'subscriptionAlertExpiredEnabled': _subscriptionAlertExpiredEnabled,
        'subscriptionAlertLocalEnabled': _subscriptionAlertLocalEnabled,
        'subscriptionAlertPushEnabled': _subscriptionAlertPushEnabled,
        'enableEmailNotifications': _enableEmailNotifications,
        'enableSMSNotifications': _enableSMSNotifications,
        'sendWelcomeEmails': _sendWelcomeEmails,
        'sendCancellationEmails': _sendCancellationEmails,
        'sendUpgradeNotifications': _sendUpgradeNotifications,
        'enableSectionBadges': _subscriptionAlertsEnabled,
      };

      // ⚠️ ملاحظات إعدادات توثيقية للمبرمجين المستقبليين (مدمجة):
      // [إعدادات] 'enableSectionBadges' يُضبط بقيمة _subscriptionAlertsEnabled
      // (تفعيل التنبيهات) وليس بمفتاح مستقل لأيقونات القسم → توصيف خاطئ محتمل.
      // [إعدادات] هناك ازدواجية في مصادر إعدادات الإشعارات: getSubscriptionSettings()
      // يحفظ مفاتيح مثل subscriptionAlertsEnabled/subscriptionWarningDays بينما
      // setNotificationType_enabled يستخدم مفاتيح منفصلة
      // (subscription_notify_new، subscription_alert_expired،
      // subscription_alert_expiring_soon). يُنصح بتوحيد المصدر لتجنب الخلط.
      // [إعدادات] عند الحفظ: المفتاح 'subscription_alert_expiring_soon' يُحفظ بقيمة
      // _subscriptionAlertRenewalEnabled (تبديل "تنبيه قرب انتهاء الاشتراك") وليس
      // بمفتاح منفصل. ورغم أن هذا يعمل وظيفياً، فإن التسمية مربكة. يُنصح بفصل
      // المفتاحين أو توثيق هذا الربط بوضوح.
      await SettingsService.saveSubscriptionSettings(settings);
      await SettingsService.setNotificationTypeEnabled(
        'subscription_notify_new',
        _subscriptionAlertNewEnabled,
      );
      await SettingsService.setNotificationTypeEnabled(
        'subscription_alert_expired',
        _subscriptionAlertExpiredEnabled,
      );
      await SettingsService.setNotificationTypeEnabled(
        'subscription_alert_expiring_soon',
        _subscriptionAlertRenewalEnabled,
      );

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
                'إعدادات الاشتراكات',
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
              heroTag: 'subscriptions_settings_save_fab',
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
              moduleId: 'subscriptions_view',
              moduleName: 'قسم الاشتراكات',
              moduleIcon: Icons.subscriptions,
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
                'إعدادات الاشتراكات',
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
                  _buildSectionHeader('الإعدادات العامة للاشتراكات'),
                  _buildGeneralSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات الفواتير والدفع'),
                  _buildBillingSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات الإشعارات'),
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
      _enableAutoRenewal = true;
      _requirePaymentConfirmation = true;
      _enableTrialPeriods = true;
      _allowSubscriptionUpgrade = true;
      _enableProrationCalculation = true;
      _sendRenewalReminders = true;
      _reminderDaysBefore = 7;
      _defaultTrialDays = 14;
      _enableAutomaticBilling = true;
      _allowPartialPayments = false;
      _enableRefunds = true;
      _defaultPaymentMethod = 'credit_card';
      _gracePeriodDays = 3;
      _lateFeePercentage = 5.0;
      _subscriptionAlertsEnabled = false;
      _enableEmailNotifications = true;
      _enableSMSNotifications = false;
      _sendWelcomeEmails = true;
      _sendCancellationEmails = true;
      _sendUpgradeNotifications = true;
      _subscriptionAlertRenewalEnabled = true;
      _subscriptionAlertNewEnabled = true;
      _subscriptionAlertExpiredEnabled = true;
      _subscriptionAlertLocalEnabled = true;
      _subscriptionAlertPushEnabled = true;
      _warningDays
        ..clear()
        ..addAll([1, 2, 3, 7]);
      _subscriptionDefaultHour = 0;
      _subscriptionDefaultMinute = 0;
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
                'تفعيل التجديد التلقائي',
                'تجديد الاشتراكات تلقائياً عند انتهائها',
                _enableAutoRenewal,
                (value) => setState(() => _enableAutoRenewal = value),
                Icons.autorenew,
              ),
              _buildSwitchTile(
                'تطلب تأكيد الدفع',
                'يجب تأكيد الدفع قبل تجديد الاشتراك',
                _requirePaymentConfirmation,
                (value) => setState(() => _requirePaymentConfirmation = value),
                Icons.payment,
              ),
              _buildSwitchTile(
                'تفعيل فترات التجربة',
                'السماح بفترات تجربة مجانية للاشتراكات',
                _enableTrialPeriods,
                (value) => setState(() => _enableTrialPeriods = value),
                Icons.free_breakfast,
              ),
              _buildSwitchTile(
                'السماح بترقية الاشتراك',
                'يمكن للعملاء ترقية اشتراكاتهم',
                _allowSubscriptionUpgrade,
                (value) => setState(() => _allowSubscriptionUpgrade = value),
                Icons.upgrade,
              ),
              _buildSwitchTile(
                'تفعيل حساب التناسب',
                'حساب المبلغ المتناسب عند التغيير',
                _enableProrationCalculation,
                (value) => setState(() => _enableProrationCalculation = value),
                Icons.calculate,
              ),
              _buildSliderTile(
                'أيام فترة التجربة الافتراضية',
                'عدد أيام التجربة المجانية',
                _defaultTrialDays.toDouble(),
                7,
                30,
                (value) => setState(() => _defaultTrialDays = value.round()),
                Icons.schedule,
              ),
              _buildTimeTile(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillingSettings() {
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
                'إنشاء فواتير تلقائياً للاشتراكات',
                _enableAutomaticBilling,
                (value) => setState(() => _enableAutomaticBilling = value),
                Icons.receipt_long,
              ),
              _buildSwitchTile(
                'السماح بالدفعات الجزئية',
                'يمكن دفع الاشتراك على دفعات',
                _allowPartialPayments,
                (value) => setState(() => _allowPartialPayments = value),
                Icons.payments,
              ),
              _buildSwitchTile(
                'تفعيل المبالغ المستردة',
                'السماح باسترداد مبالغ الاشتراكات',
                _enableRefunds,
                (value) => setState(() => _enableRefunds = value),
                Icons.money_off,
              ),
              _buildSliderTile(
                'أيام فترة السماح',
                'عدد الأيام بعد انتهاء الاشتراك قبل الإيقاف',
                _gracePeriodDays.toDouble(),
                1,
                14,
                (value) => setState(() => _gracePeriodDays = value.round()),
                Icons.schedule,
              ),
              _buildSliderTile(
                'نسبة رسوم التأخير (%)',
                'نسبة الرسوم الإضافية للدفع المتأخر',
                _lateFeePercentage,
                0,
                20,
                (value) => setState(() => _lateFeePercentage = value),
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
                'إشعار تسجيل اشتراك جديد',
                'تنبيه فوري عند إضافة اشتراك جديد لمشترك',
                _subscriptionAlertNewEnabled,
                (value) => setState(() => _subscriptionAlertNewEnabled = value),
                Icons.add_circle_outline,
              ),
              _buildSwitchTile(
                'تنبيه قرب انتهاء الاشتراك',
                'تنبيه استباقي قبل انتهاء الاشتراك بأيام محددة',
                _subscriptionAlertRenewalEnabled,
                (value) =>
                    setState(() => _subscriptionAlertRenewalEnabled = value),
                Icons.notification_important,
              ),
              _buildSwitchTile(
                'تنبيه الاشتراكات المنتهية',
                'تنبيه عاجل عند انتهاء صلاحية الاشتراك وحاجته للتجديد',
                _subscriptionAlertExpiredEnabled,
                (value) =>
                    setState(() => _subscriptionAlertExpiredEnabled = value),
                Icons.warning_amber_rounded,
              ),
              const SizedBox(height: 8),
              if (_subscriptionAlertRenewalEnabled) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.5),
                    border: Border.all(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.alarm_on,
                            color: AssyrianTheme.deepBlue,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'أيام التنبيه والتذكير قبل الانتهاء',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: AssyrianTheme.deepBlue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'حدد الأيام التي ترغب في إرسال تنبيهات فيها قبل تاريخ انتهاء الاشتراك',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [1, 2, 3, 5, 7, 14, 30].map((day) {
                          final selected = _warningDays.contains(day);
                          return FilterChip(
                            label: Text(
                              '$day ${day == 1 ? 'يوم' : (day == 2 ? 'يومان' : (day <= 10 ? 'أيام' : 'يوم'))}',
                            ),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  if (!_warningDays.contains(day)) {
                                    _warningDays.add(day);
                                    _warningDays.sort();
                                  }
                                } else {
                                  if (_warningDays.length > 1) {
                                    _warningDays.remove(day);
                                  }
                                }
                                if (_warningDays.isNotEmpty) {
                                  _reminderDaysBefore = _warningDays.last;
                                }
                              });
                            },
                            selectedColor: AssyrianTheme.primaryGold,
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AssyrianTheme.deepBlue,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 11.sp,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              side: BorderSide(
                                color: selected
                                    ? AssyrianTheme.primaryGold
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildTimeTile() {
    final timeString =
        '${_subscriptionDefaultHour.toString().padLeft(2, '0')}:${_subscriptionDefaultMinute.toString().padLeft(2, '0')}';

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
      child: Row(
        children: [
          Icon(Icons.access_time, color: AssyrianTheme.deepBlue, size: 20.sp),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وقت الاشتراك الافتراضي',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                Text(
                  'توقيت موحد لبداية ونهاية الاشتراك',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: _subscriptionDefaultHour,
                  minute: _subscriptionDefaultMinute,
                ),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AssyrianTheme.primaryGold,
                        onSurface: AssyrianTheme.deepBlue,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && mounted) {
                setState(() {
                  _subscriptionDefaultHour = picked.hour;
                  _subscriptionDefaultMinute = picked.minute;
                });
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              foregroundColor: AssyrianTheme.deepBlue,
            ),
            child: Text(
              timeString,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
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
                  'إعدادات الاشتراكات',
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
