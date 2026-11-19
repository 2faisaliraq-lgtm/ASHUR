import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/setting_repository.dart';

class GetSettingsStatsStream
    implements StreamUseCase<Map<String, int>, String> {
  GetSettingsStatsStream(this.repository);
  final SettingRepository repository;

  @override
  Stream<Either<Failure, Map<String, int>>> call(String organizationEmail) {
    return repository.getSettingsStatsStream(organizationEmail);
  }
}
