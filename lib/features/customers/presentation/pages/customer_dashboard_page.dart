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
import '../bloc/customer_bloc.dart';
import '../widgets/customer_drawer.dart';
import '../widgets/customer_filter_chips.dart';
import '../widgets/customer_quick_actions.dart';
import '../widgets/customer_search_bar.dart';
import '../widgets/customer_stats_section.dart';
import '../widgets/customers_grid.dart';

/// صفحة لوحة تحكم العملاء
class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final PermissionChecker _permissionChecker = PermissionChecker();
  final ScrollController _scrollController = ScrollController();
  String? _selectedFilter;
  bool _isGridView = false;
  bool _canCreate = false;
  late CustomerBloc _bloc;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<CustomerBloc>();
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
    final canCreate = await _permissionChecker.hasPermission(
      'customers_create',
    );

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
    // لماذا لا نعيد تحميل البيانات هنا؟
    // لأن initState يبدأ الستريمات بالفعل، وإعادة
    // التحميل هنا تُعيد بدء الستريم عند كل تغيّر
    // (مثل ظهور الكيبورد) فتهدم الواجهة وتغلق الكيبورد.
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

    // بدء الاستماع للعملاء مع التحديث الفوري - أول 20 عميل فقط
    context.read<CustomerBloc>().add(
      StartCustomersStreamEvent(widget.organizationEmail, limit: 10),
    );
    // بدء الاستماع للإحصائيات مع التحديث الفوري
    context.read<CustomerBloc>().add(
      StartCustomerStatsStreamEvent(widget.organizationEmail, limit: null),
    );
  }

  // ===== ملاحظة للمبرمجين المستقبليين =====
  // لماذا _loadCustomers لا يستدعي _startRealTimeUpdates مباشرة؟
  // لأن _startRealTimeUpdates يعيد تشغيل الـ streams مما يزيد
  // من احتمالية حدوث حالة السباق. بدلاً من ذلك، نستخدم
  // LoadCustomersEvent لتحميل البيانات يدوياً فقط عندما
  // نفشل في الحصول على البيانات من الـ streams.
  // ==========================================
  void _loadCustomers() {
    // في الداشبورد، نستخدم Stream للفلترة مع أول 20 عميل للأداء
    context.read<CustomerBloc>().add(
      StartCustomersStreamEvent(widget.organizationEmail, limit: 10),
    );
    context.read<CustomerBloc>().add(
      StartCustomerStatsStreamEvent(widget.organizationEmail, limit: null),
    );
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopCustomersStreamEvent());
    _bloc.add(const StopCustomerStatsStreamEvent());
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
        drawer: CustomerDrawer(
          currentRoute: 'dashboard',
          onAddCustomer: () => _navigateToAddCustomer(context),
          onSettings: () =>
              Navigator.pushNamed(context, AppRoutes.customersSettings),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        body: BlocBuilder<CustomerBloc, CustomerState>(
          builder: (context, state) {
            if (state is CustomerError) {
              return AppErrorWidget(
                message: state.message,
                onRetry: _loadCustomers,
              );
            }

            if (state is CustomerStreamActive) {
              return _buildCustomerContent(context, state);
            }

            if (state is CustomerLoaded) {
              return _buildCustomerContent(context, state);
            }

            // بناء الهيكل فورًا مع بيانات فارغة أثناء التحميل الأول
            return _buildCustomerContent(
              context,
              const CustomerLoaded(
                customers: [],
                filteredCustomers: [],
                selectedFilter: 'all',
                searchQuery: '',
                isGridView: false,
              ),
            );
          },
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                heroTag: 'customers_dashboard_create_fab',
                onPressed: () => _navigateToAddCustomer(context),
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                child: Icon(Icons.add, size: 28.sp),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildCustomerContent(BuildContext context, dynamic state) {
    return RefreshIndicator(
      onRefresh: () async => _loadCustomers(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // النظرة العامة في سطر واحد
          SliverToBoxAdapter(
            child: CustomerStatsSection(
              stats: state.stats,
              onFilterSelected: (filter) => _openCustomersList(context, filter),
            ),
          ),

          // الإجراءات السريعة أسفل النظرة العامة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: CustomerQuickActions(
                onAddCustomer: () => _navigateToAddCustomer(context),
                onRefresh: _loadCustomers,
                onSettings: () =>
                    Navigator.pushNamed(context, AppRoutes.customersSettings),
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
                  CustomerSearchBar(
                    onSearch: (query) {
                      context.read<CustomerBloc>().add(
                        SearchCustomersEvent(query),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  // فلاتر العملاء
                  CustomerFilterChips(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (filter) {
                      setState(() => _selectedFilter = filter);
                      context.read<CustomerBloc>().add(
                        FilterCustomersEvent(filter ?? 'all'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // عنوان قائمة العملاء مع عداد وزر التبديل
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
                          'آخر العملاء',
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
                          'آخر ${state.filteredCustomers.length} عميل',
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
                      // زر عرض الكل
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.customersList);
                        },
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

          // قائمة/شبكة العملاء
          CustomersGrid(
            customers: state.filteredCustomers,
            onCustomerTap: (customer) =>
                _showCustomerDetails(context, customer),
            isGridView: _isGridView,
          ),

          // مساحة إضافية في الأسفل للـ FAB
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _openCustomersList(BuildContext context, String filter) {
    Navigator.of(context).pushNamed(AppRoutes.customersList, arguments: filter);
  }

  void _navigateToAddCustomer(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.createCustomer);
  }

  void _showCustomerDetails(BuildContext context, customer) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.customerDetails, arguments: customer);
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
                  'إدارة العملاء',
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
