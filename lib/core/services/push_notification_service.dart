import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../email/email_normalization_service.dart';
import 'notification_delivery_service.dart';
import 'notification_queue_service.dart';
import 'one_signal_notification_service.dart';
import 'settings_service.dart';

class PushNotificationService {
  static const String _scheduledOneSignalIdsKey =
      'scheduled_onesignal_notification_ids';

  static void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {}

  static Future<void> initialize() async {
    await OneSignalNotificationService.initialize();
  }

  static Future<void> unregisterCurrentUserToken() async {
    // Device subscriptions are maintained by the OneSignal SDK.
  }

  static Future<bool> sendOneSignalToCurrentDevice({
    required String title,
    required String message,
    int? notificationId,
    DateTime? scheduledDate,
  }) async {
    await OneSignalNotificationService.initialize();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final subscriptionId =
        await OneSignalNotificationService.getCurrentUserPlayerId(user.uid);
    if (subscriptionId == null || subscriptionId.isEmpty) {
      throw StateError('لم يتم تسجيل اشتراك الجهاز في OneSignal');
    }

    final messageId = await OneSignalNotificationService.sendToCurrentDevice(
      title: title,
      body: message,
      subscriptionId: subscriptionId,
      scheduledDate: scheduledDate,
      notificationId: notificationId,
    );
    if (scheduledDate != null && messageId == null) return false;
    if (scheduledDate != null && notificationId != null && messageId != null) {
      final entries = List<String>.from(
        SettingsService.getStringList(_scheduledOneSignalIdsKey) ?? const [],
      );
      entries.removeWhere((entry) => entry.startsWith('$notificationId:'));
      entries.add('$notificationId:$messageId');
      await SettingsService.setStringList(_scheduledOneSignalIdsKey, entries);
    }
    return scheduledDate == null || messageId != null;
  }

  static Future<bool> _isOneSignalAlertEnabled(
    String section, {
    String? uid,
  }) async {
    // ✅ فحص إعدادات الإشعارات الشخصية للمستخدم الحالي أولاً
    if (uid != null) {
      final userSettings = await SettingsService.getUserNotificationSettings(
        uid,
      );
      final notificationsEnabled =
          userSettings['enableNotifications'] as bool? ?? true;
      if (!notificationsEnabled) return false;

      final typeKey = switch (section) {
        'invoices' => 'invoice_notify_new',
        'inventory' => 'inventory_notify_new',
        'customers' => 'customer_notify_new',
        'maintenance' => 'maintenance_notify_new',
        'rentals' => 'rental_notify_new',
        'expenses' => 'expenses_notify_new',
        'subscriptions' => 'subscription_notify_new',
        _ => null,
      };
      if (typeKey != null) {
        final typeEnabled = userSettings[typeKey] as bool?;
        if (typeEnabled != null && !typeEnabled) return false;
      }
    }

    final notificationSettings =
        await SettingsService.getNotificationSettings();

    final sectionSettings = switch (section) {
      'invoices' => await SettingsService.getInvoiceSettings(),
      'inventory' => await SettingsService.getInventorySettings(),
      'customers' => await SettingsService.getCustomerSettings(),
      'maintenance' => await SettingsService.getMaintenanceSettings(),
      'rentals' => await SettingsService.getRentalSettings(),
      'expenses' => await SettingsService.getExpensesSettings(),
      'subscriptions' => await SettingsService.getSubscriptionSettings(),
      _ => null,
    };
    if (sectionSettings == null) return true;

    final masterKey = switch (section) {
      'invoices' => 'invoiceAlertsEnabled',
      'inventory' => 'inventoryAlertsEnabled',
      'customers' => 'customerAlertsEnabled',
      'maintenance' => 'maintenanceAlertsEnabled',
      'rentals' => 'rentalAlertsEnabled',
      'expenses' => 'expensesAlertsEnabled',
      'subscriptions' => 'subscriptionAlertsEnabled',
      _ => '',
    };
    final pushKey = switch (section) {
      'invoices' => 'invoiceAlertPushEnabled',
      'inventory' => 'inventoryAlertPushEnabled',
      'customers' => 'customerAlertPushEnabled',
      'maintenance' => 'maintenanceAlertPushEnabled',
      'rentals' => 'rentalAlertPushEnabled',
      'expenses' => 'expensesAlertPushEnabled',
      'subscriptions' => 'subscriptionAlertPushEnabled',
      _ => '',
    };
    return _sectionAlertEnabled(sectionSettings, masterKey, pushKey);
  }

