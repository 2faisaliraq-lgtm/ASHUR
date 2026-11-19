import 'package:cloud_firestore/cloud_firestore.dart';

import 'category_entity.dart';

/// نتيجة تحميل صفحة من الفئات
class CategoriesPage {
  const CategoriesPage({required this.categories, required this.lastDocument});

  final List<CategoryEntity> categories;
  final DocumentSnapshot<Object?>? lastDocument;
}
