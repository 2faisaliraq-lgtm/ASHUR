import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../email/email_normalization_service.dart';
import '../services/settings_service.dart';

class OneSignalNotificationService {
  static const String _appId = 'e309b00d-2d36-4285-ac55-f7b5831d731d';

  /// مفتاح REST خاص بـ OneSignal—يُحفظ في الخادم وليس داخل تطبيق Flutter.
  /// ألغِ/دوّر المفتاح الذي كان موجوداً هنا لأنه أصبح مكشوفاً ضمن مصدر التطبيق.
  static const String _restApiKey = '';

  static bool _isInitialized = false;
  static bool _hasSubscriptionObserver = false;
  static Completer<void>? _initCompleter;
  static String? _currentPlayerId;
  static final EmailNormalizationService _emailService =
      EmailNormalizationService();

  static String _normalizeOrganizationEmail(String email) {
    return _emailService.normalize(email);
  }

  /// ربط نوع الإشعار (type) بالمفتاح المقابل في إعدادات الإشعارات الشخصية
  static String _mapTypeToNotificationKey(String type) {
    switch (type) {
      // الفواتير
      case 'invoice_notify_new':
      case 'invoice':
        return 'invoice_notify_new';
      case 'invoice_notify_paid':
        return 'invoice_notify_paid';
      case 'invoice_notify_updated':
        return 'invoice_notify_updated';
      case 'invoice_notify_deleted':
        return 'invoice_notify_deleted';
      case 'invoice_notify_cash':
        return 'invoice_notify_cash';
      case 'invoice_alert_overdue':
        return 'invoice_alert_overdue';
      case 'invoice_alert_unpaid':
        return 'invoice_alert_unpaid';

      // العملاء
      case 'customer_notify_new':
      case 'customer':
        return 'customer_notify_new';
      case 'customer_notify_zero_balance':
        return 'customer_notify_zero_balance';
      case 'customer_notify_updated':
        return 'customer_notify_updated';
      case 'customer_notify_deleted':
        return 'customer_notify_deleted';
      case 'customer_notify_cash_invoice':
        return 'customer_notify_cash_invoice';
      case 'customer_alert_credit_limit':
        return 'customer_alert_credit_limit';
      case 'customer_alert_high_debt':
        return 'customer_alert_high_debt';

      // المخزون
      case 'inventory_notify_new':
      case 'inventory':
        return 'inventory_notify_new';
      case 'inventory_notify_deleted':
        return 'inventory_notify_deleted';
      case 'inventory_notify_quantity_update':
        return 'inventory_notify_quantity_update';
      case 'inventory_alert_out_of_stock':
        return 'inventory_alert_out_of_stock';
      case 'inventory_alert_low_stock':
        return 'inventory_alert_low_stock';

      // الاشتراكات
      case 'subscription_notify_new':
      case 'subscription':
        return 'subscription_notify_new';
      case 'subscription_notify_updated':
        return 'subscription_notify_updated';
      case 'subscription_notify_renewed':
        return 'subscription_notify_renewed';
      case 'subscription_notify_deleted':
        return 'subscription_notify_deleted';
      case 'subscription_alert_expired':
        return 'subscription_alert_expired';
      case 'subscription_alert_expiring_soon':
        return 'subscription_alert_expiring_soon';

      // الصيانة
      case 'maintenance_notify_new':
      case 'maintenance':
        return 'maintenance_notify_new';
      case 'maintenance_notify_updated':
        return 'maintenance_notify_updated';
      case 'maintenance_notify_deleted':
        return 'maintenance_notify_deleted';
      case 'maintenance_notify_completed':
        return 'maintenance_notify_completed';
      case 'maintenance_alert_urgent':
        return 'maintenance_alert_urgent';
      case 'maintenance_alert_overdue':
        return 'maintenance_alert_overdue';

      // التأجير
      case 'rental_notify_new':
      case 'rental':
        return 'rental_notify_new';
      case 'rental_notify_updated':
        return 'rental_notify_updated';
      case 'rental_notify_deleted':
        return 'rental_notify_deleted';
      case 'rental_notify_returned':
        return 'rental_notify_returned';
      case 'rental_alert_expired':
        return 'rental_alert_expired';
      case 'rental_alert_expiring_soon':
        return 'rental_alert_expiring_soon';

      // المصروفات
      case 'expenses_notify_new':
      case 'expenses':
        return 'expenses_notify_new';
      case 'expenses_notify_updated':
        return 'expenses_notify_updated';
      case 'expenses_notify_deleted':
        return 'expenses_notify_deleted';
      case 'expenses_alert_pending':
        return 'expenses_alert_pending';

      // اختبار
      case 'test_notification':
        return 'enableNotifications';

      // افتراضي: استخدام النوع نفسه كمفتاح
      default:
        return type;
    }
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      if (kDebugMode) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await OneSignal.initialize(_appId);
      await OneSignal.Notifications.requestPermission(true);
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        event.notification.display();
      });
      if (!_hasSubscriptionObserver) {
        OneSignal.User.pushSubscription.addObserver((stateChanges) {
          final user = FirebaseAuth.instance.currentUser;
          final playerId = stateChanges.current.id;
          _currentPlayerId = playerId;
          if (user != null && playerId != null && playerId.isNotEmpty) {
            unawaited(
              _registerWithRetry(
                () => _doRegisterCurrentUserPlayerId(
                  user: user,
                  playerId: playerId,
                ),
              ).catchError((Object _) {}),
            );
          }
        });
        _hasSubscriptionObserver = true;
      }
      _isInitialized = true;
      completer.complete();

      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          unawaited(() async {
            try {
              await _registerWithRetry(() => registerCurrentUserPlayerId());
            } on Exception catch (_) {
              // إعادة التسجيل تحاول مجدداً عند تغير حالة المصادقة.
            }
          }());
        }
      });
    } on Exception catch (e) {
      final message = e.toString();
      if (message.contains('session_time')) {
        _isInitialized = false;
        completer.complete();
        _initCompleter = null;
      } else {
        completer.completeError(e);
        _initCompleter = null;
      }
    }

    return completer.future;
  }

  static Future<void> sendOrganizationNotification({
    required String organizationEmail,
    required String title,
    required String body,
    required String type,
    required String actorEmail,
    Map<String, String>? data,
    DateTime? scheduledDate,
    bool ignoreUserSettings = false,
  }) async {
    if (_restApiKey.isEmpty) {
      return;
    }

    final normalizedEmail = _normalizeOrganizationEmail(organizationEmail);

    // جلب جميع المستخدمين(Player IDs) مع فحص إعدادات الإشعارات الشخصية لكل مستخدم
    final usersSnapshot = await FirebaseFirestore.instance
        .collection(normalizedEmail)
        .doc('users')
        .collection('users')
        .get();

    final playerIds = <String>{};

    for (final doc in usersSnapshot.docs) {
      final uid = doc.id;
      final data = doc.data();

      // ⚠️ فحص إعدادات الإشعارات الشخصية للمستخدم قبل إدراجه في قائمة الإرسال
      // (تُتخطى هذه الفحوصات إذا كان ignoreUserSettings مفعلاً للإشعارات التجريبية)
      if (!ignoreUserSettings) {
        final userSettings = await SettingsService.getUserNotificationSettings(
          uid,
        );
        final notificationsEnabled =
            userSettings['enableNotifications'] as bool? ?? true;
        if (!notificationsEnabled) continue;

        // ✅ فحص نوع الإشعار المحدد للمستخدم
        final typeKey = _mapTypeToNotificationKey(type);
        final typeEnabled = userSettings[typeKey] as bool?;
        if (typeEnabled != null && !typeEnabled) continue;
      }

      // قراءة الحقل المفرد oneSignalPlayerId
      final singlePlayerId = data['oneSignalPlayerId'] as String?;
      if (singlePlayerId != null && singlePlayerId.isNotEmpty) {
        playerIds.add(singlePlayerId);
      }

      // قراءة المصفوفة oneSignalPlayerIds
      final playerIdsArray = data['oneSignalPlayerIds'] as List<dynamic>?;
      if (playerIdsArray != null) {
        for (final id in playerIdsArray) {
          if (id is String && id.isNotEmpty) {
            playerIds.add(id);
          }
        }
      }
    }

    // أضف Player ID device الحالي إذا كان موجوداً (مع فحص إعداداته الشخصية أيضاً)
    if (_currentPlayerId != null && _currentPlayerId!.isNotEmpty) {
      if (!ignoreUserSettings) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid != null) {
          final currentSettings =
              await SettingsService.getUserNotificationSettings(currentUid);
          final currentNotificationsEnabled =
              currentSettings['enableNotifications'] as bool? ?? true;
          final currentTypeKey = _mapTypeToNotificationKey(type);
          final currentTypeEnabled = currentSettings[currentTypeKey] as bool?;
          if (currentNotificationsEnabled &&
              (currentTypeEnabled == null || currentTypeEnabled)) {
            playerIds.add(_currentPlayerId!);
          }
        }
      } else {
        playerIds.add(_currentPlayerId!);
      }
    }

    if (playerIds.isEmpty) {
      return;
    }

    final requestBody = jsonEncode({
      'app_id': _appId,
      'include_player_ids': playerIds.toList(),
      'headings': {'en': title, 'ar': title},
      'contents': {'en': body, 'ar': body},
      'data': {
        'type': type,
        'actor_email': actorEmail,
        // ignore: use_null_aware_elements
        if (data != null) ...data,
      },
      if (scheduledDate != null)
        'send_after': scheduledDate.toUtc().toIso8601String(),
    });

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_restApiKey',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        return;
      }
    } on Exception catch (_) {
      // الإشعارات غير حرجة ولا توقف مسار التطبيق.
    }
  }

  static Future<String?> getCurrentUserPlayerId(String uid) async {
    final registeredPlayerId = await _getCurrentUserPlayerId(uid);
    return registeredPlayerId ?? _currentPlayerId;
  }

  static Future<String?> sendToCurrentDevice({
    required String title,
    required String body,
    required String subscriptionId,
    DateTime? scheduledDate,
    int? notificationId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return null;

    final normalizedEmail = _normalizeOrganizationEmail(user.email!);

    // جلب Player ID للمستخدم الحالي من Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection(normalizedEmail)
        .doc('users')
        .collection('users')
        .doc(user.uid)
        .get();

    final playerId = userDoc.data()?['oneSignalPlayerId'] as String?;
    if (playerId == null || playerId.isEmpty) {
      return null;
    }

    // ⚠️ فحص إعدادات الإشعارات الشخصية للمستخدم الحالي قبل الإرسال
    final currentSettings = await SettingsService.getUserNotificationSettings(
      user.uid,
    );
    final notificationsEnabled =
        currentSettings['enableNotifications'] as bool? ?? true;
    if (!notificationsEnabled) {
      return null;
    }
    final typeKey = _mapTypeToNotificationKey('subscription_notify_new');
    final typeEnabled = currentSettings[typeKey] as bool?;
    if (typeEnabled != null && !typeEnabled) {
      return null;
    }

    final requestBody = jsonEncode({
      'app_id': _appId,
      'include_player_ids': [playerId],
      'headings': {'en': title, 'ar': title},
      'contents': {'en': body, 'ar': body},
      'data': {
        'subscription_id': subscriptionId,
        'notification_id': notificationId?.toString(),
      },
      if (scheduledDate != null)
        'send_after': scheduledDate.toUtc().toIso8601String(),
    });

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_restApiKey',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        return null;
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final ids = responseData['ids'] as List<dynamic>?;
      final messageId = ids?.firstOrNull?.toString();
      return messageId;
    } on Exception catch (_) {
      return null;
    }
  }

  static Future<void> cancelScheduledNotification(String messageId) async {
    try {
      final response = await http.delete(
        Uri.parse('https://onesignal.com/api/v1/notifications/$messageId'),
        headers: {'Authorization': 'Basic $_restApiKey'},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        return;
      }
    } on Exception catch (_) {
      // تجاهل فشل إلغاء الإشعار غير الحرج.
    }
  }

  static Future<String?> getUserPlayerIdByEmail(
    String organizationEmail,
    String email,
  ) async {
    return _getUserPlayerIdByEmail(organizationEmail, email);
  }

  static Future<String?> _getCurrentUserPlayerId(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final organizationEmail = user.email;
      if (organizationEmail == null) return null;

      final normalizedEmail = _normalizeOrganizationEmail(organizationEmail);
      final doc = await FirebaseFirestore.instance
          .collection(normalizedEmail)
          .doc('users')
          .collection('users')
          .doc(uid)
          .get();

      final data = doc.data();
      return data?['oneSignalPlayerId'] as String?;
    } on Exception catch (_) {
      return null;
    }
  }

  static Future<String?> _getUserPlayerIdByEmail(
    String organizationEmail,
    String email,
  ) async {
    try {
      final normalizedEmail = _normalizeOrganizationEmail(organizationEmail);
      final doc = await FirebaseFirestore.instance
          .collection(normalizedEmail)
          .doc('users')
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (doc.docs.isEmpty) return null;
      final data = doc.docs.first.data();
      return data['oneSignalPlayerId'] as String?;
    } on Exception catch (_) {
      return null;
    }
  }

  static Future<void> registerPlayerIdForUser({
    required String uid,
    required String organizationEmail,
  }) async {
    // اشتراك OneSignal مرتبط بمالك الجهاز المسجل دخوله.
    // لا تعِد ربطه بدور أو مستخدم تم التبديل إليه مؤقتاً.
    final authenticatedUser = FirebaseAuth.instance.currentUser;
    final deviceOwnerUid = authenticatedUser?.uid ?? uid;
    final deviceOwnerOrganization =
        authenticatedUser?.email ?? organizationEmail;
    await _registerWithRetry(
      () => _doRegisterPlayerIdForUser(
        uid: deviceOwnerUid,
        organizationEmail: deviceOwnerOrganization,
      ),
    );
  }

  static Future<void> registerCurrentUserPlayerId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _registerWithRetry(() => _doRegisterCurrentUserPlayerId(user: user));
  }

  static Future<void> _doRegisterPlayerIdForUser({
    required String uid,
    required String organizationEmail,
  }) async {
    final playerId = await _waitForPlayerId();
    if (playerId == null) return;

    await _storePlayerId(
      uid: uid,
      organizationEmail: organizationEmail,
      playerId: playerId,
    );
  }

  static Future<void> _doRegisterCurrentUserPlayerId({
    required User user,
    String? playerId,
  }) async {
    final currentPlayerId = playerId ?? await _waitForPlayerId();
    if (currentPlayerId == null) return;

    final organizationEmail = user.email;
    if (organizationEmail == null) return;

    await _storePlayerId(
      uid: user.uid,
      organizationEmail: organizationEmail,
      playerId: currentPlayerId,
    );
  }

  static Future<String?> _waitForPlayerId() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null && playerId.isNotEmpty) return playerId;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  static Future<void> _storePlayerId({
    required String uid,
    required String organizationEmail,
    required String playerId,
  }) async {
    final normalizedEmail = _normalizeOrganizationEmail(organizationEmail);
    final usersRef = FirebaseFirestore.instance
        .collection(normalizedEmail)
        .doc('users')
        .collection('users');

    // ✅ لا نحذف Player ID من أي مستخدم آخر.
    // كل مستخدم يحتفظ(Player IDs) الخاصة به بشكل مستقل.
    // إزالة الحذف تمنع فقدان الإشعارات للمستخدمين الآخرين عند تسجيل مستخدم جديد.

    final docRef = usersRef.doc(uid);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      final existingData = docSnapshot.data() ?? {};
      final existingSingle = existingData['oneSignalPlayerId'] as String?;
      final existingArray =
          existingData['oneSignalPlayerIds'] as List<dynamic>?;

      final mergedIds = <String>{};
      if (existingSingle != null && existingSingle.isNotEmpty) {
        mergedIds.add(existingSingle);
      }
      if (existingArray != null) {
        for (final id in existingArray) {
          if (id is String && id.isNotEmpty) {
            mergedIds.add(id);
          }
        }
      }
      mergedIds.add(playerId);

      final firstId = mergedIds.isNotEmpty ? mergedIds.first : playerId;
      final allIds = mergedIds.toList();

      await docRef.update({
        'oneSignalPlayerId': firstId,
        'oneSignalPlayerIds': allIds,
      });
    } else {
      await docRef.set({
        'oneSignalPlayerId': playerId,
        'oneSignalPlayerIds': [playerId],
      }, SetOptions(merge: true));
    }
  }

  static Future<void> _registerWithRetry(
    Future<void> Function() operation,
  ) async {
    const maxAttempts = 3;
    const baseDelayMs = 500;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await operation();
        return;
      } on Exception catch (_) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: baseDelayMs * attempt));
      }
    }
  }
}
