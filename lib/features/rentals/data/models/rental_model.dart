import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/rental_entity.dart';

class RentalModel extends RentalEntity {
  const RentalModel({
    required super.id,
    required super.organizationEmail,
    required super.itemName,
    required super.renterName,
    required super.rentalPrice,
    required super.deposit,
    required super.startDate,
    required super.endDate,
    required super.status,
    required super.paymentFrequency,
    required super.paymentDay,
    required super.createdAt,
    required super.createdBy,
    super.itemDescription,
    super.renterPhone,
    super.renterEmail,
    super.customerId,
    super.customerName,
    super.unitId,
    super.notes,
    super.attachments,
    super.updatedAt,
    super.updatedBy,
  });

  factory RentalModel.fromJson(Map<String, dynamic> json) {
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

    return RentalModel(
      id: json['id'] as String? ?? '',
      organizationEmail: json['organizationEmail'] as String? ?? '',
      itemName:
          json['itemName']?.toString() ??
          json['propertyName']?.toString() ??
          '', // backward compatibility
      itemDescription:
          json['itemDescription']?.toString() ??
          json['propertyAddress']?.toString(),
      renterName:
          json['renterName']?.toString() ??
          json['tenantName']?.toString() ??
          '',
      renterPhone:
          json['renterPhone']?.toString() ?? json['tenantPhone']?.toString(),
      renterEmail:
          json['renterEmail']?.toString() ?? json['tenantEmail']?.toString(),
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString(),
      unitId: json['unitId']?.toString(),
      // ⚠️ ملاحظة للمبرمجين المستقبليين: if القيمة نص غير رقمي يُلقي toDouble() استثناءً.
      // يُفضل استخدام double.tryParse مع fallback بدلاً من toDouble() لتجنب انهيار التطبيق
      // إذا كانت القيمة في Firestore نصاً غير رقمي.
      rentalPrice: (json['rentalPrice'] ?? json['monthlyRent'] ?? 0).toDouble(),
      deposit: (json['deposit'] ?? json['securityDeposit'] ?? 0).toDouble(),
      // ⚠️ ملاحظة للمبرمجين المستقبليين: إذا تعذر تحليل التاريخ والقيمة الافتراضية null، العامل ! يسبب سقوطاً.
      // إذا كانت كل من startDate و start_date-null أو غير صالحة، parseDate تُعيد null، ثم ! يسبب Crash.
      // يُفضل إرجاع DateTime.now() كقيمة افتراضية آمنة بدلاً من !.
      startDate: parseDate(
        json['startDate'],
        parseDate(json['start_date'], now),
      )!,
      endDate: parseDate(json['endDate'], parseDate(json['end_date'], now))!,
      status: json['status']?.toString() ?? 'pending',
      paymentFrequency: json['paymentFrequency']?.toString() ?? 'monthly',
      // ⚠️ ملاحظة للمبرمجين المستقبليين: if القيمة نص غير رقمي يُلقي toInt() استثناءً.
      // يُفضل استخدام int.tryParse مع fallback بدلاً من toInt() لتجنب انهيار التطبيق.
      paymentDay: (json['paymentDay'] ?? 1).toInt(),
      notes: json['notes']?.toString(),
      attachments: parseAttachments(json['attachments']),
      createdAt: parseDate(
        json['createdAt'],
        parseDate(json['created_at'], now),
      )!,
      updatedAt: parseDate(json['updatedAt'], parseDate(json['updated_at'])),
      createdBy:
          json['createdBy']?.toString() ??
          json['created_by']?.toString() ??
          'المدير',
      updatedBy:
          json['updatedBy']?.toString() ?? json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationEmail': organizationEmail,
      'itemName': itemName,
      'itemDescription': itemDescription,
      'renterName': renterName,
      'renterPhone': renterPhone,
      'renterEmail': renterEmail,
      'customerId': customerId,
      'customerName': customerName,
      'unitId': unitId,
      'rentalPrice': rentalPrice,
      'deposit': deposit,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'paymentFrequency': paymentFrequency,
      'paymentDay': paymentDay,
      'notes': notes,
      'attachments': attachments,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }
}
