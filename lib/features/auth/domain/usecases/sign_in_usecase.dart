import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {

  SignInUseCase(this.repository);
  final AuthRepository repository;

  Future<Either<Failure, UserEntity>> call(
    String email,
    String password,
  ) async {
    if (email.isEmpty || password.isEmpty) {
      return const Left(AuthFailure('البريد الإلكتروني وكلمة المرور مطلوبان'));
    }

    if (!_isValidEmail(email)) {
      return const Left(AuthFailure('البريد الإلكتروني غير صحيح'));
    }

    if (password.length < 6) {
      return const Left(
        AuthFailure('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
      );
    }

    return repository.signInWithEmail(email, password);
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[\w\-\.\u0600-\u06FF]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(email);
  }
}
