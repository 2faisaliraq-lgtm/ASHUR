import 'package:ashur/features/customers/domain/entities/customer_entity.dart';
import 'package:ashur/features/expenses/domain/entities/expense_entity.dart';
import 'package:ashur/features/inventory/domain/entities/product_entity.dart';
import 'package:ashur/features/invoices/domain/entities/invoice_entity.dart';
import 'package:ashur/features/maintenance/domain/entities/maintenance_request_entity.dart';
import 'package:ashur/features/rentals/domain/entities/rental_entity.dart';
import 'package:ashur/features/subscriptions/domain/entities/subscription_entity.dart';

class SectionBadge {
  const SectionBadge({
    required this.sectionKey,
    required this.sectionName,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.customerName,
    this.subscriptionId,
    this.targetId,
  });

  final String sectionKey;
  final String sectionName;
  final String title;
  final String message;
  final String type; // info, warning, critical
  final DateTime createdAt;
  final String? customerName;
  final String? subscriptionId;
  final String? targetId;
}

/// ملخص تنبيهي وإحصائي ذكي للاشتراكات العاجلة
class SubscriptionAlertSummary {
  const SubscriptionAlertSummary({
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.urgentSubscriptions,
    required this.summaryMessage,
    required this.urgencyType,
  });

  final int expiredCount;
  final int expiringSoonCount;
  final List<SubscriptionEntity> urgentSubscriptions;
  final String summaryMessage;
  final String urgencyType; // critical, warning, none

  int get totalUrgentCount => expiredCount + expiringSoonCount;
  bool get hasUrgentItems => totalUrgentCount > 0;
}

/// ملخص تنبيهي وإحصائي للفواتير المستحقة والمتأخرة
class InvoiceAlertSummary {
  const InvoiceAlertSummary({
    required this.overdueCount,
    required this.unpaidCount,
    required this.totalRemainingDebt,
    required this.urgentInvoices,
    required this.summaryMessage,
    required this.urgencyType,
  });

  final int overdueCount;
  final int unpaidCount;
  final double totalRemainingDebt;
  final List<InvoiceEntity> urgentInvoices;
  final String summaryMessage;
  final String urgencyType; // critical, warning, none

  int get totalUrgentCount => overdueCount + unpaidCount;
  bool get hasUrgentItems => totalUrgentCount > 0;
}

/// ملخص تنبيهي وإحصائي للمخزون والمنتجات
class InventoryAlertSummary {
  const InventoryAlertSummary({
    required this.outOfStockCount,
    required this.lowStockCount,
    required this.urgentProducts,
    required this.summaryMessage,
    required this.urgencyType,
  });

  final int outOfStockCount;
  final int lowStockCount;
  final List<ProductEntity> urgentProducts;
  final String summaryMessage;
  final String urgencyType; // critical, warning, none

  int get totalUrgentCount => outOfStockCount + lowStockCount;
  bool get hasUrgentItems => totalUrgentCount > 0;
}

/// ملخص تنبيهي وإحصائي لحدود ائتمان وديون العملاء
class CustomerAlertSummary {
  const CustomerAlertSummary({
    required this.creditLimitExceededCount,
    required this.highDebtCount,
    required this.totalExceededDebt,
    required this.urgentCustomers,
    required this.summaryMessage,
    required this.urgencyType,
  });

  final int creditLimitExceededCount;
  final int highDebtCount;
  final double totalExceededDebt;
  final List<CustomerEntity> urgentCustomers;
  final String summaryMessage;
  final String urgencyType; // critical, warning, none

  int get totalUrgentCount => creditLimitExceededCount + highDebtCount;
  bool get hasUrgentItems => totalUrgentCount > 0;
}

/// ملخص تنبيهي لطلبات الصيانة العاجلة والمتأخرة
class MaintenanceAlertSummary {
  const MaintenanceAlertSummary({
    required this.urgentCount,
    required this.overdueCount,
    required this.pendingCount,
    required this.urgentRequests,
    required this.summaryMessage,
    required this.urgencyType,
  });

  final int urgentCount;
  final int overdueCount;
  final int pendingCount;
  final List<MaintenanceRequestEntity> urgentRequests;
  final String summaryMessage;
  final String urgencyType; // critical, warning, none

  int get totalUrgentCount => urgentCount + overdueCount;
  bool get hasUrgentItems => totalUrgentCount > 0;
}

