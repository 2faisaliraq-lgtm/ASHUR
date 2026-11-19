import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

/// حالة استخدام الحصول على الفئات
class GetCategories
    implements UseCase<List<CategoryEntity>, GetCategoriesParams> {

  GetCategories(this.repository);
  final CategoryRepository repository;

  @override
  Future<Either<Failure, List<CategoryEntity>>> call(
    GetCategoriesParams params,
  ) async {
    return repository.getCategories(
      organizationEmail: params.organizationEmail,
      parentId: params.parentId,
      isActive: params.isActive,
    );
  }
}

/// معاملات حالة استخدام الحصول على الفئات
class GetCategoriesParams extends Equatable {

  const GetCategoriesParams({
    required this.organizationEmail,
    this.parentId,
    this.isActive,
  });
  final String organizationEmail;
  final String? parentId;
  final bool? isActive;

  @override
  List<Object?> get props => [organizationEmail, parentId, isActive];
}
