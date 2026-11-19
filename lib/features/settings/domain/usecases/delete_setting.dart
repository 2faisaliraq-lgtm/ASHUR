import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/setting_repository.dart';

class DeleteSetting implements UseCase<void, DeleteSettingParams> {
  DeleteSetting(this.repository);
  final SettingRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteSettingParams params) async {
    return repository.deleteSetting(params.organizationEmail, params.settingId);
  }
}

class DeleteSettingParams {
  DeleteSettingParams({
    required this.organizationEmail,
    required this.settingId,
  });
  final String organizationEmail;
  final String settingId;
}
