import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/setting_entity.dart';
import '../repositories/setting_repository.dart';

class GetSettingsByCategory
    implements UseCase<List<SettingEntity>, GetSettingsByCategoryParams> {
  GetSettingsByCategory(this.repository);
  final SettingRepository repository;

  @override
  Future<Either<Failure, List<SettingEntity>>> call(
    GetSettingsByCategoryParams params,
  ) async {
    return repository.getSettingsByCategory(
      params.organizationEmail,
      params.category,
    );
  }
}

class GetSettingsByCategoryParams {
  GetSettingsByCategoryParams({
    required this.organizationEmail,
    required this.category,
  });
  final String organizationEmail;
  final String category;
}
