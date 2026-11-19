import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../entities/activation_recharge_entity.dart';
import '../entities/subscription_entity.dart';
import '../entities/subscription_log_entity.dart';
import '../entities/subscription_type_entity.dart';
import '../entities/subscription_types_page.dart';
import '../entities/subscriptions_page.dart';

/// واجهة مستودع الاشتراكات
abstract class SubscriptionRepository {
  /// الحصول على جميع الاشتراكات
  Future<Either<Failure, List<SubscriptionEntity>>> getSubscriptions(
    String organizationEmail,
  );

  /// الحصول على الاشتراكات بشكل تدريجي (pagination)
  Future<Either<Failure, SubscriptionsPage>> getSubscriptionsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  });

  // الطرق الجديدة للـ streams
  Stream<Either<Failure, List<SubscriptionEntity>>> getSubscriptionsStream(
    String organizationEmail, {
    int? limit,
    String? searchQuery,
  });
  Stream<Either<Failure, Map<String, dynamic>>> getSubscriptionStatsStream(
    String organizationEmail, {
    int? limit,
  });

  /// الحصول على أنواع الاشتراكات مع التحديث الفوري
  Stream<Either<Failure, List<SubscriptionTypeEntity>>>
      getSubscriptionTypesStream(String organizationEmail);

  /// الحصول على سجلات الاشتراكات مع التحديث الفوري
  Stream<Either<Failure, List<SubscriptionLogEntity>>>
      getSubscriptionLogsStream({
        String? userId,
        String? searchQuery,
        String? actionFilter,
        String? dateFilter,
        DateTime? startDate,
        DateTime? endDate,
        int? limit,
      });

  /// إنشاء اشتراك جديد
  /// إنشاء اشتراك جديد.
  ///
  /// ⚠️ ملاحظة ذرية للمبرمجين المستقبليين:
  /// إذا مررت [invoiceBuilder] فإن الفاتورة تُنشأ داخل
  /// نفس runTransaction لإنشاء الاشتراك (ذرية كاملة:
  /// الاشتراك + النوع + الصندوق + السجل + الفاتورة +
  /// دين العميل + invoiceIds + relatedInvoiceIds + سجل
  /// الفاتورة). هذا يمنع وجود اشتراك بلا فاتورة إذا
  /// فشل إنشاء الفاتورة — وهو العيب السابق حيث كانت
  /// الفاتورة تُنشأ في معاملة منفصلة بعد الاشتراك.
  /// الدالة تستقبل الاشتراك المُنشأ وترجع الفاتورة
  /// (بناؤها متزامن ولا يقرأ Firestore — القراءات
  /// الضرورية كالعميل تُقرأ قبل المعاملة).
  Future<Either<Failure, void>> createSubscription(
    SubscriptionEntity subscription, {
    InvoiceEntity Function(SubscriptionEntity createdSubscription)? invoiceBuilder,
  });

  /// تحديث اشتراك
  /// ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
  /// ⚠️ نستخدم Firestore runTransaction لضمان all-or-nothing.
  /// ⚠️ expectedUpdatedAt يُستخدم للتحقق من التعديل المتزامن (Optimistic Locking).
  /// ⚠️ إذا لم تُمرر expectedUpdatedAt، لن يتم التحقق من التعديل المتزامن
  /// ⚠️ وستكون عرضة لـ Lost Update Problem.
  Future<Either<Failure, void>> updateSubscription(
    SubscriptionEntity subscription, {
    int? expectedUpdatedAt,
  });

  /// حذف اشتراك
  Future<Either<Failure, void>> deleteSubscription(String subscriptionId);

  /// تحديث حالة الاشتراك
  Future<Either<Failure, void>> updateSubscriptionStatus({
    required String subscriptionId,
    required String status,
    required String organizationEmail,
    String? reason,
    String? updatedBy,
  });

  /// تجديد الاشتراك
  /// ⚠️ ملاحظة ذرية: إذا مررت [invoiceBuilder] تُنشأ
  /// الفاتورة داخل نفس المعاملة الذرية للتجديد
  /// (نفس سلوك createSubscription) لمنع اشتراك
  /// مُجدَّد بلا فاتورة.
  Future<Either<Failure, SubscriptionEntity>> renewSubscription({
    required String subscriptionId,
    required String organizationEmail,
    DateTime? customStartDate,
    bool? isAutoRenew,
    bool? isPaid,
    InvoiceEntity Function(SubscriptionEntity renewedSubscription)? invoiceBuilder,
  });

  /// الحصول على اشتراكات عميل محدد
  Future<Either<Failure, List<SubscriptionEntity>>> getCustomerSubscriptions({
    required String customerId,
    required String organizationEmail,
    String? status,
  });

  /// الحصول على الاشتراكات المنتهية الصلاحية
  Future<Either<Failure, List<SubscriptionEntity>>> getExpiredSubscriptions(
    String organizationEmail,
  );

  /// الحصول على الاشتراكات التي تنتهي قريباً
  Future<Either<Failure, List<SubscriptionEntity>>>
  getExpiringSoonSubscriptions(String organizationEmail, {int daysAhead = 7});

  /// تحديث معلومات الدفع للاشتراك
  Future<Either<Failure, void>> updateSubscriptionPayment({
    required String subscriptionId,
    required String organizationEmail,
    required double amountPaid,
    String? paymentMethod,
    String? paymentReference,
  });

  /// الحصول على اشتراك بواسطة المعرف
  Future<Either<Failure, SubscriptionEntity?>> getSubscriptionById(
    String subscriptionId,
  );

  /// البحث عن أسماء الاشتراكات المشابهة
  Future<Either<Failure, List<String>>> searchSubscriptionNames({
    required String query,
  });

  // ===== Subscription Types Methods =====

  /// الحصول على جميع أنواع الاشتراكات
  Future<Either<Failure, List<SubscriptionTypeEntity>>> getSubscriptionTypes(
    String organizationEmail,
  );

  /// الحصول على أنواع الاشتراكات بشكل تدريجي (pagination)
  Future<Either<Failure, SubscriptionTypesPage>> getSubscriptionTypesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  });

  /// إنشاء نوع اشتراك جديد
  Future<Either<Failure, void>> createSubscriptionType(
    SubscriptionTypeEntity type,
  );

  /// تحديث نوع اشتراك
  Future<Either<Failure, void>> updateSubscriptionType(
    SubscriptionTypeEntity type,
  );

  /// حذف نوع اشتراك
  Future<Either<Failure, void>> deleteSubscriptionType(
    String typeId,
    String organizationEmail,
  );

  /// البحث عن أسماء أنواع الاشتراكات المشابهة
  Future<Either<Failure, List<String>>> searchSubscriptionTypeNames({
    required String query,
  });

  // ===== Activation Recharge Methods =====

  /// شحن تفعيلات لنوع اشتراك
  Future<Either<Failure, void>> rechargeActivations({
    required String subscriptionTypeId,
    required String subscriptionTypeName,
    required int quantity,
    required double pricePerActivation,
    required String organizationEmail,
    required String createdBy,
    String? boxId,
  });

  /// الحصول على سجل شحن التفعيلات
  Future<Either<Failure, List<ActivationRechargeEntity>>>
  getActivationRecharges({
    String? subscriptionTypeId,
    String? organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  // ===== Subscription Logs Methods =====

  /// الحصول على سجل نشاطات الاشتراكات
  Future<Either<Failure, List<SubscriptionLogEntity>>> getSubscriptionLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// إضافة سجل نشاط جديد للاشتراكات
  Future<Either<Failure, SubscriptionLogEntity>> addSubscriptionLog({
    required String userId,
    required String actionType,
    String? userName,
    String? userEmail,
    String? details,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
    Map<String, dynamic>? deviceInfo,
    bool isSuccess = true,
  });

  /// حذف سجل نشاط محدد
  Future<Either<Failure, void>> deleteSubscriptionLog(String logId);

  /// مسح سجلات النشاطات
  Future<Either<Failure, void>> clearSubscriptionLogs({
    String? userId,
    DateTime? beforeDate,
  });
}
