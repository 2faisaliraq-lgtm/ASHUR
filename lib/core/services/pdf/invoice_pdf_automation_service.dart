import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../features/invoices/domain/entities/invoice_entity.dart';
import '../../../features/invoices/domain/repositories/invoice_repository.dart';
import '../../../features/settings/domain/entities/pdf_settings_entity.dart';
import '../../utils/smart_number_formatter.dart';
import 'pdf_service.dart';
import 'pdf_settings_service.dart';
import '../whatsapp_service.dart';

/// وصف خدمة أتمتة فواتير PDF وإنشاء الرسائل
class InvoicePdfAutomationService {
  final PdfService _pdfService = PdfService();
  final PdfSettingsService _settingsService = PdfSettingsService();
  final InvoiceRepository _invoiceRepository =
      GetIt.instance<InvoiceRepository>();

  /// تنسيق المبلغ
  String _formatAmount(double amount) {
    return SmartNumberFormatter.format(amount);
  }

/// إنشاء وإرسال فاتورة PDF (إذا تم تمكين الإنشاء التلقائي)
///
/// يستخدم PdfSettingsService لجلب إعدادات الفاتورة
  Future<File?> generateAndSendInvoicePdf({
    required InvoiceEntity invoice,
    required String organizationEmail,
    bool sendToCustomer = true,
  }) async {
    try {
      // 1. جلب إعدادات الفاتورة
      final settings = await _settingsService.getSettings(organizationEmail);

      // 2. إذا كان الإنشاء التلقائي معطلاً، إرجاع null
      if (!settings.enableAutoGeneration) {
        return null;
      }

      // 3. إذا كانت الفاتورة نقدية، لا تنشئ PDF (فقط أرسل رسالة نصية إذا لزم الأمر)
      if (invoice.type == 'cash') {
        if (sendToCustomer &&
            settings.enableAutoSend &&
            invoice.customerPhone.isNotEmpty) {
          await _sendTextMessageOnly(invoice, settings);
        }
        return null; // لا يوجد PDF للفاتورة النقدية
      }

      // 4. جلب القالب حسب نوع الفاتورة
      final templateResult = await _invoiceRepository.getTemplateByType(
        organizationEmail,
        invoice.type,
      );

      return await templateResult.fold(
        (failure) async {
          return null;
        },
        (template) async {
          // 5. تحميل الشعار
          Uint8List? logoBytes;
          if (template.showLogo) {
            logoBytes = await _loadLogo(settings.organizationLogo);
          }

          // 6. إنشاء فاتورة PDF باستخدام بيانات المؤسسة
          final pdfFile = await _pdfService.generateInvoicePdf(
            invoice: invoice,
            template: template,
            organizationName: settings.organizationName,
            organizationPhone: settings.organizationPhone,
            organizationAddress: settings.organizationAddress,
            logoBytes: logoBytes,
          );

          // 7. إرسال PDF إلى العميل (إذا تم تمكين الإرسال التلقائي)
          if (sendToCustomer &&
              settings.enableAutoSend &&
              invoice.customerPhone.isNotEmpty) {
            await _sendPdfToCustomer(
              invoice: invoice,
              pdfFile: pdfFile,
              settings: settings,
            );
          }

          return pdfFile;
        },
      );
    } on Exception {
      return null;
    }
  }

  /// تحميل شعار المؤسسة
  Future<Uint8List?> _loadLogo(String? logoPath) async {
    try {
      if (logoPath != null && logoPath.isNotEmpty) {
        // محاولة تحميل الشعار من المسار المحدد
        final data = await rootBundle.load(logoPath);
        return data.buffer.asUint8List();
      }

        // تحميل الشعار الافتراضي من الأصول
      final data = await rootBundle.load('assets/images/lamassu2.png');
      return data.buffer.asUint8List();
    } on Exception catch (_) {
        // فشل في تحميل الشعار، إرجاع null
      return null;
    }
  }

  /// إرسال فاتورة PDF إلى العميل
  Future<void> _sendPdfToCustomer({
    required InvoiceEntity invoice,
    required File pdfFile,
    required PdfSettingsEntity settings,
  }) async {
    try {
      // إرسال عبر واتساب (إذا تم تمكين الإرسال)
      if (settings.sendViaWhatsApp) {
        await _sendViaWhatsApp(invoice, pdfFile, settings);
      }

      // إرسال عبر البريد الإلكتروني (إذا تم تمكين الإرسال)
      if (settings.sendViaEmail) {
        await _sendViaEmail(invoice, pdfFile, settings);
      }
    } on Exception catch (_) {
      // فشل في إرسال PDF
    }
  }

