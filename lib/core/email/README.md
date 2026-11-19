# Email Normalization Service

## نظرة عامة

هذه الخدمة مسؤولة عن تطبيع عناوين البريد الإلكتروني حسب قواعد كل مزود بريد.

## الاستخدام

### الاستخدام الأساسي

```dart
import 'package:ashur/core/email/email_normalization_service.dart';

final service = EmailNormalizationService();
final normalized = service.normalize('A.Hmed+test@Gmail.com');
print(normalized); // 'ahmed@gmail.com'
```

### التحقق من التطابق

```dart
final areEqual = service.areEqual(
  'a.hmed@gmail.com',
  'ahmed@gmail.com',
);
print(areEqual); // true
```

### الحصول على معلومات التطبيع

```dart
final info = service.getNormalizationInfo('a.hmed+test@gmail.com');
print(info);
// {
//   'original': 'a.hmed+test@gmail.com',
//   'normalized': 'ahmed@gmail.com',
//   'domain': 'gmail.com',
//   'provider': 'Google Gmail',
//   'dotsRemoved': true,
//   'plusRemoved': true,
//   'isValid': true,
//   'changed': true,
// }
```

## قواعد التطبيع

### Gmail / Google Mail

- ✅ إزالة جميع النقاط (.)
- ✅ إزالة كل شيء بعد علامة (+)
- ✅ تحويل لأحرف صغيرة

**أمثلة:**

- `a.hmed@gmail.com` → `ahmed@gmail.com`
- `ahmed+test@gmail.com` → `ahmed@gmail.com`
- `A.H.M.E.D+work@Gmail.com` → `ahmed@gmail.com`

### Outlook / Hotmail / Live

- ❌ عدم إزالة النقاط
- ✅ إزالة كل شيء بعد علامة (+)
- ✅ تحويل لأحرف صغيرة

**أمثلة:**

- `ahmed.test@outlook.com` → `ahmed.test@outlook.com`
- `ahmed+work@outlook.com` → `ahmed@outlook.com`

### Yahoo

- ❌ عدم إزالة النقاط
- ✅ إزالة كل شيء بعد علامة (+)
- ✅ تحويل لأحرف صغيرة

### نطاقات أخرى

- ❌ عدم إزالة النقاط
- ❌ عدم إزالة ما بعد (+)
- ✅ تحويل لأحرف صغيرة فقط

## إضافة دعم لنطاق جديد

لإضافة دعم لنطاق جديد، عدّل ملف `email_domain_config.dart`:

```dart
class EmailDomainConfig {
  // إضافة النطاق للقائمة المناسبة
  static const List<String> dotsIgnoredDomains = [
    'gmail.com',
    'newdomain.com',  // إضافة هنا
  ];

  static const List<String> plusIgnoredDomains = [
    'gmail.com',
    'newdomain.com',  // إضافة هنا
  ];

  static const Map<String, String> knownDomains = {
    'gmail.com': 'Google Gmail',
    'newdomain.com': 'New Provider',  // إضافة هنا
  };
}
```

## الملفات

- `email_normalization_service.dart` - الخدمة الرئيسية
- `email_validator.dart` - أدوات التحقق
- `email_domain_config.dart` - إعدادات النطاقات
- `README.md` - هذا الملف

## الاختبارات

```bash
# تشغيل جميع الاختبارات
flutter test test/core/email/

# تشغيل اختبار محدد
flutter test test/core/email/email_normalization_service_test.dart
```

## أمثلة متقدمة

### تطبيع قائمة من البريد الإلكتروني

```dart
final emails = [
  'a.hmed@gmail.com',
  'test+work@outlook.com',
  'user@example.com',
];
final normalized = service.normalizeList(emails);
// ['ahmed@gmail.com', 'test@outlook.com', 'user@example.com']
```

### التحقق من نوع البريد

```dart
import 'package:ashur/core/email/email_validator.dart';

EmailValidator.isGmail('ahmed@gmail.com'); // true
EmailValidator.isOutlook('ahmed@outlook.com'); // true
EmailValidator.isYahoo('ahmed@yahoo.com'); // true
EmailValidator.isICloud('ahmed@icloud.com'); // true
```

## المراجع

- [Gmail Email Normalization](https://support.google.com/mail/answer/9211434)
- [RFC 5322 - Email Format](https://tools.ietf.org/html/rfc5322)
