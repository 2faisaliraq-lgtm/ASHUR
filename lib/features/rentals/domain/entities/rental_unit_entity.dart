import 'package:equatable/equatable.dart';

/// كيان الشيء القابل للإيجار
class RentalUnitEntity extends Equatable {
  const RentalUnitEntity({
    required this.id,
    required this.organizationEmail,
    required this.itemName,
    required this.itemType,
    required this.rentalPrice,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.itemDescription,
    this.specifications,
    this.quantity,
    this.brand,
    this.model,
    this.year,
    this.condition,
    this.location,
    this.description,
    this.notes,
    this.images,
    this.currentRentalId,
    this.currentRenterName,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String organizationEmail;
  final String itemName; // اسم الشيء (سيارة تويوتا، شقة، معدة حفر، إلخ)
  final String? itemDescription; // وصف مختصر
  final String
  itemType; // car, property, equipment, furniture, electronics, other
  final double rentalPrice; // سعر الإيجار
  final String? specifications; // المواصفات (JSON أو نص)
  final int? quantity; // الكمية المتاحة
  final String? brand; // الماركة/العلامة التجارية
  final String? model; // الموديل/الطراز
  final int? year; // سنة الصنع
  final String? condition; // الحالة: new, excellent, good, fair, poor
  final String? location; // الموقع
  final String status; // available, rented, maintenance, unavailable
  final String? description; // وصف تفصيلي
  final String? notes;
  final List<String>? images;
  final String? currentRentalId; // معرف عقد الإيجار الحالي
  final String? currentRenterName; // اسم المستأجر الحالي
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;

  @override
  List<Object?> get props => [
    id,
    organizationEmail,
    itemName,
    itemDescription,
    itemType,
    rentalPrice,
    specifications,
    quantity,
    brand,
    model,
    year,
    condition,
    location,
    status,
    description,
    notes,
    images,
    currentRentalId,
    currentRenterName,
    createdAt,
    updatedAt,
    createdBy,
    updatedBy,
  ];

  bool get isAvailable => status == 'available';
  bool get isRented => status == 'rented';
  bool get isInMaintenance => status == 'maintenance';
  bool get isUnavailable => status == 'unavailable';

  RentalUnitEntity copyWith({
    String? id,
    String? organizationEmail,
    String? itemName,
    String? itemDescription,
    String? itemType,
    double? rentalPrice,
    String? specifications,
    int? quantity,
    String? brand,
    String? model,
    int? year,
    String? condition,
    String? location,
    String? status,
    String? description,
    String? notes,
    List<String>? images,
    String? currentRentalId,
    String? currentRenterName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return RentalUnitEntity(
      id: id ?? this.id,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      itemName: itemName ?? this.itemName,
      itemDescription: itemDescription ?? this.itemDescription,
      itemType: itemType ?? this.itemType,
      rentalPrice: rentalPrice ?? this.rentalPrice,
      specifications: specifications ?? this.specifications,
      quantity: quantity ?? this.quantity,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      condition: condition ?? this.condition,
      location: location ?? this.location,
      status: status ?? this.status,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      images: images ?? this.images,
      currentRentalId: currentRentalId ?? this.currentRentalId,
      currentRenterName: currentRenterName ?? this.currentRenterName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
