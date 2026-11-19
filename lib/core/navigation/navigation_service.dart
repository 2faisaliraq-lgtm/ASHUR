import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart' as di;

import '../../core/services/enabled_modules_service.dart';
import '../../core/services/session_service.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/customers/presentation/bloc/customer_bloc.dart';
import '../../features/customers/presentation/pages/customer_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/expenses/expense_feature.dart';
import '../../features/expenses/presentation/bloc/expense_bloc.dart';
import '../../features/expenses/presentation/pages/expense_dashboard_page.dart';
import '../../features/inventory/inventory_feature.dart';
import '../../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../../features/inventory/presentation/pages/inventory_dashboard_page.dart';
import '../../features/invoices/invoice_feature.dart';
import '../../features/invoices/presentation/bloc/invoice_bloc.dart';
import '../../features/invoices/presentation/pages/invoice_dashboard_page.dart';
import '../../features/maintenance/maintenance_feature.dart';
import '../../features/maintenance/presentation/bloc/maintenance_bloc.dart';
import '../../features/maintenance/presentation/pages/maintenance_dashboard_page.dart';
import '../../features/rentals/presentation/bloc/rental_bloc.dart';
import '../../features/rentals/presentation/pages/rental_dashboard_page.dart';
import '../../features/rentals/rental_feature.dart';
import '../../features/reports/presentation/bloc/report_bloc.dart';
import '../../features/reports/presentation/pages/report_dashboard_page.dart';
import '../../features/reports/report_feature.dart';
import '../../features/settings/setting_feature.dart';
import '../../features/subscriptions/presentation/bloc/subscription_bloc.dart';
import '../../features/subscriptions/presentation/pages/subscription_dashboard_page.dart';
import '../../features/subscriptions/subscription_feature.dart';
import '../../features/users/presentation/pages/users_management_page.dart';
import '../widgets/loading_widget.dart';
import 'navigation_item.dart';

/// خدمة إدارة التنقل في التطبيق
class NavigationService {
  factory NavigationService() => _instance;
  NavigationService._internal() {
    _currentIndexNotifier = ValueNotifier<int>(0);
    _itemsNotifier = ValueNotifier<List<NavigationItem>>([]);
    switchedUserNotifier = ValueNotifier<Map<String, dynamic>?>(null);
    quickActionsSettingsNotifier = ValueNotifier<Map<String, bool>>({});
    enabledModulesNotifier = ValueNotifier<Map<String, bool>>({});
    _pagesCache = <String, Widget>{};
  }
  static final NavigationService _instance = NavigationService._internal();

  late final ValueNotifier<int> _currentIndexNotifier;
  late final ValueNotifier<List<NavigationItem>> _itemsNotifier;
  late final ValueNotifier<Map<String, dynamic>?> switchedUserNotifier;
  late final ValueNotifier<Map<String, bool>> quickActionsSettingsNotifier;
  late final ValueNotifier<Map<String, bool>> enabledModulesNotifier;
  late final Map<String, Widget> _pagesCache;

  // قائمة cached للصفحات لتجنب إعادة البناء
  List<Widget>? _cachedPagesList;

  ValueNotifier<int> get currentIndexNotifier => _currentIndexNotifier;
  ValueNotifier<List<NavigationItem>> get itemsNotifier => _itemsNotifier;
  ValueNotifier<Map<String, dynamic>?> get switchedUser =>
      switchedUserNotifier;
  ValueNotifier<Map<String, bool>> get quickActionsSettings =>
      quickActionsSettingsNotifier;
  ValueNotifier<Map<String, bool>> get enabledModules =>
      enabledModulesNotifier;

  int get currentIndex => _currentIndexNotifier.value;
  List<NavigationItem> get items => _itemsNotifier.value;

  /// التحقق مما إذا كانت بيانات التنقل محملة مسبقاً (من شاشة السبلس)
  bool get isNavigationPreloaded => _itemsNotifier.value.isNotEmpty;

  /// إعادة تعيين حالة التحميل (للاستخدام عند refresh)
  void resetPermissionsLoaded() {
    _cachedPagesList = null; // مسح قائمة الصفحات cached
  }

