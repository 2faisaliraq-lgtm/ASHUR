import 'dart:async';

import 'package:ashur/features/customers/domain/entities/customer_entity.dart';
import 'package:ashur/features/expenses/domain/entities/expense_entity.dart';
import 'package:ashur/features/inventory/domain/entities/product_entity.dart';
import 'package:ashur/features/invoices/domain/entities/invoice_entity.dart';
import 'package:ashur/features/maintenance/domain/entities/maintenance_request_entity.dart';
import 'package:ashur/features/rentals/domain/entities/rental_entity.dart';
import 'package:ashur/features/subscriptions/domain/entities/subscription_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'one_signal_notification_service.dart';
import 'push_notification_service.dart';
import 'section_badge_service.dart';
import 'settings_service.dart';
import 'subscription_notification_service.dart';
import 'session_service.dart';

/// نظام إدارة وتوجيه إشعارات الأقسام الشامل لكافة ميزات التطبيق
class SectionNotificationService {
  static const String _shownNotificationsPrefix =
      'shown_section_notifications_';

  static int _generateId(String targetId, String prefix) {
    final input = '$prefix:$targetId';
    var hash = 0;
    for (final codeUnit in input.codeUnits) {
      hash = ((hash << 5) - hash + codeUnit) & 0x7FFFFFFF;
    }
    return hash;
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

  static Future<String> _currentUserKey() async {
    final deviceId = await SettingsService.getDeviceId();
    final switchedUser = await SessionService.getSwitchedUser();
    final switchedUserId = switchedUser?['id']?.toString();
    final user = FirebaseAuth.instance.currentUser;
    final userId = switchedUserId?.isNotEmpty == true
        ? switchedUserId!
        : user?.uid ?? user?.email ?? 'default';
    return '$deviceId:$userId';
  }

  /// مفتاح تتبع الإشعارات على مستوى الجهاز فقط (أي مستخدم استخدم هذا الجهاز)
  static Future<String> _deviceNotificationsKey(String sectionKey) async {
    final deviceId = await SettingsService.getDeviceId();
    return '$_shownNotificationsPrefix${deviceId}_$sectionKey';
  }

  /// مفتاح تتبع الإشعارات على مستوى المستخدم فقط (أي جهاز استخدم هذا المستخدم)
  static Future<String> _userNotificationsKey(String sectionKey) async {
    final switchedUser = await SessionService.getSwitchedUser();
    final switchedUserId = switchedUser?['id']?.toString();
    final user = FirebaseAuth.instance.currentUser;
    final userId = switchedUserId?.isNotEmpty == true
        ? switchedUserId!
        : user?.uid ?? user?.email ?? 'default';
    return '$_shownNotificationsPrefix${userId}_$sectionKey';
  }

  static Future<Map<String, int>> _getShownList(String sectionKey) async {
    await SettingsService.ensurePreferencesInitialized();
    final deviceKey = await _deviceNotificationsKey(sectionKey);
    final userKey = await _userNotificationsKey(sectionKey);

    // دمج الإشعارات من مستوى الجهاز ومستوى المستخدم
    final deviceShown = SettingsService.getStringList(deviceKey) ?? [];
    final userShown = SettingsService.getStringList(userKey) ?? [];

    final merged = <String, int>{};
    for (final entry in [...deviceShown, ...userShown]) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final id = parts[0];
        final ts = int.tryParse(parts[1]) ?? 0;
        merged[id] = ts;
      }
    }
    return merged;
  }

  static Future<void> _saveShownList(
    String sectionKey,
    Map<String, int> map,
  ) async {
    await SettingsService.ensurePreferencesInitialized();
    final deviceKey = await _deviceNotificationsKey(sectionKey);
    final userKey = await _userNotificationsKey(sectionKey);

    final currentDevice = SettingsService.getStringList(deviceKey) ?? [];
    final mergedDevice = <String, int>{};
    for (final entry in currentDevice) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        mergedDevice[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }
    mergedDevice.addAll(map);
    final trimmedDevice = _trimMap(mergedDevice);
    await SettingsService.setStringList(
      deviceKey,
      trimmedDevice.entries.map((e) => '${e.key}:${e.value}').toList(),
    );

    final currentUser = SettingsService.getStringList(userKey) ?? [];
    final mergedUser = <String, int>{};
    for (final entry in currentUser) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        mergedUser[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }
    mergedUser.addAll(map);
    final trimmedUser = _trimMap(mergedUser);
    await SettingsService.setStringList(
      userKey,
      trimmedUser.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
  }

  static Map<String, int> _trimMap(Map<String, int> map) {
    if (map.length <= 200) return map;
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(200));
  }

  /// التحقق من إمكانية عرض التذكير بناءً على التكرار المحدد
  static Future<bool> _shouldShowReminder(
    String sectionKey,
    String notificationId,
    Map<String, int> shownMap,
  ) async {
    final lastShown = shownMap[notificationId];
    if (lastShown == null) return true; // لم يُshown من قبل

    final frequency = await SettingsService.getReminderFrequency(
      _getCurrentUserId(),
      sectionKey,
    );

    if (frequency == 'none') return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = now - lastShown;

    switch (frequency) {
      case 'daily':
        return diffMs >= Duration(days: 1).inMilliseconds;
      case 'weekly':
        return diffMs >= Duration(days: 7).inMilliseconds;
      case 'monthly':
        return diffMs >= Duration(days: 30).inMilliseconds;
      default:
        return true;
    }
  }

  static String _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? user?.email ?? 'default';
  }

  static Future<bool> isSectionNotificationsEnabled(String sectionKey) async {
    try {
      // ✅ فحص إعدادات الإشعارات الشخصية للمستخدم الحالي أولاً
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userSettings = await SettingsService.getUserNotificationSettings(user.uid);
        final notificationsEnabled = userSettings['enableNotifications'] as bool? ?? true;
        if (!notificationsEnabled) return false;

        final typeKey = switch (sectionKey) {
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

      switch (sectionKey) {
        // This method checks the section-level master switch only. Local-alert
        // and remote-push switches are checked independently by their senders.
        case 'invoices':
          final settings = await SettingsService.getInvoiceSettings();
          return settings['invoiceAlertsEnabled'] as bool? ?? false;
        case 'inventory':
          final settings = await SettingsService.getInventorySettings();
          return settings['inventoryAlertsEnabled'] as bool? ?? false;
        case 'customers':
          final settings = await SettingsService.getCustomerSettings();
          return settings['customerAlertsEnabled'] as bool? ?? false;
        case 'maintenance':
          final settings = await SettingsService.getMaintenanceSettings();
          return settings['maintenanceAlertsEnabled'] as bool? ?? false;
        case 'rentals':
          final settings = await SettingsService.getRentalSettings();
          return settings['rentalAlertsEnabled'] as bool? ?? false;
        case 'expenses':
          final settings = await SettingsService.getExpensesSettings();
          return settings['expensesAlertsEnabled'] as bool? ?? false;
        case 'subscriptions':
          final settings = await SettingsService.getSubscriptionSettings();
          return settings['subscriptionAlertsEnabled'] as bool? ?? false;
        default:
          return false;
      }
    } on Exception catch (_) {
      return false;
    }
  }

  // ==================== 2. المخزون (Inventory) ====================

  static Future<void> notifyNewInvoice(InvoiceEntity invoice) async {
    final isEnabled = await isSectionNotificationsEnabled('invoices');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'invoice_notify_new',
    )) {
      return;
    }

    await PushNotificationService.showLocalInvoiceAlert(
      title: '📄 فاتورة جديدة',
      message:
          'تم إصدار فاتورة جديدة للعميل ${invoice.customerName} بمبلغ ${invoice.totalAmount.toStringAsFixed(0)} د.ع',
      notificationId: _generateId(invoice.id, 'new_inv'),
    );
  }

  static Future<void> notifyInvoiceFullyPaid(InvoiceEntity invoice) async {
    final isEnabled = await isSectionNotificationsEnabled('invoices');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'invoice_notify_paid',
    )) {
      return;
    }

    await PushNotificationService.showLocalInvoiceAlert(
      title: '✅ تم سداد الفاتورة بالكامل',
      message:
          'تم سداد فاتورة العميل ${invoice.customerName} بالكامل. المبلغ الإجمالي: ${invoice.totalAmount.toStringAsFixed(0)} د.ع',
      notificationId: _generateId(invoice.id, 'paid_inv'),
    );
  }

  static Future<void> notifyInvoiceUpdated(InvoiceEntity invoice) async {
    final isEnabled = await isSectionNotificationsEnabled('invoices');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'invoice_notify_updated',
    )) {
      return;
    }

    await PushNotificationService.showLocalInvoiceAlert(
      title: '✏️ تعديل فاتورة',
      message:
          'تم تحديث بيانات فاتورة العميل ${invoice.customerName}. المتبقي الحالي: ${invoice.remainingAmount.toStringAsFixed(0)} د.ع',
      notificationId: _generateId(invoice.id, 'upd_inv'),
    );
  }

  static Future<void> notifyCashInvoice(
    InvoiceEntity invoice, {
    required String customerName,
    required String transactionType,
    String? createdBy,
  }) async {
    final isEnabled = await isSectionNotificationsEnabled('invoices');
    if (!isEnabled) return;

    final isCustomerEnabled = await SettingsService.isNotificationTypeEnabled(
      'customer_notify_cash_invoice',
    );
    final isInvoiceEnabled = await SettingsService.isNotificationTypeEnabled(
      'invoice_notify_cash',
    );
    if (!isCustomerEnabled && !isInvoiceEnabled) return;

    await PushNotificationService.showLocalInvoiceAlert(
      title: '💵 فاتورة نقدية',
      message:
          'تم إنشاء فاتورة نقدية للعميل $customerName بقيمة ${invoice.totalAmount.toStringAsFixed(0)} د.ع',
      notificationId: _generateId(invoice.id, 'cash_inv'),
    );
  }

  // ==================== 2. المخزون (Inventory) ====================

  static Future<void> checkAndNotifyInventory(
    List<ProductEntity> products,
  ) async {
    final isEnabled = await isSectionNotificationsEnabled('inventory');
    if (!isEnabled) return;

    final summary = SectionBadgeService.buildInventorySummary(products);
    if (!summary.hasUrgentItems) return;

    final shown = await _getShownList('inventory');
    var hasChanges = false;

    for (final product in summary.urgentProducts) {
      final isOut = product.isOutOfStock;
      final key = 'prod_${product.id}_${isOut ? 'out' : 'low'}';
      if (!(await _shouldShowReminder('inventory', key, shown))) continue;
      final notificationId = _generateId(
        product.id,
        'prod_$isOut',
      );

      final isTypeEnabled = await SettingsService.isNotificationTypeEnabled(
        isOut ? 'inventory_alert_out_of_stock' : 'inventory_alert_low_stock',
      );
      final inventorySettings = await SettingsService.getInventorySettings();
      final isAlertTypeEnabled =
          inventorySettings[isOut
                  ? 'inventoryAlertOutOfStockEnabled'
                  : 'inventoryAlertLowStockEnabled']
              as bool? ??
          true;
      if (!isAlertTypeEnabled) continue;
      if (!isTypeEnabled) continue;

      final title = isOut ? '🚨 نفاد كمية مادة' : '⚠️ تنبيه مخزون منخفض';
      final message = isOut
          ? 'المادة "${product.name}" نفدت تماماً من المخزون!'
          : 'المادة "${product.name}" متبقي منها ${product.quantity} فقط (الحد الأدنى: ${product.minQuantity.toStringAsFixed(0)})';

      await PushNotificationService.showLocalInventoryAlert(
        title: title,
        message: message,
        notificationId: notificationId,
      );

      shown[key] = DateTime.now().millisecondsSinceEpoch;
      hasChanges = true;
    }

    if (hasChanges) {
      await _saveShownList('inventory', shown);
    }
  }

  static Future<void> notifyNewProduct(
    ProductEntity product, {
    String? createdBy,
  }) async {
    final isEnabled = await isSectionNotificationsEnabled('inventory');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'inventory_notify_new',
    )) {
      return;
    }

    // لا نُظهر الإشعار للمنشئ نفسه
    if (createdBy != null && createdBy.isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == createdBy) {
        return;
      }
    }

    await PushNotificationService.showLocalInventoryAlert(
      title: '📦 إضافة مادة جديدة',
      message:
          'تمت إضافة المادة "${product.name}" بكمية (${product.quantity}) إلى المخزون',
      notificationId: _generateId(product.id, 'new_prod'),
    );
  }

  static Future<void> notifyOutOfStock(ProductEntity product) async {
    final isEnabled = await isSectionNotificationsEnabled('inventory');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'inventory_alert_out_of_stock',
    )) {
      return;
    }

    await PushNotificationService.showLocalInventoryAlert(
      title: '🚨 نفاد كمية مادة',
      message: 'المادة "${product.name}" نفدت تماماً من المستودع!',
      notificationId: _generateId(product.id, 'out_prod'),
    );
  }

  static Future<void> notifyLowStock(ProductEntity product) async {
    final isEnabled = await isSectionNotificationsEnabled('inventory');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'inventory_alert_low_stock',
    )) {
      return;
    }

    await PushNotificationService.showLocalInventoryAlert(
      title: '⚠️ تنبيه مخزون منخفض',
      message:
          'المادة "${product.name}" متبقي منها ${product.quantity} فقط (الحد الأدنى: ${product.minQuantity.toStringAsFixed(0)})',
      notificationId: _generateId(product.id, 'low_prod'),
    );
  }

  // ==================== 3. العملاء (Customers) ====================

  static Future<void> checkAndNotifyCustomers(
    List<CustomerEntity> customers,
  ) async {
    final isEnabled = await isSectionNotificationsEnabled('customers');
    if (!isEnabled) return;

    final summary = SectionBadgeService.buildCustomerSummary(customers);
    if (!summary.hasUrgentItems) return;

    final shown = await _getShownList('customers');
    var hasChanges = false;

    for (final customer in summary.urgentCustomers) {
      final limit = customer.creditLimit;
      final isExceeded =
          limit != null && limit > 0 && customer.totalDebt > limit;
      final key =
          'cust_${customer.id}_${isExceeded ? 'exceeded' : 'high'}';
      if (!(await _shouldShowReminder('customers', key, shown))) continue;
      final notificationId = _generateId(
        customer.id,
        'cust_$isExceeded',
      );
      final isTypeEnabled = await SettingsService.isNotificationTypeEnabled(
        isExceeded ? 'customer_alert_credit_limit' : 'customer_alert_high_debt',
      );
      final customerSettings = await SettingsService.getCustomerSettings();
      final isAlertTypeEnabled =
          customerSettings[isExceeded
                  ? 'customerAlertCreditLimitEnabled'
                  : 'customerAlertOverdueCreditEnabled']
              as bool? ??
          true;
      if (!isAlertTypeEnabled) continue;
      if (!isTypeEnabled) continue;

      final title = isExceeded ? '⚠️ تجاوز حد الائتمان' : '👤 تنبيه ديون عميل';
      final message = isExceeded
          ? 'العميل "${customer.name}" تجاوز حد الائتمان (${limit.toStringAsFixed(0)}). إجمالي الدين: ${customer.totalDebt.toStringAsFixed(0)} د.ع'
          : 'العميل "${customer.name}" عليه مستحقات مرتفعة بمبلغ ${customer.totalDebt.toStringAsFixed(0)} د.ع';

      await PushNotificationService.showLocalCustomerAlert(
        title: title,
        message: message,
        notificationId: notificationId,
      );

      shown[key] = DateTime.now().millisecondsSinceEpoch;
      hasChanges = true;
    }

    if (hasChanges) {
      await _saveShownList('customers', shown);
    }
  }

  static Future<void> notifyNewCustomer(
    CustomerEntity customer, {
    String? createdBy,
  }) async {
    final isEnabled = await isSectionNotificationsEnabled('customers');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'customer_notify_new',
    )) {
      return;
    }

    // لا نُظهر الإشعار للمنشئ نفسه
    if (createdBy != null && createdBy.isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == createdBy) {
        return;
      }
    }

    await PushNotificationService.showLocalCustomerAlert(
      title: '👤 تسجيل عميل جديد',
      message: 'تمت إضافة العميل "${customer.name}" بنجاح إلى سجل العملاء',
      notificationId: _generateId(customer.id, 'new_cust'),
    );
  }

  static Future<void> notifyCustomerZeroBalance(
    CustomerEntity customer, {
    String? createdBy,
  }) async {
    final isEnabled = await isSectionNotificationsEnabled('customers');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'customer_notify_zero_balance',
    )) {
      return;
    }

    // لا نُظهر الإشعار للمنشئ نفسه
    if (createdBy != null && createdBy.isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == createdBy) {
        return;
      }
    }

    await PushNotificationService.showLocalCustomerAlert(
      title: '🎉 تصفير حساب عميل',
      message:
          'تم تسديد كامل ديون العميل "${customer.name}" وأصبح رصيد حسابه 0.00 د.ع',
      notificationId: _generateId(customer.id, 'zero_cust'),
    );
  }

  static Future<void> notifyCustomerUpdated(
    CustomerEntity customer, {
    String? createdBy,
  }) async {
    final isEnabled = await isSectionNotificationsEnabled('customers');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'customer_notify_updated',
    )) {
      return;
    }

    // لا نُظهر الإشعار للمنشئ نفسه
    if (createdBy != null && createdBy.isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == createdBy) {
        return;
      }
    }

    await PushNotificationService.showLocalCustomerAlert(
      title: '✏️ تعديل بيانات عميل',
      message:
          'تم تحديث بيانات العميل "${customer.name}" (الدين الحالي: ${customer.totalDebt.toStringAsFixed(0)} د.ع)',
      notificationId: _generateId(customer.id, 'upd_cust'),
    );
  }

  static Future<void> notifyCreditLimitExceeded(
    CustomerEntity customer, {
    String? createdBy,
  }) async {
    final isEnabled = await isSectionNotificationsEnabled('customers');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'customer_alert_credit_limit',
    )) {
      return;
    }

    // لا نُظهر الإشعار للمنشئ نفسه
    if (createdBy != null && createdBy.isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == createdBy) {
        return;
      }
    }

    final limit = customer.creditLimit ?? 0;
    await PushNotificationService.showLocalCustomerAlert(
      title: '🚨 تجاوز حد الائتمان',
      message:
          'العميل "${customer.name}" تجاوز سقف الائتمان المسموح (${limit.toStringAsFixed(0)} د.ع). الدين الحالي: ${customer.totalDebt.toStringAsFixed(0)} د.ع',
      notificationId: _generateId(customer.id, 'limit_cust'),
    );
  }

  // ==================== 4. الصيانة (Maintenance) ====================

  static Future<void> checkAndNotifyMaintenance(
    List<MaintenanceRequestEntity> requests,
  ) async {
    final isEnabled = await isSectionNotificationsEnabled('maintenance');
    if (!isEnabled) return;

    final summary = SectionBadgeService.buildMaintenanceSummary(requests);
    if (!summary.hasUrgentItems) return;

    final shown = await _getShownList('maintenance');
    var hasChanges = false;

    for (final request in summary.urgentRequests) {
      final isOverdue =
          request.scheduledDate != null &&
          request.scheduledDate!.isBefore(DateTime.now());
      final key = 'maint_${request.id}_${isOverdue ? 'overdue' : 'urgent'}';
      if (!(await _shouldShowReminder('maintenance', key, shown))) continue;
      final notificationId = _generateId(
        request.id,
        'maint_$isOverdue',
      );
      final isTypeEnabled = await SettingsService.isNotificationTypeEnabled(
        isOverdue ? 'maintenance_alert_overdue' : 'maintenance_alert_urgent',
      );
      final maintenanceSettings =
          await SettingsService.getMaintenanceSettings();
      final isAlertTypeEnabled =
          maintenanceSettings[isOverdue
                  ? 'maintenanceAlertOverdueEnabled'
                  : 'maintenanceAlertUpcomingEnabled']
              as bool? ??
          true;
      if (!isAlertTypeEnabled) continue;
      if (!isTypeEnabled) continue;

      final title = isOverdue ? '⚠️ صيانة متأخرة' : '🛠️ طلب صيانة عاجل';
      final message = isOverdue
          ? 'طلب الصيانة "${request.title}" للعميل ${request.customerName} متأخر عن موعده المجدول'
          : 'طلب الصيانة "${request.title}" للعميل ${request.customerName} بحالة عاجلة وبحاجة للمتابعة';

      await PushNotificationService.showLocalMaintenanceAlert(
        title: title,
        message: message,
        notificationId: notificationId,
      );

      shown[key] = DateTime.now().millisecondsSinceEpoch;
      hasChanges = true;
    }

    if (hasChanges) {
      await _saveShownList('maintenance', shown);
    }
  }

  static Future<void> notifyNewMaintenance(
    MaintenanceRequestEntity request,
  ) async {
    final isEnabled = await isSectionNotificationsEnabled('maintenance');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'maintenance_notify_new',
    )) {
      return;
    }

    await PushNotificationService.showLocalMaintenanceAlert(
      title: '🛠️ طلب صيانة جديد',
      message:
          'تم تسجيل طلب صيانة جديد "${request.title}" للعميل ${request.customerName}',
      notificationId: _generateId(request.id, 'new_maint'),
    );
  }

  static Future<void> notifyMaintenanceCompleted(
    MaintenanceRequestEntity request,
  ) async {
    final isEnabled = await isSectionNotificationsEnabled('maintenance');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'maintenance_notify_completed',
    )) {
      return;
    }

    await PushNotificationService.showLocalMaintenanceAlert(
      title: '✅ اكتمال صيانة',
      message:
          'اكتملت أعمال الصيانة لطلب "${request.title}" للعميل ${request.customerName} وجاهز للتسليم',
      notificationId: _generateId(request.id, 'comp_maint'),
    );
  }

  // ==================== 5. التأجير (Rentals) ====================

  static Future<void> checkAndNotifyRentals(List<RentalEntity> rentals) async {
    final isEnabled = await isSectionNotificationsEnabled('rentals');
    if (!isEnabled) return;

    final summary = SectionBadgeService.buildRentalSummary(rentals);
    if (!summary.hasUrgentItems) return;

    final shown = await _getShownList('rentals');
    var hasChanges = false;

    for (final rental in summary.urgentRentals) {
      final days = rental.endDate.difference(DateTime.now()).inDays;
      final isExpired = days < 0;
      final key = 'rent_${rental.id}_${isExpired ? 'expired' : 'expiring'}';
      if (!(await _shouldShowReminder('rentals', key, shown))) continue;
      final notificationId = _generateId(
        rental.id,
        'rent_$isExpired',
      );
      final isTypeEnabled = await SettingsService.isNotificationTypeEnabled(
        isExpired ? 'rental_alert_expired' : 'rental_alert_expiring_soon',
      );
      final rentalSettings = await SettingsService.getRentalSettings();
      final isAlertTypeEnabled =
          rentalSettings[isExpired
                  ? 'rentalAlertOverdueEnabled'
                  : 'rentalAlertExpiringEnabled']
              as bool? ??
          true;
      if (!isAlertTypeEnabled) continue;
      if (!isTypeEnabled) continue;

      final customer =
          (rental.customerName != null &&
              rental.customerName!.trim().isNotEmpty)
          ? rental.customerName!.trim()
          : 'المستأجر';
      final title = isExpired ? '⚠️ تأجير متأخر' : '🔑 تنبيه انتهاء تأجير';
      final message = isExpired
          ? 'عقد تأجير $customer متأخر عن موعد الإرجاع (${_formatDate(rental.endDate)})'
          : 'عقد تأجير $customer سينتهي ${days == 0 ? 'اليوم' : 'خلال $days يوم'}';

      await PushNotificationService.showLocalRentalAlert(
        title: title,
        message: message,
        notificationId: notificationId,
      );

      shown[key] = DateTime.now().millisecondsSinceEpoch;
      hasChanges = true;
    }

    if (hasChanges) {
      await _saveShownList('rentals', shown);
    }
  }

  static Future<void> notifyNewRental(RentalEntity rental) async {
    final isEnabled = await isSectionNotificationsEnabled('rentals');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled('rental_notify_new')) {
      return;
    }

    await PushNotificationService.showLocalRentalAlert(
      title: '🔑 عقد تأجير جديد',
      message:
          'تم إبرام عقد تأجير جديد للمستأجر "${rental.renterName}" للمادة "${rental.itemName}"',
      notificationId: _generateId(rental.id, 'new_rent'),
    );
  }

  static Future<void> notifyRentalReturned(RentalEntity rental) async {
    final isEnabled = await isSectionNotificationsEnabled('rentals');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'rental_notify_returned',
    )) {
      return;
    }

    await PushNotificationService.showLocalRentalAlert(
      title: '✅ إرجاع تأجير',
      message:
          'تم تأكيد إرجاع المادة "${rental.itemName}" للمستأجر "${rental.renterName}" بنجاح',
      notificationId: _generateId(rental.id, 'ret_rent'),
    );
  }

  // ==================== 6. المصروفات (Expenses) ====================

  static Future<void> checkAndNotifyExpenses(
    List<ExpenseEntity> expenses,
  ) async {
    final isEnabled = await isSectionNotificationsEnabled('expenses');
    if (!isEnabled) return;

    final summary = SectionBadgeService.buildExpenseSummary(expenses);
    if (!summary.hasUrgentItems) return;

    final shown = await _getShownList('expenses');
    var hasChanges = false;

    for (final expense in summary.urgentExpenses) {
      final key = 'exp_${expense.id}';
      if (!(await _shouldShowReminder('expenses', key, shown))) continue;
      final notificationId = _generateId(expense.id, 'exp');
      final isTypeEnabled = await SettingsService.isNotificationTypeEnabled(
        'expenses_alert_pending',
      );
      if (!isTypeEnabled) continue;

      final title = '💰 تنبيه مصروفات معلقة';
      final message =
          'المصروف "${expense.title}" بمبلغ ${expense.amount.toStringAsFixed(0)} د.ع بانتظار المراجعة والاعتماد';

      await PushNotificationService.showLocalExpenseAlert(
        title: title,
        message: message,
        notificationId: notificationId,
      );

      shown[key] = DateTime.now().millisecondsSinceEpoch;
      hasChanges = true;
    }

    if (hasChanges) {
      await _saveShownList('expenses', shown);
    }
  }

  static Future<void> notifyNewExpense(ExpenseEntity expense) async {
    final isEnabled = await isSectionNotificationsEnabled('expenses');
    if (!isEnabled) return;
    if (!await SettingsService.isNotificationTypeEnabled(
      'expenses_notify_new',
    )) {
      return;
    }

    await PushNotificationService.showLocalExpenseAlert(
      title: '💵 تسجيل سند صرف',
      message:
          'تم تسجيل مصروف جديد "${expense.title}" بمبلغ ${expense.amount.toStringAsFixed(0)} د.ع',
      notificationId: _generateId(expense.id, 'new_exp'),
    );
  }

  // ==================== 7. الاشتراكات (Subscriptions) ====================

  static Future<void> checkAndNotifySubscriptions(
    List<SubscriptionEntity> subscriptions,
  ) async {
    await SubscriptionNotificationService.checkAndNotifyExpiringSoon(
      subscriptions,
    );
  }

  /// مسح سجل الإشعارات لقسم محدد
  static Future<void> clearSectionNotifications(String sectionKey) async {
    final userKey = await _currentUserKey();
    await SettingsService.setStringList(
      '$_shownNotificationsPrefix${userKey}_$sectionKey',
      [],
    );
  }
}
