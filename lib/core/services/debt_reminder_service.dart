import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/customers/domain/entities/customer_entity.dart';
import '../../features/invoices/domain/entities/invoice_entity.dart';
import '../email/email_normalization_service.dart';
import 'notification_service.dart';
import 'pdf/pdf_settings_service.dart';
import 'whatsapp_service.dart';

/// خدمة التذكير بالديون
class DebtReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final _emailService = EmailNormalizationService();

  /// إرسال تذكير لجميع العملاء المدينين
  Future<void> sendRemindersToAllDebtors(String organizationEmail) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // جلب اسم المؤسسة من الإعدادات
      String organizationName = 'شركتنا';
      try {
        final pdfSettingsService = PdfSettingsService();
        final settings = await pdfSettingsService.getSettings(
          organizationEmail,
        );
        if (settings.organizationName.isNotEmpty) {
          organizationName = settings.organizationName;
        }
      } on Exception catch (_) {
        // فشل في جلب اسم المؤسسة
      }

      // جلب إعدادات التذكير
      final settingsDoc = await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('notifications')
          .doc('settings')
          .get();

      if (!settingsDoc.exists) return;

      final settings = settingsDoc.data();
      final reminderSettings =
          settings?['reminderSettings'] as Map<String, dynamic>?;

      if (reminderSettings == null || !(reminderSettings['enabled'] ?? false)) {
        return; // التذكير معطل
      }

      final minimumDebt = (reminderSettings['minimumDebt'] ?? 100.0) as double;

      // جلب جميع العملاء المدينين
      final customersSnapshot = await _firestore
          .collection('customers')
          .where('organizationEmail', isEqualTo: organizationEmail)
          .where('totalDebt', isGreaterThan: minimumDebt)
          .where('status', isEqualTo: 'active')
          .get();

      for (final customerDoc in customersSnapshot.docs) {
        try {
          final customer = _customerFromFirestore(customerDoc);
          await sendReminderToCustomer(
            customer,
            organizationEmail,
            organizationName,
          );
        } on Exception catch (_) {
          // تجاهل أخطاء العملاء الفرديين
        }
      }
    } on Exception catch (_) {
      // تسجيل الخطأ
    }
  }

  /// إرسال تذكير لعميل واحد
  Future<bool> sendReminderToCustomer(
    CustomerEntity customer,
    String organizationEmail,
    String organizationName,
  ) async {
    try {
      // جلب الفواتير المستحقة للعميل
      final invoicesSnapshot = await _firestore
          .collection('invoices')
          .where('organizationEmail', isEqualTo: organizationEmail)
          .where('customerId', isEqualTo: customer.id)
          .where('status', whereIn: ['unpaid', 'partial'])
          .get();

      if (invoicesSnapshot.docs.isEmpty) return false;

      final overdueInvoices = <String>[];
      for (final doc in invoicesSnapshot.docs) {
        final invoice = _invoiceFromFirestore(doc);
        if (invoice.calculateRemainingAmount() > 0) {
          overdueInvoices.add(
            '${invoice.invoiceNumber} - ${invoice.calculateRemainingAmount().toStringAsFixed(2)} دينار',
          );
        }
      }

      if (overdueInvoices.isEmpty) return false;

      // إرسال رسالة التذكير
      final message = WhatsAppService.createAdvancedReminderMessage(
        customerName: customer.name,
        totalDebt: customer.totalDebt,
        overdueInvoicesCount: overdueInvoices.length,
        organizationName: organizationName,
        overdueInvoices: overdueInvoices,
      );

      return await WhatsAppService.sendMessage(
        phoneNumber: customer.phone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  /// إرسال تذكير بسيط لعميل واحد (بدون تفاصيل الفواتير)
  Future<bool> sendSimpleReminderToCustomer(
    CustomerEntity customer,
    String organizationEmail,
  ) async {
    try {
      if (customer.totalDebt <= 0) return false;
      if (customer.phone.isEmpty) return false;

      // التحقق من تفعيل الإشعارات
      final isEnabled = await _notificationService
          .isWhatsAppNotificationEnabled(organizationEmail);
      if (!isEnabled) return false;

      final isTypeEnabled = await _notificationService
          .isNotificationTypeEnabled(organizationEmail, 'debtReminder');
      if (!isTypeEnabled) return false;

      // جلب اسم المؤسسة من الإعدادات
      String organizationName = 'شركتنا';
      try {
        final pdfSettingsService = PdfSettingsService();
        final settings = await pdfSettingsService.getSettings(
          organizationEmail,
        );
        if (settings.organizationName.isNotEmpty) {
          organizationName = settings.organizationName;
        }
      } on Exception catch (_) {
        // فشل في جلب اسم المؤسسة
      }

      // إنشاء رسالة التذكير
      final message = WhatsAppService.createDebtReminderMessageSimple(
        customerName: customer.name,
        debtAmount: customer.totalDebt,
        organizationName: organizationName,
      );

      return await WhatsAppService.sendMessage(
        phoneNumber: customer.phone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  CustomerEntity _customerFromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    final mapData = data as Map<String, dynamic>;
    return CustomerEntity(
      id: doc.id,
      organizationEmail: mapData['organizationEmail'] ?? '',
      name: mapData['name'] ?? '',
      email: mapData['email'] ?? '',
      phone: mapData['phone'] ?? '',
      totalPurchases: (mapData['totalPurchases'] ?? 0).toDouble(),
      totalDebt: (mapData['totalDebt'] ?? 0).toDouble(),
      status: mapData['status'] ?? 'active',
      createdAt: (mapData['createdAt'] as Timestamp).toDate(),
      updatedAt: (mapData['updatedAt'] as Timestamp).toDate(),
      invoiceIds:
          (mapData['invoiceIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      logIds:
          (mapData['logIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  InvoiceEntity _invoiceFromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    final mapData = data as Map<String, dynamic>;
    return InvoiceEntity(
      id: doc.id,
      invoiceNumber: data['invoiceNumber'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerId: data['customerId'] ?? '',
      invoiceDate: (data['invoiceDate'] as Timestamp).toDate(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      paidAmount: (data['paidAmount'] ?? 0).toDouble(),
      remainingAmount: (data['remainingAmount'] ?? 0).toDouble(),
      status: data['status'] ?? 'unpaid',
      type: data['type'] ?? 'sales',
      items: const [],
      organizationEmail: data['organizationEmail'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }
}
