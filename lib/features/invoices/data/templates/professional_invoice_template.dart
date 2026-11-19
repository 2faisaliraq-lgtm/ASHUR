import 'package:material_ui/material_ui.dart';

import '../../domain/entities/invoice_template_entity.dart';

/// القالب الاحترافي للفواتير - قياسات A4 قياسية واحترافية
class ProfessionalInvoiceTemplate {
  // ===== ألوان القالب =====
  static const Color headerColorValue = Color(0xFF2C3E50); // رمادي داكن احترافي
  static const Color accentColorValue = Color(0xFF3498DB); // أزرق فاتح احترافي
  static const Color headerTextColorValue = Color(0xFFFFFFFF); // أبيض
  static const Color bodyTextColorValue = Color(0xFF2C3E50); // رمادي داكن

  // ===== نصوص القالب =====
  static const String templateName = 'القالب الاحترافي';
  static const String footerTextValue = 'شكراً لتعاملكم معنا - نقدر ثقتكم';

  // ===== إعدادات القالب =====
  static const String templateId = 'template_professional';
  static const String logoPositionValue = 'right';
  static const bool showLogoValue = true;
  static const bool showCompanyInfoValue = true;
  static const bool showCustomerInfoValue = true;
  static const bool showItemsTableValue = true;
  static const bool showNotesValue = true;
  static const bool showSignatureValue = true;
  static const bool isDefaultValue = false;

  // ===== أبعاد ورقة A4 القياسية =====
  // A4: 210mm × 297mm (نسبة 1:1.414)
  static const String pageFormat = 'A4';
  static const double pageWidthMM = 210.0; // عرض A4 قياسي
  static const double pageHeightMM = 297.0; // ارتفاع A4 قياسي

  // الهوامش القياسية للفواتير (ISO 216) - بدون هوامش
  static const double pageMarginTopMM = 0.0; // هامش علوي 0mm
  static const double pageMarginBottomMM = 0.0; // هامش سفلي 0mm
  static const double pageMarginLeftMM = 0.0; // هامش أيسر 0mm
  static const double pageMarginRightMM = 0.0; // هامش أيمن 0mm
  static const bool usePortraitOrientation = true; // وضع عمودي

  // ===== قياسات الخطوط القياسية (بالنقاط) =====
  // 1mm ≈ 2.83 points
  static const double titleFontSizeValue =
      18.0; // عنوان الفاتورة (18pt ≈ 6.4mm)
  static const double subtitleFontSizeValue =
      14.0; // العناوين الفرعية (14pt ≈ 5mm)
  static const double headerFontSizeValue = 12.0; // هيدر الجدول (12pt ≈ 4.2mm)
  static const double bodyFontSizeValue = 11.0; // النص الأساسي (11pt ≈ 3.9mm)
  static const double smallFontSizeValue = 9.0; // النص الصغير (9pt ≈ 3.2mm)
  static const double footerFontSizeValue = 8.0; // التذييل (8pt ≈ 2.8mm)

  // ===== قياسات الأقسام (بالمليمتر) =====
  static const double headerHeightMM = 40.0; // ارتفاع الهيدر
  static const double sectionSpacingMM = 10.0; // تباعد الأقسام
  static const double tableRowHeightMM = 8.0; // ارتفاع صف الجدول
  static const double logoSizeMM = 30.0; // حجم الشعار

  // ===== الخصائص الهيكلية =====
  static const String headerLayoutStyle = 'standard';
  static const bool headerFullWidth = true;
  static const bool showHeaderPattern = false;
  static const String headerPatternType = 'none';

  static const String logoShape = 'square';
  static const bool logoWithBorder = false;
  static const bool logoWithShadow = false;

  static const String customerInfoLayout = 'card';
  static const bool customerInfoWithIcon = true;
  static const String customerInfoAlignment = 'right';

  static const String tableLayout = 'professional';
  static const bool tableHeaderSeparate = true;
  static const bool tableWithTotalRow = true;
  static const String tableAlignment = 'center';
  static const bool showTableIcons = false;

  static const String sectionsStyle = 'cards';
  static const double sectionSpacing = 20.0;
  static const bool sectionAnimations = false;

  static const String fontFamily = 'Cairo';
  static const String titleFontWeight = 'bold';
  static const String bodyFontWeight = 'normal';

  static const bool showDecorativeLines = true;
  static const bool showPageNumbers = true;
  static const bool showWatermark = false;
  static const String cornerStyle = 'rounded';

  // ===== خصائص التصميم =====
  static const double headerPaddingValue = 15.0;
  static const double headerBorderRadiusValue = 8.0;
  static const double companyNameFontSizeValue = 16.0;
  static const double companyInfoFontSizeValue = 10.0;
  static const double invoiceTitleFontSizeValue = 18.0;
  static const double invoiceInfoFontSizeValue = 11.0;
  static const double logoWidthValue = 35.0;
  static const double logoHeightValue = 35.0;
  static const String logoColorValue = '#2C3E50';

  static const double customerInfoPaddingValue = 12.0;
  static const double customerInfoBorderWidthValue = 1.5;
  static const double customerInfoBorderRadiusValue = 6.0;
  static const double customerInfoTitleFontSizeValue = 14.0;
  static const double customerInfoTextFontSizeValue = 11.0;

  static const double tableBorderWidthValue = 0.5;
  static const double tableCellPaddingValue = 5.0;
  static const double tableHeaderFontSizeValue = 12.0;
  static const double tableRowFontSizeValue = 11.0;
  static const bool alternateRowColorsValue = true;
  static const Color alternateRowColorValue = Color(0xFFF8F9FA);

  static const double footerPaddingValue = 10.0;
  static const double footerBorderWidthValue = 2.0;

