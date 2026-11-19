import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rental_unit_entity.dart';

/// نموذج الشيء القابل للإيجار
class RentalUnitModel extends RentalUnitEntity {
  const RentalUnitModel({
    required super.id,
    required super.organizationEmail,
    required super.itemName,
    required super.itemType,
    required super.rentalPrice,
    required super.status,
    required super.createdAt,
    required super.createdBy,
    super.itemDescription,
    super.specifications,
    super.quantity,
    super.brand,
    super.model,
    super.year,
    super.condition,
    super.location,
    super.description,
    super.notes,
    super.images,
    super.currentRentalId,
    super.currentRenterName,
    super.updatedAt,
    super.updatedBy,
  });

  factory RentalUnitModel.fromEntity(RentalUnitEntity entity) {
    return RentalUnitModel(
      id: entity.id,
      organizationEmail: entity.organizationEmail,
      itemName: entity.itemName,
      itemDescription: entity.itemDescription,
      itemType: entity.itemType,
      rentalPrice: entity.rentalPrice,
      specifications: entity.specifications,
      quantity: entity.quantity,
      brand: entity.brand,
      model: entity.model,
      year: entity.year,
      condition: entity.condition,
      location: entity.location,
      status: entity.status,
      description: entity.description,
      notes: entity.notes,
      images: entity.images,
      currentRentalId: entity.currentRentalId,
      currentRenterName: entity.currentRenterName,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
    );
  }

  factory RentalUnitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    final mapData = data as Map<String, dynamic>;
    return RentalUnitModel(
      id: doc.id,
      organizationEmail: (mapData['organizationEmail'] as String?) ?? '',
      itemName:
          mapData['itemName'] as String? ?? mapData['unitName'] as String? ?? '',
      itemDescription:
          mapData['itemDescription'] as String? ?? mapData['unitAddress'] as String?,
      itemType:
          mapData['itemType'] as String? ?? mapData['unitType'] as String? ?? 'other',
      rentalPrice: (mapData['rentalPrice'] ?? mapData['monthlyRent'] ?? 0).toDouble(),
      specifications: mapData['specifications'] as String?,
      quantity: (mapData['quantity'] as num?)?.toInt(),
      brand: mapData['brand'] as String?,
      model: mapData['model'] as String?,
      year: (mapData['year'] as num?)?.toInt(),
      condition: mapData['condition'] as String?,
      location: mapData['location'] as String?,
      status: mapData['status'] as String? ?? 'available', // تجنب cast غير آمن قد يسبب انهيار التطبيق إذا كانت القيمة null
      description: mapData['description'] as String?,
      notes: mapData['notes'] as String?,
      images: mapData['images'] is List
          ? List<String>.from(mapData['images'] as List)
          : null,
      currentRentalId: mapData['currentRentalId'] as String?,
      currentRenterName:
          mapData['currentRenterName'] as String? ??
          mapData['currentTenantName'] as String?,
      createdAt: mapData['createdAt'] is Timestamp ? (mapData['createdAt'] as Timestamp).toDate() : DateTime.now(), // تأمين تحويل التاريخ ضد القيم غير المتوقعة
      updatedAt: mapData['updatedAt'] != null
          ? (mapData['updatedAt'] as Timestamp).toDate()
          : null,
      createdBy: mapData['createdBy'] as String? ?? '', // تجنب cast غير آمن إذا كانت القيمة null
      updatedBy: mapData['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationEmail': organizationEmail,
      'itemName': itemName,
      'itemDescription': itemDescription,
      'itemType': itemType,
      'rentalPrice': rentalPrice,
      'specifications': specifications,
      'quantity': quantity,
      'brand': brand,
      'model': model,
      'year': year,
      'condition': condition,
      'location': location,
      'status': status,
      'description': description,
      'notes': notes,
      'images': images,
      'currentRentalId': currentRentalId,
      'currentRenterName': currentRenterName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }
}
