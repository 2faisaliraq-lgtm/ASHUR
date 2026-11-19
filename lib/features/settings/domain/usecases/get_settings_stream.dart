import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/setting_entity.dart';
import '../repositories/setting_repository.dart';

class GetSettingsStreamParams {
  const GetSettingsStreamParams({required this.organizationEmail, this.limit});

  final String organizationEmail;
  final int? limit;
}

class GetSettingsStream {
  GetSettingsStream(this.repository);
  final SettingRepository repository;

  Stream<Either<Failure, List<SettingEntity>>> call(
    GetSettingsStreamParams params,
  ) {
    return repository.getSettingsStream(
      params.organizationEmail,
      limit: params.limit,
    );
  }
}