  /// إرسال عبر البريد الإلكتروني (طريقة احتياطية)
  Future<void> _sendViaEmail(
    InvoiceEntity invoice,
    File pdfFile,
    PdfSettingsEntity settings,
  ) async {
    // إرسال عبر البريد الإلكتروني (طريقة احتياطية)
  }

  /// إرسال عبر واتساب
  Future<void> _sendViaWhatsApp(
    InvoiceEntity invoice,
    File pdfFile,
    PdfSettingsEntity settings,
  ) async {
    try {
      // إنشاء رسالة واتساب بناءً على نوع الفاتورة
      final message = invoice.type == 'subscription'
          ? _createSubscriptionMessageFromInvoice(
              invoice: invoice,
              organizationName: settings.organizationName,
            )
          : _createInvoiceWhatsAppMessage(
              invoice: invoice,
              organizationName: settings.organizationName,
            );

      // إرسال PDF مع الفاتورة (إذا تم تمكين الإرسال)
      if (settings.sendPdfWithInvoice) {
        // مشاركة فاتورة PDF عبر واتساب
        await _shareInvoiceViaWhatsApp(
          pdfFile: pdfFile,
          message: message,
          customerPhone: invoice.customerPhone,
        );
      } else {
        // إرسال رسالة نصية فقط (بدون PDF)
        final success = await WhatsAppService.sendMessage(
          phoneNumber: invoice.customerPhone,
          message: message,
        );
      }

      // رفع PDF إلى Firebase Storage (إذا تم تمكين الرفع)
      if (settings.uploadToStorage) {
        await _uploadPdfToStorage(pdfFile, invoice);
      }
      } on Exception catch (_) {
        // فشل في إرسال عبر واتساب
      }
    }

    /// إرسال الفاتورة وزر QR للمستند (إذا تم تمكين الرفع)
  Future<void> _sendTextMessageOnly(
    InvoiceEntity invoice,
    PdfSettingsEntity settings,
  ) async {
    try {
      // إرسال رسالة نصية فقط (إذا كان الإرسال عبر واتساب مفعلاً)
      if (!settings.sendViaWhatsApp) {
        return; // إذا كان الإرسال عبر واتساب غير مفعل
      }

      // إنشاء رسالة إيصال نقدي
      final message = _createCashReceiptMessage(
        invoice: invoice,
        organizationName: settings.organizationName,
      );

      // إرسال رسالة نصية عبر واتساب
    } on Exception catch (_) {
      // فشل في إرسال رسالة إيصال نقدي
      }
    }

    /// مشاركة فاتورة PDF عبر واتساب (طريقة احتياطية)
  Future<void> _shareInvoiceViaWhatsApp({
    required File pdfFile,
    required String message,
    required String customerPhone,
  }) async {
    try {
      // مشاركة ملف PDF ورسالة عبر واتساب
      await WhatsAppService.sendFileWithMessage(
        file: pdfFile,
        message: message,
        phoneNumber: customerPhone,
      );
      } on Exception catch (_) {
        // فشل في مشاركة PDF، إرسال رسالة نصية فقط
        await WhatsAppService.sendMessage(
          phoneNumber: customerPhone,
          message: message,
        );
      }
    }

