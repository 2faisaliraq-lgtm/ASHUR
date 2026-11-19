import 'package:cloud_firestore/cloud_firestore.dart';

import 'maintenance_request_entity.dart';

/// نتيجة تحميل صفحة من طلبات الصيانة
///
/// ✅ ملاحظة للمبرمجين المستقبليين:
/// `lastDocument` هو آخر مستند في صفحة الاستعلام
/// نفسه (snapshot.docs.last) ويُستخدم كمؤشر
/// `startAfterDocument` للصفحة التالية. إعادته مع
/// الطلبات يمنع جلب المستند مجدداً عبر معرفه
/// (جولة شبكة زائدة بعد كل تحميل صفحة). لا تُرجع
/// هذا إلى جلب منفصل.
class MaintenanceRequestsPage {
  const MaintenanceRequestsPage({
    required this.requests,
    required this.lastDocument,
  });

  final List<MaintenanceRequestEntity> requests;
  final DocumentSnapshot<Object?>? lastDocument;
}
