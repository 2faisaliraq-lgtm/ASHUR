import 'email_domain_config.dart';
import 'email_validator.dart';

/// خدمة تطبيع البريد الإلكتروني
///
/// هذه الخدمة مسؤولة عن تطبيع عناوين البريد الإلكتروني
/// حسب قواعد كل مزود بريد.
///
/// **الاستخدام:**
/// ```dart
/// final service = EmailNormalizationService();
/// final normalized = service.normalize('A.Hmed+test@Gmail.com');
/// print(normalized); // 'ahmed@gmail.com'
/// ```
///
/// **القواعد:**
/// - Gmail: إزالة النقاط وما بعد +
/// - Outlook/Hotmail: إزالة ما بعد + فقط
/// - Yahoo: إزالة ما بعد + فقط
/// - غيرها: تحويل لأحرف صغيرة فقط
class EmailNormalizationService {
  /// Singleton instance
  static final EmailNormalizationService _instance =
      EmailNormalizationService._internal();

  factory EmailNormalizationService() => _instance;

  EmailNormalizationService._internal();

  /// تطبيع البريد الإلكتروني
  ///
  /// **المعاملات:**
  /// - `email`: البريد الإلكتروني المراد تطبيعه
  ///
  /// **يعيد:**
  /// - البريد المطبع حسب قواعد النطاق
  /// - البريد الأصلي (lowercase) إذا كان غير صحيح
  ///
  /// **أمثلة:**
  /// ```dart
  /// normalize('A.Hmed@Gmail.com')      // 'ahmed@gmail.com'
  /// normalize('ahmed+test@gmail.com')  // 'ahmed@gmail.com'
  /// normalize('ahmed.test@outlook.com') // 'ahmed.test@outlook.com'
  /// normalize('ahmed+work@outlook.com') // 'ahmed@outlook.com'
  /// ```
  String normalize(String email) {
    // التحقق من صحة البريد
    if (!EmailValidator.isValid(email)) {
      return email.toLowerCase().trim();
    }

    // فصل البريد إلى جزئين
    final parts = EmailValidator.splitEmail(email);
    if (parts == null) {
      return email.toLowerCase().trim();
    }

    var localPart = parts['local']!.toLowerCase();
    final domain = parts['domain']!.toLowerCase();

    // تطبيق قواعد النطاق
    localPart = _normalizeLocalPart(localPart, domain);

    return '$localPart@$domain';
  }

  /// تطبيع الجزء المحلي من البريد حسب النطاق
  String _normalizeLocalPart(String localPart, String domain) {
    var normalized = localPart;

    // إزالة النقاط إذا كان النطاق يتجاهلها
    if (EmailDomainConfig.shouldIgnoreDots(domain)) {
      normalized = normalized.replaceAll('.', '');
    }

    // إزالة ما بعد + إذا كان النطاق يتجاهله
    if (EmailDomainConfig.shouldIgnorePlus(domain)) {
      if (normalized.contains('+')) {
        normalized = normalized.split('+')[0];
      }
    }

    return normalized;
  }

  /// تطبيع قائمة من البريد الإلكتروني
  ///
  /// **مثال:**
  /// ```dart
  /// normalizeList(['ahmed@gmail.com', 'test@outlook.com'])
  /// ```
  List<String> normalizeList(List<String> emails) {
    return emails.map((email) => normalize(email)).toList();
  }

  /// التحقق من تطابق بريدين إلكترونيين بعد التطبيع
  ///
  /// **مثال:**
  /// ```dart
  /// areEqual('a.hmed@gmail.com', 'ahmed@gmail.com') // true
  /// areEqual('ahmed@gmail.com', 'ahmed@outlook.com') // false
  /// ```
  bool areEqual(String email1, String email2) {
    return normalize(email1) == normalize(email2);
  }

  /// الحصول على معرف المؤسسة من البريد الإلكتروني
  ///
  /// يعيد البريد المطبّع وهو نفسه معرف المؤسسة
  ///
  /// **مثال:**
  /// ```dart
  /// getOrganizationId('ahmed@gmail.com')      // 'ahmed@gmail.com'
  /// getOrganizationId('a.hmed+test@gmail.com') // 'ahmed@gmail.com'
  /// ```
  String getOrganizationId(String email) {
    return normalize(email);
  }

  /// الحصول على معلومات التطبيع
  ///
  /// يعيد معلومات مفصلة عن عملية التطبيع
  ///
  /// **مثال:**
  /// ```dart
  /// getNormalizationInfo('a.hmed+test@gmail.com')
  /// // {
  /// //   'original': 'a.hmed+test@gmail.com',
  /// //   'normalized': 'ahmed@gmail.com',
  /// //   'domain': 'gmail.com',
  /// //   'provider': 'Google Gmail',
  /// //   'dotsRemoved': true,
  /// //   'plusRemoved': true,
  /// // }
  /// ```
  Map<String, dynamic> getNormalizationInfo(String email) {
    final normalized = normalize(email);
    final domain = EmailValidator.extractDomain(email);
    final provider = domain != null
        ? EmailDomainConfig.getProviderName(domain)
        : null;

    return {
      'original': email,
      'normalized': normalized,
      'domain': domain,
      'provider': provider,
      'dotsRemoved': domain != null &&
          EmailDomainConfig.shouldIgnoreDots(domain),
      'plusRemoved': domain != null &&
          EmailDomainConfig.shouldIgnorePlus(domain),
      'isValid': EmailValidator.isValid(email),
      'changed': email.toLowerCase().trim() != normalized,
    };
  }
}
