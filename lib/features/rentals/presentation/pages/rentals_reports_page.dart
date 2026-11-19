import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../bloc/rental_bloc.dart';
import '../widgets/rental_drawer.dart';

/// صفحة تقارير الإيجارات
class RentalsReportsPage extends StatefulWidget {
  const RentalsReportsPage({super.key});

  @override
  State<RentalsReportsPage> createState() => _RentalsReportsPageState();
}

class _RentalsReportsPageState extends State<RentalsReportsPage> {
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
    
    // بدء الاستماع للتحديثات الفورية لعقود الإيجار
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      context.read<RentalBloc>().add(
        StartRentalsStreamEvent(
          organizationEmail: normalizedEmail,
        ),
      );
    }
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      context.read<RentalBloc>().add(LoadRentalsEvent(normalizedEmail));
    }
  }

  @override
  void dispose() {
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
      drawer: const RentalDrawer(currentRoute: '/rentals/reports'),
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
          if (state is RentalInitial || state is RentalLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(
                    message: 'جارٍ تحميل تقارير الإيجارات...',
                  ),
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

          if (state is RentalLoaded) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildReportsContent(context, state)),
              ],
            );
          }

          if (state is RentalsStreamActive) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: _buildReportsContentStream(context, state),
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
                  'تقارير الإيجارات',
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
                    // ⚠️ إصلاح (2026-10-12): كان
                    // onChanged فارغاً — الكتابة لا
                    // تعيد البناء فلا تُطبَّق الفلترة
                    // (_filterReports تقرأ
                    // _searchController.text). setState
                    // هنا ضروري ليُعيد البناء ويُفلتر
                    // فوراً عند الكتابة.
                    onChanged: (value) { setState(() {}); },
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
              _buildFilterChip('الإيجارات النشطة', 'active'),
              _buildFilterChip('الإيجارات المنتهية', 'expired'),
              _buildFilterChip('المتأخرة', 'overdue'),
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

  Widget _buildReportsContent(BuildContext context, RentalLoaded state) {
    final reports = _generateReports(state);
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
          return _buildStatisticsCard(state);
        }
        return _buildReportCard(filteredReports[index - 1]);
      },
    );
  }

  Widget _buildReportsContentStream(BuildContext context, RentalsStreamActive state) {
    final rentals = state.rentals;
    final reports = <Map<String, dynamic>>[];

    switch (_selectedReportType) {
      case 'overview':
        reports.add({
          'title': 'تقارير الإيجارات الشامل',
          'description': 'نظرة عامة على جميع الإيجارات في النظام',
          'type': 'overview',
          'data': {
            'total': rentals.length,
            'active': rentals.where((r) => r.status == 'active').length,
            'expired': rentals.where((r) => r.status == 'expired').length,
          },
          'icon': Icons.home_work,
          'color': AssyrianTheme.deepBlue,
        });
        break;
      case 'active':
        final activeRentals = rentals.where((r) => r.status == 'active').toList();
        final totalRevenue = activeRentals.fold<double>(0, (sum, r) => sum + r.rentalPrice);
        reports.add({
          'title': 'الإيجارات النشطة',
          'description': 'تفاصيل الإيجارات النشطة حالياً',
          'type': 'active',
          'data': {
            'active': activeRentals.length,
            'revenue': _formatCurrency(totalRevenue),
          },
          'icon': Icons.check_circle,
          'color': Colors.green,
        });
        break;
      case 'expired':
        final expiredRentals = rentals.where((r) => r.status == 'expired').toList();
        reports.add({
          'title': 'الإيجارات المنتهية',
          'description': 'الإيجارات التي انتهت مدتها',
          'type': 'expired',
          'data': {
            'expired': expiredRentals.length,
          },
          'icon': Icons.cancel,
          'color': Colors.red,
        });
        break;
      case 'overdue':
        final overdueRentals = rentals.where((r) => r.status == 'active' && r.endDate.isBefore(DateTime.now())).toList();
        reports.add({
          'title': 'الإيجارات المتأخرة',
          'description': 'الإيجارات التي تجاوزت تاريخ الانتهاء',
          'type': 'overdue',
          'data': {
            'overdue': overdueRentals.length,
            'potential_loss': _formatCurrency(overdueRentals.fold<double>(0, (sum, r) => sum + r.rentalPrice)),
          },
          'icon': Icons.schedule,
          'color': Colors.orange,
        });
        break;
      case 'revenue_analysis':
        final activeRentals = rentals.where((r) => r.status == 'active').toList();
        final monthlyRevenue = activeRentals.fold<double>(0, (sum, r) => sum + r.rentalPrice);
        reports.add({
          'title': 'تحليل إيرادات الإيجارات',
          'description': 'تحليل الإيرادات الحالية والمتوقعة',
          'type': 'revenue_analysis',
          'data': {
            'monthly_revenue': _formatCurrency(monthlyRevenue),
            'annual_projection': _formatCurrency(monthlyRevenue * 12),
            'average_rent': activeRentals.isNotEmpty ? _formatCurrency(monthlyRevenue / activeRentals.length) : _formatCurrency(0),
            'highest_rent': activeRentals.isNotEmpty ? _formatCurrency(activeRentals.map((r) => r.rentalPrice).reduce((a, b) => a > b ? a : b)) : _formatCurrency(0),
          },
          'icon': Icons.trending_up,
          'color': Colors.green,
        });
        break;
    }

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
      itemCount: filteredReports.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStatisticsCardStream(state);
        }
        return _buildReportCard(filteredReports[index - 1]);
      },
    );
  }

  Widget _buildStatisticsCardStream(RentalsStreamActive state) {
    final rentals = state.rentals;
    final totalRentals = rentals.length;
    final activeRentals = rentals.where((r) => r.status == 'active').length;
    final expiredRentals = rentals.where((r) => r.status == 'expired').length;
    final overdueRentals = rentals.where((r) => r.status == 'active' && r.endDate.isBefore(DateTime.now())).length;

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
                Icon(Icons.analytics, color: AssyrianTheme.primaryGold, size: 24.sp),
                SizedBox(width: 8.w),
                Text(
                  'إحصائيات الإيجارات',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: AssyrianTheme.deepBlue),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                const minItemWidth = 150.0;
                final maxColumns = (availableWidth / minItemWidth).floor().clamp(2, 4);

                final statItems = [
                  _buildStatItem('إجمالي الإيجارات', _formatInteger(totalRentals), Icons.home_work, AssyrianTheme.deepBlue),
                  _buildStatItem('نشطة', _formatInteger(activeRentals), Icons.check_circle, Colors.green),
                  _buildStatItem('منتهية', _formatInteger(expiredRentals), Icons.cancel, Colors.red),
                  _buildStatItem('متأخرة', _formatInteger(overdueRentals), Icons.schedule, Colors.orange),
                ];

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

  Widget _buildStatisticsCard(RentalLoaded state) {
    final totalRentals = state.rentals.length;
    final activeRentals = state.rentals
        .where((r) => r.status == 'active')
        .length;
    final expiredRentals = state.rentals
        .where((r) => r.status == 'expired')
        .length;
    final overdueRentals = state.rentals
        .where(
          (r) => r.status == 'active' && r.endDate.isBefore(DateTime.now()),
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
                  'إحصائيات الإيجارات',
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
                    'إجمالي الإيجارات',
                    _formatInteger(totalRentals),
                    Icons.home_work,
                    AssyrianTheme.deepBlue,
                  ),
                  _buildStatItem(
                    'نشطة',
                    _formatInteger(activeRentals),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'منتهية',
                    _formatInteger(expiredRentals),
                    Icons.cancel,
                    Colors.red,
                  ),
                  _buildStatItem(
                    'متأخرة',
                    _formatInteger(overdueRentals),
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
                _formatInteger(data['total'] ?? 0),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem(
                'النشطة',
                _formatInteger(data['active'] ?? 0),
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
                _formatInteger(data['active'] ?? 0),
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

  List<Map<String, dynamic>> _generateReports(RentalLoaded state) {
    final reports = <Map<String, dynamic>>[];

    switch (_selectedReportType) {
      case 'overview':
        reports.addAll(_generateOverviewReports(state));
        break;
      case 'active':
        reports.addAll(_generateActiveReports(state));
        break;
      case 'expired':
        reports.addAll(_generateExpiredReports(state));
        break;
      case 'overdue':
        reports.addAll(_generateOverdueReports(state));
        break;
      case 'revenue_analysis':
        reports.addAll(_generateRevenueReports(state));
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

  List<Map<String, dynamic>> _generateOverviewReports(RentalLoaded state) {
    return [
      {
        'title': 'تقارير الإيجارات الشامل',
        'description': 'نظرة عامة على جميع الإيجارات في النظام',
        'type': 'overview',
        'data': {
          'total': state.rentals.length,
          'active': state.rentals.where((r) => r.status == 'active').length,
          'expired': state.rentals.where((r) => r.status == 'expired').length,
        },
        'icon': Icons.home_work,
        'color': AssyrianTheme.deepBlue,
      },
      {
        'title': 'تقارير حالة الإيجارات',
        'description': 'توزيع الإيجارات حسب الحالة',
        'type': 'status',
        'data': {
          'active': state.rentals.where((r) => r.status == 'active').length,
          'expired': state.rentals.where((r) => r.status == 'expired').length,
          'overdue': state.rentals
              .where(
                (r) =>
                    r.status == 'active' && r.endDate.isBefore(DateTime.now()),
              )
              .length,
        },
        'icon': Icons.pie_chart,
        'color': Colors.blue,
      },
    ];
  }

  List<Map<String, dynamic>> _generateActiveReports(RentalLoaded state) {
    final activeRentals = state.rentals
        .where((r) => r.status == 'active')
        .toList();
    final totalRevenue = activeRentals.fold<double>(
      0,
      (sum, r) => sum + r.rentalPrice,
    );

    return [
      {
        'title': 'الإيجارات النشطة',
        'description': 'تفاصيل الإيجارات النشطة حالياً',
        'type': 'active',
        'data': {
          'active': activeRentals.length,
          'revenue': _formatCurrency(totalRevenue),
          'types': _getRentalTypeDistribution(activeRentals),
        },
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
    ];
  }

  List<Map<String, dynamic>> _generateExpiredReports(RentalLoaded state) {
    final expiredRentals = state.rentals
        .where((r) => r.status == 'expired')
        .toList();

    return [
      {
        'title': 'الإيجارات المنتهية',
        'description': 'الإيجارات التي انتهت مدتها',
        'type': 'expired',
        'data': {
          'expired': expiredRentals.length,
          'this_month': expiredRentals
              .where((r) => r.endDate.month == DateTime.now().month)
              .length,
          'types': _getRentalTypeDistribution(expiredRentals),
        },
        'icon': Icons.cancel,
        'color': Colors.red,
      },
    ];
  }

  List<Map<String, dynamic>> _generateOverdueReports(RentalLoaded state) {
    final overdueRentals = state.rentals
        .where(
          (r) => r.status == 'active' && r.endDate.isBefore(DateTime.now()),
        )
        .toList();

    return [
      {
        'title': 'الإيجارات المتأخرة',
        'description': 'الإيجارات التي تجاوزت تاريخ الانتهاء',
        'type': 'overdue',
        'data': {
          'overdue': overdueRentals.length,
          'days_overdue': overdueRentals.isNotEmpty
              ? overdueRentals
                  .map((r) => DateTime.now().difference(r.endDate).inDays)
                  .fold(0, (a, b) => a + b)
                  .toString()
              : '0',
          'potential_loss': _formatCurrency(
            overdueRentals.fold<double>(0, (sum, r) => sum + r.rentalPrice),
          ),
        },
        'icon': Icons.schedule,
        'color': Colors.orange,
      },
    ];
  }

  List<Map<String, dynamic>> _generateRevenueReports(RentalLoaded state) {
    final activeRentals = state.rentals
        .where((r) => r.status == 'active')
        .toList();
    final monthlyRevenue = activeRentals.fold<double>(
      0,
      (sum, r) => sum + r.rentalPrice,
    );
    final annualProjection = monthlyRevenue * 12;

    return [
      {
        'title': 'تحليل إيرادات الإيجارات',
        'description': 'تحليل الإيرادات الحالية والمتوقعة',
        'type': 'revenue_analysis',
        'data': {
          'monthly_revenue': _formatCurrency(monthlyRevenue),
          'annual_projection': _formatCurrency(annualProjection),
          'average_rent': activeRentals.isNotEmpty
              ? _formatCurrency(monthlyRevenue / activeRentals.length)
              : _formatCurrency(0),
          'highest_rent': activeRentals.isNotEmpty
              ? _formatCurrency(
                  activeRentals
                      .map((r) => r.rentalPrice)
                      .reduce((a, b) => a > b ? a : b),
                )
              : _formatCurrency(0),
        },
        'icon': Icons.trending_up,
        'color': Colors.green,
      },
    ];
  }

// ⚠️ ملاحظة للمبرمجين المستقبليين: النوع الرسمي للمعلمة هو List<RentalEntity> ولكن يُعلن كـ List<dynamic>;
// هذا يفقد أمان النوع. يُفضل تغيير النوع إلى List<RentalEntity>. rental.itemName يُستخدم بدلاً من propertyType
// لأن الكيان لا يحتوي على propertyType.
  Map<String, int> _getRentalTypeDistribution(List<dynamic> rentals) {
    final distribution = <String, int>{};
    for (final rental in rentals) {
      final type = rental.itemName ?? 'غير محدد';
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
}
