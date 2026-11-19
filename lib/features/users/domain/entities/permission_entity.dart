import 'package:equatable/equatable.dart';

/// كيان الصلاحية - يمثل صلاحية محددة في النظام
class PermissionEntity extends Equatable {
  const PermissionEntity({
    required this.id,
    required this.name,
    required this.displayName,
    required this.category,
    this.description,
    this.isActive = true,
  });
  final String id;
  final String name;
  final String displayName;
  final String? description;
  final String category;
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    name,
    displayName,
    description,
    category,
    isActive,
  ];

  PermissionEntity copyWith({
    String? id,
    String? name,
    String? displayName,
    String? description,
    String? category,
    bool? isActive,
  }) {
    return PermissionEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
    );
  }
}
