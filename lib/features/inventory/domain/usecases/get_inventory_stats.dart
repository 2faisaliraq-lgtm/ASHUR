import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/category_repository.dart';
import '../repositories/inventory_movement_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/shelf_repository.dart';

/// إرجاع إحصائيات المخزون (منتجات، أرفف، حركات، فئات)
class GetInventoryStats
    implements UseCase<Map<String, dynamic>, GetInventoryStatsParams> {

  GetInventoryStats({
    required this.productRepository,
    required this.categoryRepository,
    required this.shelfRepository,
    required this.movementRepository,
  });
  final ProductRepository productRepository;
  final CategoryRepository categoryRepository;
  final ShelfRepository shelfRepository;
  final InventoryMovementRepository movementRepository;

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
    GetInventoryStatsParams params,
  ) async {
    try {
      // جلب إحصائيات المنتجات
      final productsStatsResult = await productRepository.getProductsStats(
        organizationEmail: params.organizationEmail,
      );

      // جلب إحصائيات الأرفف
      final shelvesStatsResult = await shelfRepository.getShelvesStats(
        organizationEmail: params.organizationEmail,
      );

      // جلب إحصائيات حركات المخزون
      final movementsStatsResult = await movementRepository.getMovementsStats(
        organizationEmail: params.organizationEmail,
        startDate: params.startDate,
        endDate: params.endDate,
      );

      // جلب عدد المنتجات لكل فئة (فئة الأصل أو الجذر)
      final categoriesCountResult = await categoryRepository
          .getCategoriesProductCount(
            organizationEmail: params.organizationEmail,
          );

      return await productsStatsResult.fold(
        Left.new,
        (productsStats) {
          return shelvesStatsResult.fold(
            Left.new,
            (shelvesStats) {
              return movementsStatsResult.fold(
                Left.new,
                (movementsStats) {
                  return categoriesCountResult.fold(
                    Left.new,
                    (categoriesCount) {
                      final combinedStats = <String, dynamic>{
                        'products': productsStats,
                        'shelves': shelvesStats,
                        'movements': movementsStats,
                        'categoriesCount': categoriesCount,
                        'generatedAt': DateTime.now().toIso8601String(),
                      };

                      return Right(combinedStats);
                    },
                  );
                },
              );
            },
          );
        },
      );
    } on Exception catch (_) {
      return const Left(ServerFailure());
    }
  }
}

/// معلمات استخدام GetInventoryStats لإحصائيات المخزون
class GetInventoryStatsParams extends Equatable {

  const GetInventoryStatsParams({
    required this.organizationEmail,
    this.startDate,
    this.endDate,
  });
  final String organizationEmail;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [organizationEmail, startDate, endDate];
}
