import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/setting_entity.dart';
import '../repositories/setting_repository.dart';

class CreateSetting implements UseCase<SettingEntity, CreateSettingParams> {
  CreateSetting(this.repository);
  final SettingRepository repository;

  @override
  Future<Either<Failure, SettingEntity>> call(
    CreateSettingParams params,
  ) async {
    return repository.createSetting(params.setting);
  }
}

class CreateSettingParams {
  CreateSettingParams({required this.setting});
  final SettingEntity setting;
}
