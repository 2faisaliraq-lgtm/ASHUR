import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/activation_recharge_entity.dart';

/// نموذج سجل شحن التفعيلات
class ActivationRechargeModel extends ActivationRechargeEntity {
  const ActivationRechargeModel({
    required super.id,
    required super.subscriptionTypeId,
    required super.subscriptionTypeName,
    required super.addedQuantity,
    required super.pricePerActivation,
    required super.totalPrice,
    required super.timestamp,
    required super.createdBy,
    required super.organizationEmail,
    super.boxId,
    super.boxTransactionId,
  });

  /// تحويل من Entity
  factory ActivationRechargeModel.fromEntity(ActivationRechargeEntity entity) {
    return ActivationRechargeModel(
      id: entity.id,
      subscriptionTypeId: entity.subscriptionTypeId,
      subscriptionTypeName: entity.subscriptionTypeName,
      addedQuantity: entity.addedQuantity,
      pricePerActivation: entity.pricePerActivation,
      totalPrice: entity.totalPrice,
      timestamp: entity.timestamp,
      createdBy: entity.createdBy,
      organizationEmail: entity.organizationEmail,
      boxId: entity.boxId,
      boxTransactionId: entity.boxTransactionId,
    );
  }

  /// تحويل من JSON
  factory ActivationRechargeModel.fromJson(Map<String, dynamic> json) {
    return ActivationRechargeModel(
      id: json['id'] as String,
      subscriptionTypeId: json['subscriptionTypeId'] as String,
      subscriptionTypeName: json['subscriptionTypeName'] as String? ?? '',
      addedQuantity: json['addedQuantity'] as int? ?? 0,
      pricePerActivation: (json['pricePerActivation'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: json['createdBy'] as String? ?? '',
      organizationEmail: json['organizationEmail'] as String? ?? '',
      boxId: json['boxId'] as String?,
      boxTransactionId: json['boxTransactionId'] as String?,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscriptionTypeId': subscriptionTypeId,
      'subscriptionTypeName': subscriptionTypeName,
      'addedQuantity': addedQuantity,
      'pricePerActivation': pricePerActivation,
      'totalPrice': totalPrice,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdBy': createdBy,
      'organizationEmail': organizationEmail,
      if (boxId != null) 'boxId': boxId,
      if (boxTransactionId != null) 'boxTransactionId': boxTransactionId,
    };
  }

  /// تحويل إلى Entity
  ActivationRechargeEntity toEntity() {
    return ActivationRechargeEntity(
      id: id,
      subscriptionTypeId: subscriptionTypeId,
      subscriptionTypeName: subscriptionTypeName,
      addedQuantity: addedQuantity,
      pricePerActivation: pricePerActivation,
      totalPrice: totalPrice,
      timestamp: timestamp,
      createdBy: createdBy,
      organizationEmail: organizationEmail,
      boxId: boxId,
      boxTransactionId: boxTransactionId,
    );
  }
}
