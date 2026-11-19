import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/setting_entity.dart';
import '../repositories/setting_repository.dart';

class GetSettings {

  GetSettings(this.repository);
  final SettingRepository repository;

  Future<Either<Failure, List<SettingEntity>>> call(
    String organizationEmail,
  ) async {
    return repository.getSettings(organizationEmail);
  }
}
