import 'package:material_ui/material_ui.dart';

import '../../domain/entities/invoice_template_entity.dart';

/// القالب العصري للفواتير - تصميم حديث ومختلف تماماً
class ModernInvoiceTemplate {
  // ===== ألوان القالب =====
  static const Color headerColorValue = Color(0xFF6C5CE7); // بنفسجي فاتح عصري
  static const Color accentColorValue = Color(0xFF00CEC9); // تركواز مشرق
  static const Color secondaryColorValue = Color(0xFFDFE6E9); // رمادي فاتح جداً
  static const Color headerTextColorValue = Color(0xFFFFFFFF); // أبيض
  static const Color bodyTextColorValue = Color(0xFF2D3436); // رمادي داكن

  // ===== نصوص القالب =====
  static const String templateName = 'القالب العصري';
  static const String footerTextValue = 'نقدر ثقتكم - شكراً لتعاملكم معنا';

  // ===== إعدادات القالب =====
  static const String templateId = 'template_modern';
  static const String logoPositionValue = 'center'; // الشعار في الوسط
  static const bool showLogoValue = true;
  static const bool showCompanyInfoValue =
      false; // إخفاء معلومات الشركة في الهيدر
  static const bool showCustomerInfoValue = true;
  static const bool showItemsTableValue = true;
  static const bool showNotesValue = true;
  static const bool showSignatureValue = true; // إظهار التوقيع
  static const bool isDefaultValue = false;

  // ===== أبعاد ورقة A4 =====
  static const String pageFormat = 'A4'; // A4, Letter, Legal
  static const double pageWidthMM = 210.0; // عرض صفحة A4 بالمليمتر
  static const double pageHeightMM = 297.0; // ارتفاع صفحة A4 بالمليمتر
  static const double pageMarginTopMM = 0.0; // الهامش العلوي - بدون هامش
  static const double pageMarginBottomMM = 0.0; // الهامش السفلي - بدون هامش
  static const double pageMarginLeftMM = 0.0; // الهامش الأيسر - بدون هامش
  static const double pageMarginRightMM = 0.0; // الهامش الأيمن - بدون هامش
  static const bool usePortraitOrientation = true; // وضع عمودي

  // ===== الخصائص الهيكلية - تصميم مختلف تماماً =====

  // 1. تصميم الهيدر
  static const String headerLayoutStyle =
      'centered'; // 'standard' أو 'centered' أو 'sidebar'
  static const bool headerFullWidth = true; // الهيدر بعرض الصفحة
  static const bool showHeaderPattern = true; // إظهار زخرفة في الهيدر
  static const String headerPatternType =
      'diagonal'; // 'diagonal', 'waves', 'dots'

  // 2. تصميم الشعار
  static const String logoShape = 'circle'; // 'square' أو 'circle' أو 'rounded'
  static const bool logoWithBorder = true; // شعار بإطار
  static const bool logoWithShadow = true; // شعار بظل

  // 3. تصميم معلومات العميل
  static const String customerInfoLayout =
      'card'; // 'card' أو 'inline' أو 'sidebar'
  static const bool customerInfoWithIcon = true; // أيقونات مع المعلومات
  static const String customerInfoAlignment =
      'left'; // 'left' أو 'center' أو 'right'

  // 4. تصميم الجدول
  static const String tableLayout =
      'modern'; // 'traditional' أو 'modern' أو 'minimal'
  static const bool tableHeaderSeparate = true; // هيدر منفصل
  static const bool tableWithTotalRow = true; // صف إجمالي مميز
  static const String tableAlignment = 'center'; // محاذاة النص
  static const bool showTableIcons = false; // أيقونات في الجدول

  // 5. تصميم الأقسام
  static const String sectionsStyle = 'cards'; // 'cards' أو 'plain' أو 'lined'
  static const double sectionSpacing = 25.0; // تباعد كبير بين الأقسام
  static const bool sectionAnimations = true; // تأثيرات بصرية

  // 6. الخطوط
  static const String fontFamily = 'Cairo'; // 'Cairo' أو 'Tajawal' أو 'Almarai'
  static const String titleFontWeight =
      'bold'; // 'normal' أو 'bold' أو 'extraBold'
  static const String bodyFontWeight = 'normal';

  // 7. الزخرفة
  static const bool showDecorativeLines = true; // خطوط زخرفية
  static const bool showPageNumbers = true; // أرقام الصفحات
  static const bool showWatermark = false; // علامة مائية
  static const String cornerStyle =
      'rounded'; // 'sharp' أو 'rounded' أو 'ornate'

  // ===== خصائص تصميم الهيدر =====
  static const double headerPaddingValue = 30.0;
  static const double headerBorderRadiusValue = 25.0;
  static const double companyNameFontSizeValue = 28.0;
  static const double companyInfoFontSizeValue = 14.0;
  static const double invoiceTitleFontSizeValue = 24.0;
  static const double invoiceInfoFontSizeValue = 13.0;
  static const double logoWidthValue = 100.0;
  static const double logoHeightValue = 100.0;

  // ===== خصائص تصميم معلومات العميل =====
  static const double customerInfoPaddingValue = 20.0;
  static const double customerInfoBorderWidthValue = 3.0;
  static const double customerInfoBorderRadiusValue = 15.0;
  static const double customerInfoTitleFontSizeValue = 18.0;
  static const double customerInfoTextFontSizeValue = 13.0;

  // ===== خصائص تصميم الجدول =====
  static const double tableBorderWidthValue = 0.0;
  static const double tableCellPaddingValue = 5.0;
  static const double tableHeaderFontSizeValue = 14.0;
  static const double tableRowFontSizeValue = 11.0;
  static const bool alternateRowColorsValue = false;
  static const Color alternateRowColorValue = Color(0xFFFFFFFF);

  // ===== خصائص تصميم التذييل =====
  static const double footerPaddingValue = 15.0;
  static const double footerBorderWidthValue = 3.0;
  static const double footerFontSizeValue = 11.0;

  // ===== خصائص تصميم إضافية =====
  static const bool useRoundCorners = true;
  static const bool useGradientHeader = true;
  static const bool showBorderAroundTable = false;
  static const double headerHeightFactor = 1.5;
  static const String tableStyle = 'minimal';
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
        // هوامش الجدول - القالب العصري
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

  /// الحصول على اللون الإضافي كـ Color
  static Color get secondaryColor => secondaryColorValue;

  /// الحصول على لون الصفوف البديلة كـ Color
  static Color get alternateRowColor => alternateRowColorValue;
}
