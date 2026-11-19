import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/inventory_movement_entity.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

/// ⚠️ ملاحظة توثيقية للمبرمجين المستقبليين (حالة الكود الميت):
/// هذا الكلاس غير مسجل في injection_container.dart ولا يُستخدَم من قبل
/// InventoryBloc ولا من أي مسار إنتاجي — هو كود ميت (Dead Code).
/// يُحتفظ به كمرجع فقط. للتحديث الحقيقي للكمية في الإنتاج استخدِم
/// UpdateProductQuantity المسجل في DI والمستخدَم من البلوك.
/// لا تُسجِّل هذا الكلاس في DI lest يُستدعي بالخطأ في مسار إنتاجي.
/// ⚠️ ملاحظة للمبرمجين المستقبليين حول الذرّية (إصلاح 2026-10-09):
/// كان هذا الـ UseCase تجريبياً (Stub) يُرجع منتجاً وهمياً
/// دون مسح Firestore — خطر تلف مخزون صامت لو استُخدم لأنه
/// يُظهر نجاحاً وهمياً دون تحديث الكمية فعلاً. أُصلح الآن
/// ليُفوّض مباشرة إلى ProductRepository.updateProductQuantity
/// الذي يدمج الكمية + shelfId عند النقل + سجل الحركة داخل
/// runTransaction واحدة (ذرية All-or-Nothing).
/// حالة استخدام مبسطة لتحديث كمية المنتج — غير نشطة في الإنتاج
class UpdateProductQuantitySimple
    implements UseCase<ProductEntity, UpdateProductQuantitySimpleParams> {
  UpdateProductQuantitySimple({required this.productRepository});
  final ProductRepository productRepository;

  @override
  Future<Either<Failure, ProductEntity>> call(
    UpdateProductQuantitySimpleParams params,
  ) async {
    return productRepository.updateProductQuantity(
      id: params.productId,
      organizationEmail: params.organizationEmail,
      newQuantity: params.newQuantity,
      updatedBy: params.updatedBy,
      movementType: params.movementType,
      reason: params.reason,
    );
  }
}

/// معاملات حالة استخدام تحديث كمية المنتج المبسطة
class UpdateProductQuantitySimpleParams extends Equatable {

  const UpdateProductQuantitySimpleParams({
    required this.productId,
    required this.organizationEmail,
    required this.newQuantity,
    required this.updatedBy,
    required this.movementType,
    this.reason,
  });
  final String productId;
  final String organizationEmail;
  final double newQuantity;
  final String updatedBy;
  final MovementType movementType;
  final String? reason;

  @override
  List<Object?> get props => [
    productId,
    organizationEmail,
    newQuantity,
    updatedBy,
    movementType,
    reason,
  ];
}
