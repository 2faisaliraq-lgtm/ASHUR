import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/category_entity.dart';
import '../entities/categories_page.dart';
import '../entities/inventory_log_entity.dart';
import '../entities/inventory_movement_entity.dart';
import '../entities/product_entity.dart';
import '../entities/product_log_entity.dart';
import '../entities/products_page.dart';

/// واجهة مستودع المنتجات
abstract class ProductRepository {
  /// الحصول على جميع المنتجات
  Future<Either<Failure, List<ProductEntity>>> getProducts({
    required String organizationEmail,
    String? categoryId,
    String? shelfId,
    bool? isActive,
    bool? lowStock,
    String? searchQuery,
    int? limit,
    String? lastDocumentId,
  });

  /// الحصول على المنتجات مع pagination
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين: تُرجع
  /// ProductsPage التي تحمل آخر مستند في الصفحة كمؤشر
  /// startAfterDocument للصفحة التالية، بالإضافة إلى hasMore
  /// لتحديد وجود دفعة لاحقة بدون تخمين من طول الصفحة.
  Future<Either<Failure, ProductsPage>> getProductsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
    String? searchQuery,
  });

  // الطرق الجديدة للـ streams
  Stream<Either<Failure, List<ProductEntity>>> getProductsStream({
    required String organizationEmail,
    String? categoryId,
    String? shelfId,
    bool? isActive,
    bool? lowStock,
    int? limit,
    String? searchQuery,
  });

  Stream<Either<Failure, Map<String, dynamic>>> getProductsStatsStream({
    required String organizationEmail,
    int? limit,
  });

  /// ستريم الفئات للتحديث الفوري (رقائق فلترة الداشبورد)
  /// ⚠️ ملاحظة للمبرمجين المستقبليين:
  /// بدونها تُقرأ الفئات مرة واحدة فقط (Future)
  /// وتبقى رقائق الفلترة فارغة لأن حالة
  /// ProductsStreamActive لا تحمل الفئات.
  Stream<Either<Failure, List<CategoryEntity>>> getCategoriesStream({
    required String organizationEmail,
    bool? isActive,
  });

  /// الحصول على منتج بالمعرف
  Future<Either<Failure, ProductEntity>> getProductById({
    required String id,
    required String organizationEmail,
  });

  /// الحصول على منتج بالباركود
  Future<Either<Failure, ProductEntity?>> getProductByBarcode({
    required String barcode,
    required String organizationEmail,
  });

  /// إضافة منتج جديد
  Future<Either<Failure, ProductEntity>> createProduct({
    required ProductEntity product,
  });

  /// تحديث منتج
  Future<Either<Failure, ProductEntity>> updateProduct({
    required ProductEntity product,
  });

  /// حذف منتج
  Future<Either<Failure, void>> deleteProduct({
    required String id,
    required String organizationEmail,
  });

  /// تحديث كمية المنتج
  ///
  /// ⚠️ ملاحظة للمبرمجين المستقبليين:
  /// عند توفير [quantityDelta] (قيمة نسبية مثل +2 أو -3)، تُحسب
  /// الكمية النهائية ذرياً داخل المعاملة من اللقطة الحية
  /// (الكمية الحالية + quantityDelta) بدلاً من [newQuantity].
  /// استخدم quantityDelta عندما تكون الكمية الجديدة محسوبة
  /// من قيمة قديمة (مثل عمليات الإرجاع) لتجنب تلف المخزون.
  /// عند عدم توفير quantityDelta، تُستخدم [newQuantity] كما هي.
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
  });

  /// تحديث أسعار المنتج (سعر الشراء وسعر البيع)
  Future<Either<Failure, ProductEntity>> updateProductPrices({
    required String id,
    required String organizationEmail,
    required double? costPrice,
    required double sellingPrice,
    required String updatedBy,
  });

  /// البحث في المنتجات
  Future<Either<Failure, List<ProductEntity>>> searchProducts({
    required String organizationEmail,
    required String query,
    String? categoryId,
    int? limit,
  });

  /// الحصول على المنتجات منخفضة المخزون
  Future<Either<Failure, List<ProductEntity>>> getLowStockProducts({
    required String organizationEmail,
    int? limit,
  });

  /// الحصول على المنتجات النافدة
  Future<Either<Failure, List<ProductEntity>>> getOutOfStockProducts({
    required String organizationEmail,
    int? limit,
  });

  /// الحصول على إحصائيات المنتجات
  Future<Either<Failure, Map<String, dynamic>>> getProductsStats({
    required String organizationEmail,
  });

  /// البحث عن أسماء المنتجات المشابهة
  Future<Either<Failure, List<String>>> searchProductNames({
    required String query,
  });

  /// إنشاء فئة جديدة
  Future<Either<Failure, CategoryEntity>> createCategory(
    CategoryEntity category,
  );

  /// تحديث فئة
  Future<Either<Failure, CategoryEntity>> updateCategory({
    required CategoryEntity category,
  });

  /// حذف فئة
  Future<Either<Failure, void>> deleteCategory({
    required String id,
    required String organizationEmail,
  });

  /// الحصول على مستند المنتج لغرض الـ pagination
  Future<DocumentSnapshot?> getProductDocument(
    String organizationEmail,
    String productId,
  );

  /// الحصول على جميع الفئات
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    required String organizationEmail,
    bool? isActive,
  });

  /// الحصول على الفئات بشكل تدريجي (pagination)
  Future<Either<Failure, CategoriesPage>> getCategoriesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  });

  // ===== Inventory Logs Methods =====

  /// الحصول على سجل نشاطات المخزون
  Future<Either<Failure, List<InventoryLogEntity>>> getInventoryLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// إضافة سجل نشاط جديد للمخزون
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
  });

  /// حذف سجل نشاط محدد
  Future<Either<Failure, void>> deleteInventoryLog(String logId);

  /// مسح سجلات النشاطات
  Future<Either<Failure, void>> clearInventoryLogs({
    String? userId,
    DateTime? beforeDate,
  });

  // ===== Product Logs Methods =====

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
  });

  Future<Either<Failure, List<ProductLogEntity>>> getProductLogs({
    required String productId,
    String? invoiceType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  });
}
