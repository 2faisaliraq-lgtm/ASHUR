import 'package:equatable/equatable.dart';

/// كيان الإعداد
class SettingEntity extends Equatable {

  const SettingEntity({
    required this.id,
    required this.organizationEmail,
    required this.key,
    required this.value,
    required this.type,
    required this.category,
    required this.createdAt, required this.updatedAt, this.description,
  });
  final String id;
  final String organizationEmail;
  final String key;
  final String value;
  final String type; // string, number, boolean, json
  final String category; // general, appearance, notifications, security, backup
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  SettingEntity copyWith({
    String? id,
    String? organizationEmail,
    String? key,
    String? value,
    String? type,
    String? category,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SettingEntity(
      id: id ?? this.id,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      key: key ?? this.key,
      value: value ?? this.value,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    organizationEmail,
    key,
    value,
    type,
    category,
    description,
    createdAt,
    updatedAt,
  ];
}