  /// تحديث الصلاحيات وإعادة تهيئة التنقل
  Future<void> updatePermissions(List<String> newPermissions) async {
    resetPermissionsLoaded();
    final allItems = _getAllNavigationItems();

    // استخدام التحميل المسبق إذا كان متوفراً، وإلا جلب من الخدمة
    Map<String, bool> enabledModules = enabledModulesNotifier.value;
    if (enabledModules.isEmpty) {
      enabledModules = await EnabledModulesService().getEnabledModules();
      enabledModulesNotifier.value = enabledModules;
    }

    // فلترة العناصر حسب الصلاحيات والأقسام المفعلة
    final filteredItems = <NavigationItem>[];

    for (final item in allItems) {
      // التحقق من الصلاحيات
      final hasPermission = item.canAccess(newPermissions);

      // التحقق من تفعيل القسم
      final isModuleEnabled =
          item.requiredPermissions == null ||
          item.requiredPermissions!.isEmpty ||
          item.requiredPermissions!.any(
            (perm) => enabledModules[perm] ?? false,
          );

      if (hasPermission && isModuleEnabled) {
        filteredItems.add(item);
      }
    }

    _itemsNotifier.value = filteredItems;
  }

  /// تهيئة عناصر التنقل
  Future<void> initializeNavigation({
    List<String> userPermissions = const [],
    bool isAdmin = false,
  }) async {
    final allItems = _getAllNavigationItems();

    // استخدام التحميل المسبق إذا كان متوفراً، وإلا جلب من الخدمة
    Map<String, bool> enabledModules = enabledModulesNotifier.value;
    if (enabledModules.isEmpty) {
      enabledModules = await EnabledModulesService().getEnabledModules();
      enabledModulesNotifier.value = enabledModules;
    }

    // فلترة العناصر حسب الصلاحيات والأقسام المفعلة
    final filteredItems = <NavigationItem>[];

    for (final item in allItems) {
      // التحقق من الصلاحيات
      final hasPermission = item.canAccess(userPermissions);

      // التحقق من تفعيل القسم
      final isModuleEnabled =
          item.requiredPermissions == null ||
          item.requiredPermissions!.isEmpty ||
          item.requiredPermissions!.any(
            (perm) => enabledModules[perm] ?? false,
          );

      if (hasPermission && isModuleEnabled) {
        filteredItems.add(item);
      }
    }

    // التأكد من وجود عناصر على الأقل
    if (filteredItems.isEmpty) {
      // إضافة الداشبورد كحد أدنى
      filteredItems.add(
        const NavigationItem(
          id: DefaultNavigationItems.dashboard,
          label: 'الرئيسية',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          page: SizedBox(),
          color: Colors.blue,
        ),
      );
    }

    // تحديث القائمة فقط إذا كانت مختلفة
    if (_itemsNotifier.value.length != filteredItems.length ||
        !_areItemsEqual(_itemsNotifier.value, filteredItems)) {
      _itemsNotifier.value = filteredItems;
      // مسح الـ cache عند تغيير العناصر
      _pagesCache.clear();
      _cachedPagesList = null;
      // تحميل مسبق لجميع الصفحات لتكون جاهزة عند التبديل بين الأقسام
      preloadAllPages();
    }
  }

