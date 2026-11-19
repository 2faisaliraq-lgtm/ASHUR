import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/inventory/domain/entities/category_entity.dart';
import '../../../features/inventory/domain/entities/product_entity.dart';
import '../../../features/inventory/domain/entities/shelf_entity.dart';
import '../../../features/inventory/injection_container.dart' show sl;
import '../../../features/inventory/inventory_feature.dart';
import '../../../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../../../features/inventory/presentation/pages/categories_list_page.dart';
import '../../../features/inventory/presentation/pages/category_details_page.dart';
import '../../../features/inventory/presentation/pages/create_category_page.dart';
import '../../../features/inventory/presentation/pages/create_product_page.dart';
import '../../../features/inventory/presentation/pages/create_shelf_page.dart';
import '../../../features/inventory/presentation/pages/edit_category_page.dart';
import '../../../features/inventory/presentation/pages/edit_product_page.dart';
import '../../../features/inventory/presentation/pages/edit_shelf_page.dart';
import '../../../features/inventory/presentation/pages/inventory_reports_page.dart';
import '../../../features/inventory/presentation/pages/inventory_settings_page.dart';
import '../../../features/inventory/presentation/pages/product_details_page.dart';
import '../../../features/inventory/presentation/pages/products_list_page.dart';
import '../../../features/inventory/presentation/pages/shelves_list_page.dart';
import '../route_guards/bloc_route_builder.dart';
import '../route_guards/permission_route_builder.dart';
import '../route_paths.dart';

/// مسارات المخزون
Map<String, WidgetBuilder> get inventoryRoutes => {
  RoutePaths.productsList: (context) {
    final user = FirebaseAuth.instance.currentUser;
    final initialFilter = ModalRoute.of(context)?.settings.arguments as String?;
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    InventoryFeature.ensureInitialized();

    return BlocProvider<InventoryBloc>(
      create: (context) => InventoryBloc(
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
      child: ProductsListPage(initialFilter: initialFilter),
    );
  },
  RoutePaths.categoriesList: (context) {
    final user = FirebaseAuth.instance.currentUser;
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    InventoryFeature.ensureInitialized();

    return BlocProvider<InventoryBloc>(
      create: (context) => InventoryBloc(
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
      )..add(LoadInventoryData(organizationEmail: user?.email ?? '')),
      child: const CategoriesListPage(),
    );
  },
  RoutePaths.shelvesList: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    InventoryFeature.ensureInitialized();

    return BlocProvider<InventoryBloc>(
      create: (context) => InventoryBloc(
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
      child: const ShelvesListPage(),
    );
  },
  RoutePaths.inventorySettings: (context) => const InventorySettingsPage(),
  RoutePaths.inventoryReports: (context) => buildPermissionRoute(
    permission: 'reports_view',
    blocProviders: [
      BlocProvider<InventoryBloc>(
        create: (context) {
          final user = FirebaseAuth.instance.currentUser;
          // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
          InventoryFeature.ensureInitialized();

          return InventoryBloc(
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
          )..add(LoadInventoryData(organizationEmail: user?.email ?? ''));
        },
      ),
    ],
    child: const InventoryReportsPage(),
  ),
};

/// مسارات المخزون الديناميكية (تتطلب arguments)
Route<dynamic>? buildInventoryRoute(String routeName, RouteSettings settings) {
  final user = FirebaseAuth.instance.currentUser;

  switch (routeName) {
    case RoutePaths.createProduct:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      InventoryFeature.ensureInitialized();

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithMultiBloc(
          permission: 'inventory_create',
          blocProviders: [
            BlocProvider<InventoryBloc>(
              create: (context) =>
                  InventoryBloc(
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
                    )
                    ..add(LoadCategories(organizationEmail: user?.email ?? ''))
                    ..add(LoadShelves(organizationEmail: user?.email ?? '')),
            ),
          ],
          child: const CreateProductPage(),
        ),
        settings: settings,
      );

    case RoutePaths.createCategory:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      InventoryFeature.ensureInitialized();

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'inventory_create',
          bloc: InventoryBloc(
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
          )..add(LoadCategories(organizationEmail: user?.email ?? '')),
          child: const CreateCategoryPage(),
        ),
        settings: settings,
      );

    case RoutePaths.createShelf:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      InventoryFeature.ensureInitialized();

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'inventory_create',
          bloc: InventoryBloc(
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
          child: const CreateShelfPage(),
        ),
        settings: settings,
      );

    case RoutePaths.categoryDetails:
      final category = settings.arguments;
      if (category != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        InventoryFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: InventoryBloc(
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
            )..add(LoadInventoryData(organizationEmail: user?.email ?? '')),
            child: CategoryDetailsPage(category: category as CategoryEntity),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.editProduct:
      final product = settings.arguments;
      if (product != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        InventoryFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'inventory_edit',
            bloc: InventoryBloc(
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
            )..add(LoadCategories(organizationEmail: user?.email ?? '')),
            child: EditProductPage(product: product as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.productDetails:
      final product = settings.arguments;
      if (product != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        InventoryFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc:
                InventoryBloc(
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
                  )
                  ..add(LoadInventoryData(organizationEmail: user?.email ?? ''))
                  ..add(LoadShelves(organizationEmail: user?.email ?? '')),
            child: ProductDetailsPage(product: product as ProductEntity),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.editCategory:
      final category = settings.arguments;
      if (category != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        InventoryFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'inventory_edit',
            bloc: InventoryBloc(
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
            child: EditCategoryPage(category: category as CategoryEntity),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.editShelf:
      final shelf = settings.arguments;
      if (shelf != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        InventoryFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'inventory_edit',
            bloc: InventoryBloc(
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
            child: EditShelfPage(shelf: shelf as ShelfEntity),
          ),
          settings: settings,
        );
      }
      return null;

    default:
      return null;
  }
}
