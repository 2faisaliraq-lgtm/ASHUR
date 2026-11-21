import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/report_entity.dart';
import '../bloc/report_bloc.dart';
import '../widgets/delete_report_dialog.dart';
import '../widgets/report_drawer.dart';

/// صفحة عرض جميع التقارير
class ReportsListPage extends StatefulWidget {
  const ReportsListPage({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  State<ReportsListPage> createState() => _ReportsListPageState();
}

class _ReportsListPageState extends State<ReportsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canViewReports = false;
  bool _isLoadingPermissions = true;
  bool _waitingForInitialFilterData = false;
  late ReportBloc _bloc; // حفظ reference للـ bloc
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
      _waitingForInitialFilterData = true;
    }
    // حفظ reference للـ bloc
    _bloc = context.read<ReportBloc>();
    if (_waitingForInitialFilterData) {
      _bloc.add(FilterReportsEvent(_selectedFilter));
    }
    _startRealTimeUpdates();
    _loadPermissions();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission('reports_create');
    final canEdit = await _permissionChecker.hasPermission('reports_edit');
    final canDelete = await _permissionChecker.hasPermission('reports_delete');
    final canViewReports = await _permissionChecker.hasPermission(
      'reports_view',
    );

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
        _canViewReports = canViewReports;
        _isLoadingPermissions = false;
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
      // بدء الاستماع للتقارير مع التحديث الفوري.
      context.read<ReportBloc>().add(
        StartReportsStreamEvent(organizationEmail: normalizedEmail),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final organizationEmail = EmailNormalizationService().normalize(
      user.email!,
    );
    if (state is ReportLoaded &&
        state.hasMoreReportsData &&
        !state.isLoadingMoreReports) {
      _bloc.add(LoadMoreReportsEvent(organizationEmail));
    }
  }

