import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repositories/expense_repository.dart';
import '../bloc/expense_bloc.dart';
import '../widgets/delete_expense_dialog.dart';
import '../widgets/expense_drawer.dart';

/// صفحة عرض جميع المصاريف
class ExpensesListPage extends StatefulWidget {
  const ExpensesListPage({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  State<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends State<ExpensesListPage> {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final TextEditingController _searchController = TextEditingController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  final ScrollController _scrollController = ScrollController();
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canViewReports = false;
  bool _waitingForInitialFilterData = false;
  late ExpenseBloc _bloc; // حفظ reference للـ bloc

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
      _waitingForInitialFilterData = true;
    }
    // حفظ reference للـ bloc
    _bloc = context.read<ExpenseBloc>();
    if (_selectedFilter != 'all') {
      _bloc.add(FilterExpensesEvent(_selectedFilter));
    }
    _scrollController.addListener(_onScroll);
    _loadExpensesPaginated();
    _loadPermissions();
    _startRealTimeUpdates();
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission('expenses_create');
    final canEdit = await _permissionChecker.hasPermission('expenses_edit');
    final canDelete = await _permissionChecker.hasPermission('expenses_delete');
    final canViewReports = await _permissionChecker.hasPermission(
      'reports_view',
    );

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
        _canViewReports = canViewReports;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    final hasMore = state is ExpenseLoaded
        ? state.hasMore
        : state is ExpenseStreamActive
        ? state.hasMore
        : false;
    final isLoadingMore = state is ExpenseLoaded
        ? state.isLoadingMore
        : state is ExpenseStreamActive
        ? state.isLoadingMore
        : false;
    if (!hasMore || isLoadingMore) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _bloc.add(LoadMoreExpensesEvent(user.email!));
    }
  }

