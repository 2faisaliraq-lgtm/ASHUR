import 'package:equatable/equatable.dart';

/// كيان إعدادات PDF
class PdfSettingsEntity extends Equatable {
  const PdfSettingsEntity({
    required this.organizationName,
    required this.organizationPhone,
    required this.organizationAddress,
    this.organizationEmail,
    this.organizationWebsite,
    this.organizationLogo,
    this.enableAutoGeneration = true,
    this.enableAutoSend = true,
    this.sendViaWhatsApp = true,
    this.sendViaEmail = false,
    this.sendPdfWithInvoice = false,
    this.uploadToStorage = true,
    this.deleteAfterDays = 180,
    this.defaultFooterText = 'شكراً لتعاملكم معنا',
  });

  /// إعدادات افتراضية
  factory PdfSettingsEntity.defaultSettings() {
    return const PdfSettingsEntity(
      organizationName: 'اسم شركتك',
      organizationPhone: '',
      organizationAddress: 'العنوان',
    );
  }

  factory PdfSettingsEntity.fromJson(Map<String, dynamic> json) {
    return PdfSettingsEntity(
      organizationName: json['organizationName'] as String,
      organizationPhone: json['organizationPhone'] as String,
      organizationAddress: json['organizationAddress'] as String,
      organizationEmail: json['organizationEmail'] as String?,
      organizationWebsite: json['organizationWebsite'] as String?,
      organizationLogo: json['organizationLogo'] as String?,
      enableAutoGeneration: json['enableAutoGeneration'] as bool? ?? true,
      enableAutoSend: json['enableAutoSend'] as bool? ?? true,
      sendViaWhatsApp: json['sendViaWhatsApp'] as bool? ?? true,
      sendViaEmail: json['sendViaEmail'] as bool? ?? false,
      sendPdfWithInvoice: json['sendPdfWithInvoice'] as bool? ?? false,
      uploadToStorage: json['uploadToStorage'] as bool? ?? true,
      deleteAfterDays: json['deleteAfterDays'] as int? ?? 180,
      defaultFooterText:
          json['defaultFooterText'] as String? ?? 'شكراً لتعاملكم معنا',
    );
  }

  // معلومات الشركة
  final String organizationName;
  final String organizationPhone;
  final String organizationAddress;
  final String? organizationEmail;
  final String? organizationWebsite;
  final String? organizationLogo; // مسار الشعار

  // إعدادات التوليد التلقائي
  final bool enableAutoGeneration; // تفعيل توليد PDF تلقائياً
  final bool enableAutoSend; // تفعيل الإرسال التلقائي

  // إعدادات الإرسال
  final bool sendViaWhatsApp; // إرسال عبر واتساب
  final bool sendViaEmail; // إرسال عبر البريد الإلكتروني
  final bool sendPdfWithInvoice; // إرسال ملف PDF مع الفاتورة

  // إعدادات التخزين
  final bool uploadToStorage; // رفع إلى Firebase Storage
  final int deleteAfterDays; // حذف الملفات بعد عدد الأيام (0 = لا تحذف)

  // إعدادات افتراضية
  final String defaultFooterText; // نص التذييل الافتراضي

  PdfSettingsEntity copyWith({
    String? organizationName,
    String? organizationPhone,
    String? organizationAddress,
    String? organizationEmail,
    String? organizationWebsite,
    String? organizationLogo,
    bool? enableAutoGeneration,
    bool? enableAutoSend,
    bool? sendViaWhatsApp,
    bool? sendViaEmail,
    bool? sendPdfWithInvoice,
    bool? uploadToStorage,
    int? deleteAfterDays,
    String? defaultFooterText,
  }) {
    return PdfSettingsEntity(
      organizationName: organizationName ?? this.organizationName,
      organizationPhone: organizationPhone ?? this.organizationPhone,
      organizationAddress: organizationAddress ?? this.organizationAddress,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      organizationWebsite: organizationWebsite ?? this.organizationWebsite,
      organizationLogo: organizationLogo ?? this.organizationLogo,
      enableAutoGeneration: enableAutoGeneration ?? this.enableAutoGeneration,
      enableAutoSend: enableAutoSend ?? this.enableAutoSend,
      sendViaWhatsApp: sendViaWhatsApp ?? this.sendViaWhatsApp,
      sendViaEmail: sendViaEmail ?? this.sendViaEmail,
      sendPdfWithInvoice: sendPdfWithInvoice ?? this.sendPdfWithInvoice,
      uploadToStorage: uploadToStorage ?? this.uploadToStorage,
      deleteAfterDays: deleteAfterDays ?? this.deleteAfterDays,
      defaultFooterText: defaultFooterText ?? this.defaultFooterText,
    );
  }

  @override
  List<Object?> get props => [
    organizationName,
    organizationPhone,
    organizationAddress,
    organizationEmail,
    organizationWebsite,
    organizationLogo,
    enableAutoGeneration,
    enableAutoSend,
    sendViaWhatsApp,
    sendViaEmail,
    sendPdfWithInvoice,
    uploadToStorage,
    deleteAfterDays,
    defaultFooterText,
  ];

  Map<String, dynamic> toJson() {
    return {
      'organizationName': organizationName,
      'organizationPhone': organizationPhone,
      'organizationAddress': organizationAddress,
      'organizationEmail': organizationEmail,
      'organizationWebsite': organizationWebsite,
      'organizationLogo': organizationLogo,
      'enableAutoGeneration': enableAutoGeneration,
      'enableAutoSend': enableAutoSend,
      'sendViaWhatsApp': sendViaWhatsApp,
      'sendViaEmail': sendViaEmail,
      'sendPdfWithInvoice': sendPdfWithInvoice,
      'uploadToStorage': uploadToStorage,
      'deleteAfterDays': deleteAfterDays,
      'defaultFooterText': defaultFooterText,
    };
  }
}
