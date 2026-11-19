import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/role_entity.dart';
import '../repositories/users_repository.dart';

/// حالة استخدام الحصول على قائمة الأدوار
class GetRolesUseCase implements UseCase<List<RoleEntity>, NoParams> {

  GetRolesUseCase(this.repository);
  final UsersRepository repository;

  @override
  Future<Either<Failure, List<RoleEntity>>> call(NoParams params) async {
    return repository.getRoles();
  }
}
