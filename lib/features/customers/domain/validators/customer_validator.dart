import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/customer_repository.dart';

class CustomerValidator {
  CustomerValidator(this._repository);

  final CustomerRepository _repository;

  // ===== ملاحظة هامة للمبرمجين المستقبليين =====
  // 1. طرق التحقق من التكرار (isEmailUnique / isPhoneUnique) ليست ذرية
  //    مع عملية الإنشاء الفعلية: هي مجرد فحص مسبق لتحسين تجربة المستخدم.
  //    الفحص الذري النهائي يحدث داخل runTransaction في
  //    CustomerRepositoryImpl.addCustomer / addCustomerWithOpeningBalance.
  //    لذلك من الطبيعي أن يصل المستخدم لرسالة "مستخدم من قبل"
  //    بعدما كان الفحص المسبق يشير إلى إمكانية الإنشاء.
  // 2. حقل `totalDebt` هو حقل تراكمي - يجب تحديثه ذرياً فقط
  //    داخل runTransaction أو via FieldValue.increment() لتجنب تحديثات مفقودة
  //    (lost updates) عند المعالجة المتزامنة. لا تحسب هذا الحقل خارج العمليات الذرية
  //    إلا إذا كنت تريد تعديله يدوياً في منطق الفواتير لاحقاً.
  // ==========================================

  Future<Either<Failure, bool>> isEmailUnique(
    String email,
    String organizationEmail, {
    String? excludeCustomerId,
  }) async {
    // إذا كان البريد الإلكتروني فارغًا، لا حاجة للتحقق من التكرار
    if (email.isEmpty) {
      return const Right(true); // البريد الإلكتروني الفارغ دائمًا فريد
    }

    // ⚡ تحسين الأداء (2026-10-12): بدلاً من تحميل كل
    // العملاء من السيرفر (getCustomers forceRefresh —
    // قراءة O(N) وتنزيل كل مستندات العملاء)، نقرأ
    // مستند الفهرس الواحد في customer_emails حيث معرف
    // المستند هو البريد المطبّع — قراءة O(1). هذا أيضاً
    // يجعل الفحص المسبق متسقاً مع الفحص الذري النهائي
    // داخل runTransaction (الذي يستخدم نفس الفهرس) بدلاً
    // من مقارنة البريد الخام هنا.
    try {
      return await _repository.isCustomerEmailUnique(
        email,
        organizationEmail,
        excludeCustomerId: excludeCustomerId,
      );
    } on Exception catch (_) {
      // في حالة حدوث خطأ، نعيد خطأ بدلاً من افتراض أن البريد الإلكتروني فريد
      return Left(
        ServerFailure(
          message: 'فشل التحقق من تكرار البريد الإلكتروني',
        ),
      );
    }
  }

  /// التحقق من تكرار رقم الهاتف
  Future<Either<Failure, bool>> isPhoneUnique(
    String phone,
    String organizationEmail, {
    String? excludeCustomerId,
  }) async {
    // إذا كان رقم الهاتف فارغًا، لا حاجة للتحقق من التكرار
    if (phone.isEmpty) {
      return const Right(true); // رقم الهاتف الفارغ دائمًا فريد
    }

    // ⚡ تحسين الأداء (2026-10-12): نفس تحسين isEmailUnique —
    // قراءة مستند الفهرس الواحد في customer_phones (معرف
    // المستند = الهاتف المقطّع من المسافات) بدلاً من تحميل
    // كل العملاء.
    try {
      return await _repository.isCustomerPhoneUnique(
        phone,
        organizationEmail,
        excludeCustomerId: excludeCustomerId,
      );
    } on Exception catch (_) {
      // في حالة حدوث خطأ، نعيد خطأ بدلاً من افتراض أن الرقم فريد
      return Left(
        ServerFailure(
          message: 'فشل التحقق من تكرار رقم الهاتف',
        ),
      );
    }
  }

  /// التحقق من تنسيق البريد الإلكتروني
  bool isValidEmail(String email) {
    // إذا كان البريد الإلكتروني فارغًا، يعتبر صحيحًا (حقل اختياري)
    if (email.isEmpty) {
      return true;
    }

    const emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
    return RegExp(emailRegex).hasMatch(email);
  }

  /// التحقق من تنسيق رقم الهاتف
  bool isValidPhone(String phone) {
    // إذا كان الهاتف فارغًا، يعتبر صحيحًا (حقل اختياري)
    if (phone.isEmpty) {
      return true;
    }

    // يقبل: 07xxxxxxxxx (11 خانة) أو 9647xxxxxxxx (12 خانة) أو +9647xxxxxxxx
    final cleanedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final phoneRegex = RegExp(
      r'^(0[1-9][0-9]{9}|964[1-9][0-9]{9}|\+964[1-9][0-9]{9}|[1-9][0-9]{9,14})$',
    );
    return phoneRegex.hasMatch(cleanedPhone);
  }

  /// التحقق من صحة الاسم
  bool isValidName(String name) {
    return name.trim().length >= 2;
  }

  /// التحقق من صحة المبلغ
  bool isValidAmount(double? amount) {
    if (amount == null) return true; // يمكن أن تكون القيمة فارغة
    return amount.isFinite && amount >= 0;
  }

  /// التحقق من صحة الحساب
  bool isValidBalance(double? balance) {
    if (balance == null) return true; // يمكن أن تكون القيمة فارغة
    return balance.isFinite;
  }

  /// التحقق من صحة الحد الائتماني
  bool isValidCreditLimit(double? creditLimit) {
    if (creditLimit == null) return true; // يمكن أن تكون القيمة فارغة
    return creditLimit.isFinite && creditLimit >= 0;
  }

  /// التحقق من صحة الحالة
  bool isValidStatus(String status) {
    return ['active', 'inactive', 'blocked'].contains(status);
  }

  /// التحقق من صحة مجموعة العميل
  bool isValidCustomerGroup(String? groupId) {
    if (groupId == null) return true; // يمكن أن تكون القيمة فارغة
    return groupId.isNotEmpty;
  }
}
