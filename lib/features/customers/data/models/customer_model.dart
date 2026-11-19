import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/customer_entity.dart';
import '../../../../core/utils/date_parser.dart';

class CustomerModel extends CustomerEntity {
  const CustomerModel({
    required super.id,
    required super.organizationEmail,
    required super.name,
    required super.email,
    required super.phone,
    required super.totalPurchases,
    required super.totalDebt,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.address,
    super.customerGroupId,
    super.customerGroupName,
    super.creditLimit,
    super.openingBalance,
    super.notes,
    super.createdBy,
    super.updatedBy,
    super.invoiceIds = const [],
    super.logIds = const [],
  });

  factory CustomerModel.fromEntity(CustomerEntity entity) {
    return CustomerModel(
      id: entity.id,
      organizationEmail: entity.organizationEmail,
      name: entity.name,
      email: entity.email,
      phone: entity.phone,
      address: entity.address,
      customerGroupId: entity.customerGroupId,
      customerGroupName: entity.customerGroupName,
      totalPurchases: entity.totalPurchases,
      totalDebt: entity.totalDebt,
      creditLimit: entity.creditLimit,
      openingBalance: entity.openingBalance,
      status: entity.status,
      notes: entity.notes,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      invoiceIds: entity.invoiceIds,
      logIds: entity.logIds,
    );
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id']?.toString() ?? '',
      organizationEmail: json['organizationEmail']?.toString() ?? '',
      name: json['name']?.toString() ?? 'بدون اسم',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString(),
      customerGroupId: json['customerGroupId']?.toString(),
      customerGroupName: json['customerGroupName']?.toString(),
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (json['creditLimit'] as num?)?.toDouble(),
      openingBalance: (json['openingBalance'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'active',
      notes: json['notes']?.toString(),
      createdBy: json['createdBy']?.toString(),
      updatedBy: json['updatedBy']?.toString(),
      createdAt: DateParser.parse(json['createdAt']),
      updatedAt: DateParser.parse(json['updatedAt'] ?? json['createdAt']),
      invoiceIds: (json['invoiceIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      logIds: (json['logIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationEmail': organizationEmail,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'customerGroupId': customerGroupId,
      'customerGroupName': customerGroupName,
      'totalPurchases': totalPurchases,
      'totalDebt': totalDebt,
      'creditLimit': creditLimit,
      'openingBalance': openingBalance,
      'status': status,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
      'invoiceIds': invoiceIds,
      'logIds': logIds,
    };
  }

  CustomerEntity toEntity() {
    return CustomerEntity(
      id: id,
      organizationEmail: organizationEmail,
      name: name,
      email: email,
      phone: phone,
      address: address,
      customerGroupId: customerGroupId,
      customerGroupName: customerGroupName,
      totalPurchases: totalPurchases,
      totalDebt: totalDebt,
      creditLimit: creditLimit,
      openingBalance: openingBalance,
      status: status,
      notes: notes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
      invoiceIds: invoiceIds,
      logIds: logIds,
    );
  }
}
