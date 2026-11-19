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
import '../bloc/invoice_bloc.dart';
import '../widgets/invoice_drawer.dart';
import '../widgets/invoice_filter_chips.dart';
import '../widgets/invoice_quick_actions.dart';
import '../widgets/invoice_search_bar.dart';
import '../widgets/invoice_stats_section.dart';
import '../widgets/invoices_grid.dart';

/// صفحة لوحة تحكم الفواتير
class InvoiceDashboardPage extends StatefulWidget {
  const InvoiceDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<InvoiceDashboardPage> createState() => _InvoiceDashboardPageState();
}

class _InvoiceDashboardPageState extends State<InvoiceDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String? _selectedFilter;
  bool _isGridView = false; // Add grid view state
  bool _canCreate = false;
  late InvoiceBloc _invoiceBloc;
  String? _currentOrganizationEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _invoiceBloc = context.read<InvoiceBloc>();
    _startRealTimeUpdates();
    // ⚠️ تأجيل تحميل الصلاحيات حتى بعد بناء أول إطار للواجهة
    // لتجنب حظر واجهة المستخدم أثناء انتظار استجابات Firebase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPermissions();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _startRealTimeUpdates() {
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
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    context.read<InvoiceBloc>().add(
      StartInvoiceStatsStreamEvent(
        widget.organizationEmail,
        startDate: startOfDay,
        endDate: now,
        limit: 10,
      ),
    );

    context.read<InvoiceBloc>().add(
      StartInvoicesStreamEvent(widget.organizationEmail, limit: 10, startDate: startOfDay, endDate: now),
    );
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission(
      'invoices_sales_manage',
    );

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
      });
    }
  }

  void _loadInvoices() {
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا لا نستدعي _startRealTimeUpdates() هنا؟
    // لأن _startRealTimeUpdates يعيد تشغيل الـ streams مما يزيد
    // من احتمالية حدوث حالة السباق. بدلاً من ذلك، نستخدم
    // StartInvoicesStreamEvent و StartInvoiceStatsStreamEvent
    // لتحميل البيانات يدوياً فقط عندما نفشل في الحصول على البيانات
    // من الـ streams.
    // ==========================================
    _currentOrganizationEmail = widget.organizationEmail;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    context.read<InvoiceBloc>().add(
      StartInvoicesStreamEvent(widget.organizationEmail, limit: 10, startDate: startOfDay, endDate: now),
    );
    context.read<InvoiceBloc>().add(
      StartInvoiceStatsStreamEvent(
        widget.organizationEmail,
        startDate: startOfDay,
        endDate: now,
        limit: null,
      ),
    );
  }

  @override
  void dispose() {
    _invoiceBloc.add(const StopInvoicesStreamEvent());
    _invoiceBloc.add(const StopInvoiceStatsStreamEvent());
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
        drawer: InvoiceDrawer(
          currentRoute: 'dashboard',
          onAddInvoice: () => _navigateToAddInvoice(context),
          onSettings: () =>
              Navigator.pushNamed(context, AppRoutes.invoicesSettings),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        body: BlocBuilder<InvoiceBloc, InvoiceState>(
          builder: (context, state) {
            if (state is InvoiceError) {
              return AppErrorWidget(
                message: state.message,
                onRetry: _loadInvoices,
              );
            }

            if (state is InvoiceStreamActive) {
              return _buildInvoiceContent(context, state);
            }

            if (state is InvoiceLoaded) {
              return _buildInvoiceContent(context, state);
            }

            // بناء الهيكل فورًا مع بيانات فارغة أثناء التحميل الأول
            return _buildInvoiceContent(
              context,
              const InvoiceLoaded(
                invoices: [],
                filteredInvoices: [],
                selectedFilter: 'all',
                searchQuery: '',
                isGridView: false,
              ),
            );
          },
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                heroTag: 'invoices_dashboard_create_fab',
                onPressed: () => _navigateToAddInvoice(context),
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                child: Icon(Icons.add, size: 28.sp),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildInvoiceContent(BuildContext context, dynamic state) {
    // جميع الفواتير متاحة للمستخدمين الذين لديهم صلاحية العرض
    final filteredInvoices = state.filteredInvoices;

    return RefreshIndicator(
      onRefresh: () async => _loadInvoices(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // النظرة العامة في سطر واحد
          SliverToBoxAdapter(
            child: InvoiceStatsSection(
              stats: state.stats,
              onFilterSelected: (filter) =>
                  _openInvoicesList(context, filter),
            ),
          ),

          // الإجراءات السريعة أسفل النظرة العامة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: InvoiceQuickActions(
                onAddInvoice: () => _navigateToAddInvoice(context),
                onRefresh: _loadInvoices,
                onSettings: () =>
                    Navigator.pushNamed(context, AppRoutes.invoicesSettings),
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
                  InvoiceSearchBar(
                    onSearch: (query) {
                      final orgEmail = _currentOrganizationEmail;
                      if (orgEmail != null && orgEmail.isNotEmpty) {
                        final now = DateTime.now();
                        final startOfDay = DateTime(now.year, now.month, now.day);
                        context.read<InvoiceBloc>().add(
                          StartInvoicesStreamEvent(
                            orgEmail,
                            limit: null,
                            startDate: startOfDay,
                            endDate: now,
                            searchQuery: query.isEmpty ? null : query,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // فلاتر الفواتير
                  InvoiceFilterChips(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (filter) {
                      setState(() => _selectedFilter = filter);
                      context.read<InvoiceBloc>().add(
                        FilterInvoicesEvent(filter ?? 'all'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // عنوان قائمة الفواتير مع عداد وزر التبديل
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
                          'آخر الفواتير',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.deepBlue,
                            fontSize: 13.sp,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          'آخر ${filteredInvoices.length} فاتورة',
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
                      // زر "عرض الكل"
                      TextButton.icon(
                        onPressed: () => _openInvoicesList(context, 'all'),
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

          // قائمة/شبكة الفواتير
          InvoicesGrid(
            invoices: filteredInvoices,
            onInvoiceTap: (invoice) => _showInvoiceDetails(context, invoice),
            isGridView: _isGridView,
          ),

          // مساحة إضافية في الأسفل للـ FAB
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _openInvoicesList(BuildContext context, String filter) {
    Navigator.of(context).pushNamed(AppRoutes.invoicesList, arguments: filter);
  }

  void _navigateToAddInvoice(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.createInvoice);
  }

  void _showInvoiceDetails(BuildContext context, invoice) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.invoiceDetails, arguments: invoice);
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
                  'إدارة الفواتير',
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
