import 'package:cloud_firestore/cloud_firestore.dart';

import 'subscription_entity.dart';

/// نتيجة تحميل صفحة من الاشتراكات
///
/// ✅ ملاحظة للمبرمجين المستقبليين:
/// `lastDocument` هو آخر مستند في صفحة الاستعلام
/// نفسه (snapshot.docs.last) ويُستخدم كمؤشر
/// `startAfterDocument` للصفحة التالية.
class SubscriptionsPage {
  const SubscriptionsPage({required this.subscriptions, required this.lastDocument});

  final List<SubscriptionEntity> subscriptions;
  final DocumentSnapshot<Object?>? lastDocument;
}
