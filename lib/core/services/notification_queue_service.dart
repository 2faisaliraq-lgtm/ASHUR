import 'package:cloud_firestore/cloud_firestore.dart';

/// يدير قائمة الإشعارات لكل مؤسسة مع حد أقصى 50 إشعار (الأقدم يخرج - FIFO)
class NotificationQueueService {
  static const int maxNotificationsPerOrg = 50;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// مرجع مجموعة الإشعارات لمؤسسة معينة
  static CollectionReference<Map<String, dynamic>> _orgNotifications(
      String orgEmail) {
    final normalized = orgEmail.trim().toLowerCase();
    return _db.collection(normalized).doc('notifications').collection('items');
  }

  /// مرجع أجهزة الاستلام لكل إشعار
  static CollectionReference<Map<String, dynamic>> _deviceReceipts(
      String orgEmail, String notificationId) {
    final normalized = orgEmail.trim().toLowerCase();
    return _db
        .collection(normalized)
        .doc('notifications')
        .collection('items')
        .doc(notificationId)
        .collection('device_receipts');
  }

  /// مرجع المستخدمين الذين استلموا الإشعار
  static CollectionReference<Map<String, dynamic>> _userReceipts(
      String orgEmail, String notificationId) {
    final normalized = orgEmail.trim().toLowerCase();
    return _db
        .collection(normalized)
        .doc('notifications')
        .collection('items')
        .doc(notificationId)
        .collection('user_receipts');
  }

  /// إضافة إشعار جديد إلى قائمة المؤسسة وتطبيق حد الـ 50 (FIFO)
  static Future<String> addNotification({
    required String orgEmail,
    required String title,
    required String body,
    required String type,
    required String actorEmail,
    Map<String, dynamic>? data,
  }) async {
    final orgNotifications = _orgNotifications(orgEmail);

    final docId = orgNotifications.doc().id;
    final now = DateTime.now().toUtc().toIso8601String();

    await orgNotifications.doc(docId).set({
      'id': docId,
      'title': title,
      'body': body,
      'type': type,
      'actorEmail': actorEmail,
      'createdAt': now,
      'receiversCount': 0,
      'data': data ?? {},
    });

    await _enforceOrgLimit(orgEmail);

    return docId;
  }

  /// فرض الحد الأقصى 50 إشعار لكل مؤسسة - حذف الأقدم (FIFO)
  static Future<void> _enforceOrgLimit(String orgEmail) async {
    final orgNotifications = _orgNotifications(orgEmail);

    final snapshot = await orgNotifications
        .orderBy('createdAt', descending: true)
        .get();

    if (snapshot.docs.length <= maxNotificationsPerOrg) return;

    final toDelete = snapshot.docs.skip(maxNotificationsPerOrg);
    final batch = _db.batch();

    for (final doc in toDelete) {
      final notificationId = doc.id;

      // حذفReceipts الأجهزة المرتبطة بهذا الإشعار
      final deviceReceipts = await _deviceReceipts(orgEmail, notificationId).get();
      for (final receipt in deviceReceipts.docs) {
        batch.delete(receipt.reference);
      }

      // حذفReceipts المستخدمين المرتبطة بهذا الإشعار
      final userReceipts = await _userReceipts(orgEmail, notificationId).get();
      for (final receipt in userReceipts.docs) {
        batch.delete(receipt.reference);
      }

      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// تسجيل استلام جهاز لإشعار (للتحقق قبل إعادة الإرسال)
  static Future<void> recordDeviceReceipt({
    required String orgEmail,
    required String notificationId,
    required String deviceId,
    required String userId,
  }) async {
    await _deviceReceipts(orgEmail, notificationId).doc(deviceId).set({
      'deviceId': deviceId,
      'notificationId': notificationId,
      'userId': userId,
      'receivedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// تسجيل استلام مستخدم لإشعار عبر جهاز معين
  static Future<void> recordUserReceipt({
    required String orgEmail,
    required String notificationId,
    required String userId,
    required String deviceId,
  }) async {
    final userReceiptRef = _userReceipts(orgEmail, notificationId).doc(userId);
    final doc = await userReceiptRef.get();

    if (doc.exists) {
      try {
        await userReceiptRef.update({
          'deviceIds': FieldValue.arrayUnion([deviceId]),
          'lastReceivedAt': DateTime.now().toUtc().toIso8601String(),
        });
      } on FirebaseException catch (error) {
        if (error.code != 'not-found') rethrow;
        await userReceiptRef.set({
          'userId': userId,
          'notificationId': notificationId,
          'deviceIds': [deviceId],
          'firstReceivedAt': DateTime.now().toUtc().toIso8601String(),
          'lastReceivedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } else {
      await userReceiptRef.set({
        'userId': userId,
        'notificationId': notificationId,
        'deviceIds': [deviceId],
        'firstReceivedAt': DateTime.now().toUtc().toIso8601String(),
        'lastReceivedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }

    // Notifications can be pruned by the 50-item queue limit before receipts
    // are written. The receipt itself remains valid; a missing queue parent is
    // not a delivery failure, so don't let it crash notification processing.
    try {
      await _incrementReceiversCount(orgEmail, notificationId);
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
    }
  }

  /// التحقق مما إذا كان الجهاز قد استلم هذا الإشعار سابقاً
  static Future<bool> hasDeviceReceived({
    required String orgEmail,
    required String notificationId,
    required String deviceId,
  }) async {
    final doc = await _deviceReceipts(orgEmail, notificationId)
        .doc(deviceId)
        .get();
    return doc.exists;
  }

  /// التحقق مما إذا كان المستخدم قد استلم هذا الإشعار على أي جهاز سابقاً
  static Future<bool> hasUserReceived({
    required String orgEmail,
    required String notificationId,
    required String userId,
  }) async {
    final doc = await _userReceipts(orgEmail, notificationId).doc(userId).get();
    return doc.exists;
  }

  static Future<void> _incrementReceiversCount(
      String orgEmail, String notificationId) async {
    final normalized = orgEmail.trim().toLowerCase();
    final notificationRef = _db
        .collection(normalized)
        .doc('notifications')
        .collection('items')
        .doc(notificationId);
    final notification = await notificationRef.get();
    if (!notification.exists) return;
    try {
      await notificationRef.update({
        'receiversCount': FieldValue.increment(1),
      });
    } on FirebaseException catch (error) {
      // The queue may prune old items between the existence check and update.
      if (error.code != 'not-found') rethrow;
    }
  }

  /// جلب إشعارات المؤسسة حديثة_first
  static Future<List<Map<String, dynamic>>> getOrgNotifications({
    required String orgEmail,
    int limit = 50,
  }) async {
    final snapshot = await _orgNotifications(orgEmail)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
