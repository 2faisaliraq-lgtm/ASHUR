import 'package:firebase_auth/firebase_auth.dart';

import 'push_notification_service.dart';
import 'settings_service.dart';

class ExpensesNotificationService {
  static const int defaultWarningDays = 7;
  static const String _shownNotificationsKey = 'shown_expenses_notifications';

  static Future<Map<String, dynamic>> _getSettings({String? uid}) async {
    try {
      final settings = await SettingsService.getExpensesSettings();

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
            'overbudgetEnabled': true,
            'recurringDueEnabled': true,
            'approvalPendingEnabled': true,
            'localEnabled': true,
            'pushEnabled': true,
            'userDisabled': true,
          };
        }
        final typeEnabled = userSettings['expenses_notify_new'] as bool?;
        if (typeEnabled != null && !typeEnabled) {
          return {
            'enabled': false,
            'warningDays':
                _getPersonalWarningDays(userSettings) ?? const [1, 2, 3],
            'overbudgetEnabled': true,
            'recurringDueEnabled': true,
            'approvalPendingEnabled': true,
            'localEnabled': true,
            'pushEnabled': true,
            'typeDisabled': true,
          };
        }
      }

      final days = settings['expensesWarningDays'] is List
          ? (settings['expensesWarningDays'] as List)
                .map((day) => int.tryParse(day.toString()) ?? 1)
                .toList()
          : const [1, 2, 3];

      return {
        'enabled': settings['expensesAlertsEnabled'] ?? false,
        'warningDays': uid != null
            ? (_getPersonalWarningDays(userSettings!) ??
                (days.isEmpty ? const [1, 2, 3] : days))
            : (days.isEmpty ? const [1, 2, 3] : days),
        'overbudgetEnabled': settings['expensesAlertOverbudgetEnabled'] ?? true,
        'recurringDueEnabled':
            settings['expensesAlertRecurringDueEnabled'] ?? true,
        'approvalPendingEnabled':
            settings['expensesAlertApprovalPendingEnabled'] ?? true,
        'localEnabled': settings['expensesAlertLocalEnabled'] ?? true,
        'pushEnabled': settings['expensesAlertPushEnabled'] ?? false,
      };
    } on Exception {
      return {
        'enabled': false,
        'warningDays': const [1, 2, 3],
        'overbudgetEnabled': true,
        'recurringDueEnabled': true,
        'approvalPendingEnabled': true,
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

  /// تتحقق من المصروفات المستحقة والمتأخرة
  static Future<void> checkAndNotifyExpenses(
    List<Map<String, dynamic>> expenses, {
    int warningDays = defaultWarningDays,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // ⚠️ ملاحظة هامة للمبرمجين المستقبليين: هذه الدالة تتوقع List<Map<String, dynamic>>
    // حيث تُستخدم الوصول عبر مفاتيح الخريطة مثل expense['dueDate'] و expense['id'].
    // لكن تُستدعى من expenses_list_page.dart مع List<ExpenseEntity> — غير type-safe لأن
    // الآن تُقبل قائمة خرائط (List<Map<String, dynamic>>) تُحوّل من ExpenseEntity
    // في صفحة الاستدعاء (expenses_list_page.dart). الحقل 'dueDate' في هذه الدالة
    // يشير إلى حقل 'date' من ExpenseEntity الذي يُعاد namingه عند التحويل.
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    final now = _normalizeDate(DateTime.now());
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final shownNotifications =
        SettingsService.getStringList(_shownNotificationsKey) ?? [];
    final warningDaysList =
        (settings['warningDays'] as List<int>? ?? const [1, 2, 3]).toSet();
    var hasChanges = false;

    for (final expense in expenses) {
      final rawDueDate = expense['date'] as DateTime?;
      if (rawDueDate == null) continue;

      final expenseId = (expense['id'] as String?) ?? 'expense';
      final dueDate = _normalizeDate(rawDueDate);
      final daysRemaining = dueDate.difference(now).inDays;
      final category = expense['category'] as String? ?? 'مصروف';
      final amount = expense['amount'] as num? ?? 0;

      // المصروفات المتأخرة - إدراج في قائمة الانتظار
      if (daysRemaining < 0) {
        if (settings['recurringDueEnabled'] as bool? ?? true) {
          final notificationId = '${expenseId}_overdue_$dayKey';
          if (!shownNotifications.contains(notificationId)) {
            try {
              await PushNotificationService.enqueueNotification(
                title: '⚠️ مصروف متأخر الاستحقاق',
                body:
                    'مصروف $category بقيمة $amount د.ع متأخر عن موعده (${_formatDate(dueDate)})!',
                type: 'expenses_alert_pending',
                scheduledAt: DateTime.now(),
                data: {
                  'expense_id': expenseId,
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

      // المصروفات القادمة أو المستحقة اليوم - إدراج في قائمة الانتظار
      if ((settings['recurringDueEnabled'] as bool? ?? true) &&
          (warningDaysList.contains(daysRemaining) || daysRemaining == 0)) {
        final notificationId = '${expenseId}_due_${dayKey}_$daysRemaining';
        if (!shownNotifications.contains(notificationId)) {
          try {
            await PushNotificationService.enqueueNotification(
              title: 'تنبيه: مصروف مستحق',
              body: daysRemaining == 0
                  ? '$category بقيمة $amount د.ع مستحق اليوم!'
                  : '$category بقيمة $amount د.ع سيستحق خلال $daysRemaining يوم (${_formatDate(dueDate)})',
              type: 'expenses_alert_pending',
              scheduledAt: DateTime.now(),
              data: {
                'expense_id': expenseId,
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

  /// تتحقق من المصروفات التي تتجاوز الميزانية
  static Future<void> checkAndNotifyOverBudget(
    Map<String, dynamic> categoryBudget,
    Map<String, dynamic> categorySpent,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings) ||
        (settings['overbudgetEnabled'] as bool? ?? true) == false) {
      return;
    }

    final now = _normalizeDate(DateTime.now());
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final shownNotifications =
        SettingsService.getStringList(_shownNotificationsKey) ?? [];
    var hasChanges = false;

    for (final category in categoryBudget.entries) {
      final budget = category.value as num? ?? 0;
      final spent = categorySpent[category.key] as num? ?? 0;

      if (spent > budget) {
        final notificationId = '${category.key}_overbudget_$dayKey';
        if (!shownNotifications.contains(notificationId)) {
          final exceeded = spent - budget;
          try {
            await PushNotificationService.enqueueNotification(
              title: 'تنبيه: تجاوز الميزانية',
              body:
                  'فئة "$category.key" تجاوزت الميزانية بـ $exceeded د.ع (الميزانية: $budget د.ع)',
              type: 'expenses_alert_pending',
              scheduledAt: DateTime.now(),
              data: {
                'category': category.key,
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

  /// إرسال إشعار عند إضافة مصروف جديد
  static Future<void> notifyNewExpense(Map<String, dynamic> expense) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    final title = expense['title'] as String? ?? 'مصروف';
    final amount = expense['amount'] as num? ?? 0;

    await PushNotificationService.showLocalExpenseAlert(
      title: '💵 تسجيل سند صرف',
      message: 'تم تسجيل مصروف جديد "$title" بمبلغ ${amount.toStringAsFixed(0)} د.ع',
      notificationId: _generateNotificationId(
        expense['id']?.toString() ?? 'expense',
        'new_exp',
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
