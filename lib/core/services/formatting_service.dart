import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../utils/smart_number_formatter.dart';
import 'settings_service.dart';

/// خدمة التنسيق المركزية لجميع أقسام التطبيق
class FormattingService {
  /// الحصول على instance الوحيد من الخدمة
  factory FormattingService() => _instance ??= FormattingService._();
  FormattingService._();
  static FormattingService? _instance;

  // إعدادات التنسيق الحالية
  Map<String, dynamic> _currentSettings = {};
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  /// تهيئة خدمة التنسيق
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_initCompleter != null) {
      // إذا كانت التهيئة جارية بالفعل، انتظر حتى تكتمل
      await _initCompleter!.future;
      return;
    }

    _initCompleter = Completer<void>();

    try {
      _currentSettings = await SettingsService.getFormattingSettings();
      _isInitialized = true;
      _initCompleter!.complete();
    } on Exception catch (_) {
      // خطأ في تهيئة خدمة التنسيق - استخدام الإعدادات الافتراضية
      _currentSettings = _getDefaultSettings();
      _isInitialized = true;
      _initCompleter!.complete();
    } finally {
      _initCompleter = null;
    }
  }

  /// التأكد من أن الخدمة مهيأة قبل الاستخدام
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// إعادة تحميل الإعدادات
  Future<void> reload() async {
    _currentSettings = await SettingsService.getFormattingSettings();
  }

  /// الحصول على الإعدادات الافتراضية
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'dateFormat': 'dd/MM/yyyy',
      'timeFormat': '24h',
      'dateTimeFormat': 'dd/MM/yyyy HH:mm',
      'showWeekday': false,
      'showSeconds': false,
      'calendarType': 'gregorian',
      'numberFormat': 'en',
      'decimalSeparator': '.',
      'thousandsSeparator': ',',
      'decimalPlaces': 2,
      'showThousandsSeparator': true,
      'showLeadingZero': true,
      'smartDecimalSeparator': true,
      'autoThousandsSeparator': true,
      'defaultCurrency': 'IQD',
      'currencyPosition': 'before',
      'currencySymbol': 'د.ع',
      'showCurrencySymbol': true,
      'showCurrencyCode': false,
      'currencyFormat': 'symbol',
      'timezone': 'Asia/Baghdad',
      'autoDetectTimezone': true,
      'locale': 'ar_IQ',
    };
  }

  // ==================== تنسيق الأرقام ====================

  /// تنسيق رقم عادي
  String formatNumber(double number) {
    if (!_isInitialized) {
      // استخدام الإعدادات الافتراضية إذا لم تكن الخدمة مهيأة
      final defaultSettings = _getDefaultSettings();
      return SmartNumberFormatter.format(
        number,
        decimalSeparator: defaultSettings['decimalSeparator'] ?? '.',
        thousandsSeparator: defaultSettings['thousandsSeparator'] ?? ',',
        decimalPlaces: defaultSettings['decimalPlaces'] ?? 2,
        showThousandsSeparator:
            defaultSettings['showThousandsSeparator'] ?? true,
        showLeadingZero: defaultSettings['showLeadingZero'] ?? true,
        smartDecimalSeparator: defaultSettings['smartDecimalSeparator'] ?? true,
        numberFormat: defaultSettings['numberFormat'] ?? 'en',
      );
    }

    return SmartNumberFormatter.format(
      number,
      decimalSeparator: _currentSettings['decimalSeparator'] ?? '.',
      thousandsSeparator: _currentSettings['thousandsSeparator'] ?? ',',
      decimalPlaces: _currentSettings['decimalPlaces'] ?? 2,
      showThousandsSeparator:
          _currentSettings['showThousandsSeparator'] ?? true,
      showLeadingZero: _currentSettings['showLeadingZero'] ?? true,
      smartDecimalSeparator: _currentSettings['smartDecimalSeparator'] ?? true,
      numberFormat: _currentSettings['numberFormat'] ?? 'en',
    );
  }

  /// تنسيق رقم صحيح (بدون أرقام عشرية)
  String formatInteger(int number) {
    if (!_isInitialized) {
      final defaultSettings = _getDefaultSettings();
      return SmartNumberFormatter.format(
        number.toDouble(),
        decimalSeparator: defaultSettings['decimalSeparator'] ?? '.',
        thousandsSeparator: defaultSettings['thousandsSeparator'] ?? ',',
        decimalPlaces: 0,
        showThousandsSeparator:
            defaultSettings['showThousandsSeparator'] ?? true,
        showLeadingZero: defaultSettings['showLeadingZero'] ?? true,
        numberFormat: defaultSettings['numberFormat'] ?? 'en',
      );
    }

    return SmartNumberFormatter.format(
      number.toDouble(),
      decimalSeparator: _currentSettings['decimalSeparator'] ?? '.',
      thousandsSeparator: _currentSettings['thousandsSeparator'] ?? ',',
      decimalPlaces: 0,
      showThousandsSeparator:
          _currentSettings['showThousandsSeparator'] ?? true,
      showLeadingZero: _currentSettings['showLeadingZero'] ?? true,
      numberFormat: _currentSettings['numberFormat'] ?? 'en',
    );
  }

  /// تنسيق نسبة مئوية
  String formatPercentage(double percentage) {
    if (!_isInitialized) {
      final defaultSettings = _getDefaultSettings();
      var formattedNumber = SmartNumberFormatter.format(
        percentage,
        decimalSeparator: defaultSettings['decimalSeparator'] ?? '.',
        thousandsSeparator: defaultSettings['thousandsSeparator'] ?? ',',
        decimalPlaces: 1,
        showThousandsSeparator: false,
        showLeadingZero: defaultSettings['showLeadingZero'] ?? true,
        smartDecimalSeparator: defaultSettings['smartDecimalSeparator'] ?? true,
        numberFormat: defaultSettings['numberFormat'] ?? 'en',
      );
      return '$formattedNumber%';
    }

    var formattedNumber = SmartNumberFormatter.format(
      percentage,
      decimalSeparator: _currentSettings['decimalSeparator'] ?? '.',
      thousandsSeparator: _currentSettings['thousandsSeparator'] ?? ',',
      decimalPlaces: 1,
      showThousandsSeparator: false,
      showLeadingZero: _currentSettings['showLeadingZero'] ?? true,
      smartDecimalSeparator: _currentSettings['smartDecimalSeparator'] ?? true,
      numberFormat: _currentSettings['numberFormat'] ?? 'en',
    );

    return '$formattedNumber%';
  }

  // ==================== تنسيق العملات ====================

  /// تنسيق مبلغ مالي
  String formatCurrency(double amount, {String? currencyCode}) {
    if (!_isInitialized) {
      final defaultSettings = _getDefaultSettings();
      var formattedAmount = SmartNumberFormatter.format(
        amount,
        decimalSeparator: defaultSettings['decimalSeparator'] ?? '.',
        thousandsSeparator: defaultSettings['thousandsSeparator'] ?? ',',
        decimalPlaces: defaultSettings['decimalPlaces'] ?? 2,
        showThousandsSeparator:
            defaultSettings['showThousandsSeparator'] ?? true,
        showLeadingZero: defaultSettings['showLeadingZero'] ?? true,
        smartDecimalSeparator: defaultSettings['smartDecimalSeparator'] ?? true,
        numberFormat: defaultSettings['numberFormat'] ?? 'en',
      );

      var currency =
          currencyCode ?? defaultSettings['defaultCurrency'] ?? 'IQD';
      var symbol = _getCurrencySymbol(currency);
      var position = defaultSettings['currencyPosition'] ?? 'before';
      var format = defaultSettings['currencyFormat'] ?? 'symbol';
      var showSymbol = defaultSettings['showCurrencySymbol'] ?? true;
      var showCode = defaultSettings['showCurrencyCode'] ?? false;

      var currencyDisplay = '';
      if (format == 'symbol' && showSymbol) {
        currencyDisplay = symbol;
      } else if (format == 'code' && showCode) {
        currencyDisplay = currency;
      } else if (format == 'both' && showSymbol && showCode) {
        currencyDisplay = '$symbol $currency';
      } else if (showSymbol) {
        currencyDisplay = symbol;
      }

      if (position == 'before') {
        return '$currencyDisplay$formattedAmount';
      } else {
        return '$formattedAmount$currencyDisplay';
      }
    }

    var formattedAmount = SmartNumberFormatter.format(
      amount,
      decimalSeparator: _currentSettings['decimalSeparator'] ?? '.',
      thousandsSeparator: _currentSettings['thousandsSeparator'] ?? ',',
      decimalPlaces: _currentSettings['decimalPlaces'] ?? 2,
      showThousandsSeparator:
          _currentSettings['showThousandsSeparator'] ?? true,
      showLeadingZero: _currentSettings['showLeadingZero'] ?? true,
      smartDecimalSeparator: _currentSettings['smartDecimalSeparator'] ?? true,
      numberFormat: _currentSettings['numberFormat'] ?? 'en',
    );

    var currency = currencyCode ?? _currentSettings['defaultCurrency'] ?? 'IQD';
    var symbol = _getCurrencySymbol(currency);
    var position = _currentSettings['currencyPosition'] ?? 'before';
    var format = _currentSettings['currencyFormat'] ?? 'symbol';
    var showSymbol = _currentSettings['showCurrencySymbol'] ?? true;
    var showCode = _currentSettings['showCurrencyCode'] ?? false;

    var currencyDisplay = '';
    if (format == 'symbol' && showSymbol) {
      currencyDisplay = symbol;
    } else if (format == 'code' && showCode) {
      currencyDisplay = currency;
    } else if (format == 'both' && showSymbol && showCode) {
      currencyDisplay = '$symbol $currency';
    } else if (showSymbol) {
      currencyDisplay = symbol;
    }

    if (position == 'before') {
      return '$currencyDisplay$formattedAmount';
    } else {
      return '$formattedAmount$currencyDisplay';
    }
  }

  /// الحصول على رمز العملة
  String _getCurrencySymbol(String currencyCode) {
    const currencySymbols = {
      'USD': r'$',
      'EUR': '€',
      'IQD': 'د.ع',
      'SAR': 'ر.س',
      'AED': 'د.إ',
      'GBP': '£',
      'JPY': '¥',
      'CNY': '¥',
    };
    return currencySymbols[currencyCode] ?? currencyCode;
  }

  // ==================== تنسيق التاريخ والوقت ====================

  /// تنسيق التاريخ
  String formatDate(DateTime date) {
    if (!_isInitialized) {
      final defaultSettings = _getDefaultSettings();
      var format = defaultSettings['dateFormat'] ?? 'dd/MM/yyyy';
      var showWeekday = defaultSettings['showWeekday'] ?? false;

      var formattedDate = DateFormat(format).format(date);

      if (showWeekday) {
        var weekday = _getWeekdayName(date.weekday);
        formattedDate = '$weekday، $formattedDate';
      }

      return formattedDate;
    }

    var format = _currentSettings['dateFormat'] ?? 'dd/MM/yyyy';
    var showWeekday = _currentSettings['showWeekday'] ?? false;

    var formattedDate = DateFormat(format).format(date);

    if (showWeekday) {
      var weekday = _getWeekdayName(date.weekday);
      formattedDate = '$weekday، $formattedDate';
    }

    return formattedDate;
  }

  /// تنسيق الوقت
  String formatTime(DateTime time) {
    if (!_isInitialized) {
      final defaultSettings = _getDefaultSettings();
      var timeFormat = defaultSettings['timeFormat'] ?? '24h';
      var showSeconds = defaultSettings['showSeconds'] ?? false;

      String format;
      if (timeFormat == '12h') {
        format = showSeconds ? 'h:mm:ss a' : 'h:mm a';
      } else {
        format = showSeconds ? 'HH:mm:ss' : 'HH:mm';
      }

      return DateFormat(format).format(time);
    }

    var timeFormat = _currentSettings['timeFormat'] ?? '24h';
    var showSeconds = _currentSettings['showSeconds'] ?? false;

    String format;
    if (timeFormat == '12h') {
      format = showSeconds ? 'h:mm:ss a' : 'h:mm a';
    } else {
      format = showSeconds ? 'HH:mm:ss' : 'HH:mm';
    }

    return DateFormat(format).format(time);
  }

  /// تنسيق التاريخ والوقت معاً
  String formatDateTime(DateTime dateTime) {
    if (!_isInitialized) {
      final defaultSettings = _getDefaultSettings();
      var dateFormat = defaultSettings['dateFormat'] ?? 'dd/MM/yyyy';
      var timeFormat = defaultSettings['timeFormat'] ?? '24h';
      var showSeconds = defaultSettings['showSeconds'] ?? false;
      var showWeekday = defaultSettings['showWeekday'] ?? false;

      String timePattern;
      if (timeFormat == '12h') {
        timePattern = showSeconds ? 'h:mm:ss a' : 'h:mm a';
      } else {
        timePattern = showSeconds ? 'HH:mm:ss' : 'HH:mm';
      }

      var pattern = '$dateFormat $timePattern';
      var formatted = DateFormat(pattern).format(dateTime);

      if (showWeekday) {
        var weekday = _getWeekdayName(dateTime.weekday);
        formatted = '$weekday، $formatted';
      }

      return formatted;
    }

    var dateFormat = _currentSettings['dateFormat'] ?? 'dd/MM/yyyy';
    var timeFormat = _currentSettings['timeFormat'] ?? '24h';
    var showSeconds = _currentSettings['showSeconds'] ?? false;
    var showWeekday = _currentSettings['showWeekday'] ?? false;

    String timePattern;
    if (timeFormat == '12h') {
      timePattern = showSeconds ? 'h:mm:ss a' : 'h:mm a';
    } else {
      timePattern = showSeconds ? 'HH:mm:ss' : 'HH:mm';
    }

    var pattern = '$dateFormat $timePattern';
    var formatted = DateFormat(pattern).format(dateTime);

    if (showWeekday) {
      var weekday = _getWeekdayName(dateTime.weekday);
      formatted = '$weekday، $formatted';
    }

    return formatted;
  }

  /// الحصول على اسم يوم الأسبوع
  String _getWeekdayName(int weekday) {
    const weekdays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return weekdays[weekday - 1];
  }

  // ==================== تنسيق خاص بالأقسام ====================

  /// تنسيق كمية المخزون
  String formatStockQuantity(int quantity) {
    return formatInteger(quantity);
  }

  /// تنسيق سعر المنتج
  String formatProductPrice(double price, {String? currency}) {
    return formatCurrency(price, currencyCode: currency);
  }

  /// تنسيق إجمالي الفاتورة
  String formatInvoiceTotal(double total, {String? currency}) {
    return formatCurrency(total, currencyCode: currency);
  }

  /// تنسيق مبلغ المصروف
  String formatExpenseAmount(double amount, {String? currency}) {
    return formatCurrency(amount, currencyCode: currency);
  }

  /// تنسيق مبلغ الإيجار
  String formatRentalAmount(double amount, {String? currency}) {
    return formatCurrency(amount, currencyCode: currency);
  }

  /// تنسيق تكلفة الصيانة
  String formatMaintenanceCost(double cost, {String? currency}) {
    return formatCurrency(cost, currencyCode: currency);
  }

  /// تنسيق حساب العميل
  String formatCustomerBalance(double balance, {String? currency}) {
    return formatCurrency(balance, currencyCode: currency);
  }

  /// تنسيق تاريخ الفاتورة
  String formatInvoiceDate(DateTime date) {
    return formatDate(date);
  }

  /// تنسيق تاريخ انتهاء الصلاحية
  String formatExpiryDate(DateTime date) {
    return formatDate(date);
  }

  /// تنسيق تاريخ ووقت آخر تحديث
  String formatLastUpdated(DateTime dateTime) {
    return formatDateTime(dateTime);
  }

  // ==================== مساعدات للـ TextInputFormatter ====================

  /// الحصول على TextInputFormatter للأرقام
  SmartNumberInputFormatter getNumberInputFormatter() {
    if (!_isInitialized) {
      final defaultSettings = _getDefaultSettings();
      return SmartNumberInputFormatter(
        decimalSeparator: defaultSettings['decimalSeparator'] ?? '.',
        thousandsSeparator: defaultSettings['thousandsSeparator'] ?? ',',
        decimalPlaces: defaultSettings['decimalPlaces'] ?? 2,
        showThousandsSeparator:
            defaultSettings['showThousandsSeparator'] ?? true,
        autoThousandsSeparator:
            defaultSettings['autoThousandsSeparator'] ?? true,
        numberFormat: defaultSettings['numberFormat'] ?? 'en',
      );
    }

    return SmartNumberInputFormatter(
      decimalSeparator: _currentSettings['decimalSeparator'] ?? '.',
      thousandsSeparator: _currentSettings['thousandsSeparator'] ?? ',',
      decimalPlaces: _currentSettings['decimalPlaces'] ?? 2,
      showThousandsSeparator:
          _currentSettings['showThousandsSeparator'] ?? true,
      autoThousandsSeparator:
          _currentSettings['autoThousandsSeparator'] ?? true,
      numberFormat: _currentSettings['numberFormat'] ?? 'en',
    );
  }

  /// الحصول على TextInputFormatter للأسعار
  SmartNumberInputFormatter getPriceInputFormatter() {
    if (!_isInitialized) {
      final defaultSettings = _getDefaultSettings();
      return SmartNumberInputFormatter(
        decimalSeparator: defaultSettings['decimalSeparator'] ?? '.',
        thousandsSeparator: defaultSettings['thousandsSeparator'] ?? ',',
        decimalPlaces: defaultSettings['decimalPlaces'] ?? 2,
        showThousandsSeparator:
            defaultSettings['showThousandsSeparator'] ?? true,
        autoThousandsSeparator:
            defaultSettings['autoThousandsSeparator'] ?? true,
        numberFormat: defaultSettings['numberFormat'] ?? 'en',
      );
    }

    return SmartNumberInputFormatter(
      decimalSeparator: _currentSettings['decimalSeparator'] ?? '.',
      thousandsSeparator: _currentSettings['thousandsSeparator'] ?? ',',
      decimalPlaces: _currentSettings['decimalPlaces'] ?? 2,
      showThousandsSeparator:
          _currentSettings['showThousandsSeparator'] ?? true,
      autoThousandsSeparator:
          _currentSettings['autoThousandsSeparator'] ?? true,
      numberFormat: _currentSettings['numberFormat'] ?? 'en',
    );
  }

  /// الحصول على TextInputFormatter للكميات (أرقام صحيحة)
  SmartNumberInputFormatter getQuantityInputFormatter() {
    if (!_isInitialized) {
      final defaultSettings = _getDefaultSettings();
      return SmartNumberInputFormatter(
        decimalSeparator: defaultSettings['decimalSeparator'] ?? '.',
        thousandsSeparator: defaultSettings['thousandsSeparator'] ?? ',',
        decimalPlaces: 0, // كميات صحيحة فقط
        showThousandsSeparator:
            defaultSettings['showThousandsSeparator'] ?? true,
        autoThousandsSeparator:
            defaultSettings['autoThousandsSeparator'] ?? true,
        numberFormat: defaultSettings['numberFormat'] ?? 'en',
      );
    }

    return SmartNumberInputFormatter(
      decimalSeparator: _currentSettings['decimalSeparator'] ?? '.',
      thousandsSeparator: _currentSettings['thousandsSeparator'] ?? ',',
      decimalPlaces: 0, // كميات صحيحة فقط
      showThousandsSeparator:
          _currentSettings['showThousandsSeparator'] ?? true,
      autoThousandsSeparator:
          _currentSettings['autoThousandsSeparator'] ?? true,
      numberFormat: _currentSettings['numberFormat'] ?? 'en',
    );
  }

  // ==================== معلومات الإعدادات ====================

  /// الحصول على الإعدادات الحالية
  Map<String, dynamic> get currentSettings {
    if (!_isInitialized) {
      return Map.from(_getDefaultSettings());
    }
    return Map.from(_currentSettings);
  }

  /// التحقق من حالة التهيئة
  bool get isInitialized => _isInitialized;

  /// الحصول على العملة الافتراضية
  String get defaultCurrency {
    if (!_isInitialized) {
      return _getDefaultSettings()['defaultCurrency'] ?? 'IQD';
    }
    return _currentSettings['defaultCurrency'] ?? 'IQD';
  }

  /// الحصول على تنسيق الأرقام
  String get numberFormat {
    if (!_isInitialized) {
      return _getDefaultSettings()['numberFormat'] ?? 'en';
    }
    return _currentSettings['numberFormat'] ?? 'en';
  }

  /// الحصول على فاصل الأعشار
  String get decimalSeparator {
    if (!_isInitialized) {
      return _getDefaultSettings()['decimalSeparator'] ?? '.';
    }
    return _currentSettings['decimalSeparator'] ?? '.';
  }

  /// الحصول على فاصل الآلاف
  String get thousandsSeparator {
    if (!_isInitialized) {
      return _getDefaultSettings()['thousandsSeparator'] ?? ',';
    }
    return _currentSettings['thousandsSeparator'] ?? ',';
  }
}
