import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../widgets/settings_drawer.dart';

/// صفحة إعدادات الإشعارات
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;
  String? _currentUserId;

  // إعدادات الإشعارات العامة
  bool _enableNotifications = true;
  bool _enablePushNotifications = false;
  bool _enableSound = true;
  bool _enableVibration = true;
  bool _enableSectionBadges = true;

  // تكرار التذكير الدوري لكل قسم (none, daily, weekly, monthly)
  final Map<String, String> _reminderFrequencies = {
    'customer_debt_reminder': 'daily',
    'subscription_reminder': 'daily',
    'invoice_overdue_reminder': 'daily',
    'maintenance_overdue_reminder': 'daily',
    'rental_expired_reminder': 'daily',
    'inventory_low_stock_reminder': 'daily',
    'expenses_pending_reminder': 'daily',
  };

  // خريطة مفاتيح الإشعارات التفصيلية لكل قسم (معطلة افتراضياً: false)
  final Map<String, bool> _notificationToggles = {
    // الفواتير
    'invoice_notify_new': false,
    'invoice_notify_paid': false,
    'invoice_notify_updated': false,
    'invoice_notify_deleted': false,
    'invoice_notify_cash': false,
    'invoice_alert_overdue': false,
    'invoice_alert_unpaid': false,
    // العملاء
    'customer_notify_new': false,
    'customer_notify_zero_balance': false,
    'customer_notify_updated': false,
    'customer_notify_deleted': false,
    'customer_notify_cash_invoice': false,
    'customer_alert_credit_limit': false,
    'customer_alert_high_debt': false,
    // المخزون
    'inventory_notify_new': false,
    'inventory_notify_deleted': false,
    'inventory_notify_quantity_update': false,
    'inventory_alert_out_of_stock': false,
    'inventory_alert_low_stock': false,
    // الاشتراكات
    'subscription_notify_new': false,
    'subscription_notify_updated': false,
    'subscription_notify_renewed': false,
    'subscription_notify_deleted': false,
    'subscription_alert_expired': false,
    'subscription_alert_expiring_soon': false,
    // الصيانة
    'maintenance_notify_new': false,
    'maintenance_notify_updated': false,
    'maintenance_notify_deleted': false,
    'maintenance_notify_completed': false,
    'maintenance_alert_urgent': false,
    'maintenance_alert_overdue': false,
    // التأجير
    'rental_notify_new': false,
    'rental_notify_updated': false,
    'rental_notify_deleted': false,
    'rental_notify_returned': false,
    'rental_alert_expired': false,
    'rental_alert_expiring_soon': false,
    // المصروفات
    'expenses_notify_new': false,
    'expenses_notify_updated': false,
    'expenses_notify_deleted': false,
    'expenses_alert_pending': false,
  };

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadSettings();
    _loadPermissions();
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

  Future<void> _loadSettings() async {
    try {
      if (_currentUserId == null) return;

      final settings = await SettingsService.getUserNotificationSettings(
        _currentUserId!,
      );

      if (mounted) {
        setState(() {
          _enableNotifications = settings['enableNotifications'] ?? true;
          _enablePushNotifications =
              settings['enablePushNotifications'] ?? false;
          _enableSound = settings['enableSound'] ?? true;
          _enableVibration = settings['enableVibration'] ?? true;
          _enableSectionBadges = settings['enableSectionBadges'] ?? true;

          // تحميل تكرار التذكير الدوري لكل قسم
          for (final key in _reminderFrequencies.keys) {
            _reminderFrequencies[key] =
                settings[key] as String? ?? _reminderFrequencies[key] ?? 'daily';
          }

          // تحميل حالة كل نوع إشعار مع احترام القيمة الافتراضية المحددة للخيار.
          for (final key in _notificationToggles.keys) {
            _notificationToggles[key] =
                settings[key] as bool? ?? _notificationToggles[key] ?? false;
          }
        });
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
      if (_currentUserId == null) return;

      final settings = <String, dynamic>{
        'enableNotifications': _enableNotifications,
        'enablePushNotifications': _enablePushNotifications,
        'enableSound': _enableSound,
        'enableVibration': _enableVibration,
        'enableSectionBadges': _enableSectionBadges,

        // حفظ تكرار التذكير الدوري لكل قسم
        for (final entry in _reminderFrequencies.entries)
          entry.key: entry.value,
      };

      // حفظ مفاتيح الإشعارات التفصيلية
      for (final entry in _notificationToggles.entries) {
        settings[entry.key] = entry.value;
      }

      await SettingsService.saveUserNotificationSettings(
        _currentUserId!,
        settings,
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
            content: Text('تم حفظ إعدادات الإشعارات بنجاح'),
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
      drawer: const SettingsDrawer(currentRoute: '/settings/notifications'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: _buildSettingsContent(context),
      floatingActionButton: _canManageSettings
          ? FloatingActionButton(
              heroTag: 'settings_notifications_save_fab',
              onPressed: _saveSettings,
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.save, size: 28.sp),
            )
          : null,
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadSettings,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Text(
                'إعدادات الإشعارات',
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
                  _buildSectionHeader('الإعدادات العامة'),
                  _buildGeneralSettings(),
                  const SizedBox(height: 16),
                  _buildDefaultDisabledNotice(),
                  const SizedBox(height: 16),
                  _buildSectionHeader('📄 إشعارات قسم الفواتير'),
                  _buildInvoiceNotificationSettings(),
                  const SizedBox(height: 16),
                  _buildSectionHeader('👤 إشعارات قسم العملاء والحسابات'),
                  _buildCustomerNotificationSettings(),
                  const SizedBox(height: 16),
                  _buildSectionHeader('📦 إشعارات قسم المخزون والمنتجات'),
                  _buildInventoryNotificationSettings(),
                  const SizedBox(height: 16),
                  _buildSectionHeader('💳 إشعارات قسم الاشتراكات'),
                  _buildSubscriptionNotificationSettings(),
                  const SizedBox(height: 16),
                  _buildSectionHeader('🛠️ إشعارات قسم الصيانة'),
                  _buildMaintenanceNotificationSettings(),
                  const SizedBox(height: 16),
                  _buildSectionHeader('🔑 إشعارات قسم التأجير'),
                  _buildRentalNotificationSettings(),
                  const SizedBox(height: 16),
                  _buildSectionHeader('💰 إشعارات قسم المصروفات'),
                  _buildExpenseNotificationSettings(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildDefaultDisabledNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[800], size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'جميع التنبيهات معطلة افتراضياً. قم بتفعيل أنواع الإشعارات التي ترغب في استلامها فقط.',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceNotificationSettings() {
    return _buildCategoryCard([
      _buildToggleTile(
        'إشعار إصدار فاتورة جديدة',
        'تنبيه فوري عند إنشاء فاتورة جديدة في النظام',
        'invoice_notify_new',
        Icons.receipt_long,
      ),
      _buildToggleTile(
        'إشعار سداد فاتورة بالكامل',
        'تنبيه فوري عند تسديد كامل المتبقي وتصفير الفاتورة',
        'invoice_notify_paid',
        Icons.check_circle_outline,
      ),
      _buildToggleTile(
        'إشعار حذف فاتورة',
        'تنبيه عند حذف فاتورة من المؤسسة',
        'invoice_notify_deleted',
        Icons.delete_outline,
      ),
      _buildToggleTile(
        'إشعار الفاتورة النقدية',
        'تنبيه عند تسجيل فاتورة نقدية',
        'invoice_notify_cash',
        Icons.payments_outlined,
      ),
      _buildToggleTile(
        'إشعار تعديل فاتورة',
        'تنبيه عند تعديل بيانات أو مبالغ فاتورة قائمة',
        'invoice_notify_updated',
        Icons.edit_note,
      ),
      _buildToggleTile(
        'تنبيه الفواتير المتأخرة',
        'تذكير دوري بالفواتير التي تجاوزت موعد الاستحقاق',
        'invoice_alert_overdue',
        Icons.timer_off_outlined,
      ),
      _buildToggleTile(
        'تنبيه الفواتير غير المسددة',
        'تذكير بالفواتير المستحقة بانتظار التحصيل',
        'invoice_alert_unpaid',
        Icons.pending_actions,
      ),
      _buildReminderFrequencyTile(
        'invoice_overdue_reminder',
        'تكرار تذكير الفواتير المتأخرة',
        'اختر مدة التذكير بالفواتير المتأخرة عن السداد',
      ),
    ]);
  }

  Widget _buildCustomerNotificationSettings() {
    return _buildCategoryCard([
      _buildToggleTile(
        'إشعار تسجيل عميل جديد',
        'تنبيه عند إضافة عميل جديد إلى قاعدة البيانات',
        'customer_notify_new',
        Icons.person_add_alt_1,
      ),
      _buildToggleTile(
        'إشعار الفواتير النقدية وتصفير الحساب',
        'تنبيه فوري عند استلام/صرف مبالغ نقدية أو تصفير ديون وحساب العميل',
        'customer_notify_cash_invoice',
        Icons.payments_outlined,
      ),
      _buildToggleTile(
        'إشعار تعديل بيانات عميل',
        'تنبيه عند تعديل معلومات أو رصيد العميل',
        'customer_notify_updated',
        Icons.manage_accounts,
      ),
      _buildToggleTile(
        'إشعار حذف عميل',
        'تنبيه عند حذف عميل من المؤسسة',
        'customer_notify_deleted',
        Icons.person_remove_alt_1,
      ),
      _buildToggleTile(
        'تنبيه تجاوز حد الائتمان',
        'تنبيه فوري عندما تتجاوز ديون العميل السقف المسموح',
        'customer_alert_credit_limit',
        Icons.warning_amber_rounded,
      ),
      _buildToggleTile(
        'تنبيه الديون المرتفعة',
        'تذكير دوري بالعملاء الذين لديهم ديون متراكمة',
        'customer_alert_high_debt',
        Icons.account_balance,
      ),
      _buildReminderFrequencyTile(
        'customer_debt_reminder',
        'تكرار تذكير ديون العملاء',
        'اختر مدة التذكير بالعملاء الذين لديهم ديون',
      ),
    ]);
  }

  Widget _buildInventoryNotificationSettings() {
    return _buildCategoryCard([
      _buildToggleTile(
        'إشعار إضافة مادة جديدة',
        'تنبيه عند إدخال منتج جديد إلى المخزون',
        'inventory_notify_new',
        Icons.add_box_outlined,
      ),
      _buildToggleTile(
        'إشعار حذف مادة',
        'تنبيه عند حذف مادة من المخزون',
        'inventory_notify_deleted',
        Icons.delete_outline,
      ),
      _buildToggleTile(
        'إشعار تحديث كمية مادة',
        'تنبيه عند تعديل كمية مادة في المخزون',
        'inventory_notify_quantity_update',
        Icons.inventory_2_outlined,
      ),
      _buildToggleTile(
        'تنبيه نفاد كمية مادة بالكامل',
        'تنبيه عاجل عند وصول كمية أي مادة إلى 0',
        'inventory_alert_out_of_stock',
        Icons.remove_shopping_cart,
      ),
      _buildToggleTile(
        'تنبيه المخزون المنخفض',
        'تنبيه عند انخفاض كمية المادة إلى الحد الأدنى المحدد',
        'inventory_alert_low_stock',
        Icons.production_quantity_limits,
      ),
      _buildReminderFrequencyTile(
        'inventory_low_stock_reminder',
        'تكرار تذكير المخزون المنخفض',
        'اختر مدة التذكير بالمواد منخفضة المخزون',
      ),
    ]);
  }

  Widget _buildSubscriptionNotificationSettings() {
    return _buildCategoryCard([
      _buildToggleTile(
        'إشعار تسجيل اشتراك جديد',
        'تنبيه عند إضافة اشتراك جديد لمشترك',
        'subscription_notify_new',
        Icons.card_membership,
      ),
      _buildToggleTile(
        'إشعار تعديل اشتراك',
        'تنبيه عند تعديل بيانات اشتراك',
        'subscription_notify_updated',
        Icons.edit,
      ),
      _buildToggleTile(
        'إشعار تجديد اشتراك',
        'تنبيه عند تجديد اشتراك',
        'subscription_notify_renewed',
        Icons.autorenew,
      ),
      _buildToggleTile(
        'إشعار حذف اشتراك',
        'تنبيه عند حذف اشتراك',
        'subscription_notify_deleted',
        Icons.delete_outline,
      ),
      _buildToggleTile(
        'تنبيه الاشتراكات المنتهية',
        'تنبيه عاجل بالاشتراكات التي انتهت صلاحيتها وتحتاج تجديد',
        'subscription_alert_expired',
        Icons.event_busy,
      ),
      _buildToggleTile(
        'تنبيه قرب انتهاء الاشتراك',
        'تنبيه استباقي قبل انتهاء الاشتراك بأيام',
        'subscription_alert_expiring_soon',
        Icons.notification_important,
      ),
      _buildReminderFrequencyTile(
        'subscription_reminder',
        'تكرار تذكير الاشتراكات',
        'اختر مدة التذكير بالاشتراكات المنتهية أو القريبة من الانتهاء',
      ),
    ]);
  }

  Widget _buildMaintenanceNotificationSettings() {
    return _buildCategoryCard([
      _buildToggleTile(
        'إشعار تسجيل طلب صيانة جديد',
        'تنبيه فوري عند استلام تذكرة صيانة جديدة',
        'maintenance_notify_new',
        Icons.build_circle_outlined,
      ),
      _buildToggleTile(
        'إشعار اكتمال الصيانة',
        'تنبيه عند انتهاء الصيانة وجاهزية الجهاز للتسليم',
        'maintenance_notify_completed',
        Icons.task_alt,
      ),
      _buildToggleTile(
        'إشعار تعديل طلب الصيانة',
        'تنبيه عند تعديل بيانات طلب صيانة',
        'maintenance_notify_updated',
        Icons.edit,
      ),
      _buildToggleTile(
        'إشعار حذف طلب الصيانة',
        'تنبيه عند حذف طلب صيانة',
        'maintenance_notify_deleted',
        Icons.delete_outline,
      ),
      _buildToggleTile(
        'تنبيه طلبات الصيانة العاجلة',
        'تنبيه بالطلبات ذات الأولوية القصوى',
        'maintenance_alert_urgent',
        Icons.priority_high,
      ),
      _buildToggleTile(
        'تنبيه طلبات الصيانة المتأخرة',
        'تنبيه بالطلبات التي تأخرت عن موعدها المجدول',
        'maintenance_alert_overdue',
        Icons.running_with_errors,
      ),
      _buildReminderFrequencyTile(
        'maintenance_overdue_reminder',
        'تكرار تذكير الصيانة المتأخرة',
        'اختر مدة التذكير بطلبات الصيانة المتأخرة',
      ),
    ]);
  }

  Widget _buildRentalNotificationSettings() {
    return _buildCategoryCard([
      _buildToggleTile(
        'إشعار عقد تأجير جديد',
        'تنبيه عند إبرام عقد تأجير جديد',
        'rental_notify_new',
        Icons.vpn_key_outlined,
      ),
      _buildToggleTile(
        'إشعار إرجاع التأجير',
        'تنبيه عند تأكيد إرجاع المواد المؤجرة بنجاح',
        'rental_notify_returned',
        Icons.assignment_turned_in,
      ),
      _buildToggleTile(
        'إشعار تعديل عقد تأجير',
        'تنبيه عند تعديل بيانات عقد التأجير',
        'rental_notify_updated',
        Icons.edit,
      ),
      _buildToggleTile(
        'إشعار حذف عقد تأجير',
        'تنبيه عند حذف عقد تأجير',
        'rental_notify_deleted',
        Icons.delete_outline,
      ),
      _buildToggleTile(
        'تنبيه عقود التأجير المتأخرة',
        'تنبيه بالعقود التي تجاوزت موعد الإرجاع المحدد',
        'rental_alert_expired',
        Icons.history_toggle_off,
      ),
      _buildToggleTile(
        'تنبيه قرب انتهاء عقد التأجير',
        'تنبيه استباقي قبل انتهاء العقد',
        'rental_alert_expiring_soon',
        Icons.access_time,
      ),
      _buildReminderFrequencyTile(
        'rental_expired_reminder',
        'تكرار تذكير التأجير المتأخر',
        'اختر مدة التذكير بعقود التأجير المتأخرة',
      ),
    ]);
  }

  Widget _buildExpenseNotificationSettings() {
    return _buildCategoryCard([
      _buildToggleTile(
        'إشعار تسجيل مصروف جديد',
        'تنبيه عند تسجيل سند صرف جديد في النظام',
        'expenses_notify_new',
        Icons.attach_money,
      ),
      _buildToggleTile(
        'إشعار تعديل مصروف',
        'تنبيه عند تعديل مصروف مسجل',
        'expenses_notify_updated',
        Icons.edit,
      ),
      _buildToggleTile(
        'إشعار حذف مصروف',
        'تنبيه عند حذف مصروف',
        'expenses_notify_deleted',
        Icons.delete_outline,
      ),
      _buildToggleTile(
        'تنبيه المصروفات المعلقة',
        'تنبيه بالمصروفات التي بانتظار المراجعة والاعتماد',
        'expenses_alert_pending',
        Icons.hourglass_top,
      ),
      _buildReminderFrequencyTile(
        'expenses_pending_reminder',
        'تكرار تذكير المصروفات المعلقة',
        'اختر مدة التذكير بالمصروفات بانتظار المراجعة',
      ),
    ]);
  }

  Widget _buildCategoryCard(List<Widget> children) {
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
          padding: const EdgeInsets.all(10),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    String title,
    String subtitle,
    String toggleKey,
    IconData icon,
  ) {
    final isChecked = _notificationToggles[toggleKey] ?? false;
    return _buildSwitchTile(
      title,
      subtitle,
      isChecked,
      (value) => setState(() => _notificationToggles[toggleKey] = value),
      icon,
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
                'تفعيل الإشعارات العامة',
                'المفتاح الرئيسي لجميع إشعارات التطبيق',
                _enableNotifications,
                (value) => setState(() => _enableNotifications = value),
                Icons.notifications_active,
              ),
              _buildSwitchTile(
                'إشعارات المستخدمين الآخرين (Push)',
                'إرسال إشعارات إلى أجهزة بقية مستخدمي المؤسسة',
                _enablePushNotifications,
                (value) => setState(() => _enablePushNotifications = value),
                Icons.send,
              ),
              _buildSwitchTile(
                'صوت التنبيهات',
                'تشغيل صوت عند وصول أي إشعار مفعل',
                _enableSound,
                (value) => setState(() => _enableSound = value),
                Icons.volume_up,
              ),
              _buildSwitchTile(
                'اهتزاز التنبيهات',
                'اهتزاز الجهاز عند وصول إشعار',
                _enableVibration,
                (value) => setState(() => _enableVibration = value),
                Icons.vibration,
              ),
              _buildSwitchTile(
                'شريط التنبيهات العلوي في الأقسام',
                'إظهار بطاقة التنبيهات العاجلة أعلى صفحات القوائم',
                _enableSectionBadges,
                (value) => setState(() => _enableSectionBadges = value),
                Icons.flag_rounded,
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

  Widget _buildReminderFrequencyTile(String sectionKey, String title, String subtitle) {
    final current = _reminderFrequencies[sectionKey] ?? 'daily';
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
        onChanged: (val) => setState(() => _reminderFrequencies[sectionKey] = val ?? 'daily'),
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
                  'إعدادات الإشعارات',
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
