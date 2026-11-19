import 'package:cloud_firestore/cloud_firestore.dart';

import '../email/email_normalization_service.dart';
import 'pdf/pdf_settings_service.dart';
import 'whatsapp_service.dart';

/// خدمة إدارة الإشعارات المركزية
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _emailService = EmailNormalizationService();
  final _pdfSettingsService = PdfSettingsService();

  /// جلب اسم المؤسسة من الإعدادات
  Future<String> _getOrganizationName(String organizationEmail) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final settings = await _pdfSettingsService.getSettings(normalizedEmail);
      if (settings.organizationName.isNotEmpty) {
        return settings.organizationName;
      }
    } on Exception catch (_) {
      // فشل في جلب اسم المؤسسة
    }
    return 'المؤسسة';
  }

  /// التحقق من تفعيل إشعارات واتساب للمؤسسة
  Future<bool> isWhatsAppNotificationEnabled(String organizationEmail) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final doc = await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('notifications')
          .doc('settings')
          .get();

      if (!doc.exists) return true; // افتراضياً مفعل

      final data = doc.data();
      return data?['whatsappEnabled'] ?? true;
    } on Exception catch (_) {
      return true; // في حالة الخطأ، نفترض أنه مفعل
    }
  }

  /// التحقق من تفعيل نوع إشعار معين
  Future<bool> isNotificationTypeEnabled(
    String organizationEmail,
    String notificationType,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final doc = await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('notifications')
          .doc('settings')
          .get();

      if (!doc.exists) return true;

      final data = doc.data();
      final notificationTypes =
          data?['notificationTypes'] as Map<String, dynamic>?;

      if (notificationTypes == null) return true;

      return notificationTypes[notificationType] ?? true;
    } on Exception catch (_) {
      return true;
    }
  }

  /// إرسال إشعار فاتورة مع التحقق من الإعدادات
  Future<bool> sendInvoiceNotification({
    required String organizationEmail,
    required String customerPhone,
    required String customerName,
    required String invoiceNumber,
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
    required double balanceBeforeInvoice,
    required double balanceAfterInvoice,
    required String invoiceType,
    required DateTime invoiceDate,
    List<String>? items,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // التحقق من تفعيل الإشعارات
      final isEnabled = await isWhatsAppNotificationEnabled(normalizedEmail);
      if (!isEnabled) return false;

      // التحقق من تفعيل نوع الإشعار
      final isTypeEnabled = await isNotificationTypeEnabled(
        normalizedEmail,
        'invoiceCreated',
      );
      if (!isTypeEnabled) return false;

      // التحقق من وجود رقم الهاتف
      if (customerPhone.isEmpty) return false;

      // جلب اسم المؤسسة من الإعدادات
      final organizationName = await _getOrganizationName(organizationEmail);

      // إنشاء الرسالة
      final message = WhatsAppService.createDetailedInvoiceMessage(
        customerName: customerName,
        invoiceNumber: invoiceNumber,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        balanceBeforeInvoice: balanceBeforeInvoice,
        balanceAfterInvoice: balanceAfterInvoice,
        invoiceType: invoiceType,
        invoiceDate: invoiceDate,
        organizationName: organizationName,
        items: items,
      );

      // إرسال الرسالة
      return await WhatsAppService.sendMessage(
        phoneNumber: customerPhone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  /// إرسال إشعار اشتراك جديد
  Future<bool> sendSubscriptionNotification({
    required String organizationEmail,
    required String customerPhone,
    required String customerName,
    required String subscriptionName,
    required String subscriptionType,
    required double price,
    required DateTime startDate,
    required DateTime endDate,
    required String duration,
    String? invoiceNumber,
    double? balanceBeforeInvoice,
    double? balanceAfterInvoice,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    List<Map<String, dynamic>>? taxes,
    List<String>? features,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      final isEnabled = await isWhatsAppNotificationEnabled(normalizedEmail);
      if (!isEnabled) return false;

      final isTypeEnabled = await isNotificationTypeEnabled(
        normalizedEmail,
        'subscriptionCreated',
      );
      if (!isTypeEnabled) return false;

      if (customerPhone.isEmpty) return false;

      // جلب اسم المؤسسة من الإعدادات
      final organizationName = await _getOrganizationName(organizationEmail);

      final message = WhatsAppService.createSubscriptionMessage(
        customerName: customerName,
        subscriptionName: subscriptionName,
        subscriptionType: subscriptionType,
        price: price,
        startDate: startDate,
        endDate: endDate,
        duration: duration,
        organizationName: organizationName,
        invoiceNumber: invoiceNumber,
        balanceBeforeInvoice: balanceBeforeInvoice,
        balanceAfterInvoice: balanceAfterInvoice,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        taxes: taxes,
        features: features,
      );

      return await WhatsAppService.sendMessage(
        phoneNumber: customerPhone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  /// إرسال إشعار تجديد اشتراك
  Future<bool> sendSubscriptionRenewalNotification({
    required String organizationEmail,
    required String customerPhone,
    required String customerName,
    required String subscriptionName,
    required String subscriptionType,
    required DateTime startDate,
    required DateTime newEndDate,
    required double price,
    String? invoiceNumber, // رقم الفاتورة
    double? balanceBeforeInvoice,
    double? balanceAfterInvoice,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    List<Map<String, dynamic>>? taxes,
    List<String>? features, // ميزات الاشتراك
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      final isEnabled = await isWhatsAppNotificationEnabled(normalizedEmail);
      if (!isEnabled) return false;

      if (customerPhone.isEmpty) return false;

      // جلب اسم المؤسسة من الإعدادات
      final organizationName = await _getOrganizationName(organizationEmail);

      final message = WhatsAppService.createSubscriptionRenewalMessage(
        customerName: customerName,
        subscriptionName: subscriptionName,
        subscriptionType: subscriptionType,
        startDate: startDate,
        newEndDate: newEndDate,
        price: price,
        organizationName: organizationName,
        invoiceNumber: invoiceNumber,
        balanceBeforeInvoice: balanceBeforeInvoice,
        balanceAfterInvoice: balanceAfterInvoice,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        taxes: taxes,
        features: features,
      );

      return await WhatsAppService.sendMessage(
        phoneNumber: customerPhone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  /// إرسال إشعار تحديث دفعة
  Future<bool> sendPaymentUpdateNotification({
    required String organizationEmail,
    required String customerPhone,
    required String customerName,
    required String invoiceNumber,
    required double paidAmount,
    required double remainingAmount,
    required double currentBalance,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      final isEnabled = await isWhatsAppNotificationEnabled(normalizedEmail);
      if (!isEnabled) return false;

      if (customerPhone.isEmpty) return false;

      // جلب اسم المؤسسة من الإعدادات
      final organizationName = await _getOrganizationName(organizationEmail);

      final message = WhatsAppService.createPaymentUpdateMessage(
        customerName: customerName,
        invoiceNumber: invoiceNumber,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        currentBalance: currentBalance,
        organizationName: organizationName,
      );

      return await WhatsAppService.sendMessage(
        phoneNumber: customerPhone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  /// إرسال إشعار تذكير بالدين
  Future<bool> sendDebtReminderNotification({
    required String organizationEmail,
    required String customerPhone,
    required String customerName,
    required double totalDebt,
    required int overdueInvoicesCount,
    List<String>? overdueInvoices,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      final isEnabled = await isWhatsAppNotificationEnabled(normalizedEmail);
      if (!isEnabled) return false;

      final isTypeEnabled = await isNotificationTypeEnabled(
        normalizedEmail,
        'debtReminder',
      );
      if (!isTypeEnabled) return false;

      if (customerPhone.isEmpty) return false;

      // جلب اسم المؤسسة من الإعدادات
      final organizationName = await _getOrganizationName(organizationEmail);

      final message = WhatsAppService.createAdvancedReminderMessage(
        customerName: customerName,
        totalDebt: totalDebt,
        overdueInvoicesCount: overdueInvoicesCount,
        organizationName: organizationName,
        overdueInvoices: overdueInvoices,
      );

      return await WhatsAppService.sendMessage(
        phoneNumber: customerPhone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  /// إرسال إشعار طلب صيانة
  Future<bool> sendMaintenanceRequestNotification({
    required String organizationEmail,
    required String customerPhone,
    required String customerName,
    required String title,
    required String priority,
    required DateTime requestDate,
    String? description,
    String? equipmentName,
    DateTime? scheduledDate,
    double? estimatedCost,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      final isEnabled = await isWhatsAppNotificationEnabled(normalizedEmail);
      if (!isEnabled || customerPhone.isEmpty) return false;

      // جلب اسم المؤسسة من الإعدادات
      final organizationName = await _getOrganizationName(organizationEmail);

      final message = WhatsAppService.createMaintenanceRequestMessage(
        customerName: customerName,
        title: title,
        description: description ?? '',
        priority: priority,
        equipmentName: equipmentName ?? '',
        requestDate: requestDate,
        scheduledDate: scheduledDate,
        estimatedCost: estimatedCost,
        organizationName: organizationName,
      );

      return await WhatsAppService.sendMessage(
        phoneNumber: customerPhone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  /// إرسال إشعار طلب إيجار
  Future<bool> sendRentalRequestNotification({
    required String organizationEmail,
    required String customerPhone,
    required String customerName,
    required String itemName,
    required double rentalPrice,
    required double deposit,
    required DateTime startDate,
    required DateTime endDate,
    required String paymentFrequency,
    String? itemDescription,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      final isEnabled = await isWhatsAppNotificationEnabled(normalizedEmail);
      if (!isEnabled || customerPhone.isEmpty) return false;

      final organizationName = await _getOrganizationName(organizationEmail);

      final message = WhatsAppService.createRentalRequestMessage(
        customerName: customerName,
        itemName: itemName,
        itemDescription: itemDescription ?? '',
        rentalPrice: rentalPrice,
        deposit: deposit,
        startDate: startDate,
        endDate: endDate,
        paymentFrequency: paymentFrequency,
        organizationName: organizationName,
      );

      return await WhatsAppService.sendMessage(
        phoneNumber: customerPhone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  /// إرسال إشعار تصفير الحساب
  Future<bool> sendAccountClearanceNotification({
    required String organizationEmail,
    required String customerPhone,
    required String customerName,
    required double clearedAmount,
    String? invoiceNumber,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      final isEnabled = await isWhatsAppNotificationEnabled(normalizedEmail);
      if (!isEnabled || customerPhone.isEmpty) return false;

      final organizationName = await _getOrganizationName(organizationEmail);

      final message = WhatsAppService.createAccountClearanceMessage(
        customerName: customerName,
        clearedAmount: clearedAmount,
        organizationName: organizationName,
        invoiceNumber: invoiceNumber,
      );

      return await WhatsAppService.sendMessage(
        phoneNumber: customerPhone,
        message: message,
      );
    } on Exception catch (_) {
      return false;
    }
  }
}
