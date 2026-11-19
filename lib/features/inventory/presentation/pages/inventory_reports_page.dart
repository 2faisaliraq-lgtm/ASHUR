import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/inventory_drawer.dart';
import '../../domain/repositories/inventory_movement_repository.dart';

/// صفحة تقارير المخزون
class InventoryReportsPage extends StatefulWidget {
  const InventoryReportsPage({super.key});

  @override
  State<InventoryReportsPage> createState() => _InventoryReportsPageState();
}

class _InventoryReportsPageState extends State<InventoryReportsPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canViewReports = false;
  bool _isLoadingPermissions = true;
  final TextEditingController _searchController = TextEditingController();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReportType = 'overview';
  bool _isFilterExpanded = false;
  InventoryBloc? _inventoryBloc;
  Map<String, dynamic>? _movementStats;

  // Helper methods for number formatting
  String _formatInteger(int number) {
    return NumberFormat('#,###', 'en_US').format(number);
  }

  String _formatCurrency(double amount) {
    return '${NumberFormat('#,###', 'en_US').format(amount)} د.ع';
  }

  String _formatPercentage(double percentage) {
    return '${NumberFormat('#,##0.0', 'en_US').format(percentage)}%';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // حفظ مرجع الـ bloc لاستخدامه بأمان في dispose
    _inventoryBloc = context.read<InventoryBloc>();
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData();
    _loadMovementStats();

    // بدء الاستماع للتحديثات الفورية للمنتجات
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      context.read<InventoryBloc>().add(
        StartProductsStreamEvent(
          organizationEmail: user.email!,
        ),
      );
    }
  }

  Future<void> _loadMovementStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    try {
      final repo = GetIt.instance<InventoryMovementRepository>();
      final result = await repo.getMovementsStats(
        organizationEmail: user.email!,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        result.fold(
          // ⚠️ ملاحظة (2026-10-24): أخطاء جلب إحصائيات الحركات تُبلع صامتاً هنا
          // ({}) ولا تُعرض للمستخدم ولا تُسجَّل. إذا احتاج النظام لإظهار
          // خطأ إحصائيات الحركات، أضف setState مع رسالة خطأ أو debugPrint.
          (failure) => {},
          (stats) {
            setState(() {
              _movementStats = stats;
            });
          },
        );
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _movementStats = null;
        });
      }
    }
  }

  Future<void> _loadPermissions() async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: معرف الصلاحية هنا ('inventory_reports_view')
    // يجب أن يطابق ما هو معرّف في inventory_permissions.dart. أي تعديل على
    // الصلاحية هناك يجب أن ينعكس هنا.
    final canViewReports = await _permissionChecker.hasPermission('inventory_reports_view');
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
      context.read<InventoryBloc>().add(
        LoadInventoryData(organizationEmail: user.email!),
      );
    }
    _loadMovementStats();
  }

  @override
  void dispose() {
    // إغلاق bloc عند إغلاق الصفحة لمنع تسريب الاشتراكات (Zombie Streams)
    _inventoryBloc?.add(const StopProductsStreamEvent());
    _inventoryBloc?.close();
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
      drawer: const InventoryDrawer(currentRoute: '/inventory/reports'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is InventoryInitial || state is InventoryLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل تقارير المخزون...'),
                ),
              ],
            );
          }

          if (state is InventoryError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (state is InventoryLoaded) {
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
                  'تقارير المخزون',
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
                      // ⚠️ ملاحظة للمبرمجين المستقبليين: استدعاء setState هنا
                      // ضروري لتحديث واجهة المستخدم عند الكتابة في حقل البحث.
                      // بدون setState، لا يُطبّق فلتر البحث (_filterReports)
                      // لأن واجهة usuario لا تُعاد بناؤها.
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
              _buildFilterChip('المنتجات', 'products'),
              _buildFilterChip('الفئات', 'categories'),
              _buildFilterChip('المخزون المنخفض', 'low_stock'),
              _buildFilterChip('حركة المخزون', 'stock_movement'),
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

  Widget _buildReportsContent(BuildContext context, InventoryLoaded state) {
    final reports = _generateReports(state);
    final filteredReports = _filterReports(reports);

    if (filteredReports.isEmpty) {
      return AppEmptyState(
        icon: Icons.analytics_outlined,
        title: 'لا توجد تقارير متاحة',
        message: 'لا توجد بيانات كافية لإنشاء التقارير',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: filteredReports.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStatisticsCard(state);
        }
        return _buildReportCard(filteredReports[index - 1]);
      },
    );
  }

  Widget _buildStatisticsCard(InventoryLoaded state) {
    final totalProducts = state.filteredProducts.length;
    final lowStockProducts = state.filteredProducts
        .where((p) => p.quantity <= p.minQuantity)
        .length;
    final totalCategories = state.categories.length;
    final totalValue = state.filteredProducts.fold<double>(
      0,
      (sum, p) => sum + p.inventoryValue,
    );

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
                  Icons.inventory,
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
            LayoutBuilder(
              builder: (context, constraints) {
                const double minItemWidth = 150;
                final availableWidth = constraints.maxWidth;
                final maxColumns = (availableWidth / minItemWidth)
                    .floor()
                    .clamp(2, 4);

                final items = [
                  _buildStatItem(
                    'إجمالي المنتجات',
                    _formatInteger(totalProducts),
                    Icons.inventory_2,
                    AssyrianTheme.deepBlue,
                  ),
                  _buildStatItem(
                    'المخزون المنخفض',
                    _formatInteger(lowStockProducts),
                    Icons.warning,
                    Colors.orange,
                  ),
                  _buildStatItem(
                    'الفئات',
                    _formatInteger(totalCategories),
                    Icons.category,
                    Colors.purple,
                  ),
                  _buildStatItem(
                    'القيمة الإجمالية',
                    _formatCurrency(totalValue),
                    Icons.attach_money,
                    Colors.green,
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
                  color: (report['color'] is Color ? report['color'] : AssyrianTheme.deepBlue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                  child: Icon(
                    report['icon'] is IconData ? report['icon'] : Icons.analytics_outlined,
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
                'المنتجات',
                _formatInteger(data['total_products'] ?? 0),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem(
                'المنخفض',
                _formatInteger(data['low_stock'] ?? 0),
              ),
            ),
          ],
        );
      case 'products':
        return Row(
          children: [
            Expanded(
              child: _buildPreviewItem(
                'المنتجات',
                _formatInteger(data['products'] ?? 0),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildPreviewItem('القيمة', '${data['value']} د.ع'),
            ),
          ],
        );
      case 'low_stock':
        return _buildPreviewItem(
          'تحتاج تموين',
          data['low_stock_count'].toString(),
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

  List<Map<String, dynamic>> _generateReports(InventoryLoaded state) {
    final reports = <Map<String, dynamic>>[];

    switch (_selectedReportType) {
      case 'overview':
        reports.addAll(_generateOverviewReports(state));
        break;
      case 'products':
        reports.addAll(_generateProductReports(state));
        break;
      case 'categories':
        reports.addAll(_generateCategoryReports(state));
        break;
      case 'low_stock':
        reports.addAll(_generateLowStockReports(state));
        break;
      case 'stock_movement':
        reports.addAll(_generateStockMovementReports(state));
        break;
    }

    return reports;
  }

  List<Map<String, dynamic>> _generateOverviewReports(InventoryLoaded state) {
    final totalProducts = state.filteredProducts.length;
    final lowStockProducts = state.filteredProducts
        .where((p) => p.quantity <= p.minQuantity)
        .length;
    final totalValue = state.filteredProducts.fold<double>(
      0,
      (sum, p) => sum + p.inventoryValue,
    );

    return [
      {
        'title': 'تقرير المخزون الشامل',
        'description': 'نظرة عامة على جميع منتجات المخزون',
        'type': 'overview',
        'data': {
          'total_products': totalProducts,
          'low_stock': lowStockProducts,
          'total_categories': state.categories.length,
          'total_value': totalValue,
        },
        'icon': Icons.inventory,
        'color': AssyrianTheme.deepBlue,
      },
      {
        'title': 'تقرير القيمة الإجمالية',
        'description': 'قيمة المخزون الحالي بالأسعار الحالية',
        'type': 'overview',
        'data': {
          'total_products': totalProducts,
          'low_stock': lowStockProducts,
          'total_value': totalValue,
        },
        'icon': Icons.attach_money,
        'color': Colors.green,
      },
    ];
  }

  List<Map<String, dynamic>> _generateProductReports(InventoryLoaded state) {
    final totalProducts = state.filteredProducts.length;
    final totalValue = state.filteredProducts.fold<double>(
      0,
      (sum, p) => sum + p.inventoryValue,
    );

    return [
      {
        'title': 'تقرير المنتجات التفصيلي',
        'description': 'قائمة شاملة بجميع المنتجات وتفاصيلها',
        'type': 'products',
        'data': {
          'products': totalProducts,
          'value': _formatCurrency(totalValue),
        },
        'icon': Icons.inventory_2,
        'color': Colors.blue,
      },
    ];
  }

  List<Map<String, dynamic>> _generateCategoryReports(InventoryLoaded state) {
    return [
      {
        'title': 'تقرير الفئات',
        'description': 'توزيع المنتجات حسب الفئات المختلفة',
        'type': 'categories',
        'data': {
          'categories': state.categories.length,
          // ⚠️ ملاحظة للمبرمجين المستقبليين: عندما لا توجد فئات، لا يمكن
          // حساب متوسط المنتجات لكل فئة (القسمة على 1 تعطي نتيجة مضللة
          // تساوي إجمالي المنتجات). نعيد 0.0 في هذه الحالة.
          'products_per_category':
              state.categories.isNotEmpty
                  ? state.filteredProducts.length / state.categories.length
                  : 0.0,
        },
        'icon': Icons.category,
        'color': Colors.purple,
      },
    ];
  }

  List<Map<String, dynamic>> _generateLowStockReports(InventoryLoaded state) {
    final lowStockProducts = state.filteredProducts
        .where((p) => p.quantity <= p.minQuantity)
        .length;

    return [
      {
        'title': 'تقرير المخزون المنخفض',
        'description': 'المنتجات التي تحتاج إعادة تموين',
        'type': 'low_stock',
        'data': {
          'low_stock_count': lowStockProducts,
          'percentage': _formatPercentage(
            (lowStockProducts /
                    (state.products.isNotEmpty ? state.products.length : 1)) *
                100,
          ),
        },
        'icon': Icons.warning,
        'color': Colors.orange,
      },
    ];
  }

  // ⚠️ ملاحظة توثيقية للمبرمجين المستقبليين (تقرير حركة المخزن يعيد أصفاراً):
// سجلات الحركة تُخزَّن في المجموعة العليا inventory_movements وتُكتب
// ذرياً مع تحديث الكمية في ProductRepositoryImpl.updateProductQuantity.
// ولكن تقارير المخزن هنا تُرجع أصفاراً لأن قراءة الحركات من خلال
// InventoryMovementRepository غير مربوطة بواجهة التقارير بعد.
// لتفعيل التقرير الحقيقي: استدعِ InventoryMovementRepository.getMovements
// داخل هذا المنشئ بدلاً من إرجاع أصفار ثابتة.
  // ⚠️ إصلاح (2026-10-20): تقرير حركة المخزن يقرأ الآن البيانات الفعلية من
  // InventoryMovementRepository بدلاً من إرجاع أصفاراً ثابتة.
  List<Map<String, dynamic>> _generateStockMovementReports(
    InventoryLoaded state,
  ) {
    final totalMovements = _movementStats?['totalMovements'] ?? 0;
    final inMovements = _movementStats?['inMovements'] ?? 0;
    final outMovements = _movementStats?['outMovements'] ?? 0;
    final transferMovements = _movementStats?['transferMovements'] ?? 0;

    return [
      {
        'title': 'تقرير حركة المخزون',
        'description': 'تتبع حركة دخول وخروج المنتجات',
        'type': 'stock_movement',
        'data': {
          'total_movements': totalMovements,
          'in_movements': inMovements,
          'out_movements': outMovements,
          'transfer_movements': transferMovements,
        },
        'icon': Icons.swap_horiz,
        'color': Colors.teal,
      },
    ];
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
        _movementStats = null;
      });
      // ⚠️ ملاحظة للمبرمجين المستقبليين: بعد تغيير نطاق التاريخ، يتم تعيين
      // _movementStats إلى null ولكن _loadData() يُستدعى دون انتظار اكتمال
      // تحميل إحصائيات الحركات الجديدة. قد تُعرض الإحصائيات القديمة أو فارغة
      // حتى يكتمل الاستدعاء غير المتزامن. يُنصح بتحديث _movementStats بعد
      // انتهاء _loadMovementStats أو استخدام FutureBuilder لعرض حالة التحميل.
      _loadData();
    }
  }

  void _exportToPDF() {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: دالة تصدير PDF غير مطبقة بعد،
    // تُظهر فقط رسالة "سيتم تنفيذ تصدير PDF قريباً". عند التنفيذ الفعلي
    // تأكد من استخدام البيانات الفعلية من _movementStats ومن حالة التقارير
    // الحالية بدلاً من إرجاع رسالة وهمية.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ تصدير ملف PDF قريباً'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportToExcel() {
    // ⚠️ ملاحظة للمبرمجين مستقبلاً: دالة تصدير جدول البيانات غير مطبقة بعد،
    // وتعرض فقط رسالة تفيد بأن التصدير سيُنفذ قريباً. عند التنفيذ الفعلي
    // تأكد من استخدام البيانات الفعلية من _movementStats ومن حالة التقارير
    // الحالية بدلاً من إرجاع رسالة وهمية.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ تصدير جدول بيانات قريباً'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _printReport() {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: دالة الطباعة غير مطبقة بعد،
    // تُظهر فقط رسالة "سيتم تنفيذ الطباعة قريباً". عند التنفيذ الفعلي
    // تأكد من استخدام البيانات الفعلية من _movementStats ومن حالة التقارير
    // الحالية بدلاً من إرجاع رسالة وهمية.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ الطباعة قريباً'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
