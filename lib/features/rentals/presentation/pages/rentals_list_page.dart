import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/rental_entity.dart';
import '../bloc/rental_bloc.dart';
import '../widgets/delete_rental_dialog.dart';
import '../widgets/rental_drawer.dart';

/// صفحة عرض جميع عقود الإيجار
class RentalsListPage extends StatefulWidget {
  const RentalsListPage({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  State<RentalsListPage> createState() => _RentalsListPageState();
}

class _RentalsListPageState extends State<RentalsListPage> {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final TextEditingController _searchController = TextEditingController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canViewReports = false;
  bool _waitingForInitialFilterData = false;
  late RentalBloc _bloc; // حفظ reference للـ bloc
  String? _currentOrganizationEmail;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
      _waitingForInitialFilterData = true;
    }
    // حفظ reference للـ bloc
    _bloc = context.read<RentalBloc>();
    _startRealTimeUpdates();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission('rentals_create');
    final canEdit = await _permissionChecker.hasPermission('rentals_edit');
    final canDelete = await _permissionChecker.hasPermission('rentals_delete');
    final canViewReports = await _permissionChecker.hasPermission(
      'reports_view',
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
    if (user != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      _currentOrganizationEmail = normalizedEmail;
      // بدء الاستماع للإيجارات مع التحديث الفوري
      context.read<RentalBloc>().add(
        StartRentalsStreamEvent(organizationEmail: normalizedEmail),
      );

    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    if (state is! RentalsStreamActive ||
        !state.hasMoreData ||
        state.isLoadingMore ||
        _selectedFilter != 'all') {
      return;
    }
    final email = _currentOrganizationEmail;
    if (email != null) _bloc.add(LoadMoreRentalsEvent(email));
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

  void _loadRentals() {
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopRentalsStreamEvent());
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<RentalEntity> _filterRentals(List<RentalEntity> rentals) {
    var filtered = rentals;

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((rental) {
        return rental.itemName.toLowerCase().contains(query) ||
            rental.renterName.toLowerCase().contains(query) ||
            (rental.renterPhone?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // تطبيق الفلاتر نفسها التي تعرضها لوحة الإيجارات.
    switch (_selectedFilter) {
      case 'active':
        filtered = filtered
            .where((rental) => rental.status == 'active')
            .toList();
        break;
      case 'expired':
        filtered = filtered.where((rental) => rental.isExpired).toList();
        break;
      case 'expiring_soon':
        filtered = filtered.where((rental) => rental.isExpiringSoon).toList();
        break;
      case 'all':
      default:
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const RentalDrawer(currentRoute: 'rentals'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'rentals_list_create_fab',
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  AppRoutes.createRental,
                );
                if (result == true || result is RentalEntity) {
                  _startRealTimeUpdates();
                }
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<RentalBloc, RentalState>(
        listener: (context, state) {
          if (_waitingForInitialFilterData &&
              (state is RentalLoaded || state is RentalsStreamActive)) {
            _waitingForInitialFilterData = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
          if (state is RentalOperationSuccess) {
            final email = _currentOrganizationEmail;
            if (email != null) {
              _bloc.add(StartRentalsStreamEvent(organizationEmail: email));
            }
          }
          if (state is RentalError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            // تم إزالة _loadRentals() من هنا لتجنب حلقة إعادة التحميل
            // عند حدوث خطأ دائم؛ الستريم actif سيقوم بتحديث البيانات تلقائياً.
          }
        },
        builder: (context, state) {
          var allRentals = <RentalEntity>[];

          if (state is RentalLoaded) {
            allRentals = state.rentals.cast<RentalEntity>();
          } else if (state is RentalsStreamActive) {
            allRentals = state.rentals.cast<RentalEntity>();
          }

          final filteredRentals = _filterRentals(allRentals);



          if (state is RentalInitial || state is RentalLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل عقود الإيجار...'),
                ),
              ],
            );
          }

          if (state is RentalError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (filteredRentals.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.home_outlined,
                    title: 'لا توجد عقود إيجار',
                    message: 'ابدأ بإضافة عقد إيجار جديد',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: PaginatedListView<RentalEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredRentals,
                  hasMore:
                      state is RentalsStreamActive &&
                      state.hasMoreData &&
                      _selectedFilter == 'all',
                  isLoadingMore:
                      state is RentalsStreamActive && state.isLoadingMore,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildRentalCard(filteredRentals[index]),
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
                  'إدارة الإيجارات',
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
      actions: [
        if (_canViewReports)
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.rentalsReports);
            },
            icon: Icon(
              Icons.analytics,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'التقارير',
          ),
        IconButton(
          onPressed: _loadRentals,
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
                    // ⚠️ إصلاح (2026-10-12): كان
                    // onChanged فارغاً — الكتابة لا
                    // تعيد البناء فلا تُطبَّق الفلترة
                    // (_filterRentals تقرأ
                    // _searchController.text). setState
                    // هنا ضروري ليُعيد البناء ويُفلتر
                    // فوراً عند الكتابة.
                    onChanged: (value) {
                      final orgEmail = _currentOrganizationEmail;
                      if (orgEmail != null && orgEmail.isNotEmpty) {
                        context.read<RentalBloc>().add(
                          StartRentalsStreamEvent(
                            organizationEmail: orgEmail,
                            limit: value.isEmpty ? null : null,
                            searchQuery: value.isEmpty ? null : value,
                          ),
                        );
                      }
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث عن عقد إيجار...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AssyrianTheme.primaryGold,
                        size: 24.sp,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
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
          if (_isFilterExpanded) _buildFilterOptions(),
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          _buildFilterChip('الكل', 'all'),
          _buildFilterChip('نشط', 'active'),
          _buildFilterChip('منتهي', 'expired'),
          _buildFilterChip('منهي', 'terminated'),
          _buildFilterChip('قيد الانتظار', 'pending'),
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
      backgroundColor: Colors.white,
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.deepBlue,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.deepBlue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13.sp,
      ),
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : Colors.grey.withValues(alpha: 0.3),
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
            onPressed: _loadRentals,
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

  Widget _buildRentalCard(RentalEntity rental) {
    final statusColor = _getStatusColor(rental.status);
    final statusText = _getStatusText(rental.status);
    final daysRemaining = rental.endDate.difference(DateTime.now()).inDays;

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
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          minTileHeight: 72.h,
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            AppRoutes.rentalDetails,
            arguments: rental,
          );
          if (result == true || result is RentalEntity) {
            _startRealTimeUpdates();
          }
        },
        leading: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 100.w),
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.pushNamed(
                context,
                AppRoutes.editRental,
                arguments: rental,
              ).then((result) {
                if (result == true || result is RentalEntity) {
                  _startRealTimeUpdates();
                }
              });
            } else if (value == 'delete') {
              _showDeleteDialog(rental);
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
            backgroundColor: statusColor.withValues(alpha: 0.1),
            radius: 22.r,
            child: Icon(Icons.home, color: statusColor, size: 20.sp),
          ),
        ),
        title: Text(
          rental.itemName,
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
              rental.renterName,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 10.sp,
                  color: Colors.grey[500],
                ),
                SizedBox(width: 4.w),
                Text(
                  '${DateFormat('yyyy/MM/dd').format(rental.startDate)} - ${DateFormat('yyyy/MM/dd').format(rental.endDate)}',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            Text(
              '${_formattingService.formatRentalAmount(rental.rentalPrice)} / شهرياً',
              style: TextStyle(
                fontSize: 12.sp,
                color: AssyrianTheme.deepBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (rental.status == 'active' && daysRemaining >= 0) ...[
              SizedBox(height: 2.h),
              Text(
                'المتبقي: $daysRemaining يوم',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: daysRemaining < 30 ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        trailing: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
         ),
       ),
       ),
     );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'terminated':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'expired':
        return 'منتهي';
      case 'terminated':
        return 'منهي';
      case 'pending':
        return 'قيد الانتظار';
      default:
        return status;
    }
  }

  void _showDeleteDialog(RentalEntity rental) {
    DeleteRentalDialog.show(
      context,
      rental,
      context.read<RentalBloc>(),
      onDeleted: _loadRentals,
    );
  }
}
