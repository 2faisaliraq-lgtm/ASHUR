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
import '../bloc/report_bloc.dart';
import '../widgets/report_quick_actions.dart';
import '../widgets/widgets.dart';

/// صفحة لوحة تحكم التقارير
class ReportDashboardPage extends StatefulWidget {
  const ReportDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<ReportDashboardPage> createState() => _ReportDashboardPageState();
}

class _ReportDashboardPageState extends State<ReportDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String? _selectedFilter;
  bool _isGridView = false; // Add grid view state
  // ⚠️ _isGridView حالة محلية في الصفحة، ولكن ReportsStreamActive في BLoC يحتوي أيضًا على حقل isGridView.
  // عند التبديل بين العرضين، يتم تحديث _isGridView محليًا فقط دون تحديث BLoC.
  // إذا أعيد إنشاء الصفحة أو تم إعادة تحميل البيانات من الستريم، قد يضيع وضع العرض المختار.
  // الحل: نقل _isGridView إلى BLoC state واستخدامه من هناك في جميع الصفحات.
  bool _canCreate = false;
  late ReportBloc _bloc;
  String? _currentOrganizationEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ReportBloc>();
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
    final canCreate = await _permissionChecker.hasPermission('reports_create');

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ لا نحتاج لإعادة تحميل البيانات لأن الـ streams تعمل تلقائياً
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
    // بدء الاستماع للتقارير مع التحديث الفوري - أول 20 تقرير فقط
    context.read<ReportBloc>().add(
      StartReportsStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: 10,
      ),
    );
    // بدء الاستماع للإحصائيات مع التحديث الفوري
    context.read<ReportBloc>().add(const StartReportsStatsStreamEvent(limit: null));
  }

  void _loadReports() {
    // في الداشبورد، نستخدم Stream مع أول 20 تقرير للأداء
    _currentOrganizationEmail = widget.organizationEmail;
    context.read<ReportBloc>().add(
      StartReportsStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: 10,
      ),
    );
    context.read<ReportBloc>().add(const StartReportsStatsStreamEvent(limit: null));
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopReportsStreamEvent());
    _bloc.add(const StopReportsStatsStreamEvent());
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
        drawer: ReportDrawer(
          currentRoute: 'dashboard',
          onAddReport: () => _navigateToAddReport(context),
          onSettings: () =>
              Navigator.pushNamed(context, AppRoutes.reportsSettings),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        body: BlocBuilder<ReportBloc, ReportState>(
          builder: (context, state) {
            if (state is ReportError) {
              return AppErrorWidget(
                message: state.message,
                onRetry: _loadReports,
              );
            }

            if (state is ReportsStreamActive) {
              return _buildReportContent(context, state);
            }

            if (state is ReportLoaded) {
              return _buildReportContent(context, state);
            }

            // بناء الهيكل فورًا مع بيانات فارغة أثناء التحميل الأول
            return _buildReportContent(
              context,
              const ReportLoaded(
                reports: [],
                filteredReports: [],
                selectedFilter: 'all',
                searchQuery: '',
                isGridView: false,
              ),
            );
          },
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                heroTag: 'reports_dashboard_create_fab',
                onPressed: () => _navigateToAddReport(context),
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                child: Icon(Icons.add, size: 28.sp),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, dynamic state) {
    return RefreshIndicator(
      onRefresh: () async => _loadReports(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // قسم الإحصائيات
          SliverToBoxAdapter(
            child: ReportStatsSection(
              stats: state.stats,
              onFilterSelected: (filter) =>
                  _openReportsList(context, filter),
            ),
          ),

          // قسم الإجراءات السريعة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ReportQuickActions(
                onAddReport: () => _navigateToAddReport(context),
                onExportReports: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ميزة التصدير قيد التطوير'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                onRefresh: _loadReports,
                onSettings: () =>
                    Navigator.pushNamed(context, AppRoutes.reportsSettings),
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
                  ReportSearchBar(
                    onSearch: (query) {
                      final orgEmail = _currentOrganizationEmail;
                      if (orgEmail != null && orgEmail.isNotEmpty) {
                        context.read<ReportBloc>().add(
                          StartReportsStreamEvent(
                            organizationEmail: orgEmail,
                            limit: query.isEmpty ? 10 : null,
                            searchQuery: query.isEmpty ? null : query,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // فلاتر التقارير
                  ReportFilterChips(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (filter) {
                      setState(() => _selectedFilter = filter);
                      context.read<ReportBloc>().add(
                        FilterReportsEvent(filter ?? 'all'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // عنوان قائمة التقارير مع عداد وزر التبديل
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
                          'آخر التقارير',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.deepBlue,
                            fontSize: 13.sp,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          'عرض آخر ${state.filteredReports.length} تقرير',
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
                            onPressed: () =>
                                Navigator.pushNamed(context, AppRoutes.reportsList),
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
                                        // مزامنة مع BLoC إذا كانت الحالة تدعم ذلك
                                        if (context.read<ReportBloc>().state is ReportLoaded) {
                                          context.read<ReportBloc>().add(ToggleViewModeEvent());
                                        }
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
                                        // مزامنة مع BLoC إذا كانت الحالة تدعم ذلك
                                        if (context.read<ReportBloc>().state is ReportLoaded) {
                                          context.read<ReportBloc>().add(ToggleViewModeEvent());
                                        }
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

          // قائمة/شبكة التقارير
          ReportsGrid(
            reports: state.filteredReports,
            onReportTap: (report) => _showReportDetails(context, report),
            isGridView: _isGridView,
          ),

          // مساحة إضافية في الأسفل للـ FAB
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _openReportsList(BuildContext context, String filter) {
    Navigator.of(context).pushNamed(AppRoutes.reportsList, arguments: filter);
  }

  void _navigateToAddReport(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.createReport);
  }

  void _showReportDetails(BuildContext context, report) {
    Navigator.of(context).pushNamed(AppRoutes.reportDetails, arguments: report);
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
                  'إدارة التقارير',
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
