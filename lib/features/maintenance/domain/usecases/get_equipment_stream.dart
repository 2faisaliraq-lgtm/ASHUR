import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/equipment_entity.dart';
import '../repositories/maintenance_repository.dart';

/// حالة استخدام: جلب المعدات كـ Stream للتحديث الفوري
class GetEquipmentStream
    implements StreamUseCase<List<EquipmentEntity>, NoParams> {
  GetEquipmentStream(this.repository);
  final MaintenanceRepository repository;

  @override
  Stream<Either<Failure, List<EquipmentEntity>>> call(NoParams params) {
    return repository.getEquipmentStream();
  }
}
