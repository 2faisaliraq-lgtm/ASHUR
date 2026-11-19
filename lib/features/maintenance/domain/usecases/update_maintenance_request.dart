import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/maintenance_request_entity.dart';
import '../repositories/maintenance_repository.dart';

/// حالة استخدام: تحديث طلب صيانة
class UpdateMaintenanceRequest {
  UpdateMaintenanceRequest(this.repository);
  final MaintenanceRepository repository;

  Future<Either<Failure, void>> call(MaintenanceRequestEntity request) async {
    return repository.updateMaintenanceRequest(request);
  }
}
