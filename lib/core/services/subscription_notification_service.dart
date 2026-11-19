import 'package:ashur/features/subscriptions/domain/entities/subscription_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import 'push_notification_service.dart';
import 'session_service.dart';
import 'settings_service.dart';

class SubscriptionNotificationService {
  static const int defaultWarningDays = 7;
  static const String _shownNotificationsKey =
      'shown_subscription_notifications';
  static const String _scheduledNotificationIdsPrefix =
      'scheduled_subscription_notification_ids_';
  static bool _timezonesInitialized = false;

  static void _ensureTimezonesInitialized() {
    if (!_timezonesInitialized) {
      tzdata.initializeTimeZones();
      _timezonesInitialized = true;
    }
  }

  static Future<String> _scheduledIdsKey(String subscriptionId) async =>
      '${await _shownNotificationsStorageKey()}_$_scheduledNotificationIdsPrefix$subscriptionId';

  static Future<void> _cancelScheduledNotifications(
    String subscriptionId,
  ) async {
    final key = await _scheduledIdsKey(subscriptionId);
    final scheduledIds = SettingsService.getStringList(key) ?? const <String>[];
    for (final id in scheduledIds) {
      final parsedId = int.tryParse(id);
      if (parsedId != null) {
        await PushNotificationService.cancelScheduledSubscriptionAlert(
          parsedId,
        );
      }
    }
    await SettingsService.setStringList(key, []);

    // Also clear ids generated before scheduled-id tracking was added.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    final warningDays = <int>{
      0,
      ...(settings['warningDays'] as List<int>? ?? const [1, 2, 3]),
      settings['reminderDaysBefore'] as int? ?? defaultWarningDays,
    };
    for (final days in warningDays) {
      await PushNotificationService.cancelScheduledSubscriptionAlert(
        _generateNotificationId(subscriptionId, 'expiring_$days'),
      );
      await PushNotificationService.cancelScheduledSubscriptionAlert(
        _legacyNotificationId(subscriptionId, 'expiring_$days'),
      );
    }
    await PushNotificationService.cancelScheduledSubscriptionAlert(
      _generateNotificationId(
        subscriptionId,
        'expiring_today_${_dateKey(DateTime.now())}',
      ),
    );
    await PushNotificationService.cancelScheduledSubscriptionAlert(
      _generateNotificationId(subscriptionId, 'new_sub'),
    );
    await PushNotificationService.cancelScheduledSubscriptionAlert(
      _generateNotificationId(subscriptionId, 'renew_sub'),
    );
  }

  static Future<void> _cancelAllForSubscriptions(
    Iterable<SubscriptionEntity> subscriptions,
  ) async {
    for (final subscription in subscriptions) {
      await _cancelScheduledNotifications(subscription.id);
    }
  }

  static Future<void> _rememberScheduledNotification(
    String subscriptionId,
    int notificationId,
  ) async {
    final key = await _scheduledIdsKey(subscriptionId);
    final ids = List<String>.from(
      SettingsService.getStringList(key) ?? const [],
    );
    final id = notificationId.toString();
    if (!ids.contains(id)) {
      ids.add(id);
      await SettingsService.setStringList(key, ids);
    }
  }

  static Future<String> _shownNotificationsStorageKey() async {
    final deviceId = await SettingsService.getDeviceId();
    final switchedUser = await SessionService.getSwitchedUser();
    final userId = switchedUser?['id']?.toString();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final scopedUserId =
        uid ?? (userId?.isNotEmpty == true ? userId! : 'default');
    return '${_shownNotificationsKey}_${deviceId}_$scopedUserId';
  }

  /// مفتاح تتبع الإشعارات على مستوى المستخدم فقط (أي جهاز استخدم هذا المستخدم)
  static Future<String> _userNotificationsStorageKey() async {
    final switchedUser = await SessionService.getSwitchedUser();
    final userId = switchedUser?['id']?.toString();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final scopedUserId =
        uid ?? (userId?.isNotEmpty == true ? userId! : 'default');
    return '${_shownNotificationsKey}_user_$scopedUserId';
  }

  static int _legacyNotificationId(String subscriptionId, String prefix) {
    return ('$prefix:$subscriptionId'.hashCode.abs()) % 2147483647;
  }

  static Future<void> _cancelLegacyShownRecords(String subscriptionId) async {
    final shownKey = await _shownNotificationsStorageKey();
    final shown = SettingsService.getStringList(shownKey) ?? [];
    final legacyIds = <String>{
      for (final day in <int>{0, 1, 2, 3, 5, 7, 14, 30})
        _legacyNotificationId(subscriptionId, 'expiring_$day').toString(),
      _legacyNotificationId(subscriptionId, 'new_sub').toString(),
      _legacyNotificationId(subscriptionId, 'renew_sub').toString(),
    };
    final filtered = shown.where((id) => !legacyIds.contains(id)).toList();
    if (filtered.length != shown.length) {
      await SettingsService.setStringList(shownKey, filtered);
    }
  }

  static Future<Map<String, dynamic>> _getSettings({String? uid}) async {
    try {
      final settings = await SettingsService.getSubscriptionSettings();

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
            'reminderDaysBefore':
                _getPersonalReminderDaysBefore(userSettings) ??
                    defaultWarningDays,
            'renewalEnabled': false,
            'warningEnabled': false,
            'newEnabled': false,
            'expiredEnabled': false,
            'localEnabled': true,
            'pushEnabled': true,
            'localHour': 9,
            'localMinute': 0,
            'userDisabled': true,
          };
        }
        final typeEnabled = userSettings['subscription_notify_new'] as bool?;
        if (typeEnabled != null && !typeEnabled) {
          return {
            'enabled': false,
            'warningDays':
                _getPersonalWarningDays(userSettings) ?? const [1, 2, 3],
            'reminderDaysBefore':
                _getPersonalReminderDaysBefore(userSettings) ??
                    defaultWarningDays,
            'renewalEnabled': false,
            'warningEnabled': false,
            'newEnabled': false,
            'expiredEnabled': false,
            'localEnabled': true,
            'pushEnabled': true,
            'localHour': 9,
            'localMinute': 0,
            'typeDisabled': true,
          };
        }
      }

      final days = settings['subscriptionWarningDays'] is List
          ? (settings['subscriptionWarningDays'] as List)
                .map((day) => int.tryParse(day.toString()) ?? 1)
                .toList()
          : const [1, 2, 3];

      return {
        'enabled': settings['subscriptionAlertsEnabled'] ?? false,
        'warningDays': uid != null
            ? (_getPersonalWarningDays(userSettings!) ??
                (days.isEmpty ? const [1, 2, 3] : days))
            : (days.isEmpty ? const [1, 2, 3] : days),
        'reminderDaysBefore': uid != null
            ? (_getPersonalReminderDaysBefore(userSettings!) ??
                settings['reminderDaysBefore'] ?? defaultWarningDays)
            : (settings['reminderDaysBefore'] ?? defaultWarningDays),
        'renewalEnabled': settings['subscriptionAlertRenewalEnabled'] ?? false,
        'warningEnabled': settings['subscriptionAlertRenewalEnabled'] ?? false,
        'newEnabled': settings['subscriptionAlertNewEnabled'] ?? false,
        'expiredEnabled': settings['subscriptionAlertExpiredEnabled'] ?? false,
        'localEnabled': settings['subscriptionAlertLocalEnabled'] ?? true,
        'pushEnabled': settings['subscriptionAlertPushEnabled'] ?? false,
        'localHour': settings['subscriptionDefaultHour'] ?? 9,
        'localMinute': settings['subscriptionDefaultMinute'] ?? 0,
      };
    } on Exception {
      return {
        'enabled': false,
        'warningDays': const [1, 2, 3],
        'reminderDaysBefore': defaultWarningDays,
        'renewalEnabled': false,
        'warningEnabled': false,
        'newEnabled': false,
        'expiredEnabled': false,
        'localEnabled': true,
        'pushEnabled': true,
        'localHour': 9,
        'localMinute': 0,
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

  /// إنشاء معرّف رقمي فريد ومحدد للإشعار لمنع التصادم والاستبدال غير المقصود
  static int _generateNotificationId(String subscriptionId, String prefix) {
    final input = '$prefix:$subscriptionId';
    var hash = 0;
    for (final codeUnit in input.codeUnits) {
      hash = ((hash << 5) - hash + codeUnit) & 0x7FFFFFFF;
    }
    return hash;
  }

  static DateTime _normalizeDate(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  static DateTime _localNow() {
    _ensureTimezonesInitialized();
    if (kIsWeb) return DateTime.now();
    return tz.TZDateTime.now(tz.local);
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  static int _calculateDaysRemaining(SubscriptionEntity subscription) {
    final now = _localNow();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = DateTime(
      subscription.endDate.year,
      subscription.endDate.month,
      subscription.endDate.day,
    );
    return endDate.difference(today).inDays;
  }

  /// دالة عامة لحساب الأيام المتبقية
  static int calculateDaysRemaining(SubscriptionEntity subscription) {
    return _calculateDaysRemaining(subscription);
  }

  /// Schedules local reminders for configured days-before-expiry and shows one
  /// immediate alert for expired subscriptions. All dates use the device's
  /// local calendar because these are device-local notifications.
  static Future<void> checkAndNotifyExpiringSoon(
    List<SubscriptionEntity> subscriptions, {
    int warningDays = defaultWarningDays,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings)) {
      await _cancelAllForSubscriptions(subscriptions);
      return;
    }

    final localNow = _localNow();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final deviceShownKey = await _shownNotificationsStorageKey();
    final userShownKey = await _userNotificationsStorageKey();
    await SettingsService.ensurePreferencesInitialized();
    // دمج الإشعارات من مستوى الجهاز ومستوى المستخدم
    final deviceShown = List<String>.from(
      SettingsService.getStringList(deviceShownKey) ?? [],
    );
    final userShown = List<String>.from(
      SettingsService.getStringList(userShownKey) ?? [],
    );
    final shownNotifications = <String>{...deviceShown, ...userShown}.toList().toList();
    final configuredDays =
        settings['warningDays'] as List<int>? ?? const <int>[1, 2, 3];
    final activeReminderDays = (settings['warningEnabled'] as bool? ?? false)
        ? (configuredDays.where((days) => days > 0).toSet().toList()..sort())
        : <int>[];
    if ((settings['warningEnabled'] as bool? ?? false) &&
        activeReminderDays.isEmpty &&
        warningDays > 0) {
      activeReminderDays.add(warningDays);
    }
    final alreadyShown = shownNotifications.toSet();
    final processedSubscriptionIds = <String>{};
    var hasChanges = false;

    for (final subscription in subscriptions) {
      if (processedSubscriptionIds.contains(subscription.id)) continue;
      processedSubscriptionIds.add(subscription.id);
      final endDate = _normalizeDate(subscription.endDate);
      final subPrefix = '${subscription.id}_${_dateKey(endDate)}';

      if (subscription.status == 'cancelled' ||
          subscription.status == 'suspended' ||
          subscription.status == 'pending') {
        await _cancelScheduledNotifications(subscription.id);
        continue;
      }
      if (subscription.status != 'active' && subscription.status != 'expired') {
        await _cancelScheduledNotifications(subscription.id);
        continue;
      }

      final daysRemaining = endDate.difference(today).inDays;
      final isExpired = subscription.status == 'expired' || daysRemaining < 0;

      if (isExpired) {
        await _cancelScheduledNotifications(subscription.id);
        await _cancelLegacyShownRecords(subscription.id);
        if (!(settings['expiredEnabled'] as bool? ?? false)) continue;
        final expiryPrefix = 'expired_$subPrefix';
        final expiryKey = expiryPrefix;
        final legacyExpiryKey = _legacyNotificationId(
          subscription.id,
          expiryPrefix,
        ).toString();
        if (alreadyShown.contains(expiryKey) ||
            alreadyShown.contains(legacyExpiryKey)) {
          continue;
        }

        final expiryNotificationId = _generateNotificationId(
          subscription.id,
          expiryPrefix,
        );
        try {
          await PushNotificationService.showLocalSubscriptionAlert(
            title: 'انتهى الاشتراك',
            message:
                'انتهى اشتراك ${subscription.customerName ?? 'المشترك'} بتاريخ ${_formatDate(subscription.endDate)}. يرجى مراجعة التجديد.',
            notificationId: expiryNotificationId,
            payload: 'subscriptions',
            respectSettings: false,
          );
        } on FirebaseException catch (error) {
          if (error.code != 'not-found') rethrow;
          continue;
        }
        await _rememberScheduledNotification(
          subscription.id,
          expiryNotificationId,
        );
        shownNotifications.add(expiryKey);
        shownNotifications.add(legacyExpiryKey);
        alreadyShown.add(expiryKey);
        alreadyShown.add(legacyExpiryKey);
        hasChanges = true;
        continue;
      }

      if (subscription.status != 'active' ||
          !(settings['renewalEnabled'] as bool? ?? false)) {
        await _cancelScheduledNotifications(subscription.id);
        continue;
      }

      // Schedule each selected warning threshold at endDate - N days. Do not
      // wait until that exact day to schedule: the app may not be foregrounded.
      for (final daysBefore in activeReminderDays) {
        if (daysRemaining < daysBefore) continue;
        if (!(settings['warningEnabled'] as bool? ?? false)) continue;
        final reminderPrefix = 'expiring_${daysBefore}_$subPrefix';
        final reminderKey = reminderPrefix;
        if (alreadyShown.contains(reminderKey)) continue;

        final localEndDate = _normalizeDate(subscription.endDate);
        final warningDate = tz.TZDateTime(
          tz.local,
          localEndDate.year,
          localEndDate.month,
          localEndDate.day - daysBefore,
          settings['localHour'] as int? ?? 9,
          settings['localMinute'] as int? ?? 0,
        );
        if (!warningDate.isAfter(tz.TZDateTime.now(tz.local))) continue;
        final notificationId = _generateNotificationId(
          subscription.id,
          reminderPrefix,
        );
        final wasScheduled =
            await PushNotificationService.scheduleLocalSubscriptionAlert(
          title: 'اشتراك يقترب من الانتهاء',
          message:
              'اشتراك ${subscription.customerName ?? 'المشترك'} ينتهي خلال $daysBefore يوم. تاريخ الانتهاء: ${_formatDate(subscription.endDate)}.',
          scheduledDate: warningDate,
          notificationId: notificationId,
          payload: 'subscriptions',
          respectSettings: false,
        );
        if (!wasScheduled) continue;
        await _rememberScheduledNotification(subscription.id, notificationId);
        shownNotifications.add(reminderKey);
        alreadyShown.add(reminderKey);
        hasChanges = true;
        break;
      }

      if (daysRemaining == 0 &&
          (settings['renewalEnabled'] as bool? ?? false)) {
        final todayPrefix = 'expiring_today_$subPrefix';
        final todayKey = todayPrefix;
        if (!alreadyShown.contains(todayKey)) {
          final todayNotificationId = _generateNotificationId(
            subscription.id,
            todayPrefix,
          );
          try {
            await PushNotificationService.showLocalSubscriptionAlert(
              title: 'تنبيه انتهاء اشتراك',
              message:
                  'اشتراك ${subscription.customerName ?? 'المشترك'} ينتهي اليوم. راجع التجديد قبل ${_formatDateTime(subscription.endDate)}.',
              notificationId: todayNotificationId,
              payload: 'subscriptions',
              respectSettings: false,
            );
          } on FirebaseException catch (error) {
            if (error.code != 'not-found') rethrow;
            continue;
          }
          await _rememberScheduledNotification(
            subscription.id,
            todayNotificationId,
          );
          shownNotifications.add(todayKey);
          alreadyShown.add(todayKey);
          hasChanges = true;
        }
      }
    }

    if (!hasChanges) return;
    // حفظ على مستوى الجهاز ومستوى المستخدم
    final currentDeviceShown = SettingsService.getStringList(deviceShownKey) ?? [];
    final mergedDeviceShown = <String>{
      ...currentDeviceShown,
      ...shownNotifications,
    }.toList();
    final trimmedDeviceList = mergedDeviceShown.length > 200
        ? mergedDeviceShown.sublist(mergedDeviceShown.length - 200)
        : mergedDeviceShown;
    await SettingsService.setStringList(deviceShownKey, trimmedDeviceList);

    final currentUserShown = SettingsService.getStringList(userShownKey) ?? [];
    final mergedUserShown = <String>{
      ...currentUserShown,
      ...shownNotifications,
    }.toList();
    final trimmedUserList = mergedUserShown.length > 200
        ? mergedUserShown.sublist(mergedUserShown.length - 200)
        : mergedUserShown;
    await SettingsService.setStringList(userShownKey, trimmedUserList);
  }

  static String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

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

  /// إرسال إشعار عند إنشاء اشتراك جديد
  static Future<void> notifyNewSubscription(
    SubscriptionEntity subscription, {
    String? actorUid,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings) ||
        (settings['newEnabled'] as bool? ?? true) == false) {
      return;
    }

    await PushNotificationService.showLocalSubscriptionAlert(
      title: '🔄 اشتراك جديد',
      message:
          'تم إنشاء اشتراك جديد للعميل ${subscription.customerName ?? 'المشترك'} بخطة ${subscription.name}. البداية: ${_formatDateTime(subscription.startDate)}، النهاية: ${_formatDateTime(subscription.endDate)}',
      notificationId: _generateNotificationId(subscription.id, 'new_sub'),
      respectSettings: false,
    );
  }

  /// إرسال إشعار عند تجديد اشتراك
  static Future<void> notifyRenewedSubscription(
    SubscriptionEntity subscription, {
    String? actorUid,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    if (!_shouldShowLocalAlerts(settings) ||
        (settings['renewalEnabled'] as bool? ?? true) == false) {
      return;
    }

    await PushNotificationService.showLocalSubscriptionAlert(
      title: '🔄 تجديد اشتراك',
      message:
          'تم تجديد اشتراك العميل ${subscription.customerName ?? 'المشترك'} بخطة ${subscription.name}. البداية: ${_formatDateTime(subscription.startDate)}، النهاية: ${_formatDateTime(subscription.endDate)}',
      notificationId: _generateNotificationId(subscription.id, 'renew_sub'),
      respectSettings: false,
    );
  }

  /// مسح سجل الإشعارات المرسلة (للاختبار أو إعادة التعيين)
  static Future<void> clearShownNotifications() async {
    final deviceShownKey = await _shownNotificationsStorageKey();
    final userShownKey = await _userNotificationsStorageKey();
    await SettingsService.setStringList(deviceShownKey, []);
    await SettingsService.setStringList(userShownKey, []);
  }

  static Future<void> cancelSubscriptionNotifications(
    String subscriptionId,
  ) async {
    await _cancelLegacyShownRecords(subscriptionId);
    await _cancelScheduledNotifications(subscriptionId);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final settings = await _getSettings(uid: uid);
    final warningDaysList = <int>{
      0,
      ...(settings['warningDays'] as List<int>? ?? const [1, 2, 3]),
      settings['reminderDaysBefore'] as int? ?? defaultWarningDays,
    };

    for (final days in warningDaysList) {
      final notificationId = _generateNotificationId(
        subscriptionId,
        'expiring_$days',
      );
      await PushNotificationService.cancelScheduledSubscriptionAlert(
        notificationId,
      );
    }

    await PushNotificationService.cancelScheduledSubscriptionAlert(
      _generateNotificationId(subscriptionId, 'new_sub'),
    );
    await PushNotificationService.cancelScheduledSubscriptionAlert(
      _generateNotificationId(subscriptionId, 'renew_sub'),
    );

    // مسح معرّفات الإشعارات لهذا الاشتراك من سجل الجهاز والمستخدم الحالي.
    final deviceShownKey = await _shownNotificationsStorageKey();
    final userShownKey = await _userNotificationsStorageKey();
    final deviceShown = SettingsService.getStringList(deviceShownKey) ?? [];
    final userShown = SettingsService.getStringList(userShownKey) ?? [];
    final shownNotifications = <String>{...deviceShown, ...userShown}.toList();
    final notificationIdsToRemove = <String>[];
    for (final days in warningDaysList) {
      notificationIdsToRemove.add(
        _generateNotificationId(subscriptionId, 'expiring_$days').toString(),
      );
      notificationIdsToRemove.add(
        _generateNotificationId(
          subscriptionId,
          'expiring_${days}_${_dateKey(DateTime.now())}',
        ).toString(),
      );
      notificationIdsToRemove.add(
        _generateNotificationId(
          subscriptionId,
          'expiring_${days}_${_dateKey(DateTime.now().add(Duration(days: days)))}',
        ).toString(),
      );
    }
    notificationIdsToRemove.add(
      _generateNotificationId(subscriptionId, 'new_sub').toString(),
    );
    notificationIdsToRemove.add(
      _generateNotificationId(subscriptionId, 'renew_sub').toString(),
    );

    final scheduledKey = await _scheduledIdsKey(subscriptionId);
    final scheduledIds =
        SettingsService.getStringList(scheduledKey) ?? const <String>[];
    for (final scheduledId in scheduledIds) {
      final parsedId = int.tryParse(scheduledId);
      if (parsedId != null) {
        await PushNotificationService.cancelScheduledSubscriptionAlert(
          parsedId,
        );
      }
    }
    await SettingsService.setStringList(scheduledKey, []);

    final filteredNotifications = shownNotifications
        .where((id) => !id.contains('_${subscriptionId}_') && !notificationIdsToRemove.contains(id))
        .toList();
    if (filteredNotifications.length != shownNotifications.length) {
      await SettingsService.setStringList(deviceShownKey, filteredNotifications);
      await SettingsService.setStringList(userShownKey, filteredNotifications);
    }
  }

  /// قراءة أيام التنبيه الشخصية من إعدادات المستخدم
  static List<int>? _getPersonalWarningDays(Map<String, dynamic> userSettings) {
    final days = userSettings['warningDays'] as List<dynamic>?;
    if (days == null || days.isEmpty) return null;
    return days.map((day) => int.tryParse(day.toString()) ?? 1).toList();
  }

  /// قراءة أيام التذكير الشخصية من إعدادات المستخدم
  static int? _getPersonalReminderDaysBefore(
    Map<String, dynamic> userSettings,
  ) {
    return userSettings['reminderDaysBefore'] as int?;
  }
}
