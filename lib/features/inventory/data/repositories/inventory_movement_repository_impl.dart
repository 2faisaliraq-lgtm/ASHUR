import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/inventory_movement_entity.dart';
import '../../domain/repositories/inventory_movement_repository.dart';
import '../models/inventory_movement_model.dart';

/// تنفيذ مستودع حركات المخزون
///
/// ⚠️ ملاحظة مدمجة للمبرمجين المستقبليين
/// (دُمجت من تعليقين متشابهين كانتا هنا
/// وعلى createMovement لتجنب التكرار):
/// تُقرأ/تُكتب الحركات من/إلى المجموعة العليا
/// {org}/inventory/inventory_movements (وليس
/// مجموعة فرعية تحت كل منتج — نفس نمط
/// products_logs). المسار الذري الوحيد لكتابة
/// حركة مع تغيير الكمية هو runTransaction
/// واحدة في ProductRepositoryImpl
/// .updateProductQuantity — لا تُخرج أي كتابة
/// حركة من تلك المعاملة أبداً. createMovement
/// أدناه كتابة مستقلة بمستند واحد بلا نمط
/// قراءة-تعديل-كتابة فلا تحتاج معاملة
/// (أُعيد التحقق اليدوي: 2026-10-11 و2026-10-12).
class InventoryMovementRepositoryImpl implements InventoryMovementRepository {
  InventoryMovementRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();