  static bool _sectionAlertEnabled(
    Map<String, dynamic> settings,
    String masterKey,
    String pushKey,
  ) =>
      (settings[masterKey] as bool? ?? false) &&
      (settings[pushKey] as bool? ?? false);

  static Future<bool> _isOrganizationPushEnabled(
    String type, {
    String? uid,
  }) async {
    // ✅ فحص إعدادات الإشعارات الشخصية للمستخدم الحالي أولاً
    if (uid != null) {
      final userSettings = await SettingsService.getUserNotificationSettings(
        uid,
      );
      final notificationsEnabled =
          userSettings['enableNotifications'] as bool? ?? true;
      if (!notificationsEnabled) return false;

      final typeKey = switch (type) {
        'invoice_created' ||
        'invoice_updated' ||
        'invoice_deleted' ||
        'invoice_paid' ||
        'invoice_cash' => 'invoice_notify_new',
        'inventory_product_created' ||
        'inventory_product_deleted' ||
        'inventory_quantity_updated' => 'inventory_notify_new',
        'customer_created' ||
        'customer_updated' ||
        'customer_deleted' ||
        'customer_zero_balance' ||
        'customer_cash_invoice' => 'customer_notify_new',
        'maintenance_created' ||
        'maintenance_updated' ||
        'maintenance_deleted' ||
        'maintenance_completed' => 'maintenance_notify_new',
        'rental_created' ||
        'rental_updated' ||
        'rental_deleted' ||
        'rental_returned' => 'rental_notify_new',
        'expense_created' ||
        'expense_updated' ||
        'expense_deleted' => 'expenses_notify_new',
        'subscription_created' ||
        'subscription_updated' ||
        'subscription_deleted' ||
        'subscription_renewed' => 'subscription_notify_new',
        _ => null,
      };
      if (typeKey != null) {
        final typeEnabled = userSettings[typeKey] as bool?;
        if (typeEnabled != null && !typeEnabled) return false;
      }
    }

    final sectionKey = switch (type) {
      'invoice_created' ||
      'invoice_updated' ||
      'invoice_deleted' ||
      'invoice_paid' ||
      'invoice_cash' => 'invoices',
      'inventory_product_created' ||
      'inventory_product_deleted' ||
      'inventory_quantity_updated' => 'inventory',
      'customer_created' ||
      'customer_updated' ||
      'customer_deleted' ||
      'customer_zero_balance' ||
      'customer_cash_invoice' => 'customers',
      'maintenance_created' ||
      'maintenance_updated' ||
      'maintenance_deleted' ||
      'maintenance_completed' => 'maintenance',
      'rental_created' ||
      'rental_updated' ||
      'rental_deleted' ||
      'rental_returned' => 'rentals',
      'expense_created' || 'expense_updated' || 'expense_deleted' => 'expenses',
      'subscription_created' ||
      'subscription_updated' ||
      'subscription_deleted' ||
      'subscription_renewed' => 'subscriptions',
      _ => null,
    };
    if (sectionKey == null) return true;

    final section = switch (sectionKey) {
      'invoices' => await SettingsService.getInvoiceSettings(),
      'inventory' => await SettingsService.getInventorySettings(),
      'customers' => await SettingsService.getCustomerSettings(),
      'maintenance' => await SettingsService.getMaintenanceSettings(),
      'rentals' => await SettingsService.getRentalSettings(),
      'expenses' => await SettingsService.getExpensesSettings(),
      'subscriptions' => await SettingsService.getSubscriptionSettings(),
      _ => null,
    };
    if (section == null) return true;

    final masterKey = switch (sectionKey) {
      'invoices' => 'invoiceAlertsEnabled',
      'inventory' => 'inventoryAlertsEnabled',
      'customers' => 'customerAlertsEnabled',
      'maintenance' => 'maintenanceAlertsEnabled',
      'rentals' => 'rentalAlertsEnabled',
      'expenses' => 'expensesAlertsEnabled',
      'subscriptions' => 'subscriptionAlertsEnabled',
      _ => '',
    };
    final pushKey = switch (sectionKey) {
      'invoices' => 'invoiceAlertPushEnabled',
      'inventory' => 'inventoryAlertPushEnabled',
      'customers' => 'customerAlertPushEnabled',
      'maintenance' => 'maintenanceAlertPushEnabled',
      'rentals' => 'rentalAlertPushEnabled',
      'expenses' => 'expensesAlertPushEnabled',
      'subscriptions' => 'subscriptionAlertPushEnabled',
      _ => '',
    };
    final typeKey = switch (type) {
      'invoice_created' => 'invoice_notify_new',
      'invoice_updated' => 'invoice_notify_updated',
      'invoice_deleted' => 'invoice_notify_deleted',
      'invoice_paid' => 'invoice_notify_paid',
      'invoice_cash' => 'invoice_notify_cash',
      'customer_cash_invoice' => 'customer_notify_cash_invoice',
      'inventory_product_created' => 'inventory_notify_new',
      'inventory_product_deleted' => 'inventory_notify_deleted',
      'inventory_quantity_updated' => 'inventory_notify_quantity_update',
      'customer_created' => 'customer_notify_new',
      'customer_updated' => 'customer_notify_updated',
      'customer_deleted' => 'customer_notify_deleted',
      'customer_zero_balance' => 'customer_notify_zero_balance',
      'maintenance_created' => 'maintenance_notify_new',
      'maintenance_updated' => 'maintenance_notify_updated',
      'maintenance_deleted' => 'maintenance_notify_deleted',
      'maintenance_completed' => 'maintenance_notify_completed',
      'rental_created' => 'rental_notify_new',
      'rental_updated' => 'rental_notify_updated',
      'rental_deleted' => 'rental_notify_deleted',
      'rental_returned' => 'rental_notify_returned',
      'expense_created' => 'expenses_notify_new',
      'expense_updated' => 'expenses_notify_updated',
      'expense_deleted' => 'expenses_notify_deleted',
      'subscription_created' => 'subscription_notify_new',
      'subscription_updated' => 'subscription_notify_updated',
      'subscription_deleted' => 'subscription_notify_deleted',
      'subscription_renewed' => 'subscription_notify_renewed',
      _ => null,
    };
    return (section[masterKey] as bool? ?? false) &&
        (section[pushKey] as bool? ?? false) &&
        (typeKey == null ||
            await SettingsService.isNotificationTypeEnabled(typeKey));
  }

