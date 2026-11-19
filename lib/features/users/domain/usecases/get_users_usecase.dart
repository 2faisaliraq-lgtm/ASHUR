import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_management_entity.dart';
import '../repositories/users_repository.dart';

/// حالة استخدام الحصول على قائمة المستخدمين
class GetUsersUseCase
    implements UseCase<List<UserManagementEntity>, GetUsersParams> {

  GetUsersUseCase(this.repository);
  final UsersRepository repository;

  @override
  Future<Either<Failure, List<UserManagementEntity>>> call(
    GetUsersParams params,
  ) async {
    return repository.getUsers(
      organizationEmail: params.organizationEmail,
      limit: params.limit,
      searchQuery: params.searchQuery,
      roleFilters: params.roleFilters,
      isActiveFilter: params.isActiveFilter,
    );
  }
}

/// معاملات حالة استخدام الحصول على المستخدمين
class GetUsersParams extends Equatable {

  const GetUsersParams({
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

  @override
  List<Object?> get props => [
    organizationEmail,
    limit,
    searchQuery,
    roleFilters,
    isActiveFilter,
  ];
}
