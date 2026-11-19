import 'package:material_ui/material_ui.dart';

import '../../domain/entities/invoice_template_entity.dart';

/// القالب الملون للفواتير - تصميم حيوي وجذاب
class ColorfulInvoiceTemplate {
  // ===== ألوان القالب =====
  static const Color headerColorValue = Color(0xFFE74C3C); // أحمر حيوي
  static const Color accentColorValue = Color(0xFFF39C12); // برتقالي ذهبي
  static const Color secondaryColorValue = Color(0xFF3498DB); // أزرق سماوي
  static const Color headerTextColorValue = Color(0xFFFFFFFF); // أبيض
  static const Color bodyTextColorValue = Color(0xFF2C3E50); // رمادي داكن

  // ===== نصوص القالب =====
  static const String templateName = 'القالب الملون';
  static const String footerTextValue =
      'شكراً لاختياركم لنا - نتطلع لخدمتكم مجدداً';

  // ===== إعدادات القالب =====
  static const String templateId = 'template_colorful';
  static const String logoPositionValue = 'center';
  static const bool showLogoValue = true;
  static const bool showCompanyInfoValue = true;
  static const bool showCustomerInfoValue = true;
  static const bool showItemsTableValue = true;
  static const bool showNotesValue = true;
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
  static const String headerLayoutStyle = 'colorful';
  static const bool headerFullWidth = true;
  static const bool showHeaderPattern = true;
  static const String headerPatternType = 'dots';

  // 2. تصميم الشعار
  static const String logoShape = 'circle';
  static const bool logoWithBorder = true;
  static const bool logoWithShadow = true;

  // 3. تصميم معلومات العميل
  static const String customerInfoLayout = 'card';
  static const bool customerInfoWithIcon = true;
  static const String customerInfoAlignment = 'center';

  // 4. تصميم الجدول
  static const String tableLayout = 'colorful';
  static const bool tableHeaderSeparate = true;
  static const bool tableWithTotalRow = true;
  static const String tableAlignment = 'center';
  static const bool showTableIcons = true;

  // 5. تصميم الأقسام
  static const String sectionsStyle = 'cards';
  static const double sectionSpacing = 28.0;
  static const bool sectionAnimations = true;

  // 6. الخطوط
  static const String fontFamily = 'Almarai';
  static const String titleFontWeight = 'extraBold';
  static const String bodyFontWeight = 'normal';

  // 7. الزخرفة
  static const bool showDecorativeLines = true;
  static const bool showPageNumbers = true;
  static const bool showWatermark = false;
  static const String cornerStyle = 'rounded';

  // ===== قياسات الخطوط =====
  // مُحسّنة لقياس A4 (210×297mm)
  static const double titleFontSizeValue = 22.0; // عنوان الفاتورة - كبير وواضح
  static const double subtitleFontSizeValue = 16.0; // العناوين الفرعية
  static const double headerFontSizeValue = 13.0; // هيدر الجدول
  static const double bodyFontSizeValue = 11.5; // النص الأساسي
  static const double smallFontSizeValue = 10.0; // النص الصغير
  static const double footerFontSizeValue = 9.0; // التذييل

  // ===== قياسات الأقسام =====
  // مُحسّنة لقياس A4 (210×297mm)
  static const double headerHeightMM =
      55.0; // ارتفاع الهيدر - أكبر للقالب الملون
  static const double sectionSpacingMM = 15.0; // تباعد الأقسام
  static const double tableRowHeightMM = 10.0; // ارتفاع صف الجدول
  static const double logoSizeMM = 45.0; // حجم الشعار - أكبر

  // ===== خصائص التصميم الإضافية للقالب الملون =====
  static const double headerPaddingValue = 25.0;
  static const double headerBorderRadiusValue = 15.0;
  static const double companyNameFontSizeValue = 24.0;
  static const double companyInfoFontSizeValue = 13.0;
  static const double invoiceTitleFontSizeValue = 22.0;
  static const double invoiceInfoFontSizeValue = 13.0;
  static const double logoWidthValue = 90.0;
  static const double logoHeightValue = 90.0;
  static const String logoColorValue = '#E74C3C';

  static const double customerInfoPaddingValue = 18.0;
  static const double customerInfoBorderWidthValue = 2.0;
  static const double customerInfoBorderRadiusValue = 10.0;
  static const double customerInfoTitleFontSizeValue = 18.0;
  static const double customerInfoTextFontSizeValue = 13.0;

  static const double tableBorderWidthValue = 1.0;
  static const double tableCellPaddingValue = 5.0;
  static const double tableHeaderFontSizeValue = 13.0;
  static const double tableRowFontSizeValue = 11.5;
  static const bool alternateRowColorsValue = true;
  static const Color alternateRowColorValue = Color(0xFFFDEBD0);

  static const double footerPaddingValue = 15.0;
  static const double footerBorderWidthValue = 2.0;

  static const bool useRoundCorners = true;
  static const bool useGradientHeader = true;
  static const bool showBorderAroundTable = true;
  static const double headerHeightFactor = 1.2;
  static const String tableStyle = 'colorful';
  static const bool showInvoiceNumberLarge = true;
  static const bool useCardStyleForSections = true;

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
        'secondaryColor': _colorToHex(secondaryColorValue),

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
        // هوامش الجدول - القالب الملون
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