  static Future<void> sendOrganizationNotification({
    required String organizationEmail,
    required String title,
    required String body,
    required String type,
    required String actorEmail,
    Map<String, String>? data,
    String? uid,
  }) async {
    if (!await _isOrganizationPushEnabled(type, uid: uid)) return;
    await NotificationDeliveryService.sendToOrganization(
      orgEmail: organizationEmail,
      title: title,
      body: body,
      type: type,
      actorEmail: actorEmail,
      data: data,
      respectUserSettings: true,
    );
  }

  static Future<void> showLocalSubscriptionAlert({
    required String title,
    required String message,
    int? notificationId,
    String? payload,
    bool respectSettings = true,
    String? uid,
  }) async {
    if (respectSettings &&
        !await _isOneSignalAlertEnabled('subscriptions', uid: uid)) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final deviceId = await _getCurrentDeviceId();
    final orgEmail = user.email!;
    final notifId = notificationId?.toString() ?? '$title:$message';
    bool alreadySent;
    try {
      alreadySent =
          await NotificationQueueService.hasDeviceReceived(
            orgEmail: orgEmail,
            notificationId: notifId,
            deviceId: deviceId,
          ) ||
          await NotificationQueueService.hasUserReceived(
            orgEmail: orgEmail,
            notificationId: notifId,
            userId: user.uid,
          );
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
      alreadySent = false;
    }
    if (alreadySent) return;

    final sent = await sendOneSignalToCurrentDevice(
      title: title,
      message: message,
      notificationId: notificationId,
      scheduledDate: DateTime.now().add(const Duration(seconds: 1)),
    );
    if (!sent) return;
    await NotificationQueueService.recordDeviceReceipt(
      orgEmail: orgEmail,
      notificationId: notifId,
      deviceId: deviceId,
      userId: user.uid,
    );
    await NotificationQueueService.recordUserReceipt(
      orgEmail: orgEmail,
      notificationId: notifId,
      userId: user.uid,
      deviceId: deviceId,
    );
  }

