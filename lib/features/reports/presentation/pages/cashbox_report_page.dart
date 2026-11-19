import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/cashbox_transaction_entity.dart';
import '../bloc/cashbox_bloc.dart';
import '../bloc/cashbox_event.dart';
import '../bloc/cashbox_state.dart';
import '../widgets/report_drawer.dart';

/// صفحة تقرير الصندوق
class CashboxReportPage extends StatefulWidget {
  const CashboxReportPage({super.key});

  @override
  State<CashboxReportPage> createState() => _CashboxReportPageState();
}

class _CashboxReportPageState extends State<CashboxReportPage> {
  final FormattingService _formattingService = FormattingService();
  final TextEditingController _searchController = TextEditingController();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  String _filterType = 'all'; // 'all', 'in', 'out'

  late CashboxBloc _bloc;

  // Pagination
  int _currentPage = 0;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<CashboxBloc>();
    _loadData();
  }

  void _loadData({bool isRefresh = true}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);

      if (isRefresh) {
        _currentPage = 0;
        _hasMore = true;
      }

      _bloc.add(
        LoadCashboxTransactions(
          organizationEmail: normalizedEmail,
          startDate: _startDate,
          endDate: _endDate,
          limit: _pageSize,
          page: _currentPage,
        ),
      );
    }
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    _loadData(isRefresh: false);
  }

  Future<void> _selectStartDate() async {
    final DateTime? startPicked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _startDate,
      helpText: 'اختر تاريخ البداية',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (startPicked != null && mounted) {
      // ⚠️ إذا اختار المستخدم تاريخ بداية بعد تاريخ النهاية، يُعرض تحذير
      // بدلاً من تعديل endDate تلقائيًا دون استئذان المستخدم.
      if (startPicked.isAfter(_endDate)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تاريخ البداية بعد تاريخ النهاية، يرجى تعديل تاريخ النهاية'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      setState(() {
        _startDate = startPicked;
        _loadData();
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? endPicked = await showDatePicker(
      context: context,
      firstDate: _startDate, // لا يمكن اختيار تاريخ قبل تاريخ البداية
      lastDate: DateTime(2100),
      initialDate: _endDate,
      helpText: 'اختر تاريخ النهاية',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (endPicked != null && mounted) {
      setState(() {
        _endDate = endPicked;
        _loadData();
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime? startPicked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _startDate,
      helpText: 'اختر تاريخ البداية',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (startPicked != null && mounted) {
      final DateTime? endPicked = await showDatePicker(
        context: context,
        firstDate: startPicked,
        lastDate: DateTime(2100),
        initialDate: _endDate.isBefore(startPicked) ? startPicked : _endDate,
        helpText: 'اختر تاريخ النهاية',
        cancelText: 'إلغاء',
        confirmText: 'تأكيد',
      );

      if (endPicked != null && mounted) {
        setState(() {
          _startDate = startPicked;
          _endDate = endPicked;
          _loadData();
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(),
      drawer: ReportDrawer(currentRoute: 'cashbox_report'),
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ), // هامش صغير على الجانبين
      body: BlocConsumer<CashboxBloc, CashboxState>(
        listener: (context, state) {
          if (state is CashboxError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            // إعادة ضبط حالة التحميل عند الخطأ
            setState(() => _isLoadingMore = false);
          } else if (state is CashboxLoaded) {
            // ⚠️ التقسيم من الذاكرة الآن (انظر
            // CashboxBloc) — تحديث حالة تحميل
            // المزيد من العدد الكلي للحركات
            // في الفترة بدل التخمين
            setState(() {
              _isLoadingMore = false;
              _hasMore =
                  (_currentPage + 1) * _pageSize < state.totalCount;
            });
          }
        },
        builder: (context, state) {
          if (state is CashboxLoading) {
            return const LoadingWidget(message: 'جاري تحميل تقرير الصندوق...');
          }

          if (state is CashboxError) {
            return _buildErrorState(state.message);
          }

          if (state is CashboxLoaded) {
            return _buildContent(state);
          }

          return const LoadingWidget(message: 'جاري التحميل...');
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
                  'تقرير الصندوق',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                    ),
                    color: AssyrianTheme.primaryGold,
                  ),
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
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
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

  Widget _buildContent(CashboxLoaded state) {
    final filteredTransactions = _filterTransactions(state.transactions);

    return RefreshIndicator(
      onRefresh: () async {
        _loadData();
      },
      child: CustomScrollView(
        slivers: [
          // بطاقة الحساب التراكمي
          SliverToBoxAdapter(child: _buildTotalBalanceCard(state)),

          // ملخص التقرير
          SliverToBoxAdapter(child: _buildReportSummary(state)),

          // فلاتر البحث
          SliverToBoxAdapter(child: _buildFilters()),

          // جدول الحركات
          SliverToBoxAdapter(child: _buildTransactionsHeader()),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < filteredTransactions.length) {
                return _buildTransactionRow(filteredTransactions[index]);
              }
              return null;
            }, childCount: filteredTransactions.length),
          ),

          // زر تحميل المزيد
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: LoadingWidget(message: 'جاري تحميل المزيد...'),
              ),
            )
          else if (filteredTransactions.isNotEmpty && _hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: ElevatedButton.icon(
                  onPressed: _loadMore,
                  icon: Icon(Icons.add, size: 20.sp),
                  label: Text(
                    'تحميل المزيد',
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AssyrianTheme.primaryGold,
                    foregroundColor: AssyrianTheme.deepBlue,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ),

          // مساحة إضافية
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  /// بطاقة الحساب التراكمي الكامل (لا يتأثر بالفترة الزمنية)
  Widget _buildTotalBalanceCard(CashboxLoaded state) {
    return Container(
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AssyrianTheme.primaryGold.withValues(alpha: 0.2),
            AssyrianTheme.primaryGold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: AssyrianTheme.primaryGold,
                size: 32.sp,
              ),
              SizedBox(width: 12.w),
              Text(
                'حساب الصندوق',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            _formattingService.formatNumber(state.balance),
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.primaryGold,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16.sp, color: Colors.blue),
                SizedBox(width: 4.w),
                Text(
                  'حساب تراكمي كامل',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSummary(CashboxLoaded state) {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AssyrianTheme.primaryGold.withValues(alpha: 0.15),
            AssyrianTheme.primaryGold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.summarize,
                    color: AssyrianTheme.primaryGold,
                    size: 24.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'ملخص التقرير',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                ],
              ),
              // زر تحديد الفترة الزمنية
              IconButton(
                onPressed: _selectDateRange,
                icon: Icon(
                  Icons.date_range,
                  color: AssyrianTheme.primaryGold,
                  size: 24.sp,
                ),
                tooltip: 'تحديد الفترة الزمنية',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // الفترة الزمنية - قابلة للنقر
          Row(
            children: [
              // تاريخ البداية
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectStartDate(),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available,
                              color: AssyrianTheme.primaryGold,
                              size: 16.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'من ',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          DateFormat('yyyy/MM/dd').format(_startDate),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.primaryGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // تاريخ الانتهاء
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectEndDate(),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available,
                              color: AssyrianTheme.primaryGold,
                              size: 16.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'إلى ',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          DateFormat('yyyy/MM/dd').format(_endDate),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.primaryGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.arrow_downward,
                  label: 'مجموع الداخل',
                  value: _formattingService.formatNumber(state.totalIn),
                  valueColor: Colors.green,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.arrow_upward,
                  label: 'مجموع الخارج',
                  value: _formattingService.formatNumber(state.totalOut),
                  valueColor: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'صافي التغير',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                Text(
                  '${state.totalIn - state.totalOut >= 0 ? '+' : ''}${_formattingService.formatNumber(state.totalIn - state.totalOut)}',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: state.totalIn - state.totalOut >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16.sp, color: Colors.grey[600]),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AssyrianTheme.deepBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // شريط البحث
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'بحث بالوصف...',
              prefixIcon: Icon(
                Icons.search,
                color: AssyrianTheme.primaryGold,
                size: 20.sp,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
            ),
            onChanged: (value) => setState(() {}),
          ),
          SizedBox(height: 12.h),
          // فلاتر النوع
          Row(
            children: [
              Text(
                'النوع:',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'الكل',
                        value: _filterType == 'all',
                        onTap: () => setState(() => _filterType = 'all'),
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        label: 'داخل',
                        value: _filterType == 'in',
                        onTap: () => setState(() => _filterType = 'in'),
                        color: Colors.green,
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        label: 'خارج',
                        value: _filterType == 'out',
                        onTap: () => setState(() => _filterType = 'out'),
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool value,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: value
              ? (color ?? AssyrianTheme.primaryGold)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: value
                ? (color ?? AssyrianTheme.primaryGold)
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: value ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: AssyrianTheme.primaryGold, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            'تفاصيل الحركات',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(CashboxTransactionEntity transaction) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // أيقونة النوع
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: transaction.type == 'in'
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.type == 'in'
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: transaction.type == 'in' ? Colors.green : Colors.red,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          // التفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4.w,
                  runSpacing: 4.h,
                  children: [
                    Text(
                      _getSourceText(transaction.source),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                    Text(
                      DateFormat(
                        'yyyy/MM/dd HH:mm',
                      ).format(transaction.timestamp),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // المبلغ
          Text(
            transaction.type == 'in'
                ? '+${_formattingService.formatNumber(transaction.amount)}'
                : '-${_formattingService.formatNumber(transaction.amount)}',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: transaction.type == 'in' ? Colors.green : Colors.red,
            ),
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
          Icon(Icons.error_outline, size: 80.sp, color: Colors.red[300]),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
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

  List<CashboxTransactionEntity> _filterTransactions(
    List<CashboxTransactionEntity> transactions,
  ) {
    var filtered = transactions;

    // فلترة حسب النوع
    if (_filterType != 'all') {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }

    // فلترة حسب البحث
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (t) =>
                t.description.toLowerCase().contains(searchQuery) ||
                _getSourceText(t.source).toLowerCase().contains(searchQuery),
          )
          .toList();
    }

    return filtered;
  }

  String _getSourceText(String source) {
    switch (source) {
      case 'invoice':
        return 'فاتورة مبيعات';
      case 'expense':
        return 'مصروفات';
      case 'subscription':
        return 'اشتراك';
      case 'manual':
        return 'حركة يدوية';
      default:
        return source;
    }
  }
}
