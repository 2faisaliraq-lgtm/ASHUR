import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/navigation/navigation_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/subscription_notification_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../domain/entities/subscription_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/subscription_drawer.dart';
import '../widgets/subscription_filter_chips.dart';
import '../widgets/subscription_quick_actions.dart';
import '../widgets/subscription_search_bar.dart';
import '../widgets/subscription_stats_section.dart';
import '../widgets/subscriptions_grid.dart';

/// صفحة لوحة تحكم الاشتراكات
class SubscriptionDashboardPage extends StatefulWidget {
  const SubscriptionDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<SubscriptionDashboardPage> createState() =>
      _SubscriptionDashboardPageState();
}

class _SubscriptionDashboardPageState extends State<SubscriptionDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final PermissionChecker _permissionChecker = PermissionChecker();
  final ScrollController _scrollController = ScrollController();
  String? _selectedStatus;
  String? _selectedType;
  bool _isGridView = false;
  bool _canCreate = false;
  late SubscriptionBloc _bloc;
  String? _currentOrganizationEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<SubscriptionBloc>();
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
      'subscriptions_create',
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
    // لا نعيد تحميل البيانات لأن الـ streams تعمل تلقائياً
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
    // بدء الاستماع للاشتراكات مع التحديث الفوري - جميع الاشتراكات (بدون حد)
    context.read<SubscriptionBloc>().add(
      StartSubscriptionsStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: null,
      ),
    );
    // بدء الاستماع للإحصائيات مع التحديث الفوري - جميع الاشتراكات (بدون حد)
    context.read<SubscriptionBloc>().add(
      StartSubscriptionStatsStreamEvent(widget.organizationEmail, limit: null),
    );
  }

  // ⚠️ ملاحظة للمبرمجين المستقبليين: لا تستدعي هذه الطريقة من
  // didChangeDependencies لأنها تُعيد بدء الستريم عند كل تغيّر في
  // الاعتماديات (مثل ظهور الكيبورد) فتهدم الواجهة وتغلق الكيبورد
  void _loadSubscriptions() {
    _currentOrganizationEmail = widget.organizationEmail;
    // في الداشبورد، نستخدم Stream مع جميع الاشتراكات (بدون حد)
    context.read<SubscriptionBloc>().add(
      StartSubscriptionsStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: null,
      ),
    );
    context.read<SubscriptionBloc>().add(
      StartSubscriptionStatsStreamEvent(widget.organizationEmail, limit: null),
    );
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopSubscriptionsStreamEvent());
    _bloc.add(const StopSubscriptionStatsStreamEvent());
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
        drawer: SubscriptionDrawer(
          currentRoute: 'dashboard',
          onAddSubscription: () => _navigateToAddSubscription(context),
          onSettings: () =>
              Navigator.pushNamed(context, AppRoutes.subscriptionsSettings),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, state) {
            if (state is SubscriptionError) {
              return AppErrorWidget(
                message: state.message,
                onRetry: _loadSubscriptions,
              );
            }

            if (state is SubscriptionsStreamActive) {
              return _buildSubscriptionContent(context, state);
            }

            if (state is SubscriptionLoaded) {
              return _buildSubscriptionContent(context, state);
            }

            // بناء الهيكل فورًا مع بيانات فارغة أثناء التحميل الأول
            return _buildSubscriptionContent(
              context,
              const SubscriptionLoaded(
                subscriptions: [],
                filteredSubscriptions: [],
                subscriptionTypes: [],
                stats: {},
              ),
            );
          },
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                heroTag: 'subscriptions_dashboard_create_fab',
                onPressed: () => _navigateToAddSubscription(context),
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                child: Icon(Icons.add, size: 28.sp),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildSubscriptionContent(BuildContext context, dynamic state) {
    return RefreshIndicator(
      onRefresh: () async => _loadSubscriptions(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // قسم الإحصائيات
          SliverToBoxAdapter(
            child: SubscriptionStatsSection(
              stats: state.stats,
              onFilterSelected: (filter) =>
                  _openSubscriptionsList(context, filter),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: () => _openSubscriptionsList(context, null),
                icon: const Icon(Icons.list_alt),
                label: const Text('عرض جميع الاشتراكات'),
              ),
            ),
          ),

          // قسم الإجراءات السريعة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SubscriptionQuickActions(
                onAddSubscription: () => _navigateToAddSubscription(context),
                onRefresh: _loadSubscriptions,
                onSettings: () => Navigator.pushNamed(
                  context,
                  AppRoutes.subscriptionsSettings,
                ),
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
                  SubscriptionSearchBar(
                    onSearch: (query) {
                      final orgEmail = _currentOrganizationEmail;
                      if (orgEmail != null && orgEmail.isNotEmpty) {
                        context.read<SubscriptionBloc>().add(
                          StartSubscriptionsStreamEvent(
                            organizationEmail: orgEmail,
                            limit: null,
                            searchQuery: query.isEmpty ? null : query,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // فلاتر الاشتراكات
                  SubscriptionFilterChips(
                    selectedStatus: _selectedStatus,
                    selectedType: _selectedType,
                    subscriptionTypes: state.subscriptionTypes,
                    onStatusChanged: (status) {
                      setState(() => _selectedStatus = status);
                      context.read<SubscriptionBloc>().add(
                        FilterSubscriptionsEvent(
                          status: status,
                          type: _selectedType,
                        ),
                      );
                    },
                    onTypeChanged: (type) {
                      setState(() => _selectedType = type);
                      context.read<SubscriptionBloc>().add(
                        FilterSubscriptionsEvent(
                          status: _selectedStatus,
                          type: type,
                        ),
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
                          'آخر الاشتراكات',
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
                          'آخر ${state.filteredSubscriptions.length} اشتراك',
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
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.subscriptionsList,
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

          // شبكة/قائمة الاشتراكات
          SubscriptionsGrid(
            subscriptions: state.filteredSubscriptions,
            onSubscriptionTap: (subscription) =>
                _showSubscriptionDetails(context, subscription),
            isGridView: _isGridView,
          ),

          // مساحة إضافية في الأسفل للـ FAB
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _openSubscriptionsList(BuildContext context, String? filter) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.subscriptionsList, arguments: filter);
  }

  void _navigateToAddSubscription(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.createSubscription);
  }

  void _showSubscriptionDetails(BuildContext context, subscription) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.subscriptionDetails, arguments: subscription);
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
                  'إدارة الاشتراكات',
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
