import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/customer_log_entity.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_drawer.dart';
import '../widgets/customer_log_card.dart';

/// صفحة عرض سجل نشاطات العملاء
class CustomersLogPage extends StatefulWidget {
  const CustomersLogPage({super.key});

  @override
  State<CustomersLogPage> createState() => _CustomersLogPageState();
}

class _CustomersLogPageState extends State<CustomersLogPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canViewLogs = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _selectedDateFilter = 'all';
  bool _isFilterExpanded = false;
  DateTime? _startDate;
  DateTime? _endDate;
  late CustomerBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<CustomerBloc>();
    _loadPermissions();
    _loadCustomerLogs();
  }

  Future<void> _loadPermissions() async {
    final canViewLogs = await _permissionChecker.hasPermission('customers_logs_view');
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

  void forceRefresh() {
    _loadCustomerLogs();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _loadCustomerLogs();
  }

  void _loadCustomerLogs() {
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا ستريم بدلاً من التحميل مرة واحدة؟
    // سجلات النشاط تُضاف عند كل عملية على العملاء
    // أو المجموعات، لذلك نستمع لتغيراتها فورياً.
    // عند تغيير أي فلتر نعيد تشغيل الاشتراك بفلاتر
    // جديدة (نفس فلاتر getCustomerLogs).
    // ==========================================
    final user = FirebaseAuth.instance.currentUser;
    final organizationEmail = user?.email;

    if (organizationEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _bloc.add(
      StartCustomerLogsStreamEvent(
        organizationEmail: organizationEmail,
        searchQuery: _searchController.text,
        actionFilter: _selectedFilter,
        dateFilter: _selectedDateFilter,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const CustomerDrawer(currentRoute: '/customers/log'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<CustomerBloc, CustomerState>(
        listener: (context, state) {
          if (state is CustomerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CustomerLoading) {
            return const LoadingWidget();
          }

          if (state is CustomerError) {
            return _buildErrorState(state.message);
          }

          if (state is CustomerLogsLoaded) {
            return _buildLogsList(state.logs);
          }

          return AppEmptyState(
            icon: Icons.people_outline,
            title: 'لا يوجد سجل عملاء',
            message: 'سيظهر هنا سجل جميع نشاطات العملاء',
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
                  'سجل نشاطات العملاء',
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
                  'تتبع جميع عمليات العملاء',
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
          onPressed: _loadCustomerLogs,
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

  Widget _buildLogsList(List<CustomerLogEntity> logs) {
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
                    return CustomerLogCard(
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
                                _loadCustomerLogs();
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
                      _loadCustomerLogs();
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
                    _loadCustomerLogs();
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

          // فلتر نوع العملية
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
                  _loadCustomerLogs();
                },
              ),
              _buildFilterChip(
                label: 'إنشاء',
                value: 'create',
                isSelected: _selectedFilter == 'create',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'create';
                  });
                  _loadCustomerLogs();
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
                  _loadCustomerLogs();
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
                  _loadCustomerLogs();
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
                  _loadCustomerLogs();
                },
                icon: Icons.visibility,
                color: Colors.purple,
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // فلتر التاريخ
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
                  _loadCustomerLogs();
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
                  _loadCustomerLogs();
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
                  _loadCustomerLogs();
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
                  _loadCustomerLogs();
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
              _loadCustomerLogs();
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
            onPressed: _loadCustomerLogs,
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

  void _showLogDetails(CustomerLogEntity log) {
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
            _buildDetailRow('الهدف:', log.targetId ?? 'غير محدد'),
            _buildDetailRow('نوع العملية:', _getActionTypeText(log.actionType)),
            _buildDetailRow('التاريخ:', _formatDateTime(log.timestamp)),
            if (log.details != null && log.details!.isNotEmpty)
              _buildDetailRow('التفاصيل:', log.details!),
            _buildDetailRow('الحالة:', log.isSuccess ? 'نجح' : 'فشل'),
            _buildDetailRow('المستخدم:', log.userId),
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
      case 'create':
        return 'إنشاء عميل';
      case 'update':
        return 'تحديث عميل';
      case 'delete':
        return 'حذف عميل';
      case 'view':
        return 'عرض عميل';
      case 'contact':
        return 'تواصل مع عميل';
      case 'transaction':
        return 'معاملة مالية';
      default:
        return actionType;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final picked = await showDateRangePicker(
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
      _loadCustomerLogs();
    }
  }

  @override
  void dispose() {
    _bloc.add(const StopCustomerLogsStreamEvent());
    _searchController.dispose();
    super.dispose();
  }
}
