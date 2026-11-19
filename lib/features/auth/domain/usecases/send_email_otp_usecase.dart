import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use Case لإرسال رمز التحقق إلى البريد الإلكتروني
class SendEmailOTPUseCase {
  SendEmailOTPUseCase(this.repository);
  final AuthRepository repository;

  /// [isSignup] - true للتسجيل (يجب ألا يكون الحساب موجوداً)
  /// [isSignup] - false لنسيان كلمة المرور (يجب أن يكون الحساب موجوداً)
  Future<Either<Failure, void>> call(
    String email, {
    bool isSignup = true,
  }) async {
    if (email.isEmpty) {
      return const Left(AuthFailure('البريد الإلكتروني مطلوب'));
    }

    if (!_isValidEmail(email)) {
      return const Left(AuthFailure('البريد الإلكتروني غير صحيح'));
    }

    // التحقق من وجود حساب مرتبط بهذا البريد
    final result = await repository.checkIfAccountExists(email: email);
    return result.fold((failure) => Left(failure) as Either<Failure, void>, (
      exists,
    ) {
      if (isSignup) {
        // في حالة التسجيل: يجب ألا يكون الحساب موجوداً
        if (exists) {
          return const Left(AuthFailure('البريد الإلكتروني مستخدم بالفعل'))
              as Either<Failure, void>;
        }
      } else {
        // في حالة نسيان كلمة المرور: يجب أن يكون الحساب موجوداً
        if (!exists) {
          return const Left(AuthFailure('الحساب غير موجود'))
              as Either<Failure, void>;
        }
      }
      return repository.sendEmailOTP(email);
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[\w\-\.\u0600-\u06FF]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(email);
  }
}
