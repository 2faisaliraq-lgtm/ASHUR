import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../bloc/maintenance_bloc.dart';
import '../widgets/maintenance_drawer.dart';
import '../../domain/entities/maintenance_request_entity.dart';

/// صفحة تقارير الصيانة
class MaintenanceReportsPage extends StatefulWidget {
  const MaintenanceReportsPage({super.key});

  @override
  State<MaintenanceReportsPage> createState() => _MaintenanceReportsPageState();
}

class _MaintenanceReportsPageState extends State<MaintenanceReportsPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canViewReports = false;
  bool _isLoadingPermissions = true;
  final TextEditingController _searchController = TextEditingController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReportType = 'overview';
  bool _isFilterExpanded = false;

  // Helper methods for formatting
  String _formatInteger(int number) {
    return _formattingService.formatInteger(number);
  }

  String _formatCurrency(double amount) {
    return _formattingService.formatCurrency(amount);
  }

  String _formatValue(dynamic value) {
    if (value is int) {
      return _formatInteger(value);
    } else if (value is double) {
      return _formatCurrency(value);
    } else {
      return value.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData();
    
    // بدء الاستماع للتحديثات الفورية لطلبات الصيانة
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<MaintenanceBloc>().add(
        const StartMaintenanceStreamEvent(),
      );
    }
  }

  Future<void> _loadPermissions() async {
    final canViewReports = await _permissionChecker.hasPermission('maintenance_reports_view');
    if (mounted) {
      setState(() {
        _canViewReports = canViewReports;
        _isLoadingPermissions = false;
      });
    }
  }

  void _loadData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<MaintenanceBloc>().add(
        LoadMaintenanceRequestsEvent(user.email!),
      );
    }
  }

  @override
  void dispose() {
    // إيقاف ستريم التحديث الفوري عند إغلاق الصفحة
    // (أُصلح 2026-10-11: كانت الصفحة تبدأ الستريم
    // في initState دون إيقافه هنا — تسريب استماع).
    context.read<MaintenanceBloc>().add(
      const StopMaintenanceStreamEvent(),
    );
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions) {
      return scaffold.ResponsiveScaffold(
        appBar: AppBar(),
        body: LoadingWidget(message: 'جاري التحميل...'),
      );
    }

    if (!_canViewReports) {
      return scaffold.ResponsiveScaffold(
        appBar: AppBar(title: const Text('التقارير')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'ليس لديك صلاحية عرض التقارير',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى التواصل مع المسؤول للحصول على الصلاحية',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const MaintenanceDrawer(currentRoute: '/maintenance/reports'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<MaintenanceBloc, MaintenanceState>(
        listener: (context, state) {
          if (state is MaintenanceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is MaintenanceInitial || state is MaintenanceLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل تقارير الصيانة...'),
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

          if (state is MaintenanceLoaded) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildReportsContent(context, state)),
              ],
            );
          }

          // ✅ التحديث الفوري: تُعرض التقارير من ستريم الطلبات
          // (MaintenanceStreamActive) أيضاً — الصفحة تبدأ
          // الستريم في initState فلا يجب تجاهل حالته
          // (أُصلح 2026-10-11: كانت تعرض "لا توجد بيانات"
          // رغم وجود بيانات حقيقية من الستريم).
          if (state is MaintenanceStreamActive) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildReportsContent(context, state)),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              const Expanded(
                child: Center(child: Text('لا توجد بيانات متاحة')),
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
                  'تقارير الصيانة',
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
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            onSelected: (value) {
              switch (value) {
                case 'export_pdf':
                  _exportToPDF();
                  break;
                case 'export_excel':
                  _exportToExcel();
                  break;
                case 'print':
                  _printReport();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('تصدير PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('تصدير جدول بيانات'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('طباعة'),
                  ],
                ),
              ),
            ],
          ),
        IconButton(
          onPressed: _loadData,
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
                      hintText: 'البحث في التقارير...',
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
                        _isFilterExpanded || _selectedReportType != 'overview'
                        ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color:
                          _isFilterExpanded || _selectedReportType != 'overview'
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
                                  _selectedReportType != 'overview'
                              ? AssyrianTheme.primaryGold
                              : Colors.grey[600],
                          size: 24.sp,
                        ),
                        if (_selectedReportType != 'overview')
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
                    tooltip: 'فلترة التقارير',
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
            'نوع التقرير:',
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
              _buildFilterChip('نظرة عامة', 'overview'),
              _buildFilterChip('طلبات الصيانة', 'requests'),
              _buildFilterChip('الصيانة المكتملة', 'completed'),
              _buildFilterChip('الصيانة المعلقة', 'pending'),
              _buildFilterChip('تحليل التكاليف', 'cost_analysis'),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'فترة التقرير:',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16.sp),
                        SizedBox(width: 4.w),
                        Text(
                          _formattingService.formatDate(_startDate),
                          style: TextStyle(fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text('إلى', style: TextStyle(fontSize: 12.sp)),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16.sp),
                        SizedBox(width: 4.w),
                        Text(
                          _formattingService.formatDate(_endDate),
                          style: TextStyle(fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedReportType == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          color: isSelected ? AssyrianTheme.deepBlue : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedReportType = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.deepBlue,
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildReportsContent(BuildContext context, dynamic state) {
    final reports = _generateReports(state);
    final filteredReports = _filterReports(reports);

    if (filteredReports.isEmpty) {
      return AppEmptyState(
        icon: Icons.analytics_outlined,
        title: 'لا توجد تقارير متاحة',
        message: 'جرب تغيير المرشحات أو إعادة تحميل البيانات',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: filteredReports.length + 1, // +1 للإحصائيات
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStatisticsCard(state);
        }
        return _buildReportCard(filteredReports[index - 1]);
      },
    );
  }

  Widget _buildStatisticsCard(dynamic state) {
    final totalRequests = state.requests.length;
    final completedRequests = state.requests
        .where((r) => r.status == 'completed')
        .length;
    final pendingRequests = state.requests
        .where((r) => r.status == 'pending')
        .length;
    final inProgressRequests = state.requests
        .where((r) => r.status == 'in_progress')
        .length;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AssyrianTheme.primaryGold,
                  size: 24.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'إحصائيات الصيانة',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            // تحديد عدد الأعمدة بناءً على عرض الشاشة المتاح
            LayoutBuilder(
              builder: (context, constraints) {
                // حساب عدد الأعمدة بناءً على العرض المتاح
                final availableWidth = constraints.maxWidth;
                const minItemWidth = 150.0; // الحد الأدنى لعرض كل عنصر
                final maxColumns = (availableWidth / minItemWidth)
                    .floor()
                    .clamp(2, 4);

                // إنشاء قائمة العناصر
                final statItems = [
                  _buildStatItem(
                    'إجمالي الطلبات',
                    _formatInteger(totalRequests),
                    Icons.build,
                    AssyrianTheme.deepBlue,
                  ),
                  _buildStatItem(
                    'مكتملة',
                    _formatInteger(completedRequests),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'معلقة',
                    _formatInteger(pendingRequests),
                    Icons.pending,
                    Colors.orange,
                  ),
                  _buildStatItem(
                    'قيد التنفيذ',
                    _formatInteger(inProgressRequests),
                    Icons.settings,
                    Colors.blue,
                  ),
                ];

                // إذا كان بإمكان عرض 4 عناصر في سطر واحد
                if (maxColumns >= 4) {
                  return Row(
                    children: [
                      Expanded(child: statItems[0]),
                      SizedBox(width: 8.w),
                      Expanded(child: statItems[1]),
                      SizedBox(width: 8.w),
                      Expanded(child: statItems[2]),
                      SizedBox(width: 8.w),
                      Expanded(child: statItems[3]),
                    ],
                  );
                } else {
                  // عرض في صفين
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: statItems[0]),
                          SizedBox(width: 8.w),
                          Expanded(child: statItems[1]),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(child: statItems[2]),
                          SizedBox(width: 8.w),
                          Expanded(child: statItems[3]),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    // تحديد ما إذا كانت الشاشة أفقية
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.all(isLandscape ? 8.w : 12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isLandscape ? 18.sp : 24.sp),
          SizedBox(height: isLandscape ? 4.h : 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: isLandscape ? 14.sp : 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isLandscape ? 2.h : 4.h),
          Text(
            title,
            style: TextStyle(
              fontSize: isLandscape ? 8.sp : 10.sp,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showReportDetails(context, report),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: (report['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  report['icon'] as IconData,
                  color: report['color'] as Color,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      report['title'] as String,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AssyrianTheme.deepBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      report['description'] as String,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),
                    _buildReportPreview(report),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportPreview(Map<String, dynamic> report) {
    final data = report['data'] as Map<String, dynamic>;

    switch (report['type'] as String) {
      case 'overview':
        return Row(
          children: [
            Expanded(
              child: _buildPreviewItem(
                'الإجمالي',
                _formatInteger(data['total'] ?? 0),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem(
                'مكتملة',
                _formatInteger(data['completed'] ?? 0),
              ),
            ),
          ],
        );
      case 'requests':
        return Row(
          children: [
            Expanded(
              child: _buildPreviewItem(
                'طلبات',
                _formatInteger(data['requests'] ?? 0),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem('التكلفة', '${data['cost']} د.ع'),
            ),
          ],
        );
      case 'cost_analysis':
        return _buildPreviewItem(
          'التكلفة الإجمالية',
          '${data['total_cost']} د.ع',
        );
      default:
        if (data.isEmpty) {
          return const Text('لا توجد بيانات');
        }
        final firstEntry = data.entries.first;
        return _buildPreviewItem(
          firstEntry.key,
          _formatValue(firstEntry.value),
        );
    }
  }

  Widget _buildPreviewItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.primaryGold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red.shade400),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.red.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadData,
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

  List<Map<String, dynamic>> _generateReports(dynamic state) {
    // ✅ تصفية الطلبات حسب نطاق التاريخ المحدد
    // ℹ️ التصفية تستخدم requestDate (تاريخ الصيانة المطلوب) وليس createdAt (تاريخ الإنشاء في النظام).
    List<MaintenanceRequestEntity> filteredRequests = state.requests;
    final startDate = _startDate;
    final endDate = _endDate;
    filteredRequests = state.requests.where((r) {
      // تصفية حسب تاريخ الصيانة المطلوب (requestDate) وليس تاريخ الإنشاء (createdAt)
      final requestDate = r.requestDate;
      if (requestDate.isBefore(startDate)) {
        return false;
      }
      final endOfDay = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );
      if (requestDate.isAfter(endOfDay)) {
        return false;
      }
      return true;
    }).toList();

    final reports = <Map<String, dynamic>>[];

    switch (_selectedReportType) {
      case 'overview':
        reports.addAll(_generateOverviewReportsWithRequests(filteredRequests));
        break;
      case 'requests':
        reports.addAll(_generateRequestsReportsWithRequests(filteredRequests));
        break;
      case 'completed':
        reports.addAll(_generateCompletedReportsWithRequests(filteredRequests));
        break;
      case 'pending':
        reports.addAll(_generatePendingReportsWithRequests(filteredRequests));
        break;
      case 'cost_analysis':
        reports.addAll(_generateCostAnalysisReportsWithRequests(filteredRequests));
        break;
    }

    return reports;
  }

  List<Map<String, dynamic>> _filterReports(
    List<Map<String, dynamic>> reports,
  ) {
    if (_searchController.text.isEmpty) {
      return reports;
    }

    final query = _searchController.text.toLowerCase();
    return reports.where((report) {
      final title = (report['title'] as String).toLowerCase();
      final description = (report['description'] as String).toLowerCase();
      return title.contains(query) || description.contains(query);
    }).toList();
  }

  // ⚠️ ملاحظة للمبرمجين المستقبليين: تحسب التوزيع حسب الأولوية
  // (priority) وليس حسب "نوع الصيانة". لا تغير الاسم دون تحديث جميع الاستدعاءات.
  Map<String, int> _getPriorityDistribution(List<dynamic> requests) {
    final distribution = <String, int>{};
    for (final request in requests) {
      final type = (request as MaintenanceRequestEntity).priority;
      distribution[type] = (distribution[type] ?? 0) + 1;
    }
    return distribution;
  }

  // ===== دوال التقارير الجديدة التي تقبل قائمة الطلبات المصفاة حسب التاريخ =====

  List<Map<String, dynamic>> _generateOverviewReportsWithRequests(
      List<MaintenanceRequestEntity> requests) {
    return [
      {
        'title': 'تقرير الصيانة الشامل',
        'description': 'نظرة عامة على جميع طلبات الصيانة في النظام',
        'type': 'overview',
        'data': {
          'total': requests.length,
          'completed': requests.where((r) => r.status == 'completed').length,
          'pending': requests.where((r) => r.status == 'pending').length,
        },
        'icon': Icons.build,
        'color': AssyrianTheme.deepBlue,
      },
      {
        'title': 'تقرير حالة الطلبات',
        'description': 'توزيع طلبات الصيانة حسب الحالة',
        'type': 'status',
        'data': {
          'completed': requests.where((r) => r.status == 'completed').length,
          'pending': requests.where((r) => r.status == 'pending').length,
          'in_progress': requests.where((r) => r.status == 'in_progress').length,
        },
        'icon': Icons.pie_chart,
        'color': Colors.blue,
      },
    ];
  }

  List<Map<String, dynamic>> _generateRequestsReportsWithRequests(
      List<MaintenanceRequestEntity> requests) {
    final totalCost = requests.fold<double>(
      0,
      (sum, r) =>
          sum + (r.actualCost?.toDouble() ?? r.estimatedCost?.toDouble() ?? 0),
    );

    return [
      {
        'title': 'طلبات الصيانة',
        'description': 'تفاصيل جميع طلبات الصيانة',
        'type': 'requests',
        'data': {
          'requests': requests.length,
          'cost': _formatCurrency(totalCost),
          'types': _getPriorityDistribution(requests),
        },
        'icon': Icons.list_alt,
        'color': Colors.purple,
      },
    ];
  }

  List<Map<String, dynamic>> _generateCompletedReportsWithRequests(
      List<MaintenanceRequestEntity> requests) {
    final completedRequests = requests
        .where((r) => r.status == 'completed')
        .toList();

    return [
      {
        'title': 'الصيانة المكتملة',
        'description': 'طلبات الصيانة التي تم إنجازها',
        'type': 'completed',
        'data': {
          'completed': completedRequests.length,
          'this_month': completedRequests
              .where((r) =>
                  r.completedDate?.month == DateTime.now().month)
              .length,
          'types': _getPriorityDistribution(completedRequests),
        },
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
    ];
  }

  List<Map<String, dynamic>> _generatePendingReportsWithRequests(
      List<MaintenanceRequestEntity> requests) {
    final pendingRequests = requests
        .where((r) => r.status == 'pending')
        .toList();

    return [
      {
        'title': 'الصيانة المعلقة',
        'description': 'طلبات الصيانة المعلقة والمتأخرة',
        'type': 'pending',
        'data': {
          'pending': pendingRequests.length,
          'overdue': pendingRequests
              .where(
                (r) =>
                    r.scheduledDate != null &&
                    r.scheduledDate!.isBefore(DateTime.now()),
              )
              .length,
          'urgent': pendingRequests.where((r) => r.priority == 'urgent').length,
        },
        'icon': Icons.pending,
        'color': Colors.orange,
      },
    ];
  }

  List<Map<String, dynamic>> _generateCostAnalysisReportsWithRequests(
      List<MaintenanceRequestEntity> requests) {
    final totalCost = requests.fold<double>(
      0,
      (sum, r) =>
          sum + (r.actualCost?.toDouble() ?? r.estimatedCost?.toDouble() ?? 0),
    );
    final averageCost = requests.isNotEmpty
        ? totalCost / requests.length
        : 0.0;

    return [
      {
        'title': 'تحليل تكاليف الصيانة',
        'description': 'تحليل التكاليف الإجمالية والمتوسطة للصيانة',
        'type': 'cost_analysis',
        'data': {
          'total_cost': _formatCurrency(totalCost),
          'average_cost': _formatCurrency(averageCost),
          'highest_cost': requests.isNotEmpty
              ? _formatCurrency(
                  requests
                      .map((r) => r.actualCost ?? r.estimatedCost ?? 0)
                      .reduce((a, b) => a > b ? a : b),
                )
              : _formatCurrency(0),
        },
        'icon': Icons.trending_up,
        'color': Colors.green,
      },
    ];
  }

  void _showReportDetails(BuildContext context, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report['title'] as String),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(report['description'] as String),
              SizedBox(height: 16.h),
              Text(
                'البيانات التفصيلية:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
              SizedBox(height: 8.h),
              _buildDetailedData(report['data'] as Map<String, dynamic>),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportToPDF();
            },
            child: const Text('تصدير'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedData(Map<String, dynamic> data) {
    return Column(
      children: data.entries.map((entry) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(entry.key, style: TextStyle(fontSize: 12.sp)),
              ),
              Text(
                _formatValue(entry.value),
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    var picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadData();
    }
  }

  void _exportToPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ تصدير ملف PDF قريباً'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportToExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ تصدير جدول بيانات قريباً'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _printReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ الطباعة قريباً'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
