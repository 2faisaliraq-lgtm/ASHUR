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
import '../bloc/maintenance_bloc.dart';
import '../widgets/maintenance_drawer.dart';
import '../widgets/maintenance_filter_chips.dart';
import '../widgets/maintenance_quick_actions.dart';
import '../widgets/maintenance_requests_grid.dart';
import '../widgets/maintenance_search_bar.dart';
import '../widgets/maintenance_stats_section.dart';

/// صفحة لوحة تحكم الصيانة
class MaintenanceDashboardPage extends StatefulWidget {
  const MaintenanceDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<MaintenanceDashboardPage> createState() =>
      _MaintenanceDashboardPageState();
}

class _MaintenanceDashboardPageState extends State<MaintenanceDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String? _selectedStatus;
  String? _selectedPriority;
  bool _isGridView = false; // Add grid view state
  bool _canCreate = false;
  late MaintenanceBloc _bloc;
  String? _currentOrganizationEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<MaintenanceBloc>();
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
      'maintenance_create',
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
    // بدء الاستماع لطلبات الصيانة مع التحديث الفوري - أول 20 طلب فقط
    context.read<MaintenanceBloc>().add(
      StartMaintenanceStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: 10,
      ),
    );
    // بدء الاستماع للإحصائيات مع التحديث الفوري
    context.read<MaintenanceBloc>().add(
      const StartMaintenanceStatsStreamEvent(limit: null),
    );
  }

  void _loadMaintenanceRequests() {
    // في الداشبورد، نستخدم Stream مع أول 20 طلب للأداء
    _currentOrganizationEmail = widget.organizationEmail;
    context.read<MaintenanceBloc>().add(
      StartMaintenanceStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: 10,
      ),
    );
    context.read<MaintenanceBloc>().add(
      const StartMaintenanceStatsStreamEvent(limit: null),
    );
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopMaintenanceStreamEvent());
    _bloc.add(const StopMaintenanceStatsStreamEvent());
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
        drawer: MaintenanceDrawer(
          currentRoute: 'dashboard',
          onAddRequest: () => _navigateToAddRequest(context),
          onSettings: () => _navigateToSettings(context),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        body: BlocBuilder<MaintenanceBloc, MaintenanceState>(
          builder: (context, state) {
            if (state is MaintenanceError) {
              return AppErrorWidget(
                message: state.message,
                onRetry: _loadMaintenanceRequests,
              );
            }

            if (state is MaintenanceStreamActive) {
              return _buildMaintenanceContent(context, state);
            }

            if (state is MaintenanceLoaded) {
              return _buildMaintenanceContent(context, state);
            }

            // بناء الهيكل فورًا مع بيانات فارغة أثناء التحميل الأول
            return _buildMaintenanceContent(
              context,
              const MaintenanceLoaded(
                requests: [],
                filteredRequests: [],
                equipment: [],
                stats: {},
              ),
            );
          },
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                heroTag: 'maintenance_dashboard_create_fab',
                onPressed: () => _navigateToAddRequest(context),
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                child: Icon(Icons.add, size: 28.sp),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildMaintenanceContent(BuildContext context, dynamic state) {
    return RefreshIndicator(
      onRefresh: () async => _loadMaintenanceRequests(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // قسم الإحصائيات
          SliverToBoxAdapter(
            child: MaintenanceStatsSection(
              stats: state.stats,
              onFilterSelected: (filter) =>
                  _openMaintenanceList(context, filter),
            ),
          ),

          // قسم الإجراءات السريعة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: MaintenanceQuickActions(
                onAddRequest: () => _navigateToAddRequest(context),
                onRefresh: _loadMaintenanceRequests,
                onSettings: () => _navigateToSettings(context),
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
                  MaintenanceSearchBar(
                    onSearch: (query) {
                      final orgEmail = _currentOrganizationEmail;
                      if (orgEmail != null && orgEmail.isNotEmpty) {
                        context.read<MaintenanceBloc>().add(
                          StartMaintenanceStreamEvent(
                            organizationEmail: orgEmail,
                            limit: query.isEmpty ? 20 : null,
                            searchQuery: query.isEmpty ? null : query,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // فلاتر الصيانة
                  MaintenanceFilterChips(
                    selectedStatus: _selectedStatus,
                    selectedPriority: _selectedPriority,
                    onStatusChanged: (status) {
                      setState(() => _selectedStatus = status);
                      context.read<MaintenanceBloc>().add(
                        FilterMaintenanceRequestsEvent(
                          status: status,
                          priority: _selectedPriority,
                        ),
                      );
                    },
                    onPriorityChanged: (priority) {
                      setState(() => _selectedPriority = priority);
                      context.read<MaintenanceBloc>().add(
                        FilterMaintenanceRequestsEvent(
                          status: _selectedStatus,
                          priority: priority,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // عنوان قائمة الطلبات مع عداد وزر التبديل
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
                          'آخر طلبات الصيانة',
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
                          'آخر ${state.filteredRequests.length} طلب صيانة',
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
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.maintenanceList,
                        ),
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

          // شبكة/قائمة طلبات الصيانة
          MaintenanceRequestsGrid(
            requests: state.filteredRequests,
            onRequestTap: (request) => _showRequestDetails(context, request),
            isGridView: _isGridView,
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _openMaintenanceList(BuildContext context, String filter) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.maintenanceList, arguments: filter);
  }

  void _navigateToAddRequest(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.createMaintenanceRequest);
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.maintenanceSettings);
  }

  void _showRequestDetails(BuildContext context, request) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.maintenanceDetails, arguments: request);
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
                  'إدارة الصيانة',
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
