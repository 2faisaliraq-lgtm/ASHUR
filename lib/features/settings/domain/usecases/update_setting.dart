import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/setting_entity.dart';
import '../repositories/setting_repository.dart';

class UpdateSetting implements UseCase<SettingEntity, UpdateSettingParams> {
  UpdateSetting(this.repository);
  final SettingRepository repository;

  @override
  Future<Either<Failure, SettingEntity>> call(
    UpdateSettingParams params,
  ) async {
    return repository.updateSetting(params.setting);
  }
}

class UpdateSettingParams {
  UpdateSettingParams({required this.setting});
  final SettingEntity setting;
}
