import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetProductsStream
    implements StreamUseCase<List<ProductEntity>, GetProductsStreamParams> {
  GetProductsStream(this.repository);
  final ProductRepository repository;

  @override
  Stream<Either<Failure, List<ProductEntity>>> call(
    GetProductsStreamParams params,
  ) {
    return repository.getProductsStream(
      organizationEmail: params.organizationEmail,
      categoryId: params.categoryId,
      shelfId: params.shelfId,
      isActive: params.isActive,
      lowStock: params.lowStock,
      limit: params.limit,
      searchQuery: params.searchQuery,
    );
  }
}

class GetProductsStreamParams {
  const GetProductsStreamParams({
    required this.organizationEmail,
    this.categoryId,
    this.shelfId,
    this.isActive,
    this.lowStock,
    this.limit,
    this.searchQuery,
  });

  final String organizationEmail;
  final String? categoryId;
  final String? shelfId;
  final bool? isActive;
  final bool? lowStock;
  final int? limit;
  final String? searchQuery;
}
