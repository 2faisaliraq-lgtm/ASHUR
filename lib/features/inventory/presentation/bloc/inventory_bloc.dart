import 'dart:async';

import 'package:ashur/core/services/push_notification_service.dart';
import 'package:ashur/core/services/section_notification_service.dart';
import 'package:ashur/core/services/settings_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/inventory_log_entity.dart';
import '../../domain/entities/inventory_movement_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_log_entity.dart';
import '../../domain/entities/shelf_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/shelf_repository.dart';
import '../../domain/usecases/create_category.dart' as create_category_usecase;
import '../../domain/usecases/create_product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/get_categories_simple.dart';
import '../../domain/usecases/get_inventory_stats_simple.dart';
import '../../domain/usecases/get_products.dart';
import '../../domain/usecases/get_products_paginated.dart';
import '../../domain/usecases/get_products_stats_stream.dart';
import '../../domain/usecases/get_products_stream.dart';
import '../../domain/usecases/get_shelves_simple.dart';
import '../../domain/usecases/get_shelves_stream.dart';
import '../../domain/usecases/update_product_prices.dart'
    as update_product_prices_usecase;
import '../../domain/usecases/update_product_quantity.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

/// BLoC إدارة المخزون
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc({
    required this.getProducts,
    required this.getProductsPaginated,
    required this.getProductsStream,
    required this.getProductsStatsStream,
    required this.createProduct,
    required this.deleteProduct,
    required this.updateProductQuantity,
    required this.updateProductPrices,
    required this.getCategories,
    required this.getShelves,
    required this.getShelvesStream,
    required this.getInventoryStats,
    required this.createCategory,
    required this.repository,
    required this.shelfRepository,
  }) : super(InventoryInitial()) {
    on<LoadInventoryData>(_onLoadInventoryData);
    on<LoadProducts>(_onLoadProducts);
    on<LoadProductsPaginatedEvent>(_onLoadProductsPaginated);
    on<LoadMoreProductsEvent>(_onLoadMoreProducts);
    on<StartProductsStreamEvent>(_onStartProductsStream);
    on<StopProductsStreamEvent>(_onStopProductsStream);
    // ⚠️ ملاحظة للمبرمجين المستقبليين (تسريب اشتراكات الستريم):
    // InventoryBloc يُسجّل عبر registerFactory في DI، وكل صفحة تُنشئ نسخة
    // جديدة. الصفحات تُستدعي bloc.close() في dispose مما يلغي كل الاشتراكات
    // (_productsStreamSubscription, _statsStreamSubscription،
    // _shelvesStreamSubscription). تأكد من استدعاء bloc.close() في كل صفحة
    // تستخدم هذا البلوك لمنع Zombie Streams.
    on<StartProductsStatsStreamEvent>(_onStartProductsStatsStream);
    on<StopProductsStatsStreamEvent>(_onStopProductsStatsStream);
    on<StartShelvesStreamEvent>(_onStartShelvesStream);
    on<StopShelvesStreamEvent>(_onStopShelvesStream);
    on<CreateNewProduct>(_onCreateNewProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProductEvent>(_onDeleteProduct);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<LoadCategories>(_onLoadCategories);
    on<LoadMoreCategoriesEvent>(_onLoadMoreCategories);
    on<LoadMoreShelvesEvent>(_onLoadMoreShelves);
    on<LoadShelves>(_onLoadShelves);
    on<CreateCategory>(_onCreateCategory);
    on<UpdateCategoryEvent>(_onUpdateCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
    on<SearchProducts>(_onSearchProducts);
    on<FilterProducts>(_onFilterProducts);
    on<RefreshInventory>(_onRefreshInventory);
    on<ToggleInventoryViewMode>(_onToggleInventoryViewMode);
    on<LoadInventoryLogsEvent>(_onLoadInventoryLogs);
    on<LoadProductLogsEvent>(_onLoadProductLogs);
    on<UpdateProductQuantityAfterReturn>(_onUpdateProductQuantityAfterReturn);
    on<CreateShelf>(_onCreateShelf);
    on<UpdateShelfEvent>(_onUpdateShelf);
    on<DeleteShelfEvent>(_onDeleteShelf);
    on<RecalculateShelfCountersEvent>(_onRecalculateShelfCounters);
    // Stream handlers
    on<_ProductsStreamDataReceived>(_onProductsStreamDataReceived);
    on<_ProductsStreamErrorReceived>(_onProductsStreamErrorReceived);
    on<_ProductsStatsStreamDataReceived>(_onProductsStatsStreamDataReceived);
    on<_ShelvesStreamDataReceived>(_onShelvesStreamDataReceived);
  }

  final GetProducts getProducts;
  final GetProductsPaginated getProductsPaginated;
  final GetProductsStream getProductsStream;
  final GetProductsStatsStream getProductsStatsStream;
  final CreateProduct createProduct;
  final DeleteProduct deleteProduct;
  final UpdateProductQuantity updateProductQuantity;
  final update_product_prices_usecase.UpdateProductPrices updateProductPrices;
  final GetCategoriesSimple getCategories;
  final GetShelvesSimple getShelves;
  final GetShelvesStream getShelvesStream;
  final GetInventoryStatsSimple getInventoryStats;
  final create_category_usecase.CreateCategory createCategory;
  final ProductRepository repository;
  final ShelfRepository shelfRepository;

  // متغيرات للتحكم في الـ streams
  StreamSubscription<dynamic>? _productsStreamSubscription;
  StreamSubscription<dynamic>? _statsStreamSubscription;
  StreamSubscription<dynamic>? _shelvesStreamSubscription;
  List<ProductEntity> _allProducts = []; // ✅ حفظ كل المنتجات للفلترة
  // ⚠️ إصلاح 2026-10-12: أُزيل final لأن
  // _onSearchProducts يُسنِده الآن — كان final
  // لا يُسنَد أبداً فكان البحث لا يُطبَّق على
  // المنتجات أبداً (تُقرأه _applyFilters).
  String _searchQuery = '';
  String? _selectedCategoryId;
  String? _selectedShelfId;
  StockFilter? _stockFilter;

  // متغيرات للتحكم في تحميل الفئات التدريجي
  DocumentSnapshot<Object?>? _lastDocumentCategories;
  bool _isLoadingMoreCategories = false;
  bool _hasMoreCategoriesData = true;
  DocumentSnapshot<Object?>? _lastDocumentShelves;
  bool _isLoadingMoreShelves = false;
  bool _hasMoreShelvesData = true;

  // ⚠️ ملاحظة للمبرمجين المستقبليين: حالة عرض الشبكة/القائمة تُدار عبر
  // state.isGridView في InventoryLoaded وProductsStreamActive، وليس عبر
  // حقل منفصل في BLoC. لا تضف حقلاً مكرراً لـ _isGridView هنا.
  //
  // ⚠️ ملاحظة known issue (تصحيح 2026-10-24 — التعليق السابق غير دقيق):
  // التعليق أدناه skreيف قبل إضافة التسجيل الآلي. في الواقع، المعالجات
  // _onCreateNewProduct (السطر 460)، _onUpdateProduct (السطر 532)،
  // _onDeleteProduct (السطر 634) و _onUpdateQuantity (السطر 716) تُسجّل
  // جميعاً عبر repository.addInventoryLog بعد النجاح. السجل ليس فارغاً.
  // ما يظل غير مسجل تلقائياً: إنشاء/تحديث/حذف الفئات (lines 1009, 1060-1061)
  // وإنشاء/تحديث/حذف الأرفف (lines 1246-1248, 1316-1318) — يُنصح بإضافة
  // addInventoryLog لهذه العمليات لتحقيق تدقيق كامل.

  // ⚠️ ملاحظة known issue (التسجيل الآلي للنشاط غير مفعّل):
  // المعالجات _onCreateNewProduct / _onUpdateProduct / _onDeleteProduct /
  // _onUpdateQuantity لا تُسجّل entrada في InventoryLogEntity عبر
  // repository.addInventoryLog / createProductLog. السجل يظل فارغاً
  // ما لم يُستدعى يدوياً من صفحة السجلات.لإضافة تدقيق تلقائي لكل
  // عملية مخزون، استدعي addInventoryLog داخل كل معالج بعد النجاح.

  Future<void> _onLoadInventoryData(
    LoadInventoryData event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    _lastDocument = null;
    _isLoadingMoreProducts = false;

    try {
      // تحميل مجموعة واحدة كاملة، ثم اشتقاق الأرقام والمرشحات من الكيانات
      // نفسها؛ هذا يمنع اختلاف العد بين الإحصاءات والقائمة بسبب حد الصفحة.
      final productsResult = await getProducts(
        GetProductsParams(
          organizationEmail: event.organizationEmail,
          searchQuery: event.searchQuery,
        ),
      );

      // تحميل الفئات
      final categoriesResult = await getCategories(
        GetCategoriesSimpleParams(organizationEmail: event.organizationEmail),
      );

      // تحميل الرفوف
      final shelvesResult = await getShelves(
        GetShelvesSimpleParams(organizationEmail: event.organizationEmail),
      );

      productsResult.fold((failure) => emit(InventoryError(failure.message)), (
        products,
      ) {
        final stats = <String, dynamic>{
          'products': {
            'totalProducts': products.length,
            'activeProducts': products
                .where((product) => product.isActive)
                .length,
            'lowStockProducts': products
                .where((product) => product.isLowStock)
                .length,
            'outOfStockProducts': products
                .where((product) => product.isOutOfStock)
                .length,
            'totalInventoryValue': products.fold<double>(
              0,
              (total, product) => total + product.inventoryValue,
            ),
          },
        };
        final requestedStatusFilter = event.statusFilter;
        if (requestedStatusFilter != null && requestedStatusFilter != 'all') {
          _selectedCategoryId = null;
          _selectedShelfId = null;
          _stockFilter = null;
        }
        _searchQuery = event.searchQuery ?? '';
        _allProducts = products;
        categoriesResult.fold(
          (failure) => emit(InventoryError(failure.message)),
          (categories) {
            shelvesResult.fold(
              (failure) => emit(InventoryError(failure.message)),
              (shelves) {
                emit(
                  InventoryLoaded(
                    products: products,
                    categories: categories,
                    shelves: shelves,
                    stats: stats,
                    filteredProducts: _applyProductStatusFilter(
                      _applyFilters(products),
                      event.statusFilter,
                    ),
                    searchQuery: event.searchQuery ?? '',
                    hasMore: false,
                    lastDocument: null,
                  ),
                );
              },
            );
          },
        );
      });
    } on Exception catch (e) {
      // معالجة خاصة لأخطاء الفهارس
      var errorMessage = 'حدث خطأ غير متوقع: ${_readableError(e)}';

      if (e.toString().contains('index') ||
          e.toString().contains('FAILED_PRECONDITION')) {
        errorMessage = 'الفهارس قيد الإنشاء، يرجى المحاولة بعد دقائق قليلة';
      }

      emit(InventoryError(errorMessage));
    }
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<InventoryState> emit,
  ) async {
    if (state is InventoryLoaded) {
      final currentState = state as InventoryLoaded;
      emit(currentState.copyWith(isLoadingProducts: true));

      final result = await getProducts(
        GetProductsParams(
          organizationEmail: event.organizationEmail,
          categoryId: event.categoryId,
          shelfId: event.shelfId,
          isActive: event.isActive,
          lowStock: event.lowStock,
          searchQuery: event.searchQuery,
          limit: event.limit,
          lastDocumentId: event.lastDocumentId,
        ),
      );

      result.fold(
        (failure) => emit(
          currentState.copyWith(
            isLoadingProducts: false,
            error: failure.message,
          ),
        ),
        (products) => emit(
          currentState.copyWith(
            products: event.append
                ? [...currentState.products, ...products]
                : products,
            filteredProducts: event.append
                ? [...currentState.filteredProducts, ...products]
                : products,
            isLoadingProducts: false,
          ),
        ),
      );
    }
  }

  // متغيرات للتحكم في pagination
  dynamic _lastDocument;
  bool _isLoadingMoreProducts = false;
  bool _hasMoreProducts = true;
  static const int _pageSize = 20;

  Future<void> _onLoadProductsPaginated(
    LoadProductsPaginatedEvent event,
    Emitter<InventoryState> emit,
  ) async {
    final previousState = state;
    final requestedStatusFilter = event.statusFilter;
    if (requestedStatusFilter != null && requestedStatusFilter != 'all') {
      _selectedCategoryId = null;
      _selectedShelfId = null;
      _stockFilter = null;
    }
    _searchQuery = event.searchQuery ?? '';
    if (event.isRefresh) {
      _lastDocument = null;
      _isLoadingMoreProducts = false;
      _hasMoreProducts = true;
      emit(InventoryLoading());
    }

    final result = await getProductsPaginated(
      organizationEmail: event.organizationEmail,
      limit: _pageSize,
      searchQuery: event.searchQuery,
    );

    await result.fold(
      (failure) async => emit(InventoryError(failure.message)),
      (page) async {
        // ✅ تحسين (2026-10-12): مؤشر الصفحة يأتي من
        // نتيجة الاستعلام مباشرة (آخر مستند في الصفحة)
        // بدلاً من جلب المستند مجدداً عبر getProductDocument
        // — كان يضيف جولة شبكة زائدة بعد كل تحميل صفحة.
        _lastDocument = page.products.isNotEmpty ? page.lastDocument : null;
        _allProducts = page.products;

        final filteredProducts = _applyProductStatusFilter(
          _applyFilters(_allProducts),
          requestedStatusFilter,
        );
        final currentState = state;
        final sourceState =
            currentState is InventoryLoaded ||
                currentState is ProductsStreamActive
            ? currentState
            : previousState;
        final categories = sourceState is InventoryLoaded
            ? sourceState.categories
            : (sourceState is ProductsStreamActive
                  ? sourceState.categories
                  : const <CategoryEntity>[]);
        final shelves = sourceState is InventoryLoaded
            ? sourceState.shelves
            : (sourceState is ProductsStreamActive
                  ? sourceState.shelves
                  : null);
        final stats = sourceState is InventoryLoaded
            ? sourceState.stats
            : (sourceState is ProductsStreamActive ? sourceState.stats : null);

        emit(
          InventoryLoaded(
            products: page.products,
            filteredProducts: filteredProducts,
            categories: categories,
            shelves: shelves,
            stats: stats,
            searchQuery: event.searchQuery ?? '',
            selectedCategoryId: _selectedCategoryId,
            selectedShelfId: _selectedShelfId,
            stockFilter: _stockFilter,
            hasMore: page.hasMore ?? page.products.length >= _pageSize,
            lastDocument: _lastDocument,
          ),
        );
      },
    );
  }

  List<ProductEntity> _applyProductStatusFilter(
    List<ProductEntity> products,
    String? statusFilter,
  ) {
    if (statusFilter == null || statusFilter == 'all') return products;
    switch (statusFilter) {
      case 'active':
        return products.where((product) => product.isActive).toList();
      case 'inactive':
        return products.where((product) => !product.isActive).toList();
      case 'low_stock':
        return products.where((product) => product.isLowStock).toList();
      case 'out_of_stock':
        return products.where((product) => product.isOutOfStock).toList();
      default:
        return products;
    }
  }

  Future<void> _onLoadMoreProducts(
    LoadMoreProductsEvent event,
    Emitter<InventoryState> emit,
  ) async {
    if (_isLoadingMoreProducts) return;

    final currentState = state;
    final List<ProductEntity> currentProducts;
    final bool hasMore;
    final dynamic lastDocument;

    if (currentState is InventoryLoaded) {
      currentProducts = currentState.products;
      hasMore = currentState.hasMore;
      lastDocument = currentState.lastDocument;
    } else if (currentState is ProductsStreamActive) {
      currentProducts = currentState.products;
      hasMore = currentState.hasMore;
      lastDocument = currentState.lastDocument;
    } else {
      return;
    }

    if (!hasMore || lastDocument == null || !_hasMoreProducts) return;
    _isLoadingMoreProducts = true;

    if (currentState is InventoryLoaded) {
      emit(currentState.copyWith(isLoadingMore: true));
    } else if (currentState is ProductsStreamActive) {
      emit(currentState.copyWith(isLoadingMore: true));
    }

    try {
      final result = await getProductsPaginated(
        organizationEmail: event.organizationEmail,
        limit: _pageSize,
        lastDocument: lastDocument,
      );

      await result.fold(
        (failure) async {
          final latestState = state;
          if (latestState is InventoryLoaded) {
            emit(latestState.copyWith(isLoadingMore: false));
          } else if (latestState is ProductsStreamActive) {
            emit(latestState.copyWith(isLoadingMore: false));
          }
          emit(InventoryError(failure.message));
        },
        (page) async {
          final newProducts = page.products;

          // ✅ تحسين (2026-10-12): مؤشر الصفحة من نتيجة
          // الاستعلام مباشرة بدلاً من جلب المستند مجدداً
          // عبر getProductDocument (جولة شبكة زائدة).
          if (newProducts.isNotEmpty) {
            _lastDocument = page.lastDocument;
          }
          _hasMoreProducts = page.hasMore ?? newProducts.length >= _pageSize;

          final allProducts = <ProductEntity>[
            ...currentProducts,
            ...newProducts,
          ];
          _allProducts = allProducts;
          final filteredProducts = _applyFilters(allProducts);
          final latestState = state;

          if (latestState is InventoryLoaded) {
            emit(
              latestState.copyWith(
                products: allProducts,
                filteredProducts: filteredProducts,
                hasMore: _hasMoreProducts,
                isLoadingMore: false,
                lastDocument: _lastDocument,
              ),
            );
          } else if (latestState is ProductsStreamActive) {
            emit(
              latestState.copyWith(
                products: allProducts,
                filteredProducts: filteredProducts,
                hasMore: _hasMoreProducts,
                isLoadingMore: false,
                lastDocument: _lastDocument,
              ),
            );
          }
        },
      );
    } finally {
      _isLoadingMoreProducts = false;
    }
  }

  Future<void> _onCreateNewProduct(
    CreateNewProduct event,
    Emitter<InventoryState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج لا يتحقق من صلاحية
    // 'inventory_create' قبل السماح بإنشاء منتج. على عكس _onDeleteProduct
    // و _onUpdateQuantity الذين يتحققان من الصلاحية. يُنصح بإضافة فحص
    // صلاحية موحد هنا لتحقيق الاتساق مع باقي معالجات التعديل.
    if (state is InventoryLoaded) {
      final currentState = state as InventoryLoaded;
      emit(currentState.copyWith(isCreatingProduct: true));

      final result = await createProduct(
        CreateProductParams(product: event.product),
      );

      result.fold(
        (failure) => emit(
          currentState.copyWith(
            isCreatingProduct: false,
            error: failure.message,
          ),
        ),
        (newProduct) {
          final productActorEmail =
              FirebaseAuth.instance.currentUser?.email ?? '';

          unawaited(
            SectionNotificationService.notifyNewProduct(
              newProduct,
              createdBy: newProduct.createdBy,
            ),
          );
          if (newProduct.isOutOfStock) {
            unawaited(SectionNotificationService.notifyOutOfStock(newProduct));
          } else if (newProduct.isLowStock) {
            unawaited(SectionNotificationService.notifyLowStock(newProduct));
          }

          // إرسال إشعار تنظيمي بإضافة منتج جديد
          if (productActorEmail.isNotEmpty) {
            unawaited(() async {
              try {
                final isSectionEnabled =
                    await SectionNotificationService.isSectionNotificationsEnabled(
                      'inventory',
                    );
                if (!isSectionEnabled) return;
                // ⚠️ ملاحظة للمبرمجين المستقبليين: مفتاح الإشعار هنا هو
                // 'inventory_notify_new'، بينما صفحة الإعدادات تستخدم
                // 'inventory_notify_new' للإعدادات ولكن SectionNotificationService
                // يتحقق من 'inventoryAlertsEnabled' (محتسب من مخزون منخفض + انتهاء الصلاحية).
                // أي تغيير على مفاتيح الإشعارات يجب أن يتطابق عبر جميع الملفات.
                final isTypeEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                      'inventory_notify_new',
                    );
                if (!isTypeEnabled) return;
                await PushNotificationService.sendOrganizationNotification(
                  organizationEmail: newProduct.organizationEmail,
                  title: '📦 إضافة مادة جديدة',
                  body:
                      'تمت إضافة المادة "${newProduct.name}" بكمية (${newProduct.quantity}) إلى المخزون',
                  type: 'inventory_product_created',
                  actorEmail: productActorEmail,
                  data: {'productId': newProduct.id},
                );
              } on Exception catch (_) {
                // فشل الإشعار لا يمنع إنشاء منتج المخزون.
              }
            }());
          }

          emit(const InventoryOperationSuccess('تم إضافة المنتج بنجاح'));
          final updatedProducts = [newProduct, ...currentState.products];
          emit(
            currentState.copyWith(
              products: updatedProducts,
              filteredProducts: updatedProducts,
              isCreatingProduct: false,
            ),
          );
          // ⚠️ تسجيل تدقيق تلقائي لإنشاء المنتج
          unawaited(() async {
            try {
              await repository.addInventoryLog(
                userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                actionType: 'create',
                userName: FirebaseAuth.instance.currentUser?.displayName,
                userEmail: FirebaseAuth.instance.currentUser?.email,
                details: 'تم إضافة منتج جديد: ${newProduct.name}',
                targetId: newProduct.id,
                targetType: 'product',
                newValues: {
                  'name': newProduct.name,
                  'quantity': newProduct.quantity,
                  'sellingPrice': newProduct.sellingPrice,
                  'unit': newProduct.unit,
                },
                isSuccess: true,
              );
            } on Exception catch (_) {
              // فشل تسجيل التدقيق لا يجب أن كسر العملية الرئيسية
            }
          }());
        },
      );
    }
  }

  Future<void> _onUpdateProduct(
    UpdateProduct event,
    Emitter<InventoryState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج لا يتحقق من صلاحية
    // 'inventory_edit' قبل السماح بتحديث المنتج، على عكس _onDeleteProduct
    // و _onUpdateQuantity الذين يتحققان من الصلاحية. يُنصح بإضافة فحص
    // صلاحية موحد هنا لتحقيق الاتساق مع باقي معالجات التعديل.
    //
    // ⚠️ ملاحظة إضافية: يستخدم هذا المعالج علم isCreatingProduct للإشارة
    // إلى حالة التحميل أثناء التحديث، وهو تسمية غير دقيقة semantiاً. يُنصح
    // بإضافة علم isUpdatingProduct منفصل في InventoryLoaded لتحقيق الوضوح.
    if (state is InventoryLoaded) {
      final currentState = state as InventoryLoaded;
      emit(currentState.copyWith(isCreatingProduct: true));

      final result = await repository.updateProduct(product: event.product);

      result.fold(
        (failure) => emit(
          currentState.copyWith(
            isCreatingProduct: false,
            error: failure.message,
          ),
        ),
        (updatedProduct) {
          final updatedProducts = currentState.products
              .map((p) => p.id == updatedProduct.id ? updatedProduct : p)
              .toList();

          final updatedFilteredProducts = currentState.filteredProducts
              .map((p) => p.id == updatedProduct.id ? updatedProduct : p)
              .toList();

          emit(
            currentState.copyWith(
              products: updatedProducts,
              filteredProducts: updatedFilteredProducts,
              isCreatingProduct: false,
            ),
          );
          emit(const InventoryOperationSuccess('تم تحديث المنتج بنجاح'));
          // ⚠️ تسجيل تدقيق تلقائي لتحديث المنتج
          unawaited(() async {
            try {
              await repository.addInventoryLog(
                userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                actionType: 'update',
                userName: FirebaseAuth.instance.currentUser?.displayName,
                userEmail: FirebaseAuth.instance.currentUser?.email,
                details: 'تم تحديث منتج: ${updatedProduct.name}',
                targetId: updatedProduct.id,
                targetType: 'product',
                newValues: {
                  'name': updatedProduct.name,
                  'quantity': updatedProduct.quantity,
                  'sellingPrice': updatedProduct.sellingPrice,
                  'unit': updatedProduct.unit,
                },
                isSuccess: true,
              );
            } on Exception catch (_) {
              // فشل تسجيل التدقيق لا يجب أن كسر العملية الرئيسية
            }
          }());
        },
      );
    }
  }

  Future<void> _onDeleteProduct(
    DeleteProductEvent event,
    Emitter<InventoryState> emit,
  ) async {
    // التحقق من الصلاحية
    final permissionChecker = PermissionChecker();
    final hasPermission = await permissionChecker.hasPermission(
      'inventory_delete',
    );

    if (!hasPermission) {
      if (state is InventoryLoaded) {
        final currentState = state as InventoryLoaded;
        emit(currentState.copyWith(error: 'ليس لديك صلاحية لحذف المنتجات'));
      } else {
        emit(const InventoryError('ليس لديك صلاحية لحذف المنتجات'));
      }
      return;
    }

    if (state is InventoryLoaded) {
      final currentState = state as InventoryLoaded;

      // استدعاء repository لحذف المنتج من Firebase
      final result = await deleteProduct(
        DeleteProductParams(
          productId: event.productId,
          organizationEmail: event.organizationEmail,
        ),
      );

      result.fold(
        (failure) {
          emit(currentState.copyWith(error: failure.message));
        },
        (_) {
          // حذف المنتج من القائمة المحلية بعد النجاح
          final updatedProducts = currentState.products
              .where((product) => product.id != event.productId)
              .toList();

          // إرسال إشعار تنظيمي بحذف المنتج
          final deleteProductActorEmail =
              FirebaseAuth.instance.currentUser?.email ?? '';
          if (deleteProductActorEmail.isNotEmpty) {
            unawaited(() async {
              try {
                final isSectionEnabled =
                    await SectionNotificationService.isSectionNotificationsEnabled(
                      'inventory',
                    );
                if (!isSectionEnabled) return;
                final isTypeEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                      'inventory_notify_deleted',
                    );
                if (!isTypeEnabled) return;
                await PushNotificationService.sendOrganizationNotification(
                  organizationEmail: event.organizationEmail,
                  title: '🗑️ حذف مادة من المخزون',
                  body: 'تم حذف مادة من المخزون',
                  type: 'inventory_product_deleted',
                  actorEmail: deleteProductActorEmail,
                  data: {'productId': event.productId},
                );
              } on Exception catch (_) {
                // فشل الإشعار لا يمنع حذف منتج المخزون.
              }
            }());
          }

          emit(
            currentState.copyWith(
              products: updatedProducts,
              filteredProducts: updatedProducts,
            ),
          );
          // ⚠️ تسجيل تدقيق تلقائي لحذف المنتج
          unawaited(() async {
            try {
              await repository.addInventoryLog(
                userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                actionType: 'delete',
                userName: FirebaseAuth.instance.currentUser?.displayName,
                userEmail: FirebaseAuth.instance.currentUser?.email,
                details: 'تم حذف منتج: ${event.productId}',
                targetId: event.productId,
                targetType: 'product',
                isSuccess: true,
              );
            } on Exception catch (_) {
              // فشل تسجيل التدقيق لا يجب أن كسر العملية الرئيسية
            }
          }());
        },
      );
    }
  }

  Future<void> _onUpdateQuantity(
    UpdateQuantity event,
    Emitter<InventoryState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: يتم التحقق من صلاحية 'inventory_edit'
    // قبل السماح بتحديث كمية المنتج. هذه الصلاحية معرّفة في
    // inventory_permissions.dart. بدون هذا الفحص، أي مستخدم يمكنه تعديل
    // الكمية حتى لو لم يمتلك صلاحية التعديل.
    final permissionChecker = PermissionChecker();
    final hasPermission = await permissionChecker.hasPermission(
      'inventory_edit',
    );

    if (!hasPermission) {
      if (state is InventoryLoaded) {
        final currentState = state as InventoryLoaded;
        emit(currentState.copyWith(error: 'ليس لديك صلاحية لتعديل الكمية'));
      } else {
        emit(const InventoryError('ليس لديك صلاحية لتعديل الكمية'));
      }
      return;
    }

    if (state is InventoryLoaded) {
      final currentState = state as InventoryLoaded;

      final result = await updateProductQuantity(
        UpdateProductQuantityParams(
          productId: event.productId,
          organizationEmail: event.organizationEmail,
          newQuantity: event.newQuantity,
          updatedBy: event.updatedBy,
          movementType: event.movementType,
          reason: event.reason,
          reference: event.reference,
          fromShelfId: event.fromShelfId,
          toShelfId: event.toShelfId,
          unitCost: event.unitCost,
          totalCost: event.totalCost,
          metadata: event.metadata,
        ),
      );

      result.fold((failure) => emit(currentState.copyWith(error: failure.message)), (
        updatedProduct,
      ) {
        final updatedProducts = currentState.products
            .map((p) => p.id == updatedProduct.id ? updatedProduct : p)
            .toList();

        final updatedFilteredProducts = currentState.filteredProducts
            .map((p) => p.id == updatedProduct.id ? updatedProduct : p)
            .toList();

        emit(
          currentState.copyWith(
            products: updatedProducts,
            filteredProducts: updatedFilteredProducts,
          ),
        );
        // ⚠️ تسجيل تدقيق تلقائي لتعديل الكمية
        unawaited(() async {
          try {
            await repository.addInventoryLog(
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              actionType: event.movementType == MovementType.stockIn
                  ? 'stock_in'
                  : event.movementType == MovementType.stockOut
                  ? 'stock_out'
                  : 'adjust',
              userName: FirebaseAuth.instance.currentUser?.displayName,
              userEmail: FirebaseAuth.instance.currentUser?.email,
              details: event.reason ?? 'تم تعديل كمية المنتج',
              targetId: event.productId,
              targetType: 'product',
              newValues: {
                'newQuantity': event.newQuantity,
                'movementType': event.movementType.toString(),
              },
              isSuccess: true,
            );
          } on Exception catch (_) {
            // فشل تسجيل التدقيق لا يجب أن كسر العملية الرئيسية
          }
        }());

        // ⚠️ إشعار عند تحديث الكمية (إضافة: لم يكن هناك إشعار عند تعديل الكمية)
        final productActorEmail =
            FirebaseAuth.instance.currentUser?.email ?? '';
        if (productActorEmail.isNotEmpty) {
          unawaited(() async {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'inventory',
                  );
              if (!isSectionEnabled) return;
              if (updatedProduct.isOutOfStock) {
                unawaited(
                  SectionNotificationService.notifyOutOfStock(updatedProduct),
                );
              } else if (updatedProduct.isLowStock) {
                unawaited(
                  SectionNotificationService.notifyLowStock(updatedProduct),
                );
              }
              final isTypeEnabled =
                  await SettingsService.isNotificationTypeEnabled(
                    'inventory_notify_quantity_update',
                  );
              if (!isTypeEnabled) return;
              await PushNotificationService.sendOrganizationNotification(
                organizationEmail: updatedProduct.organizationEmail,
                title: '📦 تحديث كمية مادة',
                body:
                    'تم تعديل كمية "${updatedProduct.name}" إلى (${updatedProduct.quantity})',
                type: 'inventory_quantity_updated',
                actorEmail: productActorEmail,
                data: {'productId': updatedProduct.id},
              );
            } on Exception catch (_) {
              // فشل الإشعار لا يمنع تحديث كمية المخزون.
            }
          }());
        }
      });
    }
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<InventoryState> emit,
  ) async {
    // إذا لم يكن هناك state محمل، ابدأ بـ loading
    if (state is InventoryInitial) {
      emit(InventoryLoading());
    }

    final result = await getCategories(
      GetCategoriesSimpleParams(
        organizationEmail: event.organizationEmail,
        isActive: event.isActive,
      ),
    );

    result.fold(
      (failure) {
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          emit(currentState.copyWith(error: failure.message));
        } else {
          emit(InventoryError(failure.message));
        }
      },
      (categories) {
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          emit(currentState.copyWith(categories: categories));
        } else {
          // ⚠️ ملاحظة للمبرمجين المستقبليين: عند إنشاء حالة InventoryLoaded
          // جديدة هنا، تُضبط المنتجات إلى قائمة فارغة والإحصائيات إلى خريطة
          // فارغة، مما قد يفقد البيانات المحمّلة سابقاً إذا كانت الحالة
          // الحالية ليست InventoryLoaded. يُنصح بحفظ البيانات الحالية من
          // الحالة قبل الإنشاء.
          emit(
            InventoryLoaded(
              products: const [],
              categories: categories,
              stats: const {},
              filteredProducts: const [],
            ),
          );
        }
      },
    );
  }

  Future<void> _onLoadMoreCategories(
    LoadMoreCategoriesEvent event,
    Emitter<InventoryState> emit,
  ) async {
    if (_isLoadingMoreCategories || !_hasMoreCategoriesData) return;

    _isLoadingMoreCategories = true;

    try {
      final result = await repository.getCategoriesPaginated(
        organizationEmail: event.organizationEmail,
        limit: 20,
        lastDocument: _lastDocumentCategories,
      );

      result.fold((failure) => emit(InventoryError(failure.message)), (page) {
        if (page.categories.isNotEmpty) {
          _lastDocumentCategories = page.lastDocument;
          final currentCategories = <CategoryEntity>[];
          final currentState = state;
          if (currentState is InventoryLoaded) {
            currentCategories.addAll(currentState.categories);
          }
          currentCategories.addAll(page.categories);
          _hasMoreCategoriesData = page.categories.length >= 20;

          if (currentState is InventoryLoaded) {
            emit(
              InventoryLoaded(
                products: currentState.products,
                categories: currentCategories,
                shelves: currentState.shelves,
                stats: currentState.stats,
                filteredProducts: currentState.filteredProducts,
                searchQuery: currentState.searchQuery,
                selectedCategoryId: currentState.selectedCategoryId,
                selectedShelfId: currentState.selectedShelfId,
                stockFilter: currentState.stockFilter,
                isLoadingProducts: currentState.isLoadingProducts,
                isCreatingProduct: currentState.isCreatingProduct,
                error: currentState.error,
                isGridView: currentState.isGridView,
                hasMore: currentState.hasMore,
                isLoadingMore: currentState.isLoadingMore,
                lastDocument: currentState.lastDocument,
                hasMoreCategoriesData: _hasMoreCategoriesData,
                isLoadingMoreCategories: false,
                lastDocumentCategories: _lastDocumentCategories,
              ),
            );
          }
        } else {
          _hasMoreCategoriesData = false;
          final currentState = state;
          if (currentState is InventoryLoaded) {
            emit(
              InventoryLoaded(
                products: currentState.products,
                categories: currentState.categories,
                shelves: currentState.shelves,
                stats: currentState.stats,
                filteredProducts: currentState.filteredProducts,
                searchQuery: currentState.searchQuery,
                selectedCategoryId: currentState.selectedCategoryId,
                selectedShelfId: currentState.selectedShelfId,
                stockFilter: currentState.stockFilter,
                isLoadingProducts: currentState.isLoadingProducts,
                isCreatingProduct: currentState.isCreatingProduct,
                error: currentState.error,
                isGridView: currentState.isGridView,
                hasMore: currentState.hasMore,
                isLoadingMore: currentState.isLoadingMore,
                lastDocument: currentState.lastDocument,
                hasMoreCategoriesData: false,
                isLoadingMoreCategories: false,
                lastDocumentCategories: currentState.lastDocumentCategories,
              ),
            );
          }
        }
        _isLoadingMoreCategories = false;
      });
    } on Exception catch (e) {
      _isLoadingMoreCategories = false;
      final currentState = state;
      if (currentState is InventoryLoaded) {
        emit(
          InventoryLoaded(
            products: currentState.products,
            categories: currentState.categories,
            shelves: currentState.shelves,
            stats: currentState.stats,
            filteredProducts: currentState.filteredProducts,
            searchQuery: currentState.searchQuery,
            selectedCategoryId: currentState.selectedCategoryId,
            selectedShelfId: currentState.selectedShelfId,
            stockFilter: currentState.stockFilter,
            isLoadingProducts: currentState.isLoadingProducts,
            isCreatingProduct: currentState.isCreatingProduct,
            error: currentState.error,
            isGridView: currentState.isGridView,
            hasMore: currentState.hasMore,
            isLoadingMore: currentState.isLoadingMore,
            lastDocument: currentState.lastDocument,
            hasMoreCategoriesData: currentState.hasMoreCategoriesData,
            isLoadingMoreCategories: false,
            lastDocumentCategories: currentState.lastDocumentCategories,
          ),
        );
      }
      emit(InventoryError(_readableError(e)));
    }
  }

  Future<void> _onLoadMoreShelves(
    LoadMoreShelvesEvent event,
    Emitter<InventoryState> emit,
  ) async {
    if (_isLoadingMoreShelves || !_hasMoreShelvesData) return;

    _isLoadingMoreShelves = true;

    try {
      final result = await shelfRepository.getShelvesPaginated(
        organizationEmail: event.organizationEmail,
        limit: 20,
        lastDocument: _lastDocumentShelves,
      );

      result.fold((failure) => emit(InventoryError(failure.message)), (page) {
        if (page.shelves.isNotEmpty) {
          _lastDocumentShelves = page.lastDocument;
          final currentShelves = <ShelfEntity>[];
          final currentState = state;
          if (currentState is InventoryLoaded && currentState.shelves != null) {
            currentShelves.addAll(currentState.shelves!);
          }
          currentShelves.addAll(page.shelves);
          _hasMoreShelvesData = page.shelves.length >= 20;

          if (currentState is InventoryLoaded) {
            emit(
              InventoryLoaded(
                products: currentState.products,
                categories: currentState.categories,
                shelves: currentShelves,
                stats: currentState.stats,
                filteredProducts: currentState.filteredProducts,
                searchQuery: currentState.searchQuery,
                selectedCategoryId: currentState.selectedCategoryId,
                selectedShelfId: currentState.selectedShelfId,
                stockFilter: currentState.stockFilter,
                isLoadingProducts: currentState.isLoadingProducts,
                isCreatingProduct: currentState.isCreatingProduct,
                error: currentState.error,
                isGridView: currentState.isGridView,
                hasMore: currentState.hasMore,
                isLoadingMore: currentState.isLoadingMore,
                lastDocument: currentState.lastDocument,
                hasMoreCategoriesData: currentState.hasMoreCategoriesData,
                isLoadingMoreCategories: currentState.isLoadingMoreCategories,
                lastDocumentCategories: currentState.lastDocumentCategories,
                hasMoreShelvesData: _hasMoreShelvesData,
                isLoadingMoreShelves: false,
                lastDocumentShelves: _lastDocumentShelves,
              ),
            );
          }
        } else {
          _hasMoreShelvesData = false;
          final currentState = state;
          if (currentState is InventoryLoaded) {
            emit(
              InventoryLoaded(
                products: currentState.products,
                categories: currentState.categories,
                shelves: currentState.shelves,
                stats: currentState.stats,
                filteredProducts: currentState.filteredProducts,
                searchQuery: currentState.searchQuery,
                selectedCategoryId: currentState.selectedCategoryId,
                selectedShelfId: currentState.selectedShelfId,
                stockFilter: currentState.stockFilter,
                isLoadingProducts: currentState.isLoadingProducts,
                isCreatingProduct: currentState.isCreatingProduct,
                error: currentState.error,
                isGridView: currentState.isGridView,
                hasMore: currentState.hasMore,
                isLoadingMore: currentState.isLoadingMore,
                lastDocument: currentState.lastDocument,
                hasMoreCategoriesData: currentState.hasMoreCategoriesData,
                isLoadingMoreCategories: currentState.isLoadingMoreCategories,
                lastDocumentCategories: currentState.lastDocumentCategories,
                hasMoreShelvesData: false,
                isLoadingMoreShelves: false,
                lastDocumentShelves: currentState.lastDocumentShelves,
              ),
            );
          }
        }
        _isLoadingMoreShelves = false;
      });
    } on Exception catch (e) {
      _isLoadingMoreShelves = false;
      final currentState = state;
      if (currentState is InventoryLoaded) {
        emit(
          InventoryLoaded(
            products: currentState.products,
            categories: currentState.categories,
            shelves: currentState.shelves,
            stats: currentState.stats,
            filteredProducts: currentState.filteredProducts,
            searchQuery: currentState.searchQuery,
            selectedCategoryId: currentState.selectedCategoryId,
            selectedShelfId: currentState.selectedShelfId,
            stockFilter: currentState.stockFilter,
            isLoadingProducts: currentState.isLoadingProducts,
            isCreatingProduct: currentState.isCreatingProduct,
            error: currentState.error,
            isGridView: currentState.isGridView,
            hasMore: currentState.hasMore,
            isLoadingMore: currentState.isLoadingMore,
            lastDocument: currentState.lastDocument,
            hasMoreCategoriesData: currentState.hasMoreCategoriesData,
            isLoadingMoreCategories: currentState.isLoadingMoreCategories,
            lastDocumentCategories: currentState.lastDocumentCategories,
            hasMoreShelvesData: currentState.hasMoreShelvesData,
            isLoadingMoreShelves: false,
            lastDocumentShelves: currentState.lastDocumentShelves,
          ),
        );
      }
      emit(InventoryError(_readableError(e)));
    }
  }

  Future<void> _onLoadShelves(
    LoadShelves event,
    Emitter<InventoryState> emit,
  ) async {
    // إذا لم يكن هناك state محمل، ابدأ بـ loading
    if (state is InventoryInitial) {
      emit(InventoryLoading());
    }

    final result = await getShelves(
      GetShelvesSimpleParams(
        organizationEmail: event.organizationEmail,
        zone: event.zone,
        isActive: event.isActive,
      ),
    );

    result.fold(
      (failure) {
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          emit(currentState.copyWith(error: failure.message));
        } else {
          emit(InventoryError(failure.message));
        }
      },
      (shelves) {
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          emit(currentState.copyWith(shelves: shelves));
        } else {
          // ⚠️ ملاحظة للمبرمجين المستقبليين: عند إنشاء حالة InventoryLoaded
          // جديدة هنا، تُضبط المنتجات والفئات إلى قوائم فارغة والإحصائيات
          // إلى خريطة فارغة، مما قد يفقد البيانات المحمّلة سابقاً. يُنصح
          // بحفظ البيانات الحالية من الحالة قبل الإنشاء.
          emit(
            InventoryLoaded(
              products: const [],
              categories: const [],
              stats: const {},
              filteredProducts: const [],
              shelves: shelves,
            ),
          );
        }
      },
    );
  }

  void _onSearchProducts(SearchProducts event, Emitter<InventoryState> emit) {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: البحث والفلترة يُطبقان على
    // currentState.products في حالة InventoryLoaded، وعلى _allProducts في
    // حالة ProductsStreamActive. هذا يضمن عمل البحث في جميع حالات التحميل.
    _searchQuery = event.query;

    final sourceProducts = state is ProductsStreamActive
        ? _allProducts
        : _getCurrentProducts(state);

    if (sourceProducts == null) return;

    final filteredProducts = _applyFilters(sourceProducts);
    final displayedFiltered = filteredProducts.length > 10
        ? filteredProducts.sublist(0, 10)
        : filteredProducts;

    // ⚠️ ملاحظة للمبرمجين المستقبليين: يُطبق حد 10 نتائج فقط في حالة
    // ProductsStreamActive، بينما في حالة InventoryLoaded تُعرض كل
    // النتائج المفلترة دون حد. هذا يسبب اختلافاً في عدد النتائج المعروضة
    // بين وضع الستريم ووضع التحميل العادي. يُنصح بتوحيد السلوك.
    if (state is ProductsStreamActive) {
      final currentState = state as ProductsStreamActive;
      emit(
        currentState.copyWith(
          filteredProducts: displayedFiltered,
          searchQuery: event.query,
        ),
      );
    } else if (state is InventoryLoaded) {
      final currentState = state as InventoryLoaded;
      emit(
        currentState.copyWith(
          filteredProducts: displayedFiltered,
          searchQuery: event.query,
        ),
      );
    }
  }

  /// إعادة المنتجات الحالية من الحالة لأي حالة كانت
  List<ProductEntity>? _getCurrentProducts(InventoryState state) {
    if (state is InventoryLoaded) return state.products;
    if (state is ProductsStreamActive) return state.products;
    return null;
  }

  void _onFilterProducts(FilterProducts event, Emitter<InventoryState> emit) {
    // ⚠️ إصلاح 2026-10-12: مزامنة حقول
    // الفلترة الحالية قبل التطبيق — كانت
    // غير مُسنَدة أبداً فكانت _applyFilters
    // تتجاهلها (تُفقد الفلاتر عند البحث
    // ولا يُطبَّق البحث عند الفلترة).
    // _applyFilters تطبق فئة + رف + مخزون
    // + بحث معاً — النتيجة مطابقة تماماً
    // للفلتر اليدوي السابق (isLowStock و
    // isOutOfStock و isInStock مطابقة للشروط).
    _selectedCategoryId = event.categoryId;
    _selectedShelfId = event.shelfId;
    _stockFilter = event.stockFilter;

    final sourceProducts = state is ProductsStreamActive
        ? _allProducts
        : _getCurrentProducts(state);

    if (sourceProducts == null) return;

    // ✅ تطبيق الفلتر على كل المنتجات
    final filteredProducts = _applyFilters(sourceProducts);

    // ✅ تطبيق الحد الأقصى على النتائج المفلترة (ل ProductsStreamActive فقط)
    final displayedFiltered =
        state is ProductsStreamActive && filteredProducts.length > 10
        ? filteredProducts.sublist(0, 10)
        : filteredProducts;

    if (state is ProductsStreamActive) {
      final currentState = state as ProductsStreamActive;
      emit(
        currentState.copyWith(
          filteredProducts: displayedFiltered,
          selectedCategoryId: event.categoryId,
          selectedShelfId: event.shelfId,
          stockFilter: event.stockFilter,
        ),
      );
    } else if (state is InventoryLoaded) {
      final currentState = state as InventoryLoaded;
      emit(
        currentState.copyWith(
          filteredProducts: filteredProducts,
          selectedCategoryId: event.categoryId,
          selectedShelfId: event.shelfId,
          stockFilter: event.stockFilter,
        ),
      );
    }
  }

  Future<void> _onRefreshInventory(
    RefreshInventory event,
    Emitter<InventoryState> emit,
  ) async {
    add(LoadInventoryData(organizationEmail: event.organizationEmail));
  }

  void _onToggleInventoryViewMode(
    ToggleInventoryViewMode event,
    Emitter<InventoryState> emit,
  ) {
    if (state is InventoryLoaded) {
      final currentState = state as InventoryLoaded;
      emit(currentState.copyWith(isGridView: !currentState.isGridView));
    }
  }

  /// معالج إنشاء فئة جديدة
  Future<void> _onCreateCategory(
    CreateCategory event,
    Emitter<InventoryState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج لا يتحقق من صلاحية
    // 'inventory_categories_manage' أو 'inventory_create' قبل إنشاء الفئة.
    // يُنصح بإضافة فحص صلاحية موحد هنا لتحقيق الاتساق مع _onDeleteProduct.
    try {
      // استدعاء repository لإنشاء الفئة
      final result = await createCategory(
        create_category_usecase.CreateCategoryParams(category: event.category),
      );

      result.fold(
        (failure) {
          if (state is InventoryLoaded) {
            final currentState = state as InventoryLoaded;
            emit(currentState.copyWith(error: failure.message));
          } else {
            emit(InventoryError(failure.message));
          }
        },
        (category) {
          // إعادة تحميل الفئات بعد الإنشاء
          add(LoadCategories(organizationEmail: category.organizationEmail));

          if (state is InventoryLoaded) {
            final currentState = state as InventoryLoaded;
            emit(
              currentState.copyWith(
                categories: [...currentState.categories, category],
              ),
            );
          }
        },
      );
    } on Exception catch (e) {
      if (state is InventoryLoaded) {
        final currentState = state as InventoryLoaded;
        emit(currentState.copyWith(error: _readableError(e)));
      } else {
        emit(InventoryError(_readableError(e)));
      }
    }
  }

  /// معالج تحديث فئة
  Future<void> _onUpdateCategory(
    UpdateCategoryEvent event,
    Emitter<InventoryState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج لا يتحقق من صلاحية
    // قبل تحديث الفئة. يُنصح بإضافة فحص صلاحية لتحقيق الاتساق مع _onDeleteProduct.
    try {
      final currentState = state;
      if (currentState is! InventoryLoaded) {
        emit(const InventoryError('يجب تحميل البيانات أولاً'));
        return;
      }

      final result = await repository.updateCategory(category: event.category);

      result.fold(
        (failure) {
          if (state is InventoryLoaded) {
            final currentState = state as InventoryLoaded;
            emit(currentState.copyWith(error: failure.message));
          } else {
            emit(InventoryError(failure.message));
          }
        },
        (updatedCategory) {
          // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج لا يسجل عملية
          // تحديث الفئة في سجل التدقيق (InventoryLog). على عكس عمليات
          // المنتجات التي تُسجل عبر addInventoryLog. يُنصح بإضافة سجل
          // تدقيق هنا لتحقيق تتبع كامل للتغييرات على الفئات.
          final updatedCategories = currentState.categories.map((category) {
            if (category.id == updatedCategory.id) {
              return updatedCategory;
            }
            return category;
          }).toList();

          if (state is InventoryLoaded) {
            final currentState = state as InventoryLoaded;
            emit(currentState.copyWith(categories: updatedCategories));
          }

          emit(const InventoryOperationSuccess('تم تحديث الفئة بنجاح'));
        },
      );
    } on Exception catch (e) {
      if (state is InventoryLoaded) {
        final currentState = state as InventoryLoaded;
        emit(currentState.copyWith(error: _readableError(e)));
      } else {
        emit(InventoryError(_readableError(e)));
      }
    }
  }

  /// معالج حذف فئة
  Future<void> _onDeleteCategory(
    DeleteCategoryEvent event,
    Emitter<InventoryState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج لا يتحقق من صلاحية
    // 'inventory_delete' قبل حذف الفئة، على عكس _onDeleteProduct الذي
    // يتحقق من الصلاحية. يُنصح بإضافة فحص صلاحية موحد هنا لتحقيق الاتساق.
    try {
      final currentState = state;
      if (currentState is! InventoryLoaded) {
        emit(const InventoryError('يجب تحميل البيانات أولاً'));
        return;
      }

      final result = await repository.deleteCategory(
        id: event.categoryId,
        organizationEmail: event.organizationEmail,
      );

      result.fold(
        (failure) {
          if (state is InventoryLoaded) {
            final currentState = state as InventoryLoaded;
            emit(currentState.copyWith(error: failure.message));
          } else {
            emit(InventoryError(failure.message));
          }
        },
        (_) {
          final updatedCategories = currentState.categories
              .where((category) => category.id != event.categoryId)
              .toList();

          // ⚠️ ملاحظة للمبرمجين المستقبليين: حذف الفئة لا يُسجل في سجل
          // التدقيق (InventoryLog). على عكس حذف المنتج الذي يُسجل عبر
          // addInventoryLog. يُنصح بإضافة سجل تدقيق هنا لتتبع حذف الفئات.
          if (state is InventoryLoaded) {
            final currentState = state as InventoryLoaded;
            emit(currentState.copyWith(categories: updatedCategories));
          }

          emit(const InventoryOperationSuccess('تم حذف الفئة بنجاح'));
        },
      );
    } on Exception catch (e) {
      if (state is InventoryLoaded) {
        final currentState = state as InventoryLoaded;
        emit(currentState.copyWith(error: _readableError(e)));
      } else {
        emit(InventoryError(_readableError(e)));
      }
    }
  }

  /// معالج تحميل سجلات المخزون
  Future<void> _onLoadInventoryLogs(
    LoadInventoryLogsEvent event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    try {
      final result = await repository.getInventoryLogs(
        userId: event.userId,
        searchQuery: event.searchQuery,
        actionFilter: event.actionFilter,
        dateFilter: event.dateFilter,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: event.limit ?? 50,
      );

      result.fold(
        (failure) => emit(InventoryError(failure.message)),
        (logs) => emit(InventoryLogsLoaded(logs)),
      );
    } on Exception catch (e) {
      emit(InventoryError(_readableError(e)));
    }
  }

  /// معالج تحديث كمية المنتج بعد الإرجاع
  Future<void> _onUpdateProductQuantityAfterReturn(
    UpdateProductQuantityAfterReturn event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج يستدعي
      // state as InventoryLoaded دون التحقق من نوع الحالة أولاً.
      // إذا كانت الحالة ليست InventoryLoaded (مثلاً InventoryInitial
      // أو InventoryError)، سيحدث CastException. يُنصح بإضافة
      // فحص if (state is InventoryLoaded) قبل الاستدعاء.
      final currentState = state as InventoryLoaded;

      // الحصول على المنتج الحالي (للحصول على organizationEmail فقط)
      final product = currentState.products.firstWhere(
        (p) => p.id == event.productId,
        orElse: () => throw Exception('المنتج غير موجود'),
      );

      // زيادة الكمية (قيمة احتياطية فقط — تُتجاهل عند توفير quantityDelta)
      final newQuantity = product.quantity + event.quantity;

      // ⚠️ حماية (إصلاح 2026-10-08 — ملخص الذرية في
      // product_repository_impl.dart): لا تعتمد على
      // product.quantity من الحالة المحلية فقد تكون قديمة —
      // quantityDelta هو المرجع الحقيقي: المستودع يحسب
      // الكمية النهائية ذرياً من اللقطة الحية داخل المعاملة،
      // ويجعل سجل الحركة يوثق القيم الحقيقية.
      final result = await updateProductQuantity(
        UpdateProductQuantityParams(
          productId: event.productId,
          organizationEmail: product.organizationEmail,
          newQuantity: newQuantity,
          quantityDelta: event.quantity,
          updatedBy: 'system',
          movementType: MovementType.stockIn,
          reason: 'ارجاع مواد من فاتورة مرجع بيع',
        ),
      );

      result.fold((failure) => emit(InventoryError(failure.message)), (
        updatedProduct,
      ) {
        // إعادة تحميل البيانات
        add(LoadInventoryData(organizationEmail: product.organizationEmail));
      });
    } on Exception catch (e) {
      emit(InventoryError(_readableError(e)));
    }
  }

  /// معالج إنشاء رف جديد
  Future<void> _onCreateShelf(
    CreateShelf event,
    Emitter<InventoryState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج لا يتحقق من صلاحية
    // قبل إنشاء رف. يُنصح بإضافة فحص صلاحية لتحقيق الاتساق مع _onDeleteProduct.
    final result = await shelfRepository.createShelf(shelf: event.shelf);

    result.fold(
      (failure) {
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          emit(currentState.copyWith(error: failure.message));
        } else {
          emit(InventoryError(failure.message));
        }
      },
      (newShelf) {
        emit(const InventoryOperationSuccess('تم إنشاء الرف بنجاح'));
        // ⚠️ ملاحظة للمبرمجين المستقبليين: إنشاء الرف لا يُسجل في سجل
        // التدقيق (InventoryLog). يُنصح بإضافة addInventoryLog هنا لتتبع
        // إنشاء الأرفف للأغراض الأمنية والتدقيقية.
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          final List<ShelfEntity> updatedShelves = [
            newShelf,
            ...(currentState.shelves ?? []),
          ];
          emit(currentState.copyWith(shelves: updatedShelves));
        }
      },
    );
  }

  /// معالج تحديث رف
  Future<void> _onUpdateShelf(
    UpdateShelfEvent event,
    Emitter<InventoryState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج لا يتحقق من صلاحية
    // قبل تحديث رف. يُنصح بإضافة فحص صلاحية لتحقيق الاتساق مع _onDeleteProduct.
    final result = await shelfRepository.updateShelf(shelf: event.shelf);

    result.fold(
      (failure) {
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          emit(currentState.copyWith(error: failure.message));
        } else {
          emit(InventoryError(failure.message));
        }
      },
      (updatedShelf) {
        emit(const InventoryOperationSuccess('تم تحديث الرف بنجاح'));
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          final List<ShelfEntity> updatedShelves = (currentState.shelves ?? [])
              .map((s) => s.id == updatedShelf.id ? updatedShelf : s)
              .toList();
          emit(currentState.copyWith(shelves: updatedShelves));
        }
      },
    );
  }

  /// معالج حذف رف
  Future<void> _onDeleteShelf(
    DeleteShelfEvent event,
    Emitter<InventoryState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا المعالج لا يتحقق من صلاحية
    // قبل حذف الرف. يُنصح بإضافة فحص صلاحية (مثلاً 'inventory_delete'
    // أو صلاحية مخصصة للأرفف) لتحقيق الاتساق مع _onDeleteProduct.
    final result = await shelfRepository.deleteShelf(
      id: event.shelfId,
      organizationEmail: event.organizationEmail,
    );

    result.fold(
      (failure) {
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          emit(currentState.copyWith(error: failure.message));
        } else {
          emit(InventoryError(failure.message));
        }
      },
      (_) {
        emit(const InventoryOperationSuccess('تم حذف الرف بنجاح'));
        // ⚠️ ملاحظة للمبرمجين المستقبليين: حذف الرف لا يُسجل في سجل
        // التدقيق (InventoryLog). على عكس حذف المنتج الذي يُسجل عبر
        // addInventoryLog. يُنصح بإضافة سجل تدقيق هنا لتتبع حذف الأرفف.
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          final List<ShelfEntity> updatedShelves = (currentState.shelves ?? [])
              .where((s) => s.id != event.shelfId)
              .toList();
          emit(currentState.copyWith(shelves: updatedShelves));
        }
      },
    );
  }

  /// معالج إعادة حساب عدادات الأرفف من المنتجات الفعلية
  /// (تصحيح عدادات البيانات القديمة لمرة واحدة)
  Future<void> _onRecalculateShelfCounters(
    RecalculateShelfCountersEvent event,
    Emitter<InventoryState> emit,
  ) async {
    final result = await shelfRepository.recalculateShelfItemCounts(
      organizationEmail: event.organizationEmail,
    );

    result.fold(
      (failure) {
        if (state is InventoryLoaded) {
          final currentState = state as InventoryLoaded;
          emit(currentState.copyWith(error: failure.message));
        } else {
          emit(InventoryError(failure.message));
        }
      },
      (_) {
        emit(
          const InventoryOperationSuccess('تم إعادة حساب عدادات الأرفف بنجاح'),
        );
        // إعادة تحميل الأرفف لعرض العدادات المُصححة
        add(LoadShelves(organizationEmail: event.organizationEmail));
      },
    );
  }

  /// بدء الاستماع للمنتجات مع التحديث الفوري
  Future<void> _onStartProductsStream(
    StartProductsStreamEvent event,
    Emitter<InventoryState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _productsStreamSubscription?.cancel();

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is ProductsStreamActive || state is InventoryLoaded;
    if (!hasExistingData) {
      emit(InventoryLoading());
    }

    try {
      final params = GetProductsStreamParams(
        organizationEmail: event.organizationEmail,
        categoryId: event.categoryId,
        shelfId: event.shelfId,
        isActive: event.isActive,
        lowStock: event.lowStock,
        limit: event.limit,
        searchQuery: event.searchQuery,
      );

      final stream = getProductsStream(params);

      _productsStreamSubscription = stream.listen(
        (result) {
          add(_ProductsStreamDataReceived(result));
        },
        onError: (error) {
          add(_ProductsStreamErrorReceived(_readableError(error)));
        },
        onDone: () {
          // Stream completed
        },
      );
    } on Exception catch (e) {
      if (!emit.isDone) emit(InventoryError(_readableError(e)));
    }
  }

  /// إيقاف الاستماع للمنتجات
  Future<void> _onStopProductsStream(
    StopProductsStreamEvent event,
    Emitter<InventoryState> emit,
  ) async {
    await _productsStreamSubscription?.cancel();
    _productsStreamSubscription = null;
  }

  /// بدء الاستماع لإحصائيات المنتجات مع التحديث الفوري
  Future<void> _onStartProductsStatsStream(
    StartProductsStatsStreamEvent event,
    Emitter<InventoryState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _statsStreamSubscription?.cancel();

    try {
      final stream = getProductsStatsStream(event.organizationEmail);

      _statsStreamSubscription = stream.listen(
        (result) {
          add(_ProductsStatsStreamDataReceived(result));
        },
        onError: (error) {},
        onDone: () {
          // Stream completed
        },
      );
    } on Exception catch (_) {
      // تجاهل الأخطاء في إنشاء stream الإحصائيات
      // ⚠️ known issue: أخطاء Stream الإحصائيات تُبلع صامتاً هنا ولا
      // تُرسَل إلى واجهة المستخدم. إذا احتاج النظام لإظهار خطأ الإحصائيات،
      // أضف emit(InventoryError(...)) في onError.
    }
  }

  /// إيقاف الاستماع لإحصائيات المنتجات
  Future<void> _onStopProductsStatsStream(
    StopProductsStatsStreamEvent event,
    Emitter<InventoryState> emit,
  ) async {
    await _statsStreamSubscription?.cancel();
    _statsStreamSubscription = null;
  }

  /// بدء الاستماع للأرفف مع التحديث الفوري
  ///
  /// ⚠️ ملاحظة للمبرمجين المستقبليين:
  /// عدادات currentItems تتغير ذرياً مع عمليات المنتجات
  /// (نفس المعاملة) — هذا الستريم يبقي الأرفف حية دون
  /// إعادة تحميل يدوي. الأخطاء تُتجاهل لأن البيانات
  /// تبقى صالحة من آخر لقطة ناجحة.
  Future<void> _onStartShelvesStream(
    StartShelvesStreamEvent event,
    Emitter<InventoryState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _shelvesStreamSubscription?.cancel();

    try {
      final params = GetShelvesStreamParams(
        organizationEmail: event.organizationEmail,
        zone: event.zone,
        isActive: event.isActive,
      );

      final stream = getShelvesStream(params);

      _shelvesStreamSubscription = stream.listen(
        (result) {
          add(_ShelvesStreamDataReceived(result));
        },
        onError: (error) {
          // تجاهل أخطاء ستريم الأرفف — تبقى آخر بيانات صالحة
          // ⚠️ known issue: أخطاء ستريم الأرفف تُبلع صامتاً ولا تُرسَل
          // إلى واجهة المستخدم.
        },
        onDone: () {
          // Stream completed
        },
      );
    } on Exception catch (_) {
      // تجاهل أخطاء إنشاء ستريم الأرفف
    }
  }

  /// إيقاف الاستماع للأرفف
  Future<void> _onStopShelvesStream(
    StopShelvesStreamEvent event,
    Emitter<InventoryState> emit,
  ) async {
    await _shelvesStreamSubscription?.cancel();
    _shelvesStreamSubscription = null;
  }

  /// تطبيق الفلاتر والبحث على المنتجات
  List<ProductEntity> _applyFilters(List<ProductEntity> products) {
    var filtered = products;

    // تطبيق فلتر الفئة
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((product) => product.categoryId == _selectedCategoryId)
          .toList();
    }

    // تطبيق فلتر الرف
    if (_selectedShelfId != null) {
      filtered = filtered
          .where((product) => product.shelfId == _selectedShelfId)
          .toList();
    }

    // تطبيق فلتر المخزون
    if (_stockFilter != null) {
      switch (_stockFilter) {
        case StockFilter.lowStock:
          filtered = filtered.where((product) => product.isLowStock).toList();
          break;
        case StockFilter.outOfStock:
          // التحقق من أن تتبع الكمية مفعل قبل تطبيق فلتر نفاد المخزون
          filtered = filtered
              .where(
                (product) => product.trackQuantity && product.quantity <= 0,
              )
              .toList();
          break;
        case StockFilter.inStock:
          // التحقق من أن تتبع الكمية مفعل قبل تطبيق فلتر توفر المخزون
          filtered = filtered
              .where(
                (product) => !product.trackQuantity || product.quantity > 0,
              )
              .toList();
          break;
        default:
          break;
      }
    }

    // تطبيق البحث النصي
    if (_searchQuery.isNotEmpty) {
      // ⚠️ أداء (تحقق يدوي 2026-10-12): queryLower
      // مُخرَجة من اللامدا — تُحسب مرة واحدة بدلاً
      // من تكرارها لكل منتج (نص ثابت لا يتغير)
      // فالنتيجة متطابقة تماماً والفلترة أسرع.
      // لا تُعيد إدخالها داخل اللامدا.
      final queryLower = _searchQuery.toLowerCase();
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(queryLower) ||
            (product.description?.toLowerCase().contains(queryLower) ??
                false) ||
            (product.barcode?.toLowerCase().contains(queryLower) ?? false);
      }).toList();
    }

    return filtered;
  }

  /// معالج استلام البيانات من stream المنتجات
  void _onProductsStreamDataReceived(
    _ProductsStreamDataReceived event,
    Emitter<InventoryState> emit,
  ) {
    event.result.fold(
      (failure) {
        emit(InventoryError(failure.message));
      },
      (products) {
        // ✅ حفظ كل المنتجات للفلترة الكاملة
        _allProducts = products;

        // الإحصائيات تُحسب من جميع المنتجات في لقطة الستريم، بينما
        // حالة القائمة قد تحتوي على صفحة واحدة فقط.
        final stats = <String, dynamic>{
          'products': {
            'totalProducts': products.length,
            'activeProducts': products
                .where((product) => product.isActive)
                .length,
            'lowStockProducts': products
                .where((product) => product.isLowStock)
                .length,
            'outOfStockProducts': products
                .where((product) => product.isOutOfStock)
                .length,
            'totalInventoryValue': products.fold<double>(
              0,
              (total, product) => total + product.inventoryValue,
            ),
          },
        };

        final currentState = state;
        final List<ProductEntity> sourceProducts;
        if (currentState is InventoryLoaded) {
          sourceProducts = currentState.products;
        } else if (currentState is ProductsStreamActive) {
          sourceProducts = currentState.products;
        } else {
          sourceProducts = _allProducts;
        }
        final filteredProducts = _applyFilters(sourceProducts);
        final displayedFilteredProducts =
            currentState is ProductsStreamActive && filteredProducts.length > 10
            ? filteredProducts.sublist(0, 10)
            : filteredProducts;

        // ✅ التحقق من الحالة الحالية وحفظ الإحصائيات
        if (currentState is InventoryLoaded) {
          // ✅ التحقق من تغير البيانات قبل emit
          final productsChanged = !listEquals(
            currentState.products,
            _allProducts,
          );
          final filteredProductsChanged = !listEquals(
            currentState.filteredProducts,
            displayedFilteredProducts,
          );

          if (productsChanged || filteredProductsChanged) {
            emit(
              ProductsStreamActive(
                products: _allProducts,
                filteredProducts: displayedFilteredProducts,
                searchQuery: _searchQuery,
                selectedCategoryId: _selectedCategoryId,
                selectedShelfId: _selectedShelfId,
                stockFilter: _stockFilter,
                isGridView: false,
                stats: stats, // ✅ الإحصائيات من نفس اللقطة
                categories: currentState.categories,
                shelves: currentState.shelves,
                hasMore: currentState.hasMore,
                isLoadingMore: currentState.isLoadingMore,
                lastDocument: currentState.lastDocument,
              ),
            );
          }
        } else {
          emit(
            ProductsStreamActive(
              products: _allProducts,
              filteredProducts: displayedFilteredProducts,
              searchQuery: _searchQuery,
              selectedCategoryId: _selectedCategoryId,
              selectedShelfId: _selectedShelfId,
              stockFilter: _stockFilter,
              isGridView: false,
              stats: stats,
              hasMore: currentState is InventoryLoaded
                  ? currentState.hasMore
                  : currentState is ProductsStreamActive
                  ? currentState.hasMore
                  : false,
              isLoadingMore: currentState is InventoryLoaded
                  ? currentState.isLoadingMore
                  : currentState is ProductsStreamActive
                  ? currentState.isLoadingMore
                  : false,
              lastDocument: currentState is InventoryLoaded
                  ? currentState.lastDocument
                  : currentState is ProductsStreamActive
                  ? currentState.lastDocument
                  : null,
            ),
          );
        }
      },
    );
  }

  /// معالج استلام البيانات من ستريم الأرفف
  void _onShelvesStreamDataReceived(
    _ShelvesStreamDataReceived event,
    Emitter<InventoryState> emit,
  ) {
    event.result.fold(
      (failure) {
        // لا نوقف التطبيق بسبب خطأ في ستريم الأرفف
      },
      (shelves) {
        final currentState = state;
        // تحديث الرفوف في الحالة الحالية فقط (المنتجات
        // لها ستريمها الخاص وحالتها ProductsStreamActive)
        if (currentState is InventoryLoaded) {
          emit(currentState.copyWith(shelves: shelves));
        } else if (currentState is ProductsStreamActive) {
          emit(currentState.copyWith(shelves: shelves));
        }
      },
    );
  }

  /// معالج استلام خطأ من stream المنتجات
  void _onProductsStreamErrorReceived(
    _ProductsStreamErrorReceived event,
    Emitter<InventoryState> emit,
  ) {
    emit(InventoryError(event.error));
  }

  /// معالج استلام البيانات من stream الإحصائيات
  void _onProductsStatsStreamDataReceived(
    _ProductsStatsStreamDataReceived event,
    Emitter<InventoryState> emit,
  ) {
    event.result.fold(
      (failure) {
        // لا نوقف التطبيق بسبب خطأ في الإحصائيات
      },
      (stats) {
        // ✅ التحقق من تغير الإحصائيات قبل emit
        final statsChanged = state is ProductsStreamActive
            ? (state as ProductsStreamActive).stats != stats
            : state is InventoryLoaded
            ? (state as InventoryLoaded).stats != stats
            : true;

        if (statsChanged) {
          if (state is ProductsStreamActive) {
            final currentState = state as ProductsStreamActive;
            emit(currentState.copyWith(stats: stats));
          } else if (state is InventoryLoaded) {
            final currentState = state as InventoryLoaded;
            emit(currentState.copyWith(stats: stats));
          }
        }
      },
    );
  }

  /// تحميل سجلات حركة المنتج
  Future<void> _onLoadProductLogs(
    LoadProductLogsEvent event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());

    try {
      final result = await repository.getProductLogs(
        productId: event.productId,
        invoiceType: event.invoiceType,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: event.limit,
      );

      result.fold(
        (failure) => emit(InventoryError(failure.message)),
        (logs) => emit(ProductLogsLoaded(logs: logs)),
      );
    } on Exception catch (e) {
      emit(InventoryError(_readableError(e)));
    }
  }

  @override
  Future<void> close() async {
    await _productsStreamSubscription?.cancel();
    await _statsStreamSubscription?.cancel();
    await _shelvesStreamSubscription?.cancel();
    return super.close();
  }
}

/// تصفية المخزون حسب الحالة
enum StockFilter { all, inStock, lowStock, outOfStock }

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
