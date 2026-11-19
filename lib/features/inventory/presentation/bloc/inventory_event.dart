part of 'inventory_bloc.dart';

/// أحداث BLoC المخزون
abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل بيانات المخزون الأساسية
class LoadInventoryData extends InventoryEvent {
  const LoadInventoryData({
    required this.organizationEmail,
    this.searchQuery,
    this.statusFilter,
  });
  final String organizationEmail;
  final String? searchQuery;
  final String? statusFilter;

  @override
  List<Object?> get props => [organizationEmail, searchQuery, statusFilter];
}

/// تحميل المنتجات
class LoadProducts extends InventoryEvent {
  const LoadProducts({
    required this.organizationEmail,
    this.categoryId,
    this.shelfId,
    this.isActive,
    this.lowStock,
    this.searchQuery,
    this.limit,
    this.lastDocumentId,
    this.append = false,
  });
  final String organizationEmail;
  final String? categoryId;
  final String? shelfId;
  final bool? isActive;
  final bool? lowStock;
  final String? searchQuery;
  final int? limit;
  final String? lastDocumentId;
  final bool append;

  @override
  List<Object?> get props => [
    organizationEmail,
    categoryId,
    shelfId,
    isActive,
    lowStock,
    searchQuery,
    limit,
    lastDocumentId,
    append,
  ];
}

/// حدث لتحميل المنتجات بشكل تدريجي (pagination)
class LoadProductsPaginatedEvent extends InventoryEvent {
  const LoadProductsPaginatedEvent({
    required this.organizationEmail,
    this.isRefresh = false,
    this.searchQuery,
    this.statusFilter,
  });
  final String organizationEmail;
  final bool isRefresh;
  final String? searchQuery;
  final String? statusFilter;

  @override
  List<Object?> get props => [
    organizationEmail,
    isRefresh,
    searchQuery,
    statusFilter,
  ];
}

/// حدث لتحميل المزيد من المنتجات
class LoadMoreProductsEvent extends InventoryEvent {
  const LoadMoreProductsEvent(this.organizationEmail, {this.searchQuery});
  final String organizationEmail;
  final String? searchQuery;

  @override
  List<Object?> get props => [organizationEmail, searchQuery];
}

/// إنشاء منتج جديد
class CreateNewProduct extends InventoryEvent {
  const CreateNewProduct({required this.product});
  final ProductEntity product;

  @override
  List<Object?> get props => [product];
}

/// حذف منتج
class DeleteProductEvent extends InventoryEvent {
  const DeleteProductEvent({
    required this.productId,
    required this.organizationEmail,
  });
  final String productId;
  final String organizationEmail;

  @override
  List<Object?> get props => [productId, organizationEmail];
}

/// تحديث منتج كامل (الاسم، الوصف، الباركود، الفئة، الكمية، السعر، إلخ)
class UpdateProduct extends InventoryEvent {
  const UpdateProduct({required this.product});
  final ProductEntity product;

  @override
  List<Object?> get props => [product];
}

