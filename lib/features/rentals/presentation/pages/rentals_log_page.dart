import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/rental_log_entity.dart';
import '../bloc/rental_bloc.dart';
import '../widgets/rental_log_card.dart';
import '../widgets/rental_log_filter_chips.dart';

/// صفحة عرض سجل نشاطات الإيجارات
class RentalsLogPage extends StatefulWidget {
  const RentalsLogPage({super.key});

  @override
  State<RentalsLogPage> createState() => _RentalsLogPageState();
}

class _RentalsLogPageState extends State<RentalsLogPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canViewLogs = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _selectedDateFilter = 'all';
  bool _isFilterExpanded = false;
  DateTime? _startDate;
  DateTime? _endDate;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    // ✅ ملاحظة للمبرمجين المستقبليين:
    // السجل الآن ستريم حي (StartRentalLogsStreamEvent)
    // يُحدَّث تلقائياً مع كل عملية إيجار جديدة،
    // فلا حاجة لإعادة التحميل عند العودة للصفحة
    // (كان يُعاد التحميل في didChangeDependencies
    // قبل تحويله إلى ستريم).
    _loadRentalLogs();
  }

  Future<void> _loadPermissions() async {
    // ملاحظة للمبرمجين المستقبليين: اسم الصلاحية معرف في RentalsPermissions بـ 'rentals_logs_view' (مع _logs_) وليس 'rentals_view_logs'. التصحيح ضروري حتى يعمل عرض السجل للمستخدمين المفوضين.
    final canViewLogs = await _permissionChecker.hasPermission('rentals_logs_view');
    if (mounted) {
      setState(() {
        _canViewLogs = canViewLogs;
      });
    }
  }

  void forceRefresh() {
    _loadRentalLogs();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _loadRentalLogs();
  }

  void _loadRentalLogs() {
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا ستريم بدلاً من التحميل مرة واحدة؟
    // سجلات النشاط تُضاف عند كل عملية إيجار،
    // لذلك نستمع لتغيراتها فورياً. عند تغيير
    // أي فلتر نعيد تشغيل الاشتراك بفلاتر جديدة
    // (نفس فلاتر getRentalLogs).
    // ==========================================
    context.read<RentalBloc>().add(
      StartRentalLogsStreamEvent(
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
    context.read<RentalBloc>().add(const StopRentalLogsStreamEvent());
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<RentalBloc, RentalState>(
        listener: (context, state) {
          if (state is RentalError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is RentalLoading) {
            return const LoadingWidget();
          }

          if (state is RentalError) {
            return _buildErrorState(state.message);
          }

          if (state is RentalLogsLoaded) {
            return _buildLogsList(state.logs);
          }

          return AppEmptyState(
            icon: Icons.home_work,
            title: 'لا يوجد سجل إيجارات',
            message: 'سيظهر هنا سجل جميع عمليات الإيجار والعقود',
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
                  'سجل نشاطات الإيجارات',
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
                  'تتبع جميع عمليات الإيجار والعقود',
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
          onPressed: _loadRentalLogs,
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

  Widget _buildLogsList(List<RentalLogEntity> logs) {
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
                    return RentalLogCard(
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
          // شريط البحث
          Padding(
            padding: EdgeInsets.all(12.w),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'البحث في سجل الإيجارات...',
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
                          _loadRentalLogs();
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
                  _loadRentalLogs();
                });
              },
            ),
          ),

          // أزرار الفلتر
          RentalLogFilterChips(
            selectedFilter: _selectedFilter,
            selectedDateFilter: _selectedDateFilter,
            isExpanded: _isFilterExpanded,
            onFilterChanged: (filter) {
              setState(() {
                _selectedFilter = filter;
              });
              _loadRentalLogs();
            },
            onDateFilterChanged: (dateFilter) {
              setState(() {
                _selectedDateFilter = dateFilter;
              });
              _loadRentalLogs();
            },
            onExpandToggle: () {
              setState(() {
                _isFilterExpanded = !_isFilterExpanded;
              });
            },
            onClearFilters: () {
              setState(() {
                _selectedFilter = 'all';
                _selectedDateFilter = 'all';
                _startDate = null;
                _endDate = null;
                _searchController.clear();
              });
              _loadRentalLogs();
            },
          ),
        ],
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
            'لم يتم العثور على إيجارات تطابق البحث أو الفلتر المحدد',
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
              _loadRentalLogs();
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
            onPressed: _loadRentalLogs,
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

  void _showLogDetails(RentalLogEntity log) {
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
      case 'rent':
        return 'تأجير';
      case 'return':
        return 'إرجاع';
      case 'extend':
        return 'تمديد';
      case 'cancel':
        return 'إلغاء';
      case 'payment':
        return 'دفع';
      default:
        return actionType;
    }
  }

  String _getTargetTypeText(String targetType) {
    switch (targetType) {
      case 'rental_contract':
        return 'عقد إيجار';
      case 'property':
        return 'عقار';
      case 'tenant':
        return 'مستأجر';
      case 'payment':
        return 'دفعة';
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
      _loadRentalLogs();
    }
  }
}
