/// أداة التحقق من صحة البريد الإلكتروني
///
/// توفر دوال للتحقق من صحة البريد الإلكتروني وتحليل مكوناته.
class EmailValidator {
  /// RegEx للتحقق من صحة البريد الإلكتروني
  ///
  /// يتبع معيار RFC 5322 المبسط
  static final RegExp _emailRegex = RegExp(
    r'^[\w\-\.\u0600-\u06FF%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// التحقق من صحة البريد الإلكتروني
  ///
  /// مثال:
  /// ```dart
  /// EmailValidator.isValid('ahmed@gmail.com'); // true
  /// EmailValidator.isValid('invalid-email'); // false
  /// ```
  static bool isValid(String email) {
    if (email.isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  /// فصل البريد الإلكتروني إلى جزئين: محلي ونطاق
  ///
  /// مثال:
  /// ```dart
  /// EmailValidator.splitEmail('ahmed@gmail.com');
  /// // {'local': 'ahmed', 'domain': 'gmail.com'}
  /// ```
  ///
  /// يعيد null إذا كان البريد غير صحيح
  static Map<String, String>? splitEmail(String email) {
    if (!isValid(email)) return null;

    final parts = email.trim().split('@');
    if (parts.length != 2) return null;

    return {
      'local': parts[0],
      'domain': parts[1],
    };
  }

  /// استخراج النطاق من البريد الإلكتروني
  ///
  /// مثال:
  /// ```dart
  /// EmailValidator.extractDomain('ahmed@gmail.com'); // 'gmail.com'
  /// ```
  static String? extractDomain(String email) {
    final parts = splitEmail(email);
    return parts?['domain'];
  }

  /// استخراج الجزء المحلي من البريد الإلكتروني
  ///
  /// مثال:
  /// ```dart
  /// EmailValidator.extractLocalPart('ahmed@gmail.com'); // 'ahmed'
  /// ```
  static String? extractLocalPart(String email) {
    final parts = splitEmail(email);
    return parts?['local'];
  }

  /// التحقق من أن البريد ينتمي لنطاق معين
  ///
  /// مثال:
  /// ```dart
  /// EmailValidator.isDomain('ahmed@gmail.com', 'gmail.com'); // true
  /// ```
  static bool isDomain(String email, String domain) {
    final emailDomain = extractDomain(email);
    if (emailDomain == null) return false;
    return emailDomain.toLowerCase() == domain.toLowerCase();
  }

  /// التحقق من أن البريد Gmail
  static bool isGmail(String email) {
    final domain = extractDomain(email);
    if (domain == null) return false;
    return domain.toLowerCase() == 'gmail.com' ||
        domain.toLowerCase() == 'googlemail.com';
  }

  /// التحقق من أن البريد Outlook/Hotmail
  static bool isOutlook(String email) {
    final domain = extractDomain(email);
    if (domain == null) return false;
    final lowerDomain = domain.toLowerCase();
    return lowerDomain == 'outlook.com' ||
        lowerDomain == 'hotmail.com' ||
        lowerDomain == 'live.com';
  }

  /// التحقق من أن البريد Yahoo
  static bool isYahoo(String email) {
    return isDomain(email, 'yahoo.com');
  }

  /// التحقق من أن البريد iCloud
  static bool isICloud(String email) {
    final domain = extractDomain(email);
    if (domain == null) return false;
    final lowerDomain = domain.toLowerCase();
    return lowerDomain == 'icloud.com' || lowerDomain == 'me.com';
  }
}
