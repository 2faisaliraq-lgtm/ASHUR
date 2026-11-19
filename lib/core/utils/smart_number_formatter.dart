import 'package:flutter/services.dart';

/// فئة تنسيق الأرقام الذكية
// ignore: avoid_classes_with_only_static_members
class SmartNumberFormatter {
  /// تنسيق رقم بناءً على الإعدادات المحددة
  static String format(
    double number, {
    String decimalSeparator = '.',
    String thousandsSeparator = ',',
    int decimalPlaces = 2,
    bool showThousandsSeparator = true,
    bool showLeadingZero = true,
    bool smartDecimalSeparator = true,
    String numberFormat = 'en',
  }) {
    // تحويل الرقم إلى نص
    var numberStr = number.toStringAsFixed(decimalPlaces);

    // فصل الجزء الصحيح والعشري
    var parts = numberStr.split('.');
    var integerPart = parts[0];
    var decimalPart = parts.length > 1 ? parts[1] : '';

    // إزالة الأصفار الزائدة من الجزء العشري إذا كان الفاصل العشري ذكي
    if (smartDecimalSeparator && decimalPart.isNotEmpty) {
      decimalPart = decimalPart.replaceAll(RegExp(r'0+$'), '');
    }

    // تطبيق فاصل الآلاف
    if (showThousandsSeparator && integerPart.length > 3) {
      integerPart = addThousandsSeparator(integerPart, thousandsSeparator);
    }

    // تحويل الأرقام إلى العربية إذا لزم الأمر
    if (numberFormat == 'ar') {
      integerPart = convertToArabicNumbers(integerPart);
      decimalPart = convertToArabicNumbers(decimalPart);
    }

    // تجميع النتيجة النهائية
    var result = integerPart;

    if (decimalPart.isNotEmpty) {
      result += decimalSeparator + decimalPart;
    } else if (!smartDecimalSeparator && decimalPlaces > 0) {
      // إضافة الأصفار العشرية إذا لم يكن الفاصل ذكي
      var zeros = '0' * decimalPlaces;
      if (numberFormat == 'ar') {
        zeros = convertToArabicNumbers(zeros);
      }
      result += decimalSeparator + zeros;
    }

    // إضافة الصفر البادئ إذا لزم الأمر
    if (!showLeadingZero && result.startsWith('0$decimalSeparator')) {
      result = result.substring(1);
    } else if (!showLeadingZero && result.startsWith('٠$decimalSeparator')) {
      result = result.substring(1);
    }

    return result;
  }

  /// إضافة فاصل الآلاف
  static String addThousandsSeparator(String number, String separator) {
    var result = '';
    var count = 0;

    for (var i = number.length - 1; i >= 0; i--) {
      if (count == 3) {
        result = '$separator$result';
        count = 0;
      }
      result = '${number[i]}$result';
      count++;
    }

    return result;
  }

  /// تحويل الأرقام الإنجليزية إلى العربية
  static String convertToArabicNumbers(String text) {
    const arabicNumbers = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };

    var result = text;
    arabicNumbers.forEach((english, arabic) {
      result = result.replaceAll(english, arabic);
    });

    return result;
  }

  /// تحويل الأرقام العربية إلى الإنجليزية
  static String convertToEnglishNumbers(String text) {
    const englishNumbers = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    var result = text;
    englishNumbers.forEach((arabic, english) {
      result = result.replaceAll(arabic, english);
    });

    return result;
  }
}

/// TextInputFormatter للتنسيق التلقائي أثناء الكتابة
class SmartNumberInputFormatter extends TextInputFormatter {

  SmartNumberInputFormatter({
    this.decimalSeparator = '.',
    this.thousandsSeparator = ',',
    this.decimalPlaces = 2,
    this.showThousandsSeparator = true,
    this.autoThousandsSeparator = true,
    this.numberFormat = 'en',
  });
  final String decimalSeparator;
  final String thousandsSeparator;
  final int decimalPlaces;
  final bool showThousandsSeparator;
  final bool autoThousandsSeparator;
  final String numberFormat;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // تحويل الأرقام العربية إلى إنجليزية للمعالجة
    var text = SmartNumberFormatter.convertToEnglishNumbers(newValue.text);

    // إزالة جميع الفواصل الموجودة
    text = text.replaceAll(thousandsSeparator, '');

    // التحقق من صحة الرقم
    if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(text)) {
      return oldValue;
    }

    // تطبيق التنسيق التلقائي
    if (autoThousandsSeparator && showThousandsSeparator) {
      var parts = text.split('.');
      var integerPart = parts[0];
      var decimalPart = parts.length > 1 ? parts[1] : '';

      // تطبيق فاصل الآلاف على الجزء الصحيح
      if (integerPart.length > 3) {
        integerPart = SmartNumberFormatter.addThousandsSeparator(
          integerPart,
          thousandsSeparator,
        );
      }

      // تجميع النص المنسق
      var formattedText = integerPart;
      if (decimalPart.isNotEmpty || text.contains('.')) {
        formattedText += decimalSeparator;
        if (decimalPart.isNotEmpty) {
          // تحديد عدد الأرقام العشرية المسموحة
          if (decimalPart.length > decimalPlaces) {
            decimalPart = decimalPart.substring(0, decimalPlaces);
          }
          formattedText += decimalPart;
        }
      }

      // تحويل إلى الأرقام العربية إذا لزم الأمر
      if (numberFormat == 'ar') {
        formattedText = SmartNumberFormatter.convertToArabicNumbers(formattedText);
      }

      // حساب موضع المؤشر الجديد
      var cursorPosition = formattedText.length;

      return TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: cursorPosition),
      );
    }

    return newValue;
  }
}
