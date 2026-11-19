import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/smart_number_formatter.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/cashbox_transaction_entity.dart';
import '../bloc/cashbox_bloc.dart';
import '../bloc/cashbox_event.dart';
import '../bloc/cashbox_state.dart';
import '../widgets/report_drawer.dart';

/// صفحة الصندوق الرئيسية
class CashboxPage extends StatefulWidget {
  const CashboxPage({super.key});

  @override
  State<CashboxPage> createState() => _CashboxPageState();
}

class _CashboxPageState extends State<CashboxPage> {
  final FormattingService _formattingService = FormattingService();
  final PermissionChecker _permissionChecker = PermissionChecker();

  bool _canView = false;
  bool _canManage = false;
  bool _isLoadingPermissions = true;

  late CashboxBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<CashboxBloc>();
    _loadPermissions();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadData(forceRefresh: true);
      }
    });
  }

  Future<void> _loadPermissions() async {
    final canView = await _permissionChecker.hasPermission('cashbox_view');
    final canManage = await _permissionChecker.hasPermission('cashbox_manage');

    if (mounted) {
      setState(() {
        _canView = canView;
        _canManage = canManage;
        _isLoadingPermissions = false;
      });
    }
  }

  void _loadData({bool forceRefresh = false}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);

      // تعيين تاريخ اليوم
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      _bloc.add(LoadCashboxBalance(organizationEmail: normalizedEmail));
      _bloc.add(
        LoadCashboxTransactions(
          organizationEmail: normalizedEmail,
          startDate: startOfDay,
          endDate: endOfDay,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions) {
      return scaffold.ResponsiveScaffold(
        appBar: AppBar(),
        body: LoadingWidget(message: 'جاري التحميل...'),
      );
    }

    if (!_canView) {
      return scaffold.ResponsiveScaffold(
        appBar: AppBar(title: const Text('الصندوق')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80.sp, color: Colors.grey[400]),
              SizedBox(height: 16.h),
              Text(
                'ليس لديك صلاحية عرض الصندوق',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(),
      drawer: ReportDrawer(currentRoute: 'cashbox'),
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
          } else if (state is CashboxSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            // ⚠️ لا حاجة لـ _loadData() — ستريمات
            // الصندوق تُحدِّث البيانات تلقائياً
            // بعد كل عملية (انظر CashboxBloc)
          }
        },
        builder: (context, state) {
          if (state is CashboxLoading) {
            return const LoadingWidget(message: 'جاري تحميل بيانات الصندوق...');
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
      floatingActionButton: _canManage
          ? FloatingActionButton(
              heroTag: 'cashbox_add_fab',
              onPressed: () => _showTransactionDialog('in'),
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
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
                  'إدارة الصندوق',
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
    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: CustomScrollView(
        slivers: [
          // بطاقة الحساب التراكمي (لا يتأثر بالتاريخ)
          SliverToBoxAdapter(child: _buildTotalBalanceCard(state)),

          // بطاقة ملخص التقرير للفترة المحددة
          SliverToBoxAdapter(child: _buildPeriodSummaryCard(state)),

          // أزرار الإجراءات
          if (_canManage) SliverToBoxAdapter(child: _buildActionButtons(state)),

          // عنوان الحركات
          SliverToBoxAdapter(child: _buildTransactionsHeader()),

          // قائمة الحركات
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < state.transactions.length) {
                return _buildTransactionTile(state.transactions[index]);
              }
              return null;
            }, childCount: state.transactions.length),
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

  /// بطاقة ملخص التقرير للفترة المحددة (الداخل، الخارج، الصافي)
  Widget _buildPeriodSummaryCard(CashboxLoaded state) {
    final netChange = state.totalIn - state.totalOut;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AssyrianTheme.deepBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.summarize,
                color: AssyrianTheme.primaryGold,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'ملخص التقرير',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // تاريخ اليوم
          Text(
            'اليوم ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),
          // الداخل والخارج
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  label: '+ الداخل',
                  value: _formattingService.formatNumber(state.totalIn),
                  icon: Icons.arrow_downward,
                  color: Colors.green,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildSummaryItem(
                  label: '- الخارج',
                  value: _formattingService.formatNumber(state.totalOut),
                  icon: Icons.arrow_upward,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(color: Colors.grey[300], thickness: 1),
          SizedBox(height: 8.h),
          // صافي التغيير
          _buildNetChangeItem(netChange),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetChangeItem(double netChange) {
    final isPositive = netChange >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: color,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'صافي التغيير',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            '${isPositive ? '+' : ''}${_formattingService.formatNumber(netChange)}',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(CashboxLoaded state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showTransactionDialog('in'),
              icon: Icon(Icons.add, size: 20.sp),
              label: Text('إضافة مبلغ', style: TextStyle(fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showTransactionDialog('out'),
              icon: Icon(Icons.remove, size: 20.sp),
              label: Text('سحب مبلغ', style: TextStyle(fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'آخر الحركات',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/reports/cashbox/report');
            },
            child: const Text('عرض الكل'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(CashboxTransactionEntity transaction) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
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
      child: ListTile(
        contentPadding: EdgeInsets.all(12.w),
        leading: CircleAvatar(
          backgroundColor: transaction.type == 'in'
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          child: Icon(
            transaction.type == 'in'
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            color: transaction.type == 'in' ? Colors.green : Colors.red,
            size: 24.sp,
          ),
        ),
        title: Text(
          transaction.description,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              _getSourceText(transaction.source),
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 2.h),
            Text(
              DateFormat('yyyy/MM/dd HH:mm').format(transaction.timestamp),
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Text(
          transaction.type == 'in'
              ? '+${_formattingService.formatNumber(transaction.amount)}'
              : '-${_formattingService.formatNumber(transaction.amount)}',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: transaction.type == 'in' ? Colors.green : Colors.red,
          ),
        ),
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

  void _showTransactionDialog(String type) {
    final bloc = context.read<CashboxBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: bloc,
        child: CashboxTransactionDialog(type: type),
      ),
    );
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

/// حوار إضافة/سحب مبلغ من الصندوق
class CashboxTransactionDialog extends StatefulWidget {
  const CashboxTransactionDialog({required this.type, super.key});

  final String type; // 'in' أو 'out'

  @override
  State<CashboxTransactionDialog> createState() =>
      _CashboxTransactionDialogState();
}

class _CashboxTransactionDialogState extends State<CashboxTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final FormattingService _formattingService = FormattingService();

  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdd = widget.type == 'in';
    final primaryColor = isAdd ? Colors.green : Colors.red;
    final icon = isAdd ? Icons.add_circle : Icons.remove_circle;
    final title = isAdd ? 'إضافة مبلغ للصندوق' : 'سحب مبلغ من الصندوق';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: primaryColor, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // حقل المبلغ
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [_formattingService.getPriceInputFormatter()],
              decoration: InputDecoration(
                labelText: 'المبلغ',
                hintText: _formattingService.formatCurrency(0),
                prefixIcon: Icon(
                  Icons.money,
                  color: AssyrianTheme.primaryGold,
                  size: 24.sp,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: AssyrianTheme.primaryGold,
                    width: 2,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال المبلغ';
                }
                // إزالة التنسيق قبل التحقق
                final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
                if (cleanValue.isEmpty) {
                  return 'يرجى إدخال المبلغ';
                }
                final amount =
                    double.parse(cleanValue) /
                    100; // القسمة على 100 لإزالة المنازل العشرية
                if (amount <= 0) {
                  return 'المبلغ يجب أن يكون أكبر من صفر';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),

            // حقل الوصف
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'الوصف (اختياري)',
                hintText: 'اكتب سبب الإضافة/السحب...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: AssyrianTheme.primaryGold,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          ),
          child: Text(
            'إلغاء',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: _isLoading
              ? LoadingWidget(size: 16)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isAdd ? Icons.add : Icons.remove, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text(
                      isAdd ? 'إضافة' : 'سحب',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('المستخدم غير مسجل دخول');

      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);

      // إزالة التنسيق وتحويل إلى رقم
      final textAmount = SmartNumberFormatter.convertToEnglishNumbers(
        _amountController.text,
      );
      final cleanAmount = textAmount
          .replaceAll(_formattingService.thousandsSeparator, '')
          .replaceAll(_formattingService.decimalSeparator, '.');
      final amount = double.parse(cleanAmount);

      final description = _descriptionController.text.trim().isEmpty
          ? (widget.type == 'in' ? 'إضافة يدوية' : 'سحب يدوي')
          : _descriptionController.text.trim();

      // ⚠️ تنفيذ العملية الذرية مباشرة من الـ repository وانتظار
      // نتيجتها قبل إغلاق الحوار (نفس نمط DeleteReportDialog) —
      // كان يُضاف الحدث ويُغلق الحوار فوراً مع عرض نجاح
      // كاذب قبل اكتمال الـ WriteBatch، فإذا فشلت العملية
      // الذرية (شبكة/صلاحيات) ظهر النجاح ولم تُحفظ الحركة
      // ولا يُحدَّث الرصيد (نفس سبب صفحات الإنشاء/التعديل —
      // انظر _onAddReport وسجل الذرية في
      // report_repository_impl.dart). الحركة والرصيد يُحفظان
      // معاً أو لا يُحفظا — لا يُعرض النجاح إلا بعد تأكيد
      // اكتمالهما، وعند الفشل تبقى البيانات كما هي ويُعرض
      // الخطأ دون إغلاق الحوار لإعادة المحاولة.
      await context.read<CashboxBloc>().repository.recordManualTransaction(
        organizationEmail: normalizedEmail,
        type: widget.type,
        amount: amount,
        description: description,
        createdBy: user.email!,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.type == 'in' ? 'تمت الإضافة بنجاح' : 'تم السحب بنجاح',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on Exception catch (_) {
      // فشل العملية الذرية — لا حركة ولا تغيير رصيد
      // (كل شيء أو لا شيء) — الحوار يبقى مفتوحاً
      // لإعادة المحاولة ولا يُعرض نجاح كاذب
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: يرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
