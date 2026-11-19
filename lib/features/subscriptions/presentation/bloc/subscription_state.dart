import 'package:equatable/equatable.dart';

import '../../../invoices/domain/entities/invoice_entity.dart';
import '../../domain/entities/activation_recharge_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/subscription_log_entity.dart';
import '../../domain/entities/subscription_type_entity.dart';

/// حالات الاشتراكات
abstract class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class SubscriptionInitial extends SubscriptionState {}

/// حالة التحميل
class SubscriptionLoading extends SubscriptionState {}

/// حالة النجاح
class SubscriptionLoaded extends SubscriptionState {
  const SubscriptionLoaded({
    required this.subscriptions,
    required this.filteredSubscriptions,
    required this.subscriptionTypes,
    required this.stats,
    this.isGridView = false,
    this.hasMoreTypesData = true,
    this.isLoadingMoreTypes = false,
    this.lastDocumentTypes,
  });
  final List<SubscriptionEntity> subscriptions;
  final List<SubscriptionEntity> filteredSubscriptions;
  final List<String> subscriptionTypes;
  final Map<String, dynamic> stats;
  final bool isGridView;
  final bool hasMoreTypesData;
  final bool isLoadingMoreTypes;
  final dynamic lastDocumentTypes;

  @override
  List<Object?> get props => [
    subscriptions,
    filteredSubscriptions,
    subscriptionTypes,
    stats,
    isGridView,
    hasMoreTypesData,
    isLoadingMoreTypes,
    lastDocumentTypes,
  ];

  SubscriptionLoaded copyWith({
    List<SubscriptionEntity>? subscriptions,
    List<SubscriptionEntity>? filteredSubscriptions,
    List<String>? subscriptionTypes,
    Map<String, dynamic>? stats,
    bool? isGridView,
    bool? hasMoreTypesData,
    bool? isLoadingMoreTypes,
    dynamic lastDocumentTypes,
  }) {
    return SubscriptionLoaded(
      subscriptions: subscriptions ?? this.subscriptions,
      filteredSubscriptions: filteredSubscriptions ?? this.filteredSubscriptions,
      subscriptionTypes: subscriptionTypes ?? this.subscriptionTypes,
      stats: stats ?? this.stats,
      isGridView: isGridView ?? this.isGridView,
      hasMoreTypesData: hasMoreTypesData ?? this.hasMoreTypesData,
      isLoadingMoreTypes: isLoadingMoreTypes ?? this.isLoadingMoreTypes,
      lastDocumentTypes: lastDocumentTypes ?? this.lastDocumentTypes,
    );
  }
}

