import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use Case للتحقق من رمز الهاتف وإنشاء الحساب
class VerifyPhoneOTPUseCase {
  VerifyPhoneOTPUseCase(this.repository);
  final AuthRepository repository;

  Future<Either<Failure, UserEntity>> call(
    String verificationId,
    String smsCode, {
    String? name,
  }) async {
    if (verificationId.isEmpty || smsCode.isEmpty) {
      return const Left(AuthFailure('يرجى إدخال رمز التحقق'));
    }

    if (smsCode.length != 6) {
      return const Left(AuthFailure('رمز التحقق يجب أن يكون 6 أرقام'));
    }

    return await repository.verifyPhoneOTP(
      verificationId,
      smsCode,
      name: name,
    );
  }
}
