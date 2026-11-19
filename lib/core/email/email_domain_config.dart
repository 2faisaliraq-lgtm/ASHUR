/// إعدادات تطبيع البريد الإلكتروني حسب النطاق
///
/// هذا الملف يحتوي على قواعد التطبيع لكل نطاق بريد إلكتروني.
/// يمكن تخصيص القواعد حسب الحاجة.
class EmailDomainConfig {
  /// النطاقات التي تتجاهل النقاط في الجزء المحلي
  ///
  /// مثال: a.hmed@gmail.com = ahmed@gmail.com
  static const List<String> dotsIgnoredDomains = [
    'gmail.com',
    'googlemail.com',
  ];

  /// النطاقات التي تتجاهل ما بعد علامة +
  ///
  /// مثال: ahmed+test@gmail.com = ahmed@gmail.com
  static const List<String> plusIgnoredDomains = [
    'gmail.com',
    'googlemail.com',
    'outlook.com',
    'hotmail.com',
    'live.com',
    'yahoo.com',
    'icloud.com',
    'me.com',
  ];

  /// النطاقات المعروفة والمدعومة
  static const Map<String, String> knownDomains = {
    'gmail.com': 'Google Gmail',
    'googlemail.com': 'Google Gmail',
    'outlook.com': 'Microsoft Outlook',
    'hotmail.com': 'Microsoft Hotmail',
    'live.com': 'Microsoft Live',
    'yahoo.com': 'Yahoo Mail',
    'icloud.com': 'Apple iCloud',
    'me.com': 'Apple Me',
  };

  /// التحقق من أن النطاق يتجاهل النقاط
  static bool shouldIgnoreDots(String domain) {
    return dotsIgnoredDomains.contains(domain.toLowerCase());
  }

  /// التحقق من أن النطاق يتجاهل ما بعد +
  static bool shouldIgnorePlus(String domain) {
    return plusIgnoredDomains.contains(domain.toLowerCase());
  }

  /// الحصول على اسم مزود البريد
  static String? getProviderName(String domain) {
    return knownDomains[domain.toLowerCase()];
  }

  /// التحقق من أن النطاق معروف
  static bool isKnownDomain(String domain) {
    return knownDomains.containsKey(domain.toLowerCase());
  }
}