  static Future<bool> scheduleLocalSubscriptionAlert({
    required String title,
    required String message,
    required DateTime scheduledDate,
    int? notificationId,
    String? payload,
    bool respectSettings = true,
    String? uid,
  }) async {
    if (respectSettings &&
        !await _isOneSignalAlertEnabled('subscriptions', uid: uid)) {
      return false;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;
    final deviceId = await _getCurrentDeviceId();
    final orgEmail = user.email!;
    final id =
        notificationId ??
        ((scheduledDate.millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF);
    final notifId = id.toString();
    bool alreadySent;
    try {
      alreadySent =
          await NotificationQueueService.hasDeviceReceived(
            orgEmail: orgEmail,
            notificationId: notifId,
            deviceId: deviceId,
          ) ||
          await NotificationQueueService.hasUserReceived(
            orgEmail: orgEmail,
            notificationId: notifId,
            userId: user.uid,
          );
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
      alreadySent = false;
    }
    if (alreadySent) return false;

    final effectiveDate = scheduledDate.isAfter(DateTime.now())
        ? scheduledDate
        : DateTime.now().add(const Duration(seconds: 1));
    final sent = await sendOneSignalToCurrentDevice(
      title: title,
      message: message,
      notificationId: id,
      scheduledDate: effectiveDate,
    );
    if (!sent) return false;
    await NotificationQueueService.recordDeviceReceipt(
      orgEmail: orgEmail,
      notificationId: notifId,
      deviceId: deviceId,
      userId: user.uid,
    );
    await NotificationQueueService.recordUserReceipt(
      orgEmail: orgEmail,
      notificationId: notifId,
      userId: user.uid,
      deviceId: deviceId,
    );
    return true;
  }

  static Future<void> showLocalInventoryAlert({
    required String title,
    required String message,
    int? notificationId,
    String? payload,
    String? uid,
  }) async {
    if (!await _isOneSignalAlertEnabled('inventory', uid: uid)) return;
    await sendOneSignalToCurrentDevice(title: title, message: message);
  }

  static Future<void> showLocalMaintenanceAlert({
    required String title,
    required String message,
    int? notificationId,
    String? payload,
    String? uid,
  }) async {
    if (!await _isOneSignalAlertEnabled('maintenance', uid: uid)) return;
    await sendOneSignalToCurrentDevice(title: title, message: message);
  }

  static Future<void> showLocalRentalAlert({
    required String title,
    required String message,
    int? notificationId,
    String? payload,
    String? uid,
  }) async {
    if (!await _isOneSignalAlertEnabled('rentals', uid: uid)) return;
    await sendOneSignalToCurrentDevice(title: title, message: message);
  }

  static Future<void> showLocalInvoiceAlert({
    required String title,
    required String message,
    int? notificationId,
    String? payload,
  }) async {
    if (!await _isOneSignalAlertEnabled('invoices')) return;
    await sendOneSignalToCurrentDevice(title: title, message: message);
  }

  static Future<void> showLocalExpenseAlert({
    required String title,
    required String message,
    int? notificationId,
    String? payload,
    String? uid,
  }) async {
    if (!await _isOneSignalAlertEnabled('expenses', uid: uid)) return;
    await sendOneSignalToCurrentDevice(title: title, message: message);
  }

  static Future<void> showLocalCustomerAlert({
    required String title,
    required String message,
    int? notificationId,
    String? payload,
    String? uid,
  }) async {
    if (!await _isOneSignalAlertEnabled('customers', uid: uid)) return;
    await sendOneSignalToCurrentDevice(title: title, message: message);
  }

  static Future<void> cancelScheduledSubscriptionAlert(
    int notificationId,
  ) async {
    final entries = List<String>.from(
      SettingsService.getStringList(_scheduledOneSignalIdsKey) ?? const [],
    );
    final matching = entries
        .where((entry) => entry.startsWith('$notificationId:'))
        .toList();
    for (final entry in matching) {
      final messageId = entry.substring(notificationId.toString().length + 1);
      try {
        await OneSignalNotificationService.cancelScheduledNotification(
          messageId,
        );
      } on Exception catch (_) {
        // إلغاء الإشعار المجدول لا يوقف تحديث القائمة.
      }
      entries.remove(entry);
    }
    await SettingsService.setStringList(_scheduledOneSignalIdsKey, entries);
  }

  static Future<List<int>> pendingLocalNotificationIds() async => const <int>[];

  static Future<void> enqueueNotification({
    required String title,
    required String body,
    required String type,
    required DateTime scheduledAt,
    Map<String, String>? data,
    String? uid,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final emailService = EmailNormalizationService();
    final normalizedEmail = emailService.normalize(user.email!);

    await FirebaseFirestore.instance
        .collection(normalizedEmail)
        .doc('notifications')
        .collection('queue')
        .add({
          'title': title,
          'body': body,
          'type': type,
          'scheduledAt': scheduledAt,
          'organizationEmail': normalizedEmail,
          'data': data ?? {},
          'createdAt': DateTime.now().toUtc(),
          'status': 'pending',
          if (uid != null) ...{'uid': uid},
        });
  }

  static Future<String> _getCurrentDeviceId() async {
    return SettingsService.getDeviceId();
  }
}
