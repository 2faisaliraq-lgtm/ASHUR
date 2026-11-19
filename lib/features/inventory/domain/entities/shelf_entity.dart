import 'package:equatable/equatable.dart';

/// كيان الرف في المخزن
class ShelfEntity extends Equatable {

  const ShelfEntity({
    required this.id,
    required this.name,
    required this.createdAt, required this.createdBy, required this.organizationEmail, this.description,
    this.location,
    this.zone,
    this.capacity = 0,
    this.currentItems = 0,
    this.isActive = true,
    this.metadata,
    this.updatedAt,
    this.updatedBy,
  });
  final String id;
  final String name;
  final String? description;
  final String? location;
  final String? zone;
  final int capacity;
  final int currentItems;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;
  final String organizationEmail;

  /// حساب نسبة الامتلاء
  double get occupancyRate {
    if (capacity <= 0) return 0;
    return (currentItems / capacity) * 100;
  }

  /// التحقق من امتلاء الرف
  bool get isFull => capacity > 0 && currentItems >= capacity;

  /// التحقق من فراغ الرف
  bool get isEmpty => currentItems <= 0;

  /// حساب المساحة المتاحة
  int get availableSpace => capacity > 0 ? capacity - currentItems : 0;

  /// نسخ الكيان مع تعديل بعض الخصائص
  ShelfEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? location,
    String? zone,
    int? capacity,
    int? currentItems,
    bool? isActive,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? organizationEmail,
  }) {
    return ShelfEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      zone: zone ?? this.zone,
      capacity: capacity ?? this.capacity,
      currentItems: currentItems ?? this.currentItems,
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
    location,
    zone,
    capacity,
    currentItems,
    isActive,
    metadata,
    createdAt,
    updatedAt,
    createdBy,
    updatedBy,
    organizationEmail,
  ];
}
