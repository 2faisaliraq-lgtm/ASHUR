import 'package:equatable/equatable.dart';

/// أنواع حركات المخزون
enum MovementType {
  /// إدخال
  stockIn,

  /// إخراج
  stockOut,

  /// تعديل
  adjustment,

  /// نقل
  transfer,

  /// إرجاع
  return_,

  /// تلف
  damage,

  /// انتهاء صلاحية
  expiry,
}

/// كيان حركة المخزون
class InventoryMovementEntity extends Equatable {

  const InventoryMovementEntity({
    required this.id,
    required this.productId,
    this.productName,
    required this.type,
    required this.quantity,
    required this.previousQuantity,
    required this.newQuantity,
    required this.createdAt, required this.createdBy, required this.organizationEmail, this.reason,
    this.reference,
    this.fromShelfId,
    this.toShelfId,
    this.unitCost,
    this.totalCost,
    this.metadata,
  });
  final String id;
  final String productId;

  /// اسم المنتج وقت الحركة — يُحفظ في السجل ليكون
  /// ذاتياً (يُعرض حتى بعد حذف المنتج لاحقاً)
  final String? productName;
  final MovementType type;
  final double quantity;
  final double previousQuantity;
  final double newQuantity;
  final String? reason;
  final String? reference;
  final String? fromShelfId;
  final String? toShelfId;
  final double? unitCost;
  final double? totalCost;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final String createdBy;
  final String organizationEmail;

  /// التحقق من كون الحركة زيادة في المخزون
  bool get isIncrease => quantity > 0;

  /// التحقق من كون الحركة نقصان في المخزون
  bool get isDecrease => quantity < 0;

  /// التحقق من كون الحركة نقل بين الأرفف
  bool get isTransfer => type == MovementType.transfer;

  /// الحصول على وصف نوع الحركة
  String get typeDescription {
    switch (type) {
      case MovementType.stockIn:
        return 'إدخال';
      case MovementType.stockOut:
        return 'إخراج';
      case MovementType.adjustment:
        return 'تعديل';
      case MovementType.transfer:
        return 'نقل';
      case MovementType.return_:
        return 'إرجاع';
      case MovementType.damage:
        return 'تلف';
      case MovementType.expiry:
        return 'انتهاء صلاحية';
    }
  }

  /// نسخ الكيان مع تعديل بعض الخصائص
  InventoryMovementEntity copyWith({
    String? id,
    String? productId,
    String? productName,
    MovementType? type,
    double? quantity,
    double? previousQuantity,
    double? newQuantity,
    String? reason,
    String? reference,
    String? fromShelfId,
    String? toShelfId,
    double? unitCost,
    double? totalCost,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    String? createdBy,
    String? organizationEmail,
  }) {
    return InventoryMovementEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      previousQuantity: previousQuantity ?? this.previousQuantity,
      newQuantity: newQuantity ?? this.newQuantity,
      reason: reason ?? this.reason,
      reference: reference ?? this.reference,
      fromShelfId: fromShelfId ?? this.fromShelfId,
      toShelfId: toShelfId ?? this.toShelfId,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      organizationEmail: organizationEmail ?? this.organizationEmail,
    );
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    productName,
    type,
    quantity,
    previousQuantity,
    newQuantity,
    reason,
    reference,
    fromShelfId,
    toShelfId,
    unitCost,
    totalCost,
    metadata,
    createdAt,
    createdBy,
    organizationEmail,
  ];
}
