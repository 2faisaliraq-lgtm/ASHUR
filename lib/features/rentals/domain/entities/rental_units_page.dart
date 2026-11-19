import 'package:cloud_firestore/cloud_firestore.dart';

import 'rental_unit_entity.dart';

/// نتيجة تحميل صفحة من وحدات الإيجار
class RentalUnitsPage {
  const RentalUnitsPage({required this.units, required this.lastDocument});

  final List<RentalUnitEntity> units;
  final DocumentSnapshot<Object?>? lastDocument;
}
