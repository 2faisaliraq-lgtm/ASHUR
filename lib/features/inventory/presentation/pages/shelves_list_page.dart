import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/shelf_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/inventory_drawer.dart';

/// صفحة عرض جميع الرفوف
class ShelvesListPage extends StatefulWidget {
  const ShelvesListPage({super.key});

  @override
  State<ShelvesListPage> createState() => _ShelvesListPageState();
}

class _ShelvesListPageState extends State<ShelvesListPage> {
  final TextEditingController _searchController = TextEditingController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  late InventoryBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bloc = context.read<InventoryBloc>();
    _startRealTimeUpdates();
    _scrollController.addListener(_onScroll);
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
      // تحميل أول صفحة من الرفوف; المستندات التالية تُحمّل عند التمرير.
      _bloc.add(LoadMoreShelvesEvent(normalizedEmail));
      // بدء الاستماع للمخزون مع التحديث الفوري
      _bloc.add(StartProductsStreamEvent(organizationEmail: normalizedEmail));
      // بدء ستريم الأرفف — عدادات currentItems
      // تُحدَّث ذرياً مع عمليات المنتجات فتبقى
      // السعة/الامتلاء حية دون إعادة تحميل يدوي
      _bloc.add(StartShelvesStreamEvent(organizationEmail: normalizedEmail));

    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    if (state is! InventoryLoaded ||
        !(state.hasMoreShelvesData ?? false) ||
        (state.isLoadingMoreShelves ?? false)) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final normalizedEmail = EmailNormalizationService().normalize(user.email!);
      _bloc.add(LoadMoreShelvesEvent(normalizedEmail));
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

  void _loadShelves() {
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopProductsStreamEvent());
    _bloc.add(const StopShelvesStreamEvent());
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ShelfEntity> _filterShelves(List<ShelfEntity> shelves) {
    var filtered = shelves;

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((shelf) {
        return shelf.name.toLowerCase().contains(query) ||
            (shelf.description?.toLowerCase().contains(query) ?? false) ||
            (shelf.location?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // تطبيق الفلتر
    if (_selectedFilter == 'active') {
      filtered = filtered.where((shelf) => shelf.isActive).toList();
    } else if (_selectedFilter == 'inactive') {
      filtered = filtered.where((shelf) => !shelf.isActive).toList();
    } else if (_selectedFilter == 'full') {
      filtered = filtered.where((shelf) => shelf.isFull).toList();
    } else if (_selectedFilter == 'empty') {
      filtered = filtered.where((shelf) => shelf.isEmpty).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const InventoryDrawer(currentRoute: 'shelves'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: FloatingActionButton(
        heroTag: 'inventory_shelves_create_fab',
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            AppRoutes.createShelf,
          );
          if (result == true) forceRefresh();
        },
        backgroundColor: AssyrianTheme.primaryGold,
        foregroundColor: AssyrianTheme.deepBlue,
        child: Icon(Icons.add, size: 28.sp),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is InventoryOperationSuccess &&
              state.message.contains('الرف')) {
            forceRefresh();
          }
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            _loadShelves();
          }
        },
        builder: (context, state) {
          var allShelves = <ShelfEntity>[];

          if (state is InventoryLoaded) {
            allShelves = (state.shelves ?? []).cast<ShelfEntity>();
          } else if (state is ProductsStreamActive) {
            allShelves = (state.shelves ?? []).cast<ShelfEntity>();
          }

          final filteredShelves = _filterShelves(allShelves);



          if (state is InventoryInitial || state is InventoryLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل الرفوف...'),
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

          if (filteredShelves.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.shelves,
                    title: 'لا توجد رفوف',
                    message: 'ابدأ بإضافة رف جديد',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: PaginatedListView<ShelfEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredShelves,
                  hasMore: state is InventoryLoaded
                      ? state.hasMoreShelvesData ?? false
                      : false,
                  isLoadingMore: state is InventoryLoaded
                      ? state.isLoadingMoreShelves ?? false
                      : false,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildShelfCard(filteredShelves[index]),
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
                  'إدارة الرفوف',
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
          onPressed: () {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null && user.email != null) {
              final emailService = EmailNormalizationService();
              _bloc.add(
                RecalculateShelfCountersEvent(
                  organizationEmail: emailService.normalize(user.email!),
                ),
              );
            }
          },
          icon: Icon(
            Icons.calculate_outlined,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          tooltip: 'إعادة حساب عدادات الأرفف',
        ),
        IconButton(
          onPressed: _loadShelves,
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
                      _loadShelves();
                    },
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'البحث عن رف...',
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
                'حالة الرف',
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
              _buildFilterChip('ممتلئ', 'full'),
              _buildFilterChip('فارغ', 'empty'),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80.sp, color: Colors.red[300]),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadShelves,
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

  Widget _buildShelfCard(ShelfEntity shelf) {
    final occupancyRate = shelf.occupancyRate;
    Color occupancyColor = Colors.green;
    if (occupancyRate >= 90) {
      occupancyColor = Colors.red;
    } else if (occupancyRate >= 70) {
      occupancyColor = Colors.orange;
    }

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
        onTap: () => _showShelfDetails(shelf),
        leading: CircleAvatar(
          backgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
          radius: 25.r,
          child: Icon(
            Icons.shelves,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
        ),
        title: Text(
          shelf.name,
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
            if (shelf.location != null && shelf.location!.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(Icons.location_on, size: 12.sp, color: Colors.grey[600]),
                  SizedBox(width: 4.w),
                  Text(
                    shelf.location!,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            SizedBox(height: 4.h),
            Row(
              children: [
                Text(
                  'السعة: ${shelf.currentItems}/${shelf.capacity}',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: occupancyColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    _formattingService.formatPercentage(occupancyRate),
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: occupancyColor,
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
                AppRoutes.editShelf,
                arguments: shelf,
              ).then((result) {
                if (result == true || result == 'deleted') forceRefresh();
              });
            } else if (value == 'delete') {
              _confirmDelete(shelf);
            }
          },
          itemBuilder: (context) => [
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

  void _showShelfDetails(ShelfEntity shelf) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.shelves, color: AssyrianTheme.primaryGold),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                shelf.name,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (shelf.description != null && shelf.description!.isNotEmpty)
                _buildDetailRow('الوصف', shelf.description!),
              if (shelf.location != null && shelf.location!.isNotEmpty)
                _buildDetailRow('الموقع', shelf.location!),
              if (shelf.zone != null && shelf.zone!.isNotEmpty)
                _buildDetailRow('المنطقة', shelf.zone!),
              _buildDetailRow('السعة الكلية', shelf.capacity.toString()),
              _buildDetailRow('العناصر الحالية', shelf.currentItems.toString()),
              _buildDetailRow(
                'المساحة المتاحة',
                shelf.availableSpace.toString(),
              ),
              _buildDetailRow(
                'نسبة الامتلاء',
                _formattingService.formatPercentage(shelf.occupancyRate),
              ),
              _buildDetailRow('الحالة', shelf.isActive ? 'نشط' : 'غير نشط'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(
                context,
                AppRoutes.editShelf,
                arguments: shelf,
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('تعديل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(fontSize: 14.sp, color: AssyrianTheme.deepBlue),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ShelfEntity shelf) {
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
          'هل أنت متأكد من حذف الرف "${shelf.name}"؟\nلا يمكن التراجع عن هذا الإجراء.',
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
