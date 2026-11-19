import 'package:equatable/equatable.dart';

import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/subscription_type_entity.dart';

/// أحداث الاشتراكات
abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

/// حدث تحميل الاشتراكات
class LoadSubscriptionsEvent extends SubscriptionEvent {
  const LoadSubscriptionsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث تحميل المزيد من الاشتراكات (pagination)
class LoadMoreSubscriptionsEvent extends SubscriptionEvent {
  const LoadMoreSubscriptionsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث إنشاء اشتراك
class CreateSubscriptionEvent extends SubscriptionEvent {
  const CreateSubscriptionEvent(this.subscription, {required this.type});
  final SubscriptionEntity subscription;
  final String type;

  @override
  List<Object?> get props => [subscription, type];
}

/// حدث تحديث حالة الاشتراك
class UpdateSubscriptionStatusEvent extends SubscriptionEvent {
  const UpdateSubscriptionStatusEvent({
    required this.subscriptionId,
    required this.status,
    required this.organizationEmail,
    this.reason,
    this.updatedBy,
  });
  final String subscriptionId;
  final String status;
  final String organizationEmail;
  final String? reason;
  final String? updatedBy;

  @override
  List<Object?> get props => [
    subscriptionId,
    status,
    organizationEmail,
    reason,
    updatedBy,
  ];
}

/// حدث تحميل أنواع الاشتراكات
class LoadSubscriptionTypesEvent extends SubscriptionEvent {
  const LoadSubscriptionTypesEvent();
}

/// حدث تحميل إحصائيات الاشتراكات
class LoadSubscriptionStatsEvent extends SubscriptionEvent {
  const LoadSubscriptionStatsEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث البحث في الاشتراكات
class SearchSubscriptionsEvent extends SubscriptionEvent {
  const SearchSubscriptionsEvent(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

/// حدث تصفية الاشتراكات
class FilterSubscriptionsEvent extends SubscriptionEvent {
  const FilterSubscriptionsEvent({this.status, this.type});
  final String? status;
  final String? type;

  @override
  List<Object?> get props => [status, type];
}

/// حدث تبديل نوع العرض
class ToggleViewModeEvent extends SubscriptionEvent {
  const ToggleViewModeEvent();
}

// ===== Subscription Types Events =====

/// حدث تحميل قائمة أنواع الاشتراكات
class LoadSubscriptionTypesListEvent extends SubscriptionEvent {
  const LoadSubscriptionTypesListEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث تحميل المزيد من أنواع الاشتراكات (pagination)
class LoadMoreSubscriptionTypesEvent extends SubscriptionEvent {
  const LoadMoreSubscriptionTypesEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث إنشاء نوع اشتراك
class CreateSubscriptionTypeEvent extends SubscriptionEvent {
  const CreateSubscriptionTypeEvent(this.type);
  final SubscriptionTypeEntity type;

  @override
  List<Object?> get props => [type];
}

/// حدث تحديث نوع اشتراك
class UpdateSubscriptionTypeEvent extends SubscriptionEvent {
  const UpdateSubscriptionTypeEvent(this.type);
  final SubscriptionTypeEntity type;

  @override
  List<Object?> get props => [type];
}

/// حدث حذف نوع اشتراك
class DeleteSubscriptionTypeEvent extends SubscriptionEvent {
  const DeleteSubscriptionTypeEvent(this.typeId, this.organizationEmail);
  final String typeId;
  final String organizationEmail;

  @override
  List<Object?> get props => [typeId, organizationEmail];
}

/// حدث حذف اشتراك
class DeleteSubscriptionEvent extends SubscriptionEvent {
  const DeleteSubscriptionEvent(
    this.subscriptionId,
    this.organizationEmail, {
    this.deletedSubscription,
  });
  final String subscriptionId;
  final String organizationEmail;
  final SubscriptionEntity? deletedSubscription;

  @override
  List<Object?> get props => [subscriptionId, organizationEmail, deletedSubscription];
}

// ===== Subscription Logs Events =====

/// حدث تحميل سجلات الاشتراكات
class LoadSubscriptionLogsEvent extends SubscriptionEvent {
  const LoadSubscriptionLogsEvent({
    this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String? userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [
    userId,
    searchQuery,
    actionFilter,
    dateFilter,
    startDate,
    endDate,
    limit,
  ];
}

// ===== New Subscription Management Events =====

/// حدث تجديد الاشتراك
class RenewSubscriptionEvent extends SubscriptionEvent {
  const RenewSubscriptionEvent({
    required this.subscriptionId,
    required this.organizationEmail,
    this.customStartDate,
    this.isAutoRenew,
    this.isPaid,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.finalPrice = 0.0,
  });

  final String subscriptionId;
  final String organizationEmail;
  final DateTime? customStartDate;
  final bool? isAutoRenew;
  final bool? isPaid;
  final double discountAmount; // مبلغ الخصم
  final double taxAmount; // مبلغ الضريبة
  final double finalPrice; // السعر النهائي

  @override
  List<Object?> get props => [
    subscriptionId,
    organizationEmail,
    customStartDate,
    isAutoRenew,
    isPaid,
    discountAmount,
    taxAmount,
    finalPrice,
  ];
}

/// حدث الحصول على اشتراكات عميل محدد
class GetCustomerSubscriptionsEvent extends SubscriptionEvent {
  const GetCustomerSubscriptionsEvent({
    required this.customerId,
    required this.organizationEmail,
    this.status,
  });

  final String customerId;
  final String organizationEmail;
  final String? status;

  @override
  List<Object?> get props => [customerId, organizationEmail, status];
}

/// حدث الحصول على الاشتراكات المنتهية
class GetExpiredSubscriptionsEvent extends SubscriptionEvent {
  const GetExpiredSubscriptionsEvent(this.organizationEmail);

  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث الحصول على الاشتراكات التي تنتهي قريباً
class GetExpiringSoonSubscriptionsEvent extends SubscriptionEvent {
  const GetExpiringSoonSubscriptionsEvent({
    required this.organizationEmail,
    this.daysAhead = 7,
  });

  final String organizationEmail;
  final int daysAhead;

  @override
  List<Object?> get props => [organizationEmail, daysAhead];
}

/// حدث تحديث اشتراك
class UpdateSubscriptionEvent extends SubscriptionEvent {
  const UpdateSubscriptionEvent(this.subscription);
  final SubscriptionEntity subscription;

  @override
  List<Object?> get props => [subscription];
}

/// حدث تحديث معلومات الدفع للاشتراك
class UpdateSubscriptionPaymentEvent extends SubscriptionEvent {
  const UpdateSubscriptionPaymentEvent({
    required this.subscriptionId,
    required this.organizationEmail,
    required this.amountPaid,
    this.paymentMethod,
    this.paymentReference,
  });

  final String subscriptionId;
  final String organizationEmail;
  final double amountPaid;
  final String? paymentMethod;
  final String? paymentReference;

  @override
  List<Object?> get props => [
    subscriptionId,
    organizationEmail,
    amountPaid,
    paymentMethod,
    paymentReference,
  ];
}

// Stream Events
class StartSubscriptionsStreamEvent extends SubscriptionEvent {
  const StartSubscriptionsStreamEvent({
    required this.organizationEmail,
    this.limit,
    this.searchQuery,
  });
  final String organizationEmail;
  final int? limit;
  final String? searchQuery;

  @override
  List<Object?> get props => [organizationEmail, limit, searchQuery];
}

class StopSubscriptionsStreamEvent extends SubscriptionEvent {
  const StopSubscriptionsStreamEvent();
}

class StartSubscriptionStatsStreamEvent extends SubscriptionEvent {
  const StartSubscriptionStatsStreamEvent(this.organizationEmail, {this.limit});
  final String organizationEmail;
  final int? limit;

  @override
  List<Object?> get props => [organizationEmail, limit];
}

class StopSubscriptionStatsStreamEvent extends SubscriptionEvent {
  const StopSubscriptionStatsStreamEvent();
}

// Stream Events for Subscription Types
class StartSubscriptionTypesStreamEvent extends SubscriptionEvent {
  const StartSubscriptionTypesStreamEvent();
}

class StopSubscriptionTypesStreamEvent extends SubscriptionEvent {
  const StopSubscriptionTypesStreamEvent();
}

// Stream Events for Subscription Logs
class StartSubscriptionLogsStreamEvent extends SubscriptionEvent {
  const StartSubscriptionLogsStreamEvent({
    this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String? userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [
    userId,
    searchQuery,
    actionFilter,
    dateFilter,
    startDate,
    endDate,
    limit,
  ];
}

class StopSubscriptionLogsStreamEvent extends SubscriptionEvent {
  const StopSubscriptionLogsStreamEvent();
}

// ===== Activation Recharge Events =====

/// حدث شحن تفعيلات لنوع اشتراك
class RechargeActivationsEvent extends SubscriptionEvent {
  const RechargeActivationsEvent({
    required this.subscriptionTypeId,
    required this.subscriptionTypeName,
    required this.quantity,
    required this.pricePerActivation,
    required this.organizationEmail,
    required this.createdBy,
    this.boxId,
  });

  final String subscriptionTypeId;
  final String subscriptionTypeName;
  final int quantity;
  final double pricePerActivation;
  final String organizationEmail;
  final String createdBy;
  final String? boxId;

  @override
  List<Object?> get props => [
    subscriptionTypeId,
    subscriptionTypeName,
    quantity,
    pricePerActivation,
    organizationEmail,
    createdBy,
    boxId,
  ];
}

/// حدث تحميل سجل شحن التفعيلات
class LoadActivationRechargesEvent extends SubscriptionEvent {
  const LoadActivationRechargesEvent({
    this.subscriptionTypeId,
    this.organizationEmail,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String? subscriptionTypeId;
  final String? organizationEmail;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [
    subscriptionTypeId,
    organizationEmail,
    startDate,
    endDate,
    limit,
  ];
}

// ===== Missing Event Handlers =====

/// حدث ترقية الاشتراك
class UpgradeSubscriptionEvent extends SubscriptionEvent {
  const UpgradeSubscriptionEvent(this.subscription);
  final SubscriptionEntity subscription;

  @override
  List<Object?> get props => [subscription];
}

/// حدث الحصول على اشتراك بواسطة المعرف
class GetSubscriptionByIdEvent extends SubscriptionEvent {
  const GetSubscriptionByIdEvent({
    required this.subscriptionId,
    required this.organizationEmail,
  });
  final String subscriptionId;
  final String organizationEmail;

  @override
  List<Object?> get props => [subscriptionId, organizationEmail];
}

/// حدث الحصول على فواتير اشتراك محدد
class GetSubscriptionInvoicesEvent extends SubscriptionEvent {
  const GetSubscriptionInvoicesEvent({
    required this.subscriptionId,
    required this.organizationEmail,
  });
  final String subscriptionId;
  final String organizationEmail;

  @override
  List<Object?> get props => [subscriptionId, organizationEmail];
}
