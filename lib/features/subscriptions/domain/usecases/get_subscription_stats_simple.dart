import '../repositories/subscription_repository.dart';

/// حساب إحصائيات الاشتراكات البسيطة
class GetSubscriptionStatsSimple {
  GetSubscriptionStatsSimple(this.repository);
  final SubscriptionRepository repository;

  Future<Map<String, dynamic>> call(String organizationEmail) async {
    // ✅ تم التنبيه: هذه الدالة تستخدم getSubscriptions وتعيد إحصائيات الاشتراكات
    // إذا حدث خطأ، تعيد قيم افتراضية لجميع الإحصائيات (صفر)
    //	getSubscriptionStatsStream تعيد تدفق الإحصائيات في الوقت الفعلي
    try {
      final result = await repository.getSubscriptions(organizationEmail);

      return await result.fold(
        (failure) => {'total': 0, 'active': 0, 'expired': 0, 'expiringSoon': 0},
        (subscriptions) {
          final total = subscriptions.length;
          final active = subscriptions
              .where((s) => s.status == 'active' && !s.isExpired)
              .length;
          final expired = subscriptions
              .where((s) => s.isExpired)
              .length;
          final expiringSoon = subscriptions
              .where((s) => s.isExpiringSoon)
              .length;

          return {
            'total': total,
            'active': active,
            'expired': expired,
            'expiringSoon': expiringSoon,
          };
        },
      );
    } on Exception catch (_) {
      return {'total': 0, 'active': 0, 'expired': 0, 'expiringSoon': 0};
    }
  }
}
