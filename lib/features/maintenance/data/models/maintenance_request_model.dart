import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/maintenance_request_entity.dart';

/// نموذج طلب الصيانة
class MaintenanceRequestModel extends MaintenanceRequestEntity {
  const MaintenanceRequestModel({
    required super.id,
    required super.organizationEmail,
    required super.title,
    required super.description,
    required super.status,
    required super.priority,
    required super.requestDate, required super.requestedBy, required super.createdAt, super.assignedTo,
    super.equipmentId,
    super.equipmentName,
    super.location,
    super.scheduledDate,
    super.completedDate,
    super.estimatedCost,
    super.actualCost,
    super.attachments,
    super.notes,
    super.updatedAt,
    super.updatedBy,
    super.createdBy, // تغيير إلى اختياري
  });

  /// من JSON
  factory MaintenanceRequestModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    DateTime? parseDate(dynamic value, [DateTime? defaultValue]) {
      if (value == null) return defaultValue;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return defaultValue;
    }

    List<String>? parseAttachments(dynamic value) {
      if (value == null) return null;
      if (value is List) return value.map((e) => e.toString()).toList();
      return null;
    }

    return MaintenanceRequestModel(
      id: json['id'] as String? ?? '',
      organizationEmail: json['organizationEmail'] as String? ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      priority: json['priority']?.toString() ?? 'medium',
      assignedTo: json['assignedTo']?.toString(),
      equipmentId: json['equipmentId']?.toString(),
      equipmentName: json['equipmentName']?.toString(),
      location: json['location']?.toString(),
      requestDate: parseDate(
        json['requestDate'],
        parseDate(json['request_date'], now),
      ) ?? DateTime.now(),
      scheduledDate: parseDate(
        json['scheduledDate'],
        parseDate(json['scheduled_date']),
      ),
      completedDate: parseDate(
        json['completedDate'],
        parseDate(json['completed_date']),
      ),
      requestedBy:
          json['requestedBy']?.toString() ??
          json['requested_by']?.toString() ??
          '',
      estimatedCost: (json['estimatedCost'] ?? json['estimated_cost'])
          ?.toDouble(),
      actualCost: (json['actualCost'] ?? json['actual_cost'])?.toDouble(),
      attachments: parseAttachments(json['attachments']),
      notes: json['notes']?.toString(),
      createdAt: parseDate(
        json['createdAt'],
        parseDate(json['created_at'], now),
      ) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt'], parseDate(json['updated_at'])),
      updatedBy:
          json['updatedBy']?.toString() ?? json['updated_by']?.toString(),
      createdBy:
          json['createdBy']?.toString() ??
          json['created_by']?.toString() ??
          'المدير', // إضافة createdBy
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationEmail': organizationEmail,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'assignedTo': assignedTo,
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'location': location,
      'requestDate': Timestamp.fromDate(requestDate),
      'scheduledDate': scheduledDate != null
          ? Timestamp.fromDate(scheduledDate!)
          : null,
      'completedDate': completedDate != null
          ? Timestamp.fromDate(completedDate!)
          : null,
      'requestedBy': requestedBy,
      'estimatedCost': estimatedCost,
      'actualCost': actualCost,
      'attachments': attachments,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
      'createdBy': createdBy, // إضافة createdBy
    };
  }
}
