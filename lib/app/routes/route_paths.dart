/// جميع مسارات التطبيق
// ignore: avoid_classes_with_only_static_members
class RoutePaths {
  // ========== المسارات الأساسية ==========
  static const String splash = '/splash';
  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String loading = '/loading';
  static const String createAdmin = '/create-admin';
  static const String dashboard = '/dashboard';

  // ========== مسارات المستخدمين ==========
  static const String users = '/users';
  static const String usersList = '/users/list';
  static const String createUser = '/users/create';
  static const String editUser = '/users/edit';
  static const String userDetails = '/users/details';
  static const String rolesManagement = '/users/roles';
  static const String createRole = '/users/roles/create';
  static const String editRole = '/users/roles/edit';
  static const String roleDetails = '/users/roles/details';
  static const String usersSettings = '/users/settings';
  static const String usersReports = '/users/reports';
  static const String usersLog = '/users/log';

  // ========== مسارات العملاء ==========
  static const String customers = '/customers';
  static const String customersList = '/customers/list';
  static const String createCustomer = '/customers/create';
  static const String editCustomer = '/customers/edit';
  static const String customerDetails = '/customers/details';
  static const String customerGroupsList = '/customers/groups';
  static const String createCustomerGroup = '/customers/groups/create';
  static const String editCustomerGroup = '/customers/groups/edit';
  static const String customersSettings = '/customers/settings';
  static const String customersReports = '/customers/reports';

  // ========== مسارات المخزون ==========
  static const String inventory = '/inventory';
  static const String productsList = '/inventory/list';
  static const String createProduct = '/inventory/create';
  static const String editProduct = '/inventory/edit';
  static const String productDetails = '/inventory/details';
  static const String categoriesList = '/inventory/categories';
  static const String createCategory = '/inventory/categories/create';
  static const String editCategory = '/inventory/categories/edit';
  static const String categoryDetails = '/inventory/categories/details';
  static const String shelvesList = '/inventory/shelves';
  static const String createShelf = '/inventory/shelves/create';
  static const String editShelf = '/inventory/shelves/edit';
  static const String inventorySettings = '/inventory/settings';
  static const String inventoryReports = '/inventory/reports';

  // ========== مسارات الفواتير ==========
  static const String invoices = '/invoices';
  static const String invoicesList = '/invoices/list';
  static const String archivedInvoices = '/invoices/archived';
  static const String createInvoice = '/invoices/create';
  static const String editInvoice = '/invoices/edit';
  static const String invoiceDetails = '/invoices/details';
  static const String invoicesSettings = '/invoices/settings';
  static const String invoiceTemplates = '/invoices/templates';
  static const String invoicesReports = '/invoices/reports';

  // ========== مسارات المصروفات ==========
  static const String expenses = '/expenses';
  static const String expensesList = '/expenses/list';
  static const String createExpense = '/expenses/create';
  static const String editExpense = '/expenses/edit';
  static const String expenseDetails = '/expenses/details';
  static const String expensesSettings = '/expenses/settings';
  static const String expensesReports = '/expenses/reports';
  static const String expensesLog = '/expenses/log';

  // ========== مسارات الإيجارات ==========
  static const String rentals = '/rentals';
  static const String rentalsList = '/rentals/list';
  static const String createRental = '/rentals/create';
  static const String editRental = '/rentals/edit';
  static const String rentalDetails = '/rentals/details';
  static const String rentalUnits = '/rental_units';
  static const String createRentalUnit = '/create_rental_unit';
  static const String rentalsSettings = '/rentals/settings';
  static const String rentalsReports = '/rentals/reports';

  // ========== مسارات الاشتراكات ==========
  static const String subscriptions = '/subscriptions';
  static const String subscriptionsList = '/subscriptions/list';
  static const String createSubscription = '/subscriptions/create';
  static const String editSubscription = '/subscriptions/edit';
  static const String subscriptionDetails = '/subscriptions/details';
  static const String subscriptionTypesList = '/subscriptions/types';
  static const String createSubscriptionType = '/subscriptions/types/create';
  static const String editSubscriptionType = '/subscriptions/types/edit';
  static const String subscriptionTypeDetails = '/subscriptions/types/details';
  static const String subscriptionsSettings = '/subscriptions/settings';
  static const String subscriptionsReports = '/subscriptions/reports';
  static const String subscriptionsLog = '/subscriptions/log';
  static const String rechargeActivations =
      '/subscriptions/recharge-activations';
  static const String activationRechargeLogs =
      '/subscriptions/activation-recharge-logs';

  // ========== مسارات الصيانة ==========
  static const String maintenance = '/maintenance';
  static const String maintenanceList = '/maintenance/list';
  static const String createMaintenanceRequest = '/maintenance/create';
  static const String editMaintenanceRequest = '/maintenance/edit';
  static const String maintenanceDetails = '/maintenance/details';
  static const String maintenanceSettings = '/maintenance/settings';
  static const String maintenanceReports = '/maintenance/reports';
  static const String maintenanceLog = '/maintenance/log';

  // ========== مسارات التقارير ==========
  static const String reports = '/reports';
  static const String reportsList = '/reports/list';
  static const String createReport = '/reports/create';
  static const String editReport = '/reports/edit';
  static const String reportDetails = '/reports/details';
  static const String reportsSettings = '/reports/settings';
  static const String reportsLog = '/reports/log';

  // ========== مسارات الإعدادات ==========
  static const String settings = '/settings';
  static const String systemSettings = '/settings/system';
  static const String modulesSettings = '/settings/modules';
  static const String formattingSettings = '/settings/formatting';
  static const String notificationSettings = '/settings/notifications';
  static const String settingsList = '/settings/list';
  static const String pdfSettings = '/settings/pdf';

  // ========== مسارات الصندوق ==========
  static const String cashbox = '/reports/cashbox';
  static const String cashboxReport = '/reports/cashbox/report';
}
