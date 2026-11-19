import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  // الطرق الحالية
  Future<Either<Failure, UserEntity>> signInWithEmail(
    String email,
    String password,
  );
  Future<Either<Failure, UserEntity>> signUpWithEmail(
    String email,
    String password, {
    String? name,
  });
  Future<Either<Failure, UserEntity>> signInWithGoogle();
  Future<Either<Failure, void>> signOut();
  Future<Either<Failure, UserEntity?>> getCurrentUser();
  Stream<UserEntity?> get authStateChanges;

  // طرق الهاتف الجديدة (OTP)
  Future<Either<Failure, String>> sendPhoneOTP(String phoneNumber);
  Future<Either<Failure, UserEntity>> verifyPhoneOTP(
    String verificationId,
    String smsCode, {
    String? name,
  });
  Future<Either<Failure, void>> resetPasswordByPhone(
    String verificationId,
    String smsCode,
    String newPassword,
  );

  // طرق البريد الإلكتروني الجديدة (OTP)
  Future<Either<Failure, void>> sendEmailOTP(String email);
  Future<Either<Failure, UserEntity>> verifyEmailOTP(
    String email,
    String otpCode, {
    required String name,
    required String password,
  });
  Future<Either<Failure, void>> resetPasswordByEmail(
    String email,
    String otpCode,
    String newPassword,
  );

  // طرق التحقق من وجود حساب
  Future<Either<Failure, bool>> checkIfAccountExists({
    String? email,
    String? phoneNumber,
  });
}
