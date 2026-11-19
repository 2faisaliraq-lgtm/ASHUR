import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/equipment_entity.dart';
import '../repositories/maintenance_repository.dart';

/// حالة استخدام: جلب المعدات
class GetEquipment {
  GetEquipment(this.repository);
  final MaintenanceRepository repository;

  Future<Either<Failure, List<EquipmentEntity>>> call(
    String organizationEmail,
  ) async {
    return repository.getEquipment(organizationEmail);
  }
}
