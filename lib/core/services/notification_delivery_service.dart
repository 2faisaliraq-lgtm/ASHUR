import 'notification_queue_service.dart';
import 'one_signal_notification_service.dart';

/// خدمة تسليم الإشعارات للمستخدمين المفعلين في المؤسسة
class NotificationDeliveryService {
  static Future<Map<String, dynamic>> sendToOrganization({
    required String orgEmail,
    required String title,
    required String body,
    required String type,
    required String actorEmail,
    String? deviceId,
    String? currentUserId,
    Map<String, String>? data,
    bool respectUserSettings = true,
  }) async {
    // Keep in-app notification history; trusted server code sends the push.
    final notificationId = await NotificationQueueService.addNotification(
      orgEmail: orgEmail,
      title: title,
      body: body,
      type: type,
      actorEmail: actorEmail,
      data: data,
    );

    try {
      await OneSignalNotificationService.sendOrganizationNotification(
        organizationEmail: orgEmail,
        title: title,
        body: body,
        type: type,
        actorEmail: actorEmail,
        data: data,
      );
    } on Exception catch (_) {
      // فشل الإرسال عبر OneSignal REST API، يتم تجاهله تاركاً السجل في الطابور فقط
    }
    return {'notificationId': notificationId, 'sent': 0, 'skipped': 0};
  }
}
