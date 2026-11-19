import 'package:material_ui/material_ui.dart';

/// مساعد إدارة الاتجاه RTL في التطبيق
// ignore: avoid_classes_with_only_static_members
class RTLHelper {
  /// التحقق من اتجاه النص الحالي
  static bool isRTL(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl;
  }

  /// إجبار الاتجاه RTL للنص العربي
  static Widget forceRTL({required Widget child}) {
    return Directionality(textDirection: TextDirection.rtl, child: child);
  }

  /// إجبار الاتجاه LTR للنص الإنجليزي
  static Widget forceLTR({required Widget child}) {
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }

  /// تطبيق الاتجاه المناسب حسب اللغة
  static Widget autoDirection({required Widget child, required String text}) {
    // التحقق من وجود أحرف عربية
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    final isArabic = arabicRegex.hasMatch(text);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: child,
    );
  }

  /// تطبيق محاذاة النص المناسبة
  static TextAlign getTextAlign(BuildContext context, {TextAlign? fallback}) {
    if (isRTL(context)) {
      return TextAlign.right;
    }
    return fallback ?? TextAlign.left;
  }

  /// تطبيق محاذاة النص للوسط مع دعم RTL
  static TextAlign getCenterAlign(BuildContext context) {
    return TextAlign.center;
  }

  /// تطبيق محاذاة النص للبداية مع دعم RTL
  static TextAlign getStartAlign(BuildContext context) {
    if (isRTL(context)) {
      return TextAlign.right;
    }
    return TextAlign.left;
  }

  /// تطبيق محاذاة النص للنهاية مع دعم RTL
  static TextAlign getEndAlign(BuildContext context) {
    if (isRTL(context)) {
      return TextAlign.left;
    }
    return TextAlign.right;
  }

  /// الحصول على EdgeInsets مع دعم RTL
  static EdgeInsetsGeometry getEdgeInsets({
    double top = 0,
    double bottom = 0,
    double start = 0,
    double end = 0,
  }) {
    return EdgeInsetsDirectional.only(
      top: top,
      bottom: bottom,
      start: start,
      end: end,
    );
  }

  /// الحصول على EdgeInsets متماثل مع دعم RTL
  static EdgeInsets getSymmetricEdgeInsets({
    double vertical = 0,
    double horizontal = 0,
  }) {
    return EdgeInsets.symmetric(vertical: vertical, horizontal: horizontal);
  }

  /// الحصول على BorderRadius مع دعم RTL
  static BorderRadiusGeometry getBorderRadius({
    double topStart = 0,
    double topEnd = 0,
    double bottomStart = 0,
    double bottomEnd = 0,
  }) {
    return BorderRadiusDirectional.only(
      topStart: Radius.circular(topStart),
      topEnd: Radius.circular(topEnd),
      bottomStart: Radius.circular(bottomStart),
      bottomEnd: Radius.circular(bottomEnd),
    );
  }

  /// الحصول على Alignment مع دعم RTL
  static AlignmentGeometry getAlignment(
    BuildContext context, {
    required AlignmentGeometry ltrAlignment,
    required AlignmentGeometry rtlAlignment,
  }) {
    if (isRTL(context)) {
      return rtlAlignment;
    }
    return ltrAlignment;
  }

  /// الحصول على MainAxisAlignment للبداية مع دعم RTL
  static MainAxisAlignment getStartMainAxisAlignment(BuildContext context) {
    if (isRTL(context)) {
      return MainAxisAlignment.end;
    }
    return MainAxisAlignment.start;
  }

  /// الحصول على MainAxisAlignment للنهاية مع دعم RTL
  static MainAxisAlignment getEndMainAxisAlignment(BuildContext context) {
    if (isRTL(context)) {
      return MainAxisAlignment.start;
    }
    return MainAxisAlignment.end;
  }

  /// الحصول على CrossAxisAlignment للبداية مع دعم RTL
  static CrossAxisAlignment getStartCrossAxisAlignment(BuildContext context) {
    if (isRTL(context)) {
      return CrossAxisAlignment.end;
    }
    return CrossAxisAlignment.start;
  }

  /// الحصول على CrossAxisAlignment للنهاية مع دعم RTL
  static CrossAxisAlignment getEndCrossAxisAlignment(BuildContext context) {
    if (isRTL(context)) {
      return CrossAxisAlignment.start;
    }
    return CrossAxisAlignment.end;
  }
}

/// Extension لتسهيل استخدام RTL
extension RTLExtension on BuildContext {
  /// التحقق من اتجاه RTL
  bool get isRTL => RTLHelper.isRTL(this);

  /// الحصول على محاذاة البداية
  TextAlign get startAlign => RTLHelper.getStartAlign(this);

  /// الحصول على محاذاة النهاية
  TextAlign get endAlign => RTLHelper.getEndAlign(this);

  /// الحصول على محاذاة الوسط
  TextAlign get centerAlign => RTLHelper.getCenterAlign(this);
}
