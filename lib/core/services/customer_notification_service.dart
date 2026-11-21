import 'package:ashur/features/customers/domain/entities/customer_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'push_notification_service.dart';
import 'settings_service.dart';

class CustomerNotificationService {
  static const String _shownNotificationsKey = 'shown_customer_notifications';

  static Future<Map<String, dynamic>> _getSettings({String? uid}) async {
    try {
      final settings = await SettingsService.getCustomerSettings();

      // ✅ فحص إعدادات الإشعارات الشخصية للمستخدم الحالي
      if (uid != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(
          uid,
        );
        final notificationsEnabled =
            userSettings['enableNotifications'] as bool? ?? true;
        if (!notificationsEnabled) {
          return {
            'enabled': false,
            'overdueCreditEnabled': false,
            'creditLimitEnabled': false,
            'newCustomerEnabled': false,
            'localEnabled': false,
            'userDisabled': true,
          };
        }
        final typeEnabled = userSettings['customer_notify_new'] as bool?;
        if (typeEnabled != null && !typeEnabled) {
          return {
            'enabled': false,
            'overdueCreditEnabled': false,
            'creditLimitEnabled': false,
            'newCustomerEnabled': false,
            'localEnabled': false,
            'typeDisabled': true,
          };
        }
      }

      return {
        'enabled': settings['enableCustomerNotifications'] ?? false,
        'overdueCreditEnabled': settings['customer_alert_high_debt'] ?? false,
        'creditLimitEnabled': settings['customer_alert_credit_limit'] ?? false,
        'newCustomerEnabled': settings['customer_notify_new'] ?? false,
        'localEnabled': settings['customer_alert_local'] ?? false,
      };
    } on Exception catch (_) {
      return {
        'enabled': false,
        'overdueCreditEnabled': false,
        'creditLimitEnabled': false,
        'newCustomerEnabled': false,
        'localEnabled': false,
      };
    }
  }

  static bool _shouldShowLocalAlerts(Map<String, dynamic> settings) {
    final userDisabled = settings['userDisabled'] as bool? ?? false;
    final typeDisabled = settings['typeDisabled'] as bool? ?? false;
    if (userDisabled || typeDisabled) return false;

    final enabled = settings['enabled'] as bool? ?? false;
    final localEnabled = settings['localEnabled'] as bool? ?? false;
    return enabled && localEnabled;
  }

  static int _generateNotificationId(String id, String prefix) {
    // ملاحظة للمبرمجين المستقبليين: لا تُستخدم String.hashCode لأنها غير مستقرة بين
    // تشغيلات التطبيق (قد تتغير القيمة في كل تشغيل)، مما يؤدي إلى فقدان تسجيل
    // الإشعارات المعروضة في SharedPreferences وظهور الإشعارات نفسها مجدداً.
    // تُستخدم دالة تجزئة ثابتة على النص لضمان ثبات المعرّف عبر التشغيلات.
    final input = '$prefix:$id';
    var hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// تتحقق من العملاء وترسل إشعارات عن ديونهم وحالتهم
  static Future<void> checkAndNotifyCustomers(
    List<CustomerEntity> customers,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final shownNotifications =
        SettingsService.getStringList(_shownNotificationsKey) ?? [];
    var hasChanges = false;

    for (final customer in customers) {
      // التحقق من العملاء ذوي الديون المتأخرة - إدراج في قائمة الانتظار
      if ((settings['overdueCreditEnabled'] as bool? ?? true) &&
          customer.totalDebt > 0) {
        final notificationId = '${customer.id}_overdue_$dayKey';
        if (!shownNotifications.contains(notificationId)) {
          try {
            await PushNotificationService.enqueueNotification(
              title: 'تنبيه: ديون مستحقة',
              body:
                  '${customer.name} عليه ديون قدرها ${customer.totalDebt.toStringAsFixed(2)} د.ع',
              type: 'customer_alert_high_debt',
              scheduledAt: DateTime.now(),
              data: {
                'customer_id': customer.id,
                'organization_email':
                    FirebaseAuth.instance.currentUser?.email ?? '',
              },
            );
          } on FirebaseException catch (_) {
            continue;
          }
          shownNotifications.add(notificationId);
          hasChanges = true;
        }
      }

      // التحقق من العملاء القريبين من حد الائتمان - إدراج في قائمة الانتظار
      if ((settings['creditLimitEnabled'] as bool? ?? true) &&
          customer.creditLimit != null &&
          customer.totalDebt > 0 &&
          customer.totalDebt > (customer.creditLimit! * 0.8)) {
        final notificationId = '${customer.id}_credit_$dayKey';
        if (!shownNotifications.contains(notificationId)) {
          try {
            await PushNotificationService.enqueueNotification(
              title: 'تنبيه: تجاوز حد الائتمان',
              body:
                  '${customer.name} تجاوز حد الائتمان (بمقدار: ${(customer.totalDebt - customer.creditLimit!).toStringAsFixed(2)} د.ع)',
              type: 'customer_alert_credit_limit',
              scheduledAt: DateTime.now(),
              data: {
                'customer_id': customer.id,
                'organization_email':
                    FirebaseAuth.instance.currentUser?.email ?? '',
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
      // ✅ ملاحظة للمبرمجين المستقبليين: إعادة قراءة القائمة قبل الحفظ ودمجها
      // مع الإشعارات الجديدة لتجنب فقدان إشعارات أضافها طلب متوازٍ.
      // بدون هذا، يمكن لطلبين متوازيين قراءة نفس القائمة، وإضافة إشعارات مختلفة،
      // ثم آخر كتابة تربح وتخسر إشعارات الطلب الأول.
      final currentShown =
          SettingsService.getStringList(_shownNotificationsKey) ?? [];
      final merged = <String>{};
      merged.addAll(currentShown);
      merged.addAll(shownNotifications);
      final trimmed = merged.toList();
      if (trimmed.length > 200) {
        trimmed.removeRange(0, trimmed.length - 200);
      }
      await SettingsService.setStringList(_shownNotificationsKey, trimmed);
    }
  }

  /// إرسال إشعار عند إنشاء عميل جديد
  static Future<void> notifyNewCustomer(CustomerEntity customer) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings) ||
        (settings['newCustomerEnabled'] as bool? ?? true) == false) {
      return;
    }

    await PushNotificationService.showLocalCustomerAlert(
      title: '👤 تسجيل عميل جديد',
      message: 'تمت إضافة العميل "${customer.name}" بنجاح إلى سجل العملاء',
      notificationId: _generateNotificationId(customer.id, 'new_cust'),
    );
  }

  /// مسح سجل الإشعارات المرسلة
  static Future<void> clearShownNotifications() async {
    await SettingsService.setStringList(_shownNotificationsKey, []);
  }
}
