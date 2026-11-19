import 'package:cloud_firestore/cloud_firestore.dart';

import 'invoice_entity.dart';

/// نتيجة تحميل صفحة من الفواتير
///
/// ✅ ملاحظة للمبرمجين المستقبليين:
/// `lastDocument` هو آخر مستند في صفحة الاستعلام
/// نفسه (snapshot.docs.last) ويُستخدم كمؤشر
/// `startAfterDocument` للصفحة التالية. إعادته مع
/// الفواتير يمنع جلب المستند مجدداً عبر
/// `getInvoiceDocument` (جولة شبكة زائدة بعد
/// كل تحميل صفحة). لا تُرجع هذا إلى جلب منفصل.
class InvoicesPage {
  const InvoicesPage({required this.invoices, required this.lastDocument});

  final List<InvoiceEntity> invoices;
  final DocumentSnapshot<Object?>? lastDocument;
}
