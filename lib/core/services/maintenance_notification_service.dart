import 'package:firebase_auth/firebase_auth.dart';

import 'push_notification_service.dart';
import 'settings_service.dart';

class MaintenanceNotificationService {
  // ⚠️ ملاحظة للمبرمجين المستfredين: هذه الفئة معرّفة ولكنها غير مستدعاة من أي مكان
  // في قسم الصيانة حالياً. تُستدعى SectionNotificationService.checkAndNotifyMaintenance
  // من maintenance_list_page.dart بدلاً منها. إذا كانت بحاجة للتفعيل، أضف استدعاءها في
  // BLoC أو الصفحات المعنية، وإلا يمكن اعتبارها كوداً ميتاً (dead code) للإزالة مستقبلاً.
  // ✅ تم توثيق الحالة يدوياً (بدون تعديل أي منطق) — لا تُحذف الفئة لضمان التوافق
  // مع أي استدعاءات خارجية محتملة.
  static const int defaultWarningDays = 7;
  static const String _shownNotificationsKey =
      'shown_maintenance_notifications';

  static Future<Map<String, dynamic>> _getSettings({String? uid}) async {
    try {
      final settings = await SettingsService.getMaintenanceSettings();

      // ✅ فحص إعدادات الإشعارات الشخصية للمستخدم الحالي
      Map<String, dynamic>? userSettings;
      if (uid != null) {
        userSettings = await SettingsService.getUserNotificationSettings(uid);
        final notificationsEnabled =
            userSettings['enableNotifications'] as bool? ?? true;
        if (!notificationsEnabled) {
          return {
            'enabled': false,
            'warningDays':
                _getPersonalWarningDays(userSettings) ?? const [1, 2, 3],
            'overdueEnabled': true,
            'upcomingEnabled': true,
            'localEnabled': true,
            'pushEnabled': true,
            'userDisabled': true,
          };
        }
        final typeEnabled = userSettings['maintenance_notify_new'] as bool?;
        if (typeEnabled != null && !typeEnabled) {
          return {
            'enabled': false,
            'warningDays':
                _getPersonalWarningDays(userSettings) ?? const [1, 2, 3],
            'overdueEnabled': true,
            'upcomingEnabled': true,
            'localEnabled': true,
            'pushEnabled': true,
            'typeDisabled': true,
          };
        }
      }

      final days = settings['maintenanceWarningDays'] is List
          ? (settings['maintenanceWarningDays'] as List)
                .map((day) => int.tryParse(day.toString()) ?? 1)
                .toList()
          : const [1, 2, 3];

      return {
        'enabled': settings['maintenanceAlertsEnabled'] ?? false,
        'warningDays': uid != null
            ? (_getPersonalWarningDays(userSettings!) ??
                (days.isEmpty ? const [1, 2, 3] : days))
            : (days.isEmpty ? const [1, 2, 3] : days),
        'overdueEnabled': settings['maintenanceAlertOverdueEnabled'] ?? true,
        'upcomingEnabled': settings['maintenanceAlertUpcomingEnabled'] ?? true,
        'localEnabled': settings['maintenanceAlertLocalEnabled'] ?? true,
        'pushEnabled': settings['maintenanceAlertPushEnabled'] ?? false,
      };
    } on Exception {
      return {
        'enabled': false,
        'warningDays': const [1, 2, 3],
        'overdueEnabled': true,
        'upcomingEnabled': true,
        'localEnabled': true,
        'pushEnabled': true,
      };
    }
  }

  // ⚠️ ملاحظة للمبرمجين المستقبليين: دالة _generateNotificationId تستخدم hashCode
  // الذي ليس مضموناً الثبات عبر تشغيلات البرنامج. إذا احتاج النظام لمعرفات
  // إشعارات مضمونة الفريدة، يُنصح باستخدام UUID أو عداد تتابعي بدلاً من ذلك.
  // ✅ تم توثيق المخاطرة يدوياً (بدون تعديل أي منطق) — يُراعى عند إضافة معرّفات إشعارات جديدة.

  static bool _shouldShowLocalAlerts(Map<String, dynamic> settings) {
    final userDisabled = settings['userDisabled'] as bool? ?? false;
    final typeDisabled = settings['typeDisabled'] as bool? ?? false;
    if (userDisabled || typeDisabled) return false;

    final enabled = settings['enabled'] as bool? ?? false;
    final localEnabled = settings['localEnabled'] as bool? ?? true;
    return enabled && localEnabled;
  }

