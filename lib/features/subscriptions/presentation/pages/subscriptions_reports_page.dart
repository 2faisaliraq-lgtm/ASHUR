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
import '../../domain/entities/subscription_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/subscription_drawer.dart';

/// صفحة تقارير الاشتراكات
class SubscriptionsReportsPage extends StatefulWidget {
  const SubscriptionsReportsPage({super.key});

  @override
  State<SubscriptionsReportsPage> createState() =>
      _SubscriptionsReportsPageState();
}

class _SubscriptionsReportsPageState extends State<SubscriptionsReportsPage> {
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
  SubscriptionBloc? _subscriptionBloc;

  // Helper method for formatting values
  String _formatValue(dynamic value) {
    if (value is int) {
      return _formattingService.formatInteger(value);
    } else if (value is double) {
      return _formattingService.formatCurrency(value);
    } else {
      return value.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    // بدء الاستماع للتحديثات الفورية للاشتراكات عبر _loadData
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // حفظ مرجع الـ bloc لاستخدامه بأمان في dispose
    _subscriptionBloc = context.read<SubscriptionBloc>();
  }

  Future<void> _loadPermissions() async {
    final canViewReports = await _permissionChecker.hasPermission('reports_view');
    if (mounted) {
      setState(() {
        _canViewReports = canViewReports;
        _isLoadingPermissions = false;
      });
    }
  }

  void _loadData() {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: التقارير تعتمد على ستريم الاشتراكات
    // للتحديث الفوري — لا تستخدم التحميل لمرة واحدة لأنه يعرض لقطة قديمة
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<SubscriptionBloc>().add(
        StartSubscriptionsStreamEvent(
          organizationEmail: user.email!,
        ),
      );
    }
  }

