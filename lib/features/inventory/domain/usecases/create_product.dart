import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

/// حالة استخدام إنشاء منتج جديد
class CreateProduct implements UseCase<ProductEntity, CreateProductParams> {

  CreateProduct(this.repository);
  final ProductRepository repository;

  @override
  Future<Either<Failure, ProductEntity>> call(
    CreateProductParams params,
  ) async {
    return repository.createProduct(product: params.product);
  }
}

/// معاملات حالة استخدام إنشاء منتج
class CreateProductParams extends Equatable {

  const CreateProductParams({required this.product});
  final ProductEntity product;

  @override
  List<Object?> get props => [product];
}
