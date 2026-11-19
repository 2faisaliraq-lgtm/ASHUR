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

/// صفحة إعدادات قسم الصيانة
class MaintenanceSettingsPage extends StatefulWidget {
  const MaintenanceSettingsPage({super.key});

  @override
  State<MaintenanceSettingsPage> createState() =>
      _MaintenanceSettingsPageState();
}

class _MaintenanceSettingsPageState extends State<MaintenanceSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canManageSettings = false;
  bool _isSaving = false;

  // إعدادات الصيانة العامة
  bool _enableMaintenanceTracking = true;
  bool _requireApprovalForRequests = true;
  bool _enableRecurringMaintenance = true;
  bool _enableMaintenanceCategories = true;
  bool _enablePriorityLevels = true;
  bool _enableMaintenanceScheduling = true;
  int _defaultResponseTimeHours = 24;
  int _criticalResponseTimeHours = 4;

  // إعدادات الموافقات والتصاريح
  bool _enableMultiLevelApproval = false;
  int _approvalLevels = 2;
  bool _enableDelegatedApproval = true;
  double _maxCostWithoutApproval = 5000;
  bool _requirePhotoEvidence = true;
  bool _enableWorkOrderGeneration = true;
  int _reminderDaysBefore = 7;
  List<int> _maintenanceWarningDays = [1, 2, 3];

  // إعدادات الإشعارات والتنبيهات
  bool _enableEmailNotifications = true;
  bool _enableSMSNotifications = false;
  bool _sendStatusUpdateNotifications = true;
  bool _sendOverdueReminders = true;
  bool _enableMaintenanceAlerts = true;
  int _overdueReminderDays = 1;

  // إشعارات وتنبيهات قسم الصيانة (معطلة افتراضياً: false)
  bool _notifyNewMaintenance = false;
  bool _notifyCompletedMaintenance = false;
  bool _notifyUpdatedMaintenance = false; // إشعار عند تحديث طلب الصيانة
  bool _notifyDeletedMaintenance = false; // إشعار عند حذف طلب الصيانة
  bool _alertUrgentMaintenance = false;
  bool _alertOverdueMaintenance = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canManageSettings = await _permissionChecker.hasPermission('maintenance_settings_manage');

    if (mounted) {
      setState(() {
        _canManageSettings = canManageSettings;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getMaintenanceSettings();
      setState(() {
        _enableMaintenanceTracking =
            settings['enableMaintenanceTracking'] ?? true;
        _requireApprovalForRequests =
            settings['requireApprovalForRequests'] ?? true;
        _enableRecurringMaintenance =
            settings['enableRecurringMaintenance'] ?? true;
        _enableMaintenanceCategories =
            settings['enableMaintenanceCategories'] ?? true;
        _enablePriorityLevels = settings['enablePriorityLevels'] ?? true;
        _enableMaintenanceScheduling =
            settings['enableMaintenanceScheduling'] ?? true;
        _defaultResponseTimeHours = settings['defaultResponseTimeHours'] ?? 24;
        _criticalResponseTimeHours = settings['criticalResponseTimeHours'] ?? 4;
        _enableMultiLevelApproval = settings['enableMultiLevelApproval'] ?? false;
        _approvalLevels = settings['approvalLevels'] ?? 2;
        _enableDelegatedApproval = settings['enableDelegatedApproval'] ?? true;
        _maxCostWithoutApproval = (settings['maxCostWithoutApproval'] ?? 5000).toDouble();
        _requirePhotoEvidence = settings['requirePhotoEvidence'] ?? true;
        _enableWorkOrderGeneration = settings['enableWorkOrderGeneration'] ?? true;
      });

      // تحميل تفضيلات إشعارات الصيانة من إعدادات المستخدم الشخصية (معطلة افتراضياً: false)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(uid);
        if (mounted) {
          setState(() {
            _notifyNewMaintenance = userSettings['maintenance_notify_new'] as bool? ?? false;
            _notifyCompletedMaintenance = userSettings['maintenance_notify_completed'] as bool? ?? false;
            _notifyUpdatedMaintenance = userSettings['maintenance_notify_updated'] as bool? ?? false;
            _notifyDeletedMaintenance = userSettings['maintenance_notify_deleted'] as bool? ?? false;
            _alertUrgentMaintenance = userSettings['maintenance_alert_urgent'] as bool? ?? false;
            _alertOverdueMaintenance = userSettings['maintenance_alert_overdue'] as bool? ?? false;

            // ✅ قراءة reminderDaysBefore من الإعدادات الشخصية إذا كانت موجودة
            final personalReminderDays =
                userSettings['reminderDaysBefore'] as int?;
            if (personalReminderDays != null) {
              _reminderDaysBefore = personalReminderDays;
            }

            // ✅ قراءة warningDays من الإعدادات الشخصية إذا كانت موجودة
            final personalWarningDays = userSettings['warningDays'] as List<dynamic>?;
            if (personalWarningDays != null && personalWarningDays.isNotEmpty) {
              _maintenanceWarningDays =
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
        'enableMaintenanceTracking': _enableMaintenanceTracking,
        'requireApprovalForRequests': _requireApprovalForRequests,
        'enableRecurringMaintenance': _enableRecurringMaintenance,
        'enableMaintenanceCategories': _enableMaintenanceCategories,
        'enablePriorityLevels': _enablePriorityLevels,
        'enableMaintenanceScheduling': _enableMaintenanceScheduling,
        'defaultResponseTimeHours': _defaultResponseTimeHours,
        'criticalResponseTimeHours': _criticalResponseTimeHours,
        'enableMultiLevelApproval': _enableMultiLevelApproval,
        'approvalLevels': _approvalLevels,
        'enableDelegatedApproval': _enableDelegatedApproval,
        'maxCostWithoutApproval': _maxCostWithoutApproval,
        'requirePhotoEvidence': _requirePhotoEvidence,
        'enableWorkOrderGeneration': _enableWorkOrderGeneration,
        'enableEmailNotifications': _enableEmailNotifications,
        'enableSMSNotifications': _enableSMSNotifications,
        'sendStatusUpdateNotifications': _sendStatusUpdateNotifications,
        'sendOverdueReminders': _sendOverdueReminders,
        'enableMaintenanceAlerts': _enableMaintenanceAlerts,
        'overdueReminderDays': _overdueReminderDays,
      };

      await SettingsService.saveMaintenanceSettings(settings);

      // حفظ تفضيلات إشعارات الصيانة
      await SettingsService.setNotificationTypeEnabled(
        'maintenance_notify_new',
        _notifyNewMaintenance,
      );
      await SettingsService.setNotificationTypeEnabled(
        'maintenance_notify_completed',
        _notifyCompletedMaintenance,
      );
      await SettingsService.setNotificationTypeEnabled(
        'maintenance_notify_updated',
        _notifyUpdatedMaintenance,
      );
      await SettingsService.setNotificationTypeEnabled(
        'maintenance_notify_deleted',
        _notifyDeletedMaintenance,
      );
      await SettingsService.setNotificationTypeEnabled(
        'maintenance_alert_urgent',
        _alertUrgentMaintenance,
      );
      await SettingsService.setNotificationTypeEnabled(
        'maintenance_alert_overdue',
        _alertOverdueMaintenance,
      );

      // ✅ حفظ أيام التنبيه والتذكير في الإعدادات الشخصية لكل مستخدم
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await SettingsService.saveUserNotificationSettings(uid, {
          'reminderDaysBefore': _reminderDaysBefore,
          'warningDays': _maintenanceWarningDays,
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
                'إعدادات الصيانة',
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
              heroTag: 'maintenance_settings_save_fab',
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
    // التحقق من الصلاحية قبل عرض الإعدادات
    if (!_canManageSettings) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'ليس لديك صلاحية إدارة إعدادات الصيانة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'يرجى التواصل مع المسؤول للحصول على الصلاحية',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadSettings(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // زر تمكين/إيقاف القسم
          const SliverToBoxAdapter(
            child: ModuleEnableToggle(
              moduleId: 'maintenance_view',
              moduleName: 'قسم الصيانة',
              moduleIcon: Icons.build,
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
                'إعدادات الصيانة',
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
                  _buildSectionHeader('الإعدادات العامة للصيانة'),
                  _buildGeneralSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات الموافقات والتصاريح'),
                  _buildApprovalSettings(),
                  const SizedBox(height: 16),

                  _buildSectionHeader('إعدادات الإشعارات والتنبيهات'),
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
      _enableMaintenanceTracking = true;
      _requireApprovalForRequests = true;
      _enableRecurringMaintenance = true;
      _enableMaintenanceCategories = true;
      _enablePriorityLevels = true;
      _enableMaintenanceScheduling = true;
      _defaultResponseTimeHours = 24;
      _criticalResponseTimeHours = 4;
      _enableMultiLevelApproval = false;
      _approvalLevels = 2;
      _enableDelegatedApproval = true;
      _maxCostWithoutApproval = 5000.0;
      _requirePhotoEvidence = true;
      _enableWorkOrderGeneration = true;
      _enableEmailNotifications = true;
      _enableSMSNotifications = false;
      _sendStatusUpdateNotifications = true;
      _sendOverdueReminders = true;
      _enableMaintenanceAlerts = true;
      _overdueReminderDays = 1;
      _notifyNewMaintenance = false;
      _notifyCompletedMaintenance = false;
      _notifyUpdatedMaintenance = false;
      _notifyDeletedMaintenance = false;
      _alertUrgentMaintenance = false;
      _alertOverdueMaintenance = false;
    });
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
                'تفعيل تتبع الصيانة',
                'تتبع جميع طلبات وأعمال الصيانة',
                _enableMaintenanceTracking,
                (value) => setState(() => _enableMaintenanceTracking = value),
                Icons.track_changes,
              ),
              _buildSwitchTile(
                'تطلب موافقة للطلبات',
                'يجب الموافقة على طلبات الصيانة قبل التنفيذ',
                _requireApprovalForRequests,
                (value) => setState(() => _requireApprovalForRequests = value),
                Icons.approval,
              ),
              _buildSwitchTile(
                'تفعيل الصيانة الدورية',
                'جدولة أعمال الصيانة الدورية والوقائية',
                _enableRecurringMaintenance,
                (value) => setState(() => _enableRecurringMaintenance = value),
                Icons.schedule,
              ),
              _buildSwitchTile(
                'تفعيل فئات الصيانة',
                'تصنيف أعمال الصيانة حسب الفئات',
                _enableMaintenanceCategories,
                (value) => setState(() => _enableMaintenanceCategories = value),
                Icons.category,
              ),
              _buildSwitchTile(
                'تفعيل مستويات الأولوية',
                'تحديد أولوية طلبات الصيانة',
                _enablePriorityLevels,
                (value) => setState(() => _enablePriorityLevels = value),
                Icons.priority_high,
              ),
              _buildSwitchTile(
                'تفعيل جدولة الصيانة',
                'جدولة مواعيد أعمال الصيانة',
                _enableMaintenanceScheduling,
                (value) => setState(() => _enableMaintenanceScheduling = value),
                Icons.event_available,
              ),
              _buildSliderTile(
                'وقت الاستجابة الافتراضي (ساعة)',
                'الوقت المتوقع للاستجابة للطلبات العادية',
                _defaultResponseTimeHours.toDouble(),
                1,
                72,
                (value) =>
                    setState(() => _defaultResponseTimeHours = value.round()),
                Icons.access_time,
              ),
              _buildSliderTile(
                'وقت الاستجابة للطوارئ (ساعة)',
                'الوقت المتوقع للاستجابة للطلبات الطارئة',
                _criticalResponseTimeHours.toDouble(),
                1,
                24,
                (value) =>
                    setState(() => _criticalResponseTimeHours = value.round()),
                Icons.emergency,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalSettings() {
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
                'تفعيل الموافقة متعددة المستويات',
                'موافقة أكثر من شخص للطلبات المكلفة',
                _enableMultiLevelApproval,
                (value) => setState(() => _enableMultiLevelApproval = value),
                Icons.layers,
              ),
              _buildSwitchTile(
                'تفعيل الموافقة المفوضة',
                'السماح بتفويض صلاحيات الموافقة',
                _enableDelegatedApproval,
                (value) => setState(() => _enableDelegatedApproval = value),
                Icons.person_add,
              ),
              _buildSwitchTile(
                'تطلب صور كدليل',
                'رفع صور للمشكلة قبل وبعد الإصلاح',
                _requirePhotoEvidence,
                (value) => setState(() => _requirePhotoEvidence = value),
                Icons.photo_camera,
              ),
              _buildSwitchTile(
                'تفعيل إنشاء أوامر العمل',
                'إنشاء أوامر عمل تفصيلية للصيانة',
                _enableWorkOrderGeneration,
                (value) => setState(() => _enableWorkOrderGeneration = value),
                Icons.work,
              ),
              _buildSliderTile(
                'مستويات الموافقة',
                'عدد مستويات الموافقة المطلوبة',
                _approvalLevels.toDouble(),
                1,
                5,
                (value) => setState(() => _approvalLevels = value.round()),
                Icons.approval,
              ),
              _buildSliderTile(
                'الحد الأقصى للتكلفة بدون موافقة',
                'أقصى مبلغ يمكن صرفه بدون موافقة',
                _maxCostWithoutApproval,
                100,
                50000,
                (value) => setState(() => _maxCostWithoutApproval = value),
                Icons.attach_money,
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
                'إشعار تسجيل طلب صيانة جديد',
                'تنبيه فوري عند استلام تذكرة صيانة جديدة',
                _notifyNewMaintenance,
                (value) => setState(() => _notifyNewMaintenance = value),
                Icons.build_circle_outlined,
              ),
              _buildSwitchTile(
                'إشعار تحديث طلب الصيانة',
                'تنبيه عند تعديل بيانات طلب صيانة موجود',
                _notifyUpdatedMaintenance,
                (value) => setState(() => _notifyUpdatedMaintenance = value),
                Icons.edit,
              ),
              _buildSwitchTile(
                'إشعار حذف طلب الصيانة',
                'تنبيه عند حذف طلب صيانة من النظام',
                _notifyDeletedMaintenance,
                (value) => setState(() => _notifyDeletedMaintenance = value),
                Icons.delete,
              ),
              _buildSwitchTile(
                'إشعار اكتمال الصيانة',
                'تنبيه عند انتهاء الصيانة وجاهزية الجهاز للتسليم',
                _notifyCompletedMaintenance,
                (value) =>
                    setState(() => _notifyCompletedMaintenance = value),
                Icons.task_alt,
              ),
              _buildSwitchTile(
                'تنبيه طلبات الصيانة العاجلة',
                'تنبيه بالطلبات ذات الأولوية القصوى',
                _alertUrgentMaintenance,
                (value) => setState(() => _alertUrgentMaintenance = value),
                Icons.priority_high,
              ),
              _buildSwitchTile(
                'تنبيه طلبات الصيانة المتأخرة',
                'تنبيه بالطلبات التي تأخرت عن موعدها المجدول',
                _alertOverdueMaintenance,
                (value) => setState(() => _alertOverdueMaintenance = value),
                Icons.running_with_errors,
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
                  'إعدادات الصيانة',
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
