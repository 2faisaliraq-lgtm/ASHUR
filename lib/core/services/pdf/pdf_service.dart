import 'dart:io';

import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

// import 'package:printing/printing.dart'; // Removed due to Gradle build failures

import '../../../features/invoices/domain/entities/invoice_entity.dart';
import '../../../features/invoices/domain/entities/invoice_template_entity.dart';
import '../formatting_service.dart';

class PdfService {
  final FormattingService _formattingService = FormattingService();

  /// تشكيل النص العربي لعرض صحيح في ملفات PDF
  String _ar(String text) {
    try {
      return ArabicReshaper.instance.reshape(text);
    } on Exception {
      return text;
    }
  }

  /// إنشاء فاتورة PDF
  Future<File> generateInvoicePdf({
    required InvoiceEntity invoice,
    required InvoiceTemplateEntity template,
    required String organizationName,
    required String organizationPhone,
    required String organizationAddress,
    Uint8List? logoBytes,
  }) async {
    // تهيئة خدمة التنسيق
    await _formattingService.initialize();

    final pdf = pw.Document();

    // تحميل الخط العربي
    final arabicFont = await _loadArabicFont();
    final arabicFontBold = await _loadArabicFontBold();

    // تحويل الألوان من hex
    final headerColor = _hexToColor(template.headerColor);
    final accentColor = _hexToColor(template.accentColor);

    // قراءة جميع القياسات من القالب فقط - بدون قيم افتراضية
    final titleFontSize =
        template.customFields?['titleFontSizeValue'] as double? ?? 18.0;
    final subtitleFontSize =
        template.customFields?['subtitleFontSizeValue'] as double? ?? 14.0;
    final headerFontSize =
        template.customFields?['headerFontSizeValue'] as double? ?? 12.0;
    final bodyFontSize =
        template.customFields?['bodyFontSizeValue'] as double? ?? 11.0;
    final footerFontSize =
        template.customFields?['footerFontSizeValue'] as double? ?? 8.0;
    final marginTop =
        template.customFields?['pageMarginTopMM'] as double? ?? 0.0;
    final marginBottom =
        template.customFields?['pageMarginBottomMM'] as double? ?? 0.0;
    final marginLeft =
        template.customFields?['pageMarginLeftMM'] as double? ?? 0.0;
    final marginRight =
        template.customFields?['pageMarginRightMM'] as double? ?? 0.0;

    // إنشاء صفحة الفاتورة بقياسات A4 القياسية (210mm × 297mm)
    // استخدام MultiPage لدعم المحتوى الذي يمتد لعدة صفحات
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // 210mm × 297mm
        margin: pw.EdgeInsets.fromLTRB(
          marginLeft * PdfPageFormat.mm, // تحويل mm إلى points
          marginTop * PdfPageFormat.mm,
          marginRight * PdfPageFormat.mm,
          marginBottom * PdfPageFormat.mm,
        ),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),

        // الهيدر (يتكرر في كل صفحة)
        header: (context) => _buildHeader(
          template: template,
          invoice: invoice,
          organizationName: organizationName,
          organizationPhone: organizationPhone,
          organizationAddress: organizationAddress,
          headerColor: headerColor,
          accentColor: accentColor,
          logoBytes: logoBytes,
          titleFontSize: titleFontSize,
          bodyFontSize: bodyFontSize,
        ),

