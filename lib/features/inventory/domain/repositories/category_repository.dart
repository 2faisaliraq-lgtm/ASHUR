import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category_entity.dart';

/// واجهة مستودع الفئات
abstract class CategoryRepository {
  /// الحصول على جميع الفئات
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    required String organizationEmail,
    String? parentId,
    bool? isActive,
  });

  /// الحصول على فئة بالمعرف
  Future<Either<Failure, CategoryEntity>> getCategoryById({
    required String id,
    required String organizationEmail,
  });

  /// الحصول على الفئات الرئيسية
  Future<Either<Failure, List<CategoryEntity>>> getMainCategories({
    required String organizationEmail,
    bool? isActive,
  });

  /// الحصول على الفئات الفرعية
  Future<Either<Failure, List<CategoryEntity>>> getSubCategories({
    required String organizationEmail,
    required String parentId,
    bool? isActive,
  });

  /// إضافة فئة جديدة
  Future<Either<Failure, CategoryEntity>> createCategory({
    required CategoryEntity category,
  });

  /// تحديث فئة
  Future<Either<Failure, CategoryEntity>> updateCategory({
    required CategoryEntity category,
  });

  /// حذف فئة
  Future<Either<Failure, void>> deleteCategory({
    required String id,
    required String organizationEmail,
  });

  /// البحث في الفئات
  Future<Either<Failure, List<CategoryEntity>>> searchCategories({
    required String organizationEmail,
    required String query,
  });

  /// التحقق من وجود منتجات في الفئة
  Future<Either<Failure, bool>> hasProducts({
    required String categoryId,
    required String organizationEmail,
  });

  /// الحصول على عدد المنتجات في كل فئة
  Future<Either<Failure, Map<String, int>>> getCategoriesProductCount({
    required String organizationEmail,
  });
}
