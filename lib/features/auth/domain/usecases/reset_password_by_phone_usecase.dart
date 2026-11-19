import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use Case لإعادة تعيين كلمة المرور عبر الهاتف
class ResetPasswordByPhoneUseCase {
  ResetPasswordByPhoneUseCase(this.repository);
  final AuthRepository repository;

  Future<Either<Failure, void>> call(
    String verificationId,
    String smsCode,
    String newPassword,
  ) async {
    if (verificationId.isEmpty || smsCode.isEmpty) {
      return const Left(AuthFailure('يرجى إدخال رمز التحقق'));
    }

    if (smsCode.length != 6) {
      return const Left(AuthFailure('رمز التحقق يجب أن يكون 6 أرقام'));
    }

    if (newPassword.isEmpty) {
      return const Left(AuthFailure('كلمة المرور الجديدة مطلوبة'));
    }

    if (newPassword.length < 6) {
      return const Left(
        AuthFailure('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
      );
    }

    return await repository.resetPasswordByPhone(
      verificationId,
      smsCode,
      newPassword,
    );
  }
}
