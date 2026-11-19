import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/product_repository.dart';

/// إرجاع إحصائيات المخزون البسيطة (إجمالي، نشط، منخفض المخزون، خارج المخزون، قيمة المخزون)
class GetInventoryStatsSimple
    implements UseCase<Map<String, dynamic>, GetInventoryStatsSimpleParams> {

  GetInventoryStatsSimple(this.productRepository);
  final ProductRepository productRepository;

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
    GetInventoryStatsSimpleParams params,
  ) async {
    try {
      // جلب المنتجات من المستودع
      final productsResult = await productRepository.getProducts(
        organizationEmail: params.organizationEmail,
      );

      return await productsResult.fold(
        Left.new,
        (products) {
        final totalProducts = products.length;
        final activeProducts = products.where((p) => p.isActive).length;
        final lowStockProducts = products.where((p) => p.isLowStock).length;
        final outOfStockProducts = products.where((p) => p.isOutOfStock).length;

        // حساب قيمة المخزون الإجمالية (سعر البيع × الكمية)
        // ProductEntity.inventoryValue (سعر البيع إذا توفرت التكلفة، وإلا precio de venta)
        // حساب السعر التكلفي أو سعر البيع إذا توفرت التكلفة، وإلا احسب القيمة الإجمالية
        // 상품 전체 값 계산을 위한 처리: 판매 가격이 없으면 판매 가격을 사용
        // القيمة الإجمالية للمخزون (المخزون الإفرادي للمنتجات مع سعر البيع إذا توفرت التكلفة)
        final totalInventoryValue = products.fold<double>(
          0,
          (total, product) => total + product.inventoryValue,
        );

        final stats = {
          'products': {
            'totalProducts': totalProducts,
            'activeProducts': activeProducts,
            'lowStockProducts': lowStockProducts,
            'outOfStockProducts': outOfStockProducts,
            'totalInventoryValue': totalInventoryValue,
          },
          'generatedAt': DateTime.now().toIso8601String(),
        };

        return Right(stats);
      });
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حساب إحصائيات المخزون: $e'));
    }
  }
}

/// معلمات استخدام GetInventoryStatsSimple لإحصائيات المخزون البسيطة
class GetInventoryStatsSimpleParams extends Equatable {

  const GetInventoryStatsSimpleParams({required this.organizationEmail});
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}
