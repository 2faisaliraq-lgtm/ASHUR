import 'package:firebase_auth/firebase_auth.dart';

import 'push_notification_service.dart';
import 'settings_service.dart';

class RentalNotificationService {
  static const int defaultWarningDays = 7;
  static const String _shownNotificationsKey = 'shown_rental_notifications';

  static Future<Map<String, dynamic>> _getSettings({String? uid}) async {
    try {
      final settings = await SettingsService.getRentalSettings();

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
            'expiringEnabled': true,
            'returnEnabled': false,
            'localEnabled': true,
            'pushEnabled': true,
            'userDisabled': true,
          };
        }
        final typeEnabled = userSettings['rental_notify_new'] as bool?;
        if (typeEnabled != null && !typeEnabled) {
          return {
            'enabled': false,
            'warningDays':
                _getPersonalWarningDays(userSettings) ?? const [1, 2, 3],
            'overdueEnabled': true,
            'upcomingEnabled': true,
            'expiringEnabled': true,
            'returnEnabled': false,
            'localEnabled': true,
            'pushEnabled': true,
            'typeDisabled': true,
          };
        }
      }

      final days = settings['rentalWarningDays'] is List
          ? (settings['rentalWarningDays'] as List)
                .map((day) => int.tryParse(day.toString()) ?? 1)
                .toList()
          : const [1, 2, 3];

      return {
        'enabled': settings['rentalAlertsEnabled'] ?? settings['enableRentalTracking'] ?? false,
        'warningDays': uid != null
            ? (_getPersonalWarningDays(userSettings!) ??
                (days.isEmpty ? const [1, 2, 3] : days))
            : (days.isEmpty ? const [1, 2, 3] : days),
        'overdueEnabled': settings['rentalAlertOverdueEnabled'] ?? settings['rental_alert_expired'] ?? true,
        'upcomingEnabled': settings['rentalAlertUpcomingEnabled'] ?? settings['rental_notify_new'] ?? true,
        'expiringEnabled': settings['rentalAlertExpiringEnabled'] ?? settings['rental_alert_expiring_soon'] ?? true,
        'returnEnabled': settings['rental_notify_returned'] ?? false,
        'localEnabled': settings['rentalAlertLocalEnabled'] ?? true,
        'pushEnabled': settings['rentalAlertPushEnabled'] ?? false,
      };
    } on Exception {
      return {
        'enabled': false,
        'warningDays': const [1, 2, 3],
        'overdueEnabled': true,
        'upcomingEnabled': true,
        'expiringEnabled': true,
        'returnEnabled': false,
        'localEnabled': true,
        'pushEnabled': true,
      };
    }
  }

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

  /// ملاحظة للمبرمجين المستقبليين: المعلمة warningDays غير مستخدمة؛ تُستخدم قيمة الإعدادات بدلاً منها.
  /// كما أن hashCode المستخدم في _generateNotificationId قد يتصادم لمعرفات مختلفة،
  /// مما قد يخفي إشعاراً عن آخر. تُستخدم shownNotifications في الذاكرة وتُحفظ في النهاية،
  /// لذا عملية متزامنة قد تُOverwrite سجل الإشعارات المعروضة.
  ///
  /// ⚠️ تحذير: SettingsService.getStringList قد تُعيد قائمة غير قابلة للتعديل (immutable)،
  /// وعند استدعاء shownNotifications.add() في الأسطر 95 و114 قد ينهار التطبيق.
  /// يُفضل تحويل القائمة إلى قائمة قابلة للتعديل باستخدام ``List<String>.from``.
  static Future<void> checkAndNotifyRentalsDue(
    List<Map<String, dynamic>> rentals, {
    int warningDays = defaultWarningDays,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    final now = _normalizeDate(DateTime.now());
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final shownNotifications =
        List<String>.from(SettingsService.getStringList(_shownNotificationsKey) ?? []);
    final warningDaysList =
        (settings['warningDays'] as List<int>? ?? const [1, 2, 3]).toSet();
    var hasChanges = false;

    for (final rental in rentals) {
      final rawDueDate = rental['dueDate'] as DateTime?;
      if (rawDueDate == null) continue;

      final rentalId = (rental['id'] as String?) ?? 'rental';
      final dueDate = _normalizeDate(rawDueDate);
      final daysRemaining = dueDate.difference(now).inDays;
      final tenantName = rental['tenantName'] as String? ?? 'المستأجر';
      final amount = rental['amount'] as num? ?? 0;

      // الإيجارات المتأخرة
      if (daysRemaining < 0) {
        if (settings['overdueEnabled'] as bool? ?? true) {
          final notificationId = '${rentalId}_overdue_$dayKey';
          if (!shownNotifications.contains(notificationId)) {
            await _sendOverdueRentalNotification(
              rentalId,
              tenantName,
              amount,
              dueDate,
            );
            shownNotifications.add(notificationId);
            hasChanges = true;
          }
        }
        continue;
      }

      // الإيجارات القادمة أو المستحقة اليوم
      if ((settings['upcomingEnabled'] as bool? ?? true) &&
          (warningDaysList.contains(daysRemaining) || daysRemaining == 0)) {
        final notificationId = '${rentalId}_due_${dayKey}_$daysRemaining';
        if (!shownNotifications.contains(notificationId)) {
          await _sendRentalNotification(
            rentalId,
            tenantName,
            amount,
            daysRemaining,
            dueDate,
          );
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

  /// ترسل إشعار عن إيجار قريب من الاستحقاق
  static Future<void> _sendRentalNotification(
    String rentalId,
    String tenantName,
    num amount,
    int daysRemaining,
    DateTime dueDate,
  ) async {
    final title = 'تنبيه: إيجار مستحق';
    final message = daysRemaining == 0
        ? 'إيجار $tenantName بقيمة $amount د.ع مستحق اليوم!'
        : 'إيجار $tenantName بقيمة $amount د.ع سيستحق خلال $daysRemaining يوم (${_formatDate(dueDate)})';

    await PushNotificationService.showLocalRentalAlert(
      title: title,
      message: message,
      notificationId: _generateNotificationId(
        rentalId,
        'upcoming_$daysRemaining',
      ),
    );
  }

  /// ترسل إشعار عن إيجار متأخر
  static Future<void> _sendOverdueRentalNotification(
    String rentalId,
    String tenantName,
    num amount,
    DateTime dueDate,
  ) async {
    final title = '⚠️ إيجار متأخر السداد';
    final message =
        'إيجار $tenantName بقيمة $amount د.ع متأخر عن موعد استحقاقه (${_formatDate(dueDate)})!';

    await PushNotificationService.showLocalRentalAlert(
      title: title,
      message: message,
      notificationId: _generateNotificationId(rentalId, 'overdue'),
    );
  }

  /// تنسيق التاريخ بصيغة سهلة القراءة
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

  /// إرسال إشعار عند إنشاء عقد إيجار جديد
  static Future<void> notifyNewRentalContract(
    Map<String, dynamic> rental,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    final tenantName = rental['tenantName'] as String? ?? 'المستأجر';
    final itemName = rental['itemName'] as String? ?? 'المادة';
    final amount = rental['amount'] as num? ?? 0;

    await PushNotificationService.showLocalRentalAlert(
      title: '🔑 عقد إيجار جديد',
      message: 'تم إبرام عقد إيجار جديد للمستأجر "$tenantName" للمادة "$itemName"',
      notificationId: _generateNotificationId(
        rental['id']?.toString() ?? 'rental',
        'new_rent',
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
