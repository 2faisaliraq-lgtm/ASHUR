import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/product_repository.dart';

/// حالة استخدام حذف منتج
class DeleteProduct implements UseCase<void, DeleteProductParams> {

  DeleteProduct(this.repository);
  final ProductRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteProductParams params) async {
    return repository.deleteProduct(
      id: params.productId,
      organizationEmail: params.organizationEmail,
    );
  }
}

/// معاملات حالة استخدام حذف منتج
class DeleteProductParams extends Equatable {

  const DeleteProductParams({
    required this.productId,
    required this.organizationEmail,
  });
  final String productId;
  final String organizationEmail;

  @override
  List<Object?> get props => [productId, organizationEmail];
}
