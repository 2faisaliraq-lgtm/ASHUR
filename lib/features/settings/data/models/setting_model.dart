import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/setting_entity.dart';
import '../../../../core/utils/date_parser.dart';

class SettingModel extends SettingEntity {
  const SettingModel({
    required super.id,
    required super.organizationEmail,
    required super.key,
    required super.value,
    required super.type,
    required super.category,
    required super.createdAt, required super.updatedAt, super.description,
  });

  factory SettingModel.fromEntity(SettingEntity entity) {
    return SettingModel(
      id: entity.id,
      organizationEmail: entity.organizationEmail,
      key: entity.key,
      value: entity.value,
      type: entity.type,
      category: entity.category,
      description: entity.description,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  factory SettingModel.fromJson(Map<String, dynamic> json) {
    return SettingModel(
      id: json['id']?.toString() ?? '',
      organizationEmail: json['organizationEmail']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      type: json['type']?.toString() ?? 'string',
      category: json['category']?.toString() ?? 'general',
      description: json['description']?.toString(),
      createdAt: DateParser.parse(json['createdAt']),
      updatedAt: DateParser.parse(json['updatedAt'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationEmail': organizationEmail,
      'key': key,
      'value': value,
      'type': type,
      'category': category,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