  /// مقارنة قوائم العناصر
  bool _areItemsEqual(List<NavigationItem> list1, List<NavigationItem> list2) {
    if (list1.length != list2.length) return false;
    for (var i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) return false;
    }
    return true;
  }

  /// إعادة تحميل التنقل (لتحديث الأقسام المفعلة)
  Future<void> reloadNavigation() async {
    // الحصول على الصلاحيات الحالية من الـ items الموجودة
    final currentPermissions = <String>[];

    // إعادة تهيئة التنقل بنفس الصلاحيات
    await initializeNavigation(userPermissions: currentPermissions);
  }

  /// تغيير الصفحة الحالية
  void setCurrentIndex(int index) {
    if (index >= 0 && index < _itemsNotifier.value.length) {
      _currentIndexNotifier.value = index;
    }
  }

  /// الحصول على الصفحة الحالية
  Widget getCurrentPage() {
    // إذا كانت القائمة فارغة، عرض الداشبورد افتراضياً
    if (_itemsNotifier.value.isEmpty) {
      const pageId = DefaultNavigationItems.dashboard;
      _pagesCache.putIfAbsent(pageId, () => const DashboardPage());
      return _pagesCache[pageId]!;
    }

    final index = _currentIndexNotifier.value;
    if (index >= 0 && index < _itemsNotifier.value.length) {
      final pageId = _itemsNotifier.value[index].id;
      // استخدام الـ cache لتجنب إعادة إنشاء الصفحة
      return _pagesCache.putIfAbsent(pageId, () => _buildPage(pageId));
    }

    // إذا كان المؤشر غير صالح، عرض أول صفحة
    if (_itemsNotifier.value.isNotEmpty) {
      final pageId = _itemsNotifier.value[0].id;
      return _pagesCache.putIfAbsent(pageId, () => _buildPage(pageId));
    }

    // كحل أخير، عرض الداشبورد
    const pageId = DefaultNavigationItems.dashboard;
    _pagesCache.putIfAbsent(pageId, () => const DashboardPage());
    return _pagesCache[pageId]!;
  }

  /// الحصول على جميع الصفحات المحفوظة (للاستخدام مع IndexedStack)
  /// تُبنى الصفحة الحالية بشكل متزامن، والصفحات الأخرى تُبنى كسولاً في الخلفية
  /// لتجنب بناء جميع الصفحات مع BlocConsumer قبل أن يكون AuthBloc جاهزاً
  List<Widget> getAllPages() {
    // إرجاع القائمة cached إذا كانت موجودة
    if (_cachedPagesList != null) {
      return _cachedPagesList!;
    }

    if (_itemsNotifier.value.isEmpty) {
      _cachedPagesList = [const DashboardPage()];
      return _cachedPagesList!;
    }

    // بنِّي جميع الصفحات لتجنب عرض شاشات فارغة عند التبديل بين الأقسام
    final pages = List.generate(
      _itemsNotifier.value.length,
      (i) => _pagesCache.putIfAbsent(
        _itemsNotifier.value[i].id,
        () => _buildPage(_itemsNotifier.value[i].id),
      ),
    );

    _cachedPagesList = pages;
    return _cachedPagesList!;
  }

  /// تحميل مسبق لجميع الصفحات في الخلفية بعد بناء الصفحة الحالية
  void preloadAllPages() {
    if (_itemsNotifier.value.isEmpty) {
      return;
    }

    for (var i = 0; i < _itemsNotifier.value.length; i++) {
      final pageId = _itemsNotifier.value[i].id;
      if (!_pagesCache.containsKey(pageId)) {
        _pagesCache[pageId] = _buildPage(pageId);
      }
    }

    // تحديث _cachedPagesList ليحتوي على جميع الصفحات المبنية
    _cachedPagesList = List.generate(
      _itemsNotifier.value.length,
      (i) => _pagesCache[_itemsNotifier.value[i].id] ?? const SizedBox.shrink(),
    );
  }

  /// الحصول على صفحة معينة حسب الفهرس - للتهيئة الكسولة
  Widget getPageAtIndex(int index) {
    if (index < 0 || index >= _itemsNotifier.value.length) {
      return const DashboardPage();
    }

    final pageId = _itemsNotifier.value[index].id;
    return _pagesCache.putIfAbsent(pageId, () => _buildPage(pageId));
  }

  /// بناء الصفحة حسب المعرف
  Widget _buildPage(String pageId) {
    switch (pageId) {
      case DefaultNavigationItems.dashboard:
        return const DashboardPage();
      case DefaultNavigationItems.users:
        return const UsersManagementPage();
      case DefaultNavigationItems.customers:
        // صفحة إدارة العملاء - تهيئة سريعة في الخلفية
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // CustomerFeature already initialized at app startup
              return BlocProvider(
                create: (context) => di.GetIt.instance<CustomerBloc>(),
                child: CustomerDashboardPage(
                  organizationEmail: state.user.email,
                ),
              );
            }
            return const Center(child: Text('غير مصرح بالوصول للعملاء'));
          },
        );
      case DefaultNavigationItems.inventory:
        // صفحة إدارة المخزون - تهيئة سريعة في الخلفية
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // تهيئة سريعة في الخلفية
              InventoryFeature.ensureInitialized();
              return BlocProvider(
                create: (context) => di.GetIt.instance<InventoryBloc>(),
                child: InventoryDashboardPage(
                  organizationEmail: state.user.email,
                ),
              );
            }
            return const Center(child: Text('غير مصرح بالوصول للمخزون'));
          },
        );
      case DefaultNavigationItems.subscriptions:
        // صفحة إدارة الاشتراكات - تهيئة سريعة في الخلفية
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // تهيئة سريعة في الخلفية
              SubscriptionFeature.ensureInitialized();
              return BlocProvider(
                create: (context) => di.GetIt.instance<SubscriptionBloc>(),
                child: SubscriptionDashboardPage(
                  organizationEmail: state.user.email,
                ),
              );
            }
            return const Center(child: Text('غير مصرح بالوصول للاشتراكات'));
          },
        );
      case DefaultNavigationItems.maintenance:
        // صفحة إدارة الصيانة - تهيئة سريعة في الخلفية
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // تهيئة سريعة في الخلفية
              MaintenanceFeature.ensureInitialized();
              return BlocProvider(
                create: (context) => di.GetIt.instance<MaintenanceBloc>(),
                child: MaintenanceDashboardPage(
                  organizationEmail: state.user.email,
                ),
              );
            }
            return const Center(child: Text('غير مصرح بالوصول للصيانة'));
          },
        );
      case DefaultNavigationItems.rentals:
        // صفحة إدارة الإيجارات - تهيئة سريعة في الخلفية
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // تهيئة سريعة في الخلفية
              RentalFeature.ensureInitialized();
              return BlocProvider(
                create: (context) => di.GetIt.instance<RentalBloc>(),
                child: RentalDashboardPage(organizationEmail: state.user.email),
              );
            }
            return const Center(child: Text('غير مصرح بالوصول للإيجارات'));
          },
        );
      case DefaultNavigationItems.invoices:
        // صفحة إدارة الفواتير - تهيئة سريعة في الخلفية
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // تهيئة سريعة في الخلفية
              InvoiceFeature.ensureInitialized();
              return BlocProvider(
                create: (context) => di.GetIt.instance<InvoiceBloc>(),
                child: InvoiceDashboardPage(
                  organizationEmail: state.user.email,
                ),
              );
            }
            return const Center(child: Text('غير مصرح بالوصول للفواتير'));
          },
        );
      case DefaultNavigationItems.expenses:
        // صفحة إدارة المصاريف - تهيئة سريعة في الخلفية
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // تهيئة سريعة في الخلفية
              ExpenseFeature.ensureInitialized();
              return BlocProvider(
                create: (context) =>
                    di.GetIt.instance<ExpenseBloc>()
                      ..add(LoadExpensesEvent(state.user.email)),
                child: ExpenseDashboardPage(
                  organizationEmail: state.user.email,
                ),
              );
            }
            return const Center(child: Text('غير مصرح بالوصول للمصاريف'));
          },
        );
      case DefaultNavigationItems.reports:
        // صفحة التقارير - تهيئة سريعة في الخلفية
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              // تهيئة سريعة في الخلفية
              ReportFeature.ensureInitialized();
              return BlocProvider(
                create: (context) =>
                    di.GetIt.instance<ReportBloc>()
                      ..add(LoadReportsEvent(state.user.email)),
                child: ReportDashboardPage(organizationEmail: state.user.email),
              );
            }
            return const Center(child: Text('غير مصرح بالوصول للتقارير'));
          },
        );
      case 'cashbox':
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  Navigator.pushNamed(context, '/reports/cashbox');
                }
              });
            }
          },
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return const LoadingWidget(message: 'جاري تحميل الصندوق...');
            }
            return const Center(child: Text('غير مصرح بالوصول للصندوق'));
          },
        );
      case DefaultNavigationItems.settings:
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {},
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return FutureBuilder<Widget>(
                future: SettingFeature.createDashboard(state.user.email),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingWidget(message: 'جاري تحميل الإعدادات...');
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('خطأ: ${snapshot.error}'),
                    );
                  }
                  return snapshot.data ??
                      const Center(child: Text('غير مصرح بالوصول للإعدادات'));
                },
              );
            }
            return const Center(child: Text('غير مصرح بالوصول للإعدادات'));
          },
        );
      default:
        return const Center(child: Text('صفحة غير معروفة'));
    }
  }

  /// الحصول على جميع عناصر التنقل
  List<NavigationItem> _getAllNavigationItems() {
    return [
      // لوحة التحكم الآشورية
      const NavigationItem(
        id: DefaultNavigationItems.dashboard,
        label: 'الرئيسية',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: ['dashboard_view'],
        color: Colors.blue,
      ),

      // إدارة المستخدمين
      const NavigationItem(
        id: DefaultNavigationItems.users,
        label: 'المستخدمين',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: ['users_view'],
        color: Colors.green,
      ),

      // إدارة العملاء
      const NavigationItem(
        id: DefaultNavigationItems.customers,
        label: 'العملاء',
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: ['customers_view'],
        color: Color(0xFF2196F3), // اللون الأزرق
      ),

      // إدارة المخزون
      const NavigationItem(
        id: DefaultNavigationItems.inventory,
        label: 'المخزون',
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: ['inventory_view'],
        color: Color(0xFFD4AF37), // اللون الذهبي الآشوري
      ),

      // إدارة الاشتراكات
      const NavigationItem(
        id: DefaultNavigationItems.subscriptions,
        label: 'الاشتراكات',
        icon: Icons.subscriptions_outlined,
        activeIcon: Icons.subscriptions,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: ['subscriptions_view'],
        color: Color(0xFF9C27B0), // اللون البنفسجي
      ),

      // إدارة الصيانة
      const NavigationItem(
        id: DefaultNavigationItems.maintenance,
        label: 'الصيانة',
        icon: Icons.build_circle_outlined,
        activeIcon: Icons.build_circle,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: [
          'maintenance_view',
        ], // استخدام اسم الصلاحية الصحيح
        color: Color(0xFFFF5722), // اللون البرتقالي المحمر
      ),

      // إدارة الإيجارات
      const NavigationItem(
        id: DefaultNavigationItems.rentals,
        label: 'الإيجارات',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: ['rentals_view'],
        color: Color(0xFF00BCD4), // اللون الأزرق الفاتح
      ),

      // إدارة الفواتير
      const NavigationItem(
        id: DefaultNavigationItems.invoices,
        label: 'الفواتير',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: [
          'invoices_sales_manage',
          'invoices_purchase_manage',
          'invoices_cash_manage',
          'invoices_subscription_manage',
          'invoices_sales_return_manage',
        ],
        color: Color(0xFF4CAF50), // اللون الأخضر
      ),

      // إدارة المصاريف
      const NavigationItem(
        id: DefaultNavigationItems.expenses,
        label: 'المصاريف',
        icon: Icons.money_off_outlined,
        activeIcon: Icons.money_off,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: ['expenses_view'],
        color: Color(0xFFE91E63), // اللون الوردي
      ),

      // التقارير
      const NavigationItem(
        id: DefaultNavigationItems.reports,
        label: 'التقارير',
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics,
        page: SizedBox(), // صفحة وهمية - سيتم استبدالها في _buildPage
        requiredPermissions: ['reports_view'],
        color: Colors.orange,
      ),

      // الصندوق
      const NavigationItem(
        id: 'cashbox',
        label: 'الصندوق',
        icon: Icons.payments,
        activeIcon: Icons.payments,
        page: SizedBox(),
        requiredPermissions: ['cashbox_view'],
        color: Color(0xFFD4AF37),
      ),

      // الإعدادات
      const NavigationItem(
        id: DefaultNavigationItems.settings,
        label: 'الإعدادات',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        page: SizedBox(),
        requiredPermissions: ['settings_view'],
        color: Colors.purple,
      ),
    ];
  }
}
