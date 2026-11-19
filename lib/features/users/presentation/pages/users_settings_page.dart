import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/module_enable_toggle.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/users_drawer.dart';

/// صفحة إعدادات قسم المستخدمين
class UsersSettingsPage extends StatefulWidget {
  const UsersSettingsPage({super.key});

  @override
  State<UsersSettingsPage> createState() => _UsersSettingsPageState();
}

class _UsersSettingsPageState extends State<UsersSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // إعدادات المستخدمين
  bool _allowUserRegistration = true;
  bool _requireEmailVerification = true;
  bool _enableTwoFactorAuth = false;
  bool _allowPasswordReset = true;
  bool _enableUserProfilePictures = true;
  bool _enableUserNotifications = true;

  // إعدادات كلمات المرور
  int _minPasswordLength = 8;
  bool _requireUppercase = true;
  bool _requireLowercase = true;
  bool _requireNumbers = true;
  bool _requireSpecialChars = false;
  int _passwordExpiryDays = 90;

  // إعدادات الجلسات
  int _sessionTimeoutMinutes = 30;
  bool _allowMultipleSessions = false;
  bool _logoutOnInactivity = true;

  // إعدادات الأدوار
  bool _allowRoleInheritance = true;
  bool _enableRoleHierarchy = false;
  bool _requireRoleApproval = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canManageSettings = await _permissionChecker.hasPermission('users_settings_manage');

    if (mounted) {
      setState(() {
        _canManageSettings = canManageSettings;
      });
    }
  }

  void _loadSettings() {
    context.read<UsersBloc>().add(const LoadUsersSettingsEvent());
  }

  void _saveSettings() {
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

    final settings = {
      'allowUserRegistration': _allowUserRegistration,
      'requireEmailVerification': _requireEmailVerification,
      'enableTwoFactorAuth': _enableTwoFactorAuth,
      'allowPasswordReset': _allowPasswordReset,
      'enableUserProfilePictures': _enableUserProfilePictures,
      'enableUserNotifications': _enableUserNotifications,
      'minPasswordLength': _minPasswordLength,
      'requireUppercase': _requireUppercase,
      'requireLowercase': _requireLowercase,
      'requireNumbers': _requireNumbers,
      'requireSpecialChars': _requireSpecialChars,
      'passwordExpiryDays': _passwordExpiryDays,
      'sessionTimeoutMinutes': _sessionTimeoutMinutes,
      'allowMultipleSessions': _allowMultipleSessions,
      'logoutOnInactivity': _logoutOnInactivity,
      'allowRoleInheritance': _allowRoleInheritance,
      'enableRoleHierarchy': _enableRoleHierarchy,
      'requireRoleApproval': _requireRoleApproval,
    };

    context.read<UsersBloc>().add(SaveUsersSettingsEvent(settings));
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
      drawer: const UsersDrawer(currentRoute: '/users/settings'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<UsersBloc, UsersState>(
        listener: (context, state) {
          // إغلاق نافذة التحميل
          try {
            Navigator.of(context).pop();
          } on Exception {
            // تجاهل الأخطاء
          }
          
          if (state is UsersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AssyrianTheme.crimsonRed,
              ),
            );
            setState(() => _isSaving = false);
          } else if (state is UsersSettingsSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حفظ الإعدادات بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() => _isSaving = false);
          }
        },
        builder: (context, state) {
          if (state is UsersLoading) {
            return const LoadingWidget();
          }

          if (state is UsersError) {
            return AppErrorWidget(
              message: state.message,
              onRetry: _loadSettings,
            );
          }

          return _buildSettingsContent(context);
        },
      ),
      floatingActionButton: _canManageSettings
          ? FloatingActionButton(
              heroTag: 'users_settings_save_fab',
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
              moduleId: 'users_view',
              moduleName: 'قسم المستخدمين',
              moduleIcon: Icons.people,
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
                'إعدادات المستخدمين',
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
                  _buildSectionHeader('إعدادات المستخدمين العامة'),
                  _buildUserGeneralSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات كلمات المرور'),
                  _buildPasswordSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات الجلسات والأمان'),
                  _buildSessionSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات الأدوار والصلاحيات'),
                  _buildRoleSettings(),
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

  Future<void> _resetToDefaults() async {
    setState(() {
      _allowUserRegistration = true;
      _requireEmailVerification = true;
      _enableTwoFactorAuth = false;
      _allowPasswordReset = true;
      _enableUserProfilePictures = true;
      _enableUserNotifications = true;
      _minPasswordLength = 8;
      _requireUppercase = true;
      _requireLowercase = true;
      _requireNumbers = true;
      _requireSpecialChars = false;
      _passwordExpiryDays = 90;
      _sessionTimeoutMinutes = 30;
      _allowMultipleSessions = false;
      _logoutOnInactivity = true;
      _allowRoleInheritance = true;
      _enableRoleHierarchy = false;
      _requireRoleApproval = true;
    });

    // ✅ حفظ الإعدادات الافتراضية على السيرفر بدلاً من التعديل المحلي فقط
    final settings = {
      'allowUserRegistration': _allowUserRegistration,
      'requireEmailVerification': _requireEmailVerification,
      'enableTwoFactorAuth': _enableTwoFactorAuth,
      'allowPasswordReset': _allowPasswordReset,
      'enableUserProfilePictures': _enableUserProfilePictures,
      'enableUserNotifications': _enableUserNotifications,
      'minPasswordLength': _minPasswordLength,
      'requireUppercase': _requireUppercase,
      'requireLowercase': _requireLowercase,
      'requireNumbers': _requireNumbers,
      'requireSpecialChars': _requireSpecialChars,
      'passwordExpiryDays': _passwordExpiryDays,
      'sessionTimeoutMinutes': _sessionTimeoutMinutes,
      'allowMultipleSessions': _allowMultipleSessions,
      'logoutOnInactivity': _logoutOnInactivity,
      'allowRoleInheritance': _allowRoleInheritance,
      'enableRoleHierarchy': _enableRoleHierarchy,
      'requireRoleApproval': _requireRoleApproval,
    };

    if (mounted) {
      context.read<UsersBloc>().add(SaveUsersSettingsEvent(settings));
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
        style: AssyrianTheme.titleStyle.copyWith(
          fontSize: 16.sp,
          color: AssyrianTheme.primaryGold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserGeneralSettings() {
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
                'السماح بتسجيل المستخدمين الجدد',
                'يمكن للمستخدمين الجدد إنشاء حسابات',
                _allowUserRegistration,
                (value) => setState(() => _allowUserRegistration = value),
                Icons.person_add,
              ),
              _buildSwitchTile(
                'تطلب تأكيد البريد الإلكتروني',
                'يجب على المستخدمين تأكيد بريدهم الإلكتروني',
                _requireEmailVerification,
                (value) => setState(() => _requireEmailVerification = value),
                Icons.email_outlined,
              ),
              _buildSwitchTile(
                'تفعيل المصادقة الثنائية',
                'تطلب رمز إضافي عند تسجيل الدخول',
                _enableTwoFactorAuth,
                (value) => setState(() => _enableTwoFactorAuth = value),
                Icons.security,
              ),
              _buildSwitchTile(
                'السماح بإعادة تعيين كلمة المرور',
                'يمكن للمستخدمين إعادة تعيين كلمات مرورهم',
                _allowPasswordReset,
                (value) => setState(() => _allowPasswordReset = value),
                Icons.lock_reset,
              ),
              _buildSwitchTile(
                'تفعيل صور الملف الشخصي',
                'يمكن للمستخدمين رفع صور شخصية',
                _enableUserProfilePictures,
                (value) => setState(() => _enableUserProfilePictures = value),
                Icons.account_circle,
              ),
              _buildSwitchTile(
                'تفعيل إشعارات المستخدمين',
                'إرسال إشعارات للمستخدمين',
                _enableUserNotifications,
                (value) => setState(() => _enableUserNotifications = value),
                Icons.notifications,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordSettings() {
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
              _buildSliderTile(
                'الحد الأدنى لطول كلمة المرور',
                'عدد الأحرف المطلوبة كحد أدنى',
                _minPasswordLength.toDouble(),
                4,
                20,
                (value) => setState(() => _minPasswordLength = value.round()),
                Icons.password,
              ),
              _buildSwitchTile(
                'تطلب أحرف كبيرة',
                'يجب أن تحتوي كلمة المرور على أحرف كبيرة',
                _requireUppercase,
                (value) => setState(() => _requireUppercase = value),
                Icons.text_fields,
              ),
              _buildSwitchTile(
                'تطلب أحرف صغيرة',
                'يجب أن تحتوي كلمة المرور على أحرف صغيرة',
                _requireLowercase,
                (value) => setState(() => _requireLowercase = value),
                Icons.text_fields,
              ),
              _buildSwitchTile(
                'تطلب أرقام',
                'يجب أن تحتوي كلمة المرور على أرقام',
                _requireNumbers,
                (value) => setState(() => _requireNumbers = value),
                Icons.numbers,
              ),
              _buildSwitchTile(
                'تطلب رموز خاصة',
                'يجب أن تحتوي كلمة المرور على رموز خاصة',
                _requireSpecialChars,
                (value) => setState(() => _requireSpecialChars = value),
                Icons.alternate_email,
              ),
              _buildSliderTile(
                'انتهاء صلاحية كلمة المرور (أيام)',
                'عدد الأيام قبل انتهاء صلاحية كلمة المرور',
                _passwordExpiryDays.toDouble(),
                30,
                365,
                (value) => setState(() => _passwordExpiryDays = value.round()),
                Icons.schedule,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionSettings() {
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
              _buildSwitchTile(
                'السماح بجلسات متعددة',
                'يمكن للمستخدم تسجيل الدخول من أجهزة متعددة',
                _allowMultipleSessions,
                (value) => setState(() => _allowMultipleSessions = value),
                Icons.devices,
              ),
              _buildSwitchTile(
                'تسجيل الخروج عند عدم النشاط',
                'تسجيل خروج تلقائي عند عدم النشاط',
                _logoutOnInactivity,
                (value) => setState(() => _logoutOnInactivity = value),
                Icons.logout,
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

  Widget _buildRoleSettings() {
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
                'السماح بوراثة الأدوار',
                'يمكن للأدوار وراثة صلاحيات من أدوار أخرى',
                _allowRoleInheritance,
                (value) => setState(() => _allowRoleInheritance = value),
                Icons.family_restroom,
              ),
              _buildSwitchTile(
                'تفعيل التسلسل الهرمي للأدوار',
                'ترتيب الأدوار في تسلسل هرمي',
                _enableRoleHierarchy,
                (value) => setState(() => _enableRoleHierarchy = value),
                Icons.account_tree,
              ),
              _buildSwitchTile(
                'تطلب موافقة على تعيين الأدوار',
                'يجب الموافقة على تعيين أدوار جديدة للمستخدمين',
                _requireRoleApproval,
                (value) => setState(() => _requireRoleApproval = value),
                Icons.approval,
              ),
            ],
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
                  'إعدادات المستخدمين',
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
