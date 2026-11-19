import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/category_entity.dart';

/// نموذج الفئة للتعامل مع Firestore
class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.createdAt, required super.createdBy, required super.organizationEmail, super.description,
    super.parentId,
    super.color,
    super.icon,
    super.sortOrder,
    super.isActive,
    super.metadata,
    super.updatedAt,
    super.updatedBy,
  });

  /// تحويل من CategoryEntity إلى CategoryModel
  factory CategoryModel.fromEntity(CategoryEntity entity) {
    return CategoryModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      parentId: entity.parentId,
      color: entity.color,
      icon: entity.icon,
      sortOrder: entity.sortOrder,
      isActive: entity.isActive,
      metadata: entity.metadata,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      organizationEmail: entity.organizationEmail,
    );
  }

  /// تحويل من JSON إلى CategoryModel
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      parentId: json['parentId'],
      color: json['color'],
      icon: json['icon'],
      sortOrder: json['sortOrder'] ?? 0,
      isActive: json['isActive'] ?? true,
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

  /// تحويل من Firestore DocumentSnapshot إلى CategoryModel
  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    return CategoryModel.fromJson({'id': doc.id, ...data as Map<String, dynamic>});
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'parentId': parentId,
      'color': color,
      'icon': icon,
      'sortOrder': sortOrder,
      'isActive': isActive,
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
  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? parentId,
    String? color,
    String? icon,
    int? sortOrder,
    bool? isActive,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? organizationEmail,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      organizationEmail: organizationEmail ?? this.organizationEmail,
    );
  }
}
