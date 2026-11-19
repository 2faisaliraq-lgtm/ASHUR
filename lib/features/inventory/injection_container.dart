import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

// Data
import 'data/repositories/product_repository_impl.dart';
import 'data/repositories/shelf_repository_impl.dart';
import 'data/repositories/inventory_movement_repository_impl.dart';
// Domain
import 'domain/repositories/product_repository.dart';
import 'domain/repositories/shelf_repository.dart';
import 'domain/repositories/inventory_movement_repository.dart';
import 'domain/usecases/create_category.dart' as create_category_usecase;
import 'domain/usecases/create_product.dart';
import 'domain/usecases/delete_product.dart';
import 'domain/usecases/get_categories_simple.dart';
import 'domain/usecases/get_categories_stream.dart';
import 'domain/usecases/get_inventory_stats_simple.dart';
import 'domain/usecases/get_products.dart';
import 'domain/usecases/get_products_paginated.dart';
import 'domain/usecases/get_products_stats_stream.dart';
import 'domain/usecases/get_products_stream.dart';
import 'domain/usecases/get_shelves_simple.dart';
import 'domain/usecases/get_shelves_stream.dart';
import 'domain/usecases/update_product_prices.dart'
    as update_product_prices_usecase;
import 'domain/usecases/update_product_quantity.dart';
// Presentation
import 'presentation/bloc/inventory_bloc.dart';

final sl = GetIt.instance;

/// إعداد حقن التبعيات لميزة المخزون
Future<void> initInventoryDependencies() async {
  // External
  if (!sl.isRegistered<FirebaseFirestore>()) {
    sl.registerLazySingleton<FirebaseFirestore>(
      () => FirebaseFirestore.instance,
    );
  }

  // Repositories - تسجيل مع التحقق
  if (!sl.isRegistered<ProductRepository>()) {
    sl.registerLazySingleton<ProductRepository>(
      () => ProductRepositoryImpl(firestore: sl()),
    );
  }

  if (!sl.isRegistered<ShelfRepository>()) {
    sl.registerLazySingleton<ShelfRepository>(
      () => ShelfRepositoryImpl(firestore: sl()),
    );
  }

  if (!sl.isRegistered<InventoryMovementRepository>()) {
    sl.registerLazySingleton<InventoryMovementRepository>(
      () => InventoryMovementRepositoryImpl(firestore: sl()),
    );
  }

  // Use cases - تسجيل مع التحقق
  if (!sl.isRegistered<GetProducts>()) {
    sl.registerLazySingleton(() => GetProducts(sl()));
  }
  if (!sl.isRegistered<GetProductsPaginated>()) {
    sl.registerLazySingleton(() => GetProductsPaginated(sl()));
  }
  if (!sl.isRegistered<GetProductsStream>()) {
    sl.registerLazySingleton(() => GetProductsStream(sl()));
  }
  if (!sl.isRegistered<GetProductsStatsStream>()) {
    sl.registerLazySingleton(() => GetProductsStatsStream(sl()));
  }
  if (!sl.isRegistered<CreateProduct>()) {
    sl.registerLazySingleton(() => CreateProduct(sl()));
  }
  if (!sl.isRegistered<DeleteProduct>()) {
    sl.registerLazySingleton(() => DeleteProduct(sl()));
  }

  // Use cases - تحديث كمية المنتج (ذري)
  if (!sl.isRegistered<UpdateProductQuantity>()) {
    sl.registerLazySingleton(
      () => UpdateProductQuantity(
        productRepository: sl(),
      ),
    );
  }

  if (!sl.isRegistered<update_product_prices_usecase.UpdateProductPrices>()) {
    sl.registerLazySingleton(
      () => update_product_prices_usecase.UpdateProductPrices(
        productRepository: sl(),
      ),
    );
  }

  if (!sl.isRegistered<GetCategoriesSimple>()) {
    sl.registerLazySingleton(() => GetCategoriesSimple(sl()));
  }
  if (!sl.isRegistered<GetCategoriesStream>()) {
    sl.registerLazySingleton(() => GetCategoriesStream(sl()));
  }
  if (!sl.isRegistered<GetShelvesSimple>()) {
    sl.registerLazySingleton(() => GetShelvesSimple(sl()));
  }
  if (!sl.isRegistered<GetShelvesStream>()) {
    sl.registerLazySingleton(() => GetShelvesStream(sl()));
  }
  if (!sl.isRegistered<GetInventoryStatsSimple>()) {
    sl.registerLazySingleton(() => GetInventoryStatsSimple(sl()));
  }
  if (!sl.isRegistered<create_category_usecase.CreateCategory>()) {
    sl.registerLazySingleton(
      () => create_category_usecase.CreateCategory(sl()),
    );
  }

  // BLoC - تسجيل مع التحقق
  if (!sl.isRegistered<InventoryBloc>()) {
    sl.registerFactory(
      () => InventoryBloc(
        getProducts: sl(),
        getProductsPaginated: sl(),
        getProductsStream: sl(),
        getProductsStatsStream: sl(),
        createProduct: sl(),
        deleteProduct: sl(),
        updateProductQuantity: sl(),
        updateProductPrices: sl(),
        getCategories: sl(),
        getShelves: sl(),
        getShelvesStream: sl(),
        getInventoryStats: sl(),
        createCategory: sl(),
        repository: sl(),
        shelfRepository: sl(),
      ),
    );
  }
}
