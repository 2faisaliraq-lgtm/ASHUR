import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/subscription_repository.dart';

/// حالة استخدام للحصول على إحصائيات الاشتراكات
class GetSubscriptionStats {
  GetSubscriptionStats(this.repository);
  final SubscriptionRepository repository;

  Future<Either<Failure, Map<String, dynamic>>> call(
    String organizationEmail,
  ) async {
    // ⚠️ ملاحظة أداء توثيقية للمبرمجين المستقبليين: هذه الطريقة تحمل كل الاشتراكات
    // ثم يحسب الإحصائيات في الذاكرة (بطيء للمجموعات الكبيرة). يفضل استخدام
    // getSubscriptionStatsStream الذي يحسب الإحصائيات مباشرة من بيانات المستند
    // الخام دون بناء كيانات كاملة. يتم الاحتفاظ بهذا المسار للاستخدام لمرة واحدة
    // فقط (non-stream).
    final result = await repository.getSubscriptions(organizationEmail);

    return result.fold(Left.new, (subscriptions) {
      final total = subscriptions.length;
      final active = subscriptions
          .where((s) => s.status == 'active' && !s.isExpired)
          .length;
      final expired = subscriptions.where((s) => s.isExpired).length;
      final expiringSoon = subscriptions.where((s) => s.isExpiringSoon).length;

      return Right({
        'total': total,
        'active': active,
        'expired': expired,
        'expiringSoon': expiringSoon,
      });
    });
  }
}
