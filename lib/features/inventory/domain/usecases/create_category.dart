import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/category_entity.dart';
import '../repositories/product_repository.dart';

/// حالة استخدام إنشاء فئة جديدة
class CreateCategory implements UseCase<CategoryEntity, CreateCategoryParams> {

  CreateCategory(this.repository);
  final ProductRepository repository;

  @override
  Future<Either<Failure, CategoryEntity>> call(
    CreateCategoryParams params,
  ) async {
    return repository.createCategory(params.category);
  }
}

/// معاملات إنشاء الفئة
class CreateCategoryParams {

  CreateCategoryParams({required this.category});
  final CategoryEntity category;
}
