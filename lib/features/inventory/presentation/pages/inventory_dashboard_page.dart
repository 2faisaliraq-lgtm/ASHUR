import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/navigation/navigation_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/error_widget.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/inventory_drawer.dart';
import '../widgets/inventory_filter_chips.dart';
import '../widgets/inventory_quick_actions.dart';
import '../widgets/inventory_search_bar.dart';
import '../widgets/inventory_stats_section.dart';
import '../widgets/products_grid.dart';

/// صفحة لوحة تحكم المخزون
class InventoryDashboardPage extends StatefulWidget {
  const InventoryDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<InventoryDashboardPage> createState() => _InventoryDashboardPageState();
}

class _InventoryDashboardPageState extends State<InventoryDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final PermissionChecker _permissionChecker = PermissionChecker();
  final ScrollController _scrollController = ScrollController();
  bool _isGridView = false;
  bool _canCreate = false;
  late InventoryBloc _bloc;
  String? _currentOrganizationEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<InventoryBloc>();
    _startRealTimeUpdates();
    // ⚠️ تأجيل تحميل الصلاحيات حتى بعد بناء أول إطار للواجهة
    // لتجنب حظر واجهة المستخدم أثناء انتظار استجابات Firebase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPermissions();
      }
    });
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission(
      'inventory_create',
    );

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا لا نعيد تحميل البيانات هنا؟
    // لأن initState يبدأ الستريمات بالفعل، وإعادة
    // التحميل هنا تُعيد بدء الستريم عند كل تغيّر
    // (مثل ظهور الكيبورد) فتهدم الواجهة وتغلق الكيبورد.
    // ==========================================
  }

  void _startRealTimeUpdates() {
    // التحقق من صحة البريد الإلكتروني
    if (widget.organizationEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: البريد الإلكتروني للمؤسسة غير محدد'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _currentOrganizationEmail = widget.organizationEmail;
    // بدء الاستماع للمنتجات مع التحديث الفوري - جميع المنتجات (بدون حد)
    context.read<InventoryBloc>().add(
      StartProductsStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: null,
      ),
    );
    // ⚠️ ملاحظة أداء (2026-10-12): لمعد لا يوجد ستريم إحصائيات منفصل — تُحسب الإحصائيات من ستريم المنتجات نفسه في InventoryBloc (مستمع واحد على مجموعة products بدلاً من مستمعين يضاعفان عرض النطاق الحقيقي ومعالجة اللقطات).
  }

  void _loadInventory() {
    _currentOrganizationEmail = widget.organizationEmail;
    // في الداشبورد، نستخدم Stream مع جميع المنتجات (بدون حد)
    context.read<InventoryBloc>().add(
      StartProductsStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: null,
      ),
    );
  }

  @override
  void dispose() {
    // إغلاق bloc عند إغلاق الصفحة لمنع تسريب الاشتراكات (Zombie Streams)
    _bloc.add(const StopProductsStreamEvent());
    _bloc.close();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // العودة للداشبورد الرئيسي عند الضغط على زر الرجوع
        NavigationService().setCurrentIndex(0);
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildResponsiveAppBar(context),
        drawer: InventoryDrawer(
          currentRoute: 'dashboard',
          onAddProduct: () => _navigateToAddProduct(context),
          onManageCategories: () => _navigateToCategories(context),
          onViewReports: () => _navigateToReports(context),
          onScanBarcode: () => _navigateToBarcodeScan(context),
          onSettings: () =>
              Navigator.pushNamed(context, AppRoutes.inventorySettings),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
        ), // هوامش متناسقة مع باقي الداشبوردات
        body: BlocBuilder<InventoryBloc, InventoryState>(
          builder: (context, state) {
            if (state is InventoryError) {
              if (state.message.contains('فهارس') ||
                  state.message.contains('index')) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.build_circle_outlined,
                          size: 64,
                          color: AssyrianTheme.primaryGold,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'النظام قيد التحديث',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'يتم حالياً إعداد فهارس قاعدة البيانات لتحسين الأداء.\nسيكون المخزون متاحاً خلال دقائق قليلة.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _refreshInventory(context),
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AssyrianTheme.primaryGold,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return AppErrorWidget(
                message: state.message,
                onRetry: () => _refreshInventory(context),
              );
            }

            if (state is ProductsStreamActive) {
              return _buildInventoryContent(context, state);
            }

            if (state is InventoryLoaded) {
              return _buildInventoryContent(context, state);
            }

            // بناء الهيكل فورًا مع بيانات فارغة أثناء التحميل الأول
            return _buildInventoryContent(
              context,
              const InventoryLoaded(
                products: [],
                categories: [],
                filteredProducts: [],
              ),
            );
          },
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                heroTag: 'inventory_dashboard_create_fab',
                onPressed: () => _navigateToAddProduct(context),
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                child: Icon(Icons.add, size: 28.sp),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildInventoryContent(BuildContext context, dynamic state) {
    return RefreshIndicator(
      onRefresh: () async => _refreshInventory(context),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // النظرة العامة في سطر واحد
          SliverToBoxAdapter(
            child: InventoryStatsSection(
              stats: state.stats,
              onFilterSelected: (filter) =>
                  _navigateToProducts(context, filter),
            ),
          ),

          // الإجراءات السريعة أسفل النظرة العامة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: InventoryQuickActions(
                onAddProduct: () => _navigateToAddProduct(context),
                onManageCategories: () => _navigateToCategories(context),
                onViewReports: () => _navigateToReports(context),
                onScanBarcode: () => _navigateToBarcodeScan(context),
                onSettings: () =>
                    Navigator.pushNamed(context, AppRoutes.inventorySettings),
              ),
            ),
          ),

          // شريط البحث والفلاتر
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  // شريط البحث
                  InventorySearchBar(
                    onSearch: (query) {
                      final orgEmail = _currentOrganizationEmail;
                      if (orgEmail != null && orgEmail.isNotEmpty) {
                        context.read<InventoryBloc>().add(
                          StartProductsStreamEvent(
                            organizationEmail: orgEmail,
                            limit: query.isEmpty ? 10 : null,
                            searchQuery: query.isEmpty ? null : query,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // فلاتر المنتجات
                  InventoryFilterChips(
                    categories: state.categories,
                    selectedCategoryId: state.selectedCategoryId,
                    stockFilter: state.stockFilter,
                    onCategoryChanged: (categoryId) {
                      context.read<InventoryBloc>().add(
                        FilterProducts(
                          categoryId: categoryId,
                          shelfId: state.selectedShelfId,
                          stockFilter: state.stockFilter,
                        ),
                      );
                    },
                    onStockFilterChanged: (stockFilter) {
                      context.read<InventoryBloc>().add(
                        FilterProducts(
                          categoryId: state.selectedCategoryId,
                          shelfId: state.selectedShelfId,
                          stockFilter: stockFilter,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'آخر المنتجات',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AssyrianTheme.deepBlue,
                                fontSize: 13.sp,
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          'آخر ${state.filteredProducts.length} منتج',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[600],
                            fontFamily: 'Cairo',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // زر "عرض الكل"
                      TextButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.productsList, arguments: 'all'),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: Text(
                          'عرض الكل',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontFamily: 'Cairo',
                            color: AssyrianTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AssyrianTheme.primaryGold,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      // زر التبديل بين القائمة والشبكة
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AssyrianTheme.primaryGold.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.view_list,
                                size: 18.sp,
                                color: !_isGridView
                                    ? AssyrianTheme.primaryGold
                                    : Colors.grey,
                              ),
                              onPressed: () {
                                if (_isGridView) {
                                  setState(() => _isGridView = false);
                                }
                              },
                              tooltip: 'عرض قائمة',
                              constraints: BoxConstraints(
                                minWidth: 32.w,
                                minHeight: 32.h,
                              ),
                              padding: EdgeInsets.all(4.w),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.grid_view,
                                size: 18.sp,
                                color: _isGridView
                                    ? AssyrianTheme.primaryGold
                                    : Colors.grey,
                              ),
                              onPressed: () {
                                if (!_isGridView) {
                                  setState(() => _isGridView = true);
                                }
                              },
                              tooltip: 'عرض شبكة',
                              constraints: BoxConstraints(
                                minWidth: 32.w,
                                minHeight: 32.h,
                              ),
                              padding: EdgeInsets.all(4.w),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // شبكة/قائمة المنتجات
          ProductsGrid(
            products: state.filteredProducts,
            onProductTap: (product) =>
                _navigateToProductDetails(context, product),
            onQuantityUpdate: (productId, newQuantity, movementType, reason) {
              context.read<InventoryBloc>().add(
                UpdateQuantity(
                  productId: productId,
                  organizationEmail: widget.organizationEmail,
                  newQuantity: newQuantity,
                  updatedBy:
                      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user',
                  movementType: movementType,
                  reason: reason,
                ),
              );
            },
            isGridView: _isGridView,
          ),

          // مساحة إضافية في الأسفل للـ FAB
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _refreshInventory(BuildContext context) {
    _loadInventory();
  }

  void _navigateToProducts(BuildContext context, String filter) {
    Navigator.of(context).pushNamed(AppRoutes.productsList, arguments: filter);
  }

  void _navigateToAddProduct(BuildContext context) {
    // Navigate to add product page
    Navigator.of(context).pushNamed(AppRoutes.createProduct);
  }

  void _navigateToCategories(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.categoriesList);
  }

  void _navigateToReports(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.inventoryReports);
  }

  void _navigateToBarcodeScan(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ميزة مسح الباركود قيد التطوير'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _navigateToProductDetails(BuildContext context, product) {
    // التنقل إلى صفحة تفاصيل المنتج
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.productDetails, arguments: product);
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AssyrianTheme.backgroundGradient,
          boxShadow: [
            BoxShadow(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          AssyrianTheme.getLamassuForBackground(
            isDarkBackground: true,
            hasCircularBackground: false,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة المخزون',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                    ),
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'نظام إدارة المتاجر الآشوري',
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 10,
                    ),
                    color: AssyrianTheme.ivoryWhite,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
