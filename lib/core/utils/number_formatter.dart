import 'package:intl/intl.dart';

/// أدوات تنسيق الأرقام
// ignore: avoid_classes_with_only_static_members
class NumberFormatter {
  static final NumberFormat _numberFormat = NumberFormat('#,##0.##', 'ar');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ar',
    symbol: 'د.ع',
    decimalDigits: 2,
  );

  /// تنسيق رقم عادي
  static String formatNumber(double number) {
    return _numberFormat.format(number);
  }

  /// تنسيق عملة
  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  /// تنسيق نسبة مئوية
  static String formatPercentage(double percentage) {
    return '${formatNumber(percentage)}%';
  }

  /// تحويل نص إلى رقم
  static double? parseNumber(String text) {
    try {
      return double.parse(text.replaceAll(',', ''));
    } on Exception catch (_) {
      return null;
    }
  }
}
