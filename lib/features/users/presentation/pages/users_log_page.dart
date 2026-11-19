import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/user_log_entity.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/user_log_card.dart';
import '../widgets/users_drawer.dart';

/// صفحة عرض سجل نشاطات المستخدمين
class UsersLogPage extends StatefulWidget {
  const UsersLogPage({super.key});

  @override
  State<UsersLogPage> createState() => _UsersLogPageState();
}

class _UsersLogPageState extends State<UsersLogPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canViewLogs = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _selectedDateFilter = 'all';
  bool _isFilterExpanded = false;
  DateTime? _startDate;
  DateTime? _endDate;
  Timer? _searchDebounce; // مؤقت تأخير للبحث لتجنب استدعاء Firestore عند كل ضغطة مفتاح

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadUserLogs();
  }

  Future<void> _loadPermissions() async {
    final canViewLogs = await _permissionChecker.hasPermission('users_logs_view'); // ✅ تم التصحيح: معرف الصلاحية في users_permissions.dart هو 'users_logs_view' وليس 'users_view_logs'
    if (mounted) {
      setState(() {
        _canViewLogs = canViewLogs;
      });
    }
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

  void _loadUserLogs() {
    context.read<UsersBloc>().add(
      LoadUserLogsEvent(
        searchQuery: _searchController.text,
        actionFilter: _selectedFilter,
        dateFilter: _selectedDateFilter,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const UsersDrawer(currentRoute: AppRoutes.usersLog),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<UsersBloc, UsersState>(
        listener: (context, state) {
          if (state is UsersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is UsersLoading) {
            return const LoadingWidget();
          }

          if (state is UsersError) {
            return _buildErrorState(state.message);
          }

          if (state is UserLogsLoaded) {
            return _buildLogsList(state.logs);
          }

          return AppEmptyState(
            icon: Icons.history,
            title: 'لا يوجد سجل نشاطات',
            message: 'سيظهر هنا سجل جميع نشاطات المستخدمين',
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
                  'سجل نشاطات المستخدمين',
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
                  'تتبع جميع العمليات والأنشطة',
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 12,
                    ),
                    color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.8),
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
          onPressed: _loadUserLogs,
          icon: Icon(
            Icons.refresh,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          tooltip: 'تحديث',
        ),
        if (_canViewLogs)
          IconButton(
            onPressed: () => _showDateRangePicker(context),
            icon: Icon(
              Icons.date_range,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تحديد فترة زمنية',
          ),
      ],
    );
  }

  Widget _buildLogsList(List<UserLogEntity> logs) {
    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(
          child: logs.isEmpty
              ? _buildEmptyFilteredState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return UserLogCard(
                      log: logs[index],
                      onTap: () => _showLogDetails(logs[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        gradient: AssyrianTheme.cardGradient,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: AssyrianTheme.assyrianShadow,
      ),
      child: Column(
        children: [
          // شريط البحث مع زر الفلتر
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                // حقل البحث
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'البحث في السجل...',
                      hintStyle: TextStyle(
                        color: AssyrianTheme.deepBlue.withValues(alpha: 0.6),
                        fontSize: 14.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AssyrianTheme.deepBlue,
                        size: 20.sp,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _loadUserLogs();
                              },
                              icon: Icon(
                                Icons.clear,
                                color: AssyrianTheme.deepBlue,
                                size: 20.sp,
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: const BorderSide(
                          color: AssyrianTheme.primaryGold,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: const BorderSide(
                          color: AssyrianTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                        if (!mounted) return;
                        _loadUserLogs();
                      });
                    },
                  ),
                ),

                SizedBox(width: 12.w),

                // زر الفلتر
                _buildFilterButton(),
              ],
            ),
          ),

          // الفلاتر الموسعة
          if (_isFilterExpanded) ...[
            Divider(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              height: 1,
            ),
            _buildExpandedFilters(),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    final hasActiveFilters =
        _selectedFilter != 'all' || _selectedDateFilter != 'all';

    return InkWell(
      onTap: () {
        setState(() {
          _isFilterExpanded = !_isFilterExpanded;
        });
      },
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: _isFilterExpanded
              ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list,
              color: AssyrianTheme.primaryGold,
              size: 20.sp,
            ),
            if (hasActiveFilters) ...[
              SizedBox(width: 4.w),
              Container(
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFilters() {
    final hasActiveFilters =
        _selectedFilter != 'all' || _selectedDateFilter != 'all';

    return Padding(
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان الفلاتر مع زر المسح
          Row(
            children: [
              Text(
                'الفلاتر',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
              const Spacer(),
              if (hasActiveFilters)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'all';
                      _selectedDateFilter = 'all';
                      _startDate = null;
                      _endDate = null;
                      _searchController.clear();
                    });
                    _loadUserLogs();
                  },
                  borderRadius: BorderRadius.circular(6.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear, color: Colors.red, size: 14.sp),
                        SizedBox(width: 4.w),
                        Text(
                          'مسح الفلاتر',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 12.h),

          // فلاتر نوع العملية
          Text(
            'نوع العملية:',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildFilterChip(
                label: 'الكل',
                value: 'all',
                isSelected: _selectedFilter == 'all',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'all';
                  });
                  _loadUserLogs();
                },
              ),
              _buildFilterChip(
                label: 'تسجيل دخول',
                value: 'login',
                isSelected: _selectedFilter == 'login',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'login';
                  });
                  _loadUserLogs();
                },
                icon: Icons.login,
                color: Colors.green,
              ),
              _buildFilterChip(
                label: 'تسجيل خروج',
                value: 'logout',
                isSelected: _selectedFilter == 'logout',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'logout';
                  });
                  _loadUserLogs();
                },
                icon: Icons.logout,
                color: Colors.orange,
              ),
              _buildFilterChip(
                label: 'إنشاء',
                value: 'create',
                isSelected: _selectedFilter == 'create',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'create';
                  });
                  _loadUserLogs();
                },
                icon: Icons.add_circle,
                color: Colors.blue,
              ),
              _buildFilterChip(
                label: 'تحديث',
                value: 'update',
                isSelected: _selectedFilter == 'update',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'update';
                  });
                  _loadUserLogs();
                },
                icon: Icons.edit,
                color: AssyrianTheme.primaryGold,
              ),
              _buildFilterChip(
                label: 'حذف',
                value: 'delete',
                isSelected: _selectedFilter == 'delete',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'delete';
                  });
                  _loadUserLogs();
                },
                icon: Icons.delete,
                color: Colors.red,
              ),
              _buildFilterChip(
                label: 'عرض',
                value: 'view',
                isSelected: _selectedFilter == 'view',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'view';
                  });
                  _loadUserLogs();
                },
                icon: Icons.visibility,
                color: Colors.purple,
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // فلاتر التاريخ
          Text(
            'الفترة الزمنية:',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildFilterChip(
                label: 'الكل',
                value: 'all',
                isSelected: _selectedDateFilter == 'all',
                onSelected: () {
                  setState(() {
                    _selectedDateFilter = 'all';
                  });
                  _loadUserLogs();
                },
              ),
              _buildFilterChip(
                label: 'اليوم',
                value: 'today',
                isSelected: _selectedDateFilter == 'today',
                onSelected: () {
                  setState(() {
                    _selectedDateFilter = 'today';
                  });
                  _loadUserLogs();
                },
                icon: Icons.today,
              ),
              _buildFilterChip(
                label: 'هذا الأسبوع',
                value: 'week',
                isSelected: _selectedDateFilter == 'week',
                onSelected: () {
                  setState(() {
                    _selectedDateFilter = 'week';
                  });
                  _loadUserLogs();
                },
                icon: Icons.date_range,
              ),
              _buildFilterChip(
                label: 'هذا الشهر',
                value: 'month',
                isSelected: _selectedDateFilter == 'month',
                onSelected: () {
                  setState(() {
                    _selectedDateFilter = 'month';
                  });
                  _loadUserLogs();
                },
                icon: Icons.calendar_month,
              ),
              _buildFilterChip(
                label: 'فترة مخصصة',
                value: 'custom',
                isSelected: _selectedDateFilter == 'custom',
                onSelected: () {
                  setState(() {
                    _selectedDateFilter = 'custom';
                  });
                  _showDateRangePicker(context);
                },
                icon: Icons.calendar_today,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onSelected,
    IconData? icon,
    Color? color,
  }) {
    final chipColor = color ?? AssyrianTheme.primaryGold;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? chipColor : chipColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected
                    ? chipColor
                    : chipColor.withValues(alpha: 0.7),
                size: 16.sp,
              ),
              SizedBox(width: 4.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? chipColor
                    : chipColor.withValues(alpha: 0.7),
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 80.sp,
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد نتائج',
            style: AssyrianTheme.titleStyle.copyWith(
              fontSize: 18.sp,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'لم يتم العثور على نشاطات تطابق البحث أو الفلتر المحدد',
            style: AssyrianTheme.subtitleStyle.copyWith(
              fontSize: 14.sp,
              color: AssyrianTheme.deepBlue.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedFilter = 'all';
                _selectedDateFilter = 'all';
                _startDate = null;
                _endDate = null;
                _searchController.clear();
              });
              _loadUserLogs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
            ),
            child: const Text('مسح الفلاتر'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80.sp,
            color: Colors.red.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: AssyrianTheme.titleStyle.copyWith(
              fontSize: 18.sp,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: AssyrianTheme.subtitleStyle.copyWith(
              fontSize: 14.sp,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadUserLogs,
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

  void _showLogDetails(UserLogEntity log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تفاصيل النشاط',
          style: AssyrianTheme.titleStyle.copyWith(
            color: AssyrianTheme.deepBlue,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('المستخدم:', log.userName ?? 'غير محدد'),
            _buildDetailRow('البريد الإلكتروني:', log.userEmail ?? 'غير محدد'),
            _buildDetailRow('نوع العملية:', _getActionTypeText(log.actionType)),
            _buildDetailRow('التاريخ:', _formatDateTime(log.timestamp)),
            if (log.details != null && log.details!.isNotEmpty)
              _buildDetailRow('التفاصيل:', log.details!),
            _buildDetailRow('الحالة:', log.isSuccess ? 'نجح' : 'فشل'),
            if (log.ipAddress != null)
              _buildDetailRow('عنوان IP:', log.ipAddress!),
            if (log.userAgent != null)
              _buildDetailRow('المتصفح:', log.userAgent!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
                color: AssyrianTheme.deepBlue,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: AssyrianTheme.deepBlue.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActionTypeText(String actionType) {
    switch (actionType) {
      case 'login':
        return 'تسجيل دخول';
      case 'logout':
        return 'تسجيل خروج';
      case 'create':
        return 'إنشاء';
      case 'update':
        return 'تحديث';
      case 'delete':
        return 'حذف';
      case 'view':
        return 'عرض';
      default:
        return actionType;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    var picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AssyrianTheme.primaryGold,
              onPrimary: AssyrianTheme.deepBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedDateFilter = 'custom';
      });
      _loadUserLogs();
    }
  }
}
