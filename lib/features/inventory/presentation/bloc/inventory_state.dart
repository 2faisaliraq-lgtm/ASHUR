part of 'inventory_bloc.dart';

/// حالات BLoC المخزون
abstract class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class InventoryInitial extends InventoryState {}

/// حالة التحميل
class InventoryLoading extends InventoryState {}

/// حالة تحميل البيانات بنجاح
class InventoryLoaded extends InventoryState {
  const InventoryLoaded({
    required this.products,
    required this.categories,
    required this.filteredProducts,
    this.shelves,
    this.stats,
    this.searchQuery = '',
    this.selectedCategoryId,
    this.selectedShelfId,
    this.stockFilter,
    this.isLoadingProducts = false,
    this.isCreatingProduct = false,
    this.error,
    this.isGridView = false,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.lastDocument,
    this.hasMoreCategoriesData = true,
    this.isLoadingMoreCategories = false,
    this.lastDocumentCategories,
    this.hasMoreShelvesData = true,
    this.isLoadingMoreShelves = false,
    this.lastDocumentShelves,
  });
  final List<ProductEntity> products;
  final List<CategoryEntity> categories;
  final List<ShelfEntity>? shelves;
  final Map<String, dynamic>? stats;
  final List<ProductEntity> filteredProducts;
  final String searchQuery;
  final String? selectedCategoryId;
  final String? selectedShelfId;
  final StockFilter? stockFilter;
  final bool isLoadingProducts;
  final bool isCreatingProduct;
  final String? error;
  final bool isGridView;
  final bool hasMore;
  final bool isLoadingMore;
  final dynamic lastDocument;
  final bool? hasMoreCategoriesData;
  final bool? isLoadingMoreCategories;
  final dynamic lastDocumentCategories;
  final bool? hasMoreShelvesData;
  final bool? isLoadingMoreShelves;
  final dynamic lastDocumentShelves;

  InventoryLoaded copyWith({
    List<ProductEntity>? products,
    List<CategoryEntity>? categories,
    List<ShelfEntity>? shelves,
    Map<String, dynamic>? stats,
    List<ProductEntity>? filteredProducts,
    String? searchQuery,
    String? selectedCategoryId,
    String? selectedShelfId,
    StockFilter? stockFilter,
    bool? isLoadingProducts,
    bool? isCreatingProduct,
    String? error,
    bool? isGridView,
    bool? hasMore,
    bool? isLoadingMore,
    dynamic lastDocument,
    bool? hasMoreCategoriesData,
    bool? isLoadingMoreCategories,
    dynamic lastDocumentCategories,
    bool? hasMoreShelvesData,
    bool? isLoadingMoreShelves,
    dynamic lastDocumentShelves,
  }) {
    return InventoryLoaded(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      shelves: shelves ?? this.shelves,
      stats: stats ?? this.stats,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedShelfId: selectedShelfId ?? this.selectedShelfId,
      stockFilter: stockFilter ?? this.stockFilter,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      isCreatingProduct: isCreatingProduct ?? this.isCreatingProduct,
      error: error ?? this.error,
      isGridView: isGridView ?? this.isGridView,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMoreCategoriesData:
          hasMoreCategoriesData ?? this.hasMoreCategoriesData,
      isLoadingMoreCategories:
          isLoadingMoreCategories ?? this.isLoadingMoreCategories,
      lastDocumentCategories:
          lastDocumentCategories ?? this.lastDocumentCategories,
      hasMoreShelvesData: hasMoreShelvesData ?? this.hasMoreShelvesData,
      isLoadingMoreShelves: isLoadingMoreShelves ?? this.isLoadingMoreShelves,
      lastDocumentShelves: lastDocumentShelves ?? this.lastDocumentShelves,
    );
  }