/// حالة الخطأ
class SubscriptionError extends SubscriptionState {
  const SubscriptionError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// حالة نجاح العملية
class SubscriptionOperationSuccess extends SubscriptionState {
  const SubscriptionOperationSuccess(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

// ===== Subscription Types States =====

/// حالة تحميل أنواع الاشتراكات
class SubscriptionTypesLoaded extends SubscriptionState {
  const SubscriptionTypesLoaded({
    required this.types,
    this.hasMoreTypesData = true,
    this.isLoadingMoreTypes = false,
    this.lastDocumentTypes,
  });
  final List<SubscriptionTypeEntity> types;
  final bool hasMoreTypesData;
  final bool isLoadingMoreTypes;
  final dynamic lastDocumentTypes;

  @override
  List<Object?> get props => [
    types,
    hasMoreTypesData,
    isLoadingMoreTypes,
    lastDocumentTypes,
  ];

  SubscriptionTypesLoaded copyWith({
    List<SubscriptionTypeEntity>? types,
    bool? hasMoreTypesData,
    bool? isLoadingMoreTypes,
    dynamic lastDocumentTypes,
  }) {
    return SubscriptionTypesLoaded(
      types: types ?? this.types,
      hasMoreTypesData: hasMoreTypesData ?? this.hasMoreTypesData,
      isLoadingMoreTypes: isLoadingMoreTypes ?? this.isLoadingMoreTypes,
      lastDocumentTypes: lastDocumentTypes ?? this.lastDocumentTypes,
    );
  }
}

// ===== Subscription Logs States =====

/// حالة تحميل سجلات الاشتراكات
class SubscriptionLogsLoaded extends SubscriptionState {
  const SubscriptionLogsLoaded({required this.logs});

  final List<SubscriptionLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}

// ===== Activation Recharge States =====

/// حالة نجاح شحن التفعيلات
class ActivationRechargeSuccess extends SubscriptionState {
  const ActivationRechargeSuccess({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

/// حالة تحميل سجل شحن التفعيلات
class ActivationRechargesLoaded extends SubscriptionState {
  const ActivationRechargesLoaded({required this.recharges});

  final List<ActivationRechargeEntity> recharges;

  @override
  List<Object?> get props => [recharges];
}

// ===== New Subscription Management States =====

/// حالة تحميل اشتراكات عميل محدد
class CustomerSubscriptionsLoaded extends SubscriptionState {
  const CustomerSubscriptionsLoaded({
    required this.customerId,
    required this.subscriptions,
  });

  final String customerId;
  final List<SubscriptionEntity> subscriptions;

  @override
  List<Object?> get props => [customerId, subscriptions];
}

/// حالة تحميل الاشتراكات المنتهية
class ExpiredSubscriptionsLoaded extends SubscriptionState {
  const ExpiredSubscriptionsLoaded({required this.subscriptions});

  final List<SubscriptionEntity> subscriptions;

  @override
  List<Object?> get props => [subscriptions];
}

/// حالة تحميل الاشتراكات التي تنتهي قريباً
class ExpiringSoonSubscriptionsLoaded extends SubscriptionState {
  const ExpiringSoonSubscriptionsLoaded({
    required this.subscriptions,
    required this.daysAhead,
  });

  final List<SubscriptionEntity> subscriptions;
  final int daysAhead;

  @override
  List<Object?> get props => [subscriptions, daysAhead];
}

/// حالة الاشتراكات النشطة مع التحديث الفوري
class SubscriptionsStreamActive extends SubscriptionState {
  const SubscriptionsStreamActive({
    required this.subscriptions,
    required this.filteredSubscriptions,
    required this.subscriptionTypes,
    this.stats = const {},
    this.isGridView = false,
    this.searchQuery = '',
    this.statusFilter,
    this.typeFilter,
    this.hasMoreData = false,
    this.isLoadingMore = false,
    this.lastDocument,
  });

  final List<SubscriptionEntity> subscriptions;
  final List<SubscriptionEntity> filteredSubscriptions;
  final List<String> subscriptionTypes;
  final Map<String, dynamic> stats;
  final bool isGridView;
  final String searchQuery;
  final String? statusFilter;
  final String? typeFilter;
  final bool hasMoreData;
  final bool isLoadingMore;
  final dynamic lastDocument;

  SubscriptionsStreamActive copyWith({
    List<SubscriptionEntity>? subscriptions,
    List<SubscriptionEntity>? filteredSubscriptions,
    List<String>? subscriptionTypes,
    Map<String, dynamic>? stats,
    bool? isGridView,
    String? searchQuery,
    String? statusFilter,
    String? typeFilter,
    bool? hasMoreData,
    bool? isLoadingMore,
    dynamic lastDocument,
  }) {
    return SubscriptionsStreamActive(
      subscriptions: subscriptions ?? this.subscriptions,
      filteredSubscriptions: filteredSubscriptions ?? this.filteredSubscriptions,
      subscriptionTypes: subscriptionTypes ?? this.subscriptionTypes,
      stats: stats ?? this.stats,
      isGridView: isGridView ?? this.isGridView,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      typeFilter: typeFilter ?? this.typeFilter,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }

  @override
  List<Object?> get props => [
    subscriptions,
    filteredSubscriptions,
    subscriptionTypes,
    stats,
    isGridView,
    searchQuery,
    statusFilter,
    typeFilter,
    hasMoreData,
    isLoadingMore,
    lastDocument,
  ];
}

// ===== Subscription By Id State =====

/// حالة تحميل اشتراك بواسطة المعرف
class SubscriptionByIdLoaded extends SubscriptionState {
  const SubscriptionByIdLoaded({
    required this.subscriptionId,
    this.subscription,
  });

  final String subscriptionId;
  final SubscriptionEntity? subscription;

  @override
  List<Object?> get props => [subscriptionId, subscription];
}

// ===== Subscription Invoices State =====

/// حالة تحميل فواتير اشتراك
class SubscriptionInvoicesLoaded extends SubscriptionState {
  const SubscriptionInvoicesLoaded({required this.invoices});

  final List<InvoiceEntity> invoices;

  @override
  List<Object?> get props => [invoices];
}
