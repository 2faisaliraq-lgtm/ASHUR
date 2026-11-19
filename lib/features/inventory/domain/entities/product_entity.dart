import 'package:equatable/equatable.dart';

/// كيان المنتج في المخزون
class ProductEntity extends Equatable {
  const ProductEntity({
    required this.id,
    required this.name,
    required this.quantity,
    required this.minQuantity,
    required this.unit,
    required this.sellingPrice,
    required this.createdAt,
    required this.createdBy,
    required this.organizationEmail,
    this.description,
    this.barcode,
    this.categoryId,
    this.shelfId,
    this.maxQuantity,
    this.costPrice,
    this.images = const [],
    this.isActive = true,
    this.trackQuantity = true,
    this.metadata,
    this.updatedAt,
    this.updatedBy,
  });
  final String id;
  final String name;
  final String? description;
  final String? barcode;
  final String? categoryId;
  final String? shelfId;
  final double quantity;
  final double minQuantity;
  final double? maxQuantity;
  final String unit;
  final double? costPrice;
  final double sellingPrice;
  final List<String> images;
  final bool isActive;
  final bool trackQuantity;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;
  final String organizationEmail;

  /// حساب هامش الربح
  double get profitMargin {
    if (costPrice == null || costPrice == 0) return 0;
    if (sellingPrice < costPrice!) return 0; // لا يمكن أن يكون هامش ربح سالب
    return ((sellingPrice - costPrice!) / costPrice!) * 100;
  }

  /// حساب قيمة المخزون
  double get inventoryValue {
    // استخدام سعر التكلفة إذا كان متوفر، وإلا استخدام سعر البيع كبديل
    final unitCost = costPrice ?? sellingPrice;
    return quantity * unitCost;
  }

  /// التحقق من نفاد الكمية
  bool get isOutOfStock => trackQuantity && quantity <= 0;

  /// التحقق من انخفاض الكمية
  bool get isLowStock =>
      trackQuantity && minQuantity > 0 && quantity <= minQuantity && quantity > 0;

  /// التحقق من توفر الكمية
  bool get isInStock => !trackQuantity || quantity > 0;

  /// نسخ الكيان مع تعديل بعض الخصائص
  ProductEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? barcode,
    String? categoryId,
    String? shelfId,
    double? quantity,
    double? minQuantity,
    double? maxQuantity,
    String? unit,
    double? costPrice,
    double? sellingPrice,
    List<String>? images,
    bool? isActive,
    bool? trackQuantity,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? organizationEmail,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      shelfId: shelfId ?? this.shelfId,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      images: images ?? this.images,
      isActive: isActive ?? this.isActive,
      trackQuantity: trackQuantity ?? this.trackQuantity,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      organizationEmail: organizationEmail ?? this.organizationEmail,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    barcode,
    categoryId,
    shelfId,
    quantity,
    minQuantity,
    maxQuantity,
    unit,
    costPrice,
    sellingPrice,
    images,
    isActive,
    trackQuantity,
    metadata,
    createdAt,
    updatedAt,
    createdBy,
    updatedBy,
    organizationEmail,
  ];
}
