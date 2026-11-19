import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/users_page.dart';
import '../repositories/users_repository.dart';

class GetUsersPaginated {
  GetUsersPaginated(this.repository);
  final UsersRepository repository;

  Future<Either<Failure, UsersPage>> call({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
  }) {
    return repository.getUsersPaginated(
      organizationEmail: organizationEmail,
      limit: limit,
      lastDocument: lastDocument,
    );
  }
}
