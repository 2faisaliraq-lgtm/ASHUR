import '../../domain/entities/customer_group_entity.dart';

/// نموذج مجموعة العملاء
class CustomerGroupModel extends CustomerGroupEntity {
  const CustomerGroupModel({
    required super.id,
    required super.name,
    required super.description,
    required super.color,
    required super.features,
    required super.isActive,
  });

  /// تحويل من Entity
  factory CustomerGroupModel.fromEntity(CustomerGroupEntity entity) {
    return CustomerGroupModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      color: entity.color,
      features: entity.features,
      isActive: entity.isActive,
    );
  }

  /// تحويل من JSON
  factory CustomerGroupModel.fromJson(Map<String, dynamic> json) {
    return CustomerGroupModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      color: (json['color'] as String?) ?? '#000000',
      features:
          (json['features'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'features': features,
      'isActive': isActive,
    };
  }

  /// تحويل إلى Entity
  CustomerGroupEntity toEntity() {
    return CustomerGroupEntity(
      id: id,
      name: name,
      description: description,
      color: color,
      features: features,
      isActive: isActive,
    );
  }
}
