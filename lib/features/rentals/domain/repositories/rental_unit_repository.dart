import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/rental_unit_entity.dart';
import '../entities/rental_units_page.dart';

/// واجهة مستودع الوحدات القابلة للإيجار
abstract class RentalUnitRepository {
  /// إنشاء وحدة جديدة
  Future<Either<Failure, void>> createRentalUnit(RentalUnitEntity unit);

  /// تحديث وحدة
  Future<Either<Failure, void>> updateRentalUnit(RentalUnitEntity unit);

  /// حذف وحدة
  Future<Either<Failure, void>> deleteRentalUnit(String id);

  /// الحصول على جميع الوحدات
  Future<Either<Failure, List<RentalUnitEntity>>> getRentalUnits(
    String organizationEmail,
  );

  /// الحصول على الوحدات بشكل تدريجي (pagination)
  Future<Either<Failure, RentalUnitsPage>> getRentalUnitsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  });

  /// الحصول على stream للوحدات
  Stream<Either<Failure, List<RentalUnitEntity>>> getRentalUnitsStream(
    String organizationEmail,
  );

  /// الحصول على الوحدات المتاحة فقط
  Future<Either<Failure, List<RentalUnitEntity>>> getAvailableRentalUnits(
    String organizationEmail,
  );
}
