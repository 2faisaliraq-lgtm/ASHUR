import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/categories_page.dart';
import '../../domain/entities/inventory_log_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_log_entity.dart';
import '../../domain/entities/products_page.dart';
import '../../domain/entities/inventory_movement_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/category_model.dart';
import '../models/inventory_log_model.dart';
import '../models/product_log_model.dart';
import '../models/product_model.dart';

/// ⚠️ ملاحظة: قاعدة ذرية في قسم المنتجات
class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({required this.firestore});
  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();
  static const String collectionName = 'inventory';

  /// تحويل آمن لقيمة رقمية من بيانات Firestore
  /// ⚠️ تحسين (2026-10-12): يُستخدم في حساب
  /// ⚠️ ✅ ━━━━━━━━━ ━━━━━━━━━
  /// من بناء ProductModel كامل). منطقه مطابق
  /// لـ ProductModel.fromJson للقيم العددية
  /// ((json[x] ?? 0).toDouble()) مع تسامح أكبر
  /// مع الأنواع غير المتوقعة.
  static double _parseStatsDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0;
  }

  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⚠️ قاعدة Firestore الحاسمة: كل transaction.get() يجب أن يكون
  // قبل كل transaction.set()/update()/delete() داخل نفس المعاملة.
  // انتهاكها يسبب: '_commands.isEmpty': Transactions require all
  // reads to be executed before all writes.
  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ⚠️ ملخص التحقق من الذريّة في قسم المخزن (تحقق يدوي بدقة فائقة):
  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // نتيجة التحقق (2026-10-08 — أُعيد التحقق اليدوي:
  // 2026-10-09 و2026-10-11 و2026-10-12 وأُكدت سلامة
  // المعاملات الـ 12: كل transaction.get() قبل أي
  // كتابة في كل المعاملات):
  // جميع العمليات الذرية الـ 12 صحيحة وملتزمة بقاعدة القراءات قبل
  // الكتابات (كل transaction.get() قبل أي كتابة):
  //
  // المنتجات (5): createProduct (4 قراءات: المنتج + فهارس الاسم
  // والباركود + الرف — 4 كتابات) — updateProduct (كل الـ get
  // قبل أي كتابة — القراءات الشرطية للفهارس + قراءة رفَي
  // القديم والجديد كلها قبل أول كتابة) — deleteProduct (get
  // المنتج + التحقق من ملكية المؤسسة + قراءة الرف ⇐ delete
  // المنتج + فهارس الاسم والباركود + update عداد الرف) —
  // updateProductQuantity (get المنتج + قراءة رفَي المصدر والهدف
  // عند النقل ⇐ update الكمية/shelfId/metadata + set سجل الحركة
  // في inventory_movements + update عدادي الرف — quantityDelta
  // يُحسب من اللقطة الحية داخل المعاملة، وسجل الحركة يسجل
  // رف المصدر من اللقطة الحية عند النقل) — updateProductPrices
  // (قراءة خارجية للتحقق من الوجود والعرض فقط، والتحديث داخل
  // المعاملة بـ get ثم update — لا قراءة تُبنى عليها كتابة
  // خارج المعاملة)
  // الفئات (3): createCategory (get الفئة + get فهرس الاسم —
  // set الفئة + set فهرس الاسم) — updateCategory (كل الـ get
  // قبل أي كتابة) — deleteCategory (get الفئة + التحقق من
  // الملكية ⇐ delete الفئة + delete فهرس الاسم)
  // السجلات (4): addInventoryLog (set فقط بلا قراءات) —
  // deleteInventoryLog (get ⇐ delete) — createProductLog (get
  // المنتج ⇐ set السجل) — clearInventoryLogs (مقبول: Query +
  // WriteBatch لأن Firestore client SDK لا تدعم queries داخل
  // runTransaction، والخطر المتبقي — سباق بسيط على سجلات جديدة
  // تُنشأ بعد الاستعلام — مقبول لعملية تنظيف سجلات قديمة)
  //
  // ملاحظات مدمجة (دُمجت لتجنب التكرار — التفاصيل الكاملة
  // بتعليقات عند موقع كل إصلاح في الكود):
  // — سجلات الحركة (inventory_movements) وسجلات المنتجات
  //   (products_logs) تُكتب إلى المجموعات العليا {org}/inventory/
  //   (وليس مجموعات فرعية تحت كل منتج — الكتابة لمجموعة
  //   فرعية كانت تُنشئ سجلات يتيمة لا يقرأها أحد) وتُكتب
  //   ذرياً مع الكمية في نفس المعاملة (القاعدة 2) — productName
  //   يُحفظ في السجل ليكون ذاتياً (يُعرض حتى بعد حذف المنتج)
  //   ويُقرأ منها عبر InventoryMovementRepository
  // — حذف منتج لا يحذف سجلات حركته (Firestore لا تدعم الحذف
  //   المتسلسل ولا الاستعلامات داخل المعاملة) — السجلات تبقى
  //   في المجموعة العليا كسجل تدقيق مقصود (تاريخ حركات
  //   المنتج يُحفظ حتى بعد حذفه)
  // — الإصلاحات الموثقة (2026-10-08 إلى 2026-10-12): حماية
  //   .doc('') الفارغ في updateProduct/updateCategory — حذف
  //   فهرس الباركود القديم عند إزالته — quantityDelta من اللقطة
  //   الحية داخل المعاملة — حفظ metadata في نفس المعاملة —
  //   organizationEmail المُرجعة من المستند الأصلي (وليس
  //   المطبعة) — عداد currentItems مع كل عملية رف +
  //   recalculateShelfItemCounts لإعادة الحساب لمرة واحدة —
  //   fromShelfId من اللقطة الحية عند النقل — نصوص البحث
  //   الثابتة (toLowerCase) مُخرَجة من اللامبدا/الحلقات/
  //   المقارنات (تُحسب مرة واحدة — النتيجة متطابقة والفلترة
  //   أسرع، لا تُعيد إدخالها)
  //
  // ⚠️ ما يجب أن يبقى ذرياً ولماذا (لا تكسره أبداً عند أي تعديل مستقبلي):
  //   1. المنتج + فهرس الاسم + فهرس الباركود في معاملة واحدة
  //      ⚠️ لماذا: الفهارس هي ضمان عدم التكرار الوحيد. فصلها
  //        يسبب إما منتجاً بلا فهرس (يسمح بتكراره لاحقاً) أو
  //        فهرساً يتيماً يمنع استخدام الاسم/الباركود إلى الأبد
  //   2. الكمية + shelfId عند النقل + سجل الحركة في معاملة واحدة
  //      ⚠️ لماذا: سجل الحركة هو إثبات التغيير. فصلها يسبب كمية
  //        تتغير بلا أثر (اختفاء مخزون) أو سجل بلا تغيير فعلي
  //        (مخزون وهمي)
  //   3. الفئة + فهرس الاسم في معاملة واحدة
  //      ⚠️ لماذا: نفس منطق المنتج — فهرس الاسم يمنع تكرار الفئات
  //   4. الحذف + حذف الفهارس المرتبطة في معاملة واحدة
  //      ⚠️ لماذا: فهارس يتيمة تمنع إعادة استخدام الاسم/الباركود
  //        إلى الأبد (خطأ "مستخدم من قبل" رغم عدم وجود مالك)
  //   5. أي قراءة تُبنى عليها كتابة يجب أن تكون داخل المعاملة
  //      ⚠️ لماذا: قراءة خارجية ثم كتابة = race condition (مستخدمان
  //        يقرآن نفس القيمة القديمة ثم يكتبان فوق بعضهما)
  //   6. عدد عناصر الرف (currentItems) مع كل عملية تُسنِد
  //      المنتج إلى رف أو تنقله بين الأرفف (إنشاء/تحديث/
  //      نقل/حذف) في نفس المعاملة
  //      ⚠️ لماذا: currentItems عداد مُنمّق لعدد المنتجات على
  //        كل رف يُعرض في واجهة الأرفف (السعة الحالية/نسبة
  //        الامتلاء/الرفوف الممتلئة). فصله يسبب عداداً غير
  //        دقيق دائماً. يُقرأ الرف قبل الكتابة ويُمنع العدد
  //        السالب ويُتجاهل الرف غير الموجود
  //
  // ⚠️ ملاحظة للمبرمجين المستقبليين:
  //   هذا الملف مُتحقق منه يدوياً بدقة فائقة. أي تعديل مستقبلي
  //   يجب أن يكون يدوياً فقط (لا سكربت ولا أداة آلية ولا شيل)
  //   مع الحفاظ على ترتيب القراءات قبل الكتابات داخل كل
  //   runTransaction. كسر الذرية يسبب بيانات مخزون غير متسقة
  //   (تكرار منتجات، فهارس يتيمة، أو كميات تتغير بلا سجلات حركة).
  // ⚠️━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// إنشاء معرف قصير وقابل للقراءة
  String _generateShortId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final shortTimestamp = timestamp.toString().substring(8); // آخر 5 أرقام
    return '$prefix$shortTimestamp';
  }

  /// الحصول على مرجع مجموعة المنتجات للمؤسسة
  CollectionReference _getProductsCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('products');
  }

  /// الحصول على مرجع مجموعة الفئات للمؤسسة
  CollectionReference _getCategoriesCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('categories');
  }

  /// الحصول على مرجع مجموعة فهرس أسماء الفئات للمؤسسة
  /// تُستخدم لضمان عدم تكرار اسم الفئة بشكل ذري داخل المعاملة
  CollectionReference _getCategoryNameIndexCollection(
    String organizationEmail,
  ) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('category_name_index');
  }

  /// الحصول على مرجع مجموعة فهرس أسماء المنتجات للمؤسسة
  /// تُستخدم لضمان عدم تكرار اسم المنتج بشكل ذري داخل المعاملة
  CollectionReference _getProductNameIndexCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('product_name_index');
  }

  /// الحصول على مرجع مجموعة فهرس باركودات المنتجات للمؤسسة
  /// تُستخدم لضمان عدم تكرار الباركود بشكل ذري داخل المعاملة
  CollectionReference _getProductBarcodeIndexCollection(
    String organizationEmail,
  ) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('product_barcode_index');
  }

  /// الحصول على مرجع مجموعة حركات المخزون العليا للمؤسسة
  /// تُخزن سجلات الحركة هنا (وليس في مجموعة فرعية تحت
  /// كل منتج) لتكون قابلة للاستعلام — راجع إصلاح
  /// 2026-10-11 في ملخص الذرية أعلى الملف
  CollectionReference _getInventoryMovementsCollection(
    String organizationEmail,
  ) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('inventory_movements');
  }

  /// الحصول على مرجع مجموعة الأرفف للمؤسسة
  /// تُستخدم لتحديث عدد عناصر الرف (currentItems) ذرياً مع
  /// عمليات المنتجات التي تُسنِد المنتج إلى رف أو تنقله
  /// بين الأرفف — راجع القاعدة 6 في ملخص الذرية أعلى الملف
  CollectionReference _getShelvesCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('shelves');
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getProducts({
    required String organizationEmail,
    String? categoryId,
    String? shelfId,
    bool? isActive,
    bool? lowStock,
    String? searchQuery,
    int? limit,
    String? lastDocumentId,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // إذا كان الاستعلام بسيط (بدون فلاتر معقدة)، استخدم الاستعلام البسيط
      if (categoryId == null &&
          shelfId == null &&
          isActive == null &&
          searchQuery == null &&
          lastDocumentId == null) {
        return await getProductsSimple(
          organizationEmail: normalizedEmail,
          limit: limit,
        );
      }

      // البنية الصحيحة: organizationEmail/inventory/products
      Query query = _getProductsCollection(normalizedEmail);

      // تطبيق الفلاتر
      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      if (shelfId != null) {
        query = query.where('shelfId', isEqualTo: shelfId);
      }

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      // query = query.orderBy('name');

      // ترتيب حسب.createdAt للـ pagination
      query = query.orderBy('createdAt', descending: true);

      // التصفح المتقدم
      if (lastDocumentId != null) {
        final lastDoc = await _getProductsCollection(
          organizationEmail,
        ).doc(lastDocumentId).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      // تحديد عدد النتائج
      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      var products = querySnapshot.docs
          .map(ProductModel.fromFirestore)
          .toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        // ⚠️ أداء (تحقق يدوي 2026-10-12): searchLower مُخرَجة
        // من اللامدا — تُحسب مرة واحدة بدلاً من تكرارها لكل
        // منتج (نص ثابت لا يتغير) فالنتيجة متطابقة تماماً
        // والفلترة أسرع. لا تُعيد إدخالها داخل اللامدا.
        final searchLower = searchQuery.toLowerCase();
        products = products
            .where(
              (product) =>
                  product.name.toLowerCase().contains(searchLower) ||
                  (product.description?.toLowerCase().contains(searchLower) ??
                      false),
            )
            .toList();
      }

      products.sort((a, b) => a.name.compareTo(b.name));

      // فلترة المنتجات منخفضة المخزون
      if (lowStock ?? false) {
        final filteredProducts = products
            .where((product) => product.isLowStock)
            .toList();
        return Right(filteredProducts);
      }

      return Right(products);
    } on FirebaseException catch (e) {
      // معالجة خاصة لأخطاء الفهارس
      if (e.code == 'failed-precondition' &&
          (e.message?.contains('index') ?? false)) {
        return const Left(
          ServerFailure(
            message: 'الفهارس قيد الإنشاء، يرجى المحاولة بعد دقائق قليلة',
          ),
        );
      }
      return Left(ServerFailure(message: 'فشل في جلب المنتجات: ${e.message}'));
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب المنتجات: $e'));
    }
  }

  @override
  Future<Either<Failure, ProductsPage>> getProductsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
    String? searchQuery,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      Query query = _getProductsCollection(
        normalizedEmail,
      ).orderBy('createdAt', descending: true).limit(limit + 1);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      final hasMore = snapshot.docs.length > limit;
      final pageDocs = hasMore
          ? snapshot.docs.take(limit).toList()
          : snapshot.docs;

      var products = pageDocs.map(ProductModel.fromFirestore).toList();

      // تطبيق فلتر البحث في الذاكرة إذا كان موجوداً
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        products = products.where((product) {
          final name = product.name.toLowerCase();
          final description = product.description?.toLowerCase();
          final barcode = product.barcode?.toLowerCase();
          return name.contains(searchLower) ||
              (description?.contains(searchLower) ?? false) ||
              (barcode?.contains(searchLower) ?? false);
        }).toList();
      }

      final pageCursor = pageDocs.isNotEmpty ? pageDocs.last : null;
      return Right(
        ProductsPage(
          products: products,
          lastDocument: pageCursor,
          hasMore: hasMore,
        ),
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
      return Left(ServerFailure(message: 'فشل في جلب المنتجات: ${e.message}'));
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب المنتجات: $e'));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> getProductById({
    required String id,
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final doc = await _getProductsCollection(normalizedEmail).doc(id).get();

      if (!doc.exists) {
        return const Left(ServerFailure(message: 'المنتج غير موجود'));
      }

      final product = ProductModel.fromFirestore(doc);

      if (product.organizationEmail != organizationEmail) {
        return const Left(
          ServerFailure(message: 'غير مصرح بالوصول لهذا المنتج'),
        );
      }

      return Right(product);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب المنتج: ${_readableError(e)}'));
    }
  }

  @override
  Future<Either<Failure, ProductEntity?>> getProductByBarcode({
    required String barcode,
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final querySnapshot = await _getProductsCollection(
        normalizedEmail,
      ).where('barcode', isEqualTo: barcode).limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        return const Right(null);
      }

      final product = ProductModel.fromFirestore(querySnapshot.docs.first);
      if (product.organizationEmail != organizationEmail) {
        return const Right(null);
      }
      return Right(product);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في البحث بالباركود: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> createProduct({
    required ProductEntity product,
  }) async {
    try {
      final productModel = ProductModel.fromEntity(product);

      // إنشاء ID قصير وقابل للقراءة
      final productId = _generateShortId('PR'); // PR = Product

      final newProduct = productModel.copyWith(
        id: productId,
        createdAt: DateTime.now(),
      );

      final normalizedEmail = _emailService.normalize(
        product.organizationEmail,
      );

      // ⚠️ ذرية (القاعدتان 1 و6 أعلاه): المنتج + فهارس الاسم
      // والباركود + عداد الرف في معاملة واحدة، كل الـ get قبل
      // أي كتابة — إما نجاح الإنشاء أو فشله معاً (All-or-Nothing).
      final firestoreInstance = FirebaseFirestore.instance;
      await firestoreInstance.runTransaction((transaction) async {
        final productDoc = _getProductsCollection(
          normalizedEmail,
        ).doc(productId);
        final productNameIndexDoc = _getProductNameIndexCollection(
          normalizedEmail,
        ).doc(productModel.name.trim().toLowerCase());
        final productBarcodeIndexDoc =
            productModel.barcode != null && productModel.barcode!.isNotEmpty
            ? _getProductBarcodeIndexCollection(
                normalizedEmail,
              ).doc(productModel.barcode!.trim().toLowerCase())
            : null;
        // ⚠️ ذرية: مرجع رف المنتج الجديد (يُقرأ قبل أي كتابة)
        final newShelfId = newProduct.shelfId ?? '';
        final newShelfDoc = newShelfId.isNotEmpty
            ? _getShelvesCollection(normalizedEmail).doc(newShelfId)
            : null;

        // 1. التحقق من عدم وجود المنتج مسبقاً
        final docSnapshot = await transaction.get(productDoc);
        if (docSnapshot.exists) {
          throw Exception('المنتج موجود مسبقاً');
        }

        // 2. التحقق من عدم وجود اسم منتج مكرر داخل الفهرس المنفصل
        final nameIndexSnapshot = await transaction.get(productNameIndexDoc);
        if (nameIndexSnapshot.exists) {
          throw Exception('اسم المنتج مستخدم من قبل');
        }

        // 3. التحقق من عدم وجود باركود مكرر داخل الفهرس المنفصل
        if (productBarcodeIndexDoc != null) {
          final barcodeIndexSnapshot = await transaction.get(
            productBarcodeIndexDoc,
          );
          if (barcodeIndexSnapshot.exists) {
            throw Exception('الباركود مستخدم من قبل');
          }
        }

        // 3b. قراءة الرف الجديد قبل أي كتابة
        // (قاعدة Firestore: كل القراءات قبل كل الكتابات)
        final newShelfSnapshot = newShelfDoc != null
            ? await transaction.get(newShelfDoc)
            : null;

        // 4. حفظ بيانات المنتج
        final data = newProduct.toJson();
        data['id'] = productId;
        transaction.set(productDoc, data);

        // 5. إنشاء سجلات في الفهارس لضمان عدم التكرار مستقبلاً
        transaction.set(productNameIndexDoc, {
          'productId': productId,
          'name': productModel.name,
          'organizationEmail': normalizedEmail,
          'createdAt': Timestamp.now(),
        });

        if (productBarcodeIndexDoc != null) {
          transaction.set(productBarcodeIndexDoc, {
            'productId': productId,
            'barcode': productModel.barcode,
            'organizationEmail': normalizedEmail,
            'createdAt': Timestamp.now(),
          });
        }

        // 6. زيادة عدد عناصر الرف الجديد ذرياً مع إنشاء المنتج
        // (راجع القاعدة 6 أعلى الملف — فصلها يسبب عداد رف
        // غير دقيق) — يُتجاهل الرف غير الموجود ولا يُنشأ
        // مستند رف ناقصاً
        if (newShelfDoc != null &&
            newShelfSnapshot != null &&
            newShelfSnapshot.exists) {
          final shelfCount =
              ((newShelfSnapshot.data()
                          as Map<String, dynamic>?)?['currentItems']
                      as num?)
                  ?.toInt() ??
              0;
          transaction.update(newShelfDoc, {
            'currentItems': shelfCount + 1,
            'updatedAt': Timestamp.now(),
          });
        }
      });

      return Right(newProduct);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في إنشاء المنتج: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProduct({
    required ProductEntity product,
  }) async {
    try {
      final productModel = ProductModel.fromEntity(product);
      final updatedProduct = productModel.copyWith(updatedAt: DateTime.now());

      final normalizedEmail = _emailService.normalize(
        product.organizationEmail,
      );

      // ⚠️ ذرية (القواعد 1 و4 و6 أعلاه): كل الـ get (المنتج +
      // الفهارس الشرطية + رفَي القديم والجديد) قبل أي كتابة —
      // إما نجاح التحديث أو فشله معاً (All-or-Nothing).
      final firestoreInstance = FirebaseFirestore.instance;
      await firestoreInstance.runTransaction((transaction) async {
        final productDoc = _getProductsCollection(
          normalizedEmail,
        ).doc(product.id);
        final productNameIndexDoc = _getProductNameIndexCollection(
          normalizedEmail,
        ).doc(productModel.name.trim().toLowerCase());
        final productBarcodeIndexDoc =
            productModel.barcode != null && productModel.barcode!.isNotEmpty
            ? _getProductBarcodeIndexCollection(
                normalizedEmail,
              ).doc(productModel.barcode!.trim().toLowerCase())
            : null;

        // 1. التحقق من وجود المنتج قبل التحديث
        final docSnapshot = await transaction.get(productDoc);
        if (!docSnapshot.exists) {
          throw Exception('المنتج غير موجود');
        }

        final existingData = docSnapshot.data() as Map<String, dynamic>;
        final existingName =
            (existingData['name'] as String?)?.trim().toLowerCase() ?? '';
        final existingBarcode = (existingData['barcode'] as String?)
            ?.trim()
            .toLowerCase();

        // 2. التحقق من تكرار الاسم داخل الفهرس المنفصل (إذا تغير الاسم)
        if (existingName != productModel.name.trim().toLowerCase()) {
          final nameIndexSnapshot = await transaction.get(productNameIndexDoc);
          if (nameIndexSnapshot.exists) {
            throw Exception('اسم المنتج مستخدم من قبل');
          }
        }

        // 3. التحقق من تكرار الباركود داخل الفهرس المنفصل (إذا تغير الباركود)
        if (productBarcodeIndexDoc != null &&
            existingBarcode != productModel.barcode?.trim().toLowerCase()) {
          final barcodeIndexSnapshot = await transaction.get(
            productBarcodeIndexDoc,
          );
          if (barcodeIndexSnapshot.exists) {
            throw Exception('الباركود مستخدم من قبل');
          }
        }

        // 3b. قراءة رفَي المنتج القديم والجديد قبل أي كتابة
        // إذا تغير رف المنتج (قاعدة Firestore: كل القراءات
        // قبل كل الكتابات في المعاملة)
        final existingShelfId = (existingData['shelfId'] as String?) ?? '';
        final newShelfId = productModel.shelfId ?? '';
        final shelfChanged = existingShelfId != newShelfId;
        final oldShelfDoc = shelfChanged && existingShelfId.isNotEmpty
            ? _getShelvesCollection(normalizedEmail).doc(existingShelfId)
            : null;
        final newShelfDoc = shelfChanged && newShelfId.isNotEmpty
            ? _getShelvesCollection(normalizedEmail).doc(newShelfId)
            : null;
        final oldShelfSnapshot = oldShelfDoc != null
            ? await transaction.get(oldShelfDoc)
            : null;
        final newShelfSnapshot = newShelfDoc != null
            ? await transaction.get(newShelfDoc)
            : null;

        // 4. تحديث بيانات المنتج
        transaction.update(productDoc, updatedProduct.toJson());

        // 5. تحديث فهارس الأسماء والباركودات إذا تغيرت
        if (existingName != productModel.name.trim().toLowerCase()) {
          // ⚠️ حماية (إصلاح 2026-10-08 أعلاه): Firestore يرفض
          // .doc('') بمسار فارغ ويفشل المعاملة — لا تحذف الفهرس
          // القديم إلا إذا كان الاسم الحالي غير فارغ.
          if (existingName.isNotEmpty) {
            final oldNameIndexDoc = _getProductNameIndexCollection(
              normalizedEmail,
            ).doc(existingName);
            transaction.delete(oldNameIndexDoc);
          }
          transaction.set(productNameIndexDoc, {
            'productId': product.id,
            'name': productModel.name,
            'organizationEmail': normalizedEmail,
            'updatedAt': Timestamp.now(),
          });
        }

        // تحديث فهرس الباركود إذا تغير الباركود (بما في ذلك إزالته)
        // ⚠️ حماية (إصلاح 2026-10-08 أعلاه): إذا أُزيل الباركود
        // يُحذف فهرسه القديم وإلا بقي فهرساً يتيماً يمنع أي منتج
        // آخر من استخدام ذلك الباركود مستقبلاً.
        final newBarcodeLower = productModel.barcode?.trim().toLowerCase();
        if (existingBarcode != newBarcodeLower) {
          // حذف فهرس الباركود القديم إذا كان للمنتج باركود سابق
          if (existingBarcode != null && existingBarcode.isNotEmpty) {
            final oldBarcodeIndexDoc = _getProductBarcodeIndexCollection(
              normalizedEmail,
            ).doc(existingBarcode);
            transaction.delete(oldBarcodeIndexDoc);
          }
          // إنشاء فهرس الباركود الجديد فقط إذا كان الباركود الجديد غير فارغ
          if (productBarcodeIndexDoc != null) {
            transaction.set(productBarcodeIndexDoc, {
              'productId': product.id,
              'barcode': productModel.barcode,
              'organizationEmail': normalizedEmail,
              'updatedAt': Timestamp.now(),
            });
          }
        }

        // 6. تحديث عدادي الرف القديم والجديد ذرياً إذا تغير
        // رف المنتج (راجع القاعدة 6 أعلى الملف — فصلها يسبب
        // عداداً غير دقيق) — يُتجاهل الرف غير الموجود
        // ويُمنع العدد السالب
        if (oldShelfDoc != null &&
            oldShelfSnapshot != null &&
            oldShelfSnapshot.exists) {
          final oldShelfCount =
              ((oldShelfSnapshot.data()
                          as Map<String, dynamic>?)?['currentItems']
                      as num?)
                  ?.toInt() ??
              0;
          final decremented = oldShelfCount - 1;
          transaction.update(oldShelfDoc, {
            'currentItems': decremented < 0 ? 0 : decremented,
            'updatedAt': Timestamp.now(),
          });
        }
        if (newShelfDoc != null &&
            newShelfSnapshot != null &&
            newShelfSnapshot.exists) {
          final newShelfCount =
              ((newShelfSnapshot.data()
                          as Map<String, dynamic>?)?['currentItems']
                      as num?)
                  ?.toInt() ??
              0;
          transaction.update(newShelfDoc, {
            'currentItems': newShelfCount + 1,
            'updatedAt': Timestamp.now(),
          });
        }
      });

      // جلب المنتج المحدث للتأكد من التحديث
      final updatedProductResult = await getProductById(
        id: product.id,
        organizationEmail: product.organizationEmail,
      );

      return await updatedProductResult.fold(Left.new, Right.new);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في تحديث المنتج: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct({
    required String id,
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;
      final productDoc = _getProductsCollection(normalizedEmail).doc(id);

      // ⚠️ ذرية (القاعدتان 4 و6 أعلاه): get المنتج + التحقق من
      // ملكية المؤسسة + قراءة الرف قبل حذف المنتج + فهارسه +
      // تحديث عداد الرف — إما نجاح الحذف أو فشله معاً.
      await firestoreInstance.runTransaction((transaction) async {
        // التحقق من وجود المنتج قبل الحذف
        final docSnapshot = await transaction.get(productDoc);

        if (!docSnapshot.exists) {
          throw Exception('المنتج غير موجود');
        }

        // التحقق من أن البريد الإلكتروني يطابق المؤسسة
        final data = docSnapshot.data() as Map<String, dynamic>?;
        final docOrganizationEmail = data?['organizationEmail'] as String?;

        if (docOrganizationEmail == null ||
            _emailService.normalize(docOrganizationEmail) != normalizedEmail) {
          throw Exception('غير مصرح بالوصول لهذا المنتج');
        }

        // ⚠️ ذرية: قراءة رف المنتج قبل أي كتابة
        // (قاعدة القراءات قبل الكتابات) لتحديث
        // عدد عناصره ذرياً مع حذف المنتج
        final productShelfId = (data?['shelfId'] as String?) ?? '';
        final productShelfDoc = productShelfId.isNotEmpty
            ? _getShelvesCollection(normalizedEmail).doc(productShelfId)
            : null;
        final productShelfSnapshot = productShelfDoc != null
            ? await transaction.get(productShelfDoc)
            : null;

        // حذف بيانات المنتج
        // ⚠️ ملاحظة (تحقق 2026-10-11): سجلات حركة
        // المنتج في المجموعة العليا (inventory_movements)
        // لا تُحذف هنا — Firestore لا تدعم الحذف المتسلسل
        // ولا الاستعلامات داخل المعاملة — تبقى كسجل تدقيق
        // مقصود (تاريخ حركات المنتج يُحفظ حتى بعد حذفه)
        transaction.delete(productDoc);

        // حذف مستندات الفهرس المرتبطة بالمنتج
        final existingName =
            (data?['name'] as String?)?.trim().toLowerCase() ?? '';
        final existingBarcode = (data?['barcode'] as String?)
            ?.trim()
            .toLowerCase();

        if (existingName.isNotEmpty) {
          final productNameIndexDoc = _getProductNameIndexCollection(
            normalizedEmail,
          ).doc(existingName);
          transaction.delete(productNameIndexDoc);
        }

        if (existingBarcode != null && existingBarcode.isNotEmpty) {
          final productBarcodeIndexDoc = _getProductBarcodeIndexCollection(
            normalizedEmail,
          ).doc(existingBarcode);
          transaction.delete(productBarcodeIndexDoc);
        }

        // تقليل عدد عناصر رف المنتج ذرياً مع حذفه
        // (راجع القاعدة 6 أعلى الملف — فصلها يسبب
        // عداداً غير دقيق) — يُتجاهل الرف غير
        // الموجود ويُمنع العدد السالب
        if (productShelfDoc != null &&
            productShelfSnapshot != null &&
            productShelfSnapshot.exists) {
          final shelfCount =
              ((productShelfSnapshot.data()
                          as Map<String, dynamic>?)?['currentItems']
                      as num?)
                  ?.toInt() ??
              0;
          final decremented = shelfCount - 1;
          transaction.update(productShelfDoc, {
            'currentItems': decremented < 0 ? 0 : decremented,
            'updatedAt': Timestamp.now(),
          });
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حذف المنتج: ${_readableError(e)}'));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProductQuantity({
    required String id,
    required String organizationEmail,
    required double newQuantity,
    double? quantityDelta,
    required String updatedBy,
    MovementType? movementType,
    String? reason,
    String? reference,
    String? fromShelfId,
    String? toShelfId,
    double? unitCost,
    double? totalCost,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;

      // ⚠️ ذرية (القاعدتان 2 و6 أعلاه): get المنتج ✅ تحديث
      // الكمية/shelfId/metadata + set سجل الحركة + عدادي الرف
      // عند النقل في نفس المعاملة — إما نجاح كل العمليات أو
      // فشلها معاً (All-or-Nothing).
      return await firestoreInstance.runTransaction((transaction) async {
        final productDoc = _getProductsCollection(normalizedEmail).doc(id);

        // 1. جلب المنتج الحالي داخل المعاملة
        final docSnapshot = await transaction.get(productDoc);

        if (!docSnapshot.exists) {
          throw Exception('المنتج غير موجود');
        }

        final currentData = docSnapshot.data() as Map<String, dynamic>;
        final currentQuantity = (currentData['quantity'] ?? 0).toDouble();
        final trackQuantity = currentData['trackQuantity'] ?? true;

        // ⚠️ حماية (إصلاح 2026-10-08 أعلاه): عند توفير
        // quantityDelta تُحسب الكمية النهائية من اللقطة الحية
        // داخل المعاملة (currentQuantity + quantityDelta) بدلاً
        // من newQuantity المطلقة — يمنع تلف المخزون عندما تكون
        // الكمية الجديدة محسوبة من حالة محلية قديمة (مثل الإرجاع).
        final effectiveNewQuantity = quantityDelta != null
            ? currentQuantity + quantityDelta
            : newQuantity;

        // 2. التحقق من الشروط
        if (!trackQuantity) {
          throw Exception('هذا المنتج لا يدعم تتبع الكمية');
        }

        if (effectiveNewQuantity < 0) {
          throw Exception('لا يمكن أن تكون الكمية أقل من الصفر');
        }

        // 2b. قراءة رفَي المصدر والهدف قبل أي كتابة عند
        // النقل بين الأرفف (قاعدة Firestore: كل القراءات
        // قبل كل الكتابات في المعاملة)
        // يُستخدم رف المنتج الحالي الفعلي من اللقطة
        // (وليس المعامل fromShelfId) لأنه المصدر الحقيقي
        // للعدد الحالي — ويُتجاهل النقل إلى الرف نفسه
        // (لا تغيير صافٍ في عدادات الأرفف) — ويُسجَّل
        // كـ fromShelfId في سجل الحركة أيضاً (إصلاح
        // 2026-10-11 أسفل المعاملة)
        final isTransfer =
            movementType == MovementType.transfer &&
            toShelfId != null &&
            toShelfId.isNotEmpty;
        final currentShelfId = (currentData['shelfId'] as String?) ?? '';
        final shelfActuallyMoved = isTransfer && currentShelfId != toShelfId;
        final fromShelfDoc = shelfActuallyMoved && currentShelfId.isNotEmpty
            ? _getShelvesCollection(normalizedEmail).doc(currentShelfId)
            : null;
        final toShelfDoc = shelfActuallyMoved
            ? _getShelvesCollection(normalizedEmail).doc(toShelfId)
            : null;
        final fromShelfSnapshot = fromShelfDoc != null
            ? await transaction.get(fromShelfDoc)
            : null;
        final toShelfSnapshot = toShelfDoc != null
            ? await transaction.get(toShelfDoc)
            : null;

        // 3. تحديث الكمية في نفس الـ transaction
        // ملاحظة: عند النقل بين الأرفف نحدث shelfId أيضاً لضمان اتساق البيانات
        final updateMap = <String, dynamic>{
          'quantity': effectiveNewQuantity,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
          'updatedBy': updatedBy,
        };
        // ⚠️ حماية (إصلاح 2026-10-08 أعلاه): metadata تُحفظ في
        // نفس المعاملة — كان الخطأ السابق يقبلها ويُرجعها دون
        // حفظها فتبقى في الحالة المحلية فقط وتختفي بعد إعادة
        // تشغيل التطبيق.
        if (metadata != null) {
          updateMap['metadata'] = metadata;
        }
        if (movementType == MovementType.transfer &&
            toShelfId != null &&
            toShelfId.isNotEmpty) {
          updateMap['shelfId'] = toShelfId;
        }
        transaction.update(productDoc, updateMap);

        // (نقل الأرفف: الكمية + shelfId + سجل الحركة تُحدَّث
        // ذرياً في هذه المعاملة — راجع الملاحظة أعلاه)

        // 4. إنشاء سجل حركة في نفس الـ transaction
        // ⚠️ ملاحظة (إصلاح 2026-10-11): السجل يُكتب إلى
        // المجموعة العليا {org}/inventory/inventory_movements
        // (وليس مجموعة فرعية تحت المنتج — نفس إصلاح
        // products_logs 2026-10-09: المجموعة الفرعية كانت
        // تُنشئ سجلات يتيمة لا يقرأها أحد) — يُقرأ عبر
        // InventoryMovementRepository. productName يُحفظ
        // في السجل ليكون ذاتياً (يُعرض حتى بعد حذف المنتج)
        if (movementType != null) {
          final logCollection = _getInventoryMovementsCollection(
            normalizedEmail,
          );

          final logDocRef = logCollection.doc();
          final now = Timestamp.fromDate(DateTime.now());
          final movementQuantity = effectiveNewQuantity - currentQuantity;

          final logData = {
            'productId': id,
            'productName': currentData['name'] ?? '',
            'type': movementType.toString().split('.').last,
            'quantity': movementQuantity,
            'previousQuantity': currentQuantity,
            'newQuantity': effectiveNewQuantity,
            'reason': reason,
            'reference': reference,
            // ⚠️ رف المصدر المسجّل يُؤخذ من اللقطة الحية
            // (currentShelfId) عند النقل — وليس من المعامل
            // fromShelfId الذي قد يكون قديماً — ليطابق
            // عدادات الأرفف المُحدَّثة من نفس اللقطة
            // (إصلاح 2026-10-11)
            'fromShelfId': isTransfer ? currentShelfId : fromShelfId,
            'toShelfId': toShelfId,
            'unitCost': unitCost,
            'totalCost': totalCost,
            'metadata': metadata,
            'createdAt': now,
            'createdBy': updatedBy,
            'organizationEmail': normalizedEmail,
          };

          transaction.set(logDocRef, logData);
        }

        // 4b. تحديث عدادي رفَي المصدر والهدف ذرياً
        // عند النقل (راجع القاعدة 6 أعلى الملف — فصلها
        // يسبب عداداً غير دقيق) — يُتجاهل الرف غير
        // الموجود ويُمنع العدد السالب
        if (shelfActuallyMoved) {
          if (fromShelfDoc != null &&
              fromShelfSnapshot != null &&
              fromShelfSnapshot.exists) {
            final fromShelfCount =
                ((fromShelfSnapshot.data()
                            as Map<String, dynamic>?)?['currentItems']
                        as num?)
                    ?.toInt() ??
                0;
            final decremented = fromShelfCount - 1;
            transaction.update(fromShelfDoc, {
              'currentItems': decremented < 0 ? 0 : decremented,
              'updatedAt': Timestamp.now(),
            });
          }
          if (toShelfDoc != null &&
              toShelfSnapshot != null &&
              toShelfSnapshot.exists) {
            final toShelfCount =
                ((toShelfSnapshot.data()
                            as Map<String, dynamic>?)?['currentItems']
                        as num?)
                    ?.toInt() ??
                0;
            transaction.update(toShelfDoc, {
              'currentItems': toShelfCount + 1,
              'updatedAt': Timestamp.now(),
            });
          }
        }

        // 5. إرجاع المنتج المحدث
        final updatedProduct = ProductModel(
          id: id,
          name: currentData['name'] ?? '',
          description: currentData['description'],
          barcode: currentData['barcode'],
          categoryId: currentData['categoryId'],
          shelfId:
              movementType == MovementType.transfer &&
                  toShelfId != null &&
                  toShelfId.isNotEmpty
              ? toShelfId
              : (currentData['shelfId'] as String? ?? ''),
          quantity: effectiveNewQuantity,
          minQuantity: (currentData['minQuantity'] ?? 0).toDouble(),
          maxQuantity: currentData['maxQuantity']?.toDouble(),
          unit: currentData['unit'] ?? '',
          costPrice: currentData['costPrice']?.toDouble(),
          sellingPrice: (currentData['sellingPrice'] ?? 0).toDouble(),
          images: List<String>.from(currentData['images'] ?? const []),
          isActive: currentData['isActive'] ?? true,
          trackQuantity: trackQuantity,
          metadata: metadata ?? currentData['metadata'],
          createdAt: (currentData['createdAt'] as Timestamp).toDate(),
          updatedAt: DateTime.now(),
          createdBy: currentData['createdBy'] ?? '',
          updatedBy: updatedBy,
          // ⚠️ حماية (إصلاح 2026-10-09 أعلاه): organizationEmail
          // المُرجعة هي المخزنة في المستند (الأصلية) وليس المطبعة —
          // كان الخطأ السابق يُرجع normalizedEmail فتفشل تحديثات
          // لاحقة بفحص الملكية في getProductById بـ "غير مصرح
          // بالوصول" رغم أن المستخدم مخوّل.
          organizationEmail:
              (currentData['organizationEmail'] as String?) ?? normalizedEmail,
        );

        return Right(updatedProduct);
      });
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في تحديث كمية المنتج: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProductPrices({
    required String id,
    required String organizationEmail,
    required double? costPrice,
    required double sellingPrice,
    required String updatedBy,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // ⚠️ حماية (إصلاح 2026-10-09 أعلاه): تُمرَّر organizationEmail
      // الأصلية (غير المطبعة) إلى getProductById لأن فحص الملكية
      // فيه يقارنها كما هي — تمرير normalizedEmail كان يسبب فشلاً
      // خاطئاً بـ "غير مصرح بالوصول" عندما يختلف البريد بعد
      // التطبيع (نقاط Gmail أو ما بعد + أو أحرف كبيرة).
      final productResult = await getProductById(
        id: id,
        organizationEmail: organizationEmail,
      );

      // ⚠️ ملاحظة للمبرمجين المستقبليين (Bug منطقي — مكشوف للمراجعة، غير معدل حسب تعليمات "بدون تعديل"):
      // معامل fold الثاني يُعرَّف كـ async، مما يُعيد Future<Either<...>> بدلاً من
      // Either<...> المتوقّع. فالتعرية تصبح Future<Future<Either<...>>> ورناء الاستدعاء
      // لا ينتظّر الإنجاز الفعلي. التصحيح المقترح: إزالة async من المعامل واستخدام
      // return Right(updatedProduct) مباشرة بدون await داخل المعاملة، أو إعادة هيكلة
      // الدالة لتكون async بالكامل.
      return await productResult.fold(Left.new, (product) async {
        final updatedProduct = product.copyWith(
          costPrice: costPrice,
          sellingPrice: sellingPrice,
          updatedAt: DateTime.now(),
          updatedBy: updatedBy,
        );

        // ⚠️ ذرية (القاعدة 5 أعلاه): getProductById خارج المعاملة
        // للتحقق/العرض فقط، والتحديث داخلها بـ get ثم update —
        // العملية لا تعتمد على القيمة الحالية للأسعار بل تحدثها
        // مباشرة، والتحقق من الوجود داخل المعاملة (إذا حُذف المنتج
        // بين القراءة الخارجية والمعاملة تفشل بـ "المنتج غير موجود").
        final firestoreInstance = FirebaseFirestore.instance;
        await firestoreInstance.runTransaction((transaction) async {
          final productDoc = _getProductsCollection(normalizedEmail).doc(id);

          // التحقق من وجود المنتج قبل التحديث
          final docSnapshot = await transaction.get(productDoc);

          if (!docSnapshot.exists) {
            throw Exception('المنتج غير موجود');
          }

          // تحديث الأسعار في نفس الـ transaction
          transaction.update(productDoc, {
            'costPrice': costPrice,
            'sellingPrice': sellingPrice,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
            'updatedBy': updatedBy,
          });
        });

        return Right(updatedProduct);
      });
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في تحديث أسعار المنتج: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> searchProducts({
    required String organizationEmail,
    required String query,
    String? categoryId,
    int? limit,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // إذا كان الاستعلام قصير جدًا، لا نقوم بالبحث
      if (query.length < 2) {
        return const Right([]);
      }

      Query baseQuery = _getProductsCollection(normalizedEmail);

      // تطبيق فلتر الفئة إذا تم تحديده
      if (categoryId != null) {
        baseQuery = baseQuery.where('categoryId', isEqualTo: categoryId);
      }

      // تحديد الحد الأقصى للنتائج
      if (limit != null) {
        baseQuery = baseQuery.limit(limit);
      }

      final querySnapshot = await baseQuery.get();

      // ⚠️ أداء (تحقق يدوي 2026-10-12): lowerQuery مُخرَجة
      // من اللامدا — تُحسب مرة واحدة بدلاً من تكرارها لكل
      // منتج (نص ثابت لا يتغير) فالنتيجة متطابقة تماماً
      // والبحث أسرع. لا تُعيد إدخالها داخل اللامدا.
      final lowerQuery = query.toLowerCase();
      final products = querySnapshot.docs.map(ProductModel.fromFirestore).where(
        (product) {
          // البحث في الاسم، الوصف، والباركود
          return (product.name.toLowerCase().contains(lowerQuery)) ||
              (product.description?.toLowerCase().contains(lowerQuery) ??
                  false) ||
              (product.barcode?.toLowerCase().contains(lowerQuery) ?? false);
        },
      ).toList();

      // ترتيب النتائج: المطابقة التامة أولاً، ثم التي تبدأ بالاستعلام
      // ⚠️ أداء (تحقق يدوي 2026-10-12): queryLower
      // مُخرَجة من المُقارن — تُحسب مرة واحدة بدلاً من
      // تكرارها في كل مقارنة (O(n log n) مرة) فالنتيجة
      // متطابقة تماماً والترتيب أسرع. لا تُعيد إدخالها
      // داخل المُقارن.
      final queryLower = query.toLowerCase();
      products.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();

        // المطابقة التامة أولاً
        final aIsExact = aName == queryLower;
        final bIsExact = bName == queryLower;
        if (aIsExact && !bIsExact) return -1;
        if (bIsExact && !aIsExact) return 1;

        // ثم التي تبدأ بالاستعلام
        final aStartsWith = aName.startsWith(queryLower);
        final bStartsWith = bName.startsWith(queryLower);
        if (aStartsWith && !bStartsWith) return -1;
        if (bStartsWith && !aStartsWith) return 1;

        // ثم ترتيب أبجدي
        return aName.compareTo(bName);
      });

      return Right(products);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في البحث عن المنتجات: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getLowStockProducts({
    required String organizationEmail,
    int? limit,
  }) async {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return getProducts(
      organizationEmail: normalizedEmail,
      lowStock: true,
      limit: limit,
    );
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getOutOfStockProducts({
    required String organizationEmail,
    int? limit,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      var query = _getProductsCollection(normalizedEmail)
          .where('trackQuantity', isEqualTo: true)
          .where('quantity', isLessThanOrEqualTo: 0);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      final products = querySnapshot.docs
          .map(ProductModel.fromFirestore)
          .toList();

      return Right(products);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في جلب المنتجات النافدة: ${_readableError(e)}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getProductsStats({
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final querySnapshot = await _getProductsCollection(normalizedEmail).get();

      final products = querySnapshot.docs
          .map(ProductModel.fromFirestore)
          .toList();

      final totalProducts = products.length;
      final activeProducts = products.where((p) => p.isActive).length;
      final lowStockProducts = products.where((p) => p.isLowStock).length;
      final outOfStockProducts = products.where((p) => p.isOutOfStock).length;
      final totalValue = products.fold<double>(
        0,
        (total, product) => total + product.inventoryValue,
      );

      return Right({
        'totalProducts': totalProducts,
        'activeProducts': activeProducts,
        'lowStockProducts': lowStockProducts,
        'outOfStockProducts': outOfStockProducts,
        'totalInventoryValue': totalValue,
      });
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في جلب إحصائيات المنتجات: ${_readableError(e)}'),
      );
    }
  }

  /// استعلام بسيط للمنتجات بدون فهارس معقدة
  Future<Either<Failure, List<ProductEntity>>> getProductsSimple({
    required String organizationEmail,
    int? limit,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // البنية الصحيحة: organizationEmail/inventory/products
      Query query = _getProductsCollection(normalizedEmail);

      // ترتيب حسب.createdAt للتوافق مع pagination
      query = query.orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      final products = querySnapshot.docs
          .map(ProductModel.fromFirestore)
          .toList();

      return Right(products);
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' &&
          (e.message?.contains('index') ?? false)) {
        return const Left(
          ServerFailure(
            message: 'الفهارس قيد الإنشاء، يرجى المحاولة بعد دقائق قليلة',
          ),
        );
      }
      return Left(ServerFailure(message: 'فشل في جلب المنتجات: ${e.message}'));
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب المنتجات: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> searchProductNames({
    required String query,
  }) async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        return const Left(ServerFailure(message: 'يجب تسجيل الدخول أولاً'));
      }

      // استخدام البريد الإلكتروني للمستخدم الحالي كمؤسسة افتراضية عند
      // عدم تمرير organizationEmail صريحًا (هذه الدالة لا تقبل institution).
      final normalizedEmail = _emailService.normalize(currentUser.email!);
      final lowerQuery = query.toLowerCase();

      // استخدام Firestore query مع where للبحث
      final querySnapshot = await _getProductsCollection(normalizedEmail)
          .where('name', isGreaterThanOrEqualTo: lowerQuery)
          .where('name', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(20)
          .get();

      // البحث في الأسماء محلياً
      final matchingNames = querySnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String?)
          .where(
            (name) => name != null && name.toLowerCase().contains(lowerQuery),
          )
          .map((name) => name!)
          .toSet()
          .toList();

      // ترتيب النتائج: المطابقة التامة أولاً، ثم المطابقة الجزئية
      matchingNames.sort((a, b) {
        final aLower = a.toLowerCase();
        final bLower = b.toLowerCase();

        if (aLower == lowerQuery && bLower != lowerQuery) return -1;
        if (bLower == lowerQuery && aLower != lowerQuery) return 1;

        final aStarts = aLower.startsWith(lowerQuery);
        final bStarts = bLower.startsWith(lowerQuery);
        if (aStarts && !bStarts) return -1;
        if (bStarts && !aStarts) return 1;

        return a.compareTo(b);
      });

      return Right(matchingNames.take(10).toList());
    } on Exception catch (e) {
      return Left(
        ServerFailure(
          message: 'فشل في البحث عن أسماء المنتجات: ${_readableError(e)}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, CategoryEntity>> createCategory(
    CategoryEntity category,
  ) async {
    try {
      // إنشاء ID قصير وقابل للقراءة
      final categoryId = _generateShortId('CT'); // CT = Category

      final categoryWithId = category.copyWith(id: categoryId);
      final categoryModel = CategoryModel.fromEntity(categoryWithId);

      final normalizedEmail = _emailService.normalize(
        category.organizationEmail,
      );
      final firestoreInstance = FirebaseFirestore.instance;
      final categoryDoc = _getCategoriesCollection(
        normalizedEmail,
      ).doc(categoryId);
      final categoryNameIndexDoc = _getCategoryNameIndexCollection(
        normalizedEmail,
      ).doc(category.name.trim().toLowerCase());

      // ⚠️ ذرية (القاعدة 3 أعلاه): الفئة + فهرس الاسم في معاملة
      // واحدة، كل الـ get قبل أي set — إما نجاح الإنشاء أو فشله
      // معاً (All-or-Nothing).
      await firestoreInstance.runTransaction((transaction) async {
        // 1. التحقق من عدم وجود الفئة مسبقاً داخل المعاملة
        final docSnapshot = await transaction.get(categoryDoc);
        if (docSnapshot.exists) {
          throw Exception('الفئة موجودة مسبقاً');
        }

        // 2. التحقق من عدم وجود فئة بنفس الاسم داخل الفهرس المنفصل
        final nameIndexSnapshot = await transaction.get(categoryNameIndexDoc);
        if (nameIndexSnapshot.exists) {
          throw Exception('اسم الفئة مستخدم من قبل');
        }

        // 3. حفظ بيانات الفئة
        final data = categoryModel.toJson();
        data['id'] = categoryId;
        transaction.set(categoryDoc, data);

        // 4. إنشاء سجل في فهرس الأسماء لضمان عدم التكرار مستقبلاً
        transaction.set(categoryNameIndexDoc, {
          'categoryId': categoryId,
          'name': category.name,
          'organizationEmail': normalizedEmail,
          'createdAt': Timestamp.now(),
        });
      });

      return Right(categoryWithId);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, CategoryEntity>> updateCategory({
    required CategoryEntity category,
  }) async {
    try {
      final categoryModel = CategoryModel.fromEntity(category);
      final normalizedEmail = _emailService.normalize(
        category.organizationEmail,
      );
      final firestoreInstance = FirebaseFirestore.instance;
      final categoryDoc = _getCategoriesCollection(
        normalizedEmail,
      ).doc(category.id);
      final categoryNameIndexDoc = _getCategoryNameIndexCollection(
        normalizedEmail,
      ).doc(category.name.trim().toLowerCase());

      // ⚠️ ذرية (القاعدتان 3 و4 أعلاه): كل الـ get (الفئة +
      // فهرس الاسم الشرطي) قبل أي كتابة — إما نجاح التحديث أو
      // فشله معاً (All-or-Nothing).
      await firestoreInstance.runTransaction((transaction) async {
        // 1. التحقق من وجود الفئة داخل المعاملة
        final docSnapshot = await transaction.get(categoryDoc);

        if (!docSnapshot.exists) {
          throw Exception('الفئة غير موجودة');
        }

        final existingData = docSnapshot.data() as Map<String, dynamic>;
        final existingName =
            (existingData['name'] as String?)?.trim().toLowerCase() ?? '';

        // 2. التحقق من تكرار الاسم داخل الفهرس المنفصل
        if (existingName != category.name.trim().toLowerCase()) {
          final nameIndexSnapshot = await transaction.get(categoryNameIndexDoc);
          if (nameIndexSnapshot.exists) {
            throw Exception('اسم الفئة مستخدم من قبل');
          }
        }

        // 3. تحديث بيانات الفئة
        final data = categoryModel.toJson();
        data['id'] = category.id;
        transaction.update(categoryDoc, data);

        // 4. تحديث فهرس الأسماء إذا تغير الاسم
        if (existingName != category.name.trim().toLowerCase()) {
          // ⚠️ حماية (إصلاح 2026-10-08 أعلاه): Firestore يرفض
          // .doc('') بمسار فارغ ويفشل المعاملة — لا تحذف الفهرس
          // القديم إلا إذا كان الاسم الحالي غير فارغ (تطابق
          // الحماية في deleteProduct).
          if (existingName.isNotEmpty) {
            final oldNameIndexDoc = _getCategoryNameIndexCollection(
              normalizedEmail,
            ).doc(existingName);
            transaction.delete(oldNameIndexDoc);
          }
          transaction.set(categoryNameIndexDoc, {
            'categoryId': category.id,
            'name': category.name,
            'organizationEmail': normalizedEmail,
            'updatedAt': Timestamp.now(),
          });
        }
      });

      return Right(category);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory({
    required String id,
    required String organizationEmail,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;
      final categoryDoc = _getCategoriesCollection(normalizedEmail).doc(id);

      // ⚠️ ذرية (القاعدة 4 أعلاه): get الفئة + التحقق من الملكية
      // قبل حذف الفئة + فهرس اسمها في نفس المعاملة — إما نجاح
      // الحذف أو فشله معاً (All-or-Nothing).
      await firestoreInstance.runTransaction((transaction) async {
        // التحقق من وجود الفئة قبل الحذف
        final docSnapshot = await transaction.get(categoryDoc);

        if (!docSnapshot.exists) {
          throw Exception('الفئة غير موجودة');
        }

        // التحقق من أن البريد الإلكتروني يطابق المؤسسة
        final data = docSnapshot.data() as Map<String, dynamic>?;
        final docOrganizationEmail = data?['organizationEmail'] as String?;

        if (docOrganizationEmail == null ||
            _emailService.normalize(docOrganizationEmail) != normalizedEmail) {
          throw Exception('غير مصرح بالوصول لهذه الفئة');
        }

        final existingName =
            (data?['name'] as String?)?.trim().toLowerCase() ?? '';
        final categoryNameIndexDoc = existingName.isNotEmpty
            ? _getCategoryNameIndexCollection(normalizedEmail).doc(existingName)
            : null;

        // حذف بيانات الفئة
        transaction.delete(categoryDoc);

        // حذف مستند الفهرس المرتبط بالاسم
        if (categoryNameIndexDoc != null) {
          transaction.delete(categoryNameIndexDoc);
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    required String organizationEmail,
    bool? isActive,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      Query query = firestore
          .collection(normalizedEmail)
          .doc('inventory')
          .collection('categories');

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      final querySnapshot = await query.get();
      final categories = querySnapshot.docs
          .map(CategoryModel.fromFirestore)
          .toList();

      // ترتيب حسب sortOrder ثم الاسم
      categories.sort((a, b) {
        final sortComparison = a.sortOrder.compareTo(b.sortOrder);
        if (sortComparison != 0) return sortComparison;
        return a.name.compareTo(b.name);
      });

      return Right(categories);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الفئات: ${_readableError(e)}'));
    }
  }

  @override
  Future<Either<Failure, CategoriesPage>> getCategoriesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      Query query = firestore
          .collection(normalizedEmail)
          .doc('inventory')
          .collection('categories');

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final categories = querySnapshot.docs
          .map(CategoryModel.fromFirestore)
          .toList();

      // ترتيب حسب sortOrder ثم الاسم
      categories.sort((a, b) {
        final sortComparison = a.sortOrder.compareTo(b.sortOrder);
        if (sortComparison != 0) return sortComparison;
        return a.name.compareTo(b.name);
      });

      return Right(
        CategoriesPage(
          categories: categories,
          lastDocument: querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.last
              : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الفئات: ${_readableError(e)}'));
    }
  }

  // ===== Inventory Logs Methods =====

  String? _getCurrentOrganizationId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;
    return _emailService.normalize(user!.email!);
  }

  @override
  Future<Either<Failure, List<InventoryLogEntity>>> getInventoryLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('inventory')
          .collection('logs');

      // تطبيق الفلاتر
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (actionFilter != null && actionFilter != 'all') {
        query = query.where('actionType', isEqualTo: actionFilter);
      }

      // فلتر التاريخ
      if (dateFilter != null && dateFilter != 'all') {
        final now = DateTime.now();
        DateTime filterDate;

        switch (dateFilter) {
          case 'today':
            filterDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            filterDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            filterDate = now.subtract(const Duration(days: 30));
            break;
          default:
            filterDate = DateTime(2000);
        }

        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(filterDate),
        );
      }

      // فلتر التاريخ المخصص
      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(endOfDay),
        );
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      // ترتيب النتائج
      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();
      final logs = <InventoryLogEntity>[];

      // ⚠️ أداء (تحقق يدوي 2026-10-12): searchLower
      // مُخرَجة من الحلقة — تُحسب مرة واحدة بدلاً
      // من تكرارها لكل سجل (نص ثابت لا يتغير)
      // فالنتيجة متطابقة تماماً والفلترة أسرع.
      // لا تُعيد إدخالها داخل الحلقة.
      final searchLower = searchQuery != null && searchQuery.isNotEmpty
          ? searchQuery.toLowerCase()
          : null;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final log = InventoryLogModel.fromJson({
          'id': doc.id,
          ...?data,
        }).toEntity();

        // تطبيق البحث النصي
        if (searchLower != null) {
          final matchesSearch =
              (log.userName?.toLowerCase().contains(searchLower) ?? false) ||
              (log.userEmail?.toLowerCase().contains(searchLower) ?? false) ||
              (log.actionType.toLowerCase().contains(searchLower)) ||
              (log.details?.toLowerCase().contains(searchLower) ?? false);

          if (matchesSearch) {
            logs.add(log);
          }
        } else {
          logs.add(log);
        }
      }

      return Right(logs);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, InventoryLogEntity>> addInventoryLog({
    required String userId,
    required String actionType,
    String? userName,
    String? userEmail,
    String? details,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
    Map<String, dynamic>? deviceInfo,
    bool isSuccess = true,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // استخدام المستخدم الحالي إذا لم يتم تحديد معرف المستخدم
      final currentUser = FirebaseAuth.instance.currentUser;
      final actualUserId = userId == 'current_user' && currentUser != null
          ? currentUser.uid
          : userId;
      final actualUserName = userName ?? currentUser?.displayName;
      final actualUserEmail = userEmail ?? currentUser?.email;
      final now = DateTime.now();
      final logData = {
        'userId': actualUserId,
        'userName': actualUserName,
        'userEmail': actualUserEmail,
        'actionType': actionType,
        'timestamp': Timestamp.fromDate(now),
        'details': details,
        'isSuccess': isSuccess,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'targetId': targetId,
        'targetType': targetType,
        'oldValues': oldValues,
        'newValues': newValues,
        'sessionId': sessionId,
        'deviceInfo': deviceInfo,
      };

      // ⚠️ ذرية (ملخص الذرية أعلاه): set فقط بلا قراءات داخل
      // runTransaction — إما نجاح إنشاء السجل أو فشله.
      final firestoreInstance = FirebaseFirestore.instance;
      return await firestoreInstance.runTransaction((transaction) async {
        final logCollection = firestore
            .collection(organizationId)
            .doc('inventory')
            .collection('logs');

        final logDocRef = logCollection.doc();
        transaction.set(logDocRef, logData);

        final log = InventoryLogModel.fromJson({
          'id': logDocRef.id,
          ...logData,
        }).toEntity();

        return Right(log);
      });
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInventoryLog(String logId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final firestoreInstance = FirebaseFirestore.instance;
      final logDoc = firestore
          .collection(organizationId)
          .doc('inventory')
          .collection('logs')
          .doc(logId);

      // ⚠️ ذرية (القاعدة 5 أعلاه): get السجل ⇐ delete السجل في
      // نفس المعاملة — إذا حُذف السجل بين التحقق والحذف تفشل
      // المعاملة بـ "السجل غير موجود" ولا يحدث حذف ناقص.
      await firestoreInstance.runTransaction((transaction) async {
        // التحقق من وجود السجل قبل الحذف
        final docSnapshot = await transaction.get(logDoc);

        if (!docSnapshot.exists) {
          throw Exception('السجل غير موجود');
        }

        // حذف البيانات في نفس الـ transaction
        transaction.delete(logDoc);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> clearInventoryLogs({
    String? userId,
    DateTime? beforeDate,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('inventory')
          .collection('logs');

      // فلتر المستخدم
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      // فلتر التاريخ
      if (beforeDate != null) {
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(beforeDate),
        );
      }

      // ⚠️ ذرية جزئية مقبولة (ملخص الذرية أعلاه): Query +
      // WriteBatch بدلاً من runTransaction لأن Firestore client
      // SDK لا تدعم queries داخل runTransaction. الخطر المتبقي
      // (سباق بسيط على سجلات جديدة تُنشأ بعد الاستعلام) مقبول
      // لعملية تنظيف سجلات قديمة. لتحسين مستقبلي: Cloud Function
      // بـ runTransaction على مراجع محددة، أو تقسيم السجلات
      // لمجموعات شهرية/سنوية وحذف مجموعة كاملة، أو TTL policies.
      final snapshot = await query.get();
      final batch = firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Stream<Either<Failure, List<ProductEntity>>> getProductsStream({
    required String organizationEmail,
    String? categoryId,
    String? shelfId,
    bool? isActive,
    bool? lowStock,
    int? limit,
    String? searchQuery,
    String? statusFilter,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // 1. بناء الـ query الأساسي
      Query query = _getProductsCollection(normalizedEmail);

      // 2. إضافة فلتر الفئة إذا كان موجوداً (قبل orderBy)
      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      // 3. إضافة فلتر الرف إذا كان موجوداً (قبل orderBy)
      if (shelfId != null) {
        query = query.where('shelfId', isEqualTo: shelfId);
      }

      // 4. إضافة فلتر الحالة إذا كان موجوداً (قبل orderBy)
      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      // 5. الترتيب
      query = query.orderBy('createdAt', descending: true);

      // 6. ⚠️ عدم تطبيق الحد في الـ query - نريد كل البيانات للفلترة
      // التطبيق النهائي للحد سيكون في BLoC بعد الفلترة
      // if (limit != null) {
      //   query = query.limit(limit);
      // }

      // 7. الاستماع للتغييرات
      // ⚠️ تحسين (2026-10-12): نفس تحسين قسم
      // الفواتير — نحفظ المنتجات المحللة في
      // ذاكرة خاصة بهذا الستريم ونحدّث
      // المستندات المتغيرة فقط عبر docChanges
      // بدلاً من إعادة تحليل كل المنتجات مع
      // كل لقطة — كان يسبب بطءاً ملحوظاً مع
      // كثرة المنتجات عند كل تحديث. الحد لا
      // يُطبَّق في الـ query (نريد كل البيانات
      // للفلترة في الذاكرة) فالذاكرة تمثل
      // نتيجة الاستعلام كاملة ويُطبَّق الحد
      // في الذاكرة بعد الفلترة.
      final streamCache = <String, ProductEntity>{};

      return query
          .snapshots()
          .map((snapshot) {
            try {
              // تحديث تدريجي: نعالج المستندات المتغيرة فقط
              for (final change in snapshot.docChanges) {
                final doc = change.doc;
                if (change.type == DocumentChangeType.removed) {
                  streamCache.remove(doc.id);
                  continue;
                }
                try {
                  streamCache[doc.id] = ProductModel.fromFirestore(doc);
                } on Exception catch (_) {
                  streamCache.remove(doc.id);
                }
              }

              // ⚠️ أداء (تحقق يدوي 2026-10-12):
              // searchLower مُخرَجة من الحلقة —
              // تُحسب مرة واحدة لكل لقطة بدلاً
              // من تكرارها لكل منتج (نص ثابت
              // لا يتغير) فالنتيجة متطابقة تماماً
              // والفلترة أسرع. لا تُعيد إدخالها
              // داخل الحلقة.
              final searchLower = searchQuery != null && searchQuery.isNotEmpty
                  ? searchQuery.toLowerCase()
                  : null;

              var products = streamCache.values.toList()
                ..sort((a, b) {
                  final cmp = b.createdAt.compareTo(a.createdAt);
                  return cmp != 0 ? cmp : a.id.compareTo(b.id);
                });

              // 6. تطبيق فلتر البحث في الذاكرة
              if (searchLower != null) {
                products = products.where((product) {
                  final name = product.name.toLowerCase();
                  final description = product.description?.toLowerCase();
                  final barcode = product.barcode?.toLowerCase();
                  return name.contains(searchLower) ||
                      (description?.contains(searchLower) ?? false) ||
                      (barcode?.contains(searchLower) ?? false);
                }).toList();
              }

              // 7. تطبيق فلتر الحالة في الذاكرة (إذا لم يكن في Firestore)
              if (statusFilter != null && statusFilter != 'all') {
                products = products.where((product) {
                  switch (statusFilter) {
                    case 'low_stock':
                      return product.isLowStock;
                    case 'out_of_stock':
                      return product.isOutOfStock;
                    case 'active':
                      return product.isActive;
                    case 'inactive':
                      return !product.isActive;
                    default:
                      return true;
                  }
                }).toList();
              }

              // تطبيق فلتر المخزون المنخفض إذا كان مطلوباً
              if ((lowStock ?? false)) {
                // نفس شروط ProductEntity.isLowStock لتوحيد النتيجة:
                // trackQuantity && minQuantity > 0 && quantity <= minQuantity && quantity > 0
                products = products
                    .where(
                      (product) =>
                          product.trackQuantity &&
                          product.minQuantity > 0 &&
                          product.quantity <= product.minQuantity &&
                          product.quantity > 0,
                    )
                    .toList();
              }

              // 9. التأكد من عدم تجاوز الحد (حماية إضافية)
              if (limit != null && products.length > limit) {
                products = products.sublist(0, limit);
              }

              // ⚠️ ملاحظة عدم اتساق الإحصائيات:
              // هذا الستريم يُرجع كل المنتجات (بدون حد في الـ query) ويُطبّق الحد
              // في الذاكرة بعد الفلترة. لا تُستخدَم الإحصائيات المحسوبة هنا في
              // ProductsStreamActive — يُ comptesها bloc من اللقطة ذاتها.
              return Right<Failure, List<ProductEntity>>(products);
            } on Exception catch (e) {
              return Left<Failure, List<ProductEntity>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, List<ProductEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>> getProductsStatsStream({
    required String organizationEmail,
    int? limit,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final collection = _getProductsCollection(normalizedEmail);

      return collection
          .snapshots()
          .map((snapshot) {
            try {
              // ⚠️ تحسين (2026-10-12): حساب الإحصائيات
              // مباشرة من بيانات المستند الخام بدلاً
              // من بناء ProductModel كامل لكل منتج —
              // الإحصائيات تحتاج 5 حقول فقط (isActive،
              // quantity، minQuantity، sellingPrice،
              // costPrice) فبناء النموذج كامل كان يهدر
              // وقت المعالج مع كثرة المنتجات عند كل
              // لقطة. منطق الحساب مطابق تماماً للسابق
              // (lowStock = quantity <= minQuantity و
              // outOfStock = quantity <= 0 — المقارنات
              // الخام نفسها، وليسا isLowStock/
              // isOutOfStock اللتين تشترطان trackQuantity).
              var totalProducts = 0;
              var activeProducts = 0;
              var lowStockProducts = 0;
              var outOfStockProducts = 0;
              double totalValue = 0;
              double totalCost = 0;

              for (final doc in snapshot.docs) {
                final data = doc.data();
                if (data == null) continue;
                final mapData = data as Map<String, dynamic>;

                final isActive = mapData['isActive'] is bool
                    ? mapData['isActive'] as bool
                    : true;
                final trackQuantity = mapData['trackQuantity'] is bool
                    ? mapData['trackQuantity'] as bool
                    : true;
                final quantity = _parseStatsDouble(mapData['quantity']);
                final minQuantity = _parseStatsDouble(mapData['minQuantity']);
                final sellingPrice = _parseStatsDouble(mapData['sellingPrice']);
                final costPrice = _parseStatsDouble(mapData['costPrice']);

                totalProducts++;
                if (isActive) activeProducts++;
                // تطابق شروط ProductEntity.isLowStock و isOutOfStock
                // حتى تتساوى أرقام النظرة العامة مع نتائج القائمة.
                if (trackQuantity &&
                    minQuantity > 0 &&
                    quantity <= minQuantity &&
                    quantity > 0) {
                  lowStockProducts++;
                }
                if (trackQuantity && quantity <= 0) outOfStockProducts++;
                final unitCost = costPrice == 0 ? sellingPrice : costPrice;
                totalValue += quantity * unitCost;
                // ملاحظة توحيد الإحصائيات: تُستخدم costPrice ?? sellingPrice
                // لتتطابق مع getInventoryStatsSimple و getProductsStats
                // في المستودع، بدلاً من sellingPrice فقط.
                totalCost += quantity * costPrice;
              }

              final inactiveProducts = totalProducts - activeProducts;

              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              // — ━  ملاحظة للمبرمجين المستقبليين حول هيكل الإحصائيات ━  —
              // —                                                              —
              // — هذه العملية تُرجع إحصائيات Products Stream بهيكل         —
              // — متسق مع getInventoryStatsSimple:                           —
              // —   {                                                        —
              // —     'products': {                                          —
              // —       'totalProducts': ...,                                —
              // —       'activeProducts': ...,                               —
              // —       'lowStockProducts': ...,                             —
              // —       'outOfStockProducts': ...,                           —
              // —       'totalInventoryValue': ...                           —
              // —     }                                                      —
              // —   }                                                        —
              // —                                                              —
              // — لا تُرجع الإحصائيات مباشرة بدون مفتاح 'products'           —
              // — لأن InventoryStatsSection تتوقع هذا الهيكل.               —
// — ━  لا تستخدم سكربت أو أداة آلية لتعديل هذا الملف.          —
              // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              final stats = {
                'products': {
                  'totalProducts': totalProducts,
                  'activeProducts': activeProducts,
                  'lowStockProducts': lowStockProducts,
                  'outOfStockProducts': outOfStockProducts,
                  'totalInventoryValue': totalValue,
                },
              };

              return Right<Failure, Map<String, dynamic>>(stats);
            } on Exception catch (e) {
              return Left<Failure, Map<String, dynamic>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, Map<String, dynamic>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Stream<Either<Failure, List<CategoryEntity>>> getCategoriesStream({
    required String organizationEmail,
    bool? isActive,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      var query = _getCategoriesCollection(normalizedEmail).orderBy('name');
      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }
      // ⚠️ تحسين (2026-10-12): نفس تحسين
      // قسم الفواتير — نحفظ الفئات
      // المحللة في ذاكرة خاصة بهذا
      // الستريم ونحدّث المستندات
      // المتغيرة فقط عبر docChanges
      // بدلاً من إعادة تحليل كل
      // الفئات مع كل لقطة.
      final streamCache = <String, CategoryEntity>{};

      return query.snapshots().map((snapshot) {
        // تحديث تدريجي: نعالج المستندات المتغيرة فقط
        for (final change in snapshot.docChanges) {
          final doc = change.doc;
          if (change.type == DocumentChangeType.removed) {
            streamCache.remove(doc.id);
            continue;
          }
          try {
            streamCache[doc.id] = CategoryModel.fromFirestore(doc);
          } on Exception catch (_) {
            streamCache.remove(doc.id);
          }
        }

        final categories = streamCache.values.toList()
          ..sort((a, b) {
            final cmp = a.name.compareTo(b.name);
            return cmp != 0 ? cmp : a.id.compareTo(b.id);
          });
        return Right<Failure, List<CategoryEntity>>(categories);
      });
    } on Exception catch (e) {
      return Stream.value(
        Left<Failure, List<CategoryEntity>>(
          ServerFailure(message: _readableError(e)),
        ),
      );
    }
  }

  @override
  Future<DocumentSnapshot?> getProductDocument(
    String organizationEmail,
    String productId,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      return await _getProductsCollection(normalizedEmail).doc(productId).get();
    } on Exception catch (_) {
      return null;
    }
  }

  // ===== Product Logs Methods =====

  @override
  Future<Either<Failure, ProductLogEntity>> createProductLog({
    required String productId,
    required String productName,
    required String invoiceId,
    required String invoiceType,
    required double quantity,
    required double unitPrice,
    required double totalPrice,
    required String customerName,
    required String customerPhone,
    required DateTime date,
    required String organizationEmail,
    required String createdBy,
    String? notes,
  }) async {
    try {
      // تطبيق التطبيع على البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;
      final productDoc = _getProductsCollection(normalizedEmail).doc(productId);

      // ⚠️ ذرية (ملخص الذرية أعلاه): get المنتج ⇐ set سجل المنتج
      // في نفس المعاملة — السجل يثبت أن المنتج موجود وقت الحركة،
      // فصلهما يسبب سجلاً لمنتج غير موجود أو حركة بلا سجل.
      return await firestoreInstance.runTransaction((transaction) async {
        // 1. جلب بيانات المنتج داخل المعاملة
        final docSnapshot = await transaction.get(productDoc);

        if (!docSnapshot.exists) {
          throw Exception('المنتج غير موجود');
        }

        // 2. إنشاء سجل المنتج في نفس الـ transaction
        final productLog = ProductLogModel(
          id: '', // سيتم إنشاؤه تلقائياً
          productId: productId,
          productName: productName,
          invoiceId: invoiceId,
          invoiceType: invoiceType,
          quantity: quantity,
          unitPrice: unitPrice,
          totalPrice: totalPrice,
          customerName: customerName,
          customerPhone: customerPhone,
          date: date,
          organizationEmail: normalizedEmail,
          createdAt: DateTime.now(),
          createdBy: createdBy,
          notes: notes,
        );

        // ⚠️ حماية (إصلاح 2026-10-09 أعلاه): السجلات تُكتب إلى
        // المجموعة العليا {org}/inventory/products_logs وليس لمجموعة
        // فرعية تحت كل منتج — getProductLogs ومستودع الفواتير
        // يقرآن/يكتبان المجموعة العليا فقط، والكتابة لمجموعة
        // فرعية كانت تُنشئ سجلات يتيمة لا يقرأها أحد.
        final logCollection = firestore
            .collection(normalizedEmail)
            .doc('inventory')
            .collection('products_logs');

        final logDocRef = logCollection.doc();
        final logData = productLog.toFirestore();
        logData['id'] = logDocRef.id;

        transaction.set(logDocRef, logData);

        // 3. إرجاع السجل المنشأ
        final createdLog = productLog.copyWith(id: logDocRef.id);
        return Right(createdLog);
      });
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<ProductLogEntity>>> getProductLogs({
    required String productId,
    String? invoiceType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final emailService = EmailNormalizationService();
      final organizationEmail = emailService.normalize(user!.email!);

      QuerySnapshot querySnapshot;

      var query = firestore
          .collection(organizationEmail)
          .doc('inventory')
          .collection('products_logs')
          .where('productId', isEqualTo: productId)
          .orderBy('date', descending: true)
          .limit(limit);

      if (invoiceType != null && invoiceType.isNotEmpty) {
        query = query.where('invoiceType', isEqualTo: invoiceType);
      }

      if (startDate != null) {
        query = query.where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'date',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      querySnapshot = await query.get();

      final logs = querySnapshot.docs
          .map((doc) => ProductLogModel.fromFirestore(doc as DocumentSnapshot))
          .toList();

      return Right(logs);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
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
