import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product_log_entity.dart';

/// نموذج سجل حركة المنتج
class ProductLogModel extends ProductLogEntity {
  const ProductLogModel({
    required super.id,
    required super.productId,
    required super.productName,
    required super.invoiceId,
    required super.invoiceType,
    required super.quantity,
    required super.unitPrice,
    required super.totalPrice,
    required super.customerName,
    required super.customerPhone,
    required super.date,
    required super.organizationEmail,
    required super.createdAt,
    required super.createdBy,
    super.notes,
  });

  factory ProductLogModel.fromEntity(ProductLogEntity entity) {
    return ProductLogModel(
      id: entity.id,
      productId: entity.productId,
      productName: entity.productName,
      invoiceId: entity.invoiceId,
      invoiceType: entity.invoiceType,
      quantity: entity.quantity,
      unitPrice: entity.unitPrice,
      totalPrice: entity.totalPrice,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      date: entity.date,
      organizationEmail: entity.organizationEmail,
      createdAt: entity.createdAt,
      createdBy: entity.createdBy,
      notes: entity.notes,
    );
  }

  factory ProductLogModel.fromJson(Map<String, dynamic> json) {
    return ProductLogModel(
      id: json['id'] ?? '',
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      invoiceId: json['invoiceId'] ?? '',
      invoiceType: json['invoiceType'] ?? '',
      quantity: _parseDouble(json['quantity']),
      unitPrice: _parseDouble(json['unitPrice']),
      totalPrice: _parseDouble(json['totalPrice']),
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      date: _parseDate(json['date']),
      organizationEmail: json['organizationEmail'] ?? '',
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy'] ?? '',
      notes: json['notes'],
    );
  }

  factory ProductLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    return ProductLogModel.fromFirestoreData(data as Map<String, dynamic>, doc.id);
  }

  factory ProductLogModel.fromFirestoreData(
      Map<String, dynamic> data, String id) {
    return ProductLogModel(
      id: id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      invoiceId: data['invoiceId'] ?? '',
      invoiceType: data['invoiceType'] ?? '',
      quantity: _parseDouble(data['quantity']),
      unitPrice: _parseDouble(data['unitPrice']),
      totalPrice: _parseDouble(data['totalPrice']),
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      date: _parseDate(data['date']),
      organizationEmail: data['organizationEmail'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      createdBy: data['createdBy'] ?? '',
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      'invoiceId': invoiceId,
      'invoiceType': invoiceType,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'date': Timestamp.fromDate(date),
      'organizationEmail': organizationEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'notes': notes,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0;
  }
}
