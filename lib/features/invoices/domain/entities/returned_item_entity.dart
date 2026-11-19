import 'package:equatable/equatable.dart';

/// كيان يمثل مادة مرتجعة في فاتورة مرجع بيع
class ReturnedItemEntity extends Equatable {
  final String itemId;
  final String itemName;
  final String?
  productId; // معرف المنتج في Firebase - يُستخدم لجلب المنتج داخل transaction
  final int purchasedQuantity;
  final int returnedQuantity;
  final double unitPrice;
  final DateTime saleDate;
  final String originalInvoiceId;
  final String? originalInvoiceNumber;

  const ReturnedItemEntity({
    required this.itemId,
    required this.itemName,
    this.productId,
    required this.purchasedQuantity,
    required this.returnedQuantity,
    required this.unitPrice,
    required this.saleDate,
    required this.originalInvoiceId,
    this.originalInvoiceNumber,
  });

  factory ReturnedItemEntity.fromMap(Map<String, dynamic> map) {
    return ReturnedItemEntity(
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      productId: map['productId'] as String?,
      purchasedQuantity: map['purchasedQuantity'] ?? 0,
      returnedQuantity: map['returnedQuantity'] ?? 0,
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      saleDate: DateTime.parse(map['saleDate']),
      originalInvoiceId: map['originalInvoiceId'] ?? '',
      originalInvoiceNumber: map['originalInvoiceNumber'],
    );
  }

  /// نسخ مع تعديل
  ReturnedItemEntity copyWith({
    String? itemId,
    String? itemName,
    String? productId,
    int? purchasedQuantity,
    int? returnedQuantity,
    double? unitPrice,
    DateTime? saleDate,
    String? originalInvoiceId,
    String? originalInvoiceNumber,
  }) {
    return ReturnedItemEntity(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      productId: productId ?? this.productId,
      purchasedQuantity: purchasedQuantity ?? this.purchasedQuantity,
      returnedQuantity: returnedQuantity ?? this.returnedQuantity,
      unitPrice: unitPrice ?? this.unitPrice,
      saleDate: saleDate ?? this.saleDate,
      originalInvoiceId: originalInvoiceId ?? this.originalInvoiceId,
      originalInvoiceNumber:
          originalInvoiceNumber ?? this.originalInvoiceNumber,
    );
  }

  /// حساب الإجمالي للمادة المرتجعة
  double get totalPrice => unitPrice * returnedQuantity;

  /// تحويل الكيان إلى Map للحفظ في Firebase
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'productId': productId,
      'purchasedQuantity': purchasedQuantity,
      'returnedQuantity': returnedQuantity,
      'unitPrice': unitPrice,
      'saleDate': saleDate.toIso8601String(),
      'originalInvoiceId': originalInvoiceId,
      'originalInvoiceNumber': originalInvoiceNumber,
    };
  }

  @override
  List<Object?> get props => [
    itemId,
    itemName,
    productId,
    purchasedQuantity,
    returnedQuantity,
    unitPrice,
    saleDate,
    originalInvoiceId,
    originalInvoiceNumber,
  ];
}