  @override
  void dispose() {
    // إيقاف الاستماع للتحديثات عند إغلاق الصفحة
    _subscriptionBloc?.add(const StopSubscriptionsStreamEvent());
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions) {
      return scaffold.ResponsiveScaffold(
        appBar: AppBar(),
        body: LoadingWidget(message: 'جارٍ التحميل...'),
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
      drawer: const SubscriptionDrawer(currentRoute: 'reports'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is SubscriptionInitial || state is SubscriptionLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(
                    message: 'جارٍ تحميل تقارير الاشتراكات...',
                  ),
                ),
              ],
            );
          }

          if (state is SubscriptionError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (state is SubscriptionLoaded ||
              state is SubscriptionsStreamActive) {
            final subscriptions = state is SubscriptionLoaded
                ? state.subscriptions
                : (state as SubscriptionsStreamActive).subscriptions;
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: _buildReportsContent(context, subscriptions),
                ),
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
                  'تقارير الاشتراكات',
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
                  'نظام إدارة المجال العقاري',
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
                    tooltip: 'فلتر التقارير',
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
              _buildFilterChip('الاشتراكات النشطة', 'active'),
              _buildFilterChip('الاشتراكات المنتهية', 'expired'),
              _buildFilterChip('المنتهية قريباً', 'expiring_soon'),
              _buildFilterChip('تحليل الإيرادات', 'revenue_analysis'),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'فترة التقارير:',
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

  Widget _buildReportsContent(
    BuildContext context,
    List<SubscriptionEntity> subscriptions,
  ) {
    final reports = _generateReports(subscriptions);
    final filteredReports = _filterReports(reports);

    if (filteredReports.isEmpty) {
      return AppEmptyState(
        icon: Icons.analytics_outlined,
        title: 'لا توجد تقارير متاحة',
        message: 'جرّب تغيير المرشحات أو إعادة تحميل البيانات',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: filteredReports.length + 1, // +1 للإحصائيات
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStatisticsCard(subscriptions);
        }
        return _buildReportCard(filteredReports[index - 1]);
      },
    );
  }

  Widget _buildStatisticsCard(List<SubscriptionEntity> subscriptions) {
    final totalSubscriptions = subscriptions.length;
    final activeSubscriptions = subscriptions
        .where((s) => s.status == 'active' && !s.isExpired)
        .length;
    final expiredSubscriptions = subscriptions
        .where((s) => s.status == 'expired')
        .length;
    final expiringSoon = subscriptions
        .where(
          (s) =>
              s.status == 'active' &&
              s.endDate.isBefore(DateTime.now().add(const Duration(days: 3))),
        )
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
                  'إحصائيات الاشتراكات',
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
                    'إجمالي الاشتراكات',
                    _formattingService.formatInteger(totalSubscriptions),
                    Icons.subscriptions,
                    AssyrianTheme.deepBlue,
                  ),
                  _buildStatItem(
                    'الاشتراكات النشطة',
                    _formattingService.formatInteger(activeSubscriptions),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'المنتهية',
                    _formattingService.formatInteger(expiredSubscriptions),
                    Icons.cancel,
                    Colors.red,
                  ),
                  _buildStatItem(
                    'تنتهي قريباً',
                    _formattingService.formatInteger(expiringSoon),
                    Icons.schedule,
                    Colors.orange,
                  ),
                ];

                // إذ كان بإمكان عرض 4 عناصر في سطر واحد
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
                _formattingService.formatInteger(data['total'] ?? 0),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem(
                'النشطة',
                _formattingService.formatInteger(data['active'] ?? 0),
              ),
            ),
          ],
        );
      case 'active':
        return Row(
          children: [
            Expanded(
              child: _buildPreviewItem(
                'نشطة',
                _formattingService.formatInteger(data['active'] ?? 0),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem('الإيرادات', '${data['revenue']} د.ع'),
            ),
          ],
        );
      case 'revenue_analysis':
        return _buildPreviewItem(
          'الإيرادات الشهرية',
          '${data['monthly_revenue']} د.ع',
        );
      default:
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

  List<Map<String, dynamic>> _generateReports(
    List<SubscriptionEntity> subscriptions,
  ) {
    final reports = <Map<String, dynamic>>[];

    switch (_selectedReportType) {
      case 'overview':
        reports.addAll(_generateOverviewReports(subscriptions));
        break;
      case 'active':
        reports.addAll(_generateActiveReports(subscriptions));
        break;
      case 'expired':
        reports.addAll(_generateExpiredReports(subscriptions));
        break;
      case 'expiring_soon':
        reports.addAll(_generateExpiringSoonReports(subscriptions));
        break;
      case 'revenue_analysis':
        reports.addAll(_generateRevenueReports(subscriptions));
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

  List<Map<String, dynamic>> _generateOverviewReports(
    List<SubscriptionEntity> subscriptions,
  ) {
    return [
      {
        'title': 'تقارير الاشتراكات الشامل',
        'description': 'نظرة عامة على جميع الاشتراكات في النظام',
        'type': 'overview',
          'data': {
          'total': subscriptions.length,
          'active': subscriptions
              .where((s) => s.status == 'active' && !s.isExpired)
              .length,
          'expired': subscriptions
              .where((s) => s.status == 'expired')
              .length,
        },
        'icon': Icons.subscriptions,
        'color': AssyrianTheme.deepBlue,
      },
      {
        'title': 'تقارير حالة الاشتراكات',
        'description': 'توزيع الاشتراكات حسب الحالة',
        'type': 'status',
        'data': {
          // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا العد يعتمد على status == 'active'
          /// && !isExpired لمنع احتساب الاشتراكات المنتهية تاريخياً كمنشطات،
          /// موحد مع بطاقة الإحصائيات في _buildStatisticsCard (السطر 618).
          'active': subscriptions
              .where((s) => s.status == 'active' && !s.isExpired)
              .length,
          'expired': subscriptions
              .where((s) => s.status == 'expired')
              .length,
          'cancelled': subscriptions
              .where((s) => s.status == 'cancelled')
              .length,
        },
        'icon': Icons.pie_chart,
        'color': Colors.blue,
      },
    ];
  }

  List<Map<String, dynamic>> _generateActiveReports(
    List<SubscriptionEntity> subscriptions,
  ) {
    final activeSubscriptions = subscriptions
        .where((s) => s.status == 'active' && !s.isExpired)
        .toList();
    final totalRevenue = activeSubscriptions.fold<double>(
      0,
      (sum, s) => sum + s.price,
    );

    return [
      {
        'title': 'الاشتراكات النشطة',
        'description': 'تفاصيل الاشتراكات النشطة حالياً',
        'type': 'active',
        'data': {
          'active': activeSubscriptions.length,
          'revenue': _formattingService.formatCurrency(totalRevenue),
          'types': _getSubscriptionTypeDistribution(activeSubscriptions),
        },
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
    ];
  }

  List<Map<String, dynamic>> _generateExpiredReports(
    List<SubscriptionEntity> subscriptions,
  ) {
    final expiredSubscriptions = subscriptions
        .where((s) => s.status == 'expired')
        .toList();

    return [
      {
        'title': 'الاشتراكات المنتهية',
        'description': 'الاشتراكات التي انتهت صلاحيتها',
        'type': 'expired',
        'data': {
          'expired': expiredSubscriptions.length,
          'this_month': expiredSubscriptions
              .where((s) => s.endDate.month == DateTime.now().month && s.endDate.year == DateTime.now().year)
              .length,
          'types': _getSubscriptionTypeDistribution(expiredSubscriptions),
        },
        'icon': Icons.cancel,
        'color': Colors.red,
      },
    ];
  }

  List<Map<String, dynamic>> _generateExpiringSoonReports(
    List<SubscriptionEntity> subscriptions,
  ) {
    final expiringSoon = subscriptions
        .where(
          (s) =>
              s.status == 'active' &&
              !s.isExpired &&
              s.endDate.isBefore(DateTime.now().add(const Duration(days: 3))),
        )
        .toList();

    return [
      {
        'title': 'الاشتراكات المنتهية قريباً',
          'description': 'الاشتراكات التي تنتهي خلال 3 أيام',
        'type': 'expiring_soon',
        'data': {
          'expiring_soon': expiringSoon.length,
          'next_week': expiringSoon
              .where(
                (s) => s.endDate.isBefore(
                  DateTime.now().add(const Duration(days: 7)),
                ),
              )
              .length,
          'potential_loss': _formattingService.formatCurrency(
            expiringSoon.fold<double>(0, (sum, s) => sum + s.price),
          ),
        },
        'icon': Icons.schedule,
        'color': Colors.orange,
      },
    ];
  }

  List<Map<String, dynamic>> _generateRevenueReports(
    List<SubscriptionEntity> subscriptions,
  ) {
    final activeSubscriptions = subscriptions
        .where((s) => s.status == 'active' && !s.isExpired)
        .toList();
    // ⚠️ ملاحظة للمبرمجين المستقبليين: الإيراد الشهري هنا يجمع سعر الاشتراك الكامل
    /// (s.price) لكل اشتراك نشط بغض النظر عن مدة الاشتراك (يومي/أسبوعي/شهري/سنوي).
    /// للاشتراكات السنوية هذا يُبالغ في تقدير الإيراد الشهري. هذا تقريب تقريبي
    /// وليس دقيقاً — يُنصح بتوزيع السعر على مدة الاشتراك لحساب إيراد شهري حقيقي.
    final monthlyRevenue = activeSubscriptions.fold<double>(
      0,
      (sum, s) => sum + s.price,
    );
    final annualProjection = monthlyRevenue * 12;

    return [
      {
        'title': 'تحليل إيرادات الاشتراكات',
        'description': 'تحليل الإيرادات الحالية والمتوقعة',
        'type': 'revenue_analysis',
        'data': {
          'monthly_revenue': _formattingService.formatCurrency(monthlyRevenue),
          'annual_projection': _formattingService.formatCurrency(
            annualProjection,
          ),
          'average_subscription': activeSubscriptions.isNotEmpty
              ? _formattingService.formatCurrency(
                  monthlyRevenue / activeSubscriptions.length,
                )
              : _formattingService.formatCurrency(0),
          'highest_value': activeSubscriptions.isNotEmpty
              ? _formattingService.formatCurrency(
                  activeSubscriptions
                      .map((s) => s.price)
                      .reduce((a, b) => a > b ? a : b),
                )
              : _formattingService.formatCurrency(0),
        },
        'icon': Icons.trending_up,
        'color': Colors.green,
      },
    ];
  }

  Map<String, int> _getSubscriptionTypeDistribution(
    List<dynamic> subscriptions,
  ) {
    final distribution = <String, int>{};
    for (final subscription in subscriptions) {
      final type = subscription.type ?? 'غير محدد';
      distribution[type] = (distribution[type] ?? 0) + 1;
    }
    return distribution;
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

// ⚠️ ملاحظات توثيقية للمبرمجين المستقبليين — التقارير والإحصائيات (مدمجة):
// [إحصائيات] _generateRevenueReports (السطر 1139): يجمع السعر الكامل s.price لكل
// اشتراك نشط كإيراد شهري → مبالغة في التقدير للاشتراكات السنوية/الربعية.
// يفضل توزيع السعر على مدة الاشتراك لحساب إيراد شهري حقيقي.
// [إحصائيات] _generateExpiredReports (السطر 1078): يقارن endDate بالشهر/السنة
// المحليين DateTime.now() → احتمال اختلاف مع منطق UTC المستخدم في SubscriptionEntity
// (isExpired/isExpiringSoon). يفضل استخدام isExpired من الكيان.
// [تقارير] أزرار التصدير (PDF/Excel/طباعة) الأسطر 1275-1300: فوقها استباقية (stub)
// تظهر رسالة "سيتم التنفيذ قريباً" ولا تُنفذ أي تصدير حقيقي.
}