/// ملخص تنبيهي لعقود التأجير
class RentalAlertSummary {
  const RentalAlertSummary({
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.urgentRentals,
    required this.summaryMessage,
    required this.urgencyType,
  });

  final int expiredCount;
  final int expiringSoonCount;
  final List<RentalEntity> urgentRentals;
  final String summaryMessage;
  final String urgencyType; // critical, warning, none

  int get totalUrgentCount => expiredCount + expiringSoonCount;
  bool get hasUrgentItems => totalUrgentCount > 0;
}

/// ملخص تنبيهي للمصروفات المعلقة وغير المدفوعة
class ExpenseAlertSummary {
  const ExpenseAlertSummary({
    required this.pendingCount,
    required this.unpaidCount,
    required this.totalPendingAmount,
    required this.urgentExpenses,
    required this.summaryMessage,
    required this.urgencyType,
  });

  final int pendingCount;
  final int unpaidCount;
  final double totalPendingAmount;
  final List<ExpenseEntity> urgentExpenses;
  final String summaryMessage;
  final String urgencyType; // warning, none

  int get totalUrgentCount => pendingCount + unpaidCount;
  bool get hasUrgentItems => totalUrgentCount > 0;
}

class SectionBadgeService {
  static const int defaultWarningDays = 7;
  static const int urgentWarningDays = 3;

  // ==================== 1. الاشتراكات (Subscriptions) ====================

  /// بناء ملخص تفاعلي ذكي للاشتراكات المنتهية أو القريبة جداً من الانتهاء
  static SubscriptionAlertSummary buildSubscriptionSummary(
    List<SubscriptionEntity> subscriptions, {
    int urgentDays = urgentWarningDays,
  }) {
    var expiredCount = 0;
    var expiringSoonCount = 0;
    final urgentList = <SubscriptionEntity>[];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final sub in subscriptions) {
      if (sub.status == 'cancelled' || sub.status == 'suspended') {
        continue;
      }

      final end = DateTime(
        sub.endDate.year,
        sub.endDate.month,
        sub.endDate.day,
      );
      final days = end.difference(today).inDays;

      if (sub.status == 'expired' || days < 0) {
        expiredCount++;
        urgentList.add(sub);
      } else if (sub.status == 'active' && days <= urgentDays) {
        expiringSoonCount++;
        urgentList.add(sub);
      }
    }

    String summaryMessage;
    String urgencyType;

    if (expiredCount > 0 && expiringSoonCount > 0) {
      summaryMessage =
          'يوجد $expiredCount منتهي و $expiringSoonCount ينتهي قريباً بحاجة للمتابعة';
      urgencyType = 'critical';
    } else if (expiredCount > 0) {
      summaryMessage =
          'يوجد $expiredCount ${expiredCount == 1 ? 'اشتراك منتهي' : 'اشتراكات منتهية'} بحاجة للتجديد';
      urgencyType = 'critical';
    } else if (expiringSoonCount > 0) {
      summaryMessage =
          'يوجد $expiringSoonCount ${expiringSoonCount == 1 ? 'اشتراك ينتهي قريباً' : 'اشتراكات تنتهي قريباً'} (خلال $urgentDays أيام أو اليوم)';
      urgencyType = 'warning';
    } else {
      summaryMessage = '';
      urgencyType = 'none';
    }

