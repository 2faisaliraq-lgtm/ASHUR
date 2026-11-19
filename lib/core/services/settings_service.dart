import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/data/repositories/setting_repository_impl.dart';
import '../../features/settings/domain/entities/setting_entity.dart';

/// وصف إعدادات النظام وإدارة الصلاحيات تفعيل وتعطيل الإشعارات اليومية
// ignore: avoid_classes_with_only_static_members
class SettingsService {
  static SharedPreferences? _preferences;

  static Future<void> _ensurePreferences() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  static const String _deviceIdKey = 'device_id';
  static String? _deviceIdCache;

  /// إنشاء معرّف الجهاز إذا لم يكن موجوداً (يتم التخزين في SharedPreferences)
  static Future<String> getDeviceId() async {
    if (_deviceIdCache != null && _deviceIdCache!.isNotEmpty) {
      return _deviceIdCache!;
    }
    await _ensurePreferences();
    _deviceIdCache = _preferences?.getString(_deviceIdKey);
    if (_deviceIdCache == null || _deviceIdCache!.isEmpty) {
      _deviceIdCache =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}';
      await _preferences?.setString(_deviceIdKey, _deviceIdCache!);
    }
    return _deviceIdCache!;
  }

  static List<String>? getStringList(String key) {
    return _preferences?.getStringList(key);
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    await _ensurePreferences();
    return _preferences?.setStringList(key, value) ?? false;
  }

  /// الحصول على حالة تفعيل شارات الأقسام
  static bool get enableSectionBadges {
    return _preferences?.getBool('enableSectionBadges') ?? false;
  }

  /// تعيين حالة تفعيل شارات الأقسام
  static Future<bool> setEnableSectionBadges(bool enabled) async {
    await _ensurePreferences();
    return _preferences?.setBool('enableSectionBadges', enabled) ?? false;
  }

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static late final SettingRepositoryImpl _repository;
  static bool _isInitialized = false;

  // ✅ تم التنبيه: يتم تهيئة _repository بواسطة دالة initialize() لتجنب خطأ LateInitializationError.
  // استدعاء SettingsService.initialize() قبل استخدام أي طريقة require تهيئة لملفات SharedPreferences.
  static bool get isInitialized => _isInitialized;

  static void initialize() {
    _repository = SettingRepositoryImpl(firestore: _firestore);
    _isInitialized = true;
  }

  static Future<void> ensurePreferencesInitialized() async {
    await _ensurePreferences();
  }

  // البريد الإلكتروني للمستخدم الحالي من بيانات المصادقة
  static String? get _currentUserEmail {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email;
  }

  /// الحصول على معلومات المؤسسة
  static Future<Map<String, String>> getOrganizationInfo() async {
    try {
      final userEmail = _currentUserEmail;
      if (userEmail == null) {
        return {
          'name': 'شركتي الجديدة',
          'phone': '07XX XXX XXXX',
          'address': 'القاهرة، مصر',
        };
      }

      final settings = await _getSettingsByCategory('organization');

      return {
        'name': settings['organization_name'] as String? ?? 'شركتي الجديدة',
        'phone': settings['organization_phone'] as String? ?? '',
        'address': settings['organization_address'] as String? ?? 'القاهرة، مصر',
      };
    } on Exception catch (_) {
      return {'name': 'شركتي الجديدة', 'phone': '', 'address': 'القاهرة، مصر'};
    }
  }

  // جلب الإعدادات حسب الفئة من مستودع الإعدادات
  static Future<Map<String, dynamic>> _getSettingsByCategory(
    String category,
  ) async {
    try {
      final userEmail = _currentUserEmail;
      if (userEmail == null) {
        return _getCachedSettings(category);
      }

      final result = await _repository.getSettingsByCategory(
        userEmail,
        category,
      );

      return await result.fold((failure) => _getCachedSettings(category), (settings) {
        final settingsMap = <String, dynamic>{};
        for (final setting in settings) {
          settingsMap[setting.key] = _parseValue(setting.value, setting.type);
        }
        _cacheSettings(category, settingsMap);
        return settingsMap;
      });
    } on Exception catch (_) {
      return _getCachedSettings(category);
    }
  }

  static Future<void> _saveSettingsByCategory(
    String category,
    Map<String, dynamic> settings,
  ) async {
    final userEmail = _currentUserEmail;
    await _cacheSettings(category, settings);

    if (userEmail == null) {
      return;
    }

    final existingResult = await _repository.getSettingsByCategory(
      userEmail,
      category,
    );

    final existingMap = <String, SettingEntity>{};
    existingResult.fold((_) {}, (list) {
      for (final s in list) {
        existingMap[s.key] = s;
      }
    });

    final operations = <Future<void>>[];

    for (final entry in settings.entries) {
      final key = entry.key;
      final value = entry.value;
      final serializedValue = _serializeValue(value);
      final valueType = _getValueType(value);

      if (existingMap.containsKey(key)) {
        final existing = existingMap[key]!;
        if (existing.value != serializedValue || existing.type != valueType) {
          final updatedSetting = existing.copyWith(
            value: serializedValue,
            type: valueType,
            updatedAt: DateTime.now(),
          );
          operations.add(_repository.updateSetting(updatedSetting));
        }
      } else {
        final newSetting = SettingEntity(
          id: '',
          organizationEmail: userEmail,
          key: key,
          value: serializedValue,
          type: valueType,
          category: category,
          description: _getSettingDescription(key),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        operations.add(_repository.createSetting(newSetting));
      }
    }

    if (operations.isNotEmpty) {
      await Future.wait(operations);
    }
  }

  static String _serializeValue(dynamic value) {
    if (value is Map || value is List) {
      try {
        return jsonEncode(value);
      } on Exception {
        return value.toString();
      }
    }
    return value.toString();
  }

  static dynamic _parseValue(String value, String type) {
    switch (type) {
      case 'boolean':
        return value.toLowerCase() == 'true' || value == 'نعم';
      case 'number':
        return num.tryParse(value) ?? 0;
      case 'list':
      case 'map':
      case 'json':
        try {
          return jsonDecode(value);
        } on Exception {
          if (type == 'list') {
            final clean = value.replaceAll('[', '').replaceAll(']', '').trim();
            if (clean.isEmpty) return <dynamic>[];
            return clean
                .split(',')
                .map((e) => num.tryParse(e.trim()) ?? e.trim())
                .toList();
          }
          return value;
        }
      default:
        // محاولة تحليل القيمة كقائمة أو كائن JSON إذا كانت تبدأ بـ [ أو {
        if (value.startsWith('[') && value.endsWith(']')) {
          try {
            return jsonDecode(value);
          } on Exception {
            final clean = value.replaceAll('[', '').replaceAll(']', '').trim();
            if (clean.isEmpty) return <dynamic>[];
            return clean
                .split(',')
                .map((e) => num.tryParse(e.trim()) ?? e.trim())
                .toList();
          }
        }
        if (value.startsWith('{') && value.endsWith('}')) {
          try {
            return jsonDecode(value);
          } on Exception {
            return value;
          }
        }
        return value;
    }
  }

  static String _getValueType(dynamic value) {
    if (value is bool) return 'boolean';
    if (value is num) return 'number';
    if (value is List) return 'list';
    if (value is Map) return 'map';
    return 'string';
  }

  static String _getCacheKey(String category) {
    final email = _currentUserEmail ?? 'anonymous';
    return 'cached_settings_${email}_$category';
  }

  static Map<String, dynamic> _getCachedSettings(String category) {
    final key = _getCacheKey(category);
    final jsonStr = _preferences?.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } on Exception {
      return {};
    }
  }

  static Future<void> _cacheSettings(
    String category,
    Map<String, dynamic> settings,
  ) async {
    final key = _getCacheKey(category);
    final jsonStr = jsonEncode(settings);
    await _preferences?.setString(key, jsonStr);
  }

  static String? _getSettingDescription(String key) {
    final descriptions = {
      // إعدادات تسجيل العملاء
      'allowCustomerRegistration': 'السماح بتسجيل العملاء',
      'requireCustomerApproval': 'يتطلب موافقة العميل',
      'enableCustomerGroups': 'تفعيل مجموعات العملاء',
      'defaultCustomerGroup': 'المجموعة الافتراضية للعملاء',

      // تتبع المخزون
      'enableStockTracking': 'تتبع المخزون',
      'lowStockThreshold': 'حد المخزون المنخفض',
      'enableBarcodeScanning': 'مسح الباركود',
      'autoUpdatePrices': 'تحديث الأسعار تلقائياً',

      // الفواتير
      'enableAutoNumbering': 'الترقيم التلقائي',
      'invoicePrefix': 'بادئة الفاتورة',
      'nextInvoiceNumber': 'رقم الفاتورة التالي',
      'enableTaxCalculation': 'حساب الضريبة',
      'defaultTaxRate': 'المعدل الافتراضي للضريبة',

      // التقارير
      'enableAutoGeneration': 'التوليد التلقائي',
      'reportRetentionDays': 'مدة الاحتفاظ بالتقارير',
      'enableEmailReports': 'التقارير عبر البريد الإلكتروني',
      'defaultReportFormat': 'تنسيق التقرير الافتراضي',

      // المصروفات
      'enableExpenseTracking': 'تتبع المصروفات',
      'requireExpenseApproval': 'الموافقة على المصروفات',
      'enableExpenseCategories': 'فئات المصروفات',
      'defaultExpenseCategory': 'الفئة الافتراضية للمصروفات',

      // الاشتراكات
      'enableAutoRenewal': 'التجديد التلقائي',
      'renewalReminderDays': 'أيام تذكير التجديد',
      'enableSubscriptionTracking': 'تتبع الاشتراكات',
      'defaultSubscriptionPlan': 'الخطة الافتراضية للاشتراك',

      // الصيانة
      'enableMaintenanceTracking': 'تتبع الصيانة',
      'maintenanceReminderDays': 'أيام تذكير الصيانة',
      'enableMaintenanceScheduling': 'جدولة الصيانة',
      'defaultMaintenanceType': 'نوع الصيانة الافتراضي',

      // الإيجارات
      'enableRentalTracking': 'تتبع الإيجارات',
      'rentalReminderDays': 'أيام تذكير الإيجار',
      'enableRentalContracts': 'عقود الإيجار',
      'defaultRentalPeriod': 'فترة الإيجار الافتراضية',

      // التنسيق
      'dateFormat': 'تنسيق التاريخ',
      'timeFormat': 'تنسيق الوقت',
      'numberFormat': 'تنسيق الأرقام',
      'currencySymbol': 'رمز العملة',
      'currencyPosition': 'موقع رمز العملة',
      'decimalPlaces': 'عدد المنازل العشرية',

      // الشركة
      'companyName': 'اسم الشركة',
      'companyAddress': 'عنوان الشركة',
      'companyPhone': 'هاتف الشركة',
      'companyEmail': 'البريد الإلكتروني للشركة',
      'systemLanguage': 'لغة النظام',
      'enableNotifications': 'تفعيل الإشعارات',
    };

    return descriptions[key];
  }

  // البريد الإلكتروني للمستخدم الحالي
  static Future<Map<String, dynamic>> getCustomerSettings() async {
    final settings = await _getSettingsByCategory('customers');
    final customerNotifications =
        settings['enableCustomerNotifications'] as bool? ?? false;
    final paymentReminders =
        settings['enablePaymentReminders'] as bool? ?? true;
    final alertsEnabled =
        settings['customerAlertsEnabled'] as bool? ??
        (customerNotifications || paymentReminders);

    return {
      'allowCustomerRegistration':
          settings['allowCustomerRegistration'] ?? true,
      'requireCustomerApproval': settings['requireCustomerApproval'] ?? false,
      'enableCustomerGroups': settings['enableCustomerGroups'] ?? true,
      'defaultCustomerGroup': settings['defaultCustomerGroup'] ?? 'افتراضي',
      'customerAlertsEnabled': alertsEnabled,
      'customerAlertOverdueCreditEnabled':
          settings['customerAlertOverdueCreditEnabled'] ?? paymentReminders,
      'customerAlertHighDebtEnabled':
          settings['customerAlertHighDebtEnabled'] ?? paymentReminders,
      'customerAlertCreditLimitEnabled':
          settings['customerAlertCreditLimitEnabled'] ?? true,
      'customerAlertNewCustomerEnabled':
          settings['customerAlertNewCustomerEnabled'] ?? true,
      'customerAlertLowActivityEnabled':
          settings['customerAlertLowActivityEnabled'] ?? true,
      'customerAlertLocalEnabled':
          settings['customerAlertLocalEnabled'] ?? true,
      'customerAlertPushEnabled': settings['customerAlertPushEnabled'] ?? true,
      ...settings,
    };
  }

  static Future<void> saveCustomerSettings(
    Map<String, dynamic> settings,
  ) async {
    await _saveSettingsByCategory('customers', settings);
  }

  static Future<Map<String, dynamic>> getInventorySettings() async {
    final settings = await _getSettingsByCategory('inventory');
    final enableLowStock =
        settings['enableLowStockAlerts'] as bool? ??
        settings['inventoryAlertLowStockEnabled'] as bool? ??
        true;
    final enableExpiry =
        settings['enableExpiryAlerts'] as bool? ??
        settings['inventoryAlertExpiryEnabled'] as bool? ??
        true;
    final alertsEnabled =
        settings['inventoryAlertsEnabled'] as bool? ??
        (enableLowStock || enableExpiry);

    return {
      'enableStockTracking': settings['enableStockTracking'] ?? true,
      'lowStockThreshold': settings['lowStockThreshold'] ?? 10,
      'enableBarcodeScanning': settings['enableBarcodeScanning'] ?? true,
      'autoUpdatePrices': settings['autoUpdatePrices'] ?? false,
      'inventoryAlertsEnabled': alertsEnabled,
      'inventoryAlertLowStockEnabled': enableLowStock,
      'inventoryAlertOutOfStockEnabled':
          settings['inventoryAlertOutOfStockEnabled'] ?? true,
      'inventoryAlertExpiryEnabled': enableExpiry,
      'inventoryAlertLocalEnabled':
          settings['inventoryAlertLocalEnabled'] ?? true,
      'inventoryAlertPushEnabled':
          settings['inventoryAlertPushEnabled'] ?? true,
      ...settings,
    };
  }

  static Future<void> saveInventorySettings(
    Map<String, dynamic> settings,
  ) async {
    await _saveSettingsByCategory('inventory', settings);
  }

  static Future<Map<String, dynamic>> getInvoiceSettings() async {
    final settings = await _getSettingsByCategory('invoices');
    final alertsEnabled = settings['invoiceAlertsEnabled'] as bool? ?? true;

    return {
      'enableAutoNumbering': settings['enableAutoNumbering'] ?? true,
      'invoicePrefix': settings['invoicePrefix'] ?? 'INV',
      'nextInvoiceNumber': settings['nextInvoiceNumber'] ?? 1,
      'enableTaxCalculation': settings['enableTaxCalculation'] ?? true,
      'defaultTaxRate': settings['defaultTaxRate'] ?? 0.0,
      'invoiceAlertsEnabled': alertsEnabled,
      'invoiceWarningDays': settings['invoiceWarningDays'] is List
          ? settings['invoiceWarningDays']
          : const [1, 2, 3],
      'invoiceAlertOverdueEnabled':
          settings['invoiceAlertOverdueEnabled'] ?? true,
      'invoiceAlertUnpaidEnabled':
          settings['invoiceAlertUnpaidEnabled'] ?? true,
      'invoiceAlertDueEnabled': settings['invoiceAlertDueEnabled'] ?? true,
      'invoiceAlertLocalEnabled': settings['invoiceAlertLocalEnabled'] ?? true,
      'invoiceAlertPushEnabled': settings['invoiceAlertPushEnabled'] ?? true,
      ...settings,
    };
  }

  static Future<void> saveInvoiceSettings(Map<String, dynamic> settings) async {
    await _saveSettingsByCategory('invoices', settings);
  }

  static Future<Map<String, dynamic>> getReportsSettings() async {
    final settings = await _getSettingsByCategory('reports');
    return {
      'enableAutoGeneration': settings['enableAutoGeneration'] ?? true,
      'reportRetentionDays': settings['reportRetentionDays'] ?? 90,
      'enableEmailReports': settings['enableEmailReports'] ?? false,
      'defaultReportFormat': settings['defaultReportFormat'] ?? 'PDF',
      ...settings,
    };
  }

  static Future<void> saveReportsSettings(Map<String, dynamic> settings) async {
    await _saveSettingsByCategory('reports', settings);
  }

  static Future<Map<String, dynamic>> getExpensesSettings() async {
    final settings = await _getSettingsByCategory('expenses');
    final budgetChecking = settings['enableBudgetChecking'] as bool? ?? true;
    final recurringExpenses =
        settings['enableRecurringExpenses'] as bool? ?? true;
    final alertsEnabled =
        settings['expensesAlertsEnabled'] as bool? ??
        (budgetChecking || recurringExpenses);

    return {
      'enableExpenseTracking': settings['enableExpenseTracking'] ?? true,
      'requireExpenseApproval': settings['requireExpenseApproval'] ?? false,
      'enableExpenseCategories': settings['enableExpenseCategories'] ?? true,
      'defaultExpenseCategory': settings['defaultExpenseCategory'] ?? 'افتراضي',
      'expensesAlertsEnabled': alertsEnabled,
      'expensesWarningDays': settings['expensesWarningDays'] is List
          ? settings['expensesWarningDays']
          : const [1, 2, 3],
      'expensesAlertOverbudgetEnabled':
          settings['expensesAlertOverbudgetEnabled'] ?? budgetChecking,
      'expensesAlertRecurringDueEnabled':
          settings['expensesAlertRecurringDueEnabled'] ?? recurringExpenses,
      'expensesAlertApprovalPendingEnabled':
          settings['expensesAlertApprovalPendingEnabled'] ?? true,
      'expensesAlertLocalEnabled':
          settings['expensesAlertLocalEnabled'] ?? true,
      'expensesAlertPushEnabled': settings['expensesAlertPushEnabled'] ?? true,
      ...settings,
    };
  }

  static Future<void> saveExpensesSettings(
    Map<String, dynamic> settings,
  ) async {
    await _saveSettingsByCategory('expenses', settings);
  }

  static Future<Map<String, dynamic>> getSubscriptionSettings() async {
    final settings = await _getSettingsByCategory('subscriptions');
    return {
      'enableAutoRenewal': settings['enableAutoRenewal'] ?? true,
      'renewalReminderDays': settings['renewalReminderDays'] ?? 7,
      'enableSubscriptionTracking':
          settings['enableSubscriptionTracking'] ?? true,
      'defaultSubscriptionPlan': settings['defaultSubscriptionPlan'] ?? 'مخصص',
      'subscriptionAlertsEnabled':
          settings['subscriptionAlertsEnabled'] ?? true,
      'subscriptionWarningDays': settings['subscriptionWarningDays'] is List
          ? settings['subscriptionWarningDays']
          : const [1, 2, 3],
      'subscriptionAlertRenewalEnabled':
          settings['subscriptionAlertRenewalEnabled'] ?? true,
      'subscriptionAlertNewEnabled':
          settings['subscriptionAlertNewEnabled'] ?? true,
      'subscriptionAlertExpiredEnabled':
          settings['subscriptionAlertExpiredEnabled'] ?? true,
      'subscriptionAlertLocalEnabled':
          settings['subscriptionAlertLocalEnabled'] ?? true,
      'subscriptionAlertPushEnabled':
          settings['subscriptionAlertPushEnabled'] ?? true,
      'subscriptionDefaultHour': settings['subscriptionDefaultHour'] ?? 0,
      'subscriptionDefaultMinute': settings['subscriptionDefaultMinute'] ?? 0,
      ...settings,
    };
  }

  static Future<void> saveSubscriptionSettings(
    Map<String, dynamic> settings,
  ) async {
    await _saveSettingsByCategory('subscriptions', settings);
  }

  static Future<Map<String, dynamic>> getMaintenanceSettings() async {
    final settings = await _getSettingsByCategory('maintenance');
    final sendReminders =
        settings['sendMaintenanceReminders'] as bool? ??
        settings['maintenanceAlertUpcomingEnabled'] as bool? ??
        true;
    final sendUrgent =
        settings['sendUrgentAlerts'] as bool? ??
        settings['maintenanceAlertOverdueEnabled'] as bool? ??
        true;
    final alertsEnabled =
        settings['maintenanceAlertsEnabled'] as bool? ??
        (sendReminders || sendUrgent);

    return {
      'enableMaintenanceTracking':
          settings['enableMaintenanceTracking'] ?? true,
      'maintenanceReminderDays': settings['maintenanceReminderDays'] ?? 30,
      'enableMaintenanceScheduling':
          settings['enableMaintenanceScheduling'] ?? true,
      'defaultMaintenanceType': settings['defaultMaintenanceType'] ?? 'تصحيحي',
      'maintenanceAlertsEnabled': alertsEnabled,
      'maintenanceWarningDays': settings['maintenanceWarningDays'] is List
          ? settings['maintenanceWarningDays']
          : [settings['reminderDaysBefore'] ?? 3, 1, 2, 3],
      'maintenanceAlertOverdueEnabled': sendUrgent,
      'maintenanceAlertUpcomingEnabled': sendReminders,
      'maintenanceAlertLocalEnabled':
          settings['maintenanceAlertLocalEnabled'] ?? true,
      'maintenanceAlertPushEnabled':
          settings['maintenanceAlertPushEnabled'] ?? true,
      ...settings,
    };
  }

  static Future<void> saveMaintenanceSettings(
    Map<String, dynamic> settings,
  ) async {
    await _saveSettingsByCategory('maintenance', settings);
  }

  static Future<Map<String, dynamic>> getRentalSettings() async {
    final settings = await _getSettingsByCategory('rentals');
    final sendRenewal = settings['sendRenewalReminders'] as bool? ?? true;
    final sendPayment = settings['sendPaymentReminders'] as bool? ?? true;
    final sendExpiry = settings['sendExpiryNotifications'] as bool? ?? true;
    final alertsEnabled =
        settings['rentalAlertsEnabled'] as bool? ??
        (sendRenewal || sendPayment || sendExpiry);

    return {
      'enableRentalTracking': settings['enableRentalTracking'] ?? true,
      'rentalReminderDays': settings['rentalReminderDays'] ?? 7,
      'enableRentalContracts': settings['enableRentalContracts'] ?? true,
      'defaultRentalPeriod': settings['defaultRentalPeriod'] ?? 'شهري',
      'rentalAlertsEnabled': alertsEnabled,
      'rentalWarningDays': settings['rentalWarningDays'] is List
          ? settings['rentalWarningDays']
          : [
              settings['paymentReminderDays'] ?? 3,
              settings['renewalReminderDays'] ?? 7,
              1,
              2,
            ],
      'rentalAlertOverdueEnabled':
          settings['rentalAlertOverdueEnabled'] ?? true,
      'rentalAlertUpcomingEnabled': sendRenewal || sendPayment,
      'rentalAlertExpiringEnabled': sendExpiry,
      'rentalAlertLocalEnabled': settings['rentalAlertLocalEnabled'] ?? true,
      'rentalAlertPushEnabled': settings['rentalAlertPushEnabled'] ?? true,
      ...settings,
    };
  }

  static Future<void> saveRentalSettings(Map<String, dynamic> settings) async {
    await _saveSettingsByCategory('rentals', settings);
  }

  static Future<Map<String, dynamic>> getFormattingSettings() async {
    final settings = await _getSettingsByCategory('formatting');
    return {
      'dateFormat': settings['dateFormat'] ?? 'dd/MM/yyyy',
      'timeFormat': settings['timeFormat'] ?? '24h',
      'numberFormat': settings['numberFormat'] ?? 'en',
      'currencySymbol': settings['currencySymbol'] ?? 'ج.م',
      'currencyPosition': settings['currencyPosition'] ?? 'after',
      'decimalPlaces': settings['decimalPlaces'] ?? 2,
      ...settings,
    };
  }

  static Future<void> saveFormattingSettings(
    Map<String, dynamic> settings,
  ) async {
    await _saveSettingsByCategory('formatting', settings);
  }

  static Future<Map<String, dynamic>> getSystemSettings() async {
    final settings = await _getSettingsByCategory('system');
    return {
      'companyName': settings['companyName'] ?? 'شركتي الجديدة',
      'companyAddress': settings['companyAddress'] ?? '',
      'companyPhone': settings['companyPhone'] ?? '',
      'companyEmail': settings['companyEmail'] ?? '',
      'systemLanguage': settings['systemLanguage'] ?? 'ar',
      'enableNotifications': settings['enableNotifications'] ?? false,
      ...settings,
    };
  }

  static Future<void> saveSystemSettings(Map<String, dynamic> settings) async {
    await _saveSettingsByCategory('system', settings);
  }

  static Future<Map<String, dynamic>> getNotificationSettings() async {
    final settings = await _getSettingsByCategory('notifications');
    return {
      'enableNotifications': settings['enableNotifications'] ?? false,
      'enableSound': settings['enableSound'] ?? true,
      'enableVibration': settings['enableVibration'] ?? true,
      'notificationSound': settings['notificationSound'] ?? 'Default',
      'showNotificationBadge': settings['showNotificationBadge'] ?? true,
      'enableEmailNotifications': settings['enableEmailNotifications'] ?? true,
      'emailOnNewInvoice': settings['emailOnNewInvoice'] ?? true,
      'emailOnPaymentReceived': settings['emailOnPaymentReceived'] ?? true,
      'emailOnLowStock': settings['emailOnLowStock'] ?? true,
      'emailOnNewUser': settings['emailOnNewUser'] ?? true,
      'emailOnSystemAlert': settings['emailOnSystemAlert'] ?? true,
      'enableSMSNotifications': settings['enableSMSNotifications'] ?? false,
      'smsOnPaymentReceived': settings['smsOnPaymentReceived'] ?? false,
      'smsOnInvoiceDue': settings['smsOnInvoiceDue'] ?? false,
      'smsOnSystemAlert': settings['smsOnSystemAlert'] ?? false,
      'enablePushNotifications': settings['enablePushNotifications'] ?? false,
      'pushOnNewInvoice': settings['pushOnNewInvoice'] ?? false,
      'pushOnPaymentReceived': settings['pushOnPaymentReceived'] ?? false,
      'pushOnLowStock': settings['pushOnLowStock'] ?? false,
      'pushOnNewUser': settings['pushOnNewUser'] ?? false,
      'pushOnCustomerNew': settings['pushOnCustomerNew'] ?? false,
      'pushOnCustomerUpdated': settings['pushOnCustomerUpdated'] ?? false,
      'pushOnCustomerDeleted': settings['pushOnCustomerDeleted'] ?? false,
      'pushOnInventoryNew': settings['pushOnInventoryNew'] ?? false,
      'pushOnInventoryDeleted': settings['pushOnInventoryDeleted'] ?? false,
      'pushOnMaintenanceNew': settings['pushOnMaintenanceNew'] ?? false,
      'pushOnMaintenanceUpdated': settings['pushOnMaintenanceUpdated'] ?? false,
      'pushOnMaintenanceDeleted': settings['pushOnMaintenanceDeleted'] ?? false,
      'pushOnRentalNew': settings['pushOnRentalNew'] ?? false,
      'pushOnRentalUpdated': settings['pushOnRentalUpdated'] ?? false,
      'pushOnRentalDeleted': settings['pushOnRentalDeleted'] ?? false,
      'pushOnExpenseNew': settings['pushOnExpenseNew'] ?? false,
      'pushOnExpenseUpdated': settings['pushOnExpenseUpdated'] ?? false,
      'pushOnExpenseDeleted': settings['pushOnExpenseDeleted'] ?? false,
      'pushOnSubscriptionNew': settings['pushOnSubscriptionNew'] ?? false,
      'pushOnSubscriptionUpdated':
          settings['pushOnSubscriptionUpdated'] ?? false,
      'pushOnSubscriptionDeleted':
          settings['pushOnSubscriptionDeleted'] ?? false,
      'pushOnSubscriptionRenewed':
          settings['pushOnSubscriptionRenewed'] ?? false,
      'enableQuietHours': settings['enableQuietHours'] ?? false,
      'enableSystemAlerts': settings['enableSystemAlerts'] ?? true,
      'enableSectionBadges': settings['enableSectionBadges'] ?? true,
      'alertOnError': settings['alertOnError'] ?? true,
      'alertOnWarning': settings['alertOnWarning'] ?? true,
      'alertOnSuccess': settings['alertOnSuccess'] ?? false,
      ...settings,
    };
  }

  static Future<void> saveNotificationSettings(
    Map<String, dynamic> settings,
  ) async {
    await _saveSettingsByCategory('notifications', settings);
  }

  static Future<Map<String, String>> _notificationKeyAliases() async {
    return {
      'pushOnSubscriptionNew': 'subscription_notify_new',
      'pushOnSubscriptionUpdated': 'subscription_notify_updated',
      'pushOnSubscriptionDeleted': 'subscription_notify_deleted',
      'pushOnSubscriptionRenewed': 'subscription_notify_renewed',
      'subscription_notify_new': 'subscription_notify_new',
      'subscription_notify_updated': 'subscription_notify_updated',
      'subscription_notify_deleted': 'subscription_notify_deleted',
      'subscription_notify_renewed': 'subscription_notify_renewed',
      'subscription_alert_expired': 'subscription_alert_expired',
      'subscription_alert_expiring_soon': 'subscription_alert_expiring_soon',
      'invoiceAlertOverdueEnabled': 'invoiceAlertOverdueEnabled',
      'invoiceAlertUnpaidEnabled': 'invoiceAlertUnpaidEnabled',
      'inventoryAlertOutOfStockEnabled': 'inventoryAlertOutOfStockEnabled',
      'inventoryAlertLowStockEnabled': 'inventoryAlertLowStockEnabled',
      'customerAlertCreditLimitEnabled': 'customerAlertCreditLimitEnabled',
      'customerAlertOverdueCreditEnabled': 'customerAlertOverdueCreditEnabled',
      'maintenanceAlertOverdueEnabled': 'maintenanceAlertOverdueEnabled',
      'maintenanceAlertUpcomingEnabled': 'maintenanceAlertUpcomingEnabled',
      'rentalAlertOverdueEnabled': 'rentalAlertOverdueEnabled',
      'rentalAlertExpiringEnabled': 'rentalAlertExpiringEnabled',
    };
  }

  /// تعيين وتعطيل نوع الإشعار بالإشعارات اليومية
  // ✅ تم التنبيه: الإشعارات اليومية افتراضية مفعلة (القيمة الافتراضية: false)
  // getSubscriptionSettings() تعيّن الاشتراكAlertRenewalEnabled = true لتفعيل إشعارات الاشتراكات الدورية (subscriptionAlertRenewalEnabled, subscriptionAlertNewEnabled, subscriptionAlertExpiredEnabled).
  // إذا لم يتم تعيين النوع، يتم استخدام القيمة الافتراضية isNotificationTypeEnabled('pushOnSubscriptionNew')
  // الإشعارات الجديدة، الاشتراكات المحدثة، الاشتراكات المنتهية الصلاحية.
  static Future<bool> isNotificationTypeEnabled(
    String key, {
    bool defaultValue = false,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return defaultValue;

      final settings = await getUserNotificationSettings(user.uid);

      final aliases = await _notificationKeyAliases();
      final mappedKey = aliases[key] ?? key;
      return settings[mappedKey] as bool? ?? defaultValue;
    } on Exception catch (_) {
      return defaultValue;
    }
  }

  /// تعيين وتعطيل نوع الإشعار في الإعدادات الشخصية لكل مستخدم
  static Future<void> setNotificationTypeEnabled(String key, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final settings = await getUserNotificationSettings(user.uid);
      settings[key] = value;
      await saveUserNotificationSettings(user.uid, settings);
    } on Exception catch (_) {
      // تجاهل الأخطاء silencious
    }
  }

  // ============================================================
  // إعدادات الإشعارات الشخصية لكل مستخدم (Per-User Notification Settings)
  // ============================================================

  static const String _userNotificationSettingsCollection = 'notification_settings';
  static const String _userNotificationSettingsDoc = 'settings';

  /// جلب إعدادات الإشعارات الشخصية لمستخدم معين
  static Future<Map<String, dynamic>> getUserNotificationSettings(String uid) async {
    final userEmail = _currentUserEmail;
    if (userEmail == null) return {};

    try {
      final doc = await _firestore
          .collection(userEmail)
          .doc('users')
          .collection('users')
          .doc(uid)
          .collection(_userNotificationSettingsCollection)
          .doc(_userNotificationSettingsDoc)
          .get();

      if (doc.exists && doc.data() != null) {
        return Map<String, dynamic>.from(doc.data()!);
      }
      return {};
    } on Exception catch (_) {
      return {};
    }
  }

  /// حفظ إعدادات الإشعارات الشخصية لمستخدم معين
  static Future<void> saveUserNotificationSettings(
    String uid,
    Map<String, dynamic> settings,
  ) async {
    final userEmail = _currentUserEmail;
    if (userEmail == null) return;

    try {
      await _firestore
          .collection(userEmail)
          .doc('users')
          .collection('users')
          .doc(uid)
          .collection(_userNotificationSettingsCollection)
          .doc(_userNotificationSettingsDoc)
          .set(settings, SetOptions(merge: true));
    } on Exception catch (_) {
      // تجاهل الأخطاء silencious
    }
  }

  /// التحقق من تفعيل نوع إشعار معين لمستخدم معين
  static Future<bool> isUserNotificationTypeEnabled(
    String uid,
    String key, {
    bool defaultValue = false,
  }) async {
    try {
      final settings = await getUserNotificationSettings(uid);
      return settings[key] as bool? ?? defaultValue;
    } on Exception catch (_) {
      return defaultValue;
    }
  }

  /// جلب جميع إعدادات الإشعارات الشخصية مع قيم افتراضية للمستخدم الحالي
  static Future<Map<String, dynamic>> getCurrentUserNotificationSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    return await getUserNotificationSettings(user.uid);
  }
}
