import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/maintenance_request_entity.dart';
import '../repositories/maintenance_repository.dart';

/// حالة استخدام: إنشاء طلب صيانة
class CreateMaintenanceRequest {
  CreateMaintenanceRequest(this.repository);
  final MaintenanceRepository repository;

  Future<Either<Failure, String>> call(MaintenanceRequestEntity request) async {
    return repository.createMaintenanceRequest(request);
  }
}
