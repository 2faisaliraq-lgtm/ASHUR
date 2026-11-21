import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/inventory_drawer.dart';

/// صفحة عرض جميع الفئات
class CategoriesListPage extends StatefulWidget {
  const CategoriesListPage({super.key});

  @override
  State<CategoriesListPage> createState() => _CategoriesListPageState();
}

class _CategoriesListPageState extends State<CategoriesListPage> {
  final TextEditingController _searchController = TextEditingController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  late InventoryBloc _bloc; // حفظ reference للـ bloc
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // حفظ reference للـ bloc
    _bloc = context.read<InventoryBloc>();
    _startRealTimeUpdates();
    _loadPermissions();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission(
      'inventory_create',
    );
    final canEdit = await _permissionChecker.hasPermission('inventory_edit');
    final canDelete = await _permissionChecker.hasPermission(
      'inventory_delete',
    );

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      // بدء الاستماع للمخزون مع التحديث الفوري (يشمل الفئات)
      context.read<InventoryBloc>().add(
        StartProductsStreamEvent(organizationEmail: normalizedEmail),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    if (state is! InventoryLoaded ||
        !(state.hasMoreCategoriesData ?? false) ||
        (state.isLoadingMoreCategories ?? false)) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final normalizedEmail = EmailNormalizationService().normalize(user.email!);
      _bloc.add(LoadMoreCategoriesEvent(normalizedEmail));
    }
  }

  void forceRefresh() {
    _startRealTimeUpdates();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _startRealTimeUpdates();
  }

  void _loadCategories() {
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopProductsStreamEvent());
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<CategoryEntity> _filterCategories(List<CategoryEntity> categories) {
    var filtered = categories;

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((category) {
        return category.name.toLowerCase().contains(query) ||
            (category.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // تطبيق الفلتر
    if (_selectedFilter == 'active') {
      filtered = filtered.where((category) => category.isActive).toList();
    } else if (_selectedFilter == 'inactive') {
      filtered = filtered.where((category) => !category.isActive).toList();
    } else if (_selectedFilter == 'main') {
      filtered = filtered.where((category) => category.isMainCategory).toList();
    } else if (_selectedFilter == 'sub') {
      filtered = filtered.where((category) => category.isSubCategory).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const InventoryDrawer(currentRoute: 'categories'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'inventory_categories_create_fab',
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed('/inventory/categories/create');
                if (result == true) forceRefresh();
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is InventoryOperationSuccess) {
            forceRefresh();
          }
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            _loadCategories();
          }
        },
        builder: (context, state) {
          var allCategories = <CategoryEntity>[];

          if (state is InventoryLoaded) {
            allCategories = state.categories.cast<CategoryEntity>();
          } else if (state is ProductsStreamActive) {
            // الفئات متاحة من خلال inventory bloc عند تحميل المنتجات
            final inventoryState = context.read<InventoryBloc>().state;
            if (inventoryState is InventoryLoaded) {
              allCategories = inventoryState.categories.cast<CategoryEntity>();
            }
          }

          final filteredCategories = _filterCategories(allCategories);



          if (state is InventoryInitial || state is InventoryLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل الفئات...'),
                ),
              ],
            );
          }

          if (state is InventoryError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (filteredCategories.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.category_outlined,
                    title: 'لا توجد فئات',
                    message: 'ابدأ بإضافة فئة جديدة',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: PaginatedListView<CategoryEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredCategories,
                  hasMore: state is InventoryLoaded
                      ? state.hasMoreCategoriesData ?? false
                      : false,
                  isLoadingMore: state is InventoryLoaded
                      ? state.isLoadingMoreCategories ?? false
                      : false,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildCategoryCard(filteredCategories[index]),
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
                  'إدارة الفئات',
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
        IconButton(
          onPressed: _loadCategories,
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _loadCategories();
                    },
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'البحث عن فئة...',
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
                'نوع الفئة',
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
              _buildFilterChip('رئيسية', 'main'),
              _buildFilterChip('فرعية', 'sub'),
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
            onPressed: _loadCategories,
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

  Widget _buildCategoryCard(CategoryEntity category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.all(8),
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.categoryDetails, arguments: category);
        },
        leading: CircleAvatar(
          backgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
          radius: 25.r,
          child: Icon(
            Icons.category,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category.description != null &&
                category.description!.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                category.description!,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 4.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: category.isMainCategory
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    category.isMainCategory ? 'رئيسية' : 'فرعية',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: category.isMainCategory
                          ? Colors.blue
                          : Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: category.isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    category.isActive ? 'نشط' : 'غير نشط',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: category.isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.pushNamed(
                context,
                AppRoutes.editCategory,
                arguments: category,
              ).then((_) => forceRefresh());
            } else if (value == 'delete') {
              _confirmDelete(category);
            }
          },
          itemBuilder: (context) => [
            if (_canEdit)
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18.sp, color: Colors.blue),
                    SizedBox(width: 8.w),
                    const Text('تعديل'),
                  ],
                ),
              ),
            if (_canDelete)
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18.sp, color: Colors.red),
                    SizedBox(width: 8.w),
                    const Text('حذف'),
                  ],
                ),
              ),
          ],
         ),
       ),
       ),
     );
  }

  void _confirmDelete(CategoryEntity category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28.sp),
            SizedBox(width: 8.w),
            const Text('تأكيد الحذف'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف الفئة "${category.name}"؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('وظيفة الحذف قيد التطوير'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
