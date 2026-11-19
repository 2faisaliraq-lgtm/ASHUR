import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use Case لإرسال رمز التحقق إلى رقم الهاتف
class SendPhoneOTPUseCase {
  SendPhoneOTPUseCase(this.repository);
  final AuthRepository repository;

  /// [isSignup] - true للتسجيل (يجب ألا يكون الحساب موجوداً)
  /// [isSignup] - false لنسيان كلمة المرور (يجب أن يكون الحساب موجوداً)
  Future<Either<Failure, String>> call(
    String phoneNumber, {
    bool isSignup = true,
  }) async {
    if (phoneNumber.isEmpty) {
      return const Left(AuthFailure('رقم الهاتف مطلوب'));
    }

    if (!_isValidPhoneNumber(phoneNumber)) {
      return const Left(AuthFailure('رقم الهاتف غير صحيح'));
    }

    // التحقق من وجود حساب مرتبط بهذا الرقم
    final result = await repository.checkIfAccountExists(
      phoneNumber: phoneNumber,
    );
    return result.fold(
      (failure) =>
          const Left(AuthFailure('فشل في التحقق من وجود الحساب'))
              as Either<Failure, String>,
      (exists) {
        if (isSignup) {
          // في حالة التسجيل: يجب ألا يكون الحساب موجوداً
          if (exists) {
            return const Left(AuthFailure('رقم الهاتف مستخدم بالفعل'))
                as Either<Failure, String>;
          }
        } else {
          // في حالة نسيان كلمة المرور: يجب أن يكون الحساب موجوداً
          if (!exists) {
            return const Left(AuthFailure('الحساب غير موجود'))
                as Either<Failure, String>;
          }
        }
        return repository.sendPhoneOTP(phoneNumber);
      },
    );
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    // التحقق من صحة رقم الهاتف (يقبل الأرقام العراقية المحلية والدولية)
    final cleanedValue = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // يقبل: 07xxxxxxxxx (11 خانة) أو 9647xxxxxxxx (12 خانة) أو +9647xxxxxxxx
    final regex = RegExp(
      r'^(0[1-9][0-9]{9}|964[1-9][0-9]{9}|\+964[1-9][0-9]{9}|[1-9][0-9]{9,14})$',
    );
    return regex.hasMatch(cleanedValue);
  }
}
