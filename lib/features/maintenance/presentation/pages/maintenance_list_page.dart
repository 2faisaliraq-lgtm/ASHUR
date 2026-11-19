import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/maintenance_request_entity.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../bloc/maintenance_bloc.dart';
import '../widgets/delete_maintenance_dialog.dart';
import '../widgets/maintenance_drawer.dart';

/// صفحة عرض جميع طلبات الصيانة
class MaintenanceListPage extends StatefulWidget {
  const MaintenanceListPage({this.initialStatusFilter, super.key});

  final String? initialStatusFilter;

  @override
  State<MaintenanceListPage> createState() => _MaintenanceListPageState();
}

class _MaintenanceListPageState extends State<MaintenanceListPage> {
  final TextEditingController _searchController = TextEditingController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  final ScrollController _scrollController = ScrollController();
  String? _selectedStatusFilter; // ← فلتر الحالة منفصل
  String? _selectedPriorityFilter; // ← فلتر الأولوية منفصل
  bool _isFilterExpanded = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canViewReports = false;
  bool _waitingForInitialStatusFilter = false;
  late MaintenanceBloc _bloc; // حفظ reference للـ bloc
  DateTime? _lastNotificationTime; // ← وقت آخر إشعار لمنع التكرار

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialStatusFilter;
    _waitingForInitialStatusFilter = widget.initialStatusFilter != null;
    // حفظ reference للـ bloc
    _bloc = context.read<MaintenanceBloc>();
    _startRealTimeUpdates();
    _loadPermissions();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission(
      'maintenance_create',
    );
    final canEdit = await _permissionChecker.hasPermission('maintenance_edit');
    final canDelete = await _permissionChecker.hasPermission(
      'maintenance_delete',
    );
    final canViewReports = await _permissionChecker.hasPermission(
      'maintenance_reports_view',
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
    if (user != null && user.email != null) {
      // بدء الاستماع لطلبات الصيانة مع التحديث الفوري
      context.read<MaintenanceBloc>().add(
        StartMaintenanceStreamEvent(organizationEmail: user.email!),
      );
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

  void _loadMaintenanceRequests() {
    _startRealTimeUpdates();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    final hasMore = state is MaintenanceLoaded
        ? state.hasMoreData
        : state is MaintenanceStreamActive
        ? state.hasMoreData
        : false;
    final isLoadingMore = state is MaintenanceLoaded
        ? state.isLoadingMore
        : state is MaintenanceStreamActive
        ? state.isLoadingMore
        : false;
    if (!hasMore || isLoadingMore) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _bloc.add(LoadMoreMaintenanceRequestsEvent(user.email!));
    }
  }

  void _tryLoadMoreIfNeeded() => _onScroll();

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopMaintenanceStreamEvent());
    _searchController.dispose();
    super.dispose();
  }

  List<MaintenanceRequestEntity> _filterRequests(
    List<MaintenanceRequestEntity> requests,
  ) {
    var filtered = requests;

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((req) {
        return req.title.toLowerCase().contains(query) ||
            req.description.toLowerCase().contains(query) ||
            (req.equipmentName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // تطبيق فلتر الحالة
    if (_selectedStatusFilter != null && _selectedStatusFilter != 'all') {
      filtered = filtered
          .where((req) => req.status == _selectedStatusFilter)
          .toList();
    }

    // تطبيق فلتر الأولوية
    if (_selectedPriorityFilter != null && _selectedPriorityFilter != 'all') {
      filtered = filtered
          .where((req) => req.priority == _selectedPriorityFilter)
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const MaintenanceDrawer(currentRoute: 'maintenance'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'maintenance_list_create_fab',
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  AppRoutes.createMaintenanceRequest,
                );
                if (result == true) forceRefresh();
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<MaintenanceBloc, MaintenanceState>(
        listener: (context, state) {
          if (_waitingForInitialStatusFilter &&
              (state is MaintenanceLoaded ||
                  state is MaintenanceStreamActive)) {
            _waitingForInitialStatusFilter = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
          if (state is MaintenanceOperationSuccess) {
            forceRefresh();
          }
          if (state is MaintenanceLoaded) {
            _notifyMaintenanceIfNeeded(
              state.requests.cast<MaintenanceRequestEntity>(),
            );
            if (state.hasMoreData && !state.isLoadingMore) {
              _tryLoadMoreIfNeeded();
            }
          }
          if (state is MaintenanceStreamActive) {
            _notifyMaintenanceIfNeeded(
              state.requests.cast<MaintenanceRequestEntity>(),
            );
            if (state.hasMoreData && !state.isLoadingMore) {
              _tryLoadMoreIfNeeded();
            }
          }
          if (state is MaintenanceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            // ⚠️ ملاحظة للمبرمجين المستقبليين: تم إزالة استدعاء
            // _loadMaintenanceRequests() هنا لتجنب حلقة إعادة تحميل
            // غير ضرورية أو طلبات شبكة مكررة عند حدوث خطأ. يمكن للمستخدم
            // الضغط على زر التحديث يدوياً إذا أراد إعادة المحاولة.
          } else if (state is MaintenanceOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            // تحديث القائمة عند نجاح أي عملية تمت عبر نافذة تفاصيل أو نموذج.
          }
        },
        builder: (context, state) {
          var allRequests = <MaintenanceRequestEntity>[];

          if (state is MaintenanceLoaded) {
            allRequests = state.requests.cast<MaintenanceRequestEntity>();
          } else if (state is MaintenanceStreamActive) {
            allRequests = state.requests.cast<MaintenanceRequestEntity>();
          }

          final filteredRequests = _filterRequests(allRequests);

          if (state is MaintenanceInitial || state is MaintenanceLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل طلبات الصيانة...'),
                ),
              ],
            );
          }

          if (state is MaintenanceError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (filteredRequests.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.build_circle_outlined,
                    title: 'لا توجد طلبات صيانة',
                    message: 'ابدأ بإضافة طلب صيانة جديد',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: PaginatedListView<MaintenanceRequestEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredRequests,
                  hasMore: state is MaintenanceLoaded
                      ? state.hasMoreData
                      : state is MaintenanceStreamActive
                      ? state.hasMoreData
                      : false,
                  isLoadingMore: state is MaintenanceLoaded
                      ? state.isLoadingMore
                      : state is MaintenanceStreamActive
                      ? state.isLoadingMore
                      : false,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildMaintenanceCard(filteredRequests[index]),
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
                  'إدارة الصيانة',
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
              Navigator.of(context).pushNamed(AppRoutes.maintenanceReports);
            },
            icon: Icon(
              Icons.analytics,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'التقارير',
          ),
        IconButton(
          onPressed: _loadMaintenanceRequests,
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
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث عن طلب صيانة...',
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
                    color:
                        _isFilterExpanded ||
                            _selectedStatusFilter != null ||
                            _selectedPriorityFilter != null
                        ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color:
                          _isFilterExpanded ||
                              _selectedStatusFilter != null ||
                              _selectedPriorityFilter != null
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
                          color:
                              _isFilterExpanded ||
                                  _selectedStatusFilter != null ||
                                  _selectedPriorityFilter != null
                              ? AssyrianTheme.primaryGold
                              : Colors.grey[600],
                          size: 24.sp,
                        ),
                        if (_selectedStatusFilter != null ||
                            _selectedPriorityFilter != null)
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // فلاتر الحالة
          Text(
            'حالة الطلب:',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 4.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildStatusChip('الكل', 'all'),
              _buildStatusChip('قيد الانتظار', 'pending'),
              _buildStatusChip('قيد التنفيذ', 'in_progress'),
              _buildStatusChip('مكتمل', 'completed'),
              _buildStatusChip('ملغي', 'cancelled'),
            ],
          ),
          SizedBox(height: 16.h),
          // فلاتر الأولوية
          Text(
            'مستوى الأولوية:',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 4.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildPriorityChip('الكل', 'all'),
              _buildPriorityChip('منخفضة', 'low'),
              _buildPriorityChip('متوسطة', 'medium'),
              _buildPriorityChip('عالية', 'high'),
              _buildPriorityChip('عاجلة', 'urgent'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatusFilter = selected ? value : null;
          if (value == 'all') _selectedStatusFilter = null;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.deepBlue,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12.sp,
      ),
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildPriorityChip(String label, String value) {
    final isSelected = _selectedPriorityFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPriorityFilter = selected ? value : null;
          if (value == 'all') _selectedPriorityFilter = null;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.deepBlue,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12.sp,
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
            onPressed: _loadMaintenanceRequests,
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

  Widget _buildMaintenanceCard(MaintenanceRequestEntity request) {
    final statusColor = _getStatusColor(request.status);
    final statusText = _getStatusText(request.status);
    final priorityColor = _getPriorityColor(request.priority);
    final priorityText = _getPriorityText(request.priority);

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
          Navigator.pushNamed(
            context,
            AppRoutes.maintenanceDetails,
            arguments: request,
          );
        },
        leading: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 100.w),
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.pushNamed(
                context,
                AppRoutes.editMaintenanceRequest,
                arguments: request,
              );
            } else if (value == 'delete') {
              _showDeleteDialog(request);
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
            backgroundColor: priorityColor.withValues(alpha: 0.1),
            radius: 22.r,
            child: Icon(Icons.build_circle, color: priorityColor, size: 20.sp),
          ),
        ),
        title: Text(
          request.title,
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
              request.description,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                if (request.equipmentName != null) ...[
                  Icon(Icons.devices, size: 10.sp, color: Colors.grey[500]),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      request.equipmentName!,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    priorityText,
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: priorityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.calendar_today,
                  size: 10.sp,
                  color: Colors.grey[500],
                ),
                SizedBox(width: 3.w),
                Text(
                  DateFormat('yyyy/MM/dd').format(request.requestDate),
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'urgent':
        return 'عاجل';
      case 'high':
        return 'عالية';
      case 'medium':
        return 'متوسطة';
      case 'low':
        return 'منخفضة';
      default:
        return priority;
    }
  }

  /// إرسال إشعار صيانة معGuard زمني لمنع التكرار المتكرر
  void _notifyMaintenanceIfNeeded(List<MaintenanceRequestEntity> requests) {
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!).inSeconds < 30) {
      return; // تجنب الإشعارات المكررة خلال 30 ثانية
    }
    _lastNotificationTime = now;
    // فحص جميع طلبات الصيانة من السيرفر، وليس فقط المعروضة على الشاشة
    _checkAllMaintenanceNotifications();
  }

  /// ✅ التحقق من تنبيهات جميع طلبات الصيانة من السيرفر (بدون حد)
  Future<void> _checkAllMaintenanceNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      try {
        final repo = GetIt.instance<MaintenanceRepository>();
        final result = await repo.getMaintenanceRequests(
          normalizedEmail,
          limit: null, // جلب جميع طلبات الصيانة من السيرفر للتنبيهات
        );
        result.fold((failure) {}, (allRequests) {
          SectionNotificationService.checkAndNotifyMaintenance(allRequests);
        });
      } on Exception catch (_) {
        // تجاهل الأخطاء في فحص التنبيهات
      }
    }
  }

  void _showDeleteDialog(MaintenanceRequestEntity request) {
    DeleteMaintenanceDialog.show(
      context,
      request,
      context.read<MaintenanceBloc>(),
      onDeleted: _loadMaintenanceRequests,
    );
  }
}
