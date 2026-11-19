import 'package:material_ui/material_ui.dart';

import '../../domain/entities/invoice_template_entity.dart';

/// القالب البسيط للفواتير - تصميم نظيف وواضح
class MinimalInvoiceTemplate {
  // ===== ألوان القالب =====
  static const Color headerColorValue = Color(0xFF34495E); // رمادي أزرق داكن
  static const Color accentColorValue = Color(0xFF95A5A6); // رمادي فاتح
  static const Color secondaryColorValue = Color(0xFFECF0F1); // رمادي فاتح جداً
  static const Color headerTextColorValue = Color(0xFFFFFFFF); // أبيض
  static const Color bodyTextColorValue = Color(0xFF2C3E50); // رمادي داكن

  // ===== نصوص القالب =====
  static const String templateName = 'القالب البسيط';
  static const String footerTextValue = 'شكراً لكم';

  // ===== إعدادات القالب =====
  static const String templateId = 'template_minimal';
  static const String logoPositionValue = 'left';
  static const bool showLogoValue = true;
  static const bool showCompanyInfoValue = true;
  static const bool showCustomerInfoValue = true;
  static const bool showItemsTableValue = true;
  static const bool showNotesValue = false;
  static const bool showSignatureValue = false;
  static const bool isDefaultValue = false;

  // ===== أبعاد ورقة A4 =====
  static const String pageFormat = 'A4';
  static const double pageWidthMM = 210.0;
  static const double pageHeightMM = 297.0;
  static const double pageMarginTopMM = 0.0;
  static const double pageMarginBottomMM = 0.0;
  static const double pageMarginLeftMM = 0.0;
  static const double pageMarginRightMM = 0.0;
  static const bool usePortraitOrientation = true;

  // ===== الخصائص الهيكلية =====

  // 1. تصميم الهيدر
  static const String headerLayoutStyle = 'minimal';
  static const bool headerFullWidth = false;
  static const bool showHeaderPattern = false;
  static const String headerPatternType = 'none';

  // 2. تصميم الشعار
  static const String logoShape = 'square';
  static const bool logoWithBorder = false;
  static const bool logoWithShadow = false;

  // 3. تصميم معلومات العميل
  static const String customerInfoLayout = 'inline';
  static const bool customerInfoWithIcon = false;
  static const String customerInfoAlignment = 'left';

  // 4. تصميم الجدول
  static const String tableLayout = 'minimal';
  static const bool tableHeaderSeparate = false;
  static const bool tableWithTotalRow = true;
  static const String tableAlignment = 'left';
  static const bool showTableIcons = false;

  // 5. تصميم الأقسام
  static const String sectionsStyle = 'plain';
  static const double sectionSpacing = 18.0;
  static const bool sectionAnimations = false;

  // 6. الخطوط
  static const String fontFamily = 'Cairo';
  static const String titleFontWeight = 'normal';
  static const String bodyFontWeight = 'normal';

  // 7. الزخرفة
  static const bool showDecorativeLines = false;
  static const bool showPageNumbers = false;
  static const bool showWatermark = false;
  static const String cornerStyle = 'sharp';

  // ===== قياسات الخطوط =====
  // مُحسّنة لقياس A4 (210×297mm)
  static const double titleFontSizeValue = 16.0; // عنوان الفاتورة - بسيط
  static const double subtitleFontSizeValue = 13.0; // العناوين الفرعية
  static const double headerFontSizeValue = 11.5; // هيدر الجدول
  static const double bodyFontSizeValue = 10.5; // النص الأساسي
  static const double smallFontSizeValue = 9.5; // النص الصغير
  static const double footerFontSizeValue = 8.5; // التذييل

  // ===== قياسات الأقسام =====
  // مُحسّنة لقياس A4 (210×297mm)
  static const double headerHeightMM = 40.0; // ارتفاع الهيدر - أصغر
  static const double sectionSpacingMM = 10.0; // تباعد الأقسام - أقل
  static const double tableRowHeightMM = 8.0; // ارتفاع صف الجدول - مضغوط
  static const double logoSizeMM = 28.0; // حجم الشعار - صغير

  // ===== خصائص التصميم الإضافية للقالب البسيط =====
  static const double headerPaddingValue = 15.0;
  static const double headerBorderRadiusValue = 0.0;
  static const double companyNameFontSizeValue = 20.0;
  static const double companyInfoFontSizeValue = 10.0;
  static const double invoiceTitleFontSizeValue = 16.0;
  static const double invoiceInfoFontSizeValue = 10.0;
  static const double logoWidthValue = 60.0;
  static const double logoHeightValue = 60.0;
  static const String logoColorValue = '#34495E';

  static const double customerInfoPaddingValue = 10.0;
  static const double customerInfoBorderWidthValue = 1.0;
  static const double customerInfoBorderRadiusValue = 4.0;
  static const double customerInfoTitleFontSizeValue = 14.0;
  static const double customerInfoTextFontSizeValue = 10.0;

  static const double tableBorderWidthValue = 0.5;
  static const double tableCellPaddingValue = 5.0;
  static const double tableHeaderFontSizeValue = 10.0;
  static const double tableRowFontSizeValue = 9.5;
  static const bool alternateRowColorsValue = false;
  static const Color alternateRowColorValue = Color(0xFFECF0F1);

  static const double footerPaddingValue = 8.0;
  static const double footerBorderWidthValue = 1.0;

  static const bool useRoundCorners = false;
  static const bool useGradientHeader = false;
  static const bool showBorderAroundTable = false;
  static const double headerHeightFactor = 1.0;
  static const String tableStyle = 'minimal';
  static const bool showInvoiceNumberLarge = false;
  static const bool useCardStyleForSections = false;

  /// تحويل Color إلى hex string
  static String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  /// إنشاء كيان القالب
  static InvoiceTemplateEntity create() {
    return InvoiceTemplateEntity(
      id: templateId,
      name: templateName,
      type: 'sales',
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
        // أبعاد الصفحة
        'pageFormat': pageFormat,
        'pageWidthMM': pageWidthMM,
        'pageHeightMM': pageHeightMM,
        'pageMarginTopMM': pageMarginTopMM,
        'pageMarginBottomMM': pageMarginBottomMM,
        'pageMarginLeftMM': pageMarginLeftMM,
        'pageMarginRightMM': pageMarginRightMM,
        'usePortraitOrientation': usePortraitOrientation,

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
        // هوامش الجدول - القالب البسيط
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
}
