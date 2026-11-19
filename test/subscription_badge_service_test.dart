import 'package:ashur/core/services/section_badge_service.dart';
import 'package:ashur/features/customers/domain/entities/customer_entity.dart';
import 'package:ashur/features/expenses/domain/entities/expense_entity.dart';
import 'package:ashur/features/inventory/domain/entities/product_entity.dart';
import 'package:ashur/features/invoices/domain/entities/invoice_entity.dart';
import 'package:ashur/features/maintenance/domain/entities/maintenance_request_entity.dart';
import 'package:ashur/features/rentals/domain/entities/rental_entity.dart';
import 'package:ashur/features/subscriptions/domain/entities/subscription_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SectionBadgeService', () {
    test('shows subscription badge when end date is near', () {
      final subscription = SubscriptionEntity(
        id: '1',
        name: 'اشتراك أساسي',
        type: 'شهري',
        price: 50,
        duration: 'monthly',
        status: 'active',
        startDate: DateTime.now().subtract(const Duration(days: 20)),
        endDate: DateTime.now().add(const Duration(days: 2)),
        organizationEmail: 'store@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'admin',
        customerName: 'فلان',
      );

      final badge = SectionBadgeService.buildSubscriptionBadge(subscription);

      expect(badge, isNotNull);
      expect(badge!.message, contains('سينتهي اشتراكه'));
    });

    test(
      'does not show subscription badge when subscription is still active for long time',
      () {
        final subscription = SubscriptionEntity(
          id: '2',
          name: 'اشتراك أساسي',
          type: 'شهري',
          price: 50,
          duration: 'monthly',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 25)),
          organizationEmail: 'store@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: 'admin',
          customerName: 'علي',
        );

        final badge = SectionBadgeService.buildSubscriptionBadge(subscription);

        expect(badge, isNull);
      },
    );
    test('summarizes expired and urgently expiring subscriptions', () {
      final now = DateTime.now();
      final expired = _subscription(
        id: 'expired',
        status: 'active',
        endDate: now.subtract(const Duration(days: 1)),
      );
      final expiringSoon = _subscription(
        id: 'soon',
        status: 'active',
        endDate: now.add(const Duration(days: 2)),
      );
      final cancelled = _subscription(
        id: 'cancelled',
        status: 'cancelled',
        endDate: now,
      );

      final summary = SectionBadgeService.buildSubscriptionSummary([
        expired,
        expiringSoon,
        cancelled,
      ]);

      expect(summary.expiredCount, 1);
      expect(summary.expiringSoonCount, 1);
      expect(summary.urgentSubscriptions.map((item) => item.id), [
        'expired',
        'soon',
      ]);
      expect(summary.urgencyType, 'critical');
      expect(summary.hasUrgentItems, isTrue);
    });

    test('excludes active subscriptions outside the warning window', () {
      final subscription = _subscription(
        id: 'later',
        status: 'active',
        endDate: DateTime.now().add(const Duration(days: 8)),
      );

      final summary = SectionBadgeService.buildSubscriptionSummary([
        subscription,
      ]);

      expect(summary.totalUrgentCount, 0);
      expect(summary.summaryMessage, isEmpty);
      expect(summary.urgencyType, 'none');
    });

    test('summarizes invoices accurately for overdue and unpaid items', () {
      final now = DateTime.now();
      final overdueInvoice = InvoiceEntity(
        id: 'inv_1',
        invoiceNumber: 'INV-101',
        customerName: 'عميل 1',
        customerPhone: '0770',
        invoiceDate: now.subtract(const Duration(days: 35)),
        totalAmount: 1000,
        paidAmount: 200,
        remainingAmount: 800,
        status: 'partial',
        type: 'sales',
        items: const [],
        organizationEmail: 'store@example.com',
        createdAt: now,
        updatedAt: now,
        createdBy: 'admin',
      );
      final recentInvoice = InvoiceEntity(
        id: 'inv_2',
        invoiceNumber: 'INV-102',
        customerName: 'عميل 2',
        customerPhone: '0770',
        invoiceDate: now.subtract(const Duration(days: 5)),
        totalAmount: 500,
        paidAmount: 0,
        remainingAmount: 500,
        status: 'unpaid',
        type: 'sales',
        items: const [],
        organizationEmail: 'store@example.com',
        createdAt: now,
        updatedAt: now,
        createdBy: 'admin',
      );

      final summary = SectionBadgeService.buildInvoiceSummary([
        overdueInvoice,
        recentInvoice,
      ]);

      expect(summary.overdueCount, 1);
      expect(summary.unpaidCount, 1);
      expect(summary.totalRemainingDebt, 1300);
      expect(summary.urgencyType, 'critical');
      expect(summary.hasUrgentItems, isTrue);
    });

    test('summarizes inventory for out-of-stock and low-stock products', () {
      final now = DateTime.now();
      final outOfStockProduct = ProductEntity(
        id: 'p1',
        name: 'شاحن',
        quantity: 0,
        minQuantity: 5,
        unit: 'قطعة',
        sellingPrice: 10,
        costPrice: 5,
        trackQuantity: true,
        isActive: true,
        organizationEmail: 'store@example.com',
        createdAt: now,
        createdBy: 'admin',
      );
      final lowStockProduct = ProductEntity(
        id: 'p2',
        name: 'سماعة',
        quantity: 3,
        minQuantity: 5,
        unit: 'قطعة',
        sellingPrice: 20,
        costPrice: 10,
        trackQuantity: true,
        isActive: true,
        organizationEmail: 'store@example.com',
        createdAt: now,
        createdBy: 'admin',
      );

      final summary = SectionBadgeService.buildInventorySummary([
        outOfStockProduct,
        lowStockProduct,
      ]);

      expect(summary.outOfStockCount, 1);
      expect(summary.lowStockCount, 1);
      expect(summary.urgencyType, 'critical');
      expect(summary.hasUrgentItems, isTrue);
    });

    test('summarizes customers exceeding credit limit', () {
      final now = DateTime.now();
      final customer = CustomerEntity(
        id: 'c1',
        name: 'أحمد',
        phone: '0770',
        email: 'ahmed@test.com',
        totalPurchases: 5000,
        totalDebt: 3000,
        creditLimit: 2000,
        status: 'active',
        organizationEmail: 'store@example.com',
        createdAt: now,
        updatedAt: now,
      );

      final summary = SectionBadgeService.buildCustomerSummary([customer]);

      expect(summary.creditLimitExceededCount, 1);
      expect(summary.totalExceededDebt, 1000);
      expect(summary.urgencyType, 'critical');
    });

    test('summarizes maintenance requests for urgent and overdue tasks', () {
      final now = DateTime.now();
      final request = MaintenanceRequestEntity(
        id: 'm1',
        customerId: 'c1',
        customerName: 'سعيد',
        title: 'صيانة مكيف',
        description: 'تسريب',
        status: 'in_progress',
        priority: 'urgent',
        requestDate: now.subtract(const Duration(days: 3)),
        requestedBy: 'عميل',
        scheduledDate: now.subtract(const Duration(days: 1)),
        organizationEmail: 'store@example.com',
        createdAt: now,
        updatedAt: now,
        createdBy: 'admin',
      );

      final summary = SectionBadgeService.buildMaintenanceSummary([request]);

      expect(summary.urgentCount, 1);
      expect(summary.overdueCount, 1);
      expect(summary.urgencyType, 'critical');
    });

    test('summarizes rentals for overdue and expiring agreements', () {
      final now = DateTime.now();
      final rental = RentalEntity(
        id: 'r1',
        itemName: 'سيارة',
        renterName: 'خالد',
        rentalPrice: 100,
        deposit: 50,
        paymentFrequency: 'daily',
        paymentDay: 1,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 1)),
        status: 'overdue',
        organizationEmail: 'store@example.com',
        createdAt: now,
        createdBy: 'admin',
      );

      final summary = SectionBadgeService.buildRentalSummary([rental]);

      expect(summary.expiredCount, 1);
      expect(summary.urgencyType, 'critical');
    });

    test('summarizes expenses for pending items', () {
      final now = DateTime.now();
      final expense = ExpenseEntity(
        id: 'e1',
        title: 'فاتورة كهرباء',
        description: 'شهر 5',
        amount: 250,
        category: 'bills',
        date: now,
        paymentMethod: 'cash',
        status: 'pending',
        organizationEmail: 'store@example.com',
        createdAt: now,
        updatedAt: now,
        createdBy: 'admin',
      );

      final summary = SectionBadgeService.buildExpenseSummary([expense]);

      expect(summary.pendingCount, 1);
      expect(summary.totalPendingAmount, 250);
      expect(summary.urgencyType, 'warning');
    });
  });
}

SubscriptionEntity _subscription({
  required String id,
  required String status,
  required DateTime endDate,
}) {
  final now = DateTime.now();
  return SubscriptionEntity(
    id: id,
    name: 'اشتراك تجريبي',
    type: 'شهري',
    price: 50,
    duration: 'monthly',
    status: status,
    startDate: now.subtract(const Duration(days: 30)),
    endDate: endDate,
    organizationEmail: 'test@example.com',
    createdAt: now,
    updatedAt: now,
    createdBy: 'test_user',
  );
}
