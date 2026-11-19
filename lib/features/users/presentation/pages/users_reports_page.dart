import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart'; // ✅ مطلوب لـ Clipboard في وظائف التصدير والطباعة
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/users_drawer.dart';

/// صفحة تقارير المستخدمين
class UsersReportsPage extends StatefulWidget {
  const UsersReportsPage({super.key});

  @override
  State<UsersReportsPage> createState() => _UsersReportsPageState();
}

class _UsersReportsPageState extends State<UsersReportsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReportType = 'overview';
  bool _isFilterExpanded = false;
  UsersLoaded? blocState; // تخزين حالة UsersLoaded الحالية للاستخدام في التقارير

  @override
  void initState() {
    super.initState();
    _loadUsersData();
  }

  void _loadUsersData() {
    context.read<UsersBloc>().add(const StartUsersStreamEvent());
    context.read<UsersBloc>().add(const LoadRolesEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const UsersDrawer(currentRoute: '/users/reports'),
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
          if (state is UsersInitial || state is UsersLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(
                    message: 'جاري تحميل تقارير المستخدمين...',
                  ),
                ),
              ],
            );
          }

          if (state is UsersError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (state is UsersLoaded) {
            blocState = state; // حفظ الحالة للاستخدام في تصدير التقارير
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
                  'تقارير المستخدمين',
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
          onPressed: _loadUsersData,
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
              _buildFilterChip('توزيع الأدوار', 'roles'),
              _buildFilterChip('توزيع الأقسام', 'departments'),
              _buildFilterChip('نشاط المستخدمين', 'activity'),
              _buildFilterChip('الصلاحيات', 'permissions'),
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

  Widget _buildReportsContent(BuildContext context, UsersLoaded state) {
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

  Widget _buildStatisticsCard(UsersLoaded state) {
    final totalUsers = state.users.length;
    final activeUsers = state.users.where((u) => u.isActive).length;
    final inactiveUsers = totalUsers - activeUsers;
    final verifiedUsers = state.users.where((u) => u.isEmailVerified).length;

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
                  'إحصائيات سريعة',
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
                    'إجمالي المستخدمين',
                    _formattingService.formatInteger(totalUsers),
                    Icons.people,
                    AssyrianTheme.deepBlue,
                  ),
                  _buildStatItem(
                    'المستخدمون النشطون',
                    _formattingService.formatInteger(activeUsers),
                    Icons.person,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'غير النشطين',
                    _formattingService.formatInteger(inactiveUsers),
                    Icons.person_off,
                    Colors.orange,
                  ),
                  _buildStatItem(
                    'المؤكدون',
                    _formattingService.formatInteger(verifiedUsers),
                    Icons.verified_user,
                    AssyrianTheme.primaryGold,
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
                  children: [
                    Text(
                      report['title'] as String,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AssyrianTheme.deepBlue,
                      ),
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
            _buildPreviewItem(
              'الإجمالي',
              _formattingService.formatInteger(data['total']),
            ),
            SizedBox(width: 16.w),
            _buildPreviewItem(
              'النشطون',
              _formattingService.formatInteger(data['active']),
            ),
          ],
        );
      case 'status':
        return Row(
          children: [
            _buildPreviewItem(
              'نشط',
              _formattingService.formatInteger(data['active']),
            ),
            SizedBox(width: 16.w),
            _buildPreviewItem(
              'غير نشط',
              _formattingService.formatInteger(data['inactive']),
            ),
          ],
        );
      case 'activity':
        return _buildPreviewItem('معدل النشاط', '${data['activity_rate']}%');
      default:
        final firstEntry = data.entries.first;
        return _buildPreviewItem(
          firstEntry.key,
          _formattingService.formatInteger(firstEntry.value),
        );
      }
  }

  Widget _buildPreviewItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.primaryGold,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
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
            onPressed: _loadUsersData,
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

  List<Map<String, dynamic>> _generateReports(UsersLoaded state) {
    final reports = <Map<String, dynamic>>[];

    switch (_selectedReportType) {
      case 'overview':
        reports.addAll(_generateOverviewReports(state));
        break;
      case 'roles':
        reports.addAll(_generateRoleReports(state));
        break;
      case 'departments':
        reports.addAll(_generateDepartmentReports(state));
        break;
      case 'activity':
        reports.addAll(_generateActivityReports(state));
        break;
      case 'permissions':
        reports.addAll(_generatePermissionReports(state));
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

  List<Map<String, dynamic>> _generateOverviewReports(UsersLoaded state) {
    return [
      {
        'title': 'تقرير المستخدمين الشامل',
        'description': 'نظرة عامة على جميع المستخدمين في النظام',
        'type': 'overview',
        'data': {
          'total': state.users.length,
          'active': state.users.where((u) => u.isActive).length,
          'verified': state.users.where((u) => u.isEmailVerified).length,
        },
        'icon': Icons.people,
        'color': AssyrianTheme.deepBlue,
      },
      {
        'title': 'تقرير حالة المستخدمين',
        'description': 'توزيع المستخدمين حسب الحالة (نشط/غير نشط)',
        'type': 'status',
        'data': {
          'active': state.users.where((u) => u.isActive).length,
          'inactive': state.users.where((u) => !u.isActive).length,
        },
        'icon': Icons.toggle_on,
        'color': Colors.green,
      },
    ];
  }

  List<Map<String, dynamic>> _generateRoleReports(UsersLoaded state) {
    final roleDistribution = <String, int>{};
    for (final user in state.users) {
      for (final role in user.roles) {
        roleDistribution[role.displayName] =
            (roleDistribution[role.displayName] ?? 0) + 1;
      }
    }

    return [
      {
        'title': 'توزيع الأدوار',
        'description': 'عدد المستخدمين لكل دور في النظام',
        'type': 'roles',
        'data': roleDistribution,
        'icon': Icons.admin_panel_settings,
        'color': AssyrianTheme.primaryGold,
      },
    ];
  }

  List<Map<String, dynamic>> _generateDepartmentReports(UsersLoaded state) {
    final departmentDistribution = <String, int>{};
    for (final user in state.users) {
      final department = user.department ?? 'غير محدد';
      departmentDistribution[department] =
          (departmentDistribution[department] ?? 0) + 1;
    }

    return [
      {
        'title': 'توزيع الأقسام',
        'description': 'عدد المستخدمين في كل قسم',
        'type': 'departments',
        'data': departmentDistribution,
        'icon': Icons.business,
        'color': Colors.blue,
      },
    ];
  }

  List<Map<String, dynamic>> _generateActivityReports(UsersLoaded state) {
    final recentLogins = state.users
        .where((u) => u.lastLoginAt != null)
        .where(
          (u) => u.lastLoginAt!.isAfter(
            DateTime.now().subtract(const Duration(days: 30)),
          ),
        )
        .length;

    return [
      {
        'title': 'نشاط المستخدمين',
        'description': 'المستخدمون الذين سجلوا دخول خلال آخر 30 يوم',
        'type': 'activity',
        'data': {
          'recent_logins': recentLogins,
          'total_users': state.users.length,
          'activity_rate': state.users.isNotEmpty
              ? _formattingService.formatPercentage(
                  recentLogins / state.users.length * 100,
                )
              : _formattingService.formatPercentage(0),
        },
        'icon': Icons.timeline,
        'color': Colors.purple,
      },
    ];
  }

  List<Map<String, dynamic>> _generatePermissionReports(UsersLoaded state) {
    final permissionCount = <String, int>{};
    for (final user in state.users) {
      for (final permission in user.allPermissions) {
        permissionCount[permission] = (permissionCount[permission] ?? 0) + 1;
      }
    }

    return [
      {
        'title': 'توزيع الصلاحيات',
        'description': 'عدد المستخدمين لكل صلاحية',
        'type': 'permissions',
        'data': permissionCount,
        'icon': Icons.security,
        'color': Colors.red,
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
                _formattingService.formatInteger(entry.value),
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
      _loadUsersData();
    }
  }

  void _exportToPDF() {
    // ⚠️ ملاحظة: تصدير PDF الفعلي يتطلب إضافة مكتبة 'pdf' و 'printing' إلى pubspec.yaml
    // في الوقت الحالي، ننسخ ملخص التقرير إلى الحافظة كمعالجة مؤقتة.
    if (blocState is! UsersLoaded) return;
    final UsersLoaded state = blocState!;
    final reportSummary = _generateReportsSummary(state);
    Clipboard.setData(ClipboardData(text: reportSummary));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم نسخ ملخص التقرير إلى الحافظة. يتطلب تصدير ملف PDF إضافة حزمة الطباعة المناسبة',
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _exportToExcel() {
    // ⚠️ ملاحظة: تصدير جدول البيانات فعلياً يتطلب إضافة مكتبة التصدير إلى إعدادات المشروع.
    if (blocState is! UsersLoaded) return;
    final UsersLoaded state = blocState!;
    final reportSummary = _generateReportsSummary(state);
    Clipboard.setData(ClipboardData(text: reportSummary));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم نسخ بيانات التقرير إلى الحافظة. يتطلب تصدير جدول البيانات إضافة حزمة التصدير المناسبة',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _printReport() {
    // ⚠️ ملاحظة: الطباعة الفعلية تتطلب إضافة مكتبة 'printing' إلى pubspec.yaml
    if (blocState is! UsersLoaded) return;
    final UsersLoaded state = blocState!;
    final reportSummary = _generateReportsSummary(state);
    Clipboard.setData(ClipboardData(text: reportSummary));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم نسخ التقرير إلى الحافظة للطباعة. الطباعة المباشرة تتطلب مكتبة printing',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// إنشاء ملخص نصي للتقرير الحالي للنقل إلى الحافظة
  String _generateReportsSummary(UsersLoaded state) {
    final buffer = StringBuffer();
    buffer.writeln('تقرير المستخدمين - نظام إدارة المتاجر الآشوري');
    buffer.writeln('التاريخ: ${DateTime.now().toString()}');
    buffer.writeln('النوع المحدد: $_selectedReportType');
    buffer.writeln('');
    buffer.writeln('إجمالي المستخدمين في الحالة الحالية: ${state.users.length}');
    buffer.writeln('المستخدمون النشطون: ${state.users.where((u) => u.isActive).length}');
    buffer.writeln('غير النشطين: ${state.users.where((u) => !u.isActive).length}');
    buffer.writeln('');
    buffer.writeln('تفاصيل المستخدمين:');
    for (final user in state.users) {
      buffer.writeln(
        '- ${user.name ?? 'غير محدد'} | ${user.email ?? 'غير محدد'} | ${user.isActive ? 'نشط' : 'غير نشط'}',
      );
    }
    return buffer.toString();
  }
}
