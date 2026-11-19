import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_management_entity.dart';
import '../repositories/users_repository.dart';

/// حالة استخدام إنشاء مستخدم جديد
class CreateUserUseCase
    implements UseCase<UserManagementEntity, CreateUserParams> {
  CreateUserUseCase(this.repository);
  final UsersRepository repository;

  @override
  Future<Either<Failure, UserManagementEntity>> call(
    CreateUserParams params,
  ) async {
    return repository.createUser(
      email: params.email,
      name: params.name,
      phoneNumber: params.phoneNumber,
      department: params.department,
      jobTitle: params.jobTitle,
      roleIds: params.roleIds,
      roleCode: params.roleCode,
      customPermissions: params.customPermissions,
      useCurrentUser: params.useCurrentUser,
      createdBy: params.createdBy,
      accountPassword: params.accountPassword,
      logActionType: params.logActionType,
      logDetails: params.logDetails,
      logTargetId: params.logTargetId,
      logTargetType: params.logTargetType,
      logOldValues: params.logOldValues,
      logNewValues: params.logNewValues,
      logIsSuccess: params.logIsSuccess,
    );
  }
}

/// معاملات حالة استخدام إنشاء المستخدم
class CreateUserParams extends Equatable {
  const CreateUserParams({
    required this.name,
    required this.roleIds,
    required this.roleCode,
    this.email,
    this.phoneNumber,
    this.department,
    this.jobTitle,
    this.customPermissions,
    this.useCurrentUser = false,
    this.createdBy,
    this.accountPassword,
    this.logActionType,
    this.logDetails,
    this.logTargetId,
    this.logTargetType,
    this.logOldValues,
    this.logNewValues,
    this.logIsSuccess = true,
  });

  final String? email;
  final String name;
  final String? phoneNumber;
  final String? department;
  final String? jobTitle;
  final List<String> roleIds;
  final String roleCode;
  final List<String>? customPermissions;
  final bool useCurrentUser;
  final String? createdBy;
  final String? accountPassword;
  final String? logActionType;
  final String? logDetails;
  final String? logTargetId;
  final String? logTargetType;
  final Map<String, dynamic>? logOldValues;
  final Map<String, dynamic>? logNewValues;
  final bool logIsSuccess;

  @override
  List<Object?> get props => [
    email,
    name,
    phoneNumber,
    department,
    jobTitle,
    roleIds,
    roleCode,
    customPermissions,
    useCurrentUser,
    createdBy,
    accountPassword,
    logActionType,
    logDetails,
    logTargetId,
    logTargetType,
    logOldValues,
    logNewValues,
    logIsSuccess,
  ];
}
