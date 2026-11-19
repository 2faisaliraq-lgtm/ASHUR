import 'package:material_ui/material_ui.dart';

import '../../core/navigation/main_navigation_page.dart';
import '../../features/splash/splash_screen.dart';
import '../auth/static_auth_wrapper.dart';
import 'route_builders/auth_routes.dart';
import 'route_builders/customers_routes.dart';
import 'route_builders/expenses_routes.dart';
import 'route_builders/inventory_routes.dart';
import 'route_builders/invoices_routes.dart';
import 'route_builders/maintenance_routes.dart';
import 'route_builders/rentals_routes.dart';
import 'route_builders/reports_routes.dart';
import 'route_builders/settings_routes.dart';
import 'route_builders/subscriptions_routes.dart';
import 'route_builders/users_routes.dart';
import 'route_paths.dart';

/// مسارات التطبيق
// ignore: avoid_classes_with_only_static_members
class AppRoutes {
  static const String splash = RoutePaths.splash;
  static const String home = RoutePaths.home;
  static const String login = RoutePaths.login;
  static const String signup = RoutePaths.signup;
  static const String forgotPassword = RoutePaths.forgotPassword;
  static const String loading = RoutePaths.loading;
  static const String createAdmin = RoutePaths.createAdmin;
  static const String dashboard = RoutePaths.dashboard;
  static const String users = RoutePaths.users;
  static const String usersList = RoutePaths.usersList;
  static const String createUser = RoutePaths.createUser;
  static const String editUser = RoutePaths.editUser;
  static const String userDetails = RoutePaths.userDetails;
  static const String rolesManagement = RoutePaths.rolesManagement;
  static const String createRole = RoutePaths.createRole;
  static const String editRole = RoutePaths.editRole;
  static const String roleDetails = RoutePaths.roleDetails;
  static const String usersSettings = RoutePaths.usersSettings;
  static const String usersReports = RoutePaths.usersReports;
  static const String usersLog = RoutePaths.usersLog;
  static const String expensesLog = RoutePaths.expensesLog;
  static const String reportsLog = RoutePaths.reportsLog;
  static const String customersSettings = RoutePaths.customersSettings;
  static const String inventorySettings = RoutePaths.inventorySettings;
  static const String invoicesSettings = RoutePaths.invoicesSettings;
  static const String invoiceTemplates = RoutePaths.invoiceTemplates;
  static const String pdfSettings = RoutePaths.pdfSettings;
  static const String reportsSettings = RoutePaths.reportsSettings;
  static const String expensesSettings = RoutePaths.expensesSettings;
  static const String subscriptionsSettings = RoutePaths.subscriptionsSettings;
  static const String subscriptionsReports = RoutePaths.subscriptionsReports;
  static const String subscriptionsLog = RoutePaths.subscriptionsLog;
  static const String maintenanceSettings = RoutePaths.maintenanceSettings;
  static const String rentalsSettings = RoutePaths.rentalsSettings;
  static const String systemSettings = RoutePaths.systemSettings;
  static const String formattingSettings = RoutePaths.formattingSettings;
  static const String notificationSettings = RoutePaths.notificationSettings;
  static const String inventory = RoutePaths.inventory;
  static const String productsList = RoutePaths.productsList;
  static const String createProduct = RoutePaths.createProduct;
  static const String editProduct = RoutePaths.editProduct;
  static const String productDetails = RoutePaths.productDetails;
  static const String categoriesList = RoutePaths.categoriesList;
  static const String createCategory = RoutePaths.createCategory;
  static const String categoryDetails = RoutePaths.categoryDetails;
  static const String shelvesList = RoutePaths.shelvesList;
  static const String createShelf = RoutePaths.createShelf;
  static const String subscriptions = RoutePaths.subscriptions;
  static const String subscriptionsList = RoutePaths.subscriptionsList;
  static const String createSubscription = RoutePaths.createSubscription;
  static const String editSubscription = RoutePaths.editSubscription;
  static const String subscriptionTypesList = RoutePaths.subscriptionTypesList;
  static const String createSubscriptionType =
      RoutePaths.createSubscriptionType;
  static const String editSubscriptionType = RoutePaths.editSubscriptionType;
  static const String maintenance = RoutePaths.maintenance;
  static const String maintenanceList = RoutePaths.maintenanceList;
  static const String createMaintenanceRequest =
      RoutePaths.createMaintenanceRequest;
  static const String rentals = RoutePaths.rentals;
  static const String rentalsList = RoutePaths.rentalsList;
  static const String createRental = RoutePaths.createRental;
  static const String rentalUnits = RoutePaths.rentalUnits;
  static const String createRentalUnit = RoutePaths.createRentalUnit;
  static const String invoices = RoutePaths.invoices;
  static const String invoicesList = RoutePaths.invoicesList;
  static const String archivedInvoices = RoutePaths.archivedInvoices;
  static const String createInvoice = RoutePaths.createInvoice;
  static const String editInvoice = RoutePaths.editInvoice;
  static const String invoiceDetails = RoutePaths.invoiceDetails;
  static const String expenses = RoutePaths.expenses;
  static const String expensesList = RoutePaths.expensesList;
  static const String createExpense = RoutePaths.createExpense;
  static const String editExpense = RoutePaths.editExpense;
  static const String expenseDetails = RoutePaths.expenseDetails;
  static const String rentalDetails = RoutePaths.rentalDetails;
  static const String editRental = RoutePaths.editRental;
  static const String maintenanceDetails = RoutePaths.maintenanceDetails;
  static const String editMaintenanceRequest =
      RoutePaths.editMaintenanceRequest;
  static const String subscriptionDetails = RoutePaths.subscriptionDetails;
  static const String subscriptionTypeDetails =
      RoutePaths.subscriptionTypeDetails;
  static const String rechargeActivations = RoutePaths.rechargeActivations;
  static const String activationRechargeLogs =
      RoutePaths.activationRechargeLogs;
  static const String reportDetails = RoutePaths.reportDetails;
  static const String editReport = RoutePaths.editReport;
  static const String reports = RoutePaths.reports;
  static const String reportsList = RoutePaths.reportsList;
  static const String createReport = RoutePaths.createReport;
  static const String customers = RoutePaths.customers;
  static const String customersList = RoutePaths.customersList;
  static const String createCustomer = RoutePaths.createCustomer;
  static const String editCustomer = RoutePaths.editCustomer;
  static const String customerDetails = RoutePaths.customerDetails;
  static const String customerGroupsList = RoutePaths.customerGroupsList;
  static const String createCustomerGroup = RoutePaths.createCustomerGroup;
  static const String editCustomerGroup = RoutePaths.editCustomerGroup;
  static const String customersReports = RoutePaths.customersReports;
  static const String inventoryReports = RoutePaths.inventoryReports;
  static const String invoicesReports = RoutePaths.invoicesReports;
  static const String expensesReports = RoutePaths.expensesReports;
  static const String maintenanceReports = RoutePaths.maintenanceReports;
  static const String maintenanceLog = RoutePaths.maintenanceLog;
  static const String rentalsReports = RoutePaths.rentalsReports;
  static const String settings = RoutePaths.settings;
  static const String settingsList = RoutePaths.settingsList;
  static const String editCategory = RoutePaths.editCategory;
  static const String editShelf = RoutePaths.editShelf;
  static const String cashbox = RoutePaths.cashbox;
  static const String cashboxReport = RoutePaths.cashboxReport;

