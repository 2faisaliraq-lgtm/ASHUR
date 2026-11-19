import 'package:ashur/features/invoices/domain/entities/invoice_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'push_notification_service.dart';
import 'settings_service.dart';

class InvoiceNotificationService {
  static const int defaultWarningDays = 7;
  static const String _shownNotificationsKey = 'shown_invoice_notifications';

  static Future<Map<String, dynamic>> _getSettings({String? uid}) async {
    try {
      final settings = await SettingsService.getInvoiceSettings();

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
            'unpaidEnabled': true,
            'dueEnabled': true,
            'localEnabled': true,
            'pushEnabled': true,
            'userDisabled': true,
          };
        }
        final typeEnabled = userSettings['invoice_notify_new'] as bool?;
        if (typeEnabled != null && !typeEnabled) {
          return {
            'enabled': false,
            'warningDays':
                _getPersonalWarningDays(userSettings) ?? const [1, 2, 3],
            'overdueEnabled': true,
            'unpaidEnabled': true,
            'dueEnabled': true,
            'localEnabled': true,
            'pushEnabled': true,
            'typeDisabled': true,
          };
        }
      }

      final days = settings['invoiceWarningDays'] is List
          ? (settings['invoiceWarningDays'] as List)
                .map((day) => int.tryParse(day.toString()) ?? 1)
                .toList()
          : const [1, 2, 3];

      return {
        'enabled': settings['invoiceAlertsEnabled'] ?? false,
        'warningDays': uid != null
            ? (_getPersonalWarningDays(userSettings!) ??
                (days.isEmpty ? const [1, 2, 3] : days))
            : (days.isEmpty ? const [1, 2, 3] : days),
        'overdueEnabled': settings['invoiceAlertOverdueEnabled'] ?? true,
        'unpaidEnabled': settings['invoiceAlertUnpaidEnabled'] ?? true,
        'dueEnabled': settings['invoiceAlertDueEnabled'] ?? true,
        'localEnabled': settings['invoiceAlertLocalEnabled'] ?? true,
        'pushEnabled': settings['invoiceAlertPushEnabled'] ?? false,
      };
    } on Exception {
      return {
        'enabled': false,
        'warningDays': const [1, 2, 3],
        'overdueEnabled': true,
        'unpaidEnabled': true,
        'dueEnabled': true,
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

  /// تتحقق من الفواتير المستحقة الدفع والمتأخرة وترسل إشعارات عنها
  static Future<void> checkAndNotifyDueInvoices(
    List<InvoiceEntity> invoices, {
    int warningDays = defaultWarningDays,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    final now = _normalizeDate(DateTime.now());
    final dayKey = '${now.year}-${now.month}-${now.day}';
    // ✅ تم التصحيح: getStringList تعيد قائمة متزامنة (List<String>) وليس Future،
    // لذلك يُستخدم بدون await حسب التوثيق الأصلي في SettingsService.
    final shownNotifications =
        SettingsService.getStringList(_shownNotificationsKey) ?? [];
    final warningDaysList =
        (settings['warningDays'] as List<int>? ?? const [1, 2, 3]).toSet();
    var hasChanges = false;

    for (final invoice in invoices) {
      if (invoice.isPaid) {
        continue;
      }

      // حساب تاريخ الاستحقاق (بعد 30 يوم من تاريخ الفاتورة)
      final dueDate = _normalizeDate(
        invoice.invoiceDate.add(const Duration(days: 30)),
      );
      final daysRemaining = dueDate.difference(now).inDays;

      // الفواتير المتأخرة
      if (daysRemaining < 0) {
        if (settings['overdueEnabled'] as bool? ?? true) {
          final notificationId = '${invoice.id}_overdue_$dayKey';
          if (!shownNotifications.contains(notificationId)) {
            await _sendOverdueInvoiceNotification(invoice, dueDate);
            shownNotifications.add(notificationId);
            hasChanges = true;
          }
        }
        continue;
      }

      // الفواتير القادمة أو المستحقة اليوم
      if ((settings['dueEnabled'] as bool? ?? true) &&
          (warningDaysList.contains(daysRemaining) || daysRemaining == 0)) {
        final notificationId = '${invoice.id}_due_${dayKey}_$daysRemaining';
        if (!shownNotifications.contains(notificationId)) {
          await _sendInvoiceDueNotification(invoice, daysRemaining, dueDate);
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

  /// ترسل إشعار عن فاتورة قريبة من الاستحقاق
  static Future<void> _sendInvoiceDueNotification(
    InvoiceEntity invoice,
    int daysRemaining,
    DateTime dueDate,
  ) async {
    final customerName = (invoice.customerName).trim();
    final displayName = customerName.isNotEmpty ? customerName : 'عميل';

    final title = 'تنبيه فاتورة مستحقة';
    final message = daysRemaining == 0
        ? 'فاتورة #${invoice.invoiceNumber} من $displayName مستحقة اليوم! المبلغ: ${invoice.totalAmount.toStringAsFixed(2)} د.ع'
        : 'فاتورة #${invoice.invoiceNumber} من $displayName ستستحق خلال $daysRemaining يوم (${_formatDate(dueDate)})';

    await PushNotificationService.showLocalInvoiceAlert(
      title: title,
      message: message,
      notificationId: _generateNotificationId(invoice.id, 'due_$daysRemaining'),
    );
  }

  /// ترسل إشعار عن فاتورة متأخرة السداد
  static Future<void> _sendOverdueInvoiceNotification(
    InvoiceEntity invoice,
    DateTime dueDate,
  ) async {
    final customerName = (invoice.customerName).trim();
    final displayName = customerName.isNotEmpty ? customerName : 'عميل';

    final title = '⚠️ فاتورة متأخرة السداد';
    final message =
        'فاتورة #${invoice.invoiceNumber} الخاصة بـ $displayName بمبلغ ${invoice.totalAmount.toStringAsFixed(2)} د.ع متأخرة السداد منذ ${_formatDate(dueDate)}!';

    await PushNotificationService.showLocalInvoiceAlert(
      title: title,
      message: message,
      notificationId: _generateNotificationId(invoice.id, 'overdue'),
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

  /// إرسال إشعار عند إنشاء فاتورة جديدة
  static Future<void> notifyNewInvoice(InvoiceEntity invoice) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    await PushNotificationService.showLocalInvoiceAlert(
      title: '📄 فاتورة جديدة',
      message: 'تم إصدار فاتورة جديدة للعميل ${invoice.customerName} بمبلغ ${invoice.totalAmount.toStringAsFixed(0)} د.ع',
      notificationId: _generateNotificationId(invoice.id, 'new_inv'),
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
