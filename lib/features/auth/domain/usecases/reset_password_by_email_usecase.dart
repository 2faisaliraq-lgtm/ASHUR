import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use Case لإعادة تعيين كلمة المرور عبر البريد الإلكتروني
class ResetPasswordByEmailUseCase {
  ResetPasswordByEmailUseCase(this.repository);
  final AuthRepository repository;

  Future<Either<Failure, void>> call(
    String email,
    String otpCode,
    String newPassword,
  ) async {
    // التحقق من البيانات
    if (email.isEmpty) {
      return const Left(AuthFailure('البريد الإلكتروني مطلوب'));
    }

    if (!_isValidEmail(email)) {
      return const Left(AuthFailure('البريد الإلكتروني غير صحيح'));
    }

    if (otpCode.isEmpty || otpCode.length != 6) {
      return const Left(AuthFailure('يرجى إدخال رمز التحقق المكون من 6 أرقام'));
    }

    if (newPassword.isEmpty) {
      return const Left(AuthFailure('كلمة المرور الجديدة مطلوبة'));
    }

    if (newPassword.length < 6) {
      return const Left(
        AuthFailure('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
      );
    }

    return await repository.resetPasswordByEmail(email, otpCode, newPassword);
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[\w\-\.\u0600-\u06FF]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(email);
  }
}
