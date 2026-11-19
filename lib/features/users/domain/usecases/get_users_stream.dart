import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_management_entity.dart';
import '../repositories/users_repository.dart';

class GetUsersStreamParams {
  const GetUsersStreamParams({
    required this.organizationEmail,
    this.limit,
    this.searchQuery,
    this.roleFilters,
    this.isActiveFilter,
  });

  final String organizationEmail;
  final int? limit;
  final String? searchQuery;
  final List<String>? roleFilters;
  final bool? isActiveFilter;
}

class GetUsersStream
    implements StreamUseCase<List<UserManagementEntity>, GetUsersStreamParams> {
  GetUsersStream(this.repository);
  final UsersRepository repository;

  @override
  Stream<Either<Failure, List<UserManagementEntity>>> call(
    GetUsersStreamParams params,
  ) {
    return repository.getUsersStream(
      organizationEmail: params.organizationEmail,
      limit: params.limit,
      searchQuery: params.searchQuery,
      roleFilters: params.roleFilters,
      isActiveFilter: params.isActiveFilter,
    );
  }
}
