import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/subscription_entity.dart';
import '../../../../core/utils/date_parser.dart';

/// نموذج الاشتراك
class SubscriptionModel extends SubscriptionEntity {
  const SubscriptionModel({
    required super.id,
    required super.name,
    required super.type,
    required super.price,
    required super.duration,
    required super.status,
    required super.startDate,
    required super.endDate,
    required super.organizationEmail,
    required super.createdAt,
    required super.updatedAt,
    required super.createdBy,
    super.customerId,
    super.customerName,
    super.customerPhone,
    super.customDays,
    super.description,
    super.features,
    super.updatedBy,
    super.isAutoRenew,
    super.isPaid,
    super.renewalCount,
    super.lastRenewalDate,
    super.nextBillingDate,
    super.totalPaid,
    super.remainingAmount,
    super.discountAmount,
    super.taxAmount,
    super.taxes,
    super.subscriptionTypeId,
    super.priceAtCreation,
    super.currentPrice,
  });

  /// من Entity
  factory SubscriptionModel.fromEntity(SubscriptionEntity entity) {
    return SubscriptionModel(
      id: entity.id,
      name: entity.name,
      type: entity.type,
      price: entity.price,
      duration: entity.duration,
      customDays: entity.customDays,
      status: entity.status,
      startDate: entity.startDate,
      endDate: entity.endDate,
      organizationEmail: entity.organizationEmail,
      customerId: entity.customerId,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      description: entity.description,
      features: entity.features,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      isAutoRenew: entity.isAutoRenew,
      isPaid: entity.isPaid,
      renewalCount: entity.renewalCount,
      lastRenewalDate: entity.lastRenewalDate,
      nextBillingDate: entity.nextBillingDate,
      totalPaid: entity.totalPaid,
      remainingAmount: entity.remainingAmount,
      discountAmount: entity.discountAmount,
      taxAmount: entity.taxAmount,
      taxes: entity.taxes,
      subscriptionTypeId: entity.subscriptionTypeId,
      priceAtCreation: entity.priceAtCreation,
      currentPrice: entity.currentPrice,
    );
  }

  /// من JSON
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    try {
      // معالجة features - قد يكون List أو Map
      Map<String, dynamic>? featuresMap;
      if (json['features'] != null) {
        if (json['features'] is Map) {
          featuresMap = json['features'] as Map<String, dynamic>;
        } else if (json['features'] is List) {
          // تحويل List إلى Map
          final featuresList = json['features'] as List;
          featuresMap = {'items': featuresList};
        }
      }

      final startDate = DateParser.parse(json['startDate'] ?? json['created_at']);
      final endDate = DateParser.parse(json['endDate'] ?? SubscriptionEntity.calculateEndDate(
        startDate,
        json['duration'] as String? ?? 'monthly',
        json['customDays'] as int?,
      ));

      return SubscriptionModel(
        id: json['id'] as String? ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        duration: json['duration'] as String? ?? '',
        customDays: json['customDays'] as int?,
        status: json['status'] as String? ?? 'active',
        startDate: startDate,
        endDate: endDate,
        organizationEmail: json['organizationEmail'] as String? ?? '',
        customerId: json['customerId']?.toString(),
        customerName: json['customerName']?.toString(),
        customerPhone: json['customerPhone']?.toString(),
        description: json['description']?.toString(),
        features: featuresMap,
        createdAt: DateParser.parse(json['createdAt'] ?? json['created_at']),
        updatedAt: DateParser.parse(json['updatedAt'] ?? json['updated_at']),
        createdBy:
            json['createdBy']?.toString() ??
            json['created_by']?.toString() ??
            'المدير',
        updatedBy:
            json['updatedBy']?.toString() ?? json['updated_by']?.toString(),
        isAutoRenew: json['isAutoRenew'] as bool? ?? false,
        isPaid: json['isPaid'] as bool? ?? false,
        renewalCount: json['renewalCount'] as int? ?? 0,
        lastRenewalDate: DateParser.parse(json['lastRenewalDate']),
        nextBillingDate: DateParser.parse(json['nextBillingDate']),
        totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
        remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0.0,
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
        taxes: json['taxes'] != null
            ? (json['taxes'] as List)
                  .map((e) => e as Map<String, dynamic>)
                  .toList()
            : null,
        subscriptionTypeId: json['subscriptionTypeId']?.toString(),
        priceAtCreation: (json['priceAtCreation'] as num?)?.toDouble(),
        currentPrice: (json['currentPrice'] as num?)?.toDouble(),
      );
    } on Exception catch (_) {
      // خطأ في تحويل JSON
      rethrow;
    }
  }

  /// إلى JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'price': price,
      'duration': duration,
      if (customDays != null) 'customDays': customDays,
      'status': status,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'organizationEmail': organizationEmail,
      if (customerId != null) 'customerId': customerId,
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      'description': description,
      'features': features,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'isAutoRenew': isAutoRenew,
      'isPaid': isPaid,
      'renewalCount': renewalCount,
      if (lastRenewalDate != null)
        'lastRenewalDate': Timestamp.fromDate(lastRenewalDate!),
      if (nextBillingDate != null)
        'nextBillingDate': Timestamp.fromDate(nextBillingDate!),
      'totalPaid': totalPaid,
      'remainingAmount': remainingAmount,
      if (discountAmount > 0) 'discountAmount': discountAmount,
      if (taxAmount > 0) 'taxAmount': taxAmount,
      if (taxes != null && taxes!.isNotEmpty) 'taxes': taxes,
      if (subscriptionTypeId != null) 'subscriptionTypeId': subscriptionTypeId,
      if (priceAtCreation != null) 'priceAtCreation': priceAtCreation,
      if (currentPrice != null) 'currentPrice': currentPrice,
    };
  }
}
