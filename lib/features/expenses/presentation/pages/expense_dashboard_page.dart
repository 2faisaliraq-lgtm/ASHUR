import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/navigation/navigation_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/error_widget.dart';
import '../bloc/expense_bloc.dart';
import '../widgets/expense_drawer.dart';
import '../widgets/expense_filter_chips.dart';
import '../widgets/expense_quick_actions.dart';
import '../widgets/expense_search_bar.dart';
import '../widgets/expense_stats_section.dart';
import '../widgets/expenses_grid.dart';

/// صفحة لوحة تحكم المصاريف
class ExpenseDashboardPage extends StatefulWidget {
  const ExpenseDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<ExpenseDashboardPage> createState() => _ExpenseDashboardPageState();
}

class _ExpenseDashboardPageState extends State<ExpenseDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final PermissionChecker _permissionChecker = PermissionChecker();
  final ScrollController _scrollController = ScrollController();
  String? _selectedFilter;
  // ignore: prefer_final_fields
  bool _isGridView = false;
  bool _canCreate = false;
  late ExpenseBloc _bloc;
  String? _currentOrganizationEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ExpenseBloc>();
    _startRealTimeUpdates();
    // ⚠️ تأجيل تحميل الصلاحيات حتى بعد بناء أول إطار للواجهة
    // لتجنب حظر واجهة المستخدم أثناء انتظار استجابات Firebase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPermissions();
      }
    });
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission('expenses_create');

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا لا نعيد تحميل البيانات عند ظهور الصفحة؟
    // لأن ExpenseBloc بالفعل يعيد تحميل البيانات بعد كل عملية
    // ناجحة (إضافة/تعديل/حذف). إعادة التحميل هنا تزيد من احتمالية
    // حدوث حالة السباق وتسبب عرض إحصائيات فارغة مؤقتاً.
    // ==========================================
  }

  void _startRealTimeUpdates() {
    // التحقق من صحة البريد الإلكتروني
    if (widget.organizationEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: البريد الإلكتروني للمؤسسة غير محدد'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _currentOrganizationEmail = widget.organizationEmail;
    // بدء الاستماع للمصاريف مع التحديث الفوري - أول 20 مصروف فقط
    context.read<ExpenseBloc>().add(
      StartExpensesStreamEvent(widget.organizationEmail, limit: 10),
    );
    // بدء الاستماع للإحصائيات مع التحديث الفوري
    context.read<ExpenseBloc>().add(
      StartExpenseStatsStreamEvent(widget.organizationEmail, limit: null),
    );
  }

  void _loadExpenses() {
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا لا نستدعي _startRealTimeUpdates() هنا؟
    // لأن _startRealTimeUpdates يعيد تشغيل الـ streams مما يزيد
    // من احتمالية حدوث حالة السباق. بدلاً من ذلك، نستخدم
    // StartExpensesStreamEvent و StartExpenseStatsStreamEvent
    // لتحميل البيانات يدوياً فقط عندما نفشل في الحصول على البيانات
    // من الـ streams.
    // ==========================================
    // في الداشبورد، نستخدم Stream مع أول 20 مصروف للأداء
    _currentOrganizationEmail = widget.organizationEmail;
    context.read<ExpenseBloc>().add(
      StartExpensesStreamEvent(widget.organizationEmail, limit: 10),
    );
    context.read<ExpenseBloc>().add(
      StartExpenseStatsStreamEvent(widget.organizationEmail, limit: null),
    );
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopExpensesStreamEvent());
    _bloc.add(const StopExpenseStatsStreamEvent());
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // العودة للداشبورد الرئيسي عند الضغط على زر الرجوع
        NavigationService().setCurrentIndex(0);
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildResponsiveAppBar(context),
        drawer: ExpenseDrawer(
          currentRoute: 'dashboard',
          onAddExpense: () => _navigateToAddExpense(context),
          onSettings: () =>
              Navigator.pushNamed(context, AppRoutes.expensesSettings),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        body: BlocBuilder<ExpenseBloc, ExpenseState>(
          builder: (context, state) {
            if (state is ExpenseError) {
              return AppErrorWidget(
                message: state.message,
                onRetry: _loadExpenses,
              );
            }

            if (state is ExpenseStreamActive) {
              return _buildExpenseContent(context, state);
            }

            if (state is ExpenseLoaded) {
              return _buildExpenseContent(context, state);
            }

            // بناء الهيكل فورًا مع بيانات فارغة أثناء التحميل الأول
            return _buildExpenseContent(
              context,
              const ExpenseLoaded(
                expenses: [],
                filteredExpenses: [],
                selectedFilter: 'all',
                searchQuery: '',
                isGridView: false,
              ),
            );
          },
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                heroTag: 'expenses_dashboard_create_fab',
                onPressed: () => _navigateToAddExpense(context),
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                child: Icon(Icons.add, size: 28.sp),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildExpenseContent(BuildContext context, dynamic state) {
    return RefreshIndicator(
      onRefresh: () async => _loadExpenses(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // قسم الإحصائيات
          SliverToBoxAdapter(
            child: ExpenseStatsSection(
              stats: state.stats,
              onFilterSelected: (filter) => _openExpensesList(context, filter),
            ),
          ),

          // قسم الإجراءات السريعة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ExpenseQuickActions(
                onAddExpense: () => _navigateToAddExpense(context),
                onRefresh: _loadExpenses,
                onSettings: () =>
                    Navigator.pushNamed(context, AppRoutes.expensesSettings),
              ),
            ),
          ),

          // شريط البحث والفلاتر
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  // شريط البحث
                  ExpenseSearchBar(
                    onSearch: (query) {
                      final orgEmail = _currentOrganizationEmail;
                      if (orgEmail != null && orgEmail.isNotEmpty) {
                        context.read<ExpenseBloc>().add(
                          StartExpensesStreamEvent(
                            orgEmail,
                            limit: query.isEmpty ? 20 : null,
                            searchQuery: query.isEmpty ? null : query,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // فلاتر المصاريف
                  ExpenseFilterChips(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (filter) {
                      setState(() => _selectedFilter = filter);
                      context.read<ExpenseBloc>().add(
                        FilterExpensesEvent(filter ?? 'all'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'آخر المصاريف',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AssyrianTheme.deepBlue,
                                fontSize: 13.sp,
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          'آخر ${state.filteredExpenses.length} مصروف',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[600],
                            fontFamily: 'Cairo',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () => _openExpensesList(context, 'all'),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: Text(
                          'عرض الكل',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontFamily: 'Cairo',
                            color: AssyrianTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AssyrianTheme.primaryGold,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      // زر التبديل بين القائمة والشبكة
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AssyrianTheme.primaryGold.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.view_list,
                                size: 18.sp,
                                color: !_isGridView
                                    ? AssyrianTheme.primaryGold
                                    : Colors.grey,
                              ),
                              onPressed: () {
                                if (_isGridView) {
                                  setState(() => _isGridView = false);
                                }
                              },
                              tooltip: 'عرض قائمة',
                              constraints: BoxConstraints(
                                minWidth: 32.w,
                                minHeight: 32.h,
                              ),
                              padding: EdgeInsets.all(4.w),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.grid_view,
                                size: 18.sp,
                                color: _isGridView
                                    ? AssyrianTheme.primaryGold
                                    : Colors.grey,
                              ),
                              onPressed: () {
                                if (!_isGridView) {
                                  setState(() => _isGridView = true);
                                }
                              },
                              tooltip: 'عرض شبكة',
                              constraints: BoxConstraints(
                                minWidth: 32.w,
                                minHeight: 32.h,
                              ),
                              padding: EdgeInsets.all(4.w),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ExpensesGrid(
            expenses: state.filteredExpenses,
            onExpenseTap: (expense) => _showExpenseDetails(context, expense),
            isGridView: _isGridView,
          ),

          // مساحة إضافية في الأسفل للـ FAB
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _openExpensesList(BuildContext context, String filter) {
    Navigator.of(context).pushNamed(AppRoutes.expensesList, arguments: filter);
  }

  void _navigateToAddExpense(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.createExpense);
  }

  void _showExpenseDetails(BuildContext context, expense) {
    Navigator.pushNamed(context, AppRoutes.expenseDetails, arguments: expense);
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
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
                  'إدارة المصاريف',
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
    );
  }
}
