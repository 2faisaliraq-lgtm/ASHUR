import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/equipment_entity.dart';
import '../entities/maintenance_request_entity.dart';
import '../repositories/maintenance_repository.dart';

/// حالة استخدام: جلب إحصائيات الصيانة
class GetMaintenanceStats {
  GetMaintenanceStats(this.repository);
  final MaintenanceRepository repository;

  /// ⚡ requestsOverride/equipmentOverride: بيانات
  /// مجلوبة فعلاً (كاملة) لتجنب جلبها مجدداً.
  Future<Either<Failure, Map<String, dynamic>>> call(
    String organizationEmail, {
    List<MaintenanceRequestEntity>? requestsOverride,
    List<EquipmentEntity>? equipmentOverride,
  }) async {
    return repository.getMaintenanceStats(
      organizationEmail,
      requestsOverride: requestsOverride,
      equipmentOverride: equipmentOverride,
    );
  }
}
