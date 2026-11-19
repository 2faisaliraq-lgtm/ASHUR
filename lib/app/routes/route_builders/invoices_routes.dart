import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/customers/injection_container.dart'
    as customer_injection;
import '../../../features/customers/domain/repositories/customer_repository.dart';
import '../../../core/permissions/permission_checker.dart';
import '../../../features/customers/presentation/bloc/customer_bloc.dart';
import '../../../features/inventory/injection_container.dart'
    as inventory_injection;
import '../../../features/inventory/inventory_feature.dart';
import '../../../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../../../features/invoices/domain/entities/invoice_entity.dart';
import '../../../features/invoices/injection_container.dart' show getIt;
import '../../../features/invoices/invoice_feature.dart';
import '../../../features/invoices/presentation/bloc/invoice_bloc.dart';
import '../../../features/invoices/presentation/pages/archived_invoices_page.dart';
import '../../../features/invoices/presentation/pages/create_invoice_page.dart';
import '../../../features/invoices/presentation/pages/edit_invoice_page.dart';
import '../../../features/invoices/presentation/pages/invoice_details_page.dart';
import '../../../features/invoices/presentation/pages/invoice_templates_page.dart';
import '../../../features/invoices/presentation/pages/invoices_list_page.dart';
import '../../../features/invoices/presentation/pages/invoices_reports_page.dart';
import '../../../features/invoices/presentation/pages/invoices_settings_page.dart';
import '../route_guards/permission_route_builder.dart';
import '../route_paths.dart';

/// مسارات الفواتير
Map<String, WidgetBuilder> get invoicesRoutes => {
  RoutePaths.invoicesList: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    InvoiceFeature.ensureInitialized();

    return BlocProvider<InvoiceBloc>(
      create: (context) => InvoiceBloc(
        getInvoices: getIt(),
        getInvoicesPaginated: getIt(),
        getInvoicesStream: getIt(),
        getInvoiceStatsStream: getIt(),
        addInvoice: getIt(),
        updateInvoice: getIt(),
        deleteInvoice: getIt(),
        getInvoiceStats: getIt(),
        getInvoiceLogs: getIt(),
        getInvoiceLogsStream: getIt(),
        getArchivedInvoices: getIt(),
        repository: getIt(),
        customerRepository: getIt<CustomerRepository>(),
        permissionChecker: PermissionChecker(),
      ),
      child: const InvoicesListPage(),
    );
  },
  RoutePaths.archivedInvoices: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    InvoiceFeature.ensureInitialized();

    return BlocProvider<InvoiceBloc>(
      create: (context) => InvoiceBloc(
        getInvoices: getIt(),
        getInvoicesPaginated: getIt(),
        getInvoicesStream: getIt(),
        getInvoiceStatsStream: getIt(),
        addInvoice: getIt(),
        updateInvoice: getIt(),
        deleteInvoice: getIt(),
        getInvoiceStats: getIt(),
        getInvoiceLogs: getIt(),
        getInvoiceLogsStream: getIt(),
        getArchivedInvoices: getIt(),
        repository: getIt(),
        customerRepository: getIt<CustomerRepository>(),
        permissionChecker: PermissionChecker(),
      ),
      child: const ArchivedInvoicesPage(),
    );
  },
  RoutePaths.invoicesSettings: (context) => const InvoicesSettingsPage(),
  RoutePaths.invoiceTemplates: (context) {
    final user = FirebaseAuth.instance.currentUser;
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    InvoiceFeature.ensureInitialized();

    return BlocProvider<InvoiceBloc>(
      create: (context) => InvoiceBloc(
        getInvoices: getIt(),
        getInvoicesPaginated: getIt(),
        getInvoicesStream: getIt(),
        getInvoiceStatsStream: getIt(),
        addInvoice: getIt(),
        updateInvoice: getIt(),
        deleteInvoice: getIt(),
        getInvoiceStats: getIt(),
        getInvoiceLogs: getIt(),
        getInvoiceLogsStream: getIt(),
        getArchivedInvoices: getIt(),
        repository: getIt(),
        customerRepository: getIt<CustomerRepository>(),
        permissionChecker: PermissionChecker(),
      ),
      child: InvoiceTemplatesPage(organizationEmail: user?.email ?? ''),
    );
  },
  RoutePaths.invoicesReports: (context) => buildPermissionRoute(
    permission: 'invoices_reports_view',
    blocProviders: [
      BlocProvider<InvoiceBloc>(
        create: (context) {
          final user = FirebaseAuth.instance.currentUser;
          // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
          InvoiceFeature.ensureInitialized();

          return InvoiceBloc(
            getInvoices: getIt(),
            getInvoicesPaginated: getIt(),
            getInvoicesStream: getIt(),
            getInvoiceStatsStream: getIt(),
            addInvoice: getIt(),
            updateInvoice: getIt(),
            deleteInvoice: getIt(),
            getInvoiceStats: getIt(),
            getInvoiceLogs: getIt(),
            getInvoiceLogsStream: getIt(),
            getArchivedInvoices: getIt(),
            repository: getIt(),
            customerRepository: getIt<CustomerRepository>(),
            permissionChecker: PermissionChecker(),
              )..add(LoadInvoicesEvent(user?.email ?? ''));
        },
      ),
    ],
    child: const InvoicesReportsPage(),
  ),
};

