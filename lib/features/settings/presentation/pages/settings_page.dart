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
import '../widgets/settings_drawer.dart';

/// صفحة الإعدادات العامة للنظام
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // إعدادات الشركة
  String _companyName = 'شركة المتاجر الآشورية';
  String _companyAddress = '';
  String _companyPhone = '';
  String _companyEmail = '';
  String _companyWebsite = '';
  String _taxNumber = '';

  // إعدادات النظام العامة
  String _systemLanguage = 'ar';
  String _systemTimezone = 'Asia/Baghdad';
  String _dateFormat = 'dd/MM/yyyy';
  String _timeFormat = '24h';
  bool _enableDarkMode = false;
  bool _enableNotifications = true;

  // إعدادات الأمان
  bool _enableTwoFactorAuth = false;
  bool _enableLoginLogging = true;
  int _sessionTimeoutMinutes = 30;
  int _passwordExpiryDays = 90;
  bool _enableIPWhitelist = false;
  bool _enableSSL = true;

  // إعدادات النسخ الاحتياطي
  bool _enableAutoBackup = true;
  String _backupFrequency = 'يومي';
  int _backupRetentionDays = 30;
  String _backupLocation = 'Local';
  bool _enableCloudBackup = false;
  String _cloudProvider = 'جوجل درايف';

  // إعدادات الإشعارات
  bool _enableEmailNotifications = true;
  bool _enableSMSNotifications = false;
  bool _enablePushNotifications = false;
  bool _enableSystemAlerts = true;
  String _notificationSound = 'Default';
  bool _enableQuietHours = false;

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

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getSystemSettings();
      setState(() {
        _companyName = settings['companyName'] ?? 'شركة المتاجر الآشورية';
        _companyAddress = settings['companyAddress'] ?? '';
        _companyPhone = settings['companyPhone'] ?? '';
        _companyEmail = settings['companyEmail'] ?? '';
        _companyWebsite = settings['companyWebsite'] ?? '';
        _taxNumber = settings['taxNumber'] ?? '';
        _systemLanguage = settings['systemLanguage'] ?? 'ar';
        _systemTimezone = settings['systemTimezone'] ?? 'Asia/Baghdad';
        _dateFormat = settings['dateFormat'] ?? 'dd/MM/yyyy';
        _timeFormat = settings['timeFormat'] ?? '24h';
        _enableDarkMode = settings['enableDarkMode'] ?? false;
        _enableNotifications = settings['enableNotifications'] ?? true;
        _enableTwoFactorAuth = settings['enableTwoFactorAuth'] ?? false;
        _enableLoginLogging = settings['enableLoginLogging'] ?? true;
        _sessionTimeoutMinutes = settings['sessionTimeoutMinutes'] ?? 30;
        _passwordExpiryDays = settings['passwordExpiryDays'] ?? 90;
        _enableIPWhitelist = settings['enableIPWhitelist'] ?? false;
        _enableSSL = settings['enableSSL'] ?? true;
        _enableAutoBackup = settings['enableAutoBackup'] ?? true;
        _backupFrequency = _normalizeBackupFrequency(
          settings['backupFrequency'],
        );
        _backupRetentionDays = settings['backupRetentionDays'] ?? 30;
        _backupLocation = settings['backupLocation'] ?? 'Local';
        _enableCloudBackup = settings['enableCloudBackup'] ?? false;
        _cloudProvider = settings['cloudProvider'] ?? 'جوجل درايف';
        _enableEmailNotifications =
            settings['enableEmailNotifications'] ?? true;
        _enableSMSNotifications = settings['enableSMSNotifications'] ?? false;
        _enablePushNotifications = settings['enablePushNotifications'] ?? false;
        _enableSystemAlerts = settings['enableSystemAlerts'] ?? true;
        _notificationSound = settings['notificationSound'] ?? 'Default';
        _enableQuietHours = settings['enableQuietHours'] ?? false;
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
        'companyName': _companyName,
        'companyAddress': _companyAddress,
        'companyPhone': _companyPhone,
        'companyEmail': _companyEmail,
        'companyWebsite': _companyWebsite,
        'taxNumber': _taxNumber,
        'systemLanguage': _systemLanguage,
        'systemTimezone': _systemTimezone,
        'dateFormat': _dateFormat,
        'timeFormat': _timeFormat,
        'enableDarkMode': _enableDarkMode,
        'enableNotifications': _enableNotifications,
        'enableTwoFactorAuth': _enableTwoFactorAuth,
        'enableLoginLogging': _enableLoginLogging,
        'sessionTimeoutMinutes': _sessionTimeoutMinutes,
        'passwordExpiryDays': _passwordExpiryDays,
        'enableIPWhitelist': _enableIPWhitelist,
        'enableSSL': _enableSSL,
        'enableAutoBackup': _enableAutoBackup,
        'backupFrequency': _backupFrequency,
        'backupRetentionDays': _backupRetentionDays,
        'backupLocation': _backupLocation,
        'enableCloudBackup': _enableCloudBackup,
        'cloudProvider': _cloudProvider,
        'enableEmailNotifications': _enableEmailNotifications,
        'enableSMSNotifications': _enableSMSNotifications,
        'enablePushNotifications': _enablePushNotifications,
        'enableSystemAlerts': _enableSystemAlerts,
        'notificationSound': _notificationSound,
        'enableQuietHours': _enableQuietHours,
      };

      await SettingsService.saveSystemSettings(settings);

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
      drawer: const SettingsDrawer(currentRoute: '/settings'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: _buildSettingsContent(context),
      floatingActionButton: _canManageSettings
          ? FloatingActionButton(
              heroTag: 'settings_general_save_fab',
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
                'الإعدادات العامة',
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
                  _buildSectionHeader('معلومات الشركة'),
                  _buildCompanySettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات النظام العامة'),
                  _buildSystemSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات الأمان'),
                  _buildSecuritySettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('النسخ الاحتياطي'),
                  _buildBackupSettings(),
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
            icon: Icons.backup,
            label: 'نسخة احتياطية',
            onTap: _createBackup,
            color: Colors.green,
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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20.sp),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.sp,
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

  void _createBackup() {
    // تنفيذ إنشاء نسخة احتياطية
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري إنشاء النسخة الاحتياطية...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _companyName = 'شركة المتاجر الآشورية';
      _companyAddress = '';
      _companyPhone = '';
      _companyEmail = '';
      _companyWebsite = '';
      _taxNumber = '';
      _systemLanguage = 'ar';
      _systemTimezone = 'Asia/Baghdad';
      _dateFormat = 'dd/MM/yyyy';
      _timeFormat = '24h';
      _enableDarkMode = false;
      _enableNotifications = true;
      _enableTwoFactorAuth = false;
      _enableLoginLogging = true;
      _sessionTimeoutMinutes = 30;
      _passwordExpiryDays = 90;
      _enableIPWhitelist = false;
      _enableSSL = true;
      _enableAutoBackup = true;
      _backupFrequency = 'يومي';
      _backupRetentionDays = 30;
      _backupLocation = 'Local';
      _enableCloudBackup = false;
      _cloudProvider = 'جوجل درايف';
      _enableEmailNotifications = true;
      _enableSMSNotifications = false;
      _enablePushNotifications = true;
      _enableSystemAlerts = true;
      _notificationSound = 'Default';
      _enableQuietHours = false;
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

  Widget _buildCompanySettings() {
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
              _buildTextFieldTile(
                'اسم الشركة',
                'الاسم الرسمي للشركة',
                _companyName,
                (value) => setState(() => _companyName = value),
                Icons.business,
              ),
              _buildTextFieldTile(
                'عنوان الشركة',
                'العنوان الكامل للشركة',
                _companyAddress,
                (value) => setState(() => _companyAddress = value),
                Icons.location_on,
              ),
              _buildTextFieldTile(
                'رقم الهاتف',
                'رقم هاتف الشركة',
                _companyPhone,
                (value) => setState(() => _companyPhone = value),
                Icons.phone,
              ),
              _buildTextFieldTile(
                'البريد الإلكتروني',
                'البريد الإلكتروني للشركة',
                _companyEmail,
                (value) => setState(() => _companyEmail = value),
                Icons.email,
              ),
              _buildTextFieldTile(
                'الموقع الإلكتروني',
                'موقع الشركة على الإنترنت',
                _companyWebsite,
                (value) => setState(() => _companyWebsite = value),
                Icons.web,
              ),
              _buildTextFieldTile(
                'الرقم الضريبي',
                'رقم التسجيل الضريبي للشركة',
                _taxNumber,
                (value) => setState(() => _taxNumber = value),
                Icons.receipt_long,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemSettings() {
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
                'لغة النظام',
                'اللغة المستخدمة في واجهة النظام',
                _systemLanguage,
                ['ar', 'en', 'ku'],
                ['العربية', 'الإنجليزية', 'کوردی'],
                (value) => setState(() => _systemLanguage = value!),
                Icons.language,
              ),
              _buildDropdownTile(
                'المنطقة الزمنية',
                'المنطقة الزمنية المستخدمة في النظام',
                _systemTimezone,
                ['Asia/Baghdad', 'Asia/Riyadh', 'Asia/Dubai', 'UTC'],
                ['بغداد', 'الرياض', 'دبي', 'التوقيت العالمي'],
                (value) => setState(() => _systemTimezone = value!),
                Icons.access_time,
              ),
              _buildDropdownTile(
                'تنسيق التاريخ',
                'طريقة عرض التاريخ في النظام',
                _dateFormat,
                ['dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'],
                ['يوم/شهر/سنة', 'شهر/يوم/سنة', 'سنة-شهر-يوم'],
                (value) => setState(() => _dateFormat = value!),
                Icons.date_range,
              ),
              _buildDropdownTile(
                'تنسيق الوقت',
                'طريقة عرض الوقت في النظام',
                _timeFormat,
                ['24h', '12h'],
                ['24 ساعة', '12 ساعة'],
                (value) => setState(() => _timeFormat = value!),
                Icons.schedule,
              ),
              _buildSwitchTile(
                'تفعيل الوضع المظلم',
                'استخدام الألوان المظلمة في الواجهة',
                _enableDarkMode,
                (value) => setState(() => _enableDarkMode = value),
                Icons.dark_mode,
              ),
              _buildSwitchTile(
                'تفعيل الإشعارات',
                'إظهار الإشعارات في النظام',
                _enableNotifications,
                (value) => setState(() => _enableNotifications = value),
                Icons.notifications,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecuritySettings() {
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
                'المصادقة الثنائية',
                'تفعيل المصادقة الثنائية للحسابات',
                _enableTwoFactorAuth,
                (value) => setState(() => _enableTwoFactorAuth = value),
                Icons.security,
              ),
              _buildSwitchTile(
                'تسجيل عمليات تسجيل الدخول',
                'حفظ سجل بعمليات تسجيل الدخول',
                _enableLoginLogging,
                (value) => setState(() => _enableLoginLogging = value),
                Icons.login,
              ),
              _buildSliderTile(
                'مهلة انتهاء الجلسة (دقائق)',
                'المدة قبل انتهاء صلاحية الجلسة تلقائياً',
                _sessionTimeoutMinutes.toDouble(),
                5,
                120,
                (value) =>
                    setState(() => _sessionTimeoutMinutes = value.round()),
                Icons.timer,
              ),
              _buildSliderTile(
                'انتهاء صلاحية كلمة المرور (أيام)',
                'عدد الأيام قبل انتهاء صلاحية كلمة المرور',
                _passwordExpiryDays.toDouble(),
                30,
                365,
                (value) => setState(() => _passwordExpiryDays = value.round()),
                Icons.password,
              ),
              _buildSwitchTile(
                'تفعيل قائمة IP المسموحة',
                'السماح بالوصول من عناوين IP محددة فقط',
                _enableIPWhitelist,
                (value) => setState(() => _enableIPWhitelist = value),
                Icons.shield,
              ),
              _buildSwitchTile(
                'تفعيل SSL',
                'استخدام الاتصال المشفر SSL',
                _enableSSL,
                (value) => setState(() => _enableSSL = value),
                Icons.https,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackupSettings() {
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
                'النسخ الاحتياطي التلقائي',
                'إنشاء نسخ احتياطية تلقائياً',
                _enableAutoBackup,
                (value) => setState(() => _enableAutoBackup = value),
                Icons.backup,
              ),
              _buildDropdownTile(
                'تكرار النسخ الاحتياطي',
                'معدل إنشاء النسخ الاحتياطية',
                _backupFrequency,
                ['كل ساعة', 'يومي', 'أسبوعي', 'شهري'],
                ['كل ساعة', 'يومي', 'أسبوعي', 'شهري'],
                (value) => setState(() => _backupFrequency = value!),
                Icons.schedule,
              ),
              _buildSliderTile(
                'مدة الاحتفاظ بالنسخ (أيام)',
                'عدد الأيام للاحتفاظ بالنسخ الاحتياطية',
                _backupRetentionDays.toDouble(),
                7,
                365,
                (value) => setState(() => _backupRetentionDays = value.round()),
                Icons.storage,
              ),
              _buildDropdownTile(
                'موقع النسخ الاحتياطي',
                'مكان حفظ النسخ الاحتياطية',
                _backupLocation,
                ['Local', 'Network', 'Cloud'],
                ['محلي', 'شبكة', 'سحابي'],
                (value) => setState(() => _backupLocation = value!),
                Icons.folder,
              ),
              _buildSwitchTile(
                'النسخ الاحتياطي السحابي',
                'حفظ النسخ في التخزين السحابي',
                _enableCloudBackup,
                (value) => setState(() => _enableCloudBackup = value),
                Icons.cloud_upload,
              ),
              _buildDropdownTile(
                'مزود الخدمة السحابية',
                'الخدمة المستخدمة للتخزين السحابي',
                _cloudProvider,
                ['جوجل درايف', 'دروب بوكس', 'ون درايف', 'AWS S3'],
                ['جوجل درايف', 'دروب بوكس', 'ون درايف', 'خدمة أمازون السحابية (S3)'],
                (value) => setState(() => _cloudProvider = value!),
                Icons.cloud,
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
                'إشعارات البريد الإلكتروني',
                'إرسال الإشعارات عبر البريد الإلكتروني',
                _enableEmailNotifications,
                (value) => setState(() => _enableEmailNotifications = value),
                Icons.email,
              ),
              _buildSwitchTile(
                'إشعارات الرسائل النصية',
                'إرسال الإشعارات عبر الرسائل النصية',
                _enableSMSNotifications,
                (value) => setState(() => _enableSMSNotifications = value),
                Icons.sms,
              ),
              _buildSwitchTile(
                'الإشعارات الفورية',
                'إظهار الإشعارات الفورية في النظام',
                _enablePushNotifications,
                (value) => setState(() => _enablePushNotifications = value),
                Icons.notifications_active,
              ),
              _buildSwitchTile(
                'تنبيهات النظام',
                'إظهار تنبيهات النظام والأخطاء',
                _enableSystemAlerts,
                (value) => setState(() => _enableSystemAlerts = value),
                Icons.warning,
              ),
              _buildDropdownTile(
                'صوت الإشعار',
                'الصوت المستخدم للإشعارات',
                _notificationSound,
                ['Default', 'Bell', 'Chime', 'Ding', 'Silent'],
                ['افتراضي', 'جرس', 'رنين', 'صوت تنبيه', 'صامت'],
                (value) => setState(() => _notificationSound = value!),
                Icons.volume_up,
              ),
              _buildSwitchTile(
                'تفعيل الساعات الهادئة',
                'إيقاف الإشعارات في أوقات محددة',
                _enableQuietHours,
                (value) => setState(() => _enableQuietHours = value),
                Icons.do_not_disturb,
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
            controller: TextEditingController(text: value),
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

  String _normalizeBackupFrequency(Object? value) {
    const aliases = {
      'Hourly': 'كل ساعة',
      'Daily': 'يومي',
      'Weekly': 'أسبوعي',
      'Monthly': 'شهري',
    };
    final normalized = aliases[value?.toString()] ?? value?.toString();
    const supportedValues = ['كل ساعة', 'يومي', 'أسبوعي', 'شهري'];
    return supportedValues.contains(normalized) ? normalized! : 'يومي';
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
    // DropdownButton requires exactly one item for its selected value. Build a
    // unique option list so duplicate values from any caller can never violate
    // that invariant, and fall back if a stored value is no longer supported.
    final uniqueOptions = options.toSet().toList(growable: false);
    final selectedValue = uniqueOptions.contains(value)
        ? value
        : uniqueOptions.first;
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
                value: selectedValue,
                isExpanded: true,
                items: uniqueOptions.map((option) {
                  final index = options.indexOf(option);
                  final displayName = index < displayNames.length
                      ? displayNames[index]
                      : option;
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      displayName,
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
                  'الإعدادات العامة',
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
