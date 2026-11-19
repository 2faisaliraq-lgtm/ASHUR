import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/shelf_entity.dart';

/// نموذج الرف للتعامل مع Firestore
class ShelfModel extends ShelfEntity {
  const ShelfModel({
    required super.id,
    required super.name,
    required super.createdAt,
    required super.createdBy,
    required super.organizationEmail,
    super.description,
    super.location,
    super.zone,
    super.capacity,
    super.currentItems,
    super.isActive,
    super.metadata,
    super.updatedAt,
    super.updatedBy,
  });

  /// تحويل من ShelfEntity إلى ShelfModel
  factory ShelfModel.fromEntity(ShelfEntity entity) {
    return ShelfModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      location: entity.location,
      zone: entity.zone,
      capacity: entity.capacity,
      currentItems: entity.currentItems,
      isActive: entity.isActive,
      metadata: entity.metadata,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      organizationEmail: entity.organizationEmail,
    );
  }

  /// تحويل من JSON إلى ShelfModel
  factory ShelfModel.fromJson(Map<String, dynamic> json) {
    return ShelfModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      location: json['location'],
      zone: json['zone'],
      capacity: json['capacity'] ?? 0,
      currentItems: json['currentItems'] ?? 0,
      isActive: json['isActive'] ?? true,
      metadata: json['metadata'],
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : json['updatedAt'] is String
                ? DateTime.parse(json['updatedAt'] as String)
                : DateTime.now())
          : null,
      createdBy: json['createdBy'] ?? '',
      updatedBy: json['updatedBy'],
      organizationEmail: json['organizationEmail'] ?? '',
    );
  }

  /// تحويل من Firestore DocumentSnapshot إلى ShelfModel
  factory ShelfModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    return ShelfModel.fromJson({'id': doc.id, ...data as Map<String, dynamic>});
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'location': location,
      'zone': zone,
      'capacity': capacity,
      'currentItems': currentItems,
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
  ShelfModel copyWith({
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
    return ShelfModel(
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
}
