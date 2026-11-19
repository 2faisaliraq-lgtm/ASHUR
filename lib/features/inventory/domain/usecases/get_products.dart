import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

/// حالة استخدام الحصول على المنتجات
class GetProducts implements UseCase<List<ProductEntity>, GetProductsParams> {

  GetProducts(this.repository);
  final ProductRepository repository;

  @override
  Future<Either<Failure, List<ProductEntity>>> call(
    GetProductsParams params,
  ) async {
    return repository.getProducts(
      organizationEmail: params.organizationEmail,
      categoryId: params.categoryId,
      shelfId: params.shelfId,
      isActive: params.isActive,
      lowStock: params.lowStock,
      searchQuery: params.searchQuery,
      limit: params.limit,
      lastDocumentId: params.lastDocumentId,
    );
  }
}

/// معاملات حالة استخدام الحصول على المنتجات
class GetProductsParams extends Equatable {

  const GetProductsParams({
    required this.organizationEmail,
    this.categoryId,
    this.shelfId,
    this.isActive,
    this.lowStock,
    this.searchQuery,
    this.limit,
    this.lastDocumentId,
  });
  final String organizationEmail;
  final String? categoryId;
  final String? shelfId;
  final bool? isActive;
  final bool? lowStock;
  final String? searchQuery;
  final int? limit;
  final String? lastDocumentId;

  @override
  List<Object?> get props => [
    organizationEmail,
    categoryId,
    shelfId,
    isActive,
    lowStock,
    searchQuery,
    limit,
    lastDocumentId,
  ];
}
