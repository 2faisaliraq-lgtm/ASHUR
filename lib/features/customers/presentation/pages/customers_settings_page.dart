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

/// صفحة إعدادات قسم العملاء
class CustomersSettingsPage extends StatefulWidget {
  const CustomersSettingsPage({super.key});

  @override
  State<CustomersSettingsPage> createState() => _CustomersSettingsPageState();
}

class _CustomersSettingsPageState extends State<CustomersSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // إعدادات العملاء العامة
  bool _allowCustomerRegistration = true;
  bool _requireEmailVerification = true;
  bool _enableCustomerNotifications = false;
  bool _allowCustomerProfileEdit = true;
  bool _enableCustomerRating = true;
  bool _requirePhoneVerification = false;

  // إعدادات المجموعات والتصنيفات
  bool _enableCustomerGroups = true;
  bool _allowMultipleGroups = false;
  bool _enableGroupDiscounts = true;
  bool _enableLoyaltyProgram = true;
  int _loyaltyPointsPerPurchase = 10;
  double _loyaltyRedemptionRate = 0.01;

  // إعدادات الائتمان والدفع
  bool _enableCreditLimit = true;
  double _defaultCreditLimit = 5000;
  int _creditTermDays = 30;
  bool _enablePaymentReminders = true;
  int _reminderDaysBefore = 3;
  bool _blockOverdueCustomers = false;

  // إعدادات التواصل
  bool _enableSMSNotifications = true;
  bool _enableEmailNotifications = true;
  bool _enableWhatsAppNotifications = true;
  bool _sendBirthdayGreetings = true;
  bool _sendPromotionalOffers = true;
  int _maxPromotionsPerMonth = 4;

  // إشعارات وتنبيهات قسم العملاء (معطلة افتراضياً: false)
  bool _notifyNewCustomer = false;
  bool _notifyCashInvoiceAndClearance = false;
  bool _notifyCustomerUpdated = false;
  bool _alertCreditLimit = false;
  bool _alertHighDebt = false;

  // تكرار تذكير ديون العملاء (يومي، أسبوعي، شهري، لا شيء)
  String _customerDebtReminderFrequency = 'daily';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canManageSettings = await _permissionChecker.hasPermission(
      'customers_settings_manage',
    );

    if (mounted) {
      setState(() {
        _canManageSettings = canManageSettings;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getCustomerSettings();
      setState(() {
        _allowCustomerRegistration =
            settings['allowCustomerRegistration'] ?? true;
        _requireEmailVerification =
            settings['requireEmailVerification'] ?? true;
        _enableCustomerNotifications =
            settings['enableCustomerNotifications'] ?? false;
        _allowCustomerProfileEdit =
            settings['allowCustomerProfileEdit'] ?? true;
        _enableCustomerRating = settings['enableCustomerRating'] ?? true;
        _requirePhoneVerification =
            settings['requirePhoneVerification'] ?? false;
        _enableCustomerGroups = settings['enableCustomerGroups'] ?? true;
        _allowMultipleGroups = settings['allowMultipleGroups'] ?? false;
        _enableGroupDiscounts = settings['enableGroupDiscounts'] ?? true;
        _enableLoyaltyProgram = settings['enableLoyaltyProgram'] ?? true;
        _loyaltyPointsPerPurchase = settings['loyaltyPointsPerPurchase'] ?? 10;
        _loyaltyRedemptionRate = settings['loyaltyRedemptionRate'] ?? 0.01;
        _enableCreditLimit = settings['enableCreditLimit'] ?? true;
        _defaultCreditLimit = settings['defaultCreditLimit'] ?? 5000.0;
        _creditTermDays = settings['creditTermDays'] ?? 30;
        _enablePaymentReminders = settings['enablePaymentReminders'] ?? true;
        _reminderDaysBefore = settings['reminderDaysBefore'] ?? 3;
        _blockOverdueCustomers = settings['blockOverdueCustomers'] ?? false;
        _enableSMSNotifications = settings['enableSMSNotifications'] ?? true;
        _enableEmailNotifications =
            settings['enableEmailNotifications'] ?? true;
        _enableWhatsAppNotifications =
            settings['enableWhatsAppNotifications'] ?? true;
        _sendBirthdayGreetings = settings['sendBirthdayGreetings'] ?? true;
        _sendPromotionalOffers = settings['sendPromotionalOffers'] ?? true;
        _maxPromotionsPerMonth = settings['maxPromotionsPerMonth'] ?? 4;
      });

      // تحميل إعدادات الإشعارات المخصصة من إعدادات المستخدم الشخصية (معطلة افتراضياً: false)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(uid);
        if (mounted) {
          setState(() {
            _notifyNewCustomer = userSettings['customer_notify_new'] as bool? ?? false;
            _notifyCashInvoiceAndClearance =
                (userSettings['customer_notify_cash_invoice'] as bool? ?? false) ||
                (userSettings['customer_notify_zero_balance'] as bool? ?? false);
            _notifyCustomerUpdated = userSettings['customer_notify_updated'] as bool? ?? false;
            _alertCreditLimit = userSettings['customer_alert_credit_limit'] as bool? ?? false;
            _alertHighDebt = userSettings['customer_alert_high_debt'] as bool? ?? false;

            // تحميل تكرار تذكير ديون العملاء
            _customerDebtReminderFrequency =
                userSettings['customer_debt_reminder'] as String? ?? 'daily';

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
        'allowCustomerRegistration': _allowCustomerRegistration,
        'requireEmailVerification': _requireEmailVerification,
        'enableCustomerNotifications': _enableCustomerNotifications,
        'allowCustomerProfileEdit': _allowCustomerProfileEdit,
        'enableCustomerRating': _enableCustomerRating,
        'requirePhoneVerification': _requirePhoneVerification,
        'enableCustomerGroups': _enableCustomerGroups,
        'allowMultipleGroups': _allowMultipleGroups,
        'enableGroupDiscounts': _enableGroupDiscounts,
        'enableLoyaltyProgram': _enableLoyaltyProgram,
        'loyaltyPointsPerPurchase': _loyaltyPointsPerPurchase,
        'loyaltyRedemptionRate': _loyaltyRedemptionRate,
        'enableCreditLimit': _enableCreditLimit,
        'defaultCreditLimit': _defaultCreditLimit,
        'creditTermDays': _creditTermDays,
        'enablePaymentReminders': _enablePaymentReminders,
        'reminderDaysBefore': _reminderDaysBefore,
        'blockOverdueCustomers': _blockOverdueCustomers,
        'enableSMSNotifications': _enableSMSNotifications,
        'enableEmailNotifications': _enableEmailNotifications,
        'enableWhatsAppNotifications': _enableWhatsAppNotifications,
        'sendBirthdayGreetings': _sendBirthdayGreetings,
        'sendPromotionalOffers': _sendPromotionalOffers,
        'maxPromotionsPerMonth': _maxPromotionsPerMonth,
      };

      await SettingsService.saveCustomerSettings(settings);

      // حفظ تفضيلات إشعارات قسم العملاء
      // ✅ ملاحظة للمبرمجين المستقبليين: _notifyCashInvoiceAndClearance هو خيار واحد
      // في واجهة المستخدم يمثل إشعارين (الفاتورة النقدية وصفير الحساب). يتم حفظ
      // القيمة نفسها في مفتاحين للحفاظ على التوافق مع التحميل الذي يقوم بعملية OR
      // بين المفتاحين (السطر 152). لا يُفصل بينهما في الواجهة الحالية.
      await SettingsService.setNotificationTypeEnabled(
        'customer_notify_new',
        _notifyNewCustomer,
      );
      await SettingsService.setNotificationTypeEnabled(
        'customer_notify_cash_invoice',
        _notifyCashInvoiceAndClearance,
      );
      await SettingsService.setNotificationTypeEnabled(
        'invoice_notify_cash',
        _notifyCashInvoiceAndClearance,
      );
      await SettingsService.setNotificationTypeEnabled(
        'customer_notify_zero_balance',
        _notifyCashInvoiceAndClearance,
      );
      await SettingsService.setNotificationTypeEnabled(
        'customer_notify_updated',
        _notifyCustomerUpdated,
      );
      await SettingsService.setNotificationTypeEnabled(
        'customer_alert_credit_limit',
        _alertCreditLimit,
      );
      await SettingsService.setNotificationTypeEnabled(
        'customer_alert_high_debt',
        _alertHighDebt,
      );

      // حفظ تكرار تذكير ديون العملاء في الإعدادات الشخصية
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await SettingsService.saveUserNotificationSettings(uid, {
          'customer_debt_reminder': _customerDebtReminderFrequency,
        });
      }

      // ✅ حفظ أيام التنبيه والتذكير في الإعدادات الشخصية لكل مستخدم

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
                'إعدادات العملاء',
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
              heroTag: 'customers_settings_save_fab',
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
              moduleId: 'customers_view',
              moduleName: 'قسم العملاء',
              moduleIcon: Icons.person,
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
                'إعدادات العملاء',
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
                  _buildSectionHeader('الإعدادات العامة للعملاء'),
                  _buildGeneralSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('المجموعات وبرنامج الولاء'),
                  _buildGroupsAndLoyaltySettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('الائتمان والدفع'),
                  _buildCreditAndPaymentSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إشعارات وتنبيهات قسم العملاء'),
                  _buildCustomerNotificationSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات التواصل'),
                  _buildCommunicationSettings(),
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
      _allowCustomerRegistration = true;
      _requireEmailVerification = true;
      _enableCustomerNotifications = true;
      _allowCustomerProfileEdit = true;
      _enableCustomerRating = true;
      _requirePhoneVerification = false;
      _enableCustomerGroups = true;
      _allowMultipleGroups = false;
      _enableGroupDiscounts = true;
      _enableLoyaltyProgram = true;
      _loyaltyPointsPerPurchase = 10;
      _loyaltyRedemptionRate = 0.01;
      _enableCreditLimit = true;
      _defaultCreditLimit = 5000.0;
      _creditTermDays = 30;
      _enablePaymentReminders = true;
      _reminderDaysBefore = 3;
      _blockOverdueCustomers = false;
      _enableSMSNotifications = true;
      _enableEmailNotifications = true;
      _enableWhatsAppNotifications = false;
      _sendBirthdayGreetings = true;
      _sendPromotionalOffers = true;
      _maxPromotionsPerMonth = 4;
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
                'السماح بتسجيل العملاء الجدد',
                'يمكن للعملاء الجدد إنشاء حسابات',
                _allowCustomerRegistration,
                (value) => setState(() => _allowCustomerRegistration = value),
                Icons.person_add,
              ),
              _buildSwitchTile(
                'تطلب تأكيد البريد الإلكتروني',
                'يجب على العملاء تأكيد بريدهم الإلكتروني',
                _requireEmailVerification,
                (value) => setState(() => _requireEmailVerification = value),
                Icons.email_outlined,
              ),
              _buildSwitchTile(
                'تفعيل إشعارات العملاء',
                'إرسال إشعارات للعملاء',
                _enableCustomerNotifications,
                (value) => setState(() => _enableCustomerNotifications = value),
                Icons.notifications,
              ),
              _buildSwitchTile(
                'السماح بتعديل الملف الشخصي',
                'يمكن للعملاء تعديل بياناتهم الشخصية',
                _allowCustomerProfileEdit,
                (value) => setState(() => _allowCustomerProfileEdit = value),
                Icons.edit,
              ),
              _buildSwitchTile(
                'تفعيل تقييم العملاء',
                'يمكن للعملاء تقييم المنتجات والخدمات',
                _enableCustomerRating,
                (value) => setState(() => _enableCustomerRating = value),
                Icons.star_rate,
              ),
              _buildSwitchTile(
                'تطلب تأكيد رقم الهاتف',
                'يجب على العملاء تأكيد رقم هاتفهم',
                _requirePhoneVerification,
                (value) => setState(() => _requirePhoneVerification = value),
                Icons.phone_android,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsAndLoyaltySettings() {
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
                'تفعيل مجموعات العملاء',
                'تصنيف العملاء في مجموعات مختلفة',
                _enableCustomerGroups,
                (value) => setState(() => _enableCustomerGroups = value),
                Icons.group,
              ),
              _buildSwitchTile(
                'السماح بالانتماء لمجموعات متعددة',
                'يمكن للعميل الانتماء لأكثر من مجموعة',
                _allowMultipleGroups,
                (value) => setState(() => _allowMultipleGroups = value),
                Icons.groups,
              ),
              _buildSwitchTile(
                'تفعيل خصومات المجموعات',
                'خصومات خاصة لكل مجموعة عملاء',
                _enableGroupDiscounts,
                (value) => setState(() => _enableGroupDiscounts = value),
                Icons.discount,
              ),
              _buildSwitchTile(
                'تفعيل برنامج الولاء',
                'نقاط ومكافآت للعملاء المميزين',
                _enableLoyaltyProgram,
                (value) => setState(() => _enableLoyaltyProgram = value),
                Icons.loyalty,
              ),
              _buildSliderTile(
                'نقاط الولاء لكل عملية شراء',
                'عدد النقاط التي يحصل عليها العميل',
                _loyaltyPointsPerPurchase.toDouble(),
                1,
                100,
                (value) =>
                    setState(() => _loyaltyPointsPerPurchase = value.round()),
                Icons.star,
              ),
              _buildSliderTile(
                'معدل استبدال نقاط الولاء',
                'قيمة النقطة الواحدة بالعملة المحلية',
                _loyaltyRedemptionRate * 100,
                0.1,
                10,
                (value) => setState(() => _loyaltyRedemptionRate = value / 100),
                Icons.currency_exchange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditAndPaymentSettings() {
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
                'تفعيل حد الائتمان',
                'تحديد حد أقصى للائتمان لكل عميل',
                _enableCreditLimit,
                (value) => setState(() => _enableCreditLimit = value),
                Icons.credit_card,
              ),
              _buildSliderTile(
                'حد الائتمان الافتراضي',
                'الحد الأقصى للائتمان للعملاء الجدد',
                _defaultCreditLimit,
                1000,
                50000,
                (value) => setState(() => _defaultCreditLimit = value),
                Icons.account_balance,
              ),
              _buildSliderTile(
                'مدة الائتمان (أيام)',
                'عدد الأيام المسموحة للسداد',
                _creditTermDays.toDouble(),
                7,
                90,
                (value) => setState(() => _creditTermDays = value.round()),
                Icons.schedule,
              ),
              _buildSwitchTile(
                'تفعيل تذكيرات الدفع',
                'إرسال تذكيرات قبل موعد الاستحقاق',
                _enablePaymentReminders,
                (value) => setState(() => _enablePaymentReminders = value),
                Icons.notification_important,
              ),
              _buildSliderTile(
                'أيام التذكير قبل الاستحقاق',
                'عدد الأيام قبل إرسال التذكير',
                _reminderDaysBefore.toDouble(),
                1,
                14,
                (value) => setState(() => _reminderDaysBefore = value.round()),
                Icons.alarm,
              ),
              _buildSwitchTile(
                'حظر العملاء المتأخرين',
                'منع التعامل مع العملاء المتأخرين في السداد',
                _blockOverdueCustomers,
                (value) => setState(() => _blockOverdueCustomers = value),
                Icons.block,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerNotificationSettings() {
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
                'إشعار تسجيل عميل جديد',
                'تنبيه عند إضافة عميل جديد إلى قاعدة البيانات',
                _notifyNewCustomer,
                (value) => setState(() => _notifyNewCustomer = value),
                Icons.person_add_alt_1,
              ),
              _buildSwitchTile(
                'إشعار الفواتير النقدية وتصفير الحساب',
                'تنبيه فوري عند استلام/صرف مبالغ نقدية أو تصفير ديون وحساب العميل',
                _notifyCashInvoiceAndClearance,
                (value) =>
                    setState(() => _notifyCashInvoiceAndClearance = value),
                Icons.payments_outlined,
              ),
              _buildSwitchTile(
                'إشعار تعديل بيانات عميل',
                'تنبيه عند تعديل معلومات أو رصيد العميل',
                _notifyCustomerUpdated,
                (value) => setState(() => _notifyCustomerUpdated = value),
                Icons.manage_accounts,
              ),
              _buildSwitchTile(
                'تنبيه تجاوز حد الائتمان',
                'تنبيه فوري عندما تتجاوز ديون العميل السقف المسموح',
                _alertCreditLimit,
                (value) => setState(() => _alertCreditLimit = value),
                Icons.warning_amber_rounded,
              ),
              _buildSwitchTile(
                'تنبيه الديون المرتفعة',
                'تذكير دوري بالعملاء الذين لديهم ديون متراكمة',
                _alertHighDebt,
                (value) => setState(() => _alertHighDebt = value),
                Icons.account_balance,
              ),
              _buildReminderFrequencyTile(
                'customer_debt_reminder',
                'تكرار تذكير ديون العملاء',
                'اختر مدة التذكير بالعملاء الذين لديهم ديون',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommunicationSettings() {
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
                'تفعيل إشعارات الرسائل النصية',
                'إرسال إشعارات عبر الرسائل النصية',
                _enableSMSNotifications,
                (value) => setState(() => _enableSMSNotifications = value),
                Icons.sms,
              ),
              _buildSwitchTile(
                'تفعيل إشعارات البريد الإلكتروني',
                'إرسال إشعارات عبر البريد الإلكتروني',
                _enableEmailNotifications,
                (value) => setState(() => _enableEmailNotifications = value),
                Icons.email,
              ),
              _buildSwitchTile(
                'تفعيل إشعارات الواتساب',
                'إرسال إشعارات عبر الواتساب',
                _enableWhatsAppNotifications,
                (value) => setState(() => _enableWhatsAppNotifications = value),
                Icons.chat,
              ),
              _buildSwitchTile(
                'إرسال تهاني أعياد الميلاد',
                'تهنئة العملاء في أعياد ميلادهم',
                _sendBirthdayGreetings,
                (value) => setState(() => _sendBirthdayGreetings = value),
                Icons.cake,
              ),
              _buildSwitchTile(
                'إرسال العروض الترويجية',
                'إرسال عروض وخصومات للعملاء',
                _sendPromotionalOffers,
                (value) => setState(() => _sendPromotionalOffers = value),
                Icons.local_offer,
              ),
              _buildSliderTile(
                'الحد الأقصى للعروض الشهرية',
                'عدد العروض المرسلة لكل عميل شهرياً',
                _maxPromotionsPerMonth.toDouble(),
                1,
                20,
                (value) =>
                    setState(() => _maxPromotionsPerMonth = value.round()),
                Icons.campaign,
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
                  'إعدادات العملاء',
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

  Widget _buildReminderFrequencyTile(String sectionKey, String title, String subtitle) {
    final current = _customerDebtReminderFrequency;
    final items = const [
      {'label': 'يومياً', 'value': 'daily'},
      {'label': 'أسبوعياً', 'value': 'weekly'},
      {'label': 'شهراً', 'value': 'monthly'},
      {'label': 'لا شيء', 'value': 'none'},
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.5),
        border: Border.all(color: AssyrianTheme.primaryGold.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: current,
        decoration: InputDecoration(
          labelText: title,
          hintText: subtitle,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
        items: items.map((e) => DropdownMenuItem<String>(
          value: e['value'],
          child: Text(e['label'] as String, style: const TextStyle(fontSize: 13)),
        )).toList(),
        onChanged: (val) => setState(() => _customerDebtReminderFrequency = val ?? 'daily'),
      ),
    );
  }
}
