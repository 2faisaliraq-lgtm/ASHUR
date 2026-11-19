import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/inventory_movement_entity.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

/// معاملات حالة استخدام تحديث كمية المنتج
class UpdateProductQuantityParams extends Equatable {

  const UpdateProductQuantityParams({
    required this.productId,
    required this.organizationEmail,
    required this.newQuantity,
    this.quantityDelta,
    required this.updatedBy,
    required this.movementType,
    this.reason,
    this.reference,
    this.fromShelfId,
    this.toShelfId,
    this.unitCost,
    this.totalCost,
    this.metadata,
  });
  final String productId;
  final String organizationEmail;
  final double newQuantity;

  /// ⚠️ ملاحظة للمبرمجين المستقبليين:
  /// عند توفير quantityDelta (قيمة نسبية مثل +2 أو -3)، تُحسب
  /// الكمية النهائية ذرياً داخل المعاملة من اللقطة الحية
  /// (الكمية الحالية + quantityDelta) بدلاً من newQuantity.
  /// استخدمه عندما تكون الكمية الجديدة محسوبة من قيمة قديمة
  /// (مثل عمليات الإرجاع) لتجنب تلف المخزون.
  final double? quantityDelta;
  final String updatedBy;
  final MovementType movementType;
  final String? reason;
  final String? reference;
  final String? fromShelfId;
  final String? toShelfId;
  final double? unitCost;
  final double? totalCost;
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [
    productId,
    organizationEmail,
    newQuantity,
    quantityDelta,
    updatedBy,
    movementType,
    reason,
    reference,
    fromShelfId,
    toShelfId,
    unitCost,
    totalCost,
    metadata,
  ];
}

/// حالة استخدام تحديث كمية المنتج
class UpdateProductQuantity
    implements UseCase<ProductEntity, UpdateProductQuantityParams> {

  UpdateProductQuantity({
    required this.productRepository,
  });
  final ProductRepository productRepository;

  @override
  Future<Either<Failure, ProductEntity>> call(
    UpdateProductQuantityParams params,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين حول الذرّية:
    // هذا الـ UseCase يعتمد على التنفيذ الذري داخل المستودع —
    // ProductRepository.updateProductQuantity يدمج الكمية +
    // shelfId عند النقل + سجل الحركة داخل runTransaction
    // واحدة (سجل الحركة إثبات التغيير — فصلهما يسبب كمية
    // تتغير بلا أثر أو سجل بلا تغيير فعلي). راجع ملخص الذرية
    // في product_repository_impl.dart.

    return await productRepository.updateProductQuantity(
      id: params.productId,
      organizationEmail: params.organizationEmail,
      newQuantity: params.newQuantity,
      quantityDelta: params.quantityDelta,
      updatedBy: params.updatedBy,
      movementType: params.movementType,
      reason: params.reason,
      reference: params.reference,
      fromShelfId: params.fromShelfId,
      toShelfId: params.toShelfId,
      unitCost: params.unitCost,
      totalCost: params.totalCost,
      metadata: params.metadata,
    );
  }
}
