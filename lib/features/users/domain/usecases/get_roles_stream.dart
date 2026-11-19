import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/role_entity.dart';
import '../repositories/users_repository.dart';

/// حالة استخدام الحصول على stream الأدوار مع التحديث الفوري
class GetRolesStream {
  GetRolesStream(this.repository);
  final UsersRepository repository;

  Stream<Either<Failure, List<RoleEntity>>> call() {
    return repository.getRolesStream();
  }
}
