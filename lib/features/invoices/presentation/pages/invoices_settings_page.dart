import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/module_enable_toggle.dart';

/// صفحة إعدادات قسم الفواتير
class InvoicesSettingsPage extends StatefulWidget {
  const InvoicesSettingsPage({super.key});

  @override
  State<InvoicesSettingsPage> createState() => _InvoicesSettingsPageState();
}

class _InvoicesSettingsPageState extends State<InvoicesSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  bool _isSaving = false;

  //✅ تم الإصلاح: TextEditingController مخزّن على مستوى State بدلاً من إنشائه داخل build
  // لتجنب فقدان حالة الحقل والنص المكتوب من المستخدم عند كل إعادة بناء.
  final TextEditingController _invoicePrefixController = TextEditingController();

  // إعدادات الفواتير العامة
  bool _enableAutoNumbering = true;
  int _reminderDaysBefore = 7;
  List<int> _invoiceWarningDays = [1, 2, 3];
  String _invoicePrefix = 'INV';
  int _startingNumber = 1000;
  bool _allowPartialPayments = true;

  // إعدادات الضرائب والرسوم
  bool _enableTaxCalculation = true;
  double _defaultTaxRate = 15;
  bool _enableMultipleTaxRates = false;
  bool _includeTaxInPrice = false;
  bool _enableServiceCharges = false;
  double _defaultServiceCharge = 0;

  // إعدادات الخصومات والعروض
  bool _enableDiscounts = true;
  double _maxDiscountPercentage = 50;
  bool _requireDiscountApproval = true;
  bool _enableCoupons = true;
  bool _enableBulkDiscounts = true;
  int _bulkDiscountMinQuantity = 10;

  // إعدادات الطباعة والإرسال
  bool _enableAutoPrint = false;
  bool _enableEmailInvoices = true;
  bool _enableSMSNotifications = true;
  String _defaultPaperSize = 'A4';
  bool _includeCompanyLogo = true;
  bool _showPaymentInstructions = true;

  // إعدادات العملات والدفع
  String _defaultCurrency = 'IQD';
  bool _enableMultipleCurrencies = false;
  bool _enableCreditCardPayments = true;
  bool _enableBankTransfers = true;
  bool _enableCashPayments = true;
  bool _enableDigitalWallets = false;

  // إشعارات وتنبيهات قسم الفواتير (معطلة افتراضياً: false)
  bool _notifyNewInvoice = false;
  bool _notifyPaidInvoice = false;
  bool _notifyUpdatedInvoice = false;
  bool _alertOverdueInvoice = false;
  bool _alertUnpaidInvoice = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getInvoiceSettings();
      _invoicePrefix = settings['invoicePrefix'] ?? 'INV';
      // ✅ تم الإصلاح: تهيئة الـ Controller بالقيمة المحمولة بدلاً من إنشاء جديد في كل build
      _invoicePrefixController.text = _invoicePrefix;
      setState(() {
        _enableAutoNumbering = settings['enableAutoNumbering'] ?? true;
        _invoicePrefix = settings['invoicePrefix'] ?? 'INV';
        _startingNumber = settings['startingNumber'] ?? 1000;
        _allowPartialPayments = settings['allowPartialPayments'] ?? true;
        _enableTaxCalculation = settings['enableTaxCalculation'] ?? true;
        _defaultTaxRate = settings['defaultTaxRate'] ?? 15.0;
        _enableMultipleTaxRates = settings['enableMultipleTaxRates'] ?? false;
        _includeTaxInPrice = settings['includeTaxInPrice'] ?? false;
        _enableServiceCharges = settings['enableServiceCharges'] ?? false;
        _defaultServiceCharge = settings['defaultServiceCharge'] ?? 0.0;
        _enableDiscounts = settings['enableDiscounts'] ?? true;
        _maxDiscountPercentage = settings['maxDiscountPercentage'] ?? 50.0;
        _requireDiscountApproval = settings['requireDiscountApproval'] ?? true;
        _enableCoupons = settings['enableCoupons'] ?? true;
        _enableBulkDiscounts = settings['enableBulkDiscounts'] ?? true;
        _bulkDiscountMinQuantity = settings['bulkDiscountMinQuantity'] ?? 10;
        _enableAutoPrint = settings['enableAutoPrint'] ?? false;
        _enableEmailInvoices = settings['enableEmailInvoices'] ?? true;
        _enableSMSNotifications = settings['enableSMSNotifications'] ?? true;
        _defaultPaperSize = settings['defaultPaperSize'] ?? 'A4';
        _includeCompanyLogo = settings['includeCompanyLogo'] ?? true;
        _showPaymentInstructions = settings['showPaymentInstructions'] ?? true;
        _defaultCurrency = settings['defaultCurrency'] ?? 'IQD';
        _enableMultipleCurrencies =
            settings['enableMultipleCurrencies'] ?? false;
        _enableCreditCardPayments =
            settings['enableCreditCardPayments'] ?? true;
        _enableBankTransfers = settings['enableBankTransfers'] ?? true;
        _enableCashPayments = settings['enableCashPayments'] ?? true;
        _enableDigitalWallets = settings['enableDigitalWallets'] ?? false;
      });

      // تحميل إعدادات إشعارات الفواتير من إعدادات المستخدم الشخصية (معطلة افتراضياً: false)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(uid);
        if (mounted) {
          setState(() {
            _notifyNewInvoice = userSettings['invoice_notify_new'] as bool? ?? false;
            _notifyPaidInvoice = userSettings['invoice_notify_paid'] as bool? ?? false;
            _notifyUpdatedInvoice = userSettings['invoice_notify_updated'] as bool? ?? false;
            _alertOverdueInvoice = userSettings['invoice_alert_overdue'] as bool? ?? false;
            _alertUnpaidInvoice = userSettings['invoice_alert_unpaid'] as bool? ?? false;

            // ✅ قراءة reminderDaysBefore من الإعدادات الشخصية إذا كانت موجودة
            final personalReminderDays =
                userSettings['reminderDaysBefore'] as int?;
            if (personalReminderDays != null) {
              _reminderDaysBefore = personalReminderDays;
            }

            // ✅ قراءة warningDays من الإعدادات الشخصية إذا كانت موجودة
            final personalWarningDays = userSettings['warningDays'] as List<dynamic>?;
            if (personalWarningDays != null && personalWarningDays.isNotEmpty) {
              _invoiceWarningDays =
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
        'enableAutoNumbering': _enableAutoNumbering,
        'invoicePrefix': _invoicePrefix,
        'startingNumber': _startingNumber,
        'allowPartialPayments': _allowPartialPayments,
        'enableTaxCalculation': _enableTaxCalculation,
        'defaultTaxRate': _defaultTaxRate,
        'enableMultipleTaxRates': _enableMultipleTaxRates,
        'includeTaxInPrice': _includeTaxInPrice,
        'enableServiceCharges': _enableServiceCharges,
        'defaultServiceCharge': _defaultServiceCharge,
        'enableDiscounts': _enableDiscounts,
        'maxDiscountPercentage': _maxDiscountPercentage,
        'requireDiscountApproval': _requireDiscountApproval,
        'enableCoupons': _enableCoupons,
        'enableBulkDiscounts': _enableBulkDiscounts,
        'bulkDiscountMinQuantity': _bulkDiscountMinQuantity,
        'enableAutoPrint': _enableAutoPrint,
        'enableEmailInvoices': _enableEmailInvoices,
        'enableSMSNotifications': _enableSMSNotifications,
        'defaultPaperSize': _defaultPaperSize,
        'includeCompanyLogo': _includeCompanyLogo,
        'showPaymentInstructions': _showPaymentInstructions,
        'defaultCurrency': _defaultCurrency,
        'enableMultipleCurrencies': _enableMultipleCurrencies,
        'enableCreditCardPayments': _enableCreditCardPayments,
        'enableBankTransfers': _enableBankTransfers,
        'enableCashPayments': _enableCashPayments,
        'enableDigitalWallets': _enableDigitalWallets,
      };

      await SettingsService.saveInvoiceSettings(settings);

      // حفظ تفضيلات إشعارات الفواتير
      await SettingsService.setNotificationTypeEnabled(
        'invoice_notify_new',
        _notifyNewInvoice,
      );
      await SettingsService.setNotificationTypeEnabled(
        'invoice_notify_paid',
        _notifyPaidInvoice,
      );
      await SettingsService.setNotificationTypeEnabled(
        'invoice_notify_updated',
        _notifyUpdatedInvoice,
      );
      await SettingsService.setNotificationTypeEnabled(
        'invoice_alert_overdue',
        _alertOverdueInvoice,
      );
      await SettingsService.setNotificationTypeEnabled(
        'invoice_alert_unpaid',
        _alertUnpaidInvoice,
      );

      // ✅ حفظ أيام التنبيه والتذكير في الإعدادات الشخصية لكل مستخدم
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await SettingsService.saveUserNotificationSettings(uid, {
          'reminderDaysBefore': _reminderDaysBefore,
          'warningDays': _invoiceWarningDays,
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
    _invoicePrefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: AssyrianTheme.backgroundGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AssyrianTheme.getLamassuForBackground(
                    isDarkBackground: true,
                    hasCircularBackground: false,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'إعدادات الفواتير',
                    style: TextStyle(
                      color: AssyrianTheme.primaryGold,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'نظام إدارة المتاجر الآشوري',
                    style: TextStyle(
                      color: AssyrianTheme.ivoryWhite,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.settings,
                color: AssyrianTheme.deepBlue,
              ),
              title: const Text('الإعدادات العامة'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: _buildSettingsContent(context),
      floatingActionButton: FloatingActionButton(
        heroTag: 'invoices_settings_save_fab',
        onPressed: _saveSettings,
        backgroundColor: AssyrianTheme.primaryGold,
        foregroundColor: AssyrianTheme.deepBlue,
        child: Icon(Icons.save, size: 28.sp),
      ),
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
              moduleId: 'invoices_sales_manage',
              moduleName: 'قسم الفواتير',
              moduleIcon: Icons.receipt_long,
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
                'إعدادات الفواتير',
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
                  // بطاقة إعدادات PDF المركزية
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          Colors.blue[50]!,
                          Colors.blue[100]!.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.pdfSettings);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.blue[700],
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'إعدادات PDF العامة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.sp,
                                        color: AssyrianTheme.deepBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'معلومات الشركة وإعدادات التوليد التلقائي',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.blue[700],
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildSectionHeader('الإعدادات العامة للفواتير'),
                  _buildGeneralSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('الضرائب والرسوم'),
                  _buildTaxSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('الخصومات والعروض'),
                  _buildDiscountSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('الطباعة والإرسال'),
                  _buildPrintingSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إشعارات وتنبيهات قسم الفواتير'),
                  _buildInvoiceNotificationSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('العملات وطرق الدفع'),
                  _buildPaymentSettings(),
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
      child: Column(
        children: [
          Row(
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
          SizedBox(height: 12.h),
          // زر إدارة قوالب الفواتير
          ListTile(
            leading: const Icon(
              Icons.description_outlined,
              color: AssyrianTheme.primaryGold,
            ),
            title: Text(
              'قوالب الفواتير',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AssyrianTheme.deepBlue,
              ),
            ),
            subtitle: Text(
              'إدارة تصاميم الفواتير',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: AssyrianTheme.primaryGold,
            ),
            onTap: () => _navigateToTemplates(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            tileColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  /// الانتقال إلى صفحة قوالب الفواتير
  void _navigateToTemplates(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.invoiceTemplates);
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

  /// ✅ تم الإصلاح: إعادة تعيين الإعدادات الافتراضية وحفظها في SettingsService
  /// بدلاً من إعادة تعيين الحالة المحلية فقط، حتى تستمر الإعدادات بعد إعادة فتح الصفحة.
  Future<void> _resetToDefaults() async {
    setState(() {
      _enableAutoNumbering = true;
      _invoicePrefix = 'INV';
      _invoicePrefixController.text = 'INV';
      _startingNumber = 1000;
      _allowPartialPayments = true;
      _enableTaxCalculation = true;
      _defaultTaxRate = 15.0;
      _enableMultipleTaxRates = false;
      _includeTaxInPrice = false;
      _enableServiceCharges = false;
      _defaultServiceCharge = 0.0;
      _enableDiscounts = true;
      _maxDiscountPercentage = 50.0;
      _requireDiscountApproval = true;
      _enableCoupons = true;
      _enableBulkDiscounts = true;
      _bulkDiscountMinQuantity = 10;
      _enableAutoPrint = false;
      _enableEmailInvoices = true;
      _enableSMSNotifications = true;
      _defaultPaperSize = 'A4';
      _includeCompanyLogo = true;
      _showPaymentInstructions = true;
      _defaultCurrency = 'IQD';
      _enableMultipleCurrencies = false;
      _enableCreditCardPayments = true;
      _enableBankTransfers = true;
      _enableCashPayments = true;
      _enableDigitalWallets = false;
    });

    // حفظ الإعدادات الافتراضية في التخزين الدائم
    final settings = {
      'enableAutoNumbering': _enableAutoNumbering,
      'invoicePrefix': _invoicePrefix,
      'startingNumber': _startingNumber,
      'allowPartialPayments': _allowPartialPayments,
      'enableTaxCalculation': _enableTaxCalculation,
      'defaultTaxRate': _defaultTaxRate,
      'enableMultipleTaxRates': _enableMultipleTaxRates,
      'includeTaxInPrice': _includeTaxInPrice,
      'enableServiceCharges': _enableServiceCharges,
      'defaultServiceCharge': _defaultServiceCharge,
      'enableDiscounts': _enableDiscounts,
      'maxDiscountPercentage': _maxDiscountPercentage,
      'requireDiscountApproval': _requireDiscountApproval,
      'enableCoupons': _enableCoupons,
      'enableBulkDiscounts': _enableBulkDiscounts,
      'bulkDiscountMinQuantity': _bulkDiscountMinQuantity,
      'enableAutoPrint': _enableAutoPrint,
      'enableEmailInvoices': _enableEmailInvoices,
      'enableSMSNotifications': _enableSMSNotifications,
      'defaultPaperSize': _defaultPaperSize,
      'includeCompanyLogo': _includeCompanyLogo,
      'showPaymentInstructions': _showPaymentInstructions,
      'defaultCurrency': _defaultCurrency,
      'enableMultipleCurrencies': _enableMultipleCurrencies,
      'enableCreditCardPayments': _enableCreditCardPayments,
      'enableBankTransfers': _enableBankTransfers,
      'enableCashPayments': _enableCashPayments,
      'enableDigitalWallets': _enableDigitalWallets,
    };
    await SettingsService.saveInvoiceSettings(settings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إعادة التعيين للإعدادات الافتراضية'),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: AssyrianTheme.primaryGold,
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
                'ترقيم تلقائي للفواتير',
                'إنشاء أرقام فواتير تلقائياً',
                _enableAutoNumbering,
                (value) => setState(() => _enableAutoNumbering = value),
                Icons.format_list_numbered,
              ),
              _buildTextFieldTile(
                'بادئة رقم الفاتورة',
                'النص الذي يسبق رقم الفاتورة',
                _invoicePrefix,
                (value) => setState(() => _invoicePrefix = value),
                Icons.text_fields,
              ),
              _buildSliderTile(
                'رقم البداية للفواتير',
                'الرقم الذي تبدأ منه الفواتير',
                _startingNumber.toDouble(),
                1,
                10000,
                (value) => setState(() => _startingNumber = value.round()),
                Icons.start,
              ),
              _buildSwitchTile(
                'السماح بالدفعات الجزئية',
                'إمكانية دفع الفاتورة على دفعات',
                _allowPartialPayments,
                (value) => setState(() => _allowPartialPayments = value),
                Icons.payments,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxSettings() {
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
                'تفعيل حساب الضرائب',
                'إضافة الضرائب تلقائياً للفواتير',
                _enableTaxCalculation,
                (value) => setState(() => _enableTaxCalculation = value),
                Icons.calculate,
              ),
              _buildSliderTile(
                'معدل الضريبة الافتراضي (%)',
                'نسبة الضريبة المطبقة على الفواتير',
                _defaultTaxRate,
                0,
                30,
                (value) => setState(() => _defaultTaxRate = value),
                Icons.percent,
              ),
              _buildSwitchTile(
                'تفعيل معدلات ضرائب متعددة',
                'استخدام معدلات ضرائب مختلفة للمنتجات',
                _enableMultipleTaxRates,
                (value) => setState(() => _enableMultipleTaxRates = value),
                Icons.layers,
              ),
              _buildSwitchTile(
                'تضمين الضريبة في السعر',
                'إظهار الأسعار شاملة الضريبة',
                _includeTaxInPrice,
                (value) => setState(() => _includeTaxInPrice = value),
                Icons.price_check,
              ),
              _buildSwitchTile(
                'تفعيل رسوم الخدمة',
                'إضافة رسوم خدمة إضافية',
                _enableServiceCharges,
                (value) => setState(() => _enableServiceCharges = value),
                Icons.room_service,
              ),
              _buildSliderTile(
                'رسوم الخدمة الافتراضية (%)',
                'نسبة رسوم الخدمة المضافة',
                _defaultServiceCharge,
                0,
                20,
                (value) => setState(() => _defaultServiceCharge = value),
                Icons.add_circle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountSettings() {
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
                'تفعيل الخصومات',
                'إمكانية تطبيق خصومات على الفواتير',
                _enableDiscounts,
                (value) => setState(() => _enableDiscounts = value),
                Icons.discount,
              ),
              _buildSliderTile(
                'أقصى نسبة خصم مسموحة (%)',
                'الحد الأقصى للخصم المطبق',
                _maxDiscountPercentage,
                0,
                100,
                (value) => setState(() => _maxDiscountPercentage = value),
                Icons.trending_down,
              ),
              _buildSwitchTile(
                'تطلب موافقة على الخصم',
                'موافقة مدير قبل تطبيق خصومات كبيرة',
                _requireDiscountApproval,
                (value) => setState(() => _requireDiscountApproval = value),
                Icons.approval,
              ),
              _buildSwitchTile(
                'تفعيل كوبونات الخصم',
                'استخدام كوبونات خصم قابلة للاستبدال',
                _enableCoupons,
                (value) => setState(() => _enableCoupons = value),
                Icons.local_offer,
              ),
              _buildSwitchTile(
                'خصومات الكميات الكبيرة',
                'خصومات تلقائية للكميات الكبيرة',
                _enableBulkDiscounts,
                (value) => setState(() => _enableBulkDiscounts = value),
                Icons.inventory,
              ),
              _buildSliderTile(
                'الحد الأدنى للكمية للخصم',
                'أقل كمية للحصول على خصم الكمية',
                _bulkDiscountMinQuantity.toDouble(),
                5,
                100,
                (value) =>
                    setState(() => _bulkDiscountMinQuantity = value.round()),
                Icons.shopping_cart,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrintingSettings() {
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
                'طباعة تلقائية',
                'طباعة الفاتورة تلقائياً عند الإنشاء',
                _enableAutoPrint,
                (value) => setState(() => _enableAutoPrint = value),
                Icons.print,
              ),
              _buildSwitchTile(
                'إرسال الفواتير بالبريد الإلكتروني',
                'إرسال نسخة من الفاتورة للعميل',
                _enableEmailInvoices,
                (value) => setState(() => _enableEmailInvoices = value),
                Icons.email,
              ),
              _buildSwitchTile(
                'إشعارات الرسائل النصية',
                'إرسال إشعارات SMS للعملاء',
                _enableSMSNotifications,
                (value) => setState(() => _enableSMSNotifications = value),
                Icons.sms,
              ),
              _buildDropdownTile(
                'حجم الورق الافتراضي',
                'حجم الورق المستخدم في الطباعة',
                _defaultPaperSize,
                ['A4', 'A5', 'Letter', 'Receipt'],
                ['A4', 'A5', 'Letter', 'إيصال'],
                (value) => setState(() => _defaultPaperSize = value!),
                Icons.description,
              ),
              _buildSwitchTile(
                'تضمين شعار الشركة',
                'إظهار شعار الشركة في الفاتورة',
                _includeCompanyLogo,
                (value) => setState(() => _includeCompanyLogo = value),
                Icons.business,
              ),
              _buildSwitchTile(
                'إظهار تعليمات الدفع',
                'عرض طرق وتعليمات الدفع في الفاتورة',
                _showPaymentInstructions,
                (value) => setState(() => _showPaymentInstructions = value),
                Icons.info,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceNotificationSettings() {
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
                'إشعار إصدار فاتورة جديدة',
                'تنبيه فوري عند إنشاء فاتورة جديدة في النظام',
                _notifyNewInvoice,
                (value) => setState(() => _notifyNewInvoice = value),
                Icons.receipt_long,
              ),
              _buildSwitchTile(
                'إشعار سداد فاتورة بالكامل',
                'تنبيه فوري عند تسديد كامل المتبقي وتصفير الفاتورة',
                _notifyPaidInvoice,
                (value) => setState(() => _notifyPaidInvoice = value),
                Icons.check_circle_outline,
              ),
              _buildSwitchTile(
                'إشعار تعديل فاتورة',
                'تنبيه عند تعديل بيانات أو مبالغ فاتورة قائمة',
                _notifyUpdatedInvoice,
                (value) => setState(() => _notifyUpdatedInvoice = value),
                Icons.edit_note,
              ),
              _buildSwitchTile(
                'تنبيه الفواتير المتأخرة',
                'تذكير دوري بالفواتير التي تجاوزت موعد الاستحقاق',
                _alertOverdueInvoice,
                (value) => setState(() => _alertOverdueInvoice = value),
                Icons.timer_off_outlined,
              ),
              _buildSwitchTile(
                'تنبيه الفواتير غير المسددة',
                'تذكير بالفواتير المستحقة بانتظار التحصيل',
                _alertUnpaidInvoice,
                (value) => setState(() => _alertUnpaidInvoice = value),
                Icons.pending_actions,
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
              _buildDropdownTile(
                'العملة الافتراضية',
                'العملة المستخدمة في الفواتير',
                _defaultCurrency,
                ['USD', 'EUR', 'IQD', 'SAR', 'AED'],
                [
                  'دولار أمريكي',
                  'يورو',
                  'دينار عراقي',
                  'ريال سعودي',
                  'درهم إماراتي',
                ],
                (value) => setState(() => _defaultCurrency = value!),
                Icons.currency_exchange,
              ),
              _buildSwitchTile(
                'تفعيل عملات متعددة',
                'إمكانية استخدام عملات مختلفة',
                _enableMultipleCurrencies,
                (value) => setState(() => _enableMultipleCurrencies = value),
                Icons.monetization_on,
              ),
              _buildSwitchTile(
                'دفع بالبطاقات الائتمانية',
                'قبول المدفوعات بالبطاقات الائتمانية',
                _enableCreditCardPayments,
                (value) => setState(() => _enableCreditCardPayments = value),
                Icons.credit_card,
              ),
              _buildSwitchTile(
                'التحويلات البنكية',
                'قبول المدفوعات عبر التحويل البنكي',
                _enableBankTransfers,
                (value) => setState(() => _enableBankTransfers = value),
                Icons.account_balance,
              ),
              _buildSwitchTile(
                'الدفع النقدي',
                'قبول المدفوعات النقدية',
                _enableCashPayments,
                (value) => setState(() => _enableCashPayments = value),
                Icons.money,
              ),
              _buildSwitchTile(
                'المحافظ الرقمية',
                'قبول المدفوعات عبر المحافظ الرقمية',
                _enableDigitalWallets,
                (value) => setState(() => _enableDigitalWallets = value),
                Icons.wallet,
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

  Widget _buildTextFieldTile(
    String title,
    String subtitle,
    String value,
    ValueChanged<String> onChanged,
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
          TextField(
            // ✅ تم الإصلاح: استخدام Controller واحد على مستوى State بدلًا من إنشاء جديد في كل build
            controller: _invoicePrefixController,
            onChanged: onChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            style: TextStyle(fontSize: 12.sp, color: AssyrianTheme.deepBlue),
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
                  'إعدادات الفواتير',
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
          onPressed: _isSaving ? null : _saveSettings,
          icon: _isSaving
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: LoadingWidget(size: 20),
                )
              : Icon(Icons.save, color: AssyrianTheme.primaryGold, size: 24.sp),
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
