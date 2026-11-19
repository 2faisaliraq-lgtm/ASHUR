import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/category_entity.dart';
import '../repositories/product_repository.dart';

/// Use case لستريم الفئات للتحديث الفوري
class GetCategoriesStream
    implements StreamUseCase<List<CategoryEntity>, GetCategoriesStreamParams> {
  GetCategoriesStream(this.repository);
  final ProductRepository repository;

  @override
  Stream<Either<Failure, List<CategoryEntity>>> call(
    GetCategoriesStreamParams params,
  ) {
    return repository.getCategoriesStream(
      organizationEmail: params.organizationEmail,
      isActive: params.isActive,
    );
  }
}

/// معاملات ستريم الفئات
class GetCategoriesStreamParams {
  const GetCategoriesStreamParams({
    required this.organizationEmail,
    this.isActive,
  });

  final String organizationEmail;
  final bool? isActive;
}
