import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/maintenance_request_entity.dart';
import '../repositories/maintenance_repository.dart';

/// حالة استخدام: جلب طلبات الصيانة
class GetMaintenanceRequests {
  GetMaintenanceRequests(this.repository);
  final MaintenanceRepository repository;

  Future<Either<Failure, List<MaintenanceRequestEntity>>> call(
    String organizationEmail,
  ) async {
    return repository.getMaintenanceRequests(organizationEmail);
  }
}
