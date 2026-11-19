import 'package:equatable/equatable.dart';

/// كيان إحصائيات التقارير
/// ⚠️ ملاحظة: حقل monthlyReports يُعاد من getReportsStatisticsStream (في المستودع التنفيذي)
/// لكنه غير موجود في هذا الكيان — يجب إضافته هنا أو إزالة المفتاح من الخريطة المعادة
/// لتجنب فقدان البيانات عند التحويل بين الكيان والخريطة.
class ReportStatsEntity extends Equatable {

  const ReportStatsEntity({
    required this.totalReports,
    required this.pendingReports,
    required this.completedReports,
    required this.failedReports,
    required this.financialReports,
    required this.inventoryReports,
    required this.salesReports,
    this.monthlyReports = 0, // ⚠️ أُضيف لدعم الإحصائيات الشهرية من الستريم
  });
  final int totalReports;
  final int pendingReports;
  final int completedReports;
  final int failedReports;
  final int financialReports;
  final int inventoryReports;
  final int salesReports;
  final int monthlyReports; // ⚠️ عدد التقارير التي أُنشئت هذا الشهر

  @override
  List<Object?> get props => [
    totalReports,
    pendingReports,
    completedReports,
    failedReports,
    financialReports,
    inventoryReports,
    salesReports,
    monthlyReports,
  ];
}
