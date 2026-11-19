import 'package:cloud_firestore/cloud_firestore.dart';

import 'customer_entity.dart';

/// نتيجة تحميل صفحة من العملاء
///
/// ✅ ملاحظة للمبرمجين المستقبليين:
/// `lastDocument` هو آخر مستند في صفحة الاستعلام
/// نفسه (snapshot.docs.last) ويُستخدم كمؤشر
/// `startAfterDocument` للصفحة التالية. إعادته مع
/// العملاء يمنع جلب المستند مجدداً عبر
/// `getCustomerDocument` (جولة شبكة زائدة بعد
/// كل تحميل صفحة). لا تُرجع هذا إلى جلب منفصل.
class CustomersPage {
  const CustomersPage({required this.customers, required this.lastDocument});

  final List<CustomerEntity> customers;
  final DocumentSnapshot<Object?>? lastDocument;
}
