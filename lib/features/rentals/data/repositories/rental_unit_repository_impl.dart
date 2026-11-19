import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/rental_unit_entity.dart';
import '../../domain/entities/rental_units_page.dart';
import '../../domain/repositories/rental_unit_repository.dart';
import '../models/rental_unit_model.dart';

class RentalUnitRepositoryImpl implements RentalUnitRepository {
  RentalUnitRepositoryImpl({required this.firestore});
  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();

  // ════════════════════════════════════════════════════════════════
  // خريطة ذرية وحدات الإيجار (تحقق يدوي
  // ⚠️ ملاحظة: clearRentalLogs في rental_repository_impl.dart ليس ذرياً بالكامل عبر الدفعات
  // (أسطر 1022-1030) — إذا Failed دفعة لاحقة تبقى الدفعات السابقة قد نُفذت.
  // ⚠️ ملاحظة: clearRentalLogs في rental_repository_impl.dart ليس ذرياً بالكامل عبر الدفعات
  // (أسطر 1022-1030) — إذا Failed دفعة لاحقة تبقى الدفعات السابقة قد نُفذت.
  // 2026-10-11، أُعيد التحقق 2026-10-12 مجدداً
  // بدون تعديل منطق — الخريطة الكاملة
  // وتفاصيل التحقق في
  // rental_repository_impl.dart):
  //   • createRentalUnit: runTransaction(get + فحص عدم
  //     الوجود + رفض حقول التأجير + set) — يمنع
  //     الكتابة فوق وحدة موجودة بلا كشف (سباق
  //     TOCTOU بين الفحص والكتابة)، ويرفض إنشاء
  //     وحدة مؤجرة (status=rented أو currentRentalId
  //     أو currentRenterName) — الوحدة تُنشأ متاحة
  //     فقط ويُؤجرها عقد الإيجار ذرياً في
  //     createRental.
  //   • updateRentalUnit: runTransaction(get + حماية
  //     حقول التأجير + update) — معاملات العقود
  //     وحدها تملك تعديل حقول التأجير (status/
  //     currentRentalId/currentRenterName): تمنع
  //     تعديل حقول وحدة مؤجرة (للتعديل: أنهِ
  //     العقد أولاً فيُحرر الوحدة ذرياً في
  //     updateRental أو deleteRental) وتمنع تأجير
  //     وحدة متاحة عبر التحديث. بقية الحقول
  //     (الاسم/السعر/الصيانة...) تُعدَّل بحرية.
  //   • deleteRentalUnit: runTransaction(get + فحص التأجير
  //     + delete) مقيّد بمنظمة المستخدم الحالي — ذري
  //     ويمنع سباق TOCTOU بين القراءة والحذف، ويمنع
  //     حذف وحدة منظمة أخرى (collectionGroup كانت تبحث
  //     في وحدات كل المنظمات)، ويمنع حذف وحدة مؤجرة
  //     (عقد نشط يشير إليها — الفحص داخل المعاملة).
  // ════════════════════════════════════════════════════════════════

