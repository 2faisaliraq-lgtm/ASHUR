import 'package:equatable/equatable.dart';

/// كيان مجموعة العملاء
class CustomerGroupEntity extends Equatable {
  const CustomerGroupEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.features,
    required this.isActive,
    this.createdBy,
    this.updatedBy,
  });
  final String id;
  final String name;
  final String description;
  final String color; // لون المجموعة للتمييز البصري
  final List<String> features; // مميزات المجموعة
  final bool isActive;
  final String? createdBy;
  final String? updatedBy;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    color,
    features,
    isActive,
    createdBy,
    updatedBy,
  ];

  CustomerGroupEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    List<String>? features,
    bool? isActive,
    String? createdBy,
    String? updatedBy,
  }) {
    return CustomerGroupEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
