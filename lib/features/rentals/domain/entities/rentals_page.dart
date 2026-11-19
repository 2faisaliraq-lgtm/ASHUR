import 'package:cloud_firestore/cloud_firestore.dart';

import 'rental_entity.dart';

/// نتيجة تحميل صفحة من عقود الإيجار
///
/// ✅ ملاحظة للمبرمجين المستقبليين:
/// `lastDocument` هو آخر مستند في صفحة الاستعلام
/// نفسه (snapshot.docs.last) ويُستخدم كمؤشر
/// `startAfterDocument` للصفحة التالية. إعادته مع
/// العقود يمنع جلب المستند مجدداً عبر
/// `getRentalDocument` (جولة شبكة زائدة بعد
/// كل تحميل صفحة). لا تُرجع هذا إلى جلب منفصل.
class RentalsPage {
  const RentalsPage({required this.rentals, required this.lastDocument});

  final List<RentalEntity> rentals;
  final DocumentSnapshot<Object?>? lastDocument;
}