    return SubscriptionAlertSummary(
      expiredCount: expiredCount,
      expiringSoonCount: expiringSoonCount,
      urgentSubscriptions: urgentList,
      summaryMessage: summaryMessage,
      urgencyType: urgencyType,
    );
  }

  static SectionBadge? buildSubscriptionBadge(
    SubscriptionEntity subscription, {
    int warningDays = defaultWarningDays,
  }) {
    if (subscription.status != 'active') {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(
      subscription.endDate.year,
      subscription.endDate.month,
      subscription.endDate.day,
    );
    final daysRemaining = end.difference(today).inDays;

    if (daysRemaining < 0 || daysRemaining > warningDays) {
      return null;
    }

    final customerName = (subscription.customerName ?? 'المشترك').trim();
    final label = customerName.isNotEmpty ? customerName : 'مشترك';
    final urgency = daysRemaining <= 3 ? 'critical' : 'warning';
    final message = daysRemaining == 0
        ? 'المشترك $label سينتهي اشتراكه اليوم'
        : 'المشترك $label سينتهي اشتراكه خلال $daysRemaining يوم';

    return SectionBadge(
      sectionKey: 'subscriptions',
      sectionName: 'الاشتراكات',
      title: 'تنبيه اشتراك',
      message: message,
      type: urgency,
      createdAt: now,
      customerName: label,
      subscriptionId: subscription.id,
      targetId: subscription.id,
    );
  }

  static List<SectionBadge> buildSubscriptionBadges(
    List<SubscriptionEntity> subscriptions, {
    int warningDays = defaultWarningDays,
  }) {
    final badges = <SectionBadge>[];

    for (final subscription in subscriptions) {
      final badge = buildSubscriptionBadge(
        subscription,
        warningDays: warningDays,
      );
      if (badge != null) {
        badges.add(badge);
      }
    }

    return badges;
  }

  // ==================== 2. الفواتير (Invoices) ====================

  /// بناء ملخص تفاعلي ذكي للفواتير غير المسددة أو المتأخرة
  static InvoiceAlertSummary buildInvoiceSummary(
    List<InvoiceEntity> invoices, {
    int overdueDaysThreshold = 30,
  }) {
    var overdueCount = 0;
    var unpaidCount = 0;
    var totalRemainingDebt = 0.0;
    final urgentList = <InvoiceEntity>[];
    final now = DateTime.now();

    for (final invoice in invoices) {
      if (invoice.isArchived ||
          invoice.status == 'paid' ||
          invoice.remainingAmount <= 0) {
        continue;
      }
      final daysOld = now.difference(invoice.invoiceDate).inDays;
      totalRemainingDebt += invoice.calculateRemainingAmount();
      urgentList.add(invoice);

      if (daysOld >= overdueDaysThreshold) {
        overdueCount++;
      } else {
        unpaidCount++;
      }
    }

    String summaryMessage;
    String urgencyType;

    if (overdueCount > 0) {
      summaryMessage =
          'يوجد $overdueCount فواتير متأخرة تجاوزت $overdueDaysThreshold يوماً غير مسددة';
      urgencyType = 'critical';
    } else if (unpaidCount > 0) {
      summaryMessage = 'يوجد $unpaidCount فواتير غير مسددة بانتظار التحصيل';
      urgencyType = 'warning';
    } else {
      summaryMessage = '';
      urgencyType = 'none';
    }

    return InvoiceAlertSummary(
      overdueCount: overdueCount,
      unpaidCount: unpaidCount,
      totalRemainingDebt: totalRemainingDebt,
      urgentInvoices: urgentList,
      summaryMessage: summaryMessage,
      urgencyType: urgencyType,
    );
  }

  static SectionBadge? buildInvoiceBadge(InvoiceEntity invoice) {
    if (invoice.status == 'paid' ||
        invoice.remainingAmount <= 0 ||
        invoice.isArchived) {
      return null;
    }
    final now = DateTime.now();
    final daysOld = now.difference(invoice.invoiceDate).inDays;
    final urgency = daysOld >= 30 ? 'critical' : 'warning';
    final customer = invoice.customerName.isNotEmpty
        ? invoice.customerName
        : 'عميل نقدي';

    final message = daysOld >= 30
        ? 'فاتورة العميل $customer متأخرة منذ $daysOld يوم بمبلغ متبقي ${invoice.remainingAmount}'
        : 'فاتورة العميل $customer غير مسددة بالكامل (المتبقي: ${invoice.remainingAmount})';

    return SectionBadge(
      sectionKey: 'invoices',
      sectionName: 'الفواتير',
      title: daysOld >= 30 ? 'فاتورة متأخرة' : 'فاتورة غير مسددة',
      message: message,
      type: urgency,
      createdAt: now,
      customerName: customer,
      targetId: invoice.id,
    );
  }

  // ==================== 3. المخزون (Inventory) ====================

  /// بناء ملخص تفاعلي ذكي للمنتجات المنتهية وقليلة المخزون
  static InventoryAlertSummary buildInventorySummary(
    List<ProductEntity> products,
  ) {
    var outOfStockCount = 0;
    var lowStockCount = 0;
    final urgentList = <ProductEntity>[];

    for (final product in products) {
      if (!product.isActive || !product.trackQuantity) continue;

      if (product.isOutOfStock) {
        outOfStockCount++;
        urgentList.add(product);
      } else if (product.isLowStock) {
        lowStockCount++;
        urgentList.add(product);
      }
    }

    String summaryMessage;
    String urgencyType;

    if (outOfStockCount > 0) {
      summaryMessage =
          'يوجد $outOfStockCount مواد نفدت من المخزون بحاجة لإعادة الطلب فوراً';
      urgencyType = 'critical';
    } else if (lowStockCount > 0) {
      summaryMessage =
          'يوجد $lowStockCount مواد قاربت على النفاد (أقل من الحد الأدنى)';
      urgencyType = 'warning';
    } else {
      summaryMessage = '';
      urgencyType = 'none';
    }

    return InventoryAlertSummary(
      outOfStockCount: outOfStockCount,
      lowStockCount: lowStockCount,
      urgentProducts: urgentList,
      summaryMessage: summaryMessage,
      urgencyType: urgencyType,
    );
  }

  static SectionBadge? buildInventoryBadge(ProductEntity product) {
    if (!product.isActive || !product.trackQuantity) return null;
    if (!product.isOutOfStock && !product.isLowStock) return null;

    final isOut = product.isOutOfStock;
    return SectionBadge(
      sectionKey: 'inventory',
      sectionName: 'المخزون',
      title: isOut ? 'نفاد كمية' : 'مخزون منخفض',
      message: isOut
          ? 'المادة "${product.name}" نفدت بالكامل من المخزون'
          : 'المادة "${product.name}" متبقي منها ${product.quantity} فقط (الحد الأدنى: ${product.minQuantity})',
      type: isOut ? 'critical' : 'warning',
      createdAt: DateTime.now(),
      targetId: product.id,
    );
  }

  // ==================== 4. العملاء (Customers) ====================

  /// بناء ملخص تفاعلي لحدود ائتمان العملاء
  static CustomerAlertSummary buildCustomerSummary(
    List<CustomerEntity> customers,
  ) {
    var creditLimitExceededCount = 0;
    var highDebtCount = 0;
    var totalExceededDebt = 0.0;
    final urgentList = <CustomerEntity>[];

    for (final customer in customers) {
      final debt = customer.totalDebt;
      final limit = customer.creditLimit;

      if (limit != null && limit > 0 && debt > limit) {
        creditLimitExceededCount++;
        totalExceededDebt += (debt - limit);
        urgentList.add(customer);
      } else if (debt > 500000) {
        // ديون مرتفعة عامة
        highDebtCount++;
        urgentList.add(customer);
      }
    }

    String summaryMessage;
    String urgencyType;

    if (creditLimitExceededCount > 0) {
      summaryMessage =
          'يوجد $creditLimitExceededCount عملاء تجاوزوا حد الائتمان المسموح';
      urgencyType = 'critical';
    } else if (highDebtCount > 0) {
      summaryMessage = 'يوجد $highDebtCount عملاء لديهم مستحقات ديون مرتفعة';
      urgencyType = 'warning';
    } else {
      summaryMessage = '';
      urgencyType = 'none';
    }

    return CustomerAlertSummary(
      creditLimitExceededCount: creditLimitExceededCount,
      highDebtCount: highDebtCount,
      totalExceededDebt: totalExceededDebt,
      urgentCustomers: urgentList,
      summaryMessage: summaryMessage,
      urgencyType: urgencyType,
    );
  }

  static SectionBadge buildCashInvoiceBadge(
    InvoiceEntity invoice, {
    required String customerName,
    required String transactionType,
  }) {
    String title;
    String message;
    String type;
    if (transactionType == 'clearance') {
      title = 'تصفير حساب';
      message = 'تم تصفير حساب العميل $customerName وأرشفة الفواتير';
      type = 'info';
    } else if (transactionType == 'payment') {
      title = 'سند صرف نقدي';
      message =
          'إعطاء مبلغ نقدي للعميل $customerName بقيمة ${invoice.totalAmount} د.ع';
      type = 'warning';
    } else {
      title = 'سند قبض نقدي';
      message =
          'استلام مبلغ نقدي من العميل $customerName بقيمة ${invoice.totalAmount} د.ع';
      type = 'info';
    }

    return SectionBadge(
      sectionKey: 'customers',
      sectionName: 'العملاء',
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
      customerName: customerName,
      targetId: invoice.id,
    );
  }

  // ==================== 5. الصيانة (Maintenance) ====================

  /// بناء ملخص تفاعلي لطلبات الصيانة
  static MaintenanceAlertSummary buildMaintenanceSummary(
    List<MaintenanceRequestEntity> requests,
  ) {
    var urgentCount = 0;
    var overdueCount = 0;
    var pendingCount = 0;
    final urgentList = <MaintenanceRequestEntity>[];
    final now = DateTime.now();

    for (final request in requests) {
      if (request.status == 'completed' || request.status == 'cancelled') {
        continue;
      }
      pendingCount++;
      var isUrgent = false;

      if (request.priority == 'urgent' || request.priority == 'high') {
        urgentCount++;
        isUrgent = true;
      }

      if (request.scheduledDate != null &&
          request.scheduledDate!.isBefore(now)) {
        overdueCount++;
        isUrgent = true;
      }

      if (isUrgent) {
        urgentList.add(request);
      }
    }

    String summaryMessage;
    String urgencyType;

    if (overdueCount > 0) {
      summaryMessage =
          'يوجد $overdueCount طلبات صيانة متأخرة عن الموعد المتوقع';
      urgencyType = 'critical';
    } else if (urgentCount > 0) {
      summaryMessage = 'يوجد $urgentCount طلبات صيانة عاجلة بحاجة للعمل';
      urgencyType = 'warning';
    } else {
      summaryMessage = '';
      urgencyType = 'none';
    }

    return MaintenanceAlertSummary(
      urgentCount: urgentCount,
      overdueCount: overdueCount,
      pendingCount: pendingCount,
      urgentRequests: urgentList,
      summaryMessage: summaryMessage,
      urgencyType: urgencyType,
    );
  }

  // ==================== 6. التأجير (Rentals) ====================

  /// بناء ملخص تفاعلي لعقود التأجير
  static RentalAlertSummary buildRentalSummary(
    List<RentalEntity> rentals, {
    int warningDays = 2,
  }) {
    var expiredCount = 0;
    var expiringSoonCount = 0;
    final urgentList = <RentalEntity>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final rental in rentals) {
      if (rental.status == 'returned' || rental.status == 'cancelled') {
        continue;
      }
      final end = DateTime(
        rental.endDate.year,
        rental.endDate.month,
        rental.endDate.day,
      );
      final days = end.difference(today).inDays;

      if (days < 0 || rental.status == 'overdue') {
        expiredCount++;
        urgentList.add(rental);
      } else if (days <= warningDays) {
        expiringSoonCount++;
        urgentList.add(rental);
      }
    }

    String summaryMessage;
    String urgencyType;

    if (expiredCount > 0) {
      summaryMessage = 'يوجد $expiredCount عقود تأجير متأخرة عن موعد الإرجاع';
      urgencyType = 'critical';
    } else if (expiringSoonCount > 0) {
      summaryMessage =
          'يوجد $expiringSoonCount عقود تأجير تنتهي اليوم أو خلال $warningDays يوم';
      urgencyType = 'warning';
    } else {
      summaryMessage = '';
      urgencyType = 'none';
    }

    return RentalAlertSummary(
      expiredCount: expiredCount,
      expiringSoonCount: expiringSoonCount,
      urgentRentals: urgentList,
      summaryMessage: summaryMessage,
      urgencyType: urgencyType,
    );
  }

  // ==================== 7. المصروفات (Expenses) ====================

  /// بناء ملخص تفاعلي للمصروفات
  static ExpenseAlertSummary buildExpenseSummary(List<ExpenseEntity> expenses) {
    var pendingCount = 0;
    var unpaidCount = 0;
    var totalPendingAmount = 0.0;
    final urgentList = <ExpenseEntity>[];

    for (final expense in expenses) {
      if (expense.status == 'pending') {
        pendingCount++;
        totalPendingAmount += expense.amount;
        urgentList.add(expense);
      } else if (expense.status == 'unpaid') {
        unpaidCount++;
        totalPendingAmount += expense.amount;
        urgentList.add(expense);
      }
    }

    String summaryMessage;
    String urgencyType;

    if (pendingCount > 0 || unpaidCount > 0) {
      summaryMessage =
          'يوجد ${pendingCount + unpaidCount} مصروفات معلقة أو غير مدفوعة بحاجة للمراجعة';
      urgencyType = 'warning';
    } else {
      summaryMessage = '';
      urgencyType = 'none';
    }

    return ExpenseAlertSummary(
      pendingCount: pendingCount,
      unpaidCount: unpaidCount,
      totalPendingAmount: totalPendingAmount,
      urgentExpenses: urgentList,
      summaryMessage: summaryMessage,
      urgencyType: urgencyType,
    );
  }
}
