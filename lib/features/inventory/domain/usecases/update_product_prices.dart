import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

/// حالة استخدام تحديث أسعار المنتج (سعر الشراء وسعر البيع)
class UpdateProductPrices
    implements UseCase<ProductEntity, UpdateProductPricesParams> {
  UpdateProductPrices({
    required this.productRepository,
  });

  final ProductRepository productRepository;

  @override
  Future<Either<Failure, ProductEntity>> call(
    UpdateProductPricesParams params,
  ) async {
    // التحقق من أن سعر البيع أكبر من أو يساوي الصفر
    if (params.sellingPrice < 0) {
      return Left(
        ServerFailure(message: 'سعر البيع لا يمكن أن يكون سالباً'),
      );
    }

    // التحقق من أن سعر الشراء (إذا تم تقديمه) أكبر من أو يساوي الصفر
    if (params.costPrice != null && params.costPrice! < 0) {
      return Left(
        ServerFailure(message: 'سعر الشراء لا يمكن أن يكون سالباً'),
      );
    }

    return await productRepository.updateProductPrices(
      id: params.id,
      organizationEmail: params.organizationEmail,
      costPrice: params.costPrice,
      sellingPrice: params.sellingPrice,
      updatedBy: params.updatedBy,
    );
  }
}

/// معلمات حالة استخدام تحديث أسعار المنتج
class UpdateProductPricesParams extends Equatable {
  const UpdateProductPricesParams({
    required this.id,
    required this.organizationEmail,
    required this.costPrice,
    required this.sellingPrice,
    required this.updatedBy,
  });

  final String id;
  final String organizationEmail;
  final double? costPrice;
  final double sellingPrice;
  final String updatedBy;

  @override
  List<Object?> get props => [
        id,
        organizationEmail,
        costPrice,
        sellingPrice,
        updatedBy,
      ];
}
