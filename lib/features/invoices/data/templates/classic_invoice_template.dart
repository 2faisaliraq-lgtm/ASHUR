import 'package:material_ui/material_ui.dart';

import '../../domain/entities/invoice_template_entity.dart';

/// القالب الكلاسيكي للفواتير - تصميم تقليدي محافظ
class ClassicInvoiceTemplate {
  // ===== ألوان القالب =====
  static const Color headerColorValue = Color(0xFF1B365D); // أزرق غامق
  static const Color accentColorValue = Color(0xFFD4AF37); // ذهبي
  static const Color headerTextColorValue = Color(0xFFFFFFFF); // أبيض
  static const Color bodyTextColorValue = Color(0xFF000000); // أسود

  // ===== نصوص القالب =====
  static const String templateName = 'القالب الكلاسيكي';
  static const String footerTextValue = 'شكراً لتعاملكم معنا';

  // ===== إعدادات القالب =====
  static const String templateId = 'template_classic';
  static const String logoPositionValue = 'right';
  static const bool showLogoValue = true;
  static const bool showCompanyInfoValue = true;
  static const bool showCustomerInfoValue = true;
  static const bool showItemsTableValue = true;
  static const bool showNotesValue = true;
  static const bool showSignatureValue = false;
  static const bool isDefaultValue = true;

  // ===== أبعاد ورقة A4 =====
  static const String pageFormat = 'A4'; // A4, Letter, Legal
  static const double pageWidthMM = 210.0; // عرض صفحة A4 بالمليمتر
  static const double pageHeightMM = 297.0; // ارتفاع صفحة A4 بالمليمتر
  static const double pageMarginTopMM = 0.0; // الهامش العلوي - صفر
  static const double pageMarginBottomMM = 0.0; // الهامش السفلي - صفر
  static const double pageMarginLeftMM = 0.0; // الهامش الأيسر - صفر
  static const double pageMarginRightMM = 0.0; // الهامش الأيمن - صفر
  static const bool usePortraitOrientation = true; // وضع عمودي

  // ===== الخصائص الهيكلية - تصميم تقليدي =====

  // 1. تصميم الهيدر
  static const String headerLayoutStyle = 'standard'; // تصميم قياسي
  static const bool headerFullWidth = false; // ليس بعرض الصفحة
  static const bool showHeaderPattern = false; // بدون زخرفة
  static const String headerPatternType = 'none';

  // 2. تصميم الشعار
  static const String logoShape = 'square'; // مربع
  static const bool logoWithBorder = false; // بدون إطار
  static const bool logoWithShadow = false; // بدون ظل

  // 3. تصميم معلومات العميل
  static const String customerInfoLayout = 'inline'; // في السطر
  static const bool customerInfoWithIcon = false; // بدون أيقونات
  static const String customerInfoAlignment = 'right'; // محاذاة لليمين

  // 4. تصميم الجدول
  static const String tableLayout = 'traditional'; // جدول تقليدي
  static const bool tableHeaderSeparate = false; // هيدر عادي
  static const bool tableWithTotalRow = false; // بدون صف إجمالي مميز
  static const String tableAlignment = 'center';
  static const bool showTableIcons = false;

  // 5. تصميم الأقسام
  static const String sectionsStyle = 'plain'; // بسيط
  static const double sectionSpacing = 15.0; // تباعد عادي
  static const bool sectionAnimations = false; // بدون تأثيرات

  // 6. الخطوط
  static const String fontFamily = 'Cairo';
  static const String titleFontWeight = 'bold';
  static const String bodyFontWeight = 'normal';

  // 7. الزخرفة
  static const bool showDecorativeLines = false; // بدون خطوط زخرفية
  static const bool showPageNumbers = false; // بدون أرقام صفحات
  static const bool showWatermark = false; // بدون علامة مائية
  static const String cornerStyle = 'sharp'; // زوايا حادة

  // ===== خصائص تصميم الهيدر =====
  static const double headerPaddingValue = 20.0;
  static const double headerBorderRadiusValue = 0.0; // زوايا حادة
  static const double companyNameFontSizeValue = 24.0;
  static const double companyInfoFontSizeValue = 12.0;
  static const double invoiceTitleFontSizeValue = 20.0;
  static const double invoiceInfoFontSizeValue = 12.0;
  static const double logoWidthValue = 120.0; // زيادة الحجم
  static const double logoHeightValue = 120.0; // زيادة الحجم
  static const String logoColorValue = '#D4AF37'; // لون ذهبي مثل شعار التطبيق

  // ===== خصائص تصميم معلومات العميل =====
  static const double customerInfoPaddingValue = 15.0;
  static const double customerInfoBorderWidthValue = 2.0;
  static const double customerInfoBorderRadiusValue = 0.0; // زوايا حادة
  static const double customerInfoTitleFontSizeValue = 16.0;
  static const double customerInfoTextFontSizeValue = 12.0;

  // ===== خصائص تصميم الجدول =====
  static const double tableBorderWidthValue = 1.0; // حدود واضحة
  static const double tableCellPaddingValue = 5.0;
  static const double tableHeaderFontSizeValue = 12.0;
  static const double tableRowFontSizeValue = 10.0;
  static const bool alternateRowColorsValue = true;
  static const Color alternateRowColorValue = Color(0xFFF5F5F5);

  // ===== خصائص تصميم التذييل =====
  static const double footerPaddingValue = 10.0;
  static const double footerBorderWidthValue = 2.0;
  static const double footerFontSizeValue = 10.0;

  // ===== خصائص تصميم إضافية =====
  static const bool useRoundCorners = false;
  static const bool useGradientHeader = false;
  static const bool showBorderAroundTable = true;
  static const double headerHeightFactor = 1.0;
  static const String tableStyle = 'bordered';
  static const bool showInvoiceNumberLarge = false;
  static const bool useCardStyleForSections = false;

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
        // هوامش الجدول
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
