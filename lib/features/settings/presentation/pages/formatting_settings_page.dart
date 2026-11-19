import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/smart_number_formatter.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/smart_number_test_widget.dart';

/// صفحة إعدادات تنسيق الأرقام والعملات والتاريخ
class FormattingSettingsPage extends StatefulWidget {
  const FormattingSettingsPage({super.key});

  @override
  State<FormattingSettingsPage> createState() => _FormattingSettingsPageState();
}

class _FormattingSettingsPageState extends State<FormattingSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // إعدادات تنسيق التاريخ
  String _dateFormat = 'dd/MM/yyyy';
  String _timeFormat = '24h';
  String _dateTimeFormat = 'dd/MM/yyyy HH:mm';
  bool _showWeekday = false;
  bool _showSeconds = false;
  String _calendarType = 'gregorian';

  // إعدادات تنسيق الأرقام
  String _numberFormat = 'en';
  String _decimalSeparator = '.';
  String _thousandsSeparator = ',';
  int _decimalPlaces = 2;
  bool _showThousandsSeparator = true;
  bool _showLeadingZero = true;
  bool _smartDecimalSeparator = true;
  bool _autoThousandsSeparator = true;

  // إعدادات العملات
  String _defaultCurrency = 'IQD';
  String _currencyPosition = 'before';
  String _currencySymbol = 'د.ع';
  bool _showCurrencySymbol = true;
  bool _showCurrencyCode = false;
  String _currencyFormat = 'symbol';

  // إعدادات المنطقة الزمنية
  String _timezone = 'Asia/Baghdad';
  bool _autoDetectTimezone = true;
  String _locale = 'ar_IQ';

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getFormattingSettings();

      setState(() {
        // تنسيق التاريخ
        _dateFormat = settings['dateFormat'] ?? 'dd/MM/yyyy';
        String loadedTimeFormat = settings['timeFormat'] ?? '24h';
        // تحويل القيم القديمة إلى الجديدة
        if (loadedTimeFormat == 'HH:mm' || loadedTimeFormat == 'H:mm') {
          _timeFormat = '24h';
        } else if (loadedTimeFormat == 'h:mm a' ||
            loadedTimeFormat == 'hh:mm a') {
          _timeFormat = '12h';
        } else {
          _timeFormat = loadedTimeFormat;
        }
        _dateTimeFormat = settings['dateTimeFormat'] ?? 'dd/MM/yyyy HH:mm';
        _showWeekday = settings['showWeekday'] ?? false;
        _showSeconds = settings['showSeconds'] ?? false;
        _calendarType = settings['calendarType'] ?? 'gregorian';

        // تنسيق الأرقام
        String loadedNumberFormat = settings['numberFormat'] ?? 'en';
        // تحويل القيم القديمة إلى الجديدة
        if (loadedNumberFormat == '#,##0.00' ||
            loadedNumberFormat == '#,##0' ||
            loadedNumberFormat.contains('#')) {
          _numberFormat = 'en';
        } else {
          _numberFormat = loadedNumberFormat;
        }
        _decimalSeparator = settings['decimalSeparator'] ?? '.';
        _thousandsSeparator = settings['thousandsSeparator'] ?? ',';
        _decimalPlaces = settings['decimalPlaces'] ?? 2;
        _showThousandsSeparator = settings['showThousandsSeparator'] ?? true;
        _showLeadingZero = settings['showLeadingZero'] ?? true;
        _smartDecimalSeparator = settings['smartDecimalSeparator'] ?? true;
        _autoThousandsSeparator = settings['autoThousandsSeparator'] ?? true;

        // العملات
        _defaultCurrency = settings['defaultCurrency'] ?? 'IQD';
        _currencyPosition = settings['currencyPosition'] ?? 'before';
        _currencySymbol = settings['currencySymbol'] ?? 'د.ع';
        _showCurrencySymbol = settings['showCurrencySymbol'] ?? true;
        _showCurrencyCode = settings['showCurrencyCode'] ?? false;
        _currencyFormat = settings['currencyFormat'] ?? 'symbol';

        // المنطقة الزمنية
        _timezone = settings['timezone'] ?? 'Asia/Baghdad';
        _autoDetectTimezone = settings['autoDetectTimezone'] ?? true;
        _locale = settings['locale'] ?? 'ar_IQ';
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
        // تنسيق التاريخ
        'dateFormat': _dateFormat,
        'timeFormat': _timeFormat,
        'dateTimeFormat': _dateTimeFormat,
        'showWeekday': _showWeekday,
        'showSeconds': _showSeconds,
        'calendarType': _calendarType,

        // تنسيق الأرقام
        'numberFormat': _numberFormat,
        'decimalSeparator': _decimalSeparator,
        'thousandsSeparator': _thousandsSeparator,
        'decimalPlaces': _decimalPlaces,
        'showThousandsSeparator': _showThousandsSeparator,
        'showLeadingZero': _showLeadingZero,
        'smartDecimalSeparator': _smartDecimalSeparator,
        'autoThousandsSeparator': _autoThousandsSeparator,

        // العملات
        'defaultCurrency': _defaultCurrency,
        'currencyPosition': _currencyPosition,
        'currencySymbol': _currencySymbol,
        'showCurrencySymbol': _showCurrencySymbol,
        'showCurrencyCode': _showCurrencyCode,
        'currencyFormat': _currencyFormat,

        // المنطقة الزمنية
        'timezone': _timezone,
        'autoDetectTimezone': _autoDetectTimezone,
        'locale': _locale,
      };

      await SettingsService.saveFormattingSettings(settings);

      // إعادة تحميل إعدادات خدمة التنسيق
      final formattingService = GetIt.instance<FormattingService>();
      await formattingService.reload();

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
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const SettingsDrawer(currentRoute: '/settings/formatting'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: _buildSettingsContent(context),
      floatingActionButton: _canManageSettings
          ? FloatingActionButton(
              heroTag: 'settings_formatting_save_fab',
              onPressed: _saveSettings,
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: const Icon(Icons.save),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
                  'إعدادات التنسيق',
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
                  'الأرقام والعملات والتاريخ',
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
          tooltip: 'حفظ',
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

  Widget _buildSettingsContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _loadSettings(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildWelcomeCard(context)),
          SliverToBoxAdapter(child: _buildQuickActions(context)),
          SliverToBoxAdapter(child: _buildDateTimeSettings(context)),
          SliverToBoxAdapter(child: _buildNumberSettings(context)),
          SliverToBoxAdapter(child: _buildCurrencySettings(context)),
          SliverToBoxAdapter(child: _buildLocaleSettings(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AssyrianTheme.primaryGold.withValues(alpha: 0.1),
            AssyrianTheme.deepBlue.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.format_list_numbered,
              size: 24.sp,
              color: AssyrianTheme.primaryGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات التنسيق',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تخصيص تنسيق الأرقام والعملات والتاريخ',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
            label: 'الافتراضي',
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
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(icon, size: 20.sp, color: color),
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeSettings(BuildContext context) {
    return _buildSettingsSection(
      title: 'إعدادات التاريخ والوقت',
      icon: Icons.calendar_today,
      children: [
        _buildDropdownSetting(
          title: 'تنسيق التاريخ',
          value: _dateFormat,
          items: [
            {'value': 'dd/MM/yyyy', 'label': 'يوم/شهر/سنة (31/12/2023)'},
            {'value': 'MM/dd/yyyy', 'label': 'شهر/يوم/سنة (12/31/2023)'},
            {'value': 'yyyy-MM-dd', 'label': 'سنة-شهر-يوم (2023-12-31)'},
            {'value': 'dd-MM-yyyy', 'label': 'يوم-شهر-سنة (31-12-2023)'},
          ],
          onChanged: (value) => setState(() => _dateFormat = value!),
        ),
        _buildDropdownSetting(
          title: 'تنسيق الوقت',
          value: _timeFormat,
          items: [
            {'value': '24h', 'label': '24 ساعة (14:30)'},
            {'value': '12h', 'label': '12 ساعة (2:30 PM)'},
          ],
          onChanged: (value) => setState(() => _timeFormat = value!),
        ),
        _buildDropdownSetting(
          title: 'نوع التقويم',
          value: _calendarType,
          items: [
            {'value': 'gregorian', 'label': 'ميلادي'},
            {'value': 'hijri', 'label': 'هجري'},
          ],
          onChanged: (value) => setState(() => _calendarType = value!),
        ),
        _buildSwitchSetting(
          title: 'إظهار يوم الأسبوع',
          subtitle: 'عرض اسم اليوم مع التاريخ',
          value: _showWeekday,
          onChanged: (value) => setState(() => _showWeekday = value),
        ),
        _buildSwitchSetting(
          title: 'إظهار الثواني',
          subtitle: 'عرض الثواني في الوقت',
          value: _showSeconds,
          onChanged: (value) => setState(() => _showSeconds = value),
        ),
      ],
    );
  }

  Widget _buildNumberSettings(BuildContext context) {
    return _buildSettingsSection(
      title: 'إعدادات الأرقام',
      icon: Icons.numbers,
      children: [
        _buildDropdownSetting(
          title: 'نظام الأرقام',
          value: _numberFormat,
          items: [
            {'value': 'en', 'label': 'إنجليزي (1234567.89)'},
            {'value': 'ar', 'label': 'عربي (١٢٣٤٥٦٧.٨٩)'},
          ],
          onChanged: (value) => setState(() => _numberFormat = value!),
        ),
        _buildDropdownSetting(
          title: 'فاصل الأعشار',
          value: _decimalSeparator,
          items: [
            {'value': '.', 'label': 'نقطة (.)'},
            {'value': ',', 'label': 'فاصلة (,)'},
          ],
          onChanged: (value) => setState(() => _decimalSeparator = value!),
        ),
        _buildDropdownSetting(
          title: 'فاصل الآلاف',
          value: _thousandsSeparator,
          items: [
            {'value': ',', 'label': 'فاصلة (,)'},
            {'value': ' ', 'label': 'مسافة ( )'},
            {'value': '.', 'label': 'نقطة (.)'},
          ],
          onChanged: (value) => setState(() => _thousandsSeparator = value!),
        ),
        _buildSliderSetting(
          title: 'عدد الأرقام العشرية',
          value: _decimalPlaces.toDouble(),
          min: 0,
          max: 6,
          divisions: 6,
          onChanged: (value) => setState(() => _decimalPlaces = value.round()),
        ),
        _buildSwitchSetting(
          title: 'إظهار فاصل الآلاف',
          subtitle: 'عرض فاصل بين كل ثلاثة أرقام',
          value: _showThousandsSeparator,
          onChanged: (value) => setState(() => _showThousandsSeparator = value),
        ),
        _buildSwitchSetting(
          title: 'إظهار الصفر البادئ',
          subtitle: 'عرض صفر قبل الأرقام العشرية (0.5)',
          value: _showLeadingZero,
          onChanged: (value) => setState(() => _showLeadingZero = value),
        ),
        _buildSwitchSetting(
          title: 'الفاصلة العشرية الذكية',
          subtitle: 'إخفاء الفاصلة العشرية عند عدم وجود أرقام عشرية',
          value: _smartDecimalSeparator,
          onChanged: (value) => setState(() => _smartDecimalSeparator = value),
        ),
        _buildSwitchSetting(
          title: 'فاصل الآلاف التلقائي',
          subtitle: 'إضافة فاصل الآلاف تلقائياً أثناء الكتابة',
          value: _autoThousandsSeparator,
          onChanged: (value) => setState(() => _autoThousandsSeparator = value),
        ),
        _buildNumberPreview(),
        _buildSmartNumberTest(),
      ],
    );
  }

  Widget _buildCurrencySettings(BuildContext context) {
    return _buildSettingsSection(
      title: 'إعدادات العملة',
      icon: Icons.attach_money,
      children: [
        _buildDropdownSetting(
          title: 'العملة الافتراضية',
          value: _defaultCurrency,
          items: [
            {'value': 'USD', 'label': 'دولار أمريكي (USD)'},
            {'value': 'EUR', 'label': 'يورو (EUR)'},
            {'value': 'IQD', 'label': 'دينار عراقي (IQD)'},
            {'value': 'SAR', 'label': 'ريال سعودي (SAR)'},
            {'value': 'AED', 'label': 'درهم إماراتي (AED)'},
          ],
          onChanged: (value) => setState(() => _defaultCurrency = value!),
        ),
        _buildDropdownSetting(
          title: 'موضع رمز العملة',
          value: _currencyPosition,
          items: [
            {'value': 'before', 'label': r'قبل المبلغ ($100)'},
            {'value': 'after', 'label': r'بعد المبلغ (100$)'},
          ],
          onChanged: (value) => setState(() => _currencyPosition = value!),
        ),
        _buildDropdownSetting(
          title: 'تنسيق العملة',
          value: _currencyFormat,
          items: [
            {'value': 'symbol', 'label': r'رمز العملة ($)'},
            {'value': 'code', 'label': 'كود العملة (USD)'},
            {'value': 'both', 'label': r'كلاهما ($ USD)'},
          ],
          onChanged: (value) => setState(() => _currencyFormat = value!),
        ),
        _buildSwitchSetting(
          title: 'إظهار رمز العملة',
          subtitle: 'عرض رمز العملة مع المبلغ',
          value: _showCurrencySymbol,
          onChanged: (value) => setState(() => _showCurrencySymbol = value),
        ),
        _buildSwitchSetting(
          title: 'إظهار كود العملة',
          subtitle: 'عرض كود العملة مع المبلغ',
          value: _showCurrencyCode,
          onChanged: (value) => setState(() => _showCurrencyCode = value),
        ),
      ],
    );
  }

  Widget _buildLocaleSettings(BuildContext context) {
    return _buildSettingsSection(
      title: 'إعدادات المنطقة',
      icon: Icons.language,
      children: [
        _buildDropdownSetting(
          title: 'المنطقة الزمنية',
          value: _timezone,
          items: [
            {'value': 'Asia/Baghdad', 'label': 'بغداد (GMT+3)'},
            {'value': 'Asia/Riyadh', 'label': 'الرياض (GMT+3)'},
            {'value': 'Asia/Dubai', 'label': 'دبي (GMT+4)'},
            {'value': 'Europe/London', 'label': 'لندن (GMT+0)'},
            {'value': 'America/New_York', 'label': 'نيويورك (GMT-5)'},
          ],
          onChanged: (value) => setState(() => _timezone = value!),
        ),
        _buildDropdownSetting(
          title: 'اللغة والمنطقة',
          value: _locale,
          items: [
            {'value': 'ar_IQ', 'label': 'العربية - العراق'},
            {'value': 'ar_SA', 'label': 'العربية - السعودية'},
            {'value': 'ar_AE', 'label': 'العربية - الإمارات'},
            {'value': 'en_US', 'label': 'الإنجليزية - أمريكا'},
            {'value': 'en_GB', 'label': 'الإنجليزية - بريطانيا'},
          ],
          onChanged: (value) => setState(() => _locale = value!),
        ),
        _buildSwitchSetting(
          title: 'اكتشاف المنطقة الزمنية تلقائياً',
          subtitle: 'استخدام منطقة الجهاز الزمنية',
          value: _autoDetectTimezone,
          onChanged: (value) => setState(() => _autoDetectTimezone = value),
        ),
      ],
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AssyrianTheme.primaryGold, size: 20.sp),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AssyrianTheme.primaryGold,
        inactiveTrackColor: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AssyrianTheme.primaryGold,
                  width: 2,
                ),
              ),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item['value'],
                    child: Text(item['label']!),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
              Text(
                value.round().toString(),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.primaryGold,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AssyrianTheme.primaryGold,
            thumbColor: AssyrianTheme.primaryGold,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين الإعدادات'),
        content: const Text(
          'هل تريد إعادة تعيين جميع إعدادات التنسيق إلى القيم الافتراضية؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                // إعادة تعيين القيم الافتراضية
                _dateFormat = 'dd/MM/yyyy';
                _timeFormat = '24h';
                _dateTimeFormat = 'dd/MM/yyyy HH:mm';
                _showWeekday = false;
                _showSeconds = false;
                _calendarType = 'gregorian';
                _numberFormat = 'en';
                _decimalSeparator = '.';
                _thousandsSeparator = ',';
                _decimalPlaces = 2;
                _showThousandsSeparator = true;
                _smartDecimalSeparator = true;
                _autoThousandsSeparator = true;
                _defaultCurrency = 'IQD';
                _currencyPosition = 'before';
                _currencySymbol = 'د.ع';
                _showCurrencySymbol = true;
                _showCurrencyCode = false;
                _currencyFormat = 'symbol';
                _timezone = 'Asia/Baghdad';
                _autoDetectTimezone = true;
                _locale = 'ar_IQ';
              });
              _saveSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
            ),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.preview, color: AssyrianTheme.primaryGold, size: 16),
              SizedBox(width: 8),
              Text(
                'معاينة التنسيق',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildPreviewItem('1234567.89', _formatNumber(1234567.89)),
              _buildPreviewItem('1000', _formatNumber(1000)),
              _buildPreviewItem('0.5', _formatNumber(0.5)),
              _buildPreviewItem('123', _formatNumber(123)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String original, String formatted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            original,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    return SmartNumberFormatter.format(
      number,
      decimalSeparator: _decimalSeparator,
      thousandsSeparator: _thousandsSeparator,
      decimalPlaces: _decimalPlaces,
      showThousandsSeparator: _showThousandsSeparator,
      showLeadingZero: _showLeadingZero,
      smartDecimalSeparator: _smartDecimalSeparator,
      numberFormat: _numberFormat,
    );
  }

  Widget _buildSmartNumberTest() {
    return SmartNumberTestWidget(
      decimalSeparator: _decimalSeparator,
      thousandsSeparator: _thousandsSeparator,
      decimalPlaces: _decimalPlaces,
      showThousandsSeparator: _showThousandsSeparator,
      showLeadingZero: _showLeadingZero,
      smartDecimalSeparator: _smartDecimalSeparator,
      autoThousandsSeparator: _autoThousandsSeparator,
      numberFormat: _numberFormat,
    );
  }
}