        // التذييل (يتكرر في كل صفحة)
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 0.0 * PdfPageFormat.cm),
          child: pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: pw.TextStyle(
              color: PdfColors.grey,
              fontSize: footerFontSize,
            ),
          ),
        ),

        // بناء محتوى الصفحات
        build: (context) => <pw.Widget>[
          // مسافة علوية لفصل المحتوى عن الهيدر (الشعار ومعلومات الشركة)
          pw.SizedBox(height: 70),

          // معلومات العميل
          if (template.showCustomerInfo)
            _buildCustomerInfo(
              invoice,
              accentColor,
              subtitleFontSize,
              bodyFontSize,
            ),
          pw.SizedBox(height: 15),

          // جدول الأصناف (سيمتد عبر الصفحات)
          if (template.showItemsTable)
            _buildItemsTable(
              invoice,
              template,
              headerColor,
              accentColor,
              headerFontSize,
              bodyFontSize,
            ),

          pw.SizedBox(height: 15),

          // تنظيم الإجماليات والملاحظات في صف واحد
          pw.Row(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start, // محاذاة العناصر للأعلى
            children: [
              // الملاحظات (على اليمين في سياق RTL)
              if (template.showNotes && invoice.notes != null)
                pw.Expanded(
                  flex: 3, // يمكن تعديل النسبة حسب الحاجة
                  child: _buildNotes(
                    invoice.notes!,
                    accentColor,
                    subtitleFontSize,
                    bodyFontSize,
                  ),
                ),
              if (template.showNotes && invoice.notes != null)
                pw.SizedBox(width: 15), // فاصل بين الملاحظات والإجماليات
              // الإجماليات (على اليسار في سياق RTL)
              pw.Expanded(
                flex: 2, // يمكن تعديل النسبة حسب الحاجة
                child: _buildTotals(
                  invoice,
                  template,
                  headerColor,
                  accentColor,
                  bodyFontSize,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),

          // التذييل النهائي
          _buildFooter(template, accentColor, footerFontSize),
          // مسافة سفلية لفصل المحتوى عن التذييل (footer)
          pw.SizedBox(height: 60),
        ],
      ),
    );

    // حفظ الملف
    return _savePdfFile(pdf, invoice.invoiceNumber);
  }

  /// تحميل الخط العربي (Amiri)
  Future<pw.Font> _loadArabicFont() async {
    // استخدام خط أميري من الأصول لدعم الحروف العربية المشكّلة
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/Amiri-Regular.ttf',
      );
      return pw.Font.ttf(fontData);
    } on Exception catch (_) {
      // استخدام خط بديل يدعم العربية قدر الإمكان
      return pw.Font.helvetica();
    }
  }

  /// تحميل الخط العربي العريض (Amiri Bold)
  Future<pw.Font> _loadArabicFontBold() async {
    // استخدام خط أميري العريض من الأصول
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/Amiri-Bold.ttf',
      );
      return pw.Font.ttf(fontData);
    } on Exception catch (_) {
      return _loadArabicFont();
    }
  }

  /// تحويل hex color إلى PdfColor
  PdfColor _hexToColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    return PdfColor(r / 255, g / 255, b / 255);
  }

  /// بناء الهيدر
  pw.Widget _buildHeader({
    required InvoiceTemplateEntity template,
    required InvoiceEntity invoice,
    required String organizationName,
    required String organizationPhone,
    required String organizationAddress,
    required PdfColor headerColor,
    required PdfColor accentColor,
    Uint8List? logoBytes,
    required double titleFontSize,
    required double bodyFontSize,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10), // تقليل الارتفاع
      decoration: pw.BoxDecoration(
        color: headerColor,
        borderRadius: pw.BorderRadius.circular(0), // زوايا حادة
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center, // توسيط العناصر
        children: [
          // معلومات الشركة
          if (template.showCompanyInfo)
            pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                  pw.Text(
                    _ar(organizationName),
                    style: pw.TextStyle(
                      fontSize: titleFontSize + 2,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _ar(organizationPhone),
                    style: pw.TextStyle(
                      fontSize: bodyFontSize,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _ar(organizationAddress),
                    style: pw.TextStyle(
                      fontSize: bodyFontSize,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),

          // الشعار في المنتصف
          if (template.showLogo && logoBytes != null)
            pw.Container(
              width: template.customFields?['logoWidth'] ?? 80.0,
              height: template.customFields?['logoHeight'] ?? 80.0,
              alignment: pw.Alignment.center,
              child: pw.Image(
                pw.MemoryImage(logoBytes),
                fit: pw.BoxFit.contain,
              ),
            ),

          // معلومات الفاتورة
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                 pw.Text(
                    _ar('نوع الفاتورة: ${_getInvoiceTypeName(invoice.type)}'),
                   style: pw.TextStyle(
                     fontSize: titleFontSize,
                     fontWeight: pw.FontWeight.bold,
                     color: PdfColors.white,
                   ),
                 ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                     _ar('رقم الفاتورة: ${invoice.invoiceNumber}'),
                    style: pw.TextStyle(
                      fontSize: bodyFontSize - 1,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                     _ar('التاريخ: ${_formatDate(invoice.invoiceDate)}'),
                    style: pw.TextStyle(
                      fontSize: bodyFontSize - 1,
                      color: PdfColors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء معلومات العميل
  pw.Widget _buildCustomerInfo(
    InvoiceEntity invoice,
    PdfColor accentColor,
    double titleFontSize,
    double bodyFontSize,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: accentColor, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // معلومات العميل (العنوان على اليمين، التفاصيل على اليسار)
          pw.Expanded(
            flex: 1,
              child: pw.Text(
                _ar('معلومات العميل'),
                style: pw.TextStyle(
                fontSize: titleFontSize,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
          pw.SizedBox(width: 15),
          // تفاصيل العميل (الاسم، الرصيد، الهاتف)
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _ar('الاسم: ${invoice.customerName}'),
                  style: pw.TextStyle(fontSize: bodyFontSize),
                ),
                if (invoice.balanceBeforeInvoice != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    invoice.balanceBeforeInvoice! > 0
                        ? _ar('الرصيد قبل الفاتورة (مدين): ${_formatAmount(invoice.balanceBeforeInvoice!)}')
                        : invoice.balanceBeforeInvoice! < 0
                        ? _ar('الرصيد قبل الفاتورة (دائن): ${_formatAmount(invoice.balanceBeforeInvoice!.abs())}')
                        : _ar('الرصيد قبل الفاتورة: ${_formatAmount(invoice.balanceBeforeInvoice!)}'),
                    style: pw.TextStyle(fontSize: bodyFontSize),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 15),
          // رقم هاتف العميل
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _ar('الهاتف: ${invoice.customerPhone}'),
                  style: pw.TextStyle(fontSize: bodyFontSize),
                ),
                // يمكن إضافة معلومات إضافية هنا في المستقبل
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء جدول الأصناف
  pw.Widget _buildItemsTable(
    InvoiceEntity invoice,
    InvoiceTemplateEntity template,
    PdfColor headerColor,
    PdfColor accentColor,
    double headerFontSize,
    double bodyFontSize,
  ) {
    // قراءة هوامش الجدول من القالب
    final tableMarginTop =
        template.customFields?['tableMarginTopMM'] as double? ?? 0.0;
    final tableMarginBottom =
        template.customFields?['tableMarginBottomMM'] as double? ?? 0.0;
    final tableCellPadding =
        template.customFields?['tableCellPadding'] as double? ?? 6.0;

    // تحديد تأثير الدين بناءً على نوع الفاتورة
    // فواتير مرجع البيع تقلل الدين (أخضر)، الفواتير العادية تزيد الدين (أحمر)
    // الفواتير النقدية: استلام يقلل الدين (أخضر)، إعطاء يزيد الدين (أحمر)
    final bool isSalesReturn = invoice.type == 'sales_return' ||
        invoice.isSalesReturn;
    final bool isCashReceipt = invoice.type == 'cash' &&
        invoice.isCashAccountReceipt &&
        invoice.effectiveCashTransactionType == 'receipt';
    final bool isCashPayment = invoice.type == 'cash' &&
        invoice.isCashAccountReceipt &&
        invoice.effectiveCashTransactionType == 'payment';
    final String debtEffect =
        isSalesReturn || isCashReceipt ? 'decrease' : 'increase';

    return pw.Padding(
      // تم إزالة الهوامش الأفقية الإضافية من هنا
      padding: pw.EdgeInsets.only(
        top: tableMarginTop * PdfPageFormat.mm,
        bottom: tableMarginBottom * PdfPageFormat.mm,
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: accentColor, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.0), // المجموع (اليمين في RTL)
          1: const pw.FlexColumnWidth(1.0), // السعر
          2: const pw.FlexColumnWidth(0.5), // الكمية
          3: const pw.FlexColumnWidth(3.0), // الصنف
          4: const pw.FlexColumnWidth(0.5), // # (اليسار في RTL)
        },
        children: [
          // رأس الجدول
          pw.TableRow(
            decoration: pw.BoxDecoration(color: headerColor),
            children: [
              _buildTableCell(
                _ar('المجموع'),
                isHeader: true,
                fontSize: headerFontSize,
                padding: tableCellPadding,
                backgroundColor: headerColor,
              ),
              _buildTableCell(
                _ar('السعر'),
                isHeader: true,
                fontSize: headerFontSize,
                padding: tableCellPadding,
                backgroundColor: headerColor,
              ),
              _buildTableCell(
                _ar('الكمية'),
                isHeader: true,
                fontSize: headerFontSize,
                padding: tableCellPadding,
                backgroundColor: headerColor,
              ),
              _buildTableCell(
                _ar('الصنف'),
                isHeader: true,
                fontSize: headerFontSize,
                padding: tableCellPadding,
                backgroundColor: headerColor,
              ),
              _buildTableCell(
                _ar('#'),
                isHeader: true,
                fontSize: headerFontSize,
                padding: tableCellPadding,
                backgroundColor: headerColor,
                fontColor: PdfColors.white,
              ),
            ],
          ),
          // صفوف البيانات
          ...invoice.items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: index.isEven ? PdfColors.grey100 : PdfColors.white,
              ),
              children: [
                _buildTableCell(
                  _formatAmount(item.totalPrice),
                  fontSize: bodyFontSize,
                  padding: tableCellPadding,
                  debtEffect: debtEffect,
                ),
                _buildTableCell(
                  _formatAmount(item.unitPrice),
                  fontSize: bodyFontSize,
                  padding: tableCellPadding,
                  debtEffect: debtEffect,
                ),
                _buildTableCell(
                  _formatNumber(item.quantity),
                  fontSize: bodyFontSize,
                  padding: tableCellPadding,
                ),
                _buildTableCell(
                  _ar(item.productName),
                  fontSize: bodyFontSize,
                  padding: tableCellPadding,
                ),
                _buildTableCell(
                  index.toString(),
                  fontSize: bodyFontSize,
                  padding: tableCellPadding,
                  backgroundColor: PdfColors.grey100,
                  fontColor: PdfColors.grey800,
                  fontWeight: pw.FontWeight.bold,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// بناء خلية جدول مع تلوين حسب تأثير الدين
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    double fontSize = 10,
    double padding = 6,
    PdfColor? backgroundColor,
    PdfColor? fontColor,
    pw.FontWeight? fontWeight,
    String? debtEffect,
  }) {
    PdfColor? effectiveBg = backgroundColor;
    if (debtEffect == 'increase' && effectiveBg == null) {
      effectiveBg = _hexToColor('#FFEBEE');
    } else if (debtEffect == 'decrease' && effectiveBg == null) {
      effectiveBg = _hexToColor('#E8F5E9');
    }
    return pw.Container(
      padding: pw.EdgeInsets.all(padding),
      color: effectiveBg,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight ?? (isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
          color: fontColor ?? (isHeader ? PdfColors.white : PdfColors.black),
        ),
      ),
    );
  }

  /// بناء صف الإجمالي مع تلوين خلفية المبلغ حسب تأثير الدين وإضافة إشارة (+/-)
  pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    PdfColor? color,
    double fontSize = 12,
    String prefix = '',
    String? debtEffect,
  }) {
    final dynamicBg = debtEffect == 'increase'
        ? _hexToColor('#FFEBEE')
        : debtEffect == 'decrease'
            ? _hexToColor('#E8F5E9')
            : null;
    // إضافة إشارة (+ أو -) أمام المبلغ بناءً على تأثير الدين
    String displayAmount;
    if (debtEffect == 'increase') {
      displayAmount = '+${_formatAmount(amount.abs())}';
    } else if (debtEffect == 'decrease') {
      displayAmount = '-${_formatAmount(amount.abs())}';
    } else {
      displayAmount = _formatAmount(amount);
    }
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          prefix + label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
        pw.Container(
          color: dynamicBg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(
            displayAmount,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// بناء صندوق الإجماليات
  pw.Widget _buildTotals(
    InvoiceEntity invoice,
    InvoiceTemplateEntity template,
    PdfColor headerColor,
    PdfColor accentColor,
    double bodyFontSize,
  ) {
    // تحديد تأثير الدين بناءً على نوع الفاتورة
    // فواتير مرجع البيع تقلل الدين (أخضر)، الفواتير العادية تزيد الدين (أحمر)
    // الفواتير النقدية: استلام يقلل الدين (أخضر)، إعطاء يزيد الدين (أحمر)
    final bool isSalesReturn = invoice.type == 'sales_return' ||
        invoice.isSalesReturn;
    final bool isCashReceipt = invoice.type == 'cash' &&
        invoice.isCashAccountReceipt &&
        invoice.effectiveCashTransactionType == 'receipt';
    final bool isCashPayment = invoice.type == 'cash' &&
        invoice.isCashAccountReceipt &&
        invoice.effectiveCashTransactionType == 'payment';
    final String itemDebtEffect =
        isSalesReturn || isCashReceipt ? 'decrease' : 'increase';

    final grandRemainingIfBalance =
        invoice.balanceBeforeInvoice != null
            ? invoice.calculateRemainingAmount() + invoice.balanceBeforeInvoice!.abs()
            : null;

    return pw.Container(
      width: 250, // تحديد عرض ثابت لصندوق الإجماليات
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          _buildTotalRow(
            'الإجمالي الفرعي:',
            invoice.totalAmount - invoice.discountAmount,
            fontSize: bodyFontSize,
            debtEffect: itemDebtEffect,
          ),
          // عرض الضرائب إذا كانت موجودة
          if (invoice.taxes != null && invoice.taxes!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            // عرض تفاصيل كل ضريبة
            ...invoice.taxes!.map((tax) {
              final taxName = tax['name'] as String;
              final taxRate = tax['rate'] as double;
              final taxAmountValue = tax['amount'] as double;
              final isPercentage = tax['isPercentage'] as bool;

              return _buildTotalRow(
                '• $taxName:',
                taxAmountValue,
                fontSize: bodyFontSize - 1,
                color: PdfColors.orange,
                prefix: isPercentage && taxRate > 0
                    ? '(${taxRate.toStringAsFixed(1)}%) '
                    : '',
                debtEffect: itemDebtEffect,
              );
            }),
            pw.SizedBox(height: 4),
            _buildTotalRow(
              'إجمالي الضرائب:',
              invoice.taxAmount,
              fontSize: bodyFontSize,
              color: PdfColors.orange,
              isBold: true,
              debtEffect: itemDebtEffect,
            ),
          ] else if (invoice.taxAmount > 0) ...[
            pw.SizedBox(height: 4),
            _buildTotalRow(
              'الضريبة:',
              invoice.taxAmount,
              fontSize: bodyFontSize,
              color: PdfColors.orange,
              debtEffect: itemDebtEffect,
            ),
          ],
          // عرض الخصم إذا كان موجوداً — الخصم يقلل الدين دائماً
          if (invoice.discountAmount > 0) ...[
            pw.SizedBox(height: 4),
            _buildTotalRow(
              'الخصم:',
              -invoice.discountAmount,
              fontSize: bodyFontSize,
              color: PdfColors.red,
              debtEffect: 'decrease',
            ),
          ],
          pw.SizedBox(height: 4),
          _buildTotalRow(
            'المدفوع:',
            invoice.paidAmount.abs(),
            fontSize: bodyFontSize,
            debtEffect: 'decrease',
          ),
          if (invoice.type == 'cash' && invoice.isCashAccountReceipt) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  _ar('نوع المعاملة:'),
                  style: pw.TextStyle(
                    fontSize: bodyFontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _ar(invoice.effectiveCashTransactionType == 'receipt'
                      ? 'استلام مبلغ من العميل'
                      : invoice.effectiveCashTransactionType == 'payment'
                          ? 'إعطاء مبلغ للعميل'
                          : 'تصفية الحساب'),
                  style: pw.TextStyle(
                    fontSize: bodyFontSize,
                  ),
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Divider(color: accentColor, thickness: 1.5),
          pw.SizedBox(height: 4),
          // المتبقي: إذا كان مديناً (أحمر)، إذا كان دائناً أو صفراً (أخضر)
          _buildTotalRow(
            'المتبقي:',
            invoice.calculateRemainingAmount(),
            isBold: true,
            fontSize: bodyFontSize + 1,
            color: accentColor,
            debtEffect:
                invoice.calculateRemainingAmount() > 0 ? 'increase' : 'decrease',
          ),
          // إضافة الحساب السابق إذا كان موجوداً
          if (invoice.balanceBeforeInvoice != null) ...[
            pw.SizedBox(height: 4),
            _buildTotalRow(
              invoice.balanceBeforeInvoice! > 0
                  ? 'الحساب السابق (عليك):'
                  : invoice.balanceBeforeInvoice! < 0
                      ? 'الحساب السابق (لك):'
                      : 'الحساب السابق:',
              invoice.balanceBeforeInvoice!.abs(),
              fontSize: bodyFontSize,
              color: accentColor,
              debtEffect:
                  invoice.balanceBeforeInvoice! > 0 ? 'increase' : 'decrease',
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: accentColor, thickness: 1.5),
            pw.SizedBox(height: 4),
            if (grandRemainingIfBalance != null)
              _buildTotalRow(
                'الحساب الإجمالي:',
                grandRemainingIfBalance,
              isBold: true,
              fontSize: bodyFontSize + 1,
              color: headerColor,
              debtEffect:
                  grandRemainingIfBalance > 0 ? 'increase' : 'decrease',
            ),
          ],
        ],
      ),
    );
  }

  /// بناء الملاحظات
  pw.Widget _buildNotes(
    String notes,
    PdfColor accentColor,
    double titleFontSize,
    double bodyFontSize,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: accentColor, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
                           pw.Text(
                             _ar('ملاحظات:'),
                             style: pw.TextStyle(
                               fontSize: titleFontSize,
                               fontWeight: pw.FontWeight.bold,
                               color: accentColor,
                             ),
                           ),
          pw.SizedBox(height: 4),
          pw.Text(_ar(notes), style: pw.TextStyle(fontSize: bodyFontSize)),
        ],
      ),
    );
  }

  /// بناء التذييل
  pw.Widget _buildFooter(
    InvoiceTemplateEntity template,
    PdfColor accentColor,
    double fontSize,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: accentColor, width: 2)),
      ),
      child: pw.Center(
          child: pw.Text(
            _ar(template.footerText),
            style: pw.TextStyle(fontSize: fontSize, color: accentColor),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  /// حفظ ملف PDF
  Future<File> _savePdfFile(pw.Document pdf, String invoiceNumber) async {
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/invoice_$invoiceNumber.pdf');
    return file.writeAsBytes(await pdf.save());
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  /// تنسيق المبلغ للعرض مع رمز العملة
  String _formatAmount(double amount) {
    return _formattingService.formatCurrency(amount);
  }

  /// تنسيق الأرقام (للكميات)
  String _formatNumber(double number) {
    return _formattingService.formatNumber(number);
  }

  /// الحصول على اسم نوع الفاتورة
  String _getInvoiceTypeName(String type) {
    switch (type) {
      case 'sales':
        return 'مبيعات';
      case 'purchase':
        return 'مشتريات';
      case 'subscription':
        return 'اشتراك';
      case 'maintenance':
        return 'صيانة';
      case 'rental':
        return 'إيجار';
      case 'cash':
        return 'نقدية';
      default:
        return 'أخرى';
    }
  }

  /// مشاركة PDF
  Future<void> sharePdf(File pdfFile) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfFile.path)],
          subject: 'فاتورة ${pdfFile.path.split('/').last}',
        ),
      );
    } on Exception {
      // Fallback: copy file to accessible location
      final output = await getApplicationDocumentsDirectory();
      final sharedFile = File(
        '${output.path}/shared_${pdfFile.path.split('/').last}',
      );
      await sharedFile.writeAsBytes(await pdfFile.readAsBytes());
    }
  }

  /// طباعة PDF - استخدام المشاركة كبديل
  Future<void> printPdf(File pdfFile) async {
    try {
      // استخدام Share.shareXFiles والذي يدعم الطباعة على بعض الأجهزة
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfFile.path)],
          subject: 'طباعة ${pdfFile.path.split('/').last}',
        ),
      );
    } on Exception {
      // Fallback: copy file to accessible location
      final output = await getApplicationDocumentsDirectory();
      final printedFile = File(
        '${output.path}/printed_${pdfFile.path.split('/').last}',
      );
      await printedFile.writeAsBytes(await pdfFile.readAsBytes());
    }
  }

  /// Generate a consolidated history PDF for multiple invoices using the original app template design.
  /// Page 1: summary sheet with totals.
  /// Following pages: per-invoice detail pages.
  Future<File> generateInvoicesHistoryPdf({
    required List<InvoiceEntity> invoices,
    required String organizationName,
    required String organizationPhone,
    required String organizationAddress,
    Uint8List? logoBytes,
    InvoiceTemplateEntity? template,
    String? customerName,
  }) async {
    await _formattingService.initialize();

    final pdf = pw.Document();

    final arabicFont = await _loadArabicFont();
    final arabicFontBold = await _loadArabicFontBold();

    final templateEntity =
        template ??
        InvoiceTemplateEntity(
          id: 'template_classic',
          name: 'القالب الكلاسيكي',
          type: 'general',
          headerColor: '#1B365D',
          accentColor: '#D4AF37',
          showLogo: true,
          logoPosition: 'right',
          showCompanyInfo: true,
          showCustomerInfo: true,
          showItemsTable: true,
          showNotes: true,
          showSignature: false,
          footerText: 'شكراً لتعاملكم معنا',
          isDefault: true,
          customFields: {
            'pageMarginTopMM': 0.0,
            'pageMarginBottomMM': 0.0,
            'pageMarginLeftMM': 0.0,
            'pageMarginRightMM': 0.0,
            'titleFontSizeValue': 18.0,
            'subtitleFontSizeValue': 14.0,
            'headerFontSizeValue': 12.0,
            'bodyFontSizeValue': 11.0,
            'footerFontSizeValue': 8.0,
            'tableCellPadding': 6.0,
            'logoWidth': 120.0,
            'logoHeight': 120.0,
            'headerPadding': 20.0,
            'headerBorderRadius': 0.0,
            'companyNameFontSize': 24.0,
            'companyInfoFontSize': 12.0,
            'invoiceTitleFontSize': 20.0,
            'invoiceInfoFontSize': 12.0,
            'customerInfoPadding': 15.0,
            'customerInfoBorderWidth': 2.0,
            'customerInfoBorderRadius': 0.0,
            'customerInfoTitleFontSize': 16.0,
            'customerInfoTextFontSize': 12.0,
            'tableBorderWidth': 1.0,
            'tableHeaderFontSize': 12.0,
            'tableRowFontSize': 10.0,
            'alternateRowColors': true,
            'alternateRowColor': '#F5F5F5',
            'footerPadding': 10.0,
            'footerBorderWidth': 2.0,
            'footerFontSize': 10.0,
            'showBorderAroundTable': true,
            'useRoundCorners': false,
            'useGradientHeader': false,
            'showInvoiceNumberLarge': false,
            'useCardStyleForSections': false,
          },
        );

    final headerColor = _hexToColor(templateEntity.headerColor);
    final accentColor = _hexToColor(templateEntity.accentColor);
    final bodyFontSize =
        (templateEntity.customFields?['bodyFontSizeValue'] as num?)
            ?.toDouble() ??
        11.0;
    final titleFontSize =
        (templateEntity.customFields?['titleFontSizeValue'] as num?)
            ?.toDouble() ??
        20.0;
    final headerFontSize =
        (templateEntity.customFields?['headerFontSizeValue'] as num?)
            ?.toDouble() ??
        12.0;
    final footerFontSize =
        (templateEntity.customFields?['footerFontSizeValue'] as num?)
            ?.toDouble() ??
        8.0;
    final tableCellPadding =
        (templateEntity.customFields?['tableCellPadding'] as num?)
            ?.toDouble() ??
        6.0;
    final marginTop =
        (templateEntity.customFields?['pageMarginTopMM'] as num?)?.toDouble() ??
        0.0;
    final marginBottom =
        (templateEntity.customFields?['pageMarginBottomMM'] as num?)
            ?.toDouble() ??
        0.0;
    final marginLeft =
        (templateEntity.customFields?['pageMarginLeftMM'] as num?)
            ?.toDouble() ??
        0.0;
    final marginRight =
        (templateEntity.customFields?['pageMarginRightMM'] as num?)
            ?.toDouble() ??
        0.0;

    // حساب المجاميع الإجمالية - موجبة وسالبة بشكل منفصل مع صافي نهائي
    // المنطق مطابق لشاشة قائمة الفواتير: تصنيف حسب نوع الفاتورة
    final grandTotalPositive = invoices.fold<double>(
      0,
      (sum, inv) {
        final isSalesReturn = inv.type == 'sales_return' || inv.isSalesReturn;
        final isCashReceipt = inv.type == 'cash' &&
            inv.isCashAccountReceipt &&
            inv.effectiveCashTransactionType == 'receipt';
        if (isSalesReturn || isCashReceipt) {
          return sum; // سالبة - لا تضاف للموجبة
        } else {
          return sum + inv.totalAmount; // موجبة (تزيد الدين)
        }
      },
    );
    final grandTotalNegative = invoices.fold<double>(
      0,
      (sum, inv) {
        final isSalesReturn = inv.type == 'sales_return' || inv.isSalesReturn;
        final isCashReceipt = inv.type == 'cash' &&
            inv.isCashAccountReceipt &&
            inv.effectiveCashTransactionType == 'receipt';
        if (isSalesReturn || isCashReceipt) {
          return sum + inv.totalAmount.abs(); // سالبة (تقلل الدين)
        } else {
          return sum; // موجبة - لا تضاف للسالبة
        }
      },
    );
    final grandPaid = invoices.fold<double>(
      0,
      (sum, inv) => sum + inv.paidAmount.abs(),
    );
    final grandRemaining = invoices.fold<double>(
      0,
      (sum, inv) => sum + inv.calculateRemainingAmount(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(
          marginLeft * PdfPageFormat.mm,
          marginTop * PdfPageFormat.mm,
          marginRight * PdfPageFormat.mm,
          marginBottom * PdfPageFormat.mm,
        ),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        header: (context) => pw.Container(
          padding: pw.EdgeInsets.all(
            (templateEntity.customFields?['headerPadding'] as num? ?? 20.0)
                .toDouble(),
          ),
          color: headerColor,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (templateEntity.showCompanyInfo)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _ar(organizationName),
                        style: pw.TextStyle(
                          fontSize:
                              (templateEntity
                                          .customFields?['companyNameFontSize']
                                      as num?)
                                  ?.toDouble() ??
                              24.0,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        _ar(organizationPhone),
                        style: pw.TextStyle(
                          fontSize:
                              (templateEntity
                                      .customFields?['companyInfoFontSize']
                                  as num?)
                                  ?.toDouble() ??
                              12.0,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        _ar(organizationAddress),
                        style: pw.TextStyle(
                          fontSize:
                              (templateEntity
                                          .customFields?['companyInfoFontSize']
                                      as num?)
                                  ?.toDouble() ??
                              12.0,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              if (templateEntity.showLogo && logoBytes != null)
                pw.Container(
                  width:
                      (templateEntity.customFields?['logoWidth'] as num?)
                          ?.toDouble() ??
                      80.0,
                  height:
                      (templateEntity.customFields?['logoHeight'] as num?)
                          ?.toDouble() ??
                      80.0,
                  alignment: pw.Alignment.center,
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'تقرير سجل الفواتير',
                      style: pw.TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _ar('تاريخ التوليد: ${_formatDateTime(DateTime.now())}'),
                      style: pw.TextStyle(
                        fontSize: bodyFontSize - 1,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: pw.EdgeInsets.only(
            top: (templateEntity.customFields?['footerPadding'] as num? ?? 10.0)
                .toDouble(),
          ),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(
                color: accentColor,
                width:
                    (templateEntity.customFields?['footerBorderWidth'] as num?)
                        ?.toDouble() ??
                    2.0,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _ar(templateEntity.footerText),
                style: pw.TextStyle(
                  fontSize: footerFontSize,
                  color: accentColor,
                ),
              ),
              pw.Text(
                _ar('صفحة ${context.pageNumber} من ${context.pagesCount}'),
                style: pw.TextStyle(
                  fontSize: footerFontSize,
                  color: PdfColors.grey,
                ),
              ),
            ],
          ),
        ),
        build: (context) => <pw.Widget>[
          // ===== صفحة الملخص (الغلاف) =====
          // مسافة علوية لفصل المحتوى عن الهيدر (الشعار ومعلومات الشركة)
          pw.SizedBox(height: 70),

          // معلومات العميل (إذا كان للعميل المحدد)
          if (templateEntity.showCustomerInfo &&
              customerName != null &&
              customerName.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: accentColor, width: 1.5),
                borderRadius: pw.BorderRadius.circular(
                  (templateEntity.customFields?['customerInfoBorderRadius']
                              as num?)
                          ?.toDouble() ??
                      6.0,
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      _ar('معلومات العميل'),
                      style: pw.TextStyle(
                        fontSize:
                            (templateEntity
                                        .customFields?['customerInfoTitleFontSize']
                                    as num?)
                                ?.toDouble() ??
                            16.0,
                        fontWeight: pw.FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                         pw.Text(
                           _ar('إجمالي الفواتير: ${invoices.length}'),
                           style: pw.TextStyle(
                            fontSize:
                                (templateEntity
                                        .customFields?['customerInfoTextFontSize']
                                    as num?)
                                    ?.toDouble() ??
                                12.0,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                          pw.Text(
                            _ar('اسم العميل: $customerName'),
                            style: pw.TextStyle(
                              fontSize:
                                (templateEntity
                                            .customFields?['customerInfoTextFontSize']
                                        as num?)
                                    ?.toDouble() ??
                                12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 15),

          // جدول ملخص الفواتير
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: accentColor, width: 1),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    _ar('قائمة الفواتير المصدرة'),
                    style: pw.TextStyle(
                      fontSize: headerFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                ),
                pw.Table(
                  border: pw.TableBorder.all(color: accentColor, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1), // المبلغ (على اليمين في RTL)
                    1: const pw.FlexColumnWidth(3), // رقم الفاتورة (وسط)
                    2: const pw.FlexColumnWidth(0.25), // # (على اليسار في RTL)
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: headerColor),
                      children: [
                        _buildHistoryTableCell(_ar('المبلغ'), isHeader: true),
                        _buildHistoryTableCell(_ar('رقم الفاتورة'), isHeader: true),
                        _buildHistoryTableCell('#', isHeader: true),
                      ],
                    ),
                    ...invoices.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final inv = entry.value;
                      final invIsSalesReturn = inv.type == 'sales_return' ||
                          inv.isSalesReturn;
                      final invIsCashReceipt = inv.type == 'cash' &&
                          inv.isCashAccountReceipt &&
                          inv.effectiveCashTransactionType == 'receipt';
                      final invDebtEffect =
                          invIsSalesReturn || invIsCashReceipt
                              ? 'decrease'
                              : 'increase';
                      return pw.TableRow(
                        children: [
                          _buildHistoryTableCell(
                            _formatAmount(inv.totalAmount),
                            debtEffect: invDebtEffect,
                          ),
                          _buildHistoryTableCell(inv.invoiceNumber),
                          _buildHistoryTableCell(index.toString()),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 15),

          // الإجماليات الإجمالية
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
               children: [
                 // قيمة الفواتير (الموجبة - تزيد الدين) - أحمر
                 _buildTotalRow(
                   _ar('قيمة الفواتير:'),
                   grandTotalPositive,
                   fontSize: bodyFontSize,
                   isBold: true,
                   debtEffect: 'increase',
                 ),
                 pw.SizedBox(height: 4),
                 // المبالغ المدفوعة - أخضر
                 _buildTotalRow(
                   _ar('المبالغ المدفوعة:'),
                   grandPaid,
                   fontSize: bodyFontSize,
                   debtEffect: 'decrease',
                 ),
                 pw.SizedBox(height: 4),
                 // مرجع البيع - أخضر (إذا وجد)
                 if (grandTotalNegative > 0) ...[
                   _buildTotalRow(
                     _ar('مرجع البيع:'),
                     grandTotalNegative,
                     fontSize: bodyFontSize,
                     debtEffect: 'decrease',
                   ),
                   pw.SizedBox(height: 4),
                 ],
                 // المتبقي
                 _buildTotalRow(
                   _ar('المتبقي:'),
                   grandRemaining,
                   fontSize: bodyFontSize,
                   isBold: true,
                   debtEffect: grandRemaining > 0 ? 'increase' : 'decrease',
                 ),
               ],
             ),
          ),
          pw.SizedBox(height: 15),
           pw.Text(
            _ar('تفاصيل الفواتير المرفقة في الصفحات التالية'),
            style: pw.TextStyle(fontSize: bodyFontSize, color: PdfColors.grey),
          ),
          pw.SizedBox(height: 15),

          // == صفحات التفاصيل لكل فاتورة ==
          ...invoices.expand(
            (invoice) => _buildInvoiceHistoryPageWidgets(
              invoice,
              templateEntity: templateEntity,
              headerColor: headerColor,
              accentColor: accentColor,
              bodyFontSize: bodyFontSize,
              headerFontSize: headerFontSize,
              tableCellPadding: tableCellPadding,
              showCustomerInfoOnDetailPage: customerName == null,
            ),
          ),
          // مسافة سفلية لفصل المحتوى عن التذييل (footer)
          pw.SizedBox(height: 60),
        ],
      ),
    );

    return _savePdfFile(
      pdf,
      'invoice_history_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// بناء عناصر صفحة تفاصيل فاتورة واحدة باستخدام تنسيق القالب الأصلي
  List<pw.Widget> _buildInvoiceHistoryPageWidgets(
    InvoiceEntity invoice, {
    required InvoiceTemplateEntity templateEntity,
    required PdfColor headerColor,
    required PdfColor accentColor,
    required double bodyFontSize,
    required double headerFontSize,
    required double tableCellPadding,
    bool showCustomerInfoOnDetailPage = false,
  }) {
    // تحديد تأثير الدين بناءً على نوع الفاتورة
    // فواتير مرجع البيع تقلل الدين (أخضر)، الفواتير العادية تزيد الدين (أحمر)
    // الفواتير النقدية: استلام يقلل الدين (أخضر)، إعطاء يزيد الدين (أحمر)
    final bool isSalesReturn = invoice.type == 'sales_return' ||
        invoice.isSalesReturn;
    final bool isCashReceipt = invoice.type == 'cash' &&
        invoice.isCashAccountReceipt &&
        invoice.effectiveCashTransactionType == 'receipt';
    final bool isCashPayment = invoice.type == 'cash' &&
        invoice.isCashAccountReceipt &&
        invoice.effectiveCashTransactionType == 'payment';
    final String debtEffect =
        isSalesReturn || isCashReceipt ? 'decrease' : 'increase';

    return [
      pw.Container(
        color: headerColor,
        padding: const pw.EdgeInsets.all(10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
              pw.Text(
               _ar('تفاصيل الفاتورة'),
               style: pw.TextStyle(
                 fontSize: headerFontSize + 4,
                 fontWeight: pw.FontWeight.bold,
                 color: PdfColors.white,
               ),
              ),
              pw.Text(
                _ar('رقم: ${invoice.invoiceNumber}'),
                style: pw.TextStyle(
                  fontSize: bodyFontSize,
                  color: PdfColors.white,
                ),
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 12),
      if (showCustomerInfoOnDetailPage) ...[
                pw.Text(
                  _ar('رقم الهاتف: ${invoice.customerPhone}'),
                  style: pw.TextStyle(fontSize: bodyFontSize),
                ),
                pw.Text(
                  _ar('العميل: ${invoice.customerName}'),
                  style: pw.TextStyle(fontSize: bodyFontSize),
                ),
      ],
       pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _ar('التاريخ: ${_formatDate(invoice.invoiceDate)}'),
            style: pw.TextStyle(fontSize: bodyFontSize),
          ),
          pw.Text(
            _ar('النوع: ${_getInvoiceTypeName(invoice.type)}'),
            style: pw.TextStyle(fontSize: bodyFontSize),
          ),
          pw.Text(
            _ar('الحالة: ${invoice.status}'),
            style: pw.TextStyle(fontSize: bodyFontSize),
          ),
        ],
      ),
      if (invoice.type == 'cash' && invoice.isCashAccountReceipt) ...[
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _ar(
                'نوع المعاملة: ${invoice.effectiveCashTransactionType == 'receipt' ? 'استلام مبلغ من العميل' : invoice.effectiveCashTransactionType == 'payment' ? 'إعطاء مبلغ للعميل' : 'تصفية الحساب'}',
              ),
              style: pw.TextStyle(
                fontSize: bodyFontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
      pw.SizedBox(height: 8),
      if (invoice.items.isNotEmpty) ...[
        pw.Table(
          border: pw.TableBorder.all(color: accentColor, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1), // المجموع (على اليمين في RTL)
            1: const pw.FlexColumnWidth(1), // السعر
            2: const pw.FlexColumnWidth(0.5), // الكمية
            3: const pw.FlexColumnWidth(3), // الصنف
            4: const pw.FlexColumnWidth(0.5), // # (على اليسار في RTL)
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerColor),
              children: [
                _buildHistoryTableCell(_ar('المجموع'), isHeader: true),
                _buildHistoryTableCell(_ar('السعر'), isHeader: true),
                _buildHistoryTableCell(_ar('الكمية'), isHeader: true),
                _buildHistoryTableCell(_ar('الصنف'), isHeader: true),
                _buildHistoryTableCell('#', isHeader: true),
              ],
            ),
            ...invoice.items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return pw.TableRow(
                children: [
                  _buildHistoryTableCell(
                    _formatAmount(item.totalPrice),
                    debtEffect: debtEffect,
                  ),
                  _buildHistoryTableCell(
                    _formatAmount(item.unitPrice),
                    debtEffect: debtEffect,
                  ),
                  _buildHistoryTableCell(
                    item.quantity.toStringAsFixed(0),
                  ),
                  _buildHistoryTableCell(_ar(item.productName)),
                  _buildHistoryTableCell(index.toString()),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _ar('المبلغ الإجمالي:'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              _ar('المدفوع:'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              _ar('المتبقي:'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red),
            ),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // الإجمالي: increase (يزيد الدين) = أحمر، decrease (يقلل الدين) = أخضر
            pw.Container(
              color: debtEffect == 'increase'
                  ? _hexToColor('#FFEBEE')
                  : _hexToColor('#E8F5E9'),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: pw.Text(
                debtEffect == 'increase'
                    ? '+${_formatAmount(invoice.totalAmount.abs())}'
                    : '-${_formatAmount(invoice.totalAmount.abs())}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            // المدفوع: دائمًا decrease (يقلل دين العميل) = أخضر
            pw.Container(
              color: _hexToColor('#E8F5E9'),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: pw.Text(
                '-${_formatAmount(invoice.paidAmount.abs())}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            // المتبقي: >0 = increase (دين متبق) = أحمر، <=0 = decrease (لا دين) = أخضر
            pw.Container(
              color: invoice.calculateRemainingAmount() > 0
                  ? _hexToColor('#FFEBEE')
                  : _hexToColor('#E8F5E9'),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: pw.Text(
                invoice.calculateRemainingAmount() > 0
                    ? '+${_formatAmount(invoice.calculateRemainingAmount().abs())}'
                    : '-${_formatAmount(invoice.calculateRemainingAmount().abs())}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red),
              ),
            ),
          ],
        ),
      ],
      pw.SizedBox(height: 12),
      if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text(
          _ar('ملاحظات: ${invoice.notes}'),
          style: pw.TextStyle(fontSize: bodyFontSize),
        ),
      ],
    ];
  }

  pw.Widget _buildHistoryTableCell(
    String text, {
    bool isHeader = false,
    String? debtEffect,
  }) {
    final dynamicBg = debtEffect == 'increase'
        ? _hexToColor('#FFEBEE')
        : debtEffect == 'decrease'
            ? _hexToColor('#E8F5E9')
            : null;
    // إضافة إشارة (+ أو -) أمام المبلغ بناءً على تأثير الدين
    String displayText = text;
    if (debtEffect == 'increase') {
      displayText = '+$text';
    } else if (debtEffect == 'decrease') {
      displayText = '-$text';
    }
    return pw.Container(
      color: dynamicBg,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          displayText,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isHeader ? PdfColors.white : PdfColors.black,
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

