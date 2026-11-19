import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/inventory_movement_entity.dart';

/// نموذج حركة المخزون
///
/// ⚠️ ملاحظة موجزة للمبرمجين المستقبليين: الحركات
/// تُقرأ/تُكتب في المجموعة العليا
/// {org}/inventory/inventory_movements فقط، والكتابة
/// الذرية مع الكمية تكون في
/// ProductRepositoryImpl.updateProductQuantity —
/// التفاصيل الكاملة في الملاحظة المدمجة أعلى
/// InventoryMovementRepositoryImpl.
class InventoryMovementModel extends InventoryMovementEntity {
  const InventoryMovementModel({
    required super.id,
    required super.productId,
    super.productName,
    required super.type,
    required super.quantity,
    required super.previousQuantity,
    required super.newQuantity,
    required super.createdAt,
    required super.createdBy,
    required super.organizationEmail,
    super.reason,
    super.reference,
    super.fromShelfId,
    super.toShelfId,
    super.unitCost,
    super.totalCost,
    super.metadata,
  });

  /// تحويل نوع الحركة إلى نص (كما يُخزن في Firestore)
  static String typeToString(MovementType type) =>
      type.toString().split('.').last;

  /// تحويل النص المخزن إلى نوع حركة
  static MovementType typeFromString(String? value) {
    switch (value) {
      case 'stockIn':
        return MovementType.stockIn;
      case 'stockOut':
        return MovementType.stockOut;
      case 'adjustment':
        return MovementType.adjustment;
      case 'transfer':
        return MovementType.transfer;
      case 'return_':
        return MovementType.return_;
      case 'damage':
        return MovementType.damage;
      case 'expiry':
        return MovementType.expiry;
      default:
        return MovementType.adjustment;
    }
  }

  factory InventoryMovementModel.fromJson(Map<String, dynamic> json) {
    return InventoryMovementModel(
      id: json['id'] ?? '',
      productId: json['productId'] ?? '',
      productName: json['productName'],
      type: typeFromString(json['type'] as String?),
      quantity: _parseDouble(json['quantity']),
      previousQuantity: _parseDouble(json['previousQuantity']),
      newQuantity: _parseDouble(json['newQuantity']),
      reason: json['reason'],
      reference: json['reference'],
      fromShelfId: json['fromShelfId'],
      toShelfId: json['toShelfId'],
      unitCost: _parseDoubleOrNull(json['unitCost']),
      totalCost: _parseDoubleOrNull(json['totalCost']),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy'] ?? '',
      organizationEmail: json['organizationEmail'] ?? '',
    );
  }

  factory InventoryMovementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    return InventoryMovementModel.fromJson({
      'id': doc.id,
      ...data as Map<String, dynamic>,
    });
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      'type': typeToString(type),
      'quantity': quantity,
      'previousQuantity': previousQuantity,
      'newQuantity': newQuantity,
      'reason': reason,
      'reference': reference,
      'fromShelfId': fromShelfId,
      'toShelfId': toShelfId,
      'unitCost': unitCost,
      'totalCost': totalCost,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'organizationEmail': organizationEmail,
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

  static double? _parseDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