  static int _generateNotificationId(String id, String prefix) {
    return ('$prefix:$id'.hashCode.abs()) % 2147483647;
  }

  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// تتحقق من مواعيد الصيانة المستحقة والمتأخرة وترسل إشعارات
  static Future<void> checkAndNotifyMaintenanceDue(
    List<Map<String, dynamic>> maintenanceItems, {
    int warningDays = defaultWarningDays,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    final now = _normalizeDate(DateTime.now());
    final dayKey = '${now.year}-${now.month}-${now.day}';
    // ⚠️ ملاحظة للمبرمجين المستقبليين: SettingsService.getStringList قد ترجع قائمة
    // غير قابلة للتعديل من SharedPreferences. يجب تحويلها إلى قائمة قابلة للتعديل
    // قبل استدعاء .add() لتجنب UnsupportedError في وقت التشغيل.
    final shownNotifications = List<String>.from(
        SettingsService.getStringList(_shownNotificationsKey) ?? [],
    );
    final warningDaysList =
        (settings['warningDays'] as List<int>? ?? const [1, 2, 3]).toSet();
    var hasChanges = false;

    for (final item in maintenanceItems) {
      final rawDueDate = item['dueDate'] as DateTime?;
      if (rawDueDate == null) continue;

      final itemId = (item['id'] as String?) ?? 'maintenance';
      final dueDate = _normalizeDate(rawDueDate);
      final daysRemaining = dueDate.difference(now).inDays;
      final title = item['title'] as String? ?? 'صيانة';
      final asset = item['assetName'] as String? ?? 'المعدة';

      // معالجة الصيانة المتأخرة - إدراج في قائمة الانتظار
      if (daysRemaining < 0) {
        if (settings['overdueEnabled'] as bool? ?? true) {
          final notificationId = '${itemId}_overdue_$dayKey';
          if (!shownNotifications.contains(notificationId)) {
            try {
              await PushNotificationService.enqueueNotification(
                title: '⚠️ صيانة متأخرة: $title',
                body:
                    'صيانة $title للـ $asset متأخرة عن موعدها المحدد (${_formatDate(dueDate)})!',
                type: 'maintenance_alert_overdue',
                scheduledAt: DateTime.now(),
                data: {
                  'maintenance_id': itemId,
                  'organization_email': FirebaseAuth.instance.currentUser?.email ?? '',
                },
              );
            } on FirebaseException catch (_) {
              continue;
            }
            shownNotifications.add(notificationId);
            hasChanges = true;
          }
        }
        continue;
      }

      // معالجة الصيانة القادمة أو المستحقة اليوم - إدراج في قائمة الانتظار
      if ((settings['upcomingEnabled'] as bool? ?? true) &&
          (warningDaysList.contains(daysRemaining) || daysRemaining == 0)) {
        final notificationId = '${itemId}_due_${dayKey}_$daysRemaining';
        if (!shownNotifications.contains(notificationId)) {
          try {
            await PushNotificationService.enqueueNotification(
              title: 'تنبيه صيانة: $title',
              body: daysRemaining == 0
                  ? '$title للـ $asset مستحقة اليوم!'
                  : '$title للـ $asset ستستحق خلال $daysRemaining يوم (${_formatDate(dueDate)})',
              type: 'maintenance_alert_urgent',
              scheduledAt: DateTime.now(),
              data: {
                'maintenance_id': itemId,
                'organization_email': FirebaseAuth.instance.currentUser?.email ?? '',
              },
            );
          } on FirebaseException catch (_) {
            continue;
          }
          shownNotifications.add(notificationId);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      final trimmed = shownNotifications.length > 200
          ? shownNotifications.sublist(shownNotifications.length - 200)
          : shownNotifications;
      await SettingsService.setStringList(_shownNotificationsKey, trimmed);
    }
  }

  /// إرسال إشعار عند إنشاء سجل صيانة جديد
  static String _formatDate(DateTime date) {
    final monthNames = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  /// إرسال إشعار عند إنشاء سجل صيانة جديد
  static Future<void> notifyNewMaintenanceRecord(
    Map<String, dynamic> maintenance,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    final title = maintenance['title'] as String? ?? 'صيانة';
    final customerName = maintenance['customerName'] as String? ?? 'العميل';

    await PushNotificationService.showLocalMaintenanceAlert(
      title: '🛠️ طلب صيانة جديد',
      message: 'تم تسجيل طلب صيانة جديد "$title" للعميل $customerName',
      notificationId: _generateNotificationId(
        maintenance['id']?.toString() ?? 'maintenance',
        'new_maint',
      ),
    );
  }

  /// مسح سجل الإشعارات المرسلة
  static Future<void> clearShownNotifications() async {
    await SettingsService.setStringList(_shownNotificationsKey, []);
  }

  /// قراءة أيام التنبيه الشخصية من إعدادات المستخدم
  static List<int>? _getPersonalWarningDays(Map<String, dynamic> userSettings) {
    final days = userSettings['warningDays'] as List<dynamic>?;
    if (days == null || days.isEmpty) return null;
    return days.map((day) => int.tryParse(day.toString()) ?? 1).toList();
  }
}