  String? _getCurrentOrganizationId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;
    return _emailService.normalize(user!.email!);
  }

  @override
  Future<Either<Failure, void>> createRentalUnit(RentalUnitEntity unit) async {
    try {
      final model = RentalUnitModel.fromEntity(unit);
      final normalizedEmail = _emailService.normalize(unit.organizationEmail);

      // ملاحظة للمبرمجين المستقبليين: إذا كان unit.id فارغاً، يتم إنشاء معرف تلقائياً
      // بواسطة Firestore عبر collection.doc() لمنع إنشاء مستند بمعرف فارغ غير صالح.
      final unitDoc = unit.id.isEmpty
          ? firestore
              .collection(normalizedEmail)
              .doc('rentals')
              .collection('rental_units')
              .doc()
          : firestore
              .collection(normalizedEmail)
              .doc('rentals')
              .collection('rental_units')
              .doc(unit.id);

      // معاملة ذرية: فحص عدم الوجود قبل الإنشاء
      // (نفس نمط createRental) — القراءة قبل
      // الكتابة تمنع الكتابة فوق وحدة موجودة
      // بلا كشف (سباق TOCTOU بين الفحص والكتابة).
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(unitDoc);

        if (snapshot.exists) {
          throw Exception('الوحدة موجودة مسبقاً');
        }

        // الوحدة تُنشأ متاحة فقط — ربطها بعقد
        // (status=rented أو currentRentalId أو
        // currentRenterName) يحدث داخل معاملات
        // العقود وحدها (createRental) — انظر خريطة
        // الذرية أعلاه. بدون الفحص: وحدة تُنشأ
        // مؤجرة بعقد غير موجود — كسر للثابت الذري.
        if (model.status == 'rented' ||
            model.currentRentalId != null ||
            model.currentRenterName != null) {
          throw Exception(
            'لا يمكن إنشاء وحدة مؤجرة — تُؤجر الوحدات عبر عقود الإيجار فقط',
          );
        }

        transaction.set(unitDoc, model.toFirestore());
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في إنشاء الوحدة: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateRentalUnit(RentalUnitEntity unit) async {
    try {
      final model = RentalUnitModel.fromEntity(unit);
      final normalizedEmail = _emailService.normalize(unit.organizationEmail);
      final unitDoc = firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rental_units')
          .doc(unit.id);

      // معاملة ذرية: قراءة الوحدة قبل الكتابة —
      // حماية حقول التأجير (status/
      // currentRentalId/currentRenterName): معاملات
      // العقود وحدها (createRental/updateRental/
      // deleteRental) تملك تعديلها. الحماية تمنع
      // تعديل حقول وحدة مؤجرة (يُحررها العقد
      // ذرياً — لتعديلها: أنهِ العقد أولاً)
      // وتمنع تأجير وحدة متاحة عبر تحديث الوحدة
      // (يُؤجرها العقد ذرياً). بقية الحقول
      // (الاسم/السعر/الصيانة...) تُعدَّل بحرية.
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(unitDoc);

        if (!snapshot.exists) {
          throw Exception('الوحدة غير موجودة');
        }

        final unitData = snapshot.data();
        final storedStatus = unitData?['status'] as String?;
        final storedRentalId =
            unitData?['currentRentalId'] as String?;
        final storedRenterName =
            unitData?['currentRenterName'] as String?;
        final isRented =
            storedStatus == 'rented' || storedRentalId != null;
        // حقول التأجير (status=rented/
        // currentRentalId/currentRenterName) تُعدَّل
        // في معاملات العقود وحدها — لا يمكن تأجير
        // وحدة متاحة أو تغيير ربط وحدة مؤجرة عبر
        // تحديث الوحدة (انظر خريطة الذرية أعلاه).
        final wantsRentalBinding = unit.status == 'rented' ||
            unit.currentRentalId != null ||
            unit.currentRenterName != null;

        if (isRented) {
          if (unit.status != storedStatus ||
              unit.currentRentalId != storedRentalId ||
              unit.currentRenterName != storedRenterName) {
            throw Exception(
              'لا يمكن تعديل حالة وحدة مؤجرة — أنهِ العقد المرتبط بها أولاً',
            );
          }
        } else if (wantsRentalBinding) {
          throw Exception(
            'لا يمكن تأجير وحدة عبر تحديث الوحدة — تُؤجر الوحدات عبر عقود الإيجار فقط',
          );
        }

        transaction.update(unitDoc, model.toFirestore());
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث الوحدة: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRentalUnit(String id) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final unitDoc = firestore
          .collection(organizationId)
          .doc('rentals')
          .collection('rental_units')
          .doc(id);

      // معاملة ذرية: القراءة قبل الكتابة — منع حذف وحدة مؤجرة
      // (عقد نشط يشير إليها) بلا سباق بين الفحص والحذف.
      // لإنهاء وحدة مؤجرة: أنهِ العقد أولاً — يُحرر الوحدة
      // ذرياً في updateRental أو deleteRental (انظر الخريطة).
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(unitDoc);

        if (!snapshot.exists) {
          throw Exception('الوحدة غير موجودة');
        }

        final unitData = snapshot.data();
        final unitStatus = unitData?['status'] as String?;
        final currentRentalId = unitData?['currentRentalId'] as String?;
        if (unitStatus == 'rented' || currentRentalId != null) {
          throw Exception(
            'لا يمكن حذف وحدة مؤجرة — أنهِ العقد المرتبط بها أولاً',
          );
        }

        transaction.delete(unitDoc);
      });

      return const Right(null);
    } on Exception catch (e) {
      // الحفاظ على رسالة عدم الوجود كما كانت قبل التحويل للمعاملة الذرية
      if (e.toString().contains('الوحدة غير موجودة')) {
        return const Left(ServerFailure(message: 'الوحدة غير موجودة'));
      }
      // رسالة نظيفة لمنع حذف وحدة مؤجرة (بدون بادئة Exception:)
      if (e.toString().contains('لا يمكن حذف وحدة مؤجرة')) {
        return const Left(
          ServerFailure(
            message: 'لا يمكن حذف وحدة مؤجرة — أنهِ العقد المرتبط بها أولاً',
          ),
        );
      }
      return Left(ServerFailure(message: 'فشل في حذف الوحدة: $e'));
    }
  }

  @override
  Future<Either<Failure, List<RentalUnitEntity>>> getRentalUnits(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final querySnapshot = await firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rental_units')
          .orderBy('createdAt', descending: true)
          .get();

      final units = querySnapshot.docs
          .map(RentalUnitModel.fromFirestore)
          .toList();

      return Right(units);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الوحدات: $e'));
    }
  }

  @override
  Future<Either<Failure, RentalUnitsPage>> getRentalUnitsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      var query = firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rental_units')
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();

      final units = querySnapshot.docs
          .map(RentalUnitModel.fromFirestore)
          .toList();

      return Right(
        RentalUnitsPage(
          units: units,
          lastDocument: querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.last
              : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الوحدات: $e'));
    }
  }

  @override
  Stream<Either<Failure, List<RentalUnitEntity>>> getRentalUnitsStream(
    String organizationEmail,
  ) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // ✅ تحسين (2026-10-12): نفس تحسين
      // قسم الفواتير — نحفظ الوحدات
      // المحللة في ذاكرة خاصة بهذا
      // الستريم ونحدّث المستندات
      // المتغيرة فقط عبر docChanges
      // بدلاً من إعادة تحليل كل
      // الوحدات مع كل لقطة — كان
      // يسبب بطءاً ملحوظاً مع كثرة
      // الوحدات عند كل تحديث.
      final streamCache = <String, RentalUnitEntity>{};

      return firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rental_units')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            // تحديث تدريجي: نعالج المستندات المتغيرة فقط
            for (final change in snapshot.docChanges) {
              final doc = change.doc;
              if (change.type == DocumentChangeType.removed) {
                streamCache.remove(doc.id);
                continue;
              }
              try {
                streamCache[doc.id] =
                    RentalUnitModel.fromFirestore(doc);
              } on Exception catch (_) {
                streamCache.remove(doc.id);
              }
            }

            final units = streamCache.values.toList()
              ..sort((a, b) {
                final cmp = b.createdAt.compareTo(a.createdAt);
                return cmp != 0 ? cmp : a.id.compareTo(b.id);
              });
            return Right<Failure, List<RentalUnitEntity>>(units);
          })
          .handleError((error) {
            return Left<Failure, List<RentalUnitEntity>>(
              ServerFailure(message: 'فشل في جلب الوحدات: $error'),
            );
          });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب الوحدات: $e')),
      );
    }
  }

  @override
  Future<Either<Failure, List<RentalUnitEntity>>> getAvailableRentalUnits(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final querySnapshot = await firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rental_units')
          .where('status', isEqualTo: 'available')
          .orderBy('createdAt', descending: true)
          .get();

      final units = querySnapshot.docs
          .map(RentalUnitModel.fromFirestore)
          .toList();

      return Right(units);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الوحدات المتاحة: $e'));
    }
  }
}
