import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../bloc/expense_bloc.dart';
import '../widgets/expense_drawer.dart';
import '../../domain/entities/expense_entity.dart';

/// صفحة تقارير المصروفات
class ExpensesReportsPage extends StatefulWidget {
  const ExpensesReportsPage({super.key});

  @override
  State<ExpensesReportsPage> createState() => _ExpensesReportsPageState();
}

class _ExpensesReportsPageState extends State<ExpensesReportsPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canViewReports = false;
  bool _isLoadingPermissions = true;
  final TextEditingController _searchController = TextEditingController();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReportType = 'overview';
  bool _isFilterExpanded = false;
  bool _hasCustomDateRange = false; // يُصبح true عندما يحدد المستخدم نطاقاً زمنياً بشكل صريح

  // Helper methods for number formatting
  String _formatCurrency(double amount) {
    return '${NumberFormat('#,###', 'en_US').format(amount)} د.ع';
  }

  String _formatPercentage(double percentage) {
    return '${NumberFormat('#,##0.0', 'en_US').format(percentage)}%';
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData();
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
    if (user != null && user.email != null) {
      context.read<ExpenseBloc>().add(LoadExpensesEvent(user.email!));
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
      drawer: const ExpenseDrawer(currentRoute: '/expenses/reports'),
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
          if (state is ExpenseInitial || state is ExpenseLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(
                    message: 'جاري تحميل تقارير المصروفات...',
                  ),
                ),
              ],
            );
          }

          if (state is ExpenseError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (state is ExpenseLoaded) {
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
                  'تقارير المصروفات',
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
              _buildFilterChip('حسب الفئة', 'by_category'),
              _buildFilterChip('الشهرية', 'monthly'),
              _buildFilterChip('المعلقة', 'pending'),
              _buildFilterChip('مقارنة الفترات', 'comparison'),
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
                          DateFormat('yyyy/MM/dd').format(_startDate),
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
                          DateFormat('yyyy/MM/dd').format(_endDate),
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

  Widget _buildReportsContent(BuildContext context, ExpenseLoaded state) {
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

  Widget _buildStatisticsCard(ExpenseLoaded state) {
    final now = DateTime.now();
    final totalExpenses = state.expenses.length;
    final thisMonthExpenses = state.expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .length;
    final totalAmount = state.expenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );
    final pendingExpenses = state.expenses
        .where((e) => e.status == 'pending')
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
                  'إحصائيات المصروفات',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            LayoutBuilder(
              builder: (context, constraints) {
                const double minItemWidth = 150;
                final availableWidth = constraints.maxWidth;
                final maxColumns = (availableWidth / minItemWidth)
                    .floor()
                    .clamp(2, 4);

                final items = [
                  _buildStatItem(
                    'إجمالي المصروفات',
                    totalExpenses.toString(),
                    Icons.receipt_long,
                    AssyrianTheme.deepBlue,
                  ),
                  _buildStatItem(
                    'هذا الشهر',
                    thisMonthExpenses.toString(),
                    Icons.calendar_month,
                    Colors.blue,
                  ),
                  _buildStatItem(
                    'المبلغ الإجمالي',
                    _formatCurrency(totalAmount),
                    Icons.attach_money,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'المعلقة',
                    pendingExpenses.toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                ];

                if (maxColumns >= 4) {
                  // Display all 4 items in one row
                  return Row(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        Expanded(child: items[i]),
                        if (i < items.length - 1) SizedBox(width: 8.w),
                      ],
                    ],
                  );
                } else {
                  // Display in 2x2 grid
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: items[0]),
                          SizedBox(width: 8.w),
                          Expanded(child: items[1]),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(child: items[2]),
                          SizedBox(width: 8.w),
                          Expanded(child: items[3]),
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
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
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

  List<Map<String, dynamic>> _generateReports(ExpenseLoaded state) {
    final reports = <Map<String, dynamic>>[];

    switch (_selectedReportType) {
      case 'overview':
        reports.addAll(_generateOverviewReports(state));
        break;
      case 'by_category':
        reports.addAll(_generateCategoryReports(state));
        break;
      case 'monthly':
        reports.addAll(_generateMonthlyReports(state));
        break;
      case 'pending':
        reports.addAll(_generatePendingReports(state));
        break;
      case 'comparison':
        reports.addAll(_generateComparisonReports(state));
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

  List<Map<String, dynamic>> _generateOverviewReports(ExpenseLoaded state) {
    return [
      {
        'title': 'تقرير المصروفات الشامل',
        'description': 'نظرة عامة على جميع المصروفات في النظام',
        'type': 'overview',
        'data': {
          'total': state.expenses.length,
          'amount': _formatCurrency(
            state.expenses.fold<double>(0, (sum, e) => sum + e.amount),
          ),
          'this_month': state.expenses
              .where((e) => e.date.month == DateTime.now().month && e.date.year == DateTime.now().year)
              .length,
        },
        'icon': Icons.money_off,
        'color': AssyrianTheme.deepBlue,
      },
      {
        'title': 'تقرير حالة المصروفات',
        'description': 'توزيع المصروفات حسب الحالة',
        'type': 'status',
        'data': {
          'approved': state.expenses
              .where((e) => e.status == 'approved')
              .length,
          'pending': state.expenses.where((e) => e.status == 'pending').length,
          'rejected': state.expenses
              .where((e) => e.status == 'rejected')
              .length,
        },
        'icon': Icons.pie_chart,
        'color': Colors.blue,
      },
    ];
  }

  List<Map<String, dynamic>> _generateCategoryReports(ExpenseLoaded state) {
    final categoryExpenses = <String, List<dynamic>>{};
    for (final expense in state.expenses) {
      final category = expense.category;
      if (categoryExpenses[category] == null) {
        categoryExpenses[category] = [];
      }
      categoryExpenses[category]!.add(expense);
    }

    return [
      {
        'title': 'المصروفات حسب الفئة',
        'description': 'توزيع المصروفات على الفئات المختلفة',
        'type': 'by_category',
        'data': {
          'categories': categoryExpenses.length,
          'top_category': categoryExpenses.isNotEmpty
              ? categoryExpenses.entries
                    .reduce((a, b) => a.value.length > b.value.length ? a : b)
                    .key
              : 'لا توجد فئات',
          'total_amount': _formatCurrency(
            state.expenses.fold<double>(0, (sum, e) => sum + e.amount),
          ),
        },
        'icon': Icons.category,
        'color': Colors.orange,
      },
    ];
  }

  List<Map<String, dynamic>> _generateMonthlyReports(ExpenseLoaded state) {
    // استخدام نطاق التاريخ المحدد من قبل المستخدم إذا كان متاحاً،
    // وإلا استخدام الشهر الحالي
    final now = DateTime.now();

    // إذا تم تحديد نطاق تاريخ مخصص بشكل صريح، استخدمه؛ وإلا استخدم الشهر الحالي
    final hasCustomRange = _hasCustomDateRange;

    final filteredExpenses = hasCustomRange
        ? _filterExpensesByDateRange(state.expenses, _startDate, _endDate)
        : state.expenses
            .where((e) => e.date.month == now.month && e.date.year == now.year)
            .toList();

    final thisMonthAmount = filteredExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );

    return [
      {
        'title': 'المصروفات الشهرية',
        'description': hasCustomRange
            ? 'مصروفات النطاق الزمني المحدد'
            : 'مصروفات الشهر الحالي',
        'type': 'monthly',
        'data': {
          'this_month': filteredExpenses.length,
          'amount': _formatCurrency(thisMonthAmount),
          'average_daily': filteredExpenses.isNotEmpty
              ? _formatCurrency(
                  thisMonthAmount /
                      _getDaysInRange(hasCustomRange, _startDate, _endDate),
                )
              : _formatCurrency(0),
        },
        'icon': Icons.calendar_month,
        'color': Colors.green,
      },
    ];
  }

  /// تصفية المصروفات حسب نطاق التاريخ (تجنب مشكلات تحليل المحللات في دوال الإغلاق)
  List<ExpenseEntity> _filterExpensesByDateRange(
    List<ExpenseEntity> expenses,
    DateTime startDate,
    DateTime endDate,
  ) {
    final result = <ExpenseEntity>[];
    for (final expense in expenses) {
      final d = expense.date;
      if (!d.isBefore(startDate) && !d.isAfter(endDate)) {
        result.add(expense);
      }
    }
    return result;
  }

  /// حساب عدد الأيام في النطاق المحدد أو الشهر الحالي
  int _getDaysInRange(bool hasCustomRange, DateTime startDate, DateTime endDate) {
    if (hasCustomRange) {
      return endDate.difference(startDate).inDays + 1;
    }
    return DateTime.now().day;
  }

  List<Map<String, dynamic>> _generatePendingReports(ExpenseLoaded state) {
    final pendingExpenses = state.expenses
        .where((e) => e.status == 'pending')
        .toList();

    return [
      {
        'title': 'المصروفات المعلقة',
        'description': 'المصروفات التي تحتاج إلى موافقة',
        'type': 'pending',
        'data': {
          'pending': pendingExpenses.length,
          'amount': _formatCurrency(
            pendingExpenses.fold<double>(0, (sum, e) => sum + e.amount),
          ),
          'oldest': pendingExpenses.isNotEmpty
              ? DateTime.now()
                    .difference(
                      pendingExpenses
                          .map((e) => e.date)
                          .reduce((a, b) => a.isBefore(b) ? a : b),
                    )
                    .inDays
                    .toString()
              : '0',
        },
        'icon': Icons.pending,
        'color': Colors.orange,
      },
    ];
  }

  List<Map<String, dynamic>> _generateComparisonReports(ExpenseLoaded state) {
    // استخدام نطاق التاريخ المخصص إذا كان متاحاً،وإلا مقارنة الشهر الحالي بالسابق
    final hasCustomRange = _hasCustomDateRange;

    if (hasCustomRange) {
      final customExpenses =
          _filterExpensesByDateRange(state.expenses, _startDate, _endDate);
      final customAmount =
          customExpenses.fold<double>(0, (sum, e) => sum + e.amount);

      // حساب الفترة المماثلة السابقة للنطاق المخصص للمقارنة
      final durationDays = _endDate.difference(_startDate).inDays + 1;
      final lastPeriodEnd = _startDate.subtract(const Duration(days: 1));
      final lastPeriodStart = lastPeriodEnd.subtract(
        Duration(days: durationDays - 1),
      );
      final lastPeriodExpenses =
          _filterExpensesByDateRange(state.expenses, lastPeriodStart, lastPeriodEnd);
      final lastPeriodAmount =
          lastPeriodExpenses.fold<double>(0, (sum, e) => sum + e.amount);
      final difference = customAmount - lastPeriodAmount;
      final percentage = lastPeriodAmount > 0
          ? ((difference / lastPeriodAmount) * 100)
          : 0.0;

      return [
        {
          'title': 'مقارنة الفترات',
          'description': 'مقارنة المصروفات في النطاق الزمني المحدد',
          'type': 'comparison',
          'data': {
            'this_month': _formatCurrency(customAmount),
            'last_month': _formatCurrency(lastPeriodAmount),
            'difference': _formatCurrency(difference),
            'percentage': _formatPercentage(percentage),
          },
          'icon': Icons.compare_arrows,
          'color': Colors.purple,
        },
      ];
    }

    final now = DateTime.now();
    final thisMonth = now.month;
    final thisYear = now.year;
    final lastMonth = thisMonth == 1 ? 12 : thisMonth - 1;
    final lastYear = lastMonth == 12 ? thisYear - 1 : thisYear;

    final thisMonthExpenses = state.expenses
        .where((e) => e.date.month == thisMonth && e.date.year == thisYear)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final lastMonthExpenses = state.expenses
        .where((e) => e.date.month == lastMonth && e.date.year == lastYear)
        .fold<double>(0, (sum, e) => sum + e.amount);

    return [
      {
        'title': 'مقارنة الفترات',
        'description': 'مقارنة المصروفات بين الشهر الحالي والسابق',
        'type': 'comparison',
        'data': {
          'this_month': _formatCurrency(thisMonthExpenses),
          'last_month': _formatCurrency(lastMonthExpenses),
          'difference': _formatCurrency(thisMonthExpenses - lastMonthExpenses),
          'percentage': lastMonthExpenses > 0
              ? _formatPercentage(
                  ((thisMonthExpenses - lastMonthExpenses) /
                          lastMonthExpenses) *
                      100,
                )
              : _formatPercentage(0),
        },
        'icon': Icons.compare_arrows,
        'color': Colors.purple,
      },
    ];
  }

  Widget _buildReportPreview(Map<String, dynamic> report) {
    final data = report['data'] as Map<String, dynamic>;

    switch (report['type'] as String) {
      case 'overview':
        return Row(
          children: [
            Expanded(
              child: _buildPreviewItem('الإجمالي', data['total'].toString()),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem('المبلغ', '${data['amount']} د.ع'),
            ),
          ],
        );
      case 'monthly':
        return Row(
          children: [
            Expanded(
              child: _buildPreviewItem(
                'هذا الشهر',
                data['this_month'].toString(),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem('المبلغ', '${data['amount']} د.ع'),
            ),
          ],
        );
      case 'comparison':
        return _buildPreviewItem(
          'الفرق',
          '${data['difference']} د.ع (${data['percentage']}%)',
        );
      default:
        final firstEntry = data.entries.first;
        return _buildPreviewItem(firstEntry.key, firstEntry.value.toString());
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
                entry.value.toString(),
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
        _hasCustomDateRange = true;
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
