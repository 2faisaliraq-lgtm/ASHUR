import 'package:ashur/features/subscriptions/domain/entities/subscription_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionNotificationService', () {
    test('subscription daysRemaining is calculated correctly', () {
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 3));

      final subscription = SubscriptionEntity(
        id: '1',
        name: 'اشتراك تجريبي',
        type: 'شهري',
        price: 100,
        duration: '30',
        status: 'active',
        startDate: now.subtract(const Duration(days: 30)),
        endDate: endDate,
        organizationEmail: 'test@example.com',
        createdAt: now,
        updatedAt: now,
        createdBy: 'test_user',
      );

      expect(subscription.daysRemaining, greaterThanOrEqualTo(2));
      expect(subscription.daysRemaining, lessThanOrEqualTo(3));
    });
  });
}
