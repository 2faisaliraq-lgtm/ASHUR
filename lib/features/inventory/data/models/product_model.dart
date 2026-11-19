import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product_entity.dart';

/// نموذج المنتج للتعامل مع Firestore
class ProductModel extends ProductEntity {
  const ProductModel({
    required super.id,
    required super.name,
    required super.quantity,
    required super.minQuantity,
    required super.unit,
    required super.sellingPrice,
    required super.createdAt,
    required super.createdBy,
    required super.organizationEmail,
    super.description,
    super.barcode,
    super.categoryId,
    super.shelfId,
    super.maxQuantity,
    super.costPrice,
    super.images,
    super.isActive,
    super.trackQuantity,
    super.metadata,
    super.updatedAt,
    super.updatedBy,
  });

  /// تحويل من ProductEntity إلى ProductModel
  factory ProductModel.fromEntity(ProductEntity entity) {
    return ProductModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      barcode: entity.barcode,
      categoryId: entity.categoryId,
      shelfId: entity.shelfId,
      quantity: entity.quantity,
      minQuantity: entity.minQuantity,
      maxQuantity: entity.maxQuantity,
      unit: entity.unit,
      costPrice: entity.costPrice,
      sellingPrice: entity.sellingPrice,
      images: entity.images,
      isActive: entity.isActive,
      trackQuantity: entity.trackQuantity,
      metadata: entity.metadata,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      organizationEmail: entity.organizationEmail,
    );
  }

  /// تحويل من JSON إلى ProductModel
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      barcode: json['barcode'],
      categoryId: json['categoryId'],
      shelfId: json['shelfId'],
      quantity: (json['quantity'] ?? 0).toDouble(),
      minQuantity: (json['minQuantity'] ?? 0).toDouble(),
      maxQuantity: json['maxQuantity']?.toDouble(),
      unit: json['unit'] ?? '',
      costPrice: json['costPrice']?.toDouble(),
      sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
      images: List<String>.from(json['images'] ?? []),
      isActive: json['isActive'] ?? true,
      trackQuantity: json['trackQuantity'] ?? true,
      metadata: json['metadata'],
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(), // fallback if neither type
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : json['updatedAt'] is String
                ? DateTime.parse(json['updatedAt'] as String)
                : DateTime.now()) // fallback if neither type
          : null,
      createdBy: json['createdBy'] ?? '',
      updatedBy: json['updatedBy'],
      organizationEmail: json['organizationEmail'] ?? '',
    );
  }

  /// تحويل من Firestore DocumentSnapshot إلى ProductModel
  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    return ProductModel.fromJson({'id': doc.id, ...data as Map<String, dynamic>});
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'barcode': barcode,
      'categoryId': categoryId,
      'shelfId': shelfId,
      'quantity': quantity,
      'minQuantity': minQuantity,
      'maxQuantity': maxQuantity,
      'unit': unit,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'images': images,
      'isActive': isActive,
      'trackQuantity': trackQuantity,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'organizationEmail': organizationEmail,
    };
  }

  /// نسخ مع تعديل
  @override
  ProductModel copyWith({
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
    return ProductModel(
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
}
