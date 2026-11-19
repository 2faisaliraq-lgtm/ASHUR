import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/role_entity.dart';

/// نموذج الدور - يحول البيانات من وإلى Firestore
class RoleModel extends RoleEntity {
  const RoleModel({
    required super.id,
    required super.name,
    required super.displayName,
    required super.permissions, required super.createdAt, super.description,
    super.isActive,
    super.updatedAt,
    super.createdBy,
  });

  /// إنشاء نموذج من كيان
  factory RoleModel.fromEntity(RoleEntity entity) {
    return RoleModel(
      id: entity.id,
      name: entity.name,
      displayName: entity.displayName,
      description: entity.description,
      permissions: entity.permissions,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
    );
  }

  /// إنشاء نموذج من JSON
  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String?,
      permissions: List<String>.from(json['permissions'] ?? []),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : DateTime.parse(json['updatedAt'] as String))
          : null,
      createdBy: json['createdBy'] as String?,
    );
  }

  /// إنشاء نموذج من Firestore DocumentSnapshot
  factory RoleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    return RoleModel.fromJson({'id': doc.id, ...data as Map<String, dynamic>});
  }

  /// تحويل النموذج إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'description': description,
      'permissions': permissions,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
    };
  }

  /// تحويل النموذج إلى كيان
  RoleEntity toEntity() {
    return RoleEntity(
      id: id,
      name: name,
      displayName: displayName,
      description: description,
      permissions: permissions,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
    );
  }
}
