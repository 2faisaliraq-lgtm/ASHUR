import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/equipment_entity.dart';

/// نموذج المعدات
class EquipmentModel extends EquipmentEntity {
  const EquipmentModel({
    required super.id,
    required super.organizationEmail,
    required super.name,
    required super.status, required super.createdAt, super.description,
    super.model,
    super.serialNumber,
    super.manufacturer,
    super.purchaseDate,
    super.warrantyExpiry,
    super.location,
    super.updatedAt,
  });

  /// من JSON
  factory EquipmentModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    DateTime? parseDate(dynamic value, [DateTime? defaultValue]) {
      if (value == null) return defaultValue;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return defaultValue;
    }

    return EquipmentModel(
      id: json['id'] as String? ?? '',
      organizationEmail: json['organizationEmail'] as String? ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      model: json['model']?.toString(),
      serialNumber:
          json['serialNumber']?.toString() ?? json['serial_number']?.toString(),
      manufacturer: json['manufacturer']?.toString(),
      purchaseDate: parseDate(
        json['purchaseDate'],
        parseDate(json['purchase_date']),
      ),
      warrantyExpiry: parseDate(
        json['warrantyExpiry'],
        parseDate(json['warranty_expiry']),
      ),
      location: json['location']?.toString(),
      status: json['status']?.toString() ?? 'active',
      createdAt: parseDate(
        json['createdAt'],
        parseDate(json['created_at'], now),
      )!,
      updatedAt: parseDate(json['updatedAt'], parseDate(json['updated_at'])),
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationEmail': organizationEmail,
      'name': name,
      'description': description,
      'model': model,
      'serialNumber': serialNumber,
      'manufacturer': manufacturer,
      'purchaseDate': purchaseDate != null
          ? Timestamp.fromDate(purchaseDate!)
          : null,
      'warrantyExpiry': warrantyExpiry != null
          ? Timestamp.fromDate(warrantyExpiry!)
          : null,
      'location': location,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
