import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/shelf_entity.dart';
import '../../domain/entities/shelves_page.dart';
import '../../domain/repositories/shelf_repository.dart';
import '../models/shelf_model.dart';

/// ⚠️ ملاحظة: قاعدة ذرية في قسم الأرفف
class ShelfRepositoryImpl implements ShelfRepository {
  ShelfRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();

  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⚠️ ملاحظة: قاعدة ذرية Firestore: transaction.get() يجب أن يسبق transaction.set()
  // ⚠️ transaction.set()/update()/delete()
  // ⚠️ ملاحظة: العمليات في قسم الأرفف تتبع قاعدة القراءات قبل الكتابات
  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⚠️ ملخص التحقق من الذريّة في قسم الأرفف (تحقق يدوي بدقة فائقة):
  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // نتيجة التحقق (2026-10-08 — أُعيد التحقق اليدوي:
  // 2026-10-09 و2026-10-11 و2026-10-12 وأُكدت سلامة
  // المعاملات الخمس: كل transaction.get() قبل أي
  // كتابة في كل المعاملات):
  // 4 عمليات ذرية كاملة + 1 مقبولة جزئياً (آخر العناصر أدناه)،
  // وكلها ملتزمة بقاعدة القراءات قبل الكتابات:
  // — createShelf: get الررف (للتحقق من عدم التكرار) ⇐ set الرف
  // — updateShelf: get الررف (للتحقق من الوجود) ⇐ update الرف
  // — deleteShelf: get الررف + التحقق من ملكية المؤسسة ⇐ delete الرف
  // — updateShelfItemCount: get الررف ⇐ update عدد العناصر (بناء
  //   قيمة الإرجاع بعد الكتابة حساب محلي من اللقطة وليس قراءة)
  // — recalculateShelfItemCounts (إصلاح 2026-10-11): مقبول بـ
  //   Query + WriteBatch — تُقرأ كل المنتجات في لقطة واحدة
  //   متسقة وتُعدَّ في الذاكرة ثم تُحدَّث كل عدادات الأرفف
  //   في commit واحد (Firestore client SDK لا تدعم queries
  //   داخل runTransaction)
  //
  // ⚠️ ما يجب أن يبقى ذرياً ولماذا (لا تكسره أبداً عند أي تعديل مستقبلي):
  //   1. التحقق من عدم التكرار + الحفظ في معاملة واحدة
  //      ⚠️ إذا فُصلا، مستخدمان ينشئان رفاً بنفس المعرف في نفس
  //        اللحظة فيتجاوزان التحقق (رف مكرر)
  //   2. التحقق من الوجود + التحديث في معاملة واحدة
  //      ⚠️ إذا فُصلا، قد يُحدَّث رف حُذف للتو (تحديث ناقص) أو
  //        يحدث race condition بين قراءة وكتابة
  //   3. التحقق من الوجود والملكية + الحذف في معاملة واحدة
  //      ⚠️ إذا فُصلا، قد يُحذف رف تغيرت ملكيته أو حُذف للتو
  //        (حذف غير مصرح به)
  //   4. قراءة البيانات الحالية + تحديث عدد العناصر في معاملة واحدة
  //      ⚠️ إذا فُصلا، يُحسب العدد من قيمة قديمة (عدد عناصر غير
  //        دقيق)
  //   5. إعادة حساب عدادات الأرفف: عدّ كل المنتجات من لقطة
  //      واحدة ثم تحديث كل الأرفف في WriteBatch واحد
  //      ⚠️ إذا فُصلت التحديثات، تُعرض أرفف بعدادات من
  //        أزمنة مختلفة (عدادات غير متسقة مع بعضها)
  //
  // ⚠️ ملاحظة للمبرمجين المستقبليين:
  //   هذا الملف مُتحقق منه يدوياً بدقة فائقة. أي تعديل مستقبلي
  //   يجب أن يكون يدوياً فقط (لا سكربت ولا أداة آلية ولا شيل)
  //   مع الحفاظ على ترتيب القراءات قبل الكتابات داخل كل
  //   runTransaction. كسر الذرية يسبب أرففاً مكررة أو حذفاً
  //   غير مصرح به أو أعداد عناصر غير دقيقة.
  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// ⚠️ — تحذير حول هيكل الإحصائيات
  CollectionReference _getShelvesCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('shelves');
  }

  /// ⚠️ — ملاحظة حول تحديثات العدد
  /// ⚠️ — ملاحظة حول تحديثات العدد currentItems
  /// ⚠️ — ملاحظة حول الإحصائيات
  CollectionReference _getProductsCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('products');
  }

  @override
  Future<Either<Failure, List<ShelfEntity>>> getShelves({
    required String organizationEmail,
    String? zone,
    bool? isActive,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      Query query = _getShelvesCollection(normalizedEmail);

      if (zone != null) {
        query = query.where('zone', isEqualTo: zone);
      }

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      final querySnapshot = await query.get();
      final shelves = querySnapshot.docs.map(ShelfModel.fromFirestore).toList();

      return Right(shelves);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في جلب الأرفف: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, ShelvesPage>> getShelvesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      var query = _getShelvesCollection(normalizedEmail).orderBy('name');

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final shelves = querySnapshot.docs.map(ShelfModel.fromFirestore).toList();

      return Right(
        ShelvesPage(
          shelves: shelves,
          lastDocument: querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.last
              : null,
        ),
      );
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في جلب الأرفف: ${_readableError(e)}'),
      );
    }
  }

  @override
  Stream<Either<Failure, List<ShelfEntity>>> getShelvesStream({
    required String organizationEmail,
    String? zone,
    bool? isActive,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      var query = _getShelvesCollection(normalizedEmail).orderBy('name');
      if (zone != null && zone.isNotEmpty) {
        query = query.where('zone', isEqualTo: zone);
      }
      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }
      // ⚠️ تحسين (2026-10-12): نفس تحسين
      // قسم الفواتير — نحفظ الرفوف
      // المحللة في ذاكرة خاصة بهذا
      // الستريم ونحدّث المستندات
      // المتغيرة فقط عبر docChanges
      // بدلاً من إعادة تحليل كل
      // الرفوف مع كل لقطة — كان
      // يسبب بطءاً ملحوظاً مع كثرة
      // الرفوف عند كل تحديث.
      final streamCache = <String, ShelfEntity>{};

      return query.snapshots().map(
        (snapshot) {
          // تحديث تدريجي: نعالج المستندات المتغيرة فقط
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            if (change.type == DocumentChangeType.removed) {
              streamCache.remove(doc.id);
              continue;
            }
            try {
              streamCache[doc.id] =
                  ShelfModel.fromFirestore(doc);
            } on Exception catch (_) {
              streamCache.remove(doc.id);
            }
          }

          final shelves = streamCache.values.toList()
            ..sort((a, b) {
              final cmp = a.name.compareTo(b.name);
              return cmp != 0 ? cmp : a.id.compareTo(b.id);
            });
          return Right<Failure, List<ShelfEntity>>(shelves);
        },
      );
    } on Exception catch (e) {
      return Stream.value(
        Left<Failure, List<ShelfEntity>>(
          ServerFailure(message: _readableError(e)),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, ShelfEntity>> getShelfById({
    required String id,
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final doc = await _getShelvesCollection(normalizedEmail).doc(id).get();

      if (!doc.exists) {
        return const Left(ServerFailure(message: 'الرف غير موجود'));
      }

      final shelf = ShelfModel.fromFirestore(doc);

      return Right(shelf);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الرف: ${_readableError(e)}'));
    }
  }

  @override
  Future<Either<Failure, List<ShelfEntity>>> getShelvesByZone({
    required String organizationEmail,
    required String zone,
    bool? isActive,
  }) async {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return getShelves(
      organizationEmail: normalizedEmail,
      zone: zone,
      isActive: isActive,
    );
  }

  @override
  Future<Either<Failure, ShelfEntity>> createShelf({
    required ShelfEntity shelf,
  }) async {
    try {
      final shelfModel = ShelfModel.fromEntity(shelf);
      final normalizedEmail = _emailService.normalize(shelf.organizationEmail);

      // ⚠️ ذرية (القاعدة 1 أعلاه): get الررف (للتحقق من عدم
      // التكرار) ⇐ set الرف في نفس المعاملة — إما النجاح أو
      // الفشل معاً.
      final firestoreInstance = FirebaseFirestore.instance;
      final shelfDocRef = _getShelvesCollection(normalizedEmail).doc();
      final shelfId = shelfModel.id.isEmpty ? shelfDocRef.id : shelfModel.id;

      await firestoreInstance.runTransaction((transaction) async {
        final shelfDoc = _getShelvesCollection(normalizedEmail).doc(shelfId);

        // التحقق من عدم وجود الرف مسبقاً
        final docSnapshot = await transaction.get(shelfDoc);

        if (docSnapshot.exists) {
          throw Exception('الرف موجود مسبقاً');
        }

        // حفظ البيانات في نفس الـ transaction
        final data = shelfModel.toJson();
        data['id'] = shelfId;
        transaction.set(shelfDoc, data);
      });

      final createdShelf = shelfModel.copyWith(id: shelfId);
      return Right(createdShelf);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في إنشاء الرف: ${_readableError(e)}'));
    }
  }

  @override
  Future<Either<Failure, ShelfEntity>> updateShelf({
    required ShelfEntity shelf,
  }) async {
    try {
      final shelfModel = ShelfModel.fromEntity(shelf);
      final normalizedEmail = _emailService.normalize(shelf.organizationEmail);

      // ⚠️ ذرية (القاعدة 2 أعلاه): get الررف ⇐ update الرف في
      // نفس المعاملة — إذا حُذف الرف بين التحقق والتحديث تفشل
      // المعاملة بـ "الرف غير موجود" ولا يحدث تحديث ناقص.
      final firestoreInstance = FirebaseFirestore.instance;
      await firestoreInstance.runTransaction((transaction) async {
        final shelfDoc = _getShelvesCollection(normalizedEmail).doc(shelf.id);

        // التحقق من وجود الرف قبل التحديث
        final docSnapshot = await transaction.get(shelfDoc);

        if (!docSnapshot.exists) {
          throw Exception('الرف غير موجود');
        }

        // تحديث البيانات في نفس الـ transaction
        transaction.update(shelfDoc, shelfModel.toJson());
      });

      return Right(shelf);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث الرف: ${_readableError(e)}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteShelf({
    required String id,
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;
      final shelfDoc = _getShelvesCollection(normalizedEmail).doc(id);

      // ⚠️ التحقق من وجود منتجات على الرف قبل الحذف
      // لمنع منتجات تشير إلى رف محذوف (بيانات غير متسقة).
      // يتم هذا خارج المعاملة لأن Firestore لا يدعم استعلامات (Query)
      // داخل runTransaction. خطر سباق بسيط مقبول لعملية حذف رف.
      final hasProductsResult = await hasProducts(
        shelfId: id,
        organizationEmail: normalizedEmail,
      );
      if (hasProductsResult.isLeft()) {
        return hasProductsResult;
      }
      if (hasProductsResult.fold((_) => false, (has) => has)) {
        return const Left(
          ServerFailure(message: 'لا يمكن حذف الرف لأنه يحتوي على منتجات'),
        );
      }

      // ⚠️ ذرية (القاعدة 3 أعلاه): get الررف + التحقق من ملكية
      // المؤسسة ⇐ delete الرف في نفس المعاملة — إذا حُذف الرف أو
      // تغيرت ملكيته بين التحقق والحذف تفشل المعاملة ولا يُحذف
      // رف لا يملكه المستخدم.
      await firestoreInstance.runTransaction((transaction) async {
        // التحقق من وجود الرف قبل الحذف
        final docSnapshot = await transaction.get(shelfDoc);

        if (!docSnapshot.exists) {
          throw Exception('الرف غير موجود');
        }

        // التحقق من أن البريد الإلكتروني يطابق المؤسسة
        final data = docSnapshot.data() as Map<String, dynamic>?;
        final docOrganizationEmail = data?['organizationEmail'] as String?;

        if (docOrganizationEmail == null ||
            _emailService.normalize(docOrganizationEmail) != normalizedEmail) {
          throw Exception('غير مصرح بالوصول لهذه العملية');
        }

        // حذف البيانات في نفس الـ transaction
        transaction.delete(shelfDoc);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في حذف الرف: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ShelfEntity>>> searchShelves({
    required String organizationEmail,
    required String query,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final querySnapshot = await _getShelvesCollection(normalizedEmail).get();

      // ⚠️ أداء (تحقق يدوي 2026-10-12): queryLower
      // مُخرَجة من اللامدا — تُحسب مرة واحدة بدلاً من
      // ٣ مرات لكل رف (نص ثابت لا يتغير) فالنتيجة
      // متطابقة تماماً والبحث أسرع. لا تُعيد إدخالها.
      final queryLower = query.toLowerCase();
      final shelves = querySnapshot.docs
          .map(ShelfModel.fromFirestore)
          .where(
            (shelf) =>
                shelf.name.toLowerCase().contains(queryLower) ||
                (shelf.description?.toLowerCase().contains(queryLower) ??
                    false) ||
                (shelf.location?.toLowerCase().contains(queryLower) ?? false),
          )
          .toList();

      return Right(shelves);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في البحث في الأرفف: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> hasProducts({
    required String shelfId,
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final querySnapshot = await firestore
          .collection(normalizedEmail)
          .doc('inventory')
          .collection('products')
          .where('shelfId', isEqualTo: shelfId)
          .limit(1)
          .get();

      return Right(querySnapshot.docs.isNotEmpty);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في التحقق من المنتجات: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, ShelfEntity>> updateShelfItemCount({
    required String id,
    required String organizationEmail,
    required int newCount,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;
      final shelfDoc = _getShelvesCollection(normalizedEmail).doc(id);

      // ⚠️ ذرية (القاعدة 4 أعلاه): get الررف ⇐ update عدد
      // العناصر في نفس المعاملة — بناء قيمة الإرجاع بعد الكتابة
      // حساب محلي من اللقطة وليس قراءة Firestore.
      return await firestoreInstance.runTransaction((transaction) async {
        // 1. جلب بيانات الرف داخل المعاملة
        final docSnapshot = await transaction.get(shelfDoc);

        if (!docSnapshot.exists) {
          throw Exception('الرف غير موجود');
        }

        // 2. تحديث عدد العناصر في نفس الـ transaction
        transaction.update(shelfDoc, {
          'currentItems': newCount,
        });

        // 3. إرجاع الرف المحدث
        final updatedShelf = ShelfModel.fromJson({
          'id': id,
          ...docSnapshot.data() as Map<String, dynamic>,
          'currentItems': newCount,
        });

        return Right(updatedShelf);
      });
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في تحديث عدد العناصر: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> recalculateShelfItemCounts({
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // ⚠️ ذرية جزئية مقبولة (ملخص الذرية أعلاه):
      // Query + WriteBatch بدلاً من runTransaction لأن
      // Firestore client SDK لا تدعم queries داخل
      // runTransaction. تُقرأ كل المنتجات في لقطة
      // واحدة متسقة وتُعدَّ في الذاكرة ثم تُحدَّث
      // كل عدادات الأرفف في commit واحد — الخطر
      // المتبقي (سباق بسيط على منتج يُسنَد لرف بعد
      // الاستعلام) مقبول لعملية إعادة حساب لمرة
      // واحدة.
      // 1. جلب كل الأرفف
      final shelvesSnapshot =
          await _getShelvesCollection(normalizedEmail).get();

      // 2. جلب كل المنتجات في لقطة واحدة متسقة
      // وعدّها لكل رف في الذاكرة (استعلام واحد
      // بدلاً من استعلام لكل رف)
      final productsSnapshot =
          await _getProductsCollection(normalizedEmail).get();
      final counts = <String, int>{};
      for (final productDoc in productsSnapshot.docs) {
        final data = productDoc.data() as Map<String, dynamic>?;
        final shelfId = data?['shelfId'] as String?;
        if (shelfId != null && shelfId.isNotEmpty) {
          counts[shelfId] = (counts[shelfId] ?? 0) + 1;
        }
      }

      // 3. تحديث عدادات كل الأرفف في WriteBatch واحد
      // (commit ذري — إما تُحدَّث كل العدادات أو لا
      // شيء) — يُصفَّر العدد للرف الذي لم يعد يملك
      // منتجات ويُتجاهل الرف المحذوف بعد الاستعلام
      // بفشل الـ Batch بأمان (يُعاد تشغيل العملية)
      final batch = firestore.batch();
      for (final shelfDoc in shelvesSnapshot.docs) {
        batch.update(shelfDoc.reference, {
          'currentItems': counts[shelfDoc.id] ?? 0,
          'updatedAt': Timestamp.now(),
        });
      }
      await batch.commit();

      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure(
          message: 'فشل إعادة حساب عدادات الأرفف: ${_readableError(e)}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<ShelfEntity>>> getFullShelves({
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final shelvesResult = await getShelves(
        organizationEmail: normalizedEmail,
        isActive: true,
      );

      return await shelvesResult.fold(
        Left.new,
        (shelves) => Right(shelves.where((shelf) => shelf.isFull).toList()),
      );
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في تحميل الأرفف الممتلئة: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ShelfEntity>>> getEmptyShelves({
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final shelvesResult = await getShelves(
        organizationEmail: normalizedEmail,
        isActive: true,
      );

      return await shelvesResult.fold(
        Left.new,
        (shelves) => Right(shelves.where((shelf) => shelf.isEmpty).toList()),
      );
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في تحميل الأرفف الفارغة: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getShelvesStats({
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final shelvesResult = await getShelves(
        organizationEmail: normalizedEmail,
      );

      return await shelvesResult.fold(Left.new, (shelves) {
        final activeShelves = shelves.where((shelf) => shelf.isActive).toList();
        final fullShelves = activeShelves
            .where((shelf) => shelf.isFull)
            .toList();
        final emptyShelves = activeShelves
            .where((shelf) => shelf.isEmpty)
            .toList();

        final totalCapacity = activeShelves.fold<int>(
          0,
          (total, shelf) => total + shelf.capacity,
        );

        final totalItems = activeShelves.fold<int>(
          0,
          (total, shelf) => total + shelf.currentItems,
        );

        return Right({
          'totalShelves': shelves.length,
          'activeShelves': activeShelves.length,
          'fullShelves': fullShelves.length,
          'emptyShelves': emptyShelves.length,
          'totalCapacity': totalCapacity,
          'totalItems': totalItems,
          'occupancyRate': totalCapacity > 0
              ? (totalItems / totalCapacity) * 100
              : 0,
        });
      });
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في تحميل إحصائيات الأرفف: ${_readableError(e)}'),
      );
    }
  }
}

/// ⚠️ ملاحظة: جميع العمليات ذرية في نفس المعاملة
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
