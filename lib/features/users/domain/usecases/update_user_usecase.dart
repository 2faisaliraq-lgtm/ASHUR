import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_management_entity.dart';
import '../repositories/users_repository.dart';

/// حالة استخدام تحديث بيانات المستخدم
class UpdateUserUseCase
    implements UseCase<UserManagementEntity, UpdateUserParams> {
  UpdateUserUseCase(this.repository);
  final UsersRepository repository;

  @override
  Future<Either<Failure, UserManagementEntity>> call(
    UpdateUserParams params,
  ) async {
    return repository.updateUser(
      userId: params.userId,
      email: params.email,
      name: params.name,
      phoneNumber: params.phoneNumber,
      department: params.department,
      jobTitle: params.jobTitle,
      roleIds: params.roleIds,
      roleCode: params.roleCode,
      customPermissions: params.customPermissions,
      notificationEnabled: params.notificationEnabled,
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

/// معاملات حالة استخدام تحديث المستخدم
class UpdateUserParams extends Equatable {
  const UpdateUserParams({
    required this.userId,
    this.email,
    this.name,
    this.phoneNumber,
    this.department,
    this.jobTitle,
    this.roleIds,
    this.roleCode,
    this.customPermissions,
    this.notificationEnabled,
    this.logActionType,
    this.logDetails,
    this.logTargetId,
    this.logTargetType,
    this.logOldValues,
    this.logNewValues,
    this.logIsSuccess = true,
  });

  final String userId;
  final String? email;
  final String? name;
  final String? phoneNumber;
  final String? department;
  final String? jobTitle;
  final List<String>? roleIds;
  final String? roleCode;
  final List<String>? customPermissions;
  final bool? notificationEnabled;
  final String? logActionType;
  final String? logDetails;
  final String? logTargetId;
  final String? logTargetType;
  final Map<String, dynamic>? logOldValues;
  final Map<String, dynamic>? logNewValues;
  final bool logIsSuccess;

  @override
  List<Object?> get props => [
    userId,
    email,
    name,
    phoneNumber,
    department,
    jobTitle,
    roleIds,
    roleCode,
    customPermissions,
    notificationEnabled,
    logActionType,
    logDetails,
    logTargetId,
    logTargetType,
    logOldValues,
    logNewValues,
    logIsSuccess,
  ];
}
