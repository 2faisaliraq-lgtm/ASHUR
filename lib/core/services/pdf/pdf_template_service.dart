import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../features/invoices/domain/entities/invoice_template_entity.dart';

/// خدمة إدارة قوالب الفواتير PDF
class PdfTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// الحصول على القالب الافتراضي للمنظمة
  Future<InvoiceTemplateEntity?> getDefaultTemplate(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _normalizeEmail(organizationEmail);
      final doc = await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('pdf_templates')
          .doc('default')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data == null) return null;
        return InvoiceTemplateEntity.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on Exception {
      return null;
    }
  }

  /// الحصول على جميع قوالب المنظمة
  Future<List<InvoiceTemplateEntity>> getAllTemplates(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _normalizeEmail(organizationEmail);
      final snapshot = await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('pdf_templates')
          .get();

      return snapshot.docs
          .map((doc) {
            // ignore: unnecessary_non_null_assertion
            final data = doc.data()!;
            return InvoiceTemplateEntity.fromJson(
              Map<String, dynamic>.from(data),
            );
          })
          .whereType<InvoiceTemplateEntity>()
          .toList();
    } on Exception {
      return [];
    }
  }

  /// حفظ قالب جديد
  Future<void> saveTemplate(
    String organizationEmail,
    InvoiceTemplateEntity template,
  ) async {
    try {
      final normalizedEmail = _normalizeEmail(organizationEmail);
      await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('pdf_templates')
          .doc(template.id)
          .set(template.toJson());
    } on Exception {
      rethrow;
    }
  }

  /// حذف قالب
  Future<void> deleteTemplate(
    String organizationEmail,
    String templateId,
  ) async {
    try {
      final normalizedEmail = _normalizeEmail(organizationEmail);
      await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('pdf_templates')
          .doc(templateId)
          .delete();
    } on Exception {
      rethrow;
    }
  }

  /// تعيين قالب كافتراضي
  Future<void> setDefaultTemplate(
    String organizationEmail,
    String templateId,
  ) async {
    try {
      final normalizedEmail = _normalizeEmail(organizationEmail);
      await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('pdf_templates')
          .doc('default')
          .set({'templateId': templateId});
    } on Exception {
      rethrow;
    }
  }

  /// تطبيع البريد الإلكتروني
  String _normalizeEmail(String email) {
    return email.toLowerCase().replaceAll('.', '_').replaceAll('@', '_at_');
  }
}
