import 'package:equatable/equatable.dart';

/// كيان سجل شحن التفعيلات
class ActivationRechargeEntity extends Equatable {
  const ActivationRechargeEntity({
    required this.id,
    required this.subscriptionTypeId,
    required this.subscriptionTypeName,
    required this.addedQuantity,
    required this.pricePerActivation,
    required this.totalPrice,
    required this.timestamp,
    required this.createdBy,
    required this.organizationEmail,
    this.boxId,
    this.boxTransactionId,
  });

  final String id;
  final String subscriptionTypeId; // نوع الاشتراك
  final String subscriptionTypeName; // اسم نوع الاشتراك
  final int addedQuantity; // الكمية المضافة
  final double pricePerActivation; // سعر التفعيلة الواحدة
  final double totalPrice; // السعر الإجمالي
  final DateTime timestamp; // تاريخ العملية
  final String createdBy; // من أضاف
  final String organizationEmail; // البريد الإلكتروني للمؤسسة
  final String? boxId; // معرف الصندوق
  final String? boxTransactionId; // معرف حركة الصندوق

  @override
  List<Object?> get props => [
    id,
    subscriptionTypeId,
    subscriptionTypeName,
    addedQuantity,
    pricePerActivation,
    totalPrice,
    timestamp,
    createdBy,
    organizationEmail,
    boxId,
    boxTransactionId,
  ];

  /// نسخ الكيان مع تحديث بعض الحقول
  ActivationRechargeEntity copyWith({
    String? id,
    String? subscriptionTypeId,
    String? subscriptionTypeName,
    int? addedQuantity,
    double? pricePerActivation,
    double? totalPrice,
    DateTime? timestamp,
    String? createdBy,
    String? organizationEmail,
    String? boxId,
    String? boxTransactionId,
  }) {
    return ActivationRechargeEntity(
      id: id ?? this.id,
      subscriptionTypeId: subscriptionTypeId ?? this.subscriptionTypeId,
      subscriptionTypeName: subscriptionTypeName ?? this.subscriptionTypeName,
      addedQuantity: addedQuantity ?? this.addedQuantity,
      pricePerActivation: pricePerActivation ?? this.pricePerActivation,
      totalPrice: totalPrice ?? this.totalPrice,
      timestamp: timestamp ?? this.timestamp,
      createdBy: createdBy ?? this.createdBy,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      boxId: boxId ?? this.boxId,
      boxTransactionId: boxTransactionId ?? this.boxTransactionId,
    );
  }
}
