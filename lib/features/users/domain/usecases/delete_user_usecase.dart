import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/users_repository.dart';

/// حالة استخدام حذف المستخدم
class DeleteUserUseCase implements UseCase<void, DeleteUserParams> {

  DeleteUserUseCase(this.repository);
  final UsersRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteUserParams params) async {
    return repository.deleteUser(
      params.userId,
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

/// معاملات حالة استخدام حذف المستخدم
class DeleteUserParams extends Equatable {

  const DeleteUserParams({
    required this.userId,
    this.logActionType,
    this.logDetails,
    this.logTargetId,
    this.logTargetType,
    this.logOldValues,
    this.logNewValues,
    this.logIsSuccess = true,
  });
  final String userId;
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
    logActionType,
    logDetails,
    logTargetId,
    logTargetType,
    logOldValues,
    logNewValues,
    logIsSuccess,
  ];
}
