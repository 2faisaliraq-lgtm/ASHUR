import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_management_entity.dart';

/// نتيجة تحميل صفحة من المستخدمين
///
/// ✅ ملاحظة للمبرمجين المستقبليين:
/// `lastDocument` هو آخر مستند في صفحة الاستعلام
/// نفسه (snapshot.docs.last) ويُستخدم كمؤشر
/// `startAfterDocument` للصفحة التالية. إعادته مع
/// المستخدمين يمنع جلب المستند مجدداً عبر
/// `getUserDocument` (جولة شبكة زائدة بعد
/// كل تحميل صفحة). لا تُرجع هذا إلى جلب منفصل.
class UsersPage {
  const UsersPage({required this.users, required this.lastDocument});

  final List<UserManagementEntity> users;
  final DocumentSnapshot<Object?>? lastDocument;
}
