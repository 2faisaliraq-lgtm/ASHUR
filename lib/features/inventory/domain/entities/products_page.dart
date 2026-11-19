import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_entity.dart';

/// نتيجة تحميل صفحة من المنتجات
///
/// ✅ ملاحظة للمبرمجين المستقبليين:
/// `lastDocument` هو آخر مستند في صفحة الاستعلام
/// نفسه (snapshot.docs.last) ويُستخدم كمؤشر
/// `startAfterDocument` للصفحة التالية. إعادته مع
/// المنتجات يمنع جلب المستند مجدداً عبر
/// `getProductDocument` (جولة شبكة زائدة بعد
/// كل تحميل صفحة). لا تُرجع هذا إلى جلب منفصل.
class ProductsPage {
  const ProductsPage({
    required this.products,
    required this.lastDocument,
    this.hasMore,
  });

  final List<ProductEntity> products;
  final DocumentSnapshot<Object?>? lastDocument;
  final bool? hasMore;
}
