import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_group_entity.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_drawer.dart';

/// صفحة تقارير العملاء
class CustomersReportsPage extends StatefulWidget {
  const CustomersReportsPage({super.key});

  @override
  State<CustomersReportsPage> createState() => _CustomersReportsPageState();
}

class _CustomersReportsPageState extends State<CustomersReportsPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canViewReports = false;
  bool _isLoadingPermissions = true;
  final FormattingService _formattingService = FormattingService();
  String _selectedReportType = 'overview';
  Map<String, dynamic>? _selectedReport;

  final List<Map<String, String>> _reportTypes = const [
    {'id': 'overview', 'title': 'نظرة عامة'},
    {'id': 'subscription_debts', 'title': 'ديون الاشتراكات'},
    {'id': 'stagnant_debts', 'title': 'ديون متعثرة'},
    {'id': 'credit_limit_exceeded', 'title': 'تجاوز حد الدين'},
    {'id': 'sales_analysis', 'title': 'تحليل المبيعات'},
  ];

  // Helper methods for number formatting
  String _formatCurrency(double amount) {
    return _formattingService.formatCurrency(amount);
  }

  String _formatInteger(int number) {
    return _formattingService.formatInteger(number);
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
    _formattingService.initialize();
    _loadData();
  }

  Future<void> _loadPermissions() async {
    final canViewReports = await _permissionChecker.hasPermission(
      'reports_view',
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
    if (user != null) {
      // تحميل العملاء والمجموعات والإحصائيات معاً
      context.read<CustomerBloc>().add(LoadCustomersEvent(user.email!));
    }
  }

  @override
  void dispose() {
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

    // عرض شاشة تفاصيل التقرير إذا كان هناك تقرير محدد
    if (_selectedReport != null) {
      return _buildReportDetailsScreen();
    }

    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const CustomerDrawer(currentRoute: '/customers/reports'),
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
          if (state is CustomerInitial || state is CustomerLoading) {
            return const Center(
              child: LoadingWidget(message: 'جاري تحميل تقارير العملاء...'),
            );
          }

          if (state is CustomerError) {
            return _buildErrorState(state.message);
          }

          if (state is CustomerLoaded || state is CustomerStreamActive) {
            // الحصول على العملاء والإحصائيات والمجموعات من أي من الحالتين
            final customers = state is CustomerLoaded
                ? state.customers
                : (state as CustomerStreamActive).customers;
            final stats = state is CustomerLoaded
                ? state.stats
                : (state as CustomerStreamActive).stats;
            final customerGroups = state is CustomerLoaded
                ? state.customerGroups
                : <CustomerGroupEntity>[];

            // إنشاء CustomerLoaded وهمي للاستخدام في _buildReportsContent
            final loadedState = CustomerLoaded(
              customers: customers,
              filteredCustomers: customers,
              selectedFilter: 'all',
              searchQuery: '',
              stats: stats,
              customerGroups: customerGroups,
              isGridView: false,
            );

            return _buildReportsContent(context, loadedState);
          }

          // شاشة تحميل افتراضية
          return LoadingWidget(message: 'جاري التحميل...');
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
                  'تقارير العملاء',
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
          DropdownButton<String>(
            value: _selectedReportType,
            items: _reportTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type['id'],
                child: Text(
                  type['title']!,
                  style: TextStyle(
                    color: AssyrianTheme.primaryGold,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedReportType = value;
                  _selectedReport = null;
                });
              }
            },
            dropdownColor: AssyrianTheme.deepBlue,
            icon: Icon(
              Icons.analytics,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            underline: Container(),
          ),
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

  Widget _buildReportsContent(BuildContext context, CustomerLoaded state) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(8.w),
      child: _buildReportsGrid(state),
    );
  }

  Widget _buildReportsGrid(CustomerLoaded state) {
    final reports = _generateReports(state);

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minItemWidth = 300;
        final availableWidth = constraints.maxWidth;
        final maxColumns = (availableWidth / minItemWidth).floor().clamp(1, 2);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: maxColumns,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 16.h,
            childAspectRatio: maxColumns == 1 ? 3 : 2.5,
          ),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return _buildReportCard(report);
          },
        );
      },
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: InkWell(
        onTap: () => _viewReportDetails(report),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
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
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          report['title'] as String,
                          style: TextStyle(
                            fontSize: 16.sp,
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
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              if (report['data'] != null)
                Flexible(child: _buildReportData(report['data'])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportData(Map<String, dynamic> data) {
    return Container(
      constraints: BoxConstraints(maxHeight: 60.h),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8.w,
          runSpacing: 4.h,
          children: data.entries.map((entry) {
            // التحقق إذا كان العنصر يحتوي على بيانات عميل
            if (entry.value is Map && entry.value['customer'] != null) {
              final customerData = entry.value as Map<String, dynamic>;
              final customer = customerData['customer'] as dynamic;
              return InkWell(
                onTap: () => _navigateToCustomerDetails(customer),
                borderRadius: BorderRadius.circular(4.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 12.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${customerData['name']}: ${customerData['debt']}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AssyrianTheme.deepBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AssyrianTheme.deepBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateReports(CustomerLoaded state) {
    final reports = <Map<String, dynamic>>[];

    switch (_selectedReportType) {
      case 'overview':
        reports.addAll(_generateOverviewReports(state));
        break;
      case 'subscription_debts':
        reports.add(_generateSubscriptionDebtsReport(state));
        break;
      case 'stagnant_debts':
        reports.add(_generateStagnantDebtsReport(state));
        break;
      case 'credit_limit_exceeded':
        reports.add(_generateCreditLimitExceededReport(state));
        break;
      case 'sales_analysis':
        reports.addAll(_generateSalesAnalysisReports(state));
        break;
    }

    return reports;
  }

  List<Map<String, dynamic>> _generateOverviewReports(CustomerLoaded state) {
    // استخدام الإحصائيات من state.stats إذا كانت متوفرة
    final totalCustomers =
        state.stats?.totalCustomers ?? state.customers.length;
    final activeCustomers =
        state.stats?.activeCustomers ??
        state.customers.where((c) => c.status == 'active').length;
    final newCustomers = state.customers
        .where(
          (c) => c.createdAt.isAfter(
            DateTime.now().subtract(const Duration(days: 30)),
          ),
        )
        .length;
    final totalGroups = state.customerGroups.length;
    final customersWithGroups =
        state.stats?.customersWithGroups ??
        state.customers.where((c) => c.hasGroup).length;
    final customersWithoutGroups =
        state.stats?.customersWithoutGroups ??
        state.customers.where((c) => !c.hasGroup).length;

    // حساب إجمالي الديون (الموجب فقط - ما على العملاء، لا يشمل الدائن)
    final totalDebt = state.customers.fold<double>(
      0,
      (sum, customer) => sum + (customer.totalDebt > 0 ? customer.totalDebt : 0.0),
    );
    // ملاحظة للمبرمجين المستقبليين: يتم حساب totalDebt فقط للقيم الموجبة (الديون المستحقة لنا).
    // لا تشمل القيم السالبة (الدائن) لأن الديون المستحقة علينا لا تُحسب في إجمالي الديون على العملاء.
    final customersWithDebt = state.customers.where((c) => c.hasDebt).length;
    final customersWithCredit = state.customers
        .where((c) => c.hasCredit)
        .length;
    final averageDebt = customersWithDebt > 0
        ? totalDebt / customersWithDebt
        : 0.0;

    return [
      {
        'title': 'تقرير الديون',
        'description': 'إجمالي الديون على العملاء وتفاصيلها',
        'type': 'debt_overview',
        'data': _getDebtCustomersDetails(state),
        'icon': Icons.account_balance_wallet,
        'color': Colors.red,
      },
      {
        'title': 'ديون الاشتراكات',
        'description': 'العملاء الذين عليهم ديون من الاشتراكات',
        'type': 'subscription_debts',
        'data': _getSubscriptionDebtDetails(state),
        'icon': Icons.subscriptions,
        'color': Colors.purple,
      },
      {
        'title': 'ديون متعثرة',
        'description': 'عملاء عليهم ديون منذ أكثر من شهر بدون سداد',
        'type': 'stagnant_debts',
        'data': _getStagnantDebtDetails(state),
        'icon': Icons.warning_amber,
        'color': Colors.deepOrange,
      },
      {
        'title': 'تجاوز حد الدين',
        'description': 'العملاء الذين تجاوزوا حد الائتمان المحدد',
        'type': 'credit_limit_exceeded',
        'data': _getCreditLimitExceededDetails(state),
        'icon': Icons.report_problem,
        'color': Colors.redAccent,
      },
    ];
  }

  Map<String, dynamic> _generateSubscriptionDebtsReport(CustomerLoaded state) {
    return {
      'title': 'ديون الاشتراكات',
      'description': 'العملاء الذين عليهم ديون من الاشتراكات',
      'type': 'subscription_debts',
      'data': _getSubscriptionDebtDetails(state),
      'icon': Icons.subscriptions,
      'color': Colors.purple,
    };
  }

  Map<String, dynamic> _generateStagnantDebtsReport(CustomerLoaded state) {
    return {
      'title': 'ديون متعثرة',
      'description': 'عملاء عليهم ديون منذ أكثر من شهر بدون سداد',
      'type': 'stagnant_debts',
      'data': _getStagnantDebtDetails(state),
      'icon': Icons.warning_amber,
      'color': Colors.deepOrange,
    };
  }

  Map<String, dynamic> _generateCreditLimitExceededReport(
    CustomerLoaded state,
  ) {
    return {
      'title': 'تجاوز حد الدين',
      'description': 'العملاء الذين تجاوزوا حد الائتمان المحدد',
      'type': 'credit_limit_exceeded',
      'data': _getCreditLimitExceededDetails(state),
      'icon': Icons.report_problem,
      'color': Colors.redAccent,
    };
  }

  List<Map<String, dynamic>> _generateSalesAnalysisReports(
    CustomerLoaded state,
  ) {
    final totalPurchases = state.customers.fold<double>(
      0,
      (sum, customer) => sum + customer.totalPurchases,
    );
    final averagePurchases = state.customers.isNotEmpty
        ? totalPurchases / state.customers.length
        : 0.0;

    return [
      {
        'title': 'تحليل المبيعات',
        'description': 'تحليل مبيعات العملاء والمشتريات',
        'type': 'sales_analysis',
        'data': {
          'إجمالي المبيعات': _formatCurrency(totalPurchases),
          'متوسط المشتريات': _formatCurrency(averagePurchases),
          'عدد العملاء': state.customers.length,
        },
        'icon': Icons.trending_up,
        'color': Colors.orange,
      },
    ];
  }

  Map<String, dynamic> _getDebtCustomersDetails(CustomerLoaded state) {
    final debtCustomers = state.customers.where((c) => c.hasDebt).toList()
      ..sort((a, b) => b.totalDebt.compareTo(a.totalDebt));

    // ملاحظة للمبرمجين المستقبليين: يتم حساب totalDebt فقط للقيم الموجبة (الديون المستحقة لنا).
    // لا تشمل القيم السالبة (الدائن) للحفاظ على اتساق الحساب مع المبلغ العام في التقرير.
    final totalDebt = state.customers.fold<double>(
      0,
      (sum, customer) => sum + (customer.totalDebt > 0 ? customer.totalDebt : 0.0),
    );

    final details = <String, dynamic>{
      'إجمالي المدينين': debtCustomers.length,
      'إجمالي الديون': _formatCurrency(totalDebt),
    };

    if (debtCustomers.isNotEmpty) {
      for (int i = 0; i < debtCustomers.length; i++) {
        final customer = debtCustomers[i];
        details['customer_$i'] = {
          'name': customer.name,
          'debt': _formatCurrency(customer.totalDebt),
          'customer': customer,
        };
      }
    }

    return details;
  }

  Map<String, dynamic> _getCreditLimitExceededDetails(CustomerLoaded state) {
    final exceededCustomers =
        state.customers.where((c) {
          return c.exceedsCreditLimit;
        }).toList()..sort((a, b) {
          final aExcess = a.totalDebt - (a.creditLimit ?? 0);
          final bExcess = b.totalDebt - (b.creditLimit ?? 0);
          return bExcess.compareTo(aExcess);
        });

    final totalExcessDebt = exceededCustomers.fold<double>(0, (sum, customer) {
      final excess = customer.totalDebt - (customer.creditLimit ?? 0);
      return sum + excess;
    });

    final details = <String, dynamic>{
      'عملاء تجاوزوا الحد': exceededCustomers.length,
      'إجمالي التجاوز': _formatCurrency(totalExcessDebt),
    };

    if (exceededCustomers.isNotEmpty) {
      for (int i = 0; i < exceededCustomers.length; i++) {
        final customer = exceededCustomers[i];
        final excess = customer.totalDebt - (customer.creditLimit ?? 0);
        details['customer_$i'] = {
          'name': customer.name,
          'debt': _formatCurrency(customer.totalDebt),
          'limit': _formatCurrency(customer.creditLimit ?? 0),
          'excess': _formatCurrency(excess),
          'customer': customer,
        };
      }
    }

    return details;
  }

  Map<String, dynamic> _getStagnantDebtDetails(CustomerLoaded state) {
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

    // ✅ ملاحظة للمبرمجين المستقبليين: يتم استخدام updatedAt لتحديد الديون المتعثرة،
    // ولكن هذا الحقل يُحدَّث عند أي تعديل على بيانات العميل (ليس فقط عند السداد).
    // لتحديد دقيق للديون المتعثرة، يُفضل إضافة حقل lastPaymentDate إلى CustomerEntity
    // واستخدامه هنا بدلاً من updatedAt.
    final stagnantDebtCustomers = state.customers.where((c) {
      return c.hasDebt && c.updatedAt.isBefore(oneMonthAgo);
    }).toList()..sort((a, b) => b.totalDebt.compareTo(a.totalDebt));

    final totalStagnantDebt = stagnantDebtCustomers.fold<double>(
      0,
      (sum, customer) => sum + (customer.totalDebt > 0 ? customer.totalDebt : 0),
    );

    final details = <String, dynamic>{
      'عملاء متعثرين': stagnantDebtCustomers.length,
      'إجمالي الديون المتعثرة': _formatCurrency(totalStagnantDebt),
    };

    if (stagnantDebtCustomers.isNotEmpty) {
      for (int i = 0; i < stagnantDebtCustomers.length; i++) {
        final customer = stagnantDebtCustomers[i];
        final daysSinceUpdate = DateTime.now()
            .difference(customer.updatedAt)
            .inDays;
        details['customer_$i'] = {
          'name': customer.name,
          'debt': _formatCurrency(customer.totalDebt),
          'days': '$daysSinceUpdate يوم',
          'customer': customer,
        };
      }
    }

    return details;
  }

  Map<String, dynamic> _getSubscriptionDebtDetails(CustomerLoaded state) {
    // ✅ ملاحظة للمبرمجين المستقبليين: المعيار الحالي (hasDebt && totalPurchases > 0)
    // غير دقيق لأن totalPurchases قد يشمل مشتريات غير مرتبطة بالاشتراكات.
    // لتحديد دقيق لديون الاشتراكات، يُفضل إضافة حقل hasSubscriptionDebt أو نوع ديون
    // إلى CustomerEntity أو استخدام سجل الفواتير من النوع subscription.
    // حاليًا يُستخدم هذا التقدير كقيمة تقريبية فقط.
    final customersWithSubscriptionDebt = state.customers.where((c) {
      return c.hasDebt && c.totalPurchases > 0;
    }).toList();

    final totalSubscriptionDebt = customersWithSubscriptionDebt.fold<double>(
      0,
      (sum, customer) => sum + (customer.totalDebt > 0 ? customer.totalDebt : 0),
    );

    final details = <String, dynamic>{
      'عملاء عليهم ديون': customersWithSubscriptionDebt.length,
      'إجمالي ديون الاشتراكات': _formatCurrency(totalSubscriptionDebt),
    };

    if (customersWithSubscriptionDebt.isNotEmpty) {
      for (int i = 0; i < customersWithSubscriptionDebt.length; i++) {
        final customer = customersWithSubscriptionDebt[i];
        details['customer_$i'] = {
          'name': customer.name,
          'debt': _formatCurrency(customer.totalDebt),
          'customer': customer,
        };
      }
    }

    return details;
  }

  void _viewReportDetails(Map<String, dynamic> report) {
    setState(() {
      _selectedReport = report;
    });
  }

  Widget _buildReportDetailsScreen() {
    final report = _selectedReport!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() {
            _selectedReport = null;
          });
        }
      },
      child: scaffold.ResponsiveScaffold(
        appBar: AppBar(
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
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            onPressed: () {
              setState(() {
                _selectedReport = null;
              });
            },
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: (report['color'] as Color).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  report['icon'] as IconData,
                  color: report['color'] as Color,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['title'] as String,
                      style: AssyrianTheme.titleStyle.copyWith(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          mobile: 16,
                        ),
                        color: AssyrianTheme.primaryGold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      report['description'] as String,
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
            IconButton(
              onPressed: () => _exportReportToPDF(report),
              icon: Icon(
                Icons.picture_as_pdf,
                color: AssyrianTheme.primaryGold,
                size: 24.sp,
              ),
              tooltip: 'تصدير PDF',
            ),
          ],
        ),
        drawer: const CustomerDrawer(currentRoute: '/customers/reports'),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildReportDataList(
              report['data'] as Map<String, dynamic>,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReportDataList(Map<String, dynamic> data) {
    final widgets = <Widget>[];

    data.forEach((key, value) {
      if (value is Map && value['customer'] != null) {
        final customerData = value as Map<String, dynamic>;
        final customer = customerData['customer'] as dynamic;
        widgets.add(
          InkWell(
            onTap: () => _navigateToCustomerDetails(customer),
            borderRadius: BorderRadius.circular(8.r),
            child: Card(
              margin: EdgeInsets.only(bottom: 8.h),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 20.sp,
                            color: AssyrianTheme.primaryGold,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  customerData['name'] as String,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AssyrianTheme.deepBlue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (customerData['days'] != null)
                                  Text(
                                    customerData['days'] as String,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else if (customerData['limit'] != null)
                                  Text(
                                    'الحد: ${customerData['limit']} | التجاوز: ${customerData['excess']}',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      customerData['debt'] as String,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Card(
            margin: EdgeInsets.only(bottom: 8.h),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$key:',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                  Text(
                    _formatValue(value),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.primaryGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    });

    return widgets;
  }

  void _exportToPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تطبيق تصدير ملف PDF قريباً'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportToExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تطبيق تصدير جدول بيانات قريباً'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _printReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تطبيق الطباعة قريباً'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _exportReportToPDF(Map<String, dynamic> report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تصدير تقرير "${report['title']}" إلى PDF'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _navigateToCustomerDetails(dynamic customer) {
    if (customer is CustomerEntity) {
      Navigator.of(
        context,
      ).pushNamed(AppRoutes.customerDetails, arguments: customer);
    }
  }
}
