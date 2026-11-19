import 'package:equatable/equatable.dart';

/// كيان المعدات
class EquipmentEntity extends Equatable {

  const EquipmentEntity({
    required this.id,
    required this.organizationEmail,
    required this.name,
    required this.status, required this.createdAt, this.description,
    this.model,
    this.serialNumber,
    this.manufacturer,
    this.purchaseDate,
    this.warrantyExpiry,
    this.location,
    this.updatedAt,
  });
  final String id;
  final String organizationEmail;
  final String name;
  final String? description;
  final String? model;
  final String? serialNumber;
  final String? manufacturer;
  final DateTime? purchaseDate;
  final DateTime? warrantyExpiry;
  final String? location;
  final String status; // active, inactive, under_maintenance, retired
  final DateTime createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    organizationEmail,
    name,
    description,
    model,
    serialNumber,
    manufacturer,
    purchaseDate,
    warrantyExpiry,
    location,
    status,
    createdAt,
    updatedAt,
  ];

  EquipmentEntity copyWith({
    String? id,
    String? organizationEmail,
    String? name,
    String? description,
    String? model,
    String? serialNumber,
    String? manufacturer,
    DateTime? purchaseDate,
    DateTime? warrantyExpiry,
    String? location,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EquipmentEntity(
      id: id ?? this.id,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      name: name ?? this.name,
      description: description ?? this.description,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      manufacturer: manufacturer ?? this.manufacturer,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      location: location ?? this.location,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == 'active';
  bool get isUnderMaintenance => status == 'under_maintenance';
  bool get isWarrantyValid =>
      warrantyExpiry != null && warrantyExpiry!.isAfter(DateTime.now());
}
