/// أدوات التحقق من صحة البيانات
/// Validators for input validation
library;

/// التحقق من صحة البريد الإلكتروني
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'البريد الإلكتروني مطلوب';
  }

  // نمط التحقق من البريد الإلكتروني
  final emailPattern = RegExp(
    r'^[\w\-\.\u0600-\u06FF]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  if (!emailPattern.hasMatch(value)) {
    return 'البريد الإلكتروني غير صحيح';
  }

  return null;
}

/// التحقق من كلمة المرور
/// متطلبات كلمة المرور: 6 أرقام فقط
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'كلمة المرور مطلوبة';
  }

  if (value.length < 6) {
    return 'كلمة المرور يجب أن تكون 6 أرقام على الأقل';
  }

  if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
    return 'كلمة المرور يجب أن تتكون من أرقام فقط';
  }

  return null;
}

/// التحقق من كلمة المرور (نمط بسيط - للأرقام فقط)
/// يستخدم في الحالات التي تتطلب كلمة مرور رقمية فقط
String? validateNumericPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'كلمة المرور مطلوبة';
  }

  if (value.length < 6) {
    return 'كلمة المرور يجب أن تكون 6 أرقام على الأقل';
  }

  if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
    return 'كلمة المرور يجب أن تتكون من أرقام فقط';
  }

  return null;
}

/// التحقق من تأكيد كلمة المرور
String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'تأكيد كلمة المرور مطلوب';
  }

  if (value != password) {
    return 'كلمة المرور غير متطابقة';
  }

  return null;
}

/// التحقق من صحة رقم الهاتف
String? validatePhoneNumber(String? value) {
  if (value == null || value.isEmpty) {
    return 'رقم الهاتف مطلوب';
  }

  final cleanedValue = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  // يقبل: 07xxxxxxxxx (11 خانة) أو 9647xxxxxxxx (12 خانة) أو +9647xxxxxxxx
  if (!RegExp(
    r'^(0[1-9][0-9]{9}|964[1-9][0-9]{9}|\+964[1-9][0-9]{9}|[1-9][0-9]{9,14})$',
  ).hasMatch(cleanedValue)) {
    return 'رقم الهاتف غير صحيح';
  }

  return null;
}

/// التحقق من صحة الاسم
String? validateName(String? value) {
  if (value == null || value.isEmpty) {
    return 'الاسم مطلوب';
  }

  if (value.length < 2) {
    return 'الاسم يجب أن يكون حرفين على الأقل';
  }

  if (value.length > 100) {
    return 'الاسم طويل جداً';
  }

  return null;
}

/// التحقق من صحة OTP
String? validateOTP(String? value) {
  if (value == null || value.isEmpty) {
    return 'رمز التحقق مطلوب';
  }

  if (value.length != 6) {
    return 'رمز التحقق يجب أن يكون 6 أرقام';
  }

  if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
    return 'رمز التحقق يجب أن يتكون من أرقام فقط';
  }

  return null;
}

/// التحقق من الموافقة على الشروط
String? validateTermsAcceptance(bool? accepted) {
  if (accepted != true) {
    return 'يجب الموافقة على الشروط والأحكام';
  }

  return null;
}

/// فئة مساعدة للتحقق من صحة النماذج
class FormValidators {
  /// التحقق من صحة نموذج تسجيل كامل
  static ValidationResult validateSignupForm({
    required String? name,
    required String? email,
    required String? password,
    required String? confirmPassword,
    required bool? acceptTerms,
  }) {
    final errors = <String>[];

    final nameError = validateName(name);
    if (nameError != null) errors.add(nameError);

    final emailError = validateEmail(email);
    if (emailError != null) errors.add(emailError);

    final passwordError = validatePassword(password);
    if (passwordError != null) errors.add(passwordError);

    final confirmError = validateConfirmPassword(
      confirmPassword,
      password ?? '',
    );
    if (confirmError != null) errors.add(confirmError);

    final termsError = validateTermsAcceptance(acceptTerms);
    if (termsError != null) errors.add(termsError);

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  /// التحقق من صحة نموذج تسجيل الدخول
  static ValidationResult validateLoginForm({
    required String? email,
    required String? password,
  }) {
    final errors = <String>[];

    final emailError = validateEmail(email);
    if (emailError != null) errors.add(emailError);

    if (password == null || password.isEmpty) {
      errors.add('كلمة المرور مطلوبة');
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  /// التحقق من صحة نموذج إنشاء حساب (كلمة مرور رقمية)
  static ValidationResult validateSignupWithNumericPassword({
    required String? name,
    required String? emailOrPhone,
    required String? password,
    required String? confirmPassword,
    required bool? acceptTerms,
    required bool isEmail,
  }) {
    final errors = <String>[];

    final nameError = validateName(name);
    if (nameError != null) errors.add(nameError);

    if (isEmail) {
      final emailError = validateEmail(emailOrPhone);
      if (emailError != null) errors.add(emailError);
    } else {
      final phoneError = validatePhoneNumber(emailOrPhone);
      if (phoneError != null) errors.add(phoneError);
    }

    final passwordError = validateNumericPassword(password);
    if (passwordError != null) errors.add(passwordError);

    final confirmError = validateConfirmPassword(
      confirmPassword,
      password ?? '',
    );
    if (confirmError != null) errors.add(confirmError);

    final termsError = validateTermsAcceptance(acceptTerms);
    if (termsError != null) errors.add(termsError);

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}

/// نتيجة التحقق من صحة النموذج
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({required this.isValid, required this.errors});

  /// الحصول على رسالة الخطأ الأولى
  String? get firstError => errors.isNotEmpty ? errors.first : null;

  /// الحصول على جميع الأخطاء كسلسلة واحدة
  String get allErrors => errors.join('\n');
}
