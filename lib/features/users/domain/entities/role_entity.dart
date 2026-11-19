import 'package:equatable/equatable.dart';

/// كيان الدور - يمثل دور المستخدم في النظام
class RoleEntity extends Equatable {

  const RoleEntity({
    required this.id,
    required this.name,
    required this.displayName,
    required this.permissions, required this.createdAt, this.description,
    this.isActive = true,
    this.updatedAt,
    this.createdBy,
  });
  final String id;
  final String name;
  final String displayName;
  final String? description;
  final List<String> permissions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  @override
  List<Object?> get props => [
    id,
    name,
    displayName,
    description,
    permissions,
    isActive,
    createdAt,
    updatedAt,
    createdBy,
  ];

  RoleEntity copyWith({
    String? id,
    String? name,
    String? displayName,
    String? description,
    List<String>? permissions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return RoleEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
