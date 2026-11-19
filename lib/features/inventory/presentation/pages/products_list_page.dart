import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/section_badge_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../../../core/widgets/section_alert_banner.dart';
import '../../data/models/category_model.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/delete_product_dialog.dart';
import '../widgets/inventory_drawer.dart';

/// صفحة عرض جميع المنتجات
class ProductsListPage extends StatefulWidget {
  const ProductsListPage({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  final ScrollController _scrollController = ScrollController();
  late InventoryBloc _bloc; // حفظ reference للـ bloc
  Timer? _searchDebounceTimer;

  // متغيرات الصلاحيات
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canViewReports = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
    }
    // حفظ reference للـ bloc
    _bloc = context.read<InventoryBloc>();
    _scrollController.addListener(_onScroll);
    _loadProductsPaginated(isRefresh: true);
    _loadPermissions(); // تحميل الصلاحيات
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا لا نعيد تحميل البيانات هنا؟
    // لأن initState يبدأ التحميل بالفعل، وإعادة
    // التحميل هنا تُعيد بدء الستريم عند كل تغيّر
    // (مثل ظهور الكيبورد) فتهدم الواجهة وتغلق الكيبورد.
    // ==========================================
  }



  void _loadProducts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    _bloc.add(
      LoadInventoryData(
        organizationEmail: user.email!,
        searchQuery: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        statusFilter: _selectedFilter,
      ),
    );
  }

  void forceRefresh() => _loadProductsPaginated(isRefresh: true);

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    final hasMore = state is InventoryLoaded
        ? state.hasMore
        : state is ProductsStreamActive
        ? state.hasMore
        : false;
    final isLoadingMore = state is InventoryLoaded
        ? state.isLoadingMore
        : state is ProductsStreamActive
        ? state.isLoadingMore
        : false;
    if (!hasMore || isLoadingMore) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _bloc.add(
        LoadMoreProductsEvent(
          user.email!,
          searchQuery: _searchController.text.isNotEmpty
              ? _searchController.text
              : null,
        ),
      );
    }
  }

  void _loadProductsPaginated({bool isRefresh = false}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    _bloc.add(
      LoadProductsPaginatedEvent(
        organizationEmail: user.email!,
        isRefresh: isRefresh,
        searchQuery: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        statusFilter: _selectedFilter,
      ),
    );
  }

  /// ✅ التحقق من تنبيهات جميع المنتجات من السيرفر (بدون حد)
  Future<void> _checkAllProductsNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        final repo = GetIt.instance<ProductRepository>();
        final result = await repo.getProducts(organizationEmail: user.email!);
        result.fold((failure) {}, (allProducts) {
          SectionNotificationService.checkAndNotifyInventory(allProducts);
        });
      } on Exception catch (_) {
        // تجاهل الأخطاء في فحص التنبيهات
      }
    }
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    if (mounted) _loadProducts();
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission(
      'inventory_create',
    );
    final canEdit = await _permissionChecker.hasPermission('inventory_edit');
    final canDelete = await _permissionChecker.hasPermission(
      'inventory_delete',
    );
    // ملاحظة توافق الصلاحية: المفتاح يجب أن يطابق ما هو معرّف في
    // inventory_permissions.dart وهو 'inventory_reports_view'.
    // ⚠️ ملاحظة للمبرمجين المستقبليين: أي تعديل على معرف الصلاحية في
    // inventory_permissions.dart يجب أن ينعكس هنا أيضًا، وإلا سيظل
    // _canViewReports falso وتختفي زر التقارير.
    final canViewReports = await _permissionChecker.hasPermission(
      'inventory_reports_view',
    );

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
        _canViewReports = canViewReports;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ProductEntity> _filterProducts(List<ProductEntity> products) {
    var filtered = products;

    // تطبيق الحالة أولاً حتى يعمل البحث مع نتائج القائمة نفسها.
    if (_selectedFilter == 'active') {
      filtered = filtered.where((product) => product.isActive).toList();
    } else if (_selectedFilter == 'inactive') {
      filtered = filtered.where((product) => !product.isActive).toList();
    } else if (_selectedFilter == 'low_stock') {
      filtered = filtered.where((product) => product.isLowStock).toList();
    } else if (_selectedFilter == 'out_of_stock') {
      filtered = filtered.where((product) => product.isOutOfStock).toList();
    }

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(query) ||
            (product.description?.toLowerCase().contains(query) ?? false) ||
            (product.barcode?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const InventoryDrawer(currentRoute: AppRoutes.inventory),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'inventory_products_create_fab',
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.createProduct);
                // إعادة تحميل البيانات بعد نجاح إنشاء المنتج.
                if (result == true) {
                  forceRefresh();
                }
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is InventoryLoaded) {
            _checkAllProductsNotifications();
          }
          if (state is ProductsStreamActive) {
            _checkAllProductsNotifications();
          }
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            // ⚠️ تجنب حلقة لانهائية: لا نعيد التحميل تلقائياً عند الخطأ،
            // المستخدم يضغط زر "إعادة المحاولة" يدوياً.
          }
        },
        builder: (context, state) {
          var allProducts = <ProductEntity>[];
          var categories = <CategoryEntity>[];

          if (state is InventoryLoaded) {
            allProducts = state.products.cast<ProductEntity>();
            categories = state.categories.cast<CategoryEntity>();
          } else if (state is ProductsStreamActive) {
            allProducts = state.products.cast<ProductEntity>();
            categories = state.categories.cast<CategoryEntity>();
          }

          final filteredProducts = _filterProducts(allProducts);
          final inventorySummary = SectionBadgeService.buildInventorySummary(
            allProducts,
          );

          // إذا كانت الحالة أولية أو تحميل، نعرض شاشة التحميل
          if (state is InventoryInitial || state is InventoryLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل المنتجات...'),
                ),
              ],
            );
          }

          // إذا كانت الحالة خطأ
          if (state is InventoryError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          // إذا كانت القائمة فارغة
          if (filteredProducts.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'لا توجد منتجات',
                    message: 'ابدأ بإضافة منتج جديد',
                  ),
                ),
              ],
            );
          }

          // عرض القائمة
          return Column(
            children: [
              _buildSearchFilter(),
              if (inventorySummary.hasUrgentItems && _selectedFilter == 'all')
                SectionAlertBanner(
                  title: inventorySummary.urgencyType == 'critical'
                      ? '🚨 تنبيه نفاد كميات من المخزون'
                      : '⚠️ تنبيه مواد قليلة المخزون',
                  message: inventorySummary.summaryMessage,
                  count: inventorySummary.totalUrgentCount,
                  urgencyType: inventorySummary.urgencyType,
                ),
              Expanded(
                child: PaginatedListView<ProductEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredProducts,
                  hasMore: state is InventoryLoaded ? state.hasMore : false,
                  isLoadingMore: state is InventoryLoaded
                      ? state.isLoadingMore
                      : false,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final category = categories.firstWhere(
                      (cat) => cat.id == product.categoryId,
                      orElse: () => CategoryModel(
                        id: '',
                        name: 'غير محدد',
                        organizationEmail: '',
                        createdAt: DateTime.now(),
                        createdBy: '',
                      ),
                    );
                    return _buildProductCard(product, category);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
                  'إدارة المنتجات',
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
                  'نظام إدارة المخزون الآشوري',
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
      actions: [
        if (_canViewReports)
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.inventoryReports),
            icon: Icon(
              Icons.analytics,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تقارير المخزون',
          ),
        IconButton(
          onPressed: () => _loadProductsPaginated(isRefresh: true),
          icon: Icon(
            Icons.refresh,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildSearchFilter() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // شريط البحث الرئيسي
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // حقل البحث
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      // ⚠️ تحسين الأداء: استخدام debounce لتجنب تحميل شبكة
                      // عند كل ضغطة مفتاح. ننتظر 500 مللي ثانية بعد آخر ضغط.
                      _searchDebounceTimer?.cancel();
                      _searchDebounceTimer = Timer(
                        const Duration(milliseconds: 500),
                        () => _loadProductsPaginated(isRefresh: true),
                      );
                    },
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'البحث عن منتج...',
                      hintTextDirection: TextDirection.rtl,
                      prefixIcon: Icon(
                        Icons.search,
                        color: AssyrianTheme.primaryGold,
                        size: 24.sp,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _loadProductsPaginated(isRefresh: true);
                              },
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey,
                                size: 20.sp,
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(
                          color: AssyrianTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // زر الفلتر
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _isFilterExpanded || _selectedFilter != 'all'
                        ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _isFilterExpanded || _selectedFilter != 'all'
                          ? AssyrianTheme.primaryGold
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _isFilterExpanded = !_isFilterExpanded;
                      });
                    },
                    icon: Stack(
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: _isFilterExpanded || _selectedFilter != 'all'
                              ? AssyrianTheme.primaryGold
                              : Colors.grey[600],
                          size: 24.sp,
                        ),
                        if (_selectedFilter != 'all')
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8.w,
                              height: 8.h,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    tooltip: 'فلترة النتائج',
                  ),
                ),
              ],
            ),
          ),
          // قسم الفلاتر القابل للطي
          if (_isFilterExpanded) _buildFiltersSection(),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 8.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'حالة المنتج',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
              const Spacer(),
              if (_selectedFilter != 'all')
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFilter = 'all';
                    });
                    _loadProductsPaginated(isRefresh: true);
                  },
                  child: Text(
                    'مسح الفلتر',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AssyrianTheme.primaryGold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildFilterChip('الكل', 'all'),
              _buildFilterChip('نشط', 'active'),
              _buildFilterChip('غير نشط', 'inactive'),
              _buildFilterChip('كمية منخفضة', 'low_stock'),
              _buildFilterChip('نفذت الكمية', 'out_of_stock'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
        _loadProductsPaginated(isRefresh: true);
      },
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
      checkmarkColor: AssyrianTheme.deepBlue,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.deepBlue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 14.sp,
      ),
      side: BorderSide(
        color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[400]!,
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red[400]),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.red[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              message,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadProducts,
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductEntity product, CategoryEntity category) {
    // تحديد لون الحالة
    var statusColor = Colors.green;
    var statusText = 'متوفر';
    var statusIcon = Icons.check_circle;

    if (product.isOutOfStock) {
      statusColor = Colors.red;
      statusText = 'نفذت الكمية';
      statusIcon = Icons.cancel;
    } else if (product.isLowStock) {
      statusColor = Colors.orange;
      statusText = 'كمية منخفضة';
      statusIcon = Icons.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        minTileHeight: 72.h,
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.productDetails, arguments: product);
        },
        leading: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 100.w),
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.of(
                context,
              ).pushNamed(AppRoutes.editProduct, arguments: product).then((_) {
                forceRefresh();
              });
            } else if (value == 'delete') {
              _confirmDelete(product);
            }
          },
          itemBuilder: (context) => [
            if (_canEdit)
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16.sp, color: Colors.blue),
                    SizedBox(width: 6.w),
                    Text('تعديل', style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
            if (_canDelete)
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16.sp, color: Colors.red),
                    SizedBox(width: 6.w),
                    Text('حذف', style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
          ],
          child: CircleAvatar(
            backgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
            radius: 22.r,
            child: Icon(
              Icons.inventory_2,
              color: AssyrianTheme.primaryGold,
              size: 20.sp,
            ),
          ),
        ),
        title: Text(
          product.name,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 3.h),
            Text(
              category.name,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                Icon(statusIcon, size: 12.sp, color: statusColor),
                SizedBox(width: 4.w),
                Text(
                  '$statusText - ${_formattingService.formatStockQuantity(product.quantity.round())} ${product.unit}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _formattingService.formatProductPrice(product.sellingPrice),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AssyrianTheme.deepBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (product.costPrice != null) SizedBox(height: 2.h),
              if (product.costPrice != null)
                Text(
                  'التكلفة: ${_formattingService.formatProductPrice(product.costPrice!)}',
                  style: TextStyle(fontSize: 9.sp, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(ProductEntity product) {
    DeleteProductDialog.show(
      context,
      product,
      context.read<InventoryBloc>(),
      onDeleted: _loadProducts,
    );
  }
}
