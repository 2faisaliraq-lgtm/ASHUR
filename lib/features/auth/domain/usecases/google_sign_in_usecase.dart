import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class GoogleSignInUseCase {

  GoogleSignInUseCase(this.repository);
  final AuthRepository repository;

  Future<Either<Failure, UserEntity>> call() async {
    return repository.signInWithGoogle();
  }
}
