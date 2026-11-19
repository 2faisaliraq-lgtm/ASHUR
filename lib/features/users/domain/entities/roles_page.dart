import 'package:cloud_firestore/cloud_firestore.dart';

import 'role_entity.dart';

/// نتيجة تحميل صفحة من الأدوار
class RolesPage {
  const RolesPage({required this.roles, required this.lastDocument});

  final List<RoleEntity> roles;
  final DocumentSnapshot<Object?>? lastDocument;
}
