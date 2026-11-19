import 'package:cloud_firestore/cloud_firestore.dart';

import 'subscription_type_entity.dart';

/// نتيجة تحميل صفحة من أنواع الاشتراكات
class SubscriptionTypesPage {
  const SubscriptionTypesPage({required this.types, required this.lastDocument});

  final List<SubscriptionTypeEntity> types;
  final DocumentSnapshot<Object?>? lastDocument;
}
