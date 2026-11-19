import 'package:equatable/equatable.dart';

/// كيان التقرير
/// ⚠️ الحقول التالية اختيارية (nullable) لدعم التقارير القديمة التي تم إنشاؤها قبل إضافة هذه الحقول:
///   - generatedBy: معرف منقوم بإنتاج التقرير (قد يكون-null في السجلات القديمة)
///   - createdBy: معرف من أنشأ التقرير (اختياري للتوافق مع البيانات القديمة)
///   - updatedBy: آخر من عدل التقرير (إضافة جديدة، اختيارية)
///   - completedAt: تاريخ إكمال التقرير (null إذا كان التقرير لا يزال قيد التنفيذ أوpending)
class ReportEntity extends Equatable {

  const ReportEntity({
    required this.id,
    required this.organizationEmail,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.data,
    required this.status,
    required this.createdAt, this.generatedBy,
    this.completedAt,
    this.createdBy, // اختياري لدعم البيانات القديمة التي لا تحتوي على هذا الحقل
    this.updatedBy, // اختياري — يُسجل آخر من عدل التقرير، يُضاف فقط عند التعديل
  });
  final String id;
  final String organizationEmail;
  final String title;
  final String description;
  final String type; // financial, inventory, sales, expenses, custom
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> data;
  final String status; // pending, completed, failed
  final String? generatedBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? createdBy; // تغيير إلى اختياري لدعم البيانات القديمة
  final String? updatedBy;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isFailed => status.toLowerCase() == 'failed';

  ReportEntity copyWith({
    String? id,
    String? organizationEmail,
    String? title,
    String? description,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? data,
    String? status,
    String? generatedBy,
    DateTime? createdAt,
    DateTime? completedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return ReportEntity(
      id: id ?? this.id,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      data: data ?? this.data,
      status: status ?? this.status,
      generatedBy: generatedBy ?? this.generatedBy,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    createdBy: createdBy ?? this.createdBy,
    // updatedBy يُحدث فقط عند تعديل التقرير فعليًا — لا يُضبط عند الإنشاء الأولي
    updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props => [
    id,
    organizationEmail,
    title,
    description,
    type,
    startDate,
    endDate,
    data,
    status,
    generatedBy,
    createdAt,
    completedAt,
    createdBy, // يُشمل في المقارنة للتمييز بين التقارير القديمة والجديدة
    updatedBy, // يُشمل في المقارنة للكشف عن التعديلات
  ];
}
