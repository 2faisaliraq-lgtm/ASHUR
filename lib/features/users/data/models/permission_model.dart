import '../../domain/entities/permission_entity.dart';

/// نموذج الصلاحية - يحول البيانات من وإلى JSON
class PermissionModel extends PermissionEntity {
  const PermissionModel({
    required super.id,
    required super.name,
    required super.displayName,
    required super.category, super.description,
    super.isActive,
  });

  /// إنشاء نموذج من كيان
  factory PermissionModel.fromEntity(PermissionEntity entity) {
    return PermissionModel(
      id: entity.id,
      name: entity.name,
      displayName: entity.displayName,
      description: entity.description,
      category: entity.category,
      isActive: entity.isActive,
    );
  }

  /// إنشاء نموذج من JSON
  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// تحويل النموذج إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'description': description,
      'category': category,
      'isActive': isActive,
    };
  }

  /// تحويل النموذج إلى كيان
  PermissionEntity toEntity() {
    return PermissionEntity(
      id: id,
      name: name,
      displayName: displayName,
      description: description,
      category: category,
      isActive: isActive,
    );
  }
}
