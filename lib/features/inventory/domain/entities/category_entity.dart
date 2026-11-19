import 'package:equatable/equatable.dart';

/// كيان فئة المنتجات
class CategoryEntity extends Equatable {

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.createdAt, required this.createdBy, required this.organizationEmail, this.description,
    this.parentId,
    this.color,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
    this.metadata,
    this.updatedAt,
    this.updatedBy,
  });
  final String id;
  final String name;
  final String? description;
  final String? parentId;
  final String? color;
  final String? icon;
  final int sortOrder;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;
  final String organizationEmail;

  /// التحقق من كون الفئة فئة رئيسية
  bool get isMainCategory => parentId == null;

  /// التحقق من كون الفئة فئة فرعية
  bool get isSubCategory => parentId != null;

  /// نسخ الكيان مع تعديل بعض الخصائص
  CategoryEntity copyWith({
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
    return CategoryEntity(
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

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    parentId,
    color,
    icon,
    sortOrder,
    isActive,
    metadata,
    createdAt,
    updatedAt,
    createdBy,
    updatedBy,
    organizationEmail,
  ];
}
