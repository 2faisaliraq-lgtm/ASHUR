import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/permissions/permissions_manager.dart';
import '../../../../core/usecases/usecase.dart';

/// فحص صلاحيات الصيانة
class CheckMaintenancePermission implements UseCase<bool, String> {
  CheckMaintenancePermission();

  @override
  Future<Either<Failure, bool>> call(String permission) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return const Left(AuthFailure('المستخدم غير مسجل دخول'));
      }

      // استخدام مدير الصلاحيات Singleton
      final permissionsManager = PermissionsManager();
      final hasPermission = permissionsManager.hasPermission(permission);

      return Right(hasPermission);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في فحص الصلاحيات: $e'));
    }
  }
}

/// فئة الفشل في المصادقة
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}
