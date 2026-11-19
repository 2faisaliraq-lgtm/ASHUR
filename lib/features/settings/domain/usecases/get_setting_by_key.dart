import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/setting_entity.dart';
import '../repositories/setting_repository.dart';

class GetSettingByKey
    implements UseCase<SettingEntity?, GetSettingByKeyParams> {
  GetSettingByKey(this.repository);
  final SettingRepository repository;

  @override
  Future<Either<Failure, SettingEntity?>> call(
    GetSettingByKeyParams params,
  ) async {
    return repository.getSettingByKey(params.organizationEmail, params.key);
  }
}

class GetSettingByKeyParams {
  GetSettingByKeyParams({required this.organizationEmail, required this.key});
  final String organizationEmail;
  final String key;
}