  /// جميع المسارات
  static Map<String, WidgetBuilder> get routes {
    return {
      // المسارات الأساسية
      splash: (context) => const SplashScreen(),
      home: (context) => const StaticAuthWrapper(),
      loading: (context) => const SplashScreen(),
      dashboard: (context) => MainNavigationPage(),

      // مسارات المصادقة
      ...authRoutes,

      // مسارات المستخدمين
      ...usersRoutes,

      // مسارات العملاء
      ...customersRoutes,

      // مسارات المخزون
      ...inventoryRoutes,

      // مسارات الفواتير
      ...invoicesRoutes,

      // مسارات المصروفات
      ...expensesRoutes,

      // مسارات الإيجارات
      ...rentalsRoutes,

      // مسارات الاشتراكات
      ...subscriptionsRoutes,

      // مسارات الصيانة
      ...maintenanceRoutes,

      // مسارات التقارير
      ...reportsRoutes,

      // مسارات الإعدادات
      ...settingsRoutes,
    };
  }

  /// مسارات مع معاملات
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == null) {
      throw Exception('اسم المسار غير محدد');
    }

    final route = buildUserRoute(settings.name!, settings) ??
        buildCustomerRoute(settings.name!, settings) ??
        buildInventoryRoute(settings.name!, settings) ??
        buildInvoiceRoute(settings.name!, settings) ??
        buildExpenseRoute(settings.name!, settings) ??
        buildRentalRoute(settings.name!, settings) ??
        buildSubscriptionRoute(settings.name!, settings) ??
        buildMaintenanceRoute(settings.name!, settings) ??
        buildReportRoute(settings.name!, settings);

    if (route == null) {
      throw Exception('لا يوجد معالج للمسار: ${settings.name}');
    }

    return route;
  }
}