  static const bool useRoundCorners = true;
  static const bool useGradientHeader = false;
  static const bool showBorderAroundTable = true;
  static const double headerHeightFactor = 1.0;
  static const String tableStyle = 'professional';
  static const bool showInvoiceNumberLarge = true;
  static const bool useCardStyleForSections = true;

  static InvoiceTemplateEntity create() {
    return InvoiceTemplateEntity(
      id: templateId,
      name: templateName,
      type: 'general',
      headerColor: _colorToHex(headerColorValue),
      accentColor: _colorToHex(accentColorValue),
      showLogo: showLogoValue,
      logoPosition: logoPositionValue,
      showCompanyInfo: showCompanyInfoValue,
      showCustomerInfo: showCustomerInfoValue,
      showItemsTable: showItemsTableValue,
      showNotes: showNotesValue,
      showSignature: showSignatureValue,
      footerText: footerTextValue,
      isDefault: isDefaultValue,
      customFields: {
        // أبعاد الصفحة A4
        'pageFormat': pageFormat,
        'pageWidthMM': pageWidthMM,
        'pageHeightMM': pageHeightMM,
        'pageMarginTopMM': pageMarginTopMM,
        'pageMarginBottomMM': pageMarginBottomMM,
        'pageMarginLeftMM': pageMarginLeftMM,
        'pageMarginRightMM': pageMarginRightMM,
        'usePortraitOrientation': usePortraitOrientation,

        // قياسات الخطوط
        'titleFontSize': titleFontSizeValue,
        'subtitleFontSize': subtitleFontSizeValue,
        'headerFontSize': headerFontSizeValue,
        'bodyFontSize': bodyFontSizeValue,
        'smallFontSize': smallFontSizeValue,

        // قياسات الأقسام
        'headerHeightMM': headerHeightMM,
        'sectionSpacingMM': sectionSpacingMM,
        'tableRowHeightMM': tableRowHeightMM,
        'logoSizeMM': logoSizeMM,

        // الألوان
        'headerTextColor': _colorToHex(headerTextColorValue),
        'bodyTextColor': _colorToHex(bodyTextColorValue),

        // الخصائص الهيكلية
        'headerLayoutStyle': headerLayoutStyle,
        'headerFullWidth': headerFullWidth,
        'showHeaderPattern': showHeaderPattern,
        'headerPatternType': headerPatternType,

        'logoShape': logoShape,
        'logoWithBorder': logoWithBorder,
        'logoWithShadow': logoWithShadow,

        'customerInfoLayout': customerInfoLayout,
        'customerInfoWithIcon': customerInfoWithIcon,
        'customerInfoAlignment': customerInfoAlignment,

        'tableLayout': tableLayout,
        'tableHeaderSeparate': tableHeaderSeparate,
        'tableWithTotalRow': tableWithTotalRow,
        'tableAlignment': tableAlignment,
        'showTableIcons': showTableIcons,
        // هوامش الجدول - القالب الاحترافي
        'tableMarginLeftMM': 5.0,
        'tableMarginRightMM': 5.0,
        'tableMarginTopMM': 5.0,
        'tableMarginBottomMM': 5.0,

        'sectionsStyle': sectionsStyle,
        'sectionSpacing': sectionSpacing,
        'sectionAnimations': sectionAnimations,

        'fontFamily': fontFamily,
        'titleFontWeight': titleFontWeight,
        'bodyFontWeight': bodyFontWeight,

        'showDecorativeLines': showDecorativeLines,
        'showPageNumbers': showPageNumbers,
        'showWatermark': showWatermark,
        'cornerStyle': cornerStyle,

        // خصائص التصميم
        'headerPadding': headerPaddingValue,
        'headerBorderRadius': headerBorderRadiusValue,
        'companyNameFontSize': companyNameFontSizeValue,
        'companyInfoFontSize': companyInfoFontSizeValue,
        'invoiceTitleFontSize': invoiceTitleFontSizeValue,
        'invoiceInfoFontSize': invoiceInfoFontSizeValue,
        'logoWidth': logoWidthValue,
        'logoHeight': logoHeightValue,
        'logoColor': logoColorValue,
        'customerInfoPadding': customerInfoPaddingValue,
        'customerInfoBorderWidth': customerInfoBorderWidthValue,
        'customerInfoBorderRadius': customerInfoBorderRadiusValue,
        'customerInfoTitleFontSize': customerInfoTitleFontSizeValue,
        'customerInfoTextFontSize': customerInfoTextFontSizeValue,
        'tableBorderWidth': tableBorderWidthValue,
        'tableCellPadding': tableCellPaddingValue,
        'tableHeaderFontSize': tableHeaderFontSizeValue,
        'tableRowFontSize': tableRowFontSizeValue,
        'alternateRowColors': alternateRowColorsValue,
        'alternateRowColor': _colorToHex(alternateRowColorValue),
        'footerPadding': footerPaddingValue,
        'footerBorderWidth': footerBorderWidthValue,
        'footerFontSize': footerFontSizeValue,
        'useRoundCorners': useRoundCorners,
        'useGradientHeader': useGradientHeader,
        'showBorderAroundTable': showBorderAroundTable,
        'headerHeightFactor': headerHeightFactor,
        'tableStyle': tableStyle,
        'showInvoiceNumberLarge': showInvoiceNumberLarge,
        'useCardStyleForSections': useCardStyleForSections,
      },
    );
  }

  /// تحويل Color إلى hex string
  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  /// الحصول على لون الهيدر كـ Color
  static Color get headerColor => headerColorValue;

  /// الحصول على اللون الثانوي كـ Color
  static Color get accentColor => accentColorValue;

  /// الحصول على لون الصفوف البديلة كـ Color
  static Color get alternateRowColor => alternateRowColorValue;
}