  /// مرجع مجموعة حركات المخزون العليا للمؤسسة
  CollectionReference _getMovementsCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('inventory_movements');
  }

  /// الاستعلام الأساسي مرتباً حسب createdAt تنازلياً
  Query _baseQuery(String normalizedEmail) => _getMovementsCollection(
    normalizedEmail,
  ).orderBy('createdAt', descending: true);

  /// تطبيق فلتر التاريخ على الاستعلام
  Query _applyDateFilter(Query query, DateTime? startDate, DateTime? endDate) {
    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }
    return query;
  }

  @override
  Future<Either<Failure, List<InventoryMovementEntity>>> getMovements({
    required String organizationEmail,
    String? productId,
    MovementType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    String? lastDocumentId,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      Query query = _baseQuery(normalizedEmail);

      if (productId != null && productId.isNotEmpty) {
        query = query.where('productId', isEqualTo: productId);
      }
      if (type != null) {
        query = query.where(
          'type',
          isEqualTo: InventoryMovementModel.typeToString(type),
        );
      }
      query = _applyDateFilter(query, startDate, endDate);

      if (lastDocumentId != null && lastDocumentId.isNotEmpty) {
        final lastDoc = await _getMovementsCollection(
          normalizedEmail,
        ).doc(lastDocumentId).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final movements = snapshot.docs
          .map(InventoryMovementModel.fromFirestore)
          .toList();
      return Right(movements);
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' &&
          (e.message?.contains('index') ?? false)) {
        return const Left(
          ServerFailure(
            message: 'الفهارس قيد الإنشاء، يرجى المحاولة بعد دقائق قليلة',
          ),
        );
      }
      return Left(
        ServerFailure(message: 'فشل في جلب حركات المخزون: ${e.message}'),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب حركات المخزون: $e'));
    }
  }

  @override
  Future<Either<Failure, InventoryMovementEntity>> getMovementById({
    required String id,
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final doc = await _getMovementsCollection(normalizedEmail).doc(id).get();
      if (!doc.exists) {
        return const Left(ServerFailure(message: 'الحركة غير موجودة'));
      }
      return Right(InventoryMovementModel.fromFirestore(doc));
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الحركة: ${_readableError(e)}'));
    }
  }

  @override
  Future<Either<Failure, List<InventoryMovementEntity>>> getProductMovements({
    required String productId,
    required String organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      Query query = _baseQuery(
        normalizedEmail,
      ).where('productId', isEqualTo: productId);
      query = _applyDateFilter(query, startDate, endDate);
      if (limit != null) {
        query = query.limit(limit);
      }
      final snapshot = await query.get();
      return Right(
        snapshot.docs.map(InventoryMovementModel.fromFirestore).toList(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' &&
          (e.message?.contains('index') ?? false)) {
        return const Left(
          ServerFailure(
            message: 'الفهارس قيد الإنشاء، يرجى المحاولة بعد دقائق قليلة',
          ),
        );
      }
      return Left(
        ServerFailure(message: 'فشل في جلب حركات المنتج: ${e.message}'),
      );
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في جلب حركات المنتج: ${_readableError(e)}'),
      );
    }
  }

  /// إضافة حركة جديدة (كتابة مستقلة إلى
  /// المجموعة العليا — راجع الملاحظة
  /// المدمجة أعلى الكلاس)
  @override
  Future<Either<Failure, InventoryMovementEntity>> createMovement({
    required InventoryMovementEntity movement,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(
        movement.organizationEmail,
      );
      final model = InventoryMovementModel(
        id: movement.id,
        productId: movement.productId,
        productName: movement.productName,
        type: movement.type,
        quantity: movement.quantity,
        previousQuantity: movement.previousQuantity,
        newQuantity: movement.newQuantity,
        createdAt: movement.createdAt,
        createdBy: movement.createdBy,
        organizationEmail: normalizedEmail,
        reason: movement.reason,
        reference: movement.reference,
        fromShelfId: movement.fromShelfId,
        toShelfId: movement.toShelfId,
        unitCost: movement.unitCost,
        totalCost: movement.totalCost,
        metadata: movement.metadata,
      );
      final docRef = _getMovementsCollection(normalizedEmail).doc(
        model.id.isNotEmpty ? model.id : null,
      );
      await docRef.set(model.toFirestore());
      return Right(model.copyWith(id: docRef.id));
    } on FirebaseException catch (e) {
      return Left(
        ServerFailure(message: 'فشل في إنشاء حركة المخزون: ${e.message}'),
      );
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في إنشاء حركة المخزون: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<InventoryMovementEntity>>> getMovementsByType({
    required String organizationEmail,
    required MovementType type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      Query query = _baseQuery(
        normalizedEmail,
      ).where('type', isEqualTo: InventoryMovementModel.typeToString(type));
      query = _applyDateFilter(query, startDate, endDate);
      if (limit != null) {
        query = query.limit(limit);
      }
      final snapshot = await query.get();
      return Right(
        snapshot.docs.map(InventoryMovementModel.fromFirestore).toList(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' &&
          (e.message?.contains('index') ?? false)) {
        return const Left(
          ServerFailure(
            message: 'الفهارس قيد الإنشاء، يرجى المحاولة بعد دقائق قليلة',
          ),
        );
      }
      return Left(
        ServerFailure(message: 'فشل في جلب حركات النوع: ${e.message}'),
      );
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في جلب حركات النوع: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<InventoryMovementEntity>>> getShelfMovements({
    required String shelfId,
    required String organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // حركات الرف: حركات خرجت منه (fromShelfId) أو
      // دخلت إليه (toShelfId) — استعلامان مدمجان
      // لأن الحركة تحمل رف مصدر ورف هدف معاً
      final fromQuery = _applyDateFilter(
        _baseQuery(normalizedEmail).where('fromShelfId', isEqualTo: shelfId),
        startDate,
        endDate,
      );
      final toQuery = _applyDateFilter(
        _baseQuery(normalizedEmail).where('toShelfId', isEqualTo: shelfId),
        startDate,
        endDate,
      );
      final results = await Future.wait([fromQuery.get(), toQuery.get()]);
      final movements = <InventoryMovementEntity>{};
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          movements.add(InventoryMovementModel.fromFirestore(doc));
        }
      }
      final sorted = movements.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Right(limit != null ? sorted.take(limit).toList() : sorted);
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' &&
          (e.message?.contains('index') ?? false)) {
        return const Left(
          ServerFailure(
            message: 'الفهارس قيد الإنشاء، يرجى المحاولة بعد دقائق قليلة',
          ),
        );
      }
      return Left(
        ServerFailure(message: 'فشل في جلب حركات الرف: ${e.message}'),
      );
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في جلب حركات الرف: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMovementsStats({
    required String organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final query = _applyDateFilter(
        _baseQuery(normalizedEmail),
        startDate,
        endDate,
      );
      final snapshot = await query.get();
      final movements = snapshot.docs
          .map(InventoryMovementModel.fromFirestore)
          .toList();

      final byType = <String, int>{};
      var inCount = 0;
      var outCount = 0;
      var transferCount = 0;
      for (final movement in movements) {
        final typeKey = InventoryMovementModel.typeToString(movement.type);
        byType[typeKey] = (byType[typeKey] ?? 0) + 1;
        if (movement.type == MovementType.transfer) {
          transferCount++;
        } else if (movement.quantity > 0) {
          inCount++;
        } else if (movement.quantity < 0) {
          outCount++;
        }
      }

      return Right({
        'totalMovements': movements.length,
        'inMovements': inCount,
        'outMovements': outCount,
        'transferMovements': transferCount,
        'movementsByType': byType,
      });
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في حساب إحصائيات الحركات: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMovementsReport({
    required String organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
    String? productId,
    MovementType? type,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      Query query = _baseQuery(normalizedEmail);
      if (productId != null && productId.isNotEmpty) {
        query = query.where('productId', isEqualTo: productId);
      }
      if (type != null) {
        query = query.where(
          'type',
          isEqualTo: InventoryMovementModel.typeToString(type),
        );
      }
      query = _applyDateFilter(query, startDate, endDate);
      final snapshot = await query.get();
      final movements = snapshot.docs
          .map(InventoryMovementModel.fromFirestore)
          .toList();

      final byProduct = <String, int>{};
      var netQuantity = 0.0;
      for (final movement in movements) {
        byProduct[movement.productId] =
            (byProduct[movement.productId] ?? 0) + 1;
        netQuantity += movement.quantity;
      }

      return Right({
        'totalMovements': movements.length,
        'netQuantity': netQuantity,
        'movementsByProduct': byProduct,
        'movements': movements,
      });
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في إنشاء تقرير الحركات: ${_readableError(e)}'),
      );
    }
  }
}

/// استخراج رسالة خطأ مفهومة للمستخدم من أي استثناء.
String _readableError(dynamic e) {
  final message = (e as dynamic).message;
  if (message is String && message.isNotEmpty) {
    return message;
  }
  final errorString = e.toString();
  if (errorString.startsWith('Exception: ')) {
    return errorString.substring('Exception: '.length);
  }
  return 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى';
}
