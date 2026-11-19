import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/inventory_movement_entity.dart';

/// واجهة مستودع حركات المخزون
abstract class InventoryMovementRepository {
  /// الحصول على جميع حركات المخزون
  Future<Either<Failure, List<InventoryMovementEntity>>> getMovements({
    required String organizationEmail,
    String? productId,
    MovementType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    String? lastDocumentId,
  });

  /// الحصول على حركة بالمعرف
  Future<Either<Failure, InventoryMovementEntity>> getMovementById({
    required String id,
    required String organizationEmail,
  });

  /// الحصول على حركات منتج معين
  Future<Either<Failure, List<InventoryMovementEntity>>> getProductMovements({
    required String productId,
    required String organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// إضافة حركة جديدة
  Future<Either<Failure, InventoryMovementEntity>> createMovement({
    required InventoryMovementEntity movement,
  });

  /// الحصول على حركات حسب النوع
  Future<Either<Failure, List<InventoryMovementEntity>>> getMovementsByType({
    required String organizationEmail,
    required MovementType type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// الحصول على حركات رف معين
  Future<Either<Failure, List<InventoryMovementEntity>>> getShelfMovements({
    required String shelfId,
    required String organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// الحصول على إحصائيات الحركات
  Future<Either<Failure, Map<String, dynamic>>> getMovementsStats({
    required String organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// الحصول على تقرير حركات المخزون
  Future<Either<Failure, Map<String, dynamic>>> getMovementsReport({
    required String organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
    String? productId,
    MovementType? type,
  });
}