/// مسارات الفواتير الديناميكية (تتطلب arguments)
Route<dynamic>? buildInvoiceRoute(String routeName, RouteSettings settings) {
  final user = FirebaseAuth.instance.currentUser;

  switch (routeName) {
    case RoutePaths.createInvoice:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      InvoiceFeature.ensureInitialized();
      // CustomerFeature already initialized at app startup
      InventoryFeature.ensureInitialized();

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithMultiBloc(
          permission: 'invoices_sales_manage',
          alternativePermissions: [
            'invoices_purchase_manage',
            'invoices_cash_manage',
            'invoices_subscription_manage',
            'invoices_sales_return_manage',
          ],
          blocProviders: [
              BlocProvider<InvoiceBloc>(
                create: (context) => InvoiceBloc(
                  getInvoices: getIt(),
                  getInvoicesPaginated: getIt(),
                  getInvoicesStream: getIt(),
                  getInvoiceStatsStream: getIt(),
                  addInvoice: getIt(),
                  updateInvoice: getIt(),
                  deleteInvoice: getIt(),
                  getInvoiceStats: getIt(),
                  getInvoiceLogs: getIt(),
                  getInvoiceLogsStream: getIt(),
                  getArchivedInvoices: getIt(),
                  repository: getIt(),
                      customerRepository: getIt<CustomerRepository>(),
                      permissionChecker: PermissionChecker(),
                            ),
            ),
            BlocProvider<CustomerBloc>(
              create: (context) => CustomerBloc(
                getCustomers: customer_injection.getIt(),
                getCustomersPaginated: customer_injection.getIt(),
                getCustomersStream: customer_injection.getIt(),
                getCustomerStatsStream: customer_injection.getIt(),
                addCustomer: customer_injection.getIt(),
                addCustomerWithOpeningBalance: customer_injection.getIt(),
                updateCustomer: customer_injection.getIt(),
                deleteCustomer: customer_injection.getIt(),
                getCustomerStats: customer_injection.getIt(),
                getCustomerLogs: customer_injection.getIt(),
                repository: customer_injection.getIt(),
              )..add(LoadCustomersEvent(user?.email ?? '')),
            ),
            BlocProvider<InventoryBloc>(
              create: (context) => InventoryBloc(
                getProducts: inventory_injection.sl(),
                getProductsPaginated: inventory_injection.sl(),
                getProductsStream: inventory_injection.sl(),
                getProductsStatsStream: inventory_injection.sl(),
                createProduct: inventory_injection.sl(),
                deleteProduct: inventory_injection.sl(),
                updateProductQuantity: inventory_injection.sl(),
                updateProductPrices: inventory_injection.sl(),
                getCategories: inventory_injection.sl(),
                getShelves: inventory_injection.sl(),
                getShelvesStream: inventory_injection.sl(),
                getInventoryStats: inventory_injection.sl(),
                createCategory: inventory_injection.sl(),
                repository: inventory_injection.sl(),
                shelfRepository: inventory_injection.sl(),
              )..add(LoadInventoryData(organizationEmail: user?.email ?? '')),
            ),
          ],
          child: const CreateInvoicePage(),
        ),
        settings: settings,
      );

    case RoutePaths.editInvoice:
      final invoice = settings.arguments;
      if (invoice != null) {
        final invoiceType = (invoice as InvoiceEntity).type;
        // تحديد الصلاحية المطلوبة بناءً على نوع الفاتورة
        String requiredPermission;
        switch (invoiceType) {
          case 'sales':
            requiredPermission = 'invoices_sales_manage';
            break;
          case 'purchase':
            requiredPermission = 'invoices_purchase_manage';
            break;
          case 'cash':
            requiredPermission = 'invoices_cash_manage';
            break;
          case 'subscription':
            requiredPermission = 'invoices_subscription_manage';
            break;
          case 'sales_return':
            requiredPermission = 'invoices_sales_return_manage';
            break;
          default:
            // لا يوجد fallback لـ invoices_edit لأنها حذفت
            requiredPermission = 'invoices_sales_manage';
        }

        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        InvoiceFeature.ensureInitialized();
        // CustomerFeature already initialized at app startup
        InventoryFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithMultiBloc(
            permission: requiredPermission,
            blocProviders: [
              BlocProvider<InvoiceBloc>(
                create: (context) => InvoiceBloc(
                  getInvoices: getIt(),
                  getInvoicesPaginated: getIt(),
                  getInvoicesStream: getIt(),
                  getInvoiceStatsStream: getIt(),
                  addInvoice: getIt(),
                  updateInvoice: getIt(),
                  deleteInvoice: getIt(),
                  getInvoiceStats: getIt(),
                   getInvoiceLogs: getIt(),
                    getInvoiceLogsStream: getIt(),
                    getArchivedInvoices: getIt(),
                     repository: getIt(),
                         customerRepository: getIt<CustomerRepository>(),
                      permissionChecker: PermissionChecker(),
                            ),
              ),
              BlocProvider<CustomerBloc>(
                create: (context) => CustomerBloc(
                  getCustomers: customer_injection.getIt(),
                  getCustomersPaginated: customer_injection.getIt(),
                  getCustomersStream: customer_injection.getIt(),
                  getCustomerStatsStream: customer_injection.getIt(),
                  addCustomer: customer_injection.getIt(),
                  addCustomerWithOpeningBalance: customer_injection.getIt(),
                  updateCustomer: customer_injection.getIt(),
                  deleteCustomer: customer_injection.getIt(),
                  getCustomerStats: customer_injection.getIt(),
                  getCustomerLogs: customer_injection.getIt(),
                  repository: customer_injection.getIt(),
                )..add(LoadCustomersEvent(user?.email ?? '')),
              ),
              BlocProvider<InventoryBloc>(
                create: (context) => InventoryBloc(
                  getProducts: inventory_injection.sl(),
                  getProductsPaginated: inventory_injection.sl(),
                  getProductsStream: inventory_injection.sl(),
                  getProductsStatsStream: inventory_injection.sl(),
                  createProduct: inventory_injection.sl(),
                  deleteProduct: inventory_injection.sl(),
                  updateProductQuantity: inventory_injection.sl(),
                  updateProductPrices: inventory_injection.sl(),
                  getCategories: inventory_injection.sl(),
                  getShelves: inventory_injection.sl(),
                  getShelvesStream: inventory_injection.sl(),
                  getInventoryStats: inventory_injection.sl(),
                  createCategory: inventory_injection.sl(),
                  repository: inventory_injection.sl(),
                  shelfRepository: inventory_injection.sl(),
                )..add(LoadInventoryData(organizationEmail: user?.email ?? '')),
              ),
            ],
            child: EditInvoicePage(invoice: invoice),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.invoiceDetails:
      final invoice = settings.arguments;
      if (invoice != null) {
        final invoiceType = (invoice as InvoiceEntity).type;
        // تحديد الصلاحية المطلوبة بناءً على نوع الفاتورة
        String requiredPermission;
        switch (invoiceType) {
          case 'sales':
            requiredPermission = 'invoices_sales_manage';
            break;
          case 'purchase':
            requiredPermission = 'invoices_purchase_manage';
            break;
          case 'cash':
            requiredPermission = 'invoices_cash_manage';
            break;
          case 'subscription':
            requiredPermission = 'invoices_subscription_manage';
            break;
          case 'sales_return':
            requiredPermission = 'invoices_sales_return_manage';
            break;
          default:
            // لا يوجد fallback لـ invoices_view لأنها حذفت
            requiredPermission = 'invoices_sales_manage';
        }

        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        InvoiceFeature.ensureInitialized();
        // CustomerFeature already initialized at app startup
        InventoryFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithMultiBloc(
            permission: requiredPermission,
            blocProviders: [
              BlocProvider<InvoiceBloc>(
                create: (context) => InvoiceBloc(
                  getInvoices: getIt(),
                  getInvoicesPaginated: getIt(),
                  getInvoicesStream: getIt(),
                  getInvoiceStatsStream: getIt(),
                  addInvoice: getIt(),
                  updateInvoice: getIt(),
                  deleteInvoice: getIt(),
                  getInvoiceStats: getIt(),
                   getInvoiceLogs: getIt(),
                    getInvoiceLogsStream: getIt(),
                    getArchivedInvoices: getIt(),
                     repository: getIt(),
                         customerRepository: getIt<CustomerRepository>(),
                      permissionChecker: PermissionChecker(),
                            ),
              ),
              BlocProvider<CustomerBloc>(
                create: (context) => CustomerBloc(
                  getCustomers: customer_injection.getIt(),
                  getCustomersPaginated: customer_injection.getIt(),
                  getCustomersStream: customer_injection.getIt(),
                  getCustomerStatsStream: customer_injection.getIt(),
                  addCustomer: customer_injection.getIt(),
                  addCustomerWithOpeningBalance: customer_injection.getIt(),
                  updateCustomer: customer_injection.getIt(),
                  deleteCustomer: customer_injection.getIt(),
                  getCustomerStats: customer_injection.getIt(),
                  getCustomerLogs: customer_injection.getIt(),
                  repository: customer_injection.getIt(),
                )..add(LoadCustomersEvent(user?.email ?? '')),
              ),
              BlocProvider<InventoryBloc>(
                create: (context) => InventoryBloc(
                  getProducts: inventory_injection.sl(),
                  getProductsPaginated: inventory_injection.sl(),
                  getProductsStream: inventory_injection.sl(),
                  getProductsStatsStream: inventory_injection.sl(),
                  createProduct: inventory_injection.sl(),
                  deleteProduct: inventory_injection.sl(),
                  updateProductQuantity: inventory_injection.sl(),
                  updateProductPrices: inventory_injection.sl(),
                  getCategories: inventory_injection.sl(),
                  getShelves: inventory_injection.sl(),
                  getShelvesStream: inventory_injection.sl(),
                  getInventoryStats: inventory_injection.sl(),
                  createCategory: inventory_injection.sl(),
                  repository: inventory_injection.sl(),
                  shelfRepository: inventory_injection.sl(),
                )..add(LoadInventoryData(organizationEmail: user?.email ?? '')),
              ),
            ],
            child: InvoiceDetailsPage(invoice: invoice),
          ),
          settings: settings,
        );
      }
      return null;

    default:
      return null;
  }
}
