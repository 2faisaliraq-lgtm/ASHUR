import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/expense_log_entity.dart';
import '../bloc/expense_bloc.dart';
import '../widgets/expense_drawer.dart';
import '../widgets/expense_log_card.dart';

/// صفحة عرض سجل نشاطات المصروفات
class ExpensesLogPage extends StatefulWidget {
  const ExpensesLogPage({super.key});

  @override
  State<ExpensesLogPage> createState() => _ExpensesLogPageState();
}

class _ExpensesLogPageState extends State<ExpensesLogPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canViewLogs = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _selectedDateFilter = 'all';
  bool _isFilterExpanded = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    // ✅ ملاحظة للمبرمجين المستقبليين:
    // السجل الآن ستريم حي (StartExpenseLogsStreamEvent)
    // يُحدَّث تلقائياً مع كل عملية مصروف جديدة،
    // فلا حاجة لإعادة التحميل عند العودة للصفحة
    // (كان يُعاد التحميل في didChangeDependencies
    // قبل تحويله إلى ستريم).
    _loadExpenseLogs();
  }

  Future<void> _loadPermissions() async {
    // الصلاحية المتاحة في ExpensesPermissions هي 'expenses_view' (لا توجد 'expenses_view_logs').
    final canViewLogs = await _permissionChecker.hasPermission('expenses_view');
    if (mounted) {
      setState(() {
        _canViewLogs = canViewLogs;
      });
    }
  }

  void forceRefresh() {
    _loadExpenseLogs();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _loadExpenseLogs();
  }

  void _loadExpenseLogs() {
    context.read<ExpenseBloc>().add(
      StartExpenseLogsStreamEvent(
        searchQuery: _searchController.text,
        actionFilter: _selectedFilter,
        dateFilter: _selectedDateFilter,
        startDate: _startDate,
        endDate: _endDate,
        limit: 100,
      ),
    );
  }

  @override
  void dispose() {
    // إيقاف ستريم السجل عند إغلاق الصفحة
    context.read<ExpenseBloc>().add(const StopExpenseLogsStreamEvent());
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: BlocProvider.value(
        value: context.read<ExpenseBloc>(),
        child: const ExpenseDrawer(currentRoute: '/expenses/log'),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state is ExpenseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ExpenseLoading) {
            return const LoadingWidget();
          }

          if (state is ExpenseError) {
            return _buildErrorState(state.message);
          }

          if (state is ExpenseLogsLoaded) {
            return _buildLogsList(state.logs);
          }

          return AppEmptyState(
            icon: Icons.receipt_long,
            title: 'لا يوجد سجل مصروفات',
            message: 'سيظهر هنا سجل جميع عمليات المصروفات والنفقات',
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
                  'سجل نشاطات المصروفات',
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
                  'تتبع جميع عمليات المصروفات والنفقات',
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
          onPressed: _loadExpenseLogs,
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

  Widget _buildLogsList(List<ExpenseLogEntity> logs) {
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
                    return ExpenseLogCard(
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
                                _loadExpenseLogs();
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
                      _loadExpenseLogs();
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
                    _loadExpenseLogs();
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
                  _loadExpenseLogs();
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
                  _loadExpenseLogs();
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
                  _loadExpenseLogs();
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
                  _loadExpenseLogs();
                },
                icon: Icons.delete,
                color: Colors.red,
              ),
              _buildFilterChip(
                label: 'موافقة',
                value: 'approve',
                isSelected: _selectedFilter == 'approve',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'approve';
                  });
                  _loadExpenseLogs();
                },
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _buildFilterChip(
                label: 'رفض',
                value: 'reject',
                isSelected: _selectedFilter == 'reject',
                onSelected: () {
                  setState(() {
                    _selectedFilter = 'reject';
                  });
                  _loadExpenseLogs();
                },
                icon: Icons.cancel,
                color: Colors.orange,
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
                  _loadExpenseLogs();
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
                  _loadExpenseLogs();
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
                  _loadExpenseLogs();
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
                  _loadExpenseLogs();
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
            'لم يتم العثور على مصروفات تطابق البحث أو الفلتر المحدد',
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
              _loadExpenseLogs();
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
            onPressed: _loadExpenseLogs,
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

  void _showLogDetails(ExpenseLogEntity log) {
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
            _buildDetailRow('نوع العملية:', _getActionTypeText(log.actionType)),
            _buildDetailRow('التاريخ:', _formatDateTime(log.timestamp)),
            if (log.targetType != null)
              _buildDetailRow(
                'نوع الهدف:',
                _getTargetTypeText(log.targetType!),
              ),
            if (log.targetId != null)
              _buildDetailRow('معرف الهدف:', log.targetId!),
            if (log.details != null && log.details!.isNotEmpty)
              _buildDetailRow('التفاصيل:', log.details!),
            _buildDetailRow('الحالة:', log.isSuccess ? 'نجح' : 'فشل'),
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
        return 'إنشاء';
      case 'update':
        return 'تحديث';
      case 'delete':
        return 'حذف';
      case 'view':
        return 'عرض';
      case 'approve':
        return 'موافقة';
      case 'reject':
        return 'رفض';
      case 'pay':
        return 'دفع';
      case 'refund':
        return 'استرداد';
      default:
        return actionType;
    }
  }

  String _getTargetTypeText(String targetType) {
    switch (targetType) {
      case 'expense':
        return 'مصروف';
      case 'category':
        return 'فئة';
      case 'receipt':
        return 'إيصال';
      case 'approval':
        return 'موافقة';
      default:
        return targetType;
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
      _loadExpenseLogs();
    }
  }
}