/// تحديث كمية المنتج
class UpdateQuantity extends InventoryEvent {
  const UpdateQuantity({
    required this.productId,
    required this.organizationEmail,
    required this.newQuantity,
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

/// تحميل الفئات
class LoadCategories extends InventoryEvent {
  const LoadCategories({
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

/// تحميل المزيد من الفئات (pagination)
class LoadMoreCategoriesEvent extends InventoryEvent {
  const LoadMoreCategoriesEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// تحميل المزيد من الرفوف (pagination)
class LoadMoreShelvesEvent extends InventoryEvent {
  const LoadMoreShelvesEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// إنشاء فئة جديدة
class CreateCategory extends InventoryEvent {
  const CreateCategory({required this.category});
  final CategoryEntity category;

  @override
  List<Object?> get props => [category];
}

/// تحديث فئة
class UpdateCategoryEvent extends InventoryEvent {
  const UpdateCategoryEvent(this.category);
  final CategoryEntity category;

  @override
  List<Object?> get props => [category];
}

/// حذف فئة
class DeleteCategoryEvent extends InventoryEvent {
  const DeleteCategoryEvent({
    required this.categoryId,
    required this.organizationEmail,
  });
  final String categoryId;
  final String organizationEmail;

  @override
  List<Object?> get props => [categoryId, organizationEmail];
}

/// البحث في المنتجات
class SearchProducts extends InventoryEvent {
  const SearchProducts({required this.query});
  final String query;

  @override
  List<Object?> get props => [query];
}

/// فلترة المنتجات
class FilterProducts extends InventoryEvent {
  const FilterProducts({this.categoryId, this.shelfId, this.stockFilter});
  final String? categoryId;
  final String? shelfId;
  final StockFilter? stockFilter;

  @override
  List<Object?> get props => [categoryId, shelfId, stockFilter];
}

/// تحديث المخزون
class RefreshInventory extends InventoryEvent {
  const RefreshInventory({required this.organizationEmail});
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// تبديل نوع العرض
class ToggleInventoryViewMode extends InventoryEvent {
  const ToggleInventoryViewMode();
}

/// تحميل الرفوف
class LoadShelves extends InventoryEvent {
  const LoadShelves({
    required this.organizationEmail,
    this.zone,
    this.isActive,
  });
  final String organizationEmail;
  final String? zone;
  final bool? isActive;

  @override
  List<Object?> get props => [organizationEmail, zone, isActive];
}

/// إنشاء رف جديد
class CreateShelf extends InventoryEvent {
  const CreateShelf({required this.shelf});
  final ShelfEntity shelf;

  @override
  List<Object?> get props => [shelf];
}

/// تحديث رف
class UpdateShelfEvent extends InventoryEvent {
  const UpdateShelfEvent(this.shelf);
  final ShelfEntity shelf;

  @override
  List<Object?> get props => [shelf];
}

/// حذف رف
class DeleteShelfEvent extends InventoryEvent {
  const DeleteShelfEvent({
    required this.shelfId,
    required this.organizationEmail,
  });
  final String shelfId;
  final String organizationEmail;

  @override
  List<Object?> get props => [shelfId, organizationEmail];
}

/// إعادة حساب عدادات عناصر الأرفف من المنتجات الفعلية
class RecalculateShelfCountersEvent extends InventoryEvent {
  const RecalculateShelfCountersEvent({required this.organizationEmail});
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// تحميل سجلات المخزون
class LoadInventoryLogsEvent extends InventoryEvent {
  const LoadInventoryLogsEvent({
    required this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [
    userId,
    searchQuery,
    actionFilter,
    dateFilter,
    startDate,
    endDate,
    limit,
  ];
}

// Stream Events
class StartProductsStreamEvent extends InventoryEvent {
  const StartProductsStreamEvent({
    required this.organizationEmail,
    this.categoryId,
    this.shelfId,
    this.isActive,
    this.lowStock,
    this.limit,
    this.searchQuery,
  });

  final String organizationEmail;
  final String? categoryId;
  final String? shelfId;
  final bool? isActive;
  final bool? lowStock;
  final int? limit;
  final String? searchQuery;

  @override
  List<Object?> get props => [
    organizationEmail,
    categoryId,
    shelfId,
    isActive,
    lowStock,
    limit,
    searchQuery,
  ];
}

class StopProductsStreamEvent extends InventoryEvent {
  const StopProductsStreamEvent();
}

/// تحديث كمية المنتج بعد إرجاع مادة
class UpdateProductQuantityAfterReturn extends InventoryEvent {
  const UpdateProductQuantityAfterReturn({
    required this.productId,
    required this.quantity,
  });
  final String productId;
  final double quantity;

  @override
  List<Object?> get props => [productId, quantity];
}

class StartProductsStatsStreamEvent extends InventoryEvent {
  const StartProductsStatsStreamEvent(this.organizationEmail, {this.limit});
  final String organizationEmail;
  final int? limit;

  @override
  List<Object?> get props => [organizationEmail, limit];
}

class StopProductsStatsStreamEvent extends InventoryEvent {
  const StopProductsStatsStreamEvent();
}

/// بدء ستريم الأرفف للتحديث الفوري
///
/// ⚠️ ملاحظة للمبرمجين المستقبليين:
/// عدادات currentItems في الأرفف تُحدَّث ذرياً مع كل
/// عملية منتج (إنشاء/تحديث/حذف/نقل كمية) داخل نفس
/// runTransaction في ProductRepositoryImpl — بدون هذا
/// الستريم تُعرض الأرفف بعدادات قديمة (سعة/امتلاء)
/// حتى إعادة التحميل اليدوي. لا تحذف هذا الستريم.
class StartShelvesStreamEvent extends InventoryEvent {
  const StartShelvesStreamEvent({
    required this.organizationEmail,
    this.zone,
    this.isActive,
  });

  final String organizationEmail;
  final String? zone;
  final bool? isActive;

  @override
  List<Object?> get props => [organizationEmail, zone, isActive];
}

class StopShelvesStreamEvent extends InventoryEvent {
  const StopShelvesStreamEvent();
}

/// حدث تحميل سجلات حركة المنتج
class LoadProductLogsEvent extends InventoryEvent {
  const LoadProductLogsEvent({
    required this.productId,
    this.invoiceType,
    this.startDate,
    this.endDate,
    this.limit = 100,
  });

  final String productId;
  final String? invoiceType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;

  @override
  List<Object?> get props => [
    productId,
    invoiceType,
    startDate,
    endDate,
    limit,
  ];
}

// Internal Stream Events
class _ProductsStreamDataReceived extends InventoryEvent {
  const _ProductsStreamDataReceived(this.result);
  final Either<Failure, List<ProductEntity>> result;

  @override
  List<Object?> get props => [result];
}

class _ProductsStreamErrorReceived extends InventoryEvent {
  const _ProductsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

class _ProductsStatsStreamDataReceived extends InventoryEvent {
  const _ProductsStatsStreamDataReceived(this.result);
  final Either<Failure, Map<String, dynamic>> result;

  @override
  List<Object?> get props => [result];
}

class _ShelvesStreamDataReceived extends InventoryEvent {
  const _ShelvesStreamDataReceived(this.result);
  final Either<Failure, List<ShelfEntity>> result;

  @override
  List<Object?> get props => [result];
}
