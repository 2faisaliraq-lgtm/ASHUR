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
  pw.Font? _cachedRegularFont;
  pw.Font? _cachedBoldFont;
  InvoiceTemplateEntity? _cachedDefaultTemplate;
  static final Map<String, String> _arCache = {};

  /// تهيئة خدمة تنسيق النصوص العربية للبي دي إف
  String _ar(String text) {
    // إرجاع من الكاش إذا وجد لتجنب إعادة التشكيل
    final cached = _arCache[text];
    if (cached != null) return cached;

    // تجنب إعادة تشكيل النصوص التي لا تحتوي على أحرف عربية (أرقام، رموز، إنجليزي)
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    if (!hasArabic) {
      _arCache[text] = text;
      return text;
    }

    try {
      final reshaped = ArabicReshaper.instance.reshape(text);
      _arCache[text] = reshaped;
      return reshaped;
    } on Exception {
      _arCache[text] = text;
      return text;
    }
  }

  /// تسخين كاش النصوص العربية الشائعة لتجنب إعادة التشكيل في أول استخدام
  void _prewarmArCache() {
    final commonTexts = [
      // العناوين والتسميات العامة
      'المجموع', 'السعر', 'الكمية', 'الصنف', '#',
      'المبلغ الصافي:', 'الضريبة:', 'الخصم:', 'المدفوع:', 'المتبقي:',
      'المبالغ المستلمة من العميل:', 'المبالغ المعطاة للعميل:', 'المبالغ المدفوعة:',
      'فواتير لها رصيد (مدفوعة):', 'مرجع البيع:', 'قيمة الفواتير:',
      'دين العميل (المتبقي):', 'الرصيد بعد الفاتورة:',
      // الرصيد قبل الفاتورة
      'الرصيد قبل الفاتورة (مدين):', 'الرصيد قبل الفاتورة (دائن):',
      'الرصيد قبل الفاتورة (مستقر):',
      // معلومات العميل والشركة
      'معلومات العميل', 'معلومات الشركة', 'العميل:', 'الهاتف:',
      'رقم الفاتورة:', 'التاريخ:', 'النوع:', 'الحالة:',
      // الفواتير والتفاصيل
      'تفاصيل الفاتورة', 'قائمة الفواتير', 'ملاحظات:',
      'نوع الفاتورة:', 'الصفحة', 'من', 'سجل الفواتير المرفق',
      'تاريخ التصدير:',
      // تنبيه المتبقي
      'إذا كان المتبقي موجباً فهو عليه، وإذا كان سالباً فهو له',
      // أنواع الفواتير
      'المبيعات', 'المشتريات', 'الاشتراك', 'الصيانة', 'الإيجار', 'النقدي',
      'غير معروف',
      // نصوص القالب الافتراضي
      'شكراً لتعاملكم معنا', 'شكراً لثقتكم بنا',
    ];
    for (final text in commonTexts) {
      if (!_arCache.containsKey(text)) {
        try {
          final reshaped = ArabicReshaper.instance.reshape(text);
          _arCache[text] = reshaped;
        } on Exception {
          _arCache[text] = text;
        }
      }
    }
  }

  /// إنشاء ملف PDF لفاتورة واحدة
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

    // تسخين كاش النصوص العربية الشائعة لتسريع الإنشاء الأول
    _prewarmArCache();

    final pdf = pw.Document();

    // تحميل الخطوط العربية
    final arabicFont = await _loadArabicFont();
    final arabicFontBold = await _loadArabicFontBold();

    // تحويل الألوان السداسية إلى ألوان PdfColor
    final headerColor = _hexToColor(template.headerColor);
    final accentColor = _hexToColor(template.accentColor);

    // قراءة أحجام الخط والهوامش من القالب
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

    // إعداد صفحة A4 (210mm × 297mm) مع دعم الصفحات المتعددة عبر MultiPage
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

        // الترويسة (تظهر في كل صفحة)
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

        // التذييل (يظهر في كل صفحة)
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 0.0 * PdfPageFormat.cm),
          child: pw.Text(
            _ar('صفحة ${context.pageNumber} من ${context.pagesCount}'),
            style: pw.TextStyle(
              color: PdfColors.grey,
              fontSize: footerFontSize,
            ),
          ),
        ),

        // بناء محتوى الصفحة
        build: (context) => <pw.Widget>[
          // مسافة أسفل الترويسة
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

          // جدول الأصناف
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

          // قسم الإجماليات
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // الإجماليات
              pw.Expanded(
                flex: 2,
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

          // تذييل الفاتورة
          _buildFooter(template, accentColor, footerFontSize),
          // مسافة أمان أسفل الصفحة قبل التذييل
          pw.SizedBox(height: 60),
        ],
      ),
    );

    // حفظ ملف PDF
    return _savePdfFile(pdf, invoice.invoiceNumber);
  }

  /// تحميل الخط العربي العادي
  Future<pw.Font> _loadArabicFont() async {
    if (_cachedRegularFont != null) return _cachedRegularFont!;
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      _cachedRegularFont = pw.Font.ttf(fontData);
      return _cachedRegularFont!;
    } on Exception catch (_) {
      return pw.Font.helvetica();
    }
  }

  /// تحميل الخط العربي العريض
  Future<pw.Font> _loadArabicFontBold() async {
    if (_cachedBoldFont != null) return _cachedBoldFont!;
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
      _cachedBoldFont = pw.Font.ttf(fontData);
      return _cachedBoldFont!;
    } on Exception catch (_) {
      return _loadArabicFont();
    }
  }

  /// تحويل لون Hex إلى PdfColor
  PdfColor _hexToColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    return PdfColor(r / 255, g / 255, b / 255);
  }

  /// بناء الترويسة
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
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: headerColor,
        borderRadius: pw.BorderRadius.circular(0),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // معلومات المؤسسة
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

          // شعار المؤسسة
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

          // عنوان وبيانات الفاتورة
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
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _ar('العميل: ${invoice.customerName}'),
                  style: pw.TextStyle(fontSize: bodyFontSize),
                ),
                if (invoice.balanceBeforeInvoice != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    invoice.balanceBeforeInvoice! > 0
                        ? _ar(
                            'الرصيد السابق (عليه): ${_formatAmount(invoice.balanceBeforeInvoice!)}',
                          )
                        : invoice.balanceBeforeInvoice! < 0
                        ? _ar(
                            'الرصيد السابق (له): ${_formatAmount(invoice.balanceBeforeInvoice!.abs())}',
                          )
                        : _ar(
                            'الرصيد السابق (متزن): ${_formatAmount(invoice.balanceBeforeInvoice!)}',
                          ),
                    style: pw.TextStyle(fontSize: bodyFontSize),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 15),
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _ar('الاسم: ${invoice.customerName}'),
                  style: pw.TextStyle(fontSize: bodyFontSize),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// تحديد تأثير الفاتورة على الرصيد/الدين
  String _getInvoiceDebtEffect(
    InvoiceEntity invoice, {
    bool isSummary = false,
  }) {
    if (invoice.type == 'sales_return' || invoice.isSalesReturn) {
      return 'decrease';
    }

    if (invoice.type == 'cash') {
      if (invoice.cashTransactionType == 'receipt') return 'decrease';
      if (invoice.cashTransactionType == 'payment') return 'increase';
      final remaining = invoice.totalAmount - invoice.paidAmount;
      return remaining > 0 ? 'increase' : 'decrease';
    }

    if (isSummary) {
      final remaining = invoice.totalAmount - invoice.paidAmount;
      return remaining > 0 ? 'increase' : 'decrease';
    }

    return 'increase';
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
    final tableMarginTop =
        template.customFields?['tableMarginTopMM'] as double? ?? 0.0;
    final tableMarginBottom =
        template.customFields?['tableMarginBottomMM'] as double? ?? 0.0;
    final tableCellPadding =
        template.customFields?['tableCellPadding'] as double? ?? 6.0;

    final String debtEffect = _getInvoiceDebtEffect(invoice);

    return pw.Padding(
      padding: pw.EdgeInsets.only(
        top: tableMarginTop * PdfPageFormat.mm,
        bottom: tableMarginBottom * PdfPageFormat.mm,
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: accentColor, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.0), // الإجمالي
          1: const pw.FlexColumnWidth(1.0), // السعر
          2: const pw.FlexColumnWidth(0.5), // الكمية
          3: const pw.FlexColumnWidth(3.0), // الصنف
          4: const pw.FlexColumnWidth(0.5), // #
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: headerColor),
            children: [
              _buildTableCell(
                _ar('الإجمالي'),
                isHeader: true,
                fontSize: headerFontSize,
                padding: tableCellPadding,
                backgroundColor: headerColor,
              ),
              _buildTableCell(
                _ar('سعر الوحدة'),
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
                _ar('اسم الصنف'),
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

  /// بناء خلية جدول
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
          fontWeight:
              fontWeight ??
              (isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
          color: fontColor ?? (isHeader ? PdfColors.white : PdfColors.black),
        ),
      ),
    );
  }

  /// بناء صف إجمالي مع إشارة +/- وتلوين حسب تأثير الدين
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
          _ar(prefix + label),
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

  /// بناء الإجماليات والضرائب والخصم والمدفوع والمتبقي
  pw.Widget _buildTotals(
    InvoiceEntity invoice,
    InvoiceTemplateEntity template,
    PdfColor headerColor,
    PdfColor accentColor,
    double bodyFontSize,
  ) {
    final String debtEffect = _getInvoiceDebtEffect(invoice);

    final grandRemainingIfBalance = invoice.balanceBeforeInvoice != null
        ? invoice.totalAmount -
              invoice.paidAmount +
              invoice.balanceBeforeInvoice!.abs()
        : null;

    return pw.Container(
      width: 250,
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          _buildTotalRow(
            'المجموع الفرعي:',
            invoice.totalAmount - invoice.discountAmount,
            fontSize: bodyFontSize,
            debtEffect: debtEffect,
          ),
          if (invoice.taxes != null && invoice.taxes!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
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
                debtEffect: debtEffect,
              );
            }),
            pw.SizedBox(height: 4),
            _buildTotalRow(
              'إجمالي الضرائب:',
              invoice.taxAmount,
              fontSize: bodyFontSize,
              color: PdfColors.orange,
              isBold: true,
              debtEffect: debtEffect,
            ),
          ] else if (invoice.taxAmount > 0) ...[
            pw.SizedBox(height: 4),
            _buildTotalRow(
              'إجمالي الضرائب:',
              invoice.taxAmount,
              fontSize: bodyFontSize,
              color: PdfColors.orange,
              debtEffect: debtEffect,
            ),
          ],
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
            debtEffect:
                invoice.type == 'cash' &&
                    invoice.isCashAccountReceipt &&
                    invoice.cashTransactionType == 'payment'
                ? 'increase'
                : 'decrease',
          ),
          if (invoice.type == 'cash' && invoice.isCashAccountReceipt) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  _ar('نوع الحركة:'),
                  style: pw.TextStyle(
                    fontSize: bodyFontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _ar(
                    invoice.cashTransactionType == 'receipt'
                        ? 'سند قبض نقدي'
                        : invoice.cashTransactionType == 'payment'
                        ? 'سند صرف نقدي'
                        : 'حركة نقدية',
                  ),
                  style: pw.TextStyle(fontSize: bodyFontSize),
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Divider(color: accentColor, thickness: 1.5),
          pw.SizedBox(height: 4),
          _buildTotalRow(
            'المتبقي:',
            invoice.totalAmount - invoice.paidAmount,
            isBold: true,
            fontSize: bodyFontSize + 1,
            color: accentColor,
            debtEffect: invoice.totalAmount - invoice.paidAmount > 0
                ? 'increase'
                : 'decrease',
          ),
          if (invoice.balanceBeforeInvoice != null) ...[
            pw.SizedBox(height: 4),
            _buildTotalRow(
              invoice.balanceBeforeInvoice! > 0
                  ? 'الرصيد السابق (عليه):'
                  : invoice.balanceBeforeInvoice! < 0
                  ? 'الرصيد السابق (له):'
                  : 'الرصيد السابق:',
              invoice.balanceBeforeInvoice!.abs(),
              fontSize: bodyFontSize,
              color: accentColor,
              debtEffect: invoice.balanceBeforeInvoice! > 0
                  ? 'increase'
                  : 'decrease',
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: accentColor, thickness: 1.5),
            pw.SizedBox(height: 4),
            if (grandRemainingIfBalance != null)
              _buildTotalRow(
                'الإجمالي النهائي:',
                grandRemainingIfBalance,
                isBold: true,
                fontSize: bodyFontSize + 1,
                color: headerColor,
                debtEffect: grandRemainingIfBalance > 0
                    ? 'increase'
                    : 'decrease',
              ),
          ],
        ],
      ),
    );
  }

  /// بناء تذييل الفاتورة
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

  /// حفظ ملف PDF على جهاز المستخدم
  Future<File> _savePdfFile(pw.Document pdf, String invoiceNumber) async {
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/invoice_$invoiceNumber.pdf');
    return file.writeAsBytes(await pdf.save());
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  /// تنسيق المبالغ المالية
  String _formatAmount(double amount) {
    return _formattingService.formatCurrency(amount);
  }

  /// تنسيق الأرقام
  String _formatNumber(double number) {
    return _formattingService.formatNumber(number);
  }

  /// الحصول على اسم نوع الفاتورة بالعربية
  String _getInvoiceTypeName(String type) {
    switch (type) {
      case 'sales':
        return 'فاتورة مبيعات';
      case 'purchase':
        return 'فاتورة مشتريات';
      case 'subscription':
        return 'فاتورة اشتراك';
      case 'maintenance':
        return 'فاتورة صيانة';
      case 'rental':
        return 'فاتورة إيجار';
      case 'cash':
        return 'سند نقدي';
      default:
        return 'فاتورة';
    }
  }

  /// مشاركة ملف PDF
  Future<void> sharePdf(File pdfFile) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfFile.path)],
          subject: _ar('فاتورة ${pdfFile.path.split('/').last}'),
        ),
      );
    } on Exception {
      final output = await getApplicationDocumentsDirectory();
      final sharedFile = File(
        '${output.path}/shared_${pdfFile.path.split('/').last}',
      );
      await sharedFile.writeAsBytes(await pdfFile.readAsBytes());
    }
  }

  /// طباعة ملف PDF
  Future<void> printPdf(File pdfFile) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfFile.path)],
          subject: _ar('طباعة ${pdfFile.path.split('/').last}'),
        ),
      );
    } on Exception {
      final output = await getApplicationDocumentsDirectory();
      final printedFile = File(
        '${output.path}/printed_${pdfFile.path.split('/').last}',
      );
      await printedFile.writeAsBytes(await pdfFile.readAsBytes());
    }
  }

  /// إنشاء ملف PDF موحد لسجل عدة فواتير مع صفحة ملخص وصفحات تفاصيل
  Future<File> generateInvoicesHistoryPdf({
    required List<InvoiceEntity> invoices,
    required String organizationName,
    required String organizationPhone,
    required String organizationAddress,
    Uint8List? logoBytes,
    InvoiceTemplateEntity? template,
    String? customerName,
    double? customerDebt,
  }) async {
    await _formattingService.initialize();

    // تسخين كاش النصوص العربية الشائعة لتسريع الإنشاء الأول
    _prewarmArCache();

    final pdf = pw.Document();

    final arabicFont = await _loadArabicFont();
    final arabicFontBold = await _loadArabicFontBold();

    final templateEntity =
        template ??
        (_cachedDefaultTemplate ??
            (_cachedDefaultTemplate = InvoiceTemplateEntity(
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
            )));

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

    // حساب الإجماليات العامة والرصيد المتبقي
    double? grandRemaining;
    double grandTotalPositive = 0;
    double grandTotalNegative = 0;
    double grandSalesReturn = 0;
    double grandCashReceived = 0;
    double grandCashGiven = 0;
    double grandPaidFromRegular = 0;

    if (customerDebt != null) {
      grandRemaining = customerDebt;
    } else {
      for (final inv in invoices) {
        final isSalesReturn = inv.type == 'sales_return' || inv.isSalesReturn;

        if (isSalesReturn) {
          grandSalesReturn += inv.totalAmount.abs();
          grandRemaining = (grandRemaining ?? 0) - inv.totalAmount.abs();
        } else if (inv.type == 'cash') {
          if (inv.cashTransactionType == 'payment') {
            grandCashGiven += inv.totalAmount.abs();
            grandRemaining = (grandRemaining ?? 0) + inv.totalAmount.abs();
          } else {
            grandCashReceived += inv.totalAmount.abs();
            grandRemaining = (grandRemaining ?? 0) - inv.totalAmount.abs();
          }
        } else {
          final remaining = inv.totalAmount - inv.paidAmount;
          grandRemaining = (grandRemaining ?? 0) + remaining;

          if (inv.totalAmount == 0 && inv.paidAmount != 0) {
            if (inv.paidAmount > 0) {
              grandCashReceived += inv.paidAmount;
            } else {
              grandCashGiven += inv.paidAmount.abs();
            }
          } else if (remaining > 0) {
            grandTotalPositive += inv.totalAmount;
            if (inv.paidAmount > 0) {
              grandPaidFromRegular += inv.paidAmount;
            } else if (inv.paidAmount < 0) {
              grandCashGiven += inv.paidAmount.abs();
            }
          } else {
            grandTotalNegative += remaining.abs();
          }
        }
      }

      grandRemaining =
          grandTotalPositive -
          grandTotalNegative -
          grandSalesReturn -
          grandCashReceived +
          grandCashGiven -
          grandPaidFromRegular;
    }

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
                      _ar('سجل الفواتير'),
                      style: pw.TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _ar('تاريخ الطباعة: ${_formatDateTime(DateTime.now())}'),
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
          // مسافة أسفل الترويسة
          pw.SizedBox(height: 70),

          // معلومات العميل عند توفر اسم العميل
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
                          _ar('عدد الفواتير: ${invoices.length}'),
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
                    _ar('ملخص الفواتير المسجلة'),
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
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(0.25),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: headerColor),
                      children: [
                        _buildHistoryTableCell(_ar('المبلغ'), isHeader: true),
                        _buildHistoryTableCell(
                          _ar('رقم الفاتورة'),
                          isHeader: true,
                        ),
                        _buildHistoryTableCell('#', isHeader: true),
                      ],
                    ),
                    ...invoices.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final inv = entry.value;
                      final invDebtEffect = _getInvoiceDebtEffect(
                        inv,
                        isSummary: true,
                      );
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

          // الإجماليات العامة
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                _buildTotalRow(
                  'المتبقي:',
                  customerDebt ?? grandRemaining ?? 0,
                  fontSize: bodyFontSize,
                  isBold: true,
                  debtEffect: (customerDebt ?? grandRemaining ?? 0) > 0
                      ? 'increase'
                      : 'decrease',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Text(
            _ar('تفاصيل الفواتير المسجلة في الكشف التفصيلي'),
            style: pw.TextStyle(fontSize: bodyFontSize, color: PdfColors.grey),
          ),
          pw.SizedBox(height: 15),

          // تفاصيل كل فاتورة
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
          pw.SizedBox(height: 60),
        ],
      ),
    );

    return _savePdfFile(
      pdf,
      'invoice_history_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// بناء عناصر تفاصيل الفاتورة داخل سجل الفواتير
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
    final String debtEffect = _getInvoiceDebtEffect(invoice);

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
          _ar('الهاتف: ${invoice.customerPhone}'),
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
                'نوع الحركة: ${invoice.cashTransactionType == 'receipt'
                    ? 'مقبوض نقدي من العميل'
                    : invoice.cashTransactionType == 'payment'
                    ? 'مدفوع نقدي للعميل'
                    : 'حركة نقدية'}',
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
      // عرض جدول الأصناف دائمًا للفواتير النقدية، أو إذا كانت هناك أصناف
      if (invoice.items.isNotEmpty || invoice.type == 'cash') ...[
        pw.Table(
          border: pw.TableBorder.all(color: accentColor, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(0.5),
            3: const pw.FlexColumnWidth(3),
            4: const pw.FlexColumnWidth(0.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerColor),
              children: [
                _buildHistoryTableCell(_ar('المبلغ'), isHeader: true),
                _buildHistoryTableCell(_ar('سعر الوحدة'), isHeader: true),
                _buildHistoryTableCell(_ar('الكمية'), isHeader: true),
                _buildHistoryTableCell(_ar('الصنف / وصف'), isHeader: true),
                _buildHistoryTableCell('#', isHeader: true),
              ],
            ),
            if (invoice.items.isEmpty && invoice.type == 'cash')
              // صف توضيحي للفواتير النقدية بدون أصناف - يعرض المبلغ ونوع العملية
              pw.TableRow(
                children: [
                  _buildHistoryTableCell(
                    _formatAmount(
                      invoice.totalAmount.abs(),
                    ),
                    debtEffect: debtEffect,
                  ),
                  _buildHistoryTableCell(
                    _ar(
                      invoice.cashTransactionType == 'receipt'
                          ? 'مقبوض نقدي من العميل'
                          : invoice.cashTransactionType == 'payment'
                              ? 'مدفوع نقدي للعميل'
                              : 'حركة نقدية',
                    ),
                    debtEffect: debtEffect,
                  ),
                  _buildHistoryTableCell('-', debtEffect: debtEffect),
                  _buildHistoryTableCell(
                    _ar(
                      'فاتورة نقدية - ${invoice.cashTransactionType == 'receipt' ? 'استلام' : 'دفع'}',
                    ),
                    debtEffect: debtEffect,
                  ),
                  _buildHistoryTableCell('-', debtEffect: debtEffect),
                ],
              )
            else
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
                    _buildHistoryTableCell(item.quantity.toStringAsFixed(0)),
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
              _ar('إجمالي الفاتورة:'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              _ar('المدفوع:'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              _ar('المتبقي:'),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red,
              ),
            ),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Container(
              color: debtEffect == 'increase'
                  ? _hexToColor('#FFEBEE')
                  : _hexToColor('#E8F5E9'),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              child: pw.Text(
                debtEffect == 'increase'
                    ? '+${_formatAmount(invoice.totalAmount.abs())}'
                    : '-${_formatAmount(invoice.totalAmount.abs())}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Container(
              color:
                  (invoice.type == 'cash' &&
                      invoice.isCashAccountReceipt &&
                      invoice.cashTransactionType == 'payment')
                  ? _hexToColor('#FFEBEE')
                  : _hexToColor('#E8F5E9'),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              child: pw.Text(
                (invoice.type == 'cash' &&
                        invoice.isCashAccountReceipt &&
                        invoice.cashTransactionType == 'payment')
                    ? '+${_formatAmount(invoice.paidAmount.abs())}'
                    : '-${_formatAmount(invoice.paidAmount.abs())}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Container(
              color: invoice.remainingAmount > 0 && invoice.isUnpaid
                  ? _hexToColor('#FFEBEE')
                  : _hexToColor('#E8F5E9'),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              child: pw.Text(
                invoice.remainingAmount > 0 && invoice.isUnpaid
                    ? '+${_formatAmount(invoice.remainingAmount.abs())}'
                    : '-${_formatAmount(invoice.remainingAmount.abs())}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red,
                ),
              ),
            ),
          ],
        ),
      ],
      pw.SizedBox(height: 12),
    ];
  }

  /// بناء خلية جدول السجل مع دعم إشارة +/- وتلوين حالة الدين
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

  /// تنسيق التاريخ والوقت
  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
