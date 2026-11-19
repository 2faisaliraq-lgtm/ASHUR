import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/subscription_type_entity.dart';

/// نموذج نوع الاشتراك
class SubscriptionTypeModel extends SubscriptionTypeEntity {
  const SubscriptionTypeModel({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    required super.duration,
    required super.features,
    required super.isActive,
    super.customDays,
    super.activationQuantity,
    super.linkedSubscriptionsCount,
    super.createdBy,
    super.updatedBy,
    super.createdAt,
    super.updatedAt,
  });

  /// تحويل من Entity
  factory SubscriptionTypeModel.fromEntity(SubscriptionTypeEntity entity) {
    return SubscriptionTypeModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      price: entity.price,
      duration: entity.duration,
      customDays: entity.customDays,
      features: entity.features,
      isActive: entity.isActive,
      activationQuantity: entity.activationQuantity,
      linkedSubscriptionsCount: entity.linkedSubscriptionsCount,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// تحويل من JSON
  factory SubscriptionTypeModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionTypeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      duration: json['duration'] as String,
      customDays: json['customDays'] as int?,
      features:
          (json['features'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isActive: json['isActive'] as bool? ?? true,
      activationQuantity: json['activationQuantity'] as int? ?? 0,
      linkedSubscriptionsCount: json['linkedSubscriptionsCount'] as int? ?? 0,
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration': duration,
      if (customDays != null) 'customDays': customDays,
      'features': features,
      'isActive': isActive,
      'activationQuantity': activationQuantity,
      'linkedSubscriptionsCount': linkedSubscriptionsCount,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// تحويل إلى Entity
  SubscriptionTypeEntity toEntity() {
    return SubscriptionTypeEntity(
      id: id,
      name: name,
      description: description,
      price: price,
      duration: duration,
      customDays: customDays,
      features: features,
      isActive: isActive,
      activationQuantity: activationQuantity,
      linkedSubscriptionsCount: linkedSubscriptionsCount,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
