import 'package:cloud_firestore/cloud_firestore.dart';

import 'shelf_entity.dart';

/// نتيجة تحميل صفحة من الأرفف
class ShelvesPage {
  const ShelvesPage({required this.shelves, required this.lastDocument});

  final List<ShelfEntity> shelves;
  final DocumentSnapshot<Object?>? lastDocument;
}
