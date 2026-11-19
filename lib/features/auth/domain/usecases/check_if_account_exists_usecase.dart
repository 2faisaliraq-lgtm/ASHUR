import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Use Case للتحقق من وجود حساب
class CheckIfAccountExistsUseCase {
  CheckIfAccountExistsUseCase(this.repository);
  final AuthRepository repository;

  Future<Either<Failure, bool>> call({
    String? email,
    String? phoneNumber,
  }) async {
    return await repository.checkIfAccountExists(
      email: email,
      phoneNumber: phoneNumber,
    );
  }
}
