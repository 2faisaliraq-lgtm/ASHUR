import 'package:cloud_firestore/cloud_firestore.dart';

import 'report_entity.dart';

/// نتيجة تحميل صفحة من التقارير
class ReportsPage {
  const ReportsPage({required this.reports, required this.lastDocument});

  final List<ReportEntity> reports;
  final DocumentSnapshot<Object?>? lastDocument;
}
