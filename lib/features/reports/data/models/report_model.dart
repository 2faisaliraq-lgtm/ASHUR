import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/report_entity.dart';
import '../../../../core/utils/date_parser.dart';

class ReportModel extends ReportEntity {
  const ReportModel({
    required super.id,
    required super.organizationEmail,
    required super.title,
    required super.description,
    required super.type,
    required super.startDate,
    required super.endDate,
    required super.data,
    required super.status,
    required super.createdAt, super.generatedBy,
    super.completedAt,
    super.createdBy, // تغيير إلى اختياري
    super.updatedBy, // إضافة updatedBy
  });

  factory ReportModel.fromEntity(ReportEntity entity) {
    return ReportModel(
      id: entity.id,
      organizationEmail: entity.organizationEmail,
      title: entity.title,
      description: entity.description,
      type: entity.type,
      startDate: entity.startDate,
      endDate: entity.endDate,
      data: entity.data,
      status: entity.status,
      generatedBy: entity.generatedBy,
      createdAt: entity.createdAt,
      completedAt: entity.completedAt,
      createdBy: entity.createdBy, // إضافة createdBy
      updatedBy: entity.updatedBy, // إضافة updatedBy
    );
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id']?.toString() ?? '',
      organizationEmail: json['organizationEmail']?.toString() ?? '',
      title: json['title']?.toString() ?? 'بدون عنوان',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'custom',
      // ⚠️ DateParser.parse قد يلقى استثناء إذا كانت القيمة فارغة أو غير صالحة —
      // يجب التأكد من وجود createdAt في جميع المستندات المخزنة (انظر سجل migrations)
      startDate: DateParser.parse(json['startDate'] ?? ''),
      endDate: DateParser.parse(json['endDate'] ?? ''),
      data: (json['data'] != null && json['data'] is Map)
          ? Map<String, dynamic>.from(json['data'] as Map)
          : {},
      status: json['status']?.toString() ?? 'pending',
      generatedBy: json['generatedBy']?.toString(),
      // ⚠️ إذا كانت createdAt مفقودة في المستند، DateParser.parse قد يُعطي تاريخًا افتراضيًا
      // أو يُلقى استثناء — يُنصح بتقويم البيانات القديمة وضمان وجود هذا الحقل
      createdAt: DateParser.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateParser.parse(json['completedAt'])
          : null,
      createdBy:
          json['createdBy']?.toString() ??
          json['created_by']?.toString(), // السماح بـ null للبيانات القديمة
      updatedBy:
          json['updatedBy']?.toString() ??
          json['updated_by']?.toString(), // إضافة updatedBy
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationEmail': organizationEmail,
      'title': title,
      'description': description,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'data': data,
      'status': status,
      'generatedBy': generatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null, // null إذا لم يكتمل التقرير بعد — يُستبعد من الفهارس الاستعلامية
      'createdBy': createdBy, // إضافة createdBy
      'updatedBy': updatedBy, // إضافة updatedBy
    };
  }
}