    /// رفع PDF إلى Firebase Storage
  Future<String?> _uploadPdfToStorage(
    File pdfFile,
    InvoiceEntity invoice,
  ) async {
    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${invoice.invoiceNumber}_$timestamp.pdf';
      final path = 'invoices/${invoice.organizationEmail}/$fileName';

      // رفع ملف PDF
      final ref = storage.ref().child(path);
      await ref.putFile(pdfFile);

      // جلب رابط التحميل المباشر للملف المرفوع
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } on Exception catch (_) {
      return null;
    }
  }

  /// إنشاء رسالة واتساب للفاتورة (مع تفاصيل الرصيد)
  String _createInvoiceWhatsAppMessage({
    required InvoiceEntity invoice,
    required String organizationName,
  }) {
    final invoiceTypeName = _getInvoiceTypeName(invoice.type);

    // تحديد ما إذا كانت الفاتورة محدثة
    final isUpdated =
        invoice.updatedBy != null &&
        invoice.updatedBy!.isNotEmpty &&
        invoice.updatedBy != invoice.createdBy;

    // معلومات تغيير الرصيد
    var balanceInfo = '';
    if (invoice.balanceBeforeInvoice != null &&
        invoice.balanceAfterInvoice != null) {
      final balanceChange =
          invoice.balanceAfterInvoice! - invoice.balanceBeforeInvoice!;
      final changeSymbol = balanceChange > 0 ? '+' : '';
      final changeText = balanceChange > 0
          ? 'زيادة'
          : balanceChange < 0
          ? 'انخفاض'
          : 'بدون تغيير';

      final previousBalanceLabel = invoice.balanceBeforeInvoice! > 0
          ? 'الرصيد السابق (دائن):'
          : invoice.balanceBeforeInvoice! < 0
          ? 'الرصيد السابق (مدين):'
          : 'الرصيد السابق:';

      final currentBalanceLabel = invoice.balanceAfterInvoice! > 0
          ? 'الرصيد الحالي (دائن):'
          : invoice.balanceAfterInvoice! < 0
          ? 'الرصيد الحالي (مدين):'
          : 'الرصيد الحالي:';

      balanceInfo =
          '''
────────────────────
          ملخص الرصيد
────────────────────

$previousBalanceLabel ${_formatAmount(invoice.balanceBeforeInvoice!.abs())} ج.م
$currentBalanceLabel ${_formatAmount(invoice.balanceAfterInvoice!.abs())} ج.م
التغيير: $changeSymbol${_formatAmount(balanceChange.abs())} ج.م ($changeText)
''';
    }

    // عناصر الفاتورة
    var itemsInfo = '';
    if (invoice.items.isNotEmpty) {
      itemsInfo =
          '''
────────────────────
             عناصر الفاتورة
────────────────────

${invoice.items.map((item) => '• ${item.productName} - ${_formatAmount(item.totalPrice)} ج.م').join('\n')}
''';
    }

    // ملاحظات التحديث
    var updateAlert = '';
    String? updateDate;
    if (isUpdated) {
      updateDate = _formatDateTime(invoice.updatedAt);
      updateAlert = '''
📢 تحديث: تم تعديل الفاتورة 📢


⚠️ تم تحديث الرصيد ليشمل العناصر المضافة أو المحذوفة
وتم تعديل الرصيد الحالي للفاتورة
المبلغ الصافي بعد التعديلات

''';
    }

    // ملاحظات التحديث
    var updateNote = '';
    if (isUpdated) {
      updateNote = '''

ملاحظات التحديث
✅ تم تعديل الرصيد الحالي للفاتورة
✅ تم تحديث الرصيد ليشمل التغييرات
✅ تم تعديل المصروفات والضريبة
   الإجمالي بعد التعديلات

''';
    }

    return '''
━━━━━━━━━━━━━━━━━━━━
        $organizationName
━━━━━━━━━━━━━━━━━━━━

الفاتورة الصادرة ${invoice.customerName}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}
$updateAlert────────────────────
          نوع الفاتورة $invoiceTypeName
────────────────────

رقم الفاتورة $invoiceTypeName: ${invoice.invoiceNumber}${isUpdated ? ' (مُحدَّثة)' : ''}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}${isUpdated ? '\nتاريخ التحديث: $updateDate' : ''}
المبلغ الإجمالي: ${_formatAmount(invoice.totalAmount)} ج.م
المبلغ المدفوع: ${_formatAmount(invoice.paidAmount.abs())} ج.م
المبلغ المتبقي: ${_formatAmount(invoice.calculateRemainingAmount())} ج.م
$itemsInfo
$balanceInfo$updateNote━━━━━━━━━━━━━━━━━━━━
''';
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getInvoiceTypeName(String type) {
    switch (type) {
      case 'sales':
        return 'فاتورة مبيعات';
      case 'purchase':
        return 'فاتورة شراء';
      case 'subscription':
        return 'فاتورة اشتراك';
      case 'maintenance':
        return 'فاتورة صيانة';
      case 'rental':
        return 'فاتورة إيجار';
      case 'cash':
        return 'إيصال نقدي';
      default:
        return 'فاتورة';
    }
  }

  /// إنشاء رسالة إيصال نقدي (بدون PDF)
  String _createCashReceiptMessage({
    required InvoiceEntity invoice,
    required String organizationName,
  }) {
    // تحديد نوع المعاملة النقدية بناءً على نوع المعاملة الفعلي
    final transactionType = invoice.effectiveCashTransactionType;
    final isAccountClearance = transactionType == 'clearance';
    final isPayment = transactionType == 'payment';
    final isReceipt = transactionType == 'receipt';

    // الرصيد والتغيير
    var balanceInfo = '';
    if (invoice.balanceBeforeInvoice != null &&
        invoice.balanceAfterInvoice != null) {
      final balanceChange =
          invoice.balanceAfterInvoice! - invoice.balanceBeforeInvoice!;
      final changeSymbol = balanceChange > 0 ? '+' : '';
      final changeText = balanceChange > 0
          ? 'زيادة'
          : balanceChange < 0
          ? 'انخفاض'
          : 'بدون تغيير';

      final previousBalanceLabel = invoice.balanceBeforeInvoice! > 0
          ? 'الرصيد السابق (دائن):'
          : invoice.balanceBeforeInvoice! < 0
          ? 'الرصيد السابق (مدين):'
          : 'الرصيد السابق:';

      final currentBalanceLabel = invoice.balanceAfterInvoice! > 0
          ? 'الرصيد الحالي (دائن):'
          : invoice.balanceAfterInvoice! < 0
          ? 'الرصيد الحالي (مدين):'
          : 'الرصيد الحالي:';

      balanceInfo =
          '''
────────────────────
          ملخص الرصيد
────────────────────
$previousBalanceLabel ${_formatAmount(invoice.balanceBeforeInvoice!.abs())} ج.م
$currentBalanceLabel ${_formatAmount(invoice.balanceAfterInvoice!.abs())} ج.م
التغيير: $changeSymbol${_formatAmount(balanceChange.abs())} ج.م ($changeText)
''';
    }

    if (isAccountClearance) {
      return '''
━━━━━━━━━━━━━━━━━━━━
        $organizationName
━━━━━━━━━━━━━━━━━━━━
الفاتورة الصادرة ${invoice.customerName}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}
────────────────────
        تسوية الرصيد
────────────────────
✅ تم تسوية الرصيد ويتم التعديل
رقم الفاتورة: ${invoice.invoiceNumber}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}
المبلغ الإجمالي: ${_formatAmount(invoice.totalAmount)} ج.م
الرصيد المدفوع: 0 ج.م
────────────────────
          ملاحظات التحديث
────────────────────
🎉 تم تسوية الرصيد ويتم التعديل وفقا لخصم الفاتورة
━━━━━━━━━━━━━━━━━━━━
''';
    } else if (isPayment) {
      return '''
━━━━━━━━━━━━━━━━━━━━
        $organizationName
━━━━━━━━━━━━━━━━━━━━
الفاتورة الصادرة ${invoice.customerName}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}
────────────────────
          إيصال نقدي
────────────────────

رقم الفاتورة الأصلية: دفعة مالية
رقم الفاتورة: ${invoice.invoiceNumber}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}
المبلغ الإجمالي: ${_formatAmount(invoice.totalAmount)} ج.م
$balanceInfo
━━━━━━━━━━━━━━━━━━━━
''';
    } else if (isReceipt) {
      return '''
━━━━━━━━━━━━━━━━━━━━
        $organizationName
━━━━━━━━━━━━━━━━━━━━
الفاتورة الصادرة ${invoice.customerName}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}
────────────────────
          إيصال استلام مبلغ
────────────────────
✅ تم استلام المبلغ بنجاح
رقم الفاتورة: ${invoice.invoiceNumber}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}
المبلغ الإجمالي: ${_formatAmount(invoice.totalAmount)} ج.م
$balanceInfo
━━━━━━━━━━━━━━━━━━━━
''';
    }

    // إرجاع رسالة الإيصال النقدي الافتراضية
    return '''
━━━━━━━━━━━━━━━━━━━━
        $organizationName
━━━━━━━━━━━━━━━━━━━━
الفاتورة الصادرة ${invoice.customerName}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}
────────────────────
          إيصال نقدي
────────────────────
رقم الفاتورة: ${invoice.invoiceNumber}
تاريخ الفاتورة: ${_formatDate(invoice.invoiceDate)}
المبلغ الإجمالي: ${_formatAmount(invoice.totalAmount)} ج.م
$balanceInfo
━━━━━━━━━━━━━━━━━━━━
''';
  }

  /// إنشاء رسالة إيصال نقدي (بدون PDF)
  String _createSubscriptionMessageFromInvoice({
    required InvoiceEntity invoice,
    required String organizationName,
  }) {
    // تحليل ملاحظات الاشتراك من الفاتورة
    String subscriptionName = 'اشتراك';
    String subscriptionType = '';
    String duration = '';
    DateTime? startDate;
    DateTime? endDate;
    List<String> features = [];

    if (invoice.notes != null && invoice.notes!.isNotEmpty) {
      // تحليل ملاحظات الاشتراك من الفاتورة:
      // مثال على التنسيق: "اسم الاشتراك اشتراك 월 [اسم]\nتاريخ البدء: [تاريخ]\nالمدة: [المدة]\n\nالميزات:\n• ميزة 1\n• ميزة 2"

      // جلب اسم الاشتراك من الملاحظات
      final nameMatch = RegExp(
        r'اسم الاشتراك اشتراك (.+?)\n',
      ).firstMatch(invoice.notes!);
      if (nameMatch != null) {
        subscriptionName = nameMatch.group(1)!;
      }

      // جلب نوع الاشتراك من الملاحظات
      final typeMatch = RegExp(r'\nنوع الاشتراك: (.+?)\n').firstMatch(invoice.notes!);
      if (typeMatch != null) {
        subscriptionType = typeMatch.group(1)!;
      }

      // جلب مدة الاشتراك من الملاحظات
      final durationMatch = RegExp(
        r'المدة: (.+?)\n',
      ).firstMatch(invoice.notes!);
      if (durationMatch != null) {
        duration = durationMatch.group(1)!;
      }

      // جلب تاريخ البدء والانتهاء من الملاحظات
      final datesMatch = RegExp(
        r'تاريخ البدء (\d{4}-\d{2}-\d{2})(?: (\d{2}):(\d{2}))? إلى (\d{4}-\d{2}-\d{2})(?: (\d{2}):(\d{2}))?',
      ).firstMatch(invoice.notes!);
      if (datesMatch != null) {
        try {
          final startDateParts = datesMatch.group(1)!.split('-');
          final endDateParts = datesMatch.group(4)!.split('-');

          if (startDateParts.length == 3 && endDateParts.length == 3) {
            startDate = DateTime(
              int.parse(startDateParts[0]),
              int.parse(startDateParts[1]),
              int.parse(startDateParts[2]),
              int.tryParse(datesMatch.group(2) ?? '') ?? 0,
              int.tryParse(datesMatch.group(3) ?? '') ?? 0,
            );
            endDate = DateTime(
              int.parse(endDateParts[0]),
              int.parse(endDateParts[1]),
              int.parse(endDateParts[2]),
              int.tryParse(datesMatch.group(5) ?? '') ?? 0,
              int.tryParse(datesMatch.group(6) ?? '') ?? 0,
            );
          }
        } on Exception catch (_) {
          // إذا فشل تحليل التاريخ، استخدم تاريخ الفاتورة
          startDate = invoice.invoiceDate;
          endDate = invoice.invoiceDate;
        }
      }

      // جلب ميزات الاشتراك من الملاحظات
      // مثال على التنسيق: "الميزات:\n• ميزة 1\n• ميزة 2\n... (انتهت الميزات عندما يظهر "السعر الأساسي:" أو "الضريبة:")"
      final featuresMatch = RegExp(
        r'الميزات:\n([\s\S]+?)(?=\nالسعر الأساسي:|\nالضريبة:|$)',
      ).firstMatch(invoice.notes!);
      if (featuresMatch != null) {
        final featuresText = featuresMatch.group(1)!;
        // استخراج ميزات الاشتراك من النص المنفصل بأسطر جديدة
        features = featuresText
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => line.replaceFirst(RegExp(r'^\s*•\s*'), '').trim())
            .toList();
      }
    }

    // حساب السعر الأساسي (الإجمالي + الخصم - الضريبة)
    final basePrice =
        invoice.totalAmount + invoice.discountAmount - invoice.taxAmount;

    // تحديد ما إذا كانت الفاتورة محدثة (تم تعديلها بعد الإنشاء)
    final isUpdated =
        invoice.updatedBy != null &&
        invoice.updatedBy!.isNotEmpty &&
        invoice.updatedBy != invoice.createdBy;

    // إنشاء رسالة اشتراك عبر خدمة واتساب
    return WhatsAppService.createSubscriptionFromInvoiceMessage(
      customerName: invoice.customerName,
      subscriptionName: subscriptionName,
      subscriptionType: subscriptionType,
      duration: duration,
      startDate: startDate ?? invoice.invoiceDate,
      endDate: endDate ?? invoice.invoiceDate,
      basePrice: basePrice,
      finalPrice: invoice.totalAmount,
      invoiceNumber: invoice.invoiceNumber,
      organizationName: organizationName,
      balanceBeforeInvoice: invoice.balanceBeforeInvoice,
      balanceAfterInvoice: invoice.balanceAfterInvoice,
      discountAmount: invoice.discountAmount,
      taxAmount: invoice.taxAmount,
      taxes: invoice.taxes,
      features: features.isNotEmpty ? features : null,
      isUpdated: isUpdated,
      updatedAt: isUpdated ? invoice.updatedAt : null,
    );
  }
}
