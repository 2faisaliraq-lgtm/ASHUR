import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/expense_entity.dart';
import '../../../../core/utils/date_parser.dart';

class ExpenseModel extends ExpenseEntity {
  const ExpenseModel({
    required super.id,
    required super.organizationEmail,
    required super.title,
    required super.description,
    required super.amount,
    required super.category,
    required super.date,
    required super.paymentMethod,
    required super.status, required super.createdAt, required super.updatedAt, required super.createdBy, super.receiptUrl,
    super.approvedBy,
    super.approvedAt,
    super.updatedBy,
    super.paidAmount = 0.0,
  });

  factory ExpenseModel.fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
      id: entity.id,
      organizationEmail: entity.organizationEmail,
      title: entity.title,
      description: entity.description,
      amount: entity.amount,
      category: entity.category,
      date: entity.date,
      paymentMethod: entity.paymentMethod,
      receiptUrl: entity.receiptUrl,
      status: entity.status,
      approvedBy: entity.approvedBy,
      approvedAt: entity.approvedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      paidAmount: entity.paidAmount,
    );
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    // ملاحظة للمبرمجين المستقبليين: منطق استخلاص العنوان والوصف مبسط هنا.
    // إذا كان العنوان فارغاً يُستخدم 'بدون عنوان'، وإذا كان الوصف فارغاً يُستخدم سلسلة فارغة.
    final rawTitle = json['title']?.toString() ?? '';
    final rawDescription = json['description']?.toString() ?? '';
    final rawNotes = json['notes']?.toString() ?? '';

    return ExpenseModel(
      id: json['id']?.toString() ?? '',
      organizationEmail: json['organizationEmail']?.toString() ?? '',
      title: rawTitle.isNotEmpty ? rawTitle : 'بدون عنوان',
      description: rawDescription.isNotEmpty ? rawDescription : (rawNotes.isNotEmpty ? rawNotes : ''),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? 'غير محدد',
      date: DateParser.parse(json['date'] ?? json['expenseDate']),
      paymentMethod: json['paymentMethod']?.toString() ?? 'غير محدد',
      receiptUrl: json['receiptUrl']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      approvedBy: json['approvedBy']?.toString(),
      approvedAt: json['approvedAt'] != null
          ? DateParser.parse(json['approvedAt'])
          : null,
      createdAt: DateParser.parse(json['createdAt']),
      updatedAt: DateParser.parse(json['updatedAt'] ?? json['createdAt']),
      createdBy: json['createdBy']?.toString() ?? 'المدير',
      updatedBy: json['updatedBy']?.toString(),
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ⚠️ ملاحظة للمبرمجين المستقبليين: toJson() يُعيد حقل 'id' مع جميع الحقول.
  // عند استخدامه في transaction.update() (انظر expense_repository_impl.dart السطر 577)
  // قد يحاول تحديث معرف المستند الذي لا يمكن تغييره في Firestore.
  // يفضل استبعاد 'id' و 'createdAt' و 'createdBy' من خريطة التحديث مستقبلاً.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationEmail': organizationEmail,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      'receiptUrl': receiptUrl,
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'paidAmount': paidAmount,
    };
  }

  /// تحويل إلى JSON للتحديث — يستبعد الحقول التي لا يمكن تغييرها في Firestore (id، createdAt، createdBy)
  /// تُستخدم هذه الطريقة في transaction.update() بدلاً من toJson() لتجنب محاولة تحديث معرف المستند.
  Map<String, dynamic> toUpdateJson() {
    return {
      'organizationEmail': organizationEmail,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      'receiptUrl': receiptUrl,
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
      'paidAmount': paidAmount,
    };
  }
}