  void forceRefresh() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final normalizedEmail = EmailNormalizationService().normalize(user.email!);
    _bloc.add(LoadReportsEvent(normalizedEmail));
    _startRealTimeUpdates();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _startRealTimeUpdates();
  }

  void _loadReports() {
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopReportsStreamEvent());
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ⚠️ التصفية تُطبق في BLoC عبر _applyFilters المشتركة.
  // هذه الصفحة تعتمد على filteredReports من حالة BLoC مباشرة لتجنب التصفية المزدوجة.
  // البحث والفلترة محليًا في الصفحة للصفحة العادية (ReportLoaded)، بينما BLoC
  // يُطبق التصفية على بيانات الستريم (ReportsStreamActive).
  // يُنصح بتوحيد التصفية في مكان واحد في المستقبل.
  List<ReportEntity> _filterReports(List<ReportEntity> reports) {
    var filtered = reports;

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((report) {
        return report.title.toLowerCase().contains(query) ||
            report.description.toLowerCase().contains(query);
      }).toList();
    }

    // تطبيق الفلتر
    if (_selectedFilter == 'this_month') {
      final now = DateTime.now();
      filtered = filtered
          .where(
            (report) =>
                report.createdAt.year == now.year &&
                report.createdAt.month == now.month,
          )
          .toList();
    } else if (_selectedFilter == 'pending' ||
        _selectedFilter == 'completed' ||
        _selectedFilter == 'failed') {
      filtered = filtered
          .where((report) => report.status.toLowerCase() == _selectedFilter)
          .toList();
    } else if (_selectedFilter != 'all') {
      filtered = filtered
          .where((report) => report.type == _selectedFilter)
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // التحقق من صلاحية عرض التقارير
    if (_isLoadingPermissions) {
      return scaffold.ResponsiveScaffold(
        appBar: AppBar(),
        body: LoadingWidget(message: 'جاري تحميل...'),
      );
    }

    if (!_canViewReports) {
      // عرض شاشة طلب رمز الوصول
      return scaffold.ResponsiveScaffold(
        appBar: AppBar(title: const Text('التقارير')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80.sp, color: Colors.grey[400]),
              SizedBox(height: 16.h),
              Text(
                'ليس لديك صلاحية عرض التقارير',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'يرجى التواصل مع المسؤول للحصول على الصلاحية',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const ReportDrawer(currentRoute: 'reports'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'reports_list_create_fab',
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  AppRoutes.createReport,
                );
                if (result == true || result is ReportEntity) {
                  forceRefresh();
                }
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<ReportBloc, ReportState>(
        listener: (context, state) {
          if (_waitingForInitialFilterData &&
              (state is ReportLoaded || state is ReportsStreamActive)) {
            _waitingForInitialFilterData = false;
            _bloc.add(FilterReportsEvent(_selectedFilter));
          }
          if (state is ReportOperationSuccess) {
            forceRefresh();
          }
          if (state is ReportError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            // ⚠️ تم إزالة استدعاء _loadReports() التلقائي عند الخطأ
            // لمنع حلقة لانهائية (خطأ → إعادة تحميل → خطأ → ...).
            // يُترك زر "إعادة المحاولة" في واجهة الخطأ للمستخدم ليقرر متى يعيد المحاولة.
          }
        },
        builder: (context, state) {
          var allReports = <ReportEntity>[];

          if (state is ReportLoaded) {
            allReports = state.filteredReports.cast<ReportEntity>();
          } else if (state is ReportsStreamActive) {
            allReports = state.filteredReports.cast<ReportEntity>();
          }

          final filteredReports = _filterReports(allReports);

          if (state is ReportInitial || state is ReportLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل التقارير...'),
                ),
              ],
            );
          }

          if (state is ReportError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (filteredReports.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.analytics_outlined,
                    title: 'لا توجد تقارير',
                    message: 'ابدأ بإنشاء تقرير جديد',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: PaginatedListView<ReportEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredReports,
                  hasMore: state is ReportLoaded
                      ? state.hasMoreReportsData
                      : state is ReportsStreamActive
                      ? state.hasMoreReportsData
                      : false,
                  isLoadingMore: state is ReportLoaded
                      ? state.isLoadingMoreReports
                      : state is ReportsStreamActive
                      ? state.isLoadingMoreReports
                      : false,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildReportCard(filteredReports[index]),
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
                  'إدارة التقارير',
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
        IconButton(
          onPressed: _loadReports,
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
                      // ⚠️ البحث يُطبَّق محلياً في _filterReports
                      // من الذاكرة — إعادة بناء فقط بدون
                      // إعادة جلب الستريم عند كل حرف
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث عن تقرير...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AssyrianTheme.primaryGold,
                        size: 24.sp,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                // إعادة البناء لعرض كل
                                // التقارير بعد المسح
                                setState(() {});
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حسب الحالة:',
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
              _buildFilterChip('الكل', 'all'),
              _buildFilterChip('قيد الإنشاء', 'pending'),
              _buildFilterChip('مكتمل', 'completed'),
              _buildFilterChip('فشل', 'failed'),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'حسب النوع:',
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
              _buildFilterChip('مالي', 'financial'),
              _buildFilterChip('مخزون', 'inventory'),
              _buildFilterChip('مبيعات', 'sales'),
              _buildFilterChip('مصاريف', 'expenses'),
              _buildFilterChip('مخصص', 'custom'),
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
        _bloc.add(FilterReportsEvent(value));
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
            onPressed: _loadReports,
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

  Widget _buildReportCard(ReportEntity report) {
    final statusColor = _getStatusColor(report.status);
    final statusText = _getStatusText(report.status);
    final typeText = _getTypeText(report.type);

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
          onTap: () async {
            final result = await Navigator.of(
              context,
            ).pushNamed(AppRoutes.reportDetails, arguments: report);
            if (result == true || result is ReportEntity) forceRefresh();
          },
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.1),
            radius: 25.r,
            child: Icon(Icons.analytics, color: statusColor, size: 24.sp),
          ),
          title: Text(
            report.title,
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
              SizedBox(height: 4.h),
              Text(
                report.description,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Icon(Icons.category, size: 11.sp, color: Colors.grey[500]),
                  SizedBox(width: 4.w),
                  Text(
                    typeText,
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.calendar_today,
                    size: 11.sp,
                    color: Colors.grey[500],
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    DateFormat('yyyy/MM/dd').format(report.createdAt),
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'view') {
                    // ⚠️ Placeholder: وظيفة عرض التقرير غير مطبقة — لا يحدث شيء عند اختيار "عرض".
                    // يجب تنفيذ التنقل إلى ReportDetailsPage أو عرض تفاصيل التقرير هنا.
                  } else if (value == 'download') {
                    // ⚠️ Placeholder: وظيفة تحميل التقرير غير مطبقة — لا يحدث شيء عند اختيار "تحميل".
                    // يجب تنفيذ منطق التصدير والتنزيل هنا (يحتاج صلاحية reports_download).
                  } else if (value == 'delete') {
                    _showDeleteDialog(report);
                  }
                },
                itemBuilder: (context) => [
                  if (_canEdit)
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 18.sp,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 8.w),
                          const Text('عرض'),
                        ],
                      ),
                    ),
                  if (_canEdit)
                    PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(
                            Icons.download,
                            size: 18.sp,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8.w),
                          const Text('تحميل'),
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
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'مكتمل';
      case 'pending':
        return 'قيد الإنشاء';
      case 'failed':
        return 'فشل';
      default:
        return status;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'financial':
        return 'تقرير مالي';
      case 'inventory':
        return 'تقرير مخزون';
      case 'sales':
        return 'تقرير مبيعات';
      case 'expenses':
        return 'تقرير مصاريف';
      case 'custom':
        return 'تقرير مخصص';
      default:
        return type;
    }
  }

  void _showDeleteDialog(ReportEntity report) {
    DeleteReportDialog.show(
      context,
      report,
      context.read<ReportBloc>(),
      onDeleted: _loadReports,
    );
  }
}
