import 'package:firebase_auth/firebase_auth.dart';

import 'push_notification_service.dart';
import 'settings_service.dart';

class InventoryNotificationService {
  static const String _shownNotificationsKey = 'shown_inventory_notifications';

  static Future<Map<String, dynamic>> _getSettings({String? uid}) async {
    try {
      final settings = await SettingsService.getInventorySettings();

      // ✅ فحص إعدادات الإشعارات الشخصية للمستخدم الحالي
      if (uid != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(uid);
        final notificationsEnabled = userSettings['enableNotifications'] as bool? ?? true;
        if (!notificationsEnabled) {
          return {
            'enabled': false,
            'lowStockEnabled': true,
            'outOfStockEnabled': true,
            'expiryEnabled': true,
            'localEnabled': true,
            'pushEnabled': true,
            'userDisabled': true,
          };
        }
        final typeEnabled = userSettings['inventory_notify_new'] as bool?;
        if (typeEnabled != null && !typeEnabled) {
          return {
            'enabled': false,
            'lowStockEnabled': true,
            'outOfStockEnabled': true,
            'expiryEnabled': true,
            'localEnabled': true,
            'pushEnabled': true,
            'typeDisabled': true,
          };
        }
      }

      return {
        'enabled': settings['inventoryAlertsEnabled'] ?? false,
        'lowStockEnabled': settings['inventoryAlertLowStockEnabled'] ?? true,
        'outOfStockEnabled':
            settings['inventoryAlertOutOfStockEnabled'] ?? true,
        'expiryEnabled': settings['inventoryAlertExpiryEnabled'] ?? true,
        'localEnabled': settings['inventoryAlertLocalEnabled'] ?? true,
        'pushEnabled': settings['inventoryAlertPushEnabled'] ?? false,
      };
    } on Exception {
      return {
        'enabled': false,
        'lowStockEnabled': true,
        'outOfStockEnabled': true,
        'expiryEnabled': true,
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

  /// تتحقق من المخزون المنخفض والسلع المنتهية الصلاحية
  static Future<void> checkAndNotifyInventory(
    List<Map<String, dynamic>> items,
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

    for (final item in items) {
      final itemId =
          (item['id'] as String?) ?? item['name']?.toString() ?? 'item';
      final quantity = item['quantity'] as num? ?? 0;
      final threshold = item['lowStockThreshold'] as num? ?? 10;
      final expiryDate = item['expiryDate'] as DateTime?;
      final itemName = item['name'] as String? ?? 'صنف';

      // التحقق من المخزون المنخفض - إدراج في قائمة الانتظار
      if ((settings['lowStockEnabled'] as bool? ?? true) &&
          quantity <= threshold &&
          quantity > 0) {
        final notificationId = '${itemId}_lowstock_$dayKey';
        if (!shownNotifications.contains(notificationId)) {
          try {
            await PushNotificationService.enqueueNotification(
              title: 'تنبيه: مخزون منخفض',
              body:
                  'المخزون الحالي للصنف "$itemName" ($quantity) أقل من الحد الأدنى ($threshold)',
              type: 'inventory_alert_low_stock',
              scheduledAt: DateTime.now(),
              data: {
                'item_id': itemId,
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

      // التحقق من المخزون المنتهي - إدراج في قائمة الانتظار
      if ((settings['outOfStockEnabled'] as bool? ?? true) && quantity <= 0) {
        final notificationId = '${itemId}_outofstock_$dayKey';
        if (!shownNotifications.contains(notificationId)) {
          try {
            await PushNotificationService.enqueueNotification(
              title: 'تنبيه: مخزون منتهي',
              body: 'الصنف "$itemName" انتهى من المخزون!',
              type: 'inventory_alert_out_of_stock',
              scheduledAt: DateTime.now(),
              data: {
                'item_id': itemId,
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

      // التحقق من الصلاحية - إدراج في قائمة الانتظار
      if ((settings['expiryEnabled'] as bool? ?? true) && expiryDate != null) {
        final daysUntilExpiry = expiryDate.difference(now).inDays;
        if (daysUntilExpiry <= 7 && daysUntilExpiry > 0) {
          final notificationId = '${itemId}_expiry_$dayKey';
          if (!shownNotifications.contains(notificationId)) {
            try {
              await PushNotificationService.enqueueNotification(
                title: 'تنبيه: قرب انتهاء الصلاحية',
                body:
                    'الصنف "$itemName" ينتهي صلاحيته خلال $daysUntilExpiry أيام (${_formatDate(expiryDate)})',
                type: 'inventory_alert_out_of_stock',
                scheduledAt: DateTime.now(),
                data: {
                  'item_id': itemId,
                  'organization_email': FirebaseAuth.instance.currentUser?.email ?? '',
                },
              );
            } on FirebaseException catch (_) {
              continue;
            }
            shownNotifications.add(notificationId);
            hasChanges = true;
          }
        } else if (daysUntilExpiry <= 0) {
          final notificationId = '${itemId}_expired_$dayKey';
          if (!shownNotifications.contains(notificationId)) {
            try {
              await PushNotificationService.enqueueNotification(
                title: 'تنبيه: صلاحية منتهية',
                body: 'الصنف "$itemName" انتهت صلاحيته! يجب إزالته من المخزون.',
                type: 'inventory_alert_out_of_stock',
                scheduledAt: DateTime.now(),
                data: {
                  'item_id': itemId,
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
    }

    if (hasChanges) {
      // ⚠️ إصلاح Race Condition: إعادة قراءة القائمة قبل الحفظ لضمان عدم
      // فقدان إشعارات أضافها استدعاء متوازٍ للدالة (Dart أحادي الخيط
      // لكن الفجوات async تسمح بتداخل الاستدعاءات بين القراءة والكتابة).
      final currentShown = SettingsService.getStringList(_shownNotificationsKey) ?? [];
      final merged = <String>[];
      merged.addAll(currentShown);
      merged.addAll(shownNotifications.where((id) => !currentShown.contains(id)));
      final trimmed = merged.length > 200
          ? merged.sublist(merged.length - 200)
          : merged;
      await SettingsService.setStringList(_shownNotificationsKey, trimmed);
    }
  }

  /// إرسال إشعار عند إضافة صنف مخزون جديد
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

  /// إرسال إشعار عند إضافة صنف مخزون جديد
  static Future<void> notifyNewInventoryItem(Map<String, dynamic> item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      return;
    }

    final itemName = item['name'] as String? ?? 'صنف';
    final quantity = item['quantity'] as num? ?? 0;

    await PushNotificationService.showLocalInventoryAlert(
      title: '📦 إضافة مادة جديدة',
      message: 'تمت إضافة المادة "$itemName" بكمية ($quantity) إلى المخزون',
      notificationId: _generateNotificationId(
        item['id']?.toString() ?? 'item',
        'new_item',
      ),
    );
  }

  /// مسح سجل الإشعارات المرسلة
  static Future<void> clearShownNotifications() async {
    await SettingsService.setStringList(_shownNotificationsKey, []);
  }
}
