import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/pdf/pdf_settings_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/pdf_settings_entity.dart';

class PdfSettingsPage extends StatefulWidget {
  const PdfSettingsPage({super.key});

  @override
  State<PdfSettingsPage> createState() => _PdfSettingsPageState();
}

class _PdfSettingsPageState extends State<PdfSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = PdfSettingsService();
  final ScrollController _scrollController = ScrollController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _footerController;
  late TextEditingController _deleteAfterDaysController;

  bool _isLoading = true;
  bool _isSaving = false;

  bool _enableAutoGeneration = true;
  bool _enableAutoSend = true;
  bool _sendViaWhatsApp = true;
  bool _sendViaEmail = false;
  bool _sendPdfWithInvoice = false;
  bool _uploadToStorage = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadPermissions();
    _loadSettings();
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

  void _initControllers() {
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _emailController = TextEditingController();
    _websiteController = TextEditingController();
    _footerController = TextEditingController();
    _deleteAfterDaysController = TextEditingController(text: '180');
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;

      final settings = await _settingsService.getSettings(user!.email!);

      setState(() {
        _nameController.text = settings.organizationName;
        _phoneController.text = settings.organizationPhone;
        _addressController.text = settings.organizationAddress;
        _emailController.text = settings.organizationEmail ?? '';
        _websiteController.text = settings.organizationWebsite ?? '';
        _footerController.text = settings.defaultFooterText;
        _deleteAfterDaysController.text = settings.deleteAfterDays.toString();

        _enableAutoGeneration = settings.enableAutoGeneration;
        _enableAutoSend = settings.enableAutoSend;
        _sendViaWhatsApp = settings.sendViaWhatsApp;
        _sendViaEmail = settings.sendViaEmail;
        _sendPdfWithInvoice = settings.sendPdfWithInvoice;
        _uploadToStorage = settings.uploadToStorage;
      });
    } on Exception catch (e) {
      _showError('فشل في تحميل الإعدادات: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    // عرض نافذة التحميل
    if (mounted) {
      LoadingWidget.showLoadingDialog(
        context,
        message: 'جاري حفظ الإعدادات...',
        subtitle: 'الرجاء الانتظار...',
        icon: Icons.save,
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        if (mounted) {
          try {
            Navigator.of(context).pop();
          } on Exception {
            // تجاهل الأخطاء
          }
        }
        return;
      }

      final settings = PdfSettingsEntity(
        organizationName: _nameController.text.trim(),
        organizationPhone: _phoneController.text.trim(),
        organizationAddress: _addressController.text.trim(),
        organizationEmail: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        organizationWebsite: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        enableAutoGeneration: _enableAutoGeneration,
        enableAutoSend: _enableAutoSend,
        sendViaWhatsApp: _sendViaWhatsApp,
        sendViaEmail: _sendViaEmail,
        sendPdfWithInvoice: _sendPdfWithInvoice,
        uploadToStorage: _uploadToStorage,
        deleteAfterDays: int.tryParse(_deleteAfterDaysController.text) ?? 180,
        defaultFooterText: _footerController.text.trim(),
      );

      await _settingsService.saveSettings(settings, user!.email!);

      if (mounted) {
        // إغلاق نافذة التحميل
        try {
          Navigator.of(context).pop();
        } on Exception {
          // تجاهل الأخطاء
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ الإعدادات بنجاح'),
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

        _showError('فشل في حفظ الإعدادات: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// إعادة تعيين الإعدادات إلى الافتراضية
  void _resetToDefaults() {
    setState(() {
      _nameController.text = 'اسم شركتك';
      _phoneController.text = '';
      _addressController.text = 'العنوان';
      _emailController.text = '';
      _websiteController.text = '';
      _footerController.text = 'شكراً لتعاملكم معنا';
      _deleteAfterDaysController.text = '180';
      _enableAutoGeneration = true;
      _enableAutoSend = true;
      _sendViaWhatsApp = true;
      _sendViaEmail = false;
      _sendPdfWithInvoice = false;
      _uploadToStorage = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: _buildDrawer(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: _isLoading
          ? LoadingWidget(message: 'جاري التحميل...')
          : _buildSettingsContent(context),
      floatingActionButton: _canManageSettings
          ? FloatingActionButton(
              heroTag: 'settings_pdf_save_fab',
              onPressed: _isSaving ? null : _saveSettings,
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: _isSaving
                  ? LoadingWidget(size: 20)
                  : Icon(Icons.save, size: 28.sp),
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
          // أزرار الإجراءات السريعة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: _buildQuickActions(),
            ),
          ),

          // عنوان الصفحة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Text(
                'إعدادات فواتير PDF',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ),
          ),

          // محتوى الإعدادات
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('معلومات الشركة'),
                  _buildCompanyInfoSection(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('الأتمتة'),
                  _buildAutomationSection(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('طرق الإرسال'),
                  _buildSendingSection(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('التخزين'),
                  _buildStorageSection(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('الإعدادات الافتراضية'),
                  _buildDefaultsSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
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
                  'إعدادات PDF',
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
        if (!_isLoading)
          IconButton(
            icon: _isSaving
                ? LoadingWidget(size: 20)
                : Icon(
                    Icons.save,
                    color: AssyrianTheme.primaryGold,
                    size: 24.sp,
                  ),
            onPressed: _isSaving ? null : _saveSettings,
            tooltip: 'حفظ الإعدادات',
          ),
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          onPressed: _loadSettings,
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: AssyrianTheme.backgroundGradient,
            ),
            child: Text(
              'إعدادات فواتير PDF',
              style: TextStyle(color: AssyrianTheme.primaryGold, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('الإعدادات العامة'),
            onTap: () => Navigator.pop(context),
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

  Widget _buildCompanyInfoSection() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.business,
                    color: AssyrianTheme.primaryGold,
                    size: 24.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'معلومات الشركة',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _nameController,
                style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'اسم الشركة *',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: const Icon(
                    Icons.business_center,
                    color: AssyrianTheme.primaryGold,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم الشركة';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _phoneController,
                style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف *',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: const Icon(
                    Icons.phone,
                    color: AssyrianTheme.primaryGold,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال رقم الهاتف';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _addressController,
                style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'العنوان *',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: const Icon(
                    Icons.location_on,
                    color: AssyrianTheme.primaryGold,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال العنوان';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _emailController,
                style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني (اختياري)',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: const Icon(
                    Icons.email,
                    color: AssyrianTheme.primaryGold,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _websiteController,
                style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'الموقع الإلكتروني (اختياري)',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: const Icon(
                    Icons.language,
                    color: AssyrianTheme.primaryGold,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutomationSection() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: AssyrianTheme.primaryGold,
                    size: 24.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'الأتمتة',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              SwitchListTile(
                title: Text(
                  'توليد PDF تلقائياً',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'إنشاء ملف PDF عند إنشاء أي فاتورة',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
                value: _enableAutoGeneration,
                activeThumbColor: AssyrianTheme.primaryGold,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                onChanged: (value) {
                  setState(() => _enableAutoGeneration = value);
                },
              ),
              SwitchListTile(
                title: Text(
                  'الإرسال التلقائي',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'إرسال الفاتورة للعميل تلقائياً',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
                value: _enableAutoSend,
                activeThumbColor: AssyrianTheme.primaryGold,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                onChanged: _enableAutoGeneration
                    ? (value) {
                        setState(() => _enableAutoSend = value);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendingSection() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.send,
                    color: AssyrianTheme.primaryGold,
                    size: 24.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'طرق الإرسال',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              SwitchListTile(
                title: Text(
                  'إرسال عبر واتساب',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'إرسال رابط الفاتورة عبر واتساب',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
                value: _sendViaWhatsApp,
                activeThumbColor: AssyrianTheme.primaryGold,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                onChanged: _enableAutoSend
                    ? (value) {
                        setState(() => _sendViaWhatsApp = value);
                      }
                    : null,
              ),
              SwitchListTile(
                title: Text(
                  'إرسال عبر البريد الإلكتروني',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'إرسال الفاتورة كمرفق بالبريد',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
                value: _sendViaEmail,
                activeThumbColor: AssyrianTheme.primaryGold,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                onChanged: _enableAutoSend
                    ? (value) {
                        setState(() => _sendViaEmail = value);
                      }
                    : null,
              ),
              SwitchListTile(
                title: Text(
                  'إرسال ملف PDF مع الفاتورة',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'إرسال ملف PDF مع الرسالة (إذا معطل، يتم إرسال رسالة نصية فقط)',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
                value: _sendPdfWithInvoice,
                activeThumbColor: AssyrianTheme.primaryGold,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                onChanged: _enableAutoSend
                    ? (value) {
                        setState(() => _sendPdfWithInvoice = value);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageSection() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_upload,
                    color: AssyrianTheme.primaryGold,
                    size: 24.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'التخزين',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              SwitchListTile(
                title: Text(
                  'رفع إلى السحابة',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'رفع ملفات PDF إلى Firebase Storage',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
                value: _uploadToStorage,
                activeThumbColor: AssyrianTheme.primaryGold,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                onChanged: (value) {
                  setState(() => _uploadToStorage = value);
                },
              ),
              if (_uploadToStorage) ...[
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _deleteAfterDaysController,
                  decoration: const InputDecoration(
                    labelText: 'حذف الملفات بعد (أيام)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    prefixIcon: Icon(
                      Icons.delete_sweep,
                      color: AssyrianTheme.primaryGold,
                    ),
                    filled: true,
                    fillColor: AssyrianTheme.ivoryWhite,
                    helperText: 'اكتب 0 لعدم الحذف التلقائي',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال عدد الأيام';
                    }
                    final days = int.tryParse(value);
                    if (days == null || days < 0) {
                      return 'الرجاء إدخال رقم صحيح';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultsSection() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: AssyrianTheme.primaryGold,
                    size: 24.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'الإعدادات الافتراضية',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _footerController,
                style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'نص التذييل الافتراضي',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: const Icon(
                    Icons.text_fields,
                    color: AssyrianTheme.primaryGold,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _footerController.dispose();
    _deleteAfterDaysController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
