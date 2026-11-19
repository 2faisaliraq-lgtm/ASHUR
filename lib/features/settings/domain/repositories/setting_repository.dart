import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/setting_entity.dart';

/// واجهة مستودع الإعدادات
abstract class SettingRepository {
  Future<Either<Failure, List<SettingEntity>>> getSettings(
    String organizationEmail,
  );

  Future<Either<Failure, SettingEntity>> createSetting(SettingEntity setting);

  Future<Either<Failure, SettingEntity>> updateSetting(SettingEntity setting);

  Future<Either<Failure, void>> deleteSetting(
    String organizationEmail,
    String settingId,
  );

  Future<Either<Failure, SettingEntity?>> getSettingByKey(
    String organizationEmail,
    String key,
  );

  Future<Either<Failure, List<SettingEntity>>> getSettingsByCategory(
    String organizationEmail,
    String category,
  );

  Future<Either<Failure, void>> initializeDefaultSettings(
    String organizationEmail,
  );

  // Stream methods for real-time updates
  Stream<Either<Failure, List<SettingEntity>>> getSettingsStream(
    String organizationEmail, {
    int? limit,
  });

  Stream<Either<Failure, Map<String, int>>> getSettingsStatsStream(
    String organizationEmail,
  );
}
