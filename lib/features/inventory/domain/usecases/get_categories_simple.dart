import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/category_entity.dart';
import '../repositories/product_repository.dart';

/// حالة استخدام مبسطة للحصول على الفئات
class GetCategoriesSimple
    implements UseCase<List<CategoryEntity>, GetCategoriesSimpleParams> {

  GetCategoriesSimple(this.repository);
  final ProductRepository repository;

  @override
  Future<Either<Failure, List<CategoryEntity>>> call(
    GetCategoriesSimpleParams params,
  ) async {
    return repository.getCategories(
      organizationEmail: params.organizationEmail,
      isActive: params.isActive,
    );
  }
}

/// معاملات حالة استخدام الحصول على الفئات المبسطة
class GetCategoriesSimpleParams extends Equatable {

  const GetCategoriesSimpleParams({
    required this.organizationEmail,
    this.isActive,
  });
  final String organizationEmail;
  final bool? isActive;

  @override
  List<Object?> get props => [organizationEmail, isActive];
}
