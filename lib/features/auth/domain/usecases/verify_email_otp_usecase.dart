import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use Case للتحقق من رمز البريد الإلكتروني وإنشاء الحساب
class VerifyEmailOTPUseCase {
  VerifyEmailOTPUseCase(this.repository);
  final AuthRepository repository;

  Future<Either<Failure, UserEntity>> call(
    String email,
    String otpCode, {
    required String name,
    required String password,
  }) async {
    if (email.isEmpty || otpCode.isEmpty) {
      return const Left(AuthFailure('يرجى إدخال البريد ورمز التحقق'));
    }

    if (otpCode.isEmpty || otpCode.length != 6) {
      return const Left(
        AuthFailure('رمز التحقق يجب أن يكون 6 أحرف'),
      );
    }

    if (!_isAlphanumericOtp(otpCode)) {
      return const Left(
        AuthFailure('رمز التحقق يجب أن يتكون من أحرف وأرقام'),
      );
    }

    if (name.isEmpty) {
      return const Left(AuthFailure('الاسم مطلوب'));
    }

    if (password.isEmpty) {
      return const Left(AuthFailure('كلمة المرور مطلوبة'));
    }

    if (password.length < 6) {
      return const Left(
        AuthFailure('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
      );
    }

    if (!_isAlphanumericPassword(password)) {
      return const Left(
        AuthFailure('كلمة المرور يجب أن تتكون من أحرف وأرقام'),
      );
    }

    return await repository.verifyEmailOTP(
      email,
      otpCode,
      name: name,
      password: password,
    );
  }

  bool _isAlphanumericPassword(String password) {
    return RegExp(r'^[a-zA-Z0-9\u0600-\u06FF]+$').hasMatch(password);
  }

  bool _isAlphanumericOtp(String otp) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(otp);
  }
}
