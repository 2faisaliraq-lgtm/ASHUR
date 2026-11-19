import 'package:cloud_firestore/cloud_firestore.dart';

import 'customer_group_entity.dart';

/// نتيجة تحميل صفحة من مجموعات العملاء
class CustomerGroupsPage {
  const CustomerGroupsPage({required this.groups, required this.lastDocument});

  final List<CustomerGroupEntity> groups;
  final DocumentSnapshot<Object?>? lastDocument;
}
