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
import '../../domain/entities/invoice_entity.dart';
import '../bloc/invoice_bloc.dart';
import '../widgets/invoice_drawer.dart';

/// صفحة تقارير الفواتير
class InvoicesReportsPage extends StatefulWidget {
  const InvoicesReportsPage({super.key});

  @override
  State<InvoicesReportsPage> createState() => _InvoicesReportsPageState();
}

class _InvoicesReportsPageState extends State<InvoicesReportsPage> {
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
  String? _normalizedEmail; // بريد المؤسسة للاستخدام في الستريم والبحث

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

  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// هذه الدالة تقوم بفلترة الفواتير حسب نطاق التاريخ المحدد في الصفحة.
  /// يجب استخدامها في جميع دوال الإحصائيات والتقارير لضمان
  /// أن الإحصائيات المعروضة تتوافق مع الفلتر الزمني المحدد من المستخدم.
  List<InvoiceEntity> _getFilteredInvoices(InvoiceLoaded state) {
    return state.invoices.where((invoice) {
      return invoice.invoiceDate.isAfter(
            _startDate.subtract(const Duration(seconds: 1)),
          ) &&
          invoice.invoiceDate.isBefore(
            _endDate.add(const Duration(days: 1)),
          );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData();
  }

  Future<void> _loadPermissions() async {
    final canViewReports = await _permissionChecker.hasPermission(
      'invoices_reports_view',
    );
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
      final emailService = EmailNormalizationService();
      _normalizedEmail = emailService.normalize(user.email!);
      // استخدام Stream لتحميل جميع الفواتير من السيرفر للتنبيهات والبحث
      context.read<InvoiceBloc>().add(
        StartInvoicesStreamEvent(
          _normalizedEmail!,
          limit: null, // جلب جميع الفواتير، وليس فقط أول 1000
          searchQuery: _searchController.text.isNotEmpty
              ? _searchController.text
              : null,
        ),
      );
    }
  }

  @override
  void dispose() {
    // ⚠️ تم الإصلاح: إيقاف ستريم الفواتير لتجنب تسريب StreamSubscription
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      context.read<InvoiceBloc>().add(
        const StopInvoicesStreamEvent(),
      );
    }
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
      drawer: const InvoiceDrawer(currentRoute: 'reports'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<InvoiceBloc, InvoiceState>(
        listener: (context, state) {
          if (state is InvoiceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is InvoiceInitial || state is InvoiceLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(
                    message: 'جاري تحميل تقارير الفواتير...',
                  ),
                ),
              ],
            );
          }

          if (state is InvoiceError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (state is InvoiceLoaded) {
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
                  'تقارير الفواتير',
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
                      if (_normalizedEmail != null &&
                          _normalizedEmail!.isNotEmpty) {
                        context.read<InvoiceBloc>().add(
                          StartInvoicesStreamEvent(
                            _normalizedEmail!,
                            limit: null,
                            searchQuery:
                                value.isNotEmpty ? value : null,
                          ),
                        );
                      }
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
              _buildFilterChip('الفواتير المدفوعة', 'paid'),
              _buildFilterChip('الفواتير المعلقة', 'pending'),
              _buildFilterChip('تحليل المبيعات', 'sales_analysis'),
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

  Widget _buildReportsContent(BuildContext context, InvoiceLoaded state) {
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

  Widget _buildStatisticsCard(InvoiceLoaded state) {
    final filteredInvoices = _getFilteredInvoices(state);

    final totalInvoices = filteredInvoices.length;
    final paidInvoices = filteredInvoices.where((i) => i.status == 'paid').length;
    final pendingInvoices = filteredInvoices
        .where((i) => i.status == 'unpaid')
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
                  'إحصائيات الفواتير',
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
                    'إجمالي الفواتير',
                    _formattingService.formatInteger(totalInvoices),
                    Icons.receipt,
                    AssyrianTheme.deepBlue,
                  ),
                  _buildStatItem(
                    'الفواتير المدفوعة',
                    _formattingService.formatInteger(paidInvoices),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'المعلقة',
                    _formattingService.formatInteger(pendingInvoices),
                    Icons.pending,
                    Colors.orange,
                  ),
                ];

                // إذا كان بإمكان عرض 4 عناصر في سطر واحد
                if (maxColumns >= 4) {
                  // إضافة عنصر رابع للإجمالي المتبقي
                  final statItems4 = [
                    ...statItems,
                    _buildStatItem(
                      'المتبقي',
                      _formattingService.formatInteger(
                        filteredInvoices.fold<int>(0, (sum, i) => sum + i.calculateRemainingAmount().toInt()),
                      ),
                      Icons.account_balance_wallet,
                      Colors.orange,
                    ),
                  ];
                  return Row(
                    children: [
                      Expanded(child: statItems4[0]),
                      SizedBox(width: 8.w),
                      Expanded(child: statItems4[1]),
                      SizedBox(width: 8.w),
                      Expanded(child: statItems4[2]),
                      SizedBox(width: 8.w),
                      Expanded(child: statItems4[3]),
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
                          const SizedBox.shrink(),
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
                'المدفوعة',
                _formattingService.formatInteger(data['paid'] ?? 0),
              ),
            ),
          ],
        );
      case 'paid':
        return Row(
          children: [
            Expanded(
              child: _buildPreviewItem(
                'مدفوعة',
                _formattingService.formatInteger(data['paid'] ?? 0),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem('المبلغ', '${data['amount']} د.ع'),
            ),
          ],
        );
      case 'sales_analysis':
        return _buildPreviewItem(
          'المبيعات الشهرية',
          '${data['monthly_sales']} د.ع',
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

  List<Map<String, dynamic>> _generateReports(InvoiceLoaded state) {
    final reports = <Map<String, dynamic>>[];

    switch (_selectedReportType) {
      case 'overview':
        reports.addAll(_generateOverviewReports(state));
        break;
      case 'paid':
        reports.addAll(_generatePaidReports(state));
        break;
      case 'pending':
        reports.addAll(_generatePendingReports(state));
        break;
      case 'sales_analysis':
        reports.addAll(_generateSalesReports(state));
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

  List<Map<String, dynamic>> _generateOverviewReports(InvoiceLoaded state) {
    final invoices = _getFilteredInvoices(state);
    return [
      {
        'title': 'تقرير الفواتير الشامل',
        'description': 'نظرة عامة على جميع الفواتير في النظام',
        'type': 'overview',
        'data': {
          'total': invoices.length,
          'paid': invoices.where((i) => i.status == 'paid').length,
          'pending': invoices.where((i) => i.status == 'unpaid').length,
        },
        'icon': Icons.receipt,
        'color': AssyrianTheme.deepBlue,
      },
      {
        'title': 'تقرير حالة الفواتير',
        'description': 'توزيع الفواتير حسب الحالة',
        'type': 'status',
        'data': {
          'paid': invoices.where((i) => i.status == 'paid').length,
          'pending': invoices.where((i) => i.status == 'unpaid').length,
        },
        'icon': Icons.pie_chart,
        'color': Colors.blue,
      },
    ];
  }

  List<Map<String, dynamic>> _generatePaidReports(InvoiceLoaded state) {
    final paidInvoices = _getFilteredInvoices(state)
        .where((i) => i.status == 'paid')
        .toList();
    final totalAmount = paidInvoices.fold<double>(
      0,
      (sum, i) => sum + i.totalAmount,
    );

    return [
      {
        'title': 'الفواتير المدفوعة',
        'description': 'تفاصيل الفواتير المدفوعة',
        'type': 'paid',
        'data': {
          'paid': paidInvoices.length,
          'amount': _formattingService.formatCurrency(totalAmount),
          'this_month': paidInvoices
              .where((i) => i.invoiceDate.year == DateTime.now().year &&
                  i.invoiceDate.month == DateTime.now().month)
              .length,
        },
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
    ];
  }

  List<Map<String, dynamic>> _generatePendingReports(InvoiceLoaded state) {
    final pendingInvoices = _getFilteredInvoices(state)
        .where((i) => i.status == 'unpaid')
        .toList();

    return [
      {
        'title': 'الفواتير المعلقة',
        'description': 'الفواتير التي لم يتم دفعها بعد',
        'type': 'pending',
        'data': {
          'pending': pendingInvoices.length,
          'amount': _formattingService.formatCurrency(
            pendingInvoices.fold<double>(0, (sum, i) => sum + i.totalAmount),
          ),
          'this_week': pendingInvoices
              .where(
                (i) => i.invoiceDate.isAfter(
                  DateTime.now().subtract(const Duration(days: 7)),
                ),
              )
              .length,
        },
        'icon': Icons.pending,
        'color': Colors.orange,
      },
    ];
  }

  List<Map<String, dynamic>> _generateSalesReports(InvoiceLoaded state) {
    final paidInvoices = _getFilteredInvoices(state)
        .where((i) => i.status == 'paid')
        .toList();
    final monthlySales = paidInvoices
        .where((i) => i.invoiceDate.year == DateTime.now().year &&
            i.invoiceDate.month == DateTime.now().month)
        .fold<double>(0, (sum, i) => sum + i.totalAmount.toDouble());
    final averageInvoice = paidInvoices.isNotEmpty
        ? paidInvoices.fold<double>(
                0,
                (sum, i) => sum + i.totalAmount.toDouble(),
              ) /
                paidInvoices.length
        : 0.0;

    return [
      {
        'title': 'تحليل المبيعات',
        'description': 'تحليل المبيعات والإيرادات',
        'type': 'sales_analysis',
        'data': {
          'monthly_sales': _formattingService.formatCurrency(monthlySales),
          'average_invoice': _formattingService.formatCurrency(averageInvoice),
          'total_revenue': _formattingService.formatCurrency(
            paidInvoices.fold<double>(
              0,
              (sum, i) => sum + i.totalAmount.toDouble(),
            ),
          ),
          'best_month': 'الشهر الحالي', // يمكن تحسينه لاحقاً
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

  /// ⚠️ ملاحظة للمبرمجين مستقبلاً: دوال التصدير والطباعة أدناه هياكل أولية
  /// ولا تنفذ أي عملية فعلية حتى الآن. لتنفيذ التصدير الحقيقي:
  /// 1. أضف حزمة الطباعة أو PDF إلى ملف إعدادات المشروع.
  /// 2. استدعِ منطق جمع البيانات من _getFilteredInvoices(state).
  /// 3. استبدل التنفيذ أدناه بتنفيذ فعلي باستخدام الحزمة المضافة.
  /// حتى ذلك الحين، تعرض كل دالة رسالة توضيحية للمستخدم.
  void _exportToPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تصدير ملف PDF غير متوفر بعد — يرجى إضافة حزمة الطباعة وتفعيلها'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _exportToExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تصدير جدول بيانات غير متوفر بعد — يرجى إضافة حزمة التصدير وتفعيلها'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _printReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('الطباعة غير متوفرة بعد — يرجى إضافة حزمة الطباعة وتفعيلها'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }
}