  void _loadExpensesPaginated({bool isRefresh = false}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      context.read<ExpenseBloc>().add(
        LoadExpensesPaginatedEvent(
          organizationEmail: user.email!,
          isRefresh: isRefresh,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا لا نعيد تحميل البيانات هنا؟
    // لأن initState يبدأ الستريمات بالفعل، وإعادة
    // التحميل هنا تُعيد بدء الستريم عند كل تغيّر
    // (مثل ظهور الكيبورد) فتهدم الواجهة وتغلق الكيبورد.
    // ==========================================
  }

  void _startRealTimeUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // تطبيع البريد الإلكتروني
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);

      // بدء الاستماع للمصروفات مع التحديث الفوري - استخدام الحد المحدد
      context.read<ExpenseBloc>().add(
        StartExpensesStreamEvent(normalizedEmail, limit: 10),
      );
    }
  }

  void forceRefresh() {
    _loadExpensesPaginated(isRefresh: true);
  }

  /// ✅ التحقق من تنبيهات جميع المصروفات من السيرفر (بدون حد)
  Future<void> _checkAllExpensesNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      try {
        final repo = GetIt.instance<ExpenseRepository>();
        final result = await repo.getExpenses(normalizedEmail);
        result.fold((failure) {}, (allExpenses) {
          SectionNotificationService.checkAndNotifyExpenses(allExpenses);
        });
      } on Exception catch (_) {
        // تجاهل الأخطاء في فحص التنبيهات
      }
    }
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _loadExpensesPaginated(isRefresh: true);
  }

  void _loadExpenses() {
    _loadExpensesPaginated(isRefresh: true);
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopExpensesStreamEvent());
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const ExpenseDrawer(currentRoute: 'expenses'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'expenses_list_create_fab',
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.createExpense);
                // إعادة تحميل البيانات بعد الإنشاء الناجح.
                if (result == true || result is ExpenseEntity) {
                  forceRefresh();
                }
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (_waitingForInitialFilterData &&
              (state is ExpenseLoaded || state is ExpenseStreamActive)) {
            _waitingForInitialFilterData = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _bloc.add(FilterExpensesEvent(_selectedFilter));
              }
            });
          }
          if (state is ExpenseOperationSuccess) {
            forceRefresh();
          }
          // استدعاء الإشعارات مرة واحدة فقط عند تحميل البيانات الأولي (ExpenseLoaded)
          if (state is ExpenseLoaded) {
            _checkAllExpensesNotifications();
          }
          if (state is ExpenseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            // إعادة المحاولة بعد خطأ
            refreshWithDelay();
          }
        },
        builder: (context, state) {
          // استخدام البيانات المفلترة من BLoC مباشرة لتجنب التصفية المزدوجة
          var allExpenses = <ExpenseEntity>[];
          if (state is ExpenseLoaded) {
            allExpenses = state.filteredExpenses.cast<ExpenseEntity>();
          } else if (state is ExpenseStreamActive) {
            allExpenses = state.filteredExpenses.cast<ExpenseEntity>();
          }

          final filteredExpenses = allExpenses;

          if (state is ExpenseInitial || state is ExpenseLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل المصاريف...'),
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

          if (filteredExpenses.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.money_off_outlined,
                    title: 'لا توجد مصاريف',
                    message: 'ابدأ بإضافة مصروف جديد',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    forceRefresh();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: PaginatedListView<ExpenseEntity>(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(4),
                    items: filteredExpenses,
                    hasMore: state is ExpenseLoaded
                        ? state.hasMore
                        : state is ExpenseStreamActive
                        ? state.hasMore
                        : false,
                    isLoadingMore: state is ExpenseLoaded
                        ? state.isLoadingMore
                        : state is ExpenseStreamActive
                        ? state.isLoadingMore
                        : false,
                    onLoadMore: _onScroll,
                    itemBuilder: (context, index) =>
                        _buildExpenseCard(filteredExpenses[index]),
                  ),
                ),
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
      actions: [
        if (_canViewReports)
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.expensesReports);
            },
            icon: Icon(
              Icons.analytics,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'التقارير',
          ),
        IconButton(
          onPressed: _loadExpenses,
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
                      // تفعيل البحث الفعلي في صفحة القائمة عبر BLoC
                      context.read<ExpenseBloc>().add(
                        SearchExpensesEvent(value),
                      );
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث عن مصروف...',
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
                    color: _isFilterExpanded || _selectedFilter != 'all'
                        ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _isFilterExpanded || _selectedFilter != 'all'
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
                          color: _isFilterExpanded || _selectedFilter != 'all'
                              ? AssyrianTheme.primaryGold
                              : Colors.grey[600],
                          size: 24.sp,
                        ),
                        if (_selectedFilter != 'all')
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
                    tooltip: 'فلترة النتائج',
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
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          _buildFilterChip('الكل', 'all'),
          _buildFilterChip('قيد الانتظار', 'pending'),
          _buildFilterChip('موافق عليه', 'approved'),
          _buildFilterChip('مرفوض', 'rejected'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
        _bloc.add(FilterExpensesEvent(value));
      },
      backgroundColor: Colors.white,
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.deepBlue,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.deepBlue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13.sp,
      ),
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : Colors.grey.withValues(alpha: 0.3),
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
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadExpenses,
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

  Widget _buildExpenseCard(ExpenseEntity expense) {
    final statusColor = _getStatusColor(expense.status);
    final statusText = _getStatusText(expense.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          minTileHeight: 72.h,
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.expenseDetails,
            arguments: expense,
          );
        },
        leading: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 100.w),
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.pushNamed(
                context,
                AppRoutes.editExpense,
                arguments: expense,
              ).then((result) {
                if (result == true || result is ExpenseEntity) {
                  forceRefresh();
                }
              });
            } else if (value == 'delete') {
              _showDeleteDialog(expense);
            }
          },
          itemBuilder: (context) => [
            if (_canEdit)
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16.sp, color: Colors.blue),
                    SizedBox(width: 6.w),
                    Text('تعديل', style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
            if (_canDelete)
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16.sp, color: Colors.red),
                    SizedBox(width: 6.w),
                    Text('حذف', style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
          ],
          child: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.1),
            radius: 22.r,
            child: Icon(Icons.money_off, color: statusColor, size: 20.sp),
          ),
        ),
        title: Text(
          expense.title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 3.h),
            Text(
              expense.description,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    expense.category,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.calendar_today,
                  size: 10.sp,
                  color: Colors.grey[500],
                ),
                SizedBox(width: 3.w),
                Text(
                  _formattingService.formatDate(expense.date),
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            Text(
              _formattingService.formatExpenseAmount(expense.amount),
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
         ),
       ),
       ),
     );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'approved':
        return 'موافق عليه';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }

  void _showDeleteDialog(ExpenseEntity expense) {
    DeleteExpenseDialog.show(
      context,
      expense,
      context.read<ExpenseBloc>(),
      onDeleted: _loadExpenses,
    );
  }
}