  @override
  List<Object?> get props => [
    products,
    categories,
    shelves,
    stats,
    filteredProducts,
    searchQuery,
    selectedCategoryId,
    selectedShelfId,
    stockFilter,
    isLoadingProducts,
    isCreatingProduct,
    error,
    isGridView,
    hasMore,
    isLoadingMore,
    lastDocument,
    hasMoreCategoriesData,
    isLoadingMoreCategories,
    lastDocumentCategories,
    hasMoreShelvesData,
    isLoadingMoreShelves,
    lastDocumentShelves,
  ];
}

/// حالة الخطأ
class InventoryError extends InventoryState {
  const InventoryError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// حالة تحميل سجلات المخزون
class InventoryLogsLoaded extends InventoryState {
  const InventoryLogsLoaded(this.logs);

  final List<InventoryLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}

/// حالة نجاح عملية على المخزون
class InventoryOperationSuccess extends InventoryState {
  const InventoryOperationSuccess(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

// Stream State
class ProductsStreamActive extends InventoryState {
  const ProductsStreamActive({
    required this.products,
    required this.filteredProducts,
    required this.searchQuery,
    required this.selectedCategoryId,
    required this.selectedShelfId,
    required this.stockFilter,
    required this.isGridView,
    this.categories = const [],
    this.shelves,
    this.stats,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.lastDocument,
    this.hasMoreCategoriesData = true,
    this.isLoadingMoreCategories = false,
    this.lastDocumentCategories,
    this.hasMoreShelvesData = true,
    this.isLoadingMoreShelves = false,
    this.lastDocumentShelves,
  });

  final List<ProductEntity> products;
  final List<ProductEntity> filteredProducts;
  final List<CategoryEntity> categories;
  final List<ShelfEntity>? shelves;
  final String searchQuery;
  final String? selectedCategoryId;
  final String? selectedShelfId;
  final StockFilter? stockFilter;
  final bool isGridView;
  final Map<String, dynamic>? stats;
  final bool hasMore;
  final bool isLoadingMore;
  final dynamic lastDocument;
  final bool? hasMoreCategoriesData;
  final bool? isLoadingMoreCategories;
  final dynamic lastDocumentCategories;
  final bool? hasMoreShelvesData;
  final bool? isLoadingMoreShelves;
  final dynamic lastDocumentShelves;

  ProductsStreamActive copyWith({
    List<ProductEntity>? products,
    List<ProductEntity>? filteredProducts,
    List<CategoryEntity>? categories,
    List<ShelfEntity>? shelves,
    String? searchQuery,
    String? selectedCategoryId,
    String? selectedShelfId,
    StockFilter? stockFilter,
    bool? isGridView,
    Map<String, dynamic>? stats,
    bool? hasMore,
    bool? isLoadingMore,
    dynamic lastDocument,
    bool? hasMoreCategoriesData,
    bool? isLoadingMoreCategories,
    dynamic lastDocumentCategories,
  }) {
    return ProductsStreamActive(
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      shelves: shelves ?? this.shelves,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedShelfId: selectedShelfId ?? this.selectedShelfId,
      stockFilter: stockFilter ?? this.stockFilter,
      isGridView: isGridView ?? this.isGridView,
      stats: stats ?? this.stats,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMoreCategoriesData:
          hasMoreCategoriesData ?? this.hasMoreCategoriesData,
      isLoadingMoreCategories:
          isLoadingMoreCategories ?? this.isLoadingMoreCategories,
      lastDocumentCategories:
          lastDocumentCategories ?? this.lastDocumentCategories,
    );
  }

  @override
  List<Object?> get props => [
    products,
    filteredProducts,
    categories,
    shelves,
    searchQuery,
    selectedCategoryId,
    selectedShelfId,
    stockFilter,
    isGridView,
    stats,
    hasMore,
    isLoadingMore,
    lastDocument,
    hasMoreCategoriesData,
    isLoadingMoreCategories,
    lastDocumentCategories,
  ];
}

/// حالة تحميل سجلات حركة المنتج
class ProductLogsLoaded extends InventoryState {
  const ProductLogsLoaded({required this.logs});
  final List<ProductLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}
