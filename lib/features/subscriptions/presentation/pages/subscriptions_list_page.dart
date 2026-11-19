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
import '../../../../core/services/section_badge_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/subscription_notification_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/subscription_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/delete_subscription_dialog.dart';
import '../widgets/renew_subscription_dialog.dart';
import '../widgets/subscription_drawer.dart';

/// صفحة عرض جميع الاشتراكات
class SubscriptionsListPage extends StatefulWidget {
  const SubscriptionsListPage({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  State<SubscriptionsListPage> createState() => _SubscriptionsListPageState();
}

class _SubscriptionsListPageState extends State<SubscriptionsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String _selectedFilter = 'all';
  String _sortBy = 'expiring_soonest';
  bool _isFilterExpanded = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canViewReports = false;
  bool _enableSectionBadges = true;
  bool _isBannerDismissed = false;
  bool _isRenewingSubscription = false;
  bool _waitingForInitialFilterData = false;
  late SubscriptionBloc _bloc; // حفظ reference للـ bloc
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final initialFilter = widget.initialFilter;
    if (initialFilter != null && initialFilter.isNotEmpty) {
      _selectedFilter = initialFilter;
      _waitingForInitialFilterData = true;
    }
    // حفظ reference للـ bloc
    _bloc = context.read<SubscriptionBloc>();
    _startRealTimeUpdates();
    _loadPermissions();
    _loadBadgeSettings();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadBadgeSettings() async {
    try {
      final settings = await SettingsService.getSubscriptionSettings();
      if (mounted) {
        setState(() {
          _enableSectionBadges =
              settings['subscriptionAlertsEnabled'] ??
              settings['enableSectionBadges'] ??
              false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _enableSectionBadges = false);
      }
    }
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission(
      'subscriptions_create',
    );
    final canEdit = await _permissionChecker.hasPermission(
      'subscriptions_edit',
    );
    final canDelete = await _permissionChecker.hasPermission(
      'subscriptions_delete',
    );
    final canViewReports = await _permissionChecker.hasPermission(
      'subscriptions_reports_view',
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

  void _applyFilter(String filter) {
    setState(() => _selectedFilter = filter);
  }

  void _startRealTimeUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // تطبيع البريد الإلكتروني
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);

      // بدء الاستماع للاشتراكات مع التحديث الفوري
      context.read<SubscriptionBloc>().add(
        StartSubscriptionsStreamEvent(organizationEmail: normalizedEmail),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    if (state is! SubscriptionsStreamActive ||
        !state.hasMoreData ||
        state.isLoadingMore ||
        _selectedFilter != 'all') {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final normalizedEmail = EmailNormalizationService().normalize(user.email!);
      _bloc.add(LoadMoreSubscriptionsEvent(normalizedEmail));
    }
  }

  void forceRefresh() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    final email = EmailNormalizationService().normalize(user!.email!);
    _bloc.add(LoadSubscriptionsEvent(email));
    _startRealTimeUpdates();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _startRealTimeUpdates();
  }

  void _loadSubscriptions() {
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopSubscriptionsStreamEvent());
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<SubscriptionEntity> _filterSubscriptions(
    List<SubscriptionEntity> subscriptions,
  ) {
    var filtered = subscriptions;

    // تطبيق البحث عبر اسم العميل، الهاتف، اسم الاشتراك، والنوع
    if (_searchController.text.trim().isNotEmpty) {
      final query = _searchController.text.trim().toLowerCase();
      filtered = filtered.where((sub) {
        final nameMatches = sub.name.toLowerCase().contains(query);
        final customerMatches =
            sub.customerName?.toLowerCase().contains(query) ?? false;
        final phoneMatches =
            sub.customerPhone?.toLowerCase().contains(query) ?? false;
        final typeMatches = sub.type.toLowerCase().contains(query);
        final descMatches =
            sub.description?.toLowerCase().contains(query) ?? false;
        return nameMatches ||
            customerMatches ||
            phoneMatches ||
            typeMatches ||
            descMatches;
      }).toList();
    }

    // تطبيق الفلتر
    if (_selectedFilter != 'all') {
      if (_selectedFilter == 'active') {
        // فلترة الاشتراكات النشطة فقط والتي لم تنتهي بعد
        filtered = filtered.where((sub) {
          return sub.status == 'active' && !sub.isExpired;
        }).toList();
      } else if (_selectedFilter == 'expiring_soon') {
        // فلترة الاشتراكات التي على وشك الانتهاء (3 أيام أو أقل أو اليوم) ونشطة
        filtered = filtered.where((sub) {
          return sub.isExpiringSoon;
        }).toList();
      } else if (_selectedFilter == 'expired') {
        // استخدم تعريف الإحصاء نفسه: كل اشتراك منتهٍ، بما فيه الملغى إذا كان منتهيًا.
        filtered = filtered.where((sub) => sub.isExpired).toList();
      } else {
        filtered = filtered.where((sub) {
          return sub.status == _selectedFilter ||
              sub.duration == _selectedFilter;
        }).toList();
      }
    }

    // تطبيق الترتيب
    final sorted = List<SubscriptionEntity>.from(filtered);
    switch (_sortBy) {
      case 'expiring_soonest':
        sorted.sort((a, b) {
          // النشطة أولاً، ثم حسب تاريخ الانتهاء
          if (a.status == 'active' && b.status != 'active') return -1;
          if (a.status != 'active' && b.status == 'active') return 1;
          return a.endDate.compareTo(b.endDate);
        });
        break;
      case 'newest':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'name':
        sorted.sort((a, b) {
          final nameA = (a.customerName ?? a.name).toLowerCase();
          final nameB = (b.customerName ?? b.name).toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;
      case 'price':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
    }

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const SubscriptionDrawer(currentRoute: 'subscriptions'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'subscriptions_list_create_fab',
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/subscriptions/create',
                );
                if (result == true || result is SubscriptionEntity) {
                  forceRefresh();
                }
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionOperationSuccess &&
              _isRenewingSubscription) {
            _isRenewingSubscription = false;
            forceRefresh();
          } else if (state is SubscriptionError && _isRenewingSubscription) {
            _isRenewingSubscription = false;
          }
          // ✅ تم الإصلاح: إزالة استدعاء _loadSubscriptions() عند كل خطأ لتجنب
          // حلقة إعادة التحميل اللانهائية إذا كان الخطأ متكرراً (خطأ شبكي أو صلاحية).
          // العرض فقط للرسالة، وإعادة المحاولة تكون via زر "إعادة المحاولة" يدوياً.
          if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          var allSubscriptions = <SubscriptionEntity>[];

          if (state is SubscriptionLoaded) {
            allSubscriptions = state.subscriptions;
          } else if (state is SubscriptionsStreamActive) {
            allSubscriptions = state.subscriptions;
          }

          if (_waitingForInitialFilterData &&
              (state is SubscriptionLoaded ||
                  state is SubscriptionsStreamActive)) {
            _waitingForInitialFilterData = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _applyFilter(_selectedFilter);
            });
          }

          final filteredSubscriptions = _filterSubscriptions(allSubscriptions);

          if (state is SubscriptionInitial || state is SubscriptionLoading) {
            return Column(
              children: [
                _buildSearchFilter(allSubscriptions),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل الاشتراكات...'),
                ),
              ],
            );
          }

          if (state is SubscriptionError) {
            return Column(
              children: [
                _buildSearchFilter(allSubscriptions),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }



          if (filteredSubscriptions.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(allSubscriptions),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.subscriptions_outlined,
                    title: 'لا توجد اشتراكات',
                    message: 'ابدأ بإضافة اشتراك جديد',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(allSubscriptions),
              if (_enableSectionBadges)
                _buildSectionBadgeBanner(allSubscriptions),
              Expanded(
                child: PaginatedListView<SubscriptionEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredSubscriptions,
                  hasMore:
                      state is SubscriptionsStreamActive &&
                      state.hasMoreData &&
                      _selectedFilter == 'all',
                  isLoadingMore:
                      state is SubscriptionsStreamActive && state.isLoadingMore,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildSubscriptionCard(filteredSubscriptions[index]),
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
      actions: [
        if (_canViewReports)
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.subscriptionsReports),
            icon: Icon(
              Icons.analytics,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تقارير الاشتراكات',
          ),
        IconButton(
          onPressed: _loadSubscriptions,
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

  Widget _buildSearchFilter(List<SubscriptionEntity> allSubscriptions) {
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
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث عن مشترك، باقة، هاتف...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AssyrianTheme.primaryGold,
                        size: 24.sp,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
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
          if (_isFilterExpanded) _buildFilterOptions(allSubscriptions),
        ],
      ),
    );
  }

  Widget _buildSectionBadgeBanner(List<SubscriptionEntity> subscriptions) {
    if (_isBannerDismissed) {
      return const SizedBox.shrink();
    }

    final summary = SectionBadgeService.buildSubscriptionSummary(
      subscriptions,
      urgentDays: 3,
    );

    if (!summary.hasUrgentItems) {
      return const SizedBox.shrink();
    }

    final isCritical = summary.urgencyType == 'critical';
    final primaryColor = isCritical
        ? Colors.red.shade700
        : Colors.amber.shade800;
    final bgColor = isCritical ? Colors.red.shade50 : Colors.amber.shade50;
    final borderColor = isCritical
        ? Colors.red.shade200
        : Colors.amber.shade200;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 6.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCritical
                    ? Icons.error_outline_rounded
                    : Icons.schedule_rounded,
                color: primaryColor,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  summary.summaryMessage,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AssyrianTheme.deepBlue,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.close,
                  size: 16.sp,
                  color: Colors.grey.shade600,
                ),
                tooltip: 'إخفاء التنبيه',
                onPressed: () {
                  setState(() {
                    _isBannerDismissed = true;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              if (summary.expiredCount > 0)
                Padding(
                  padding: EdgeInsets.only(left: 6.w),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6.r),
                    onTap: () {
                      setState(() {
                        _selectedFilter = 'expired';
                        _isFilterExpanded = true;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 12.sp,
                            color: Colors.red.shade800,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'عرض المنتهية (${summary.expiredCount})',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (summary.expiringSoonCount > 0)
                InkWell(
                  borderRadius: BorderRadius.circular(6.r),
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'expiring_soon';
                      _isFilterExpanded = true;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 12.sp,
                          color: Colors.amber.shade900,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'عرض القريبة (${summary.expiringSoonCount})',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _buildFilterOptions(List<SubscriptionEntity> allSubscriptions) {
    final activeCount = allSubscriptions
        .where((s) => s.status == 'active' && !s.isExpired)
        .length;
    final expiringCount = allSubscriptions
        .where((s) => s.isExpiringSoon)
        .length;
    final expiredCount = allSubscriptions
        .where((s) => s.isExpired && s.status != 'cancelled')
        .length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'الترتيب:',
                style: TextStyle(
                  fontSize: 12.sp,
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
                      _buildSortChip('الأقرب انتهاءً', 'expiring_soonest'),
                      SizedBox(width: 6.w),
                      _buildSortChip('الأحدث', 'newest'),
                      SizedBox(width: 6.w),
                      _buildSortChip('الاسم', 'name'),
                      SizedBox(width: 6.w),
                      _buildSortChip('السعر الأعلى', 'price'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'الحالة والمدة:',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 4.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              _buildFilterChip('الكل (${allSubscriptions.length})', 'all'),
              _buildFilterChip('نشط ($activeCount)', 'active'),
              _buildFilterChip(
                'على وشك الانتهاء ($expiringCount)',
                'expiring_soon',
              ),
              _buildFilterChip('منتهي ($expiredCount)', 'expired'),
              _buildFilterChip('معلق', 'suspended'),
              _buildFilterChip('ملغي', 'cancelled'),
              _buildFilterChip('شهري', 'monthly'),
              _buildFilterChip('سنوي', 'yearly'),
              _buildFilterChip('أسبوعي', 'weekly'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _sortBy = value;
          });
        }
      },
      backgroundColor: Colors.white,
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.deepBlue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11.sp,
      ),
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => _applyFilter(value),
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
            onPressed: _loadSubscriptions,
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

  String _formatDate(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} $hour:$minute';
  }

  String _getDurationText(String duration) {
    switch (duration) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      case 'quarterly':
        return 'ربع سنوي (3 أشهر)';
      case 'yearly':
        return 'سنوي';
      case 'custom':
        return 'مخصص';
      default:
        return duration;
    }
  }

  Widget _buildRemainingDaysBadge(
    int daysRemaining,
    bool isExpired,
    bool isExpiringSoon,
  ) {
    if (isExpired) {
      final daysAgo = daysRemaining.abs();
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Text(
          daysAgo == 0 ? 'منتهي اليوم' : 'منتهي منذ $daysAgo يوم',
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.red.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (daysRemaining == 0) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Text(
          'ينتهي اليوم!',
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.orange.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isExpiringSoon ? Colors.amber.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        'متبقي $daysRemaining ${daysRemaining == 1 ? 'يوم' : 'أيام'}',
        style: TextStyle(
          fontSize: 10.sp,
          color: isExpiringSoon ? Colors.amber.shade900 : Colors.green.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(SubscriptionEntity subscription) {
    final now = DateTime.now();
    final isExpired = subscription.isExpired;
    final isExpiringSoon = subscription.isExpiringSoon;
    final daysRemaining = subscription.daysRemaining;

    // تحديد اللون والنص الفعلي للحالة بدقة متناهية
    Color statusColor;
    String statusText;

    if (subscription.status == 'cancelled') {
      statusColor = Colors.grey;
      statusText = 'ملغي';
    } else if (subscription.status == 'suspended') {
      statusColor = Colors.blueGrey;
      statusText = 'معلق';
    } else if (isExpired) {
      statusColor = Colors.red.shade700;
      statusText = 'منتهي';
    } else if (isExpiringSoon) {
      statusColor = Colors.orange.shade800;
      statusText = daysRemaining == 0 ? 'ينتهي اليوم' : 'ينتهي قريباً';
    } else {
      statusColor = Colors.green.shade700;
      statusText = 'نشط';
    }

    final customerName = (subscription.customerName ?? '').trim();
    final displayName = customerName.isNotEmpty
        ? customerName
        : subscription.name;
    final planSubtitle = customerName.isNotEmpty
        ? '${subscription.name} • ${_getDurationText(subscription.duration)}'
        : '${subscription.type} • ${_getDurationText(subscription.duration)}';

    // حساب نسبة الاستهلاك للشريط الزمني
    final totalDays = subscription.endDate
        .difference(subscription.startDate)
        .inDays;
    final elapsedDays = now.difference(subscription.startDate).inDays;
    final double progress = totalDays <= 0
        ? 1.0
        : (elapsedDays / totalDays).clamp(0.0, 1.0);

    Color progressColor;
    if (isExpired) {
      progressColor = Colors.red;
    } else if (isExpiringSoon) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: isExpired
              ? Colors.red.withValues(alpha: 0.3)
              : isExpiringSoon
              ? Colors.orange.withValues(alpha: 0.4)
              : AssyrianTheme.primaryGold.withValues(alpha: 0.25),
          width: isExpiringSoon || isExpired ? 1.4 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.subscriptionDetails, arguments: subscription);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف العلوي: الاسم، النوع، والسعر
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: isExpired
                        ? Colors.red.shade50
                        : isExpiringSoon
                        ? Colors.orange.shade50
                        : AssyrianTheme.primaryGold.withValues(alpha: 0.12),
                    radius: 20.r,
                    child: Icon(
                      isExpired
                          ? Icons.event_busy
                          : isExpiringSoon
                          ? Icons.alarm
                          : Icons.subscriptions,
                      color: isExpired
                          ? Colors.red.shade700
                          : isExpiringSoon
                          ? Colors.orange.shade800
                          : AssyrianTheme.primaryGold,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.deepBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          planSubtitle,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          _formattingService.formatCurrency(subscription.price),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AssyrianTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? Colors.red.shade100
                              : isExpiringSoon
                              ? Colors.orange.shade100
                              : statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                          border: isExpired
                              ? Border.all(color: Colors.red.shade300)
                              : null,
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 8.h),
              const Divider(height: 1),
              SizedBox(height: 8.h),

              // صف التواريخ وحالة الأيام المتبقية
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${_formatDate(subscription.startDate)} - ${_formatDate(subscription.endDate)}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  _buildRemainingDaysBadge(
                    daysRemaining,
                    isExpired,
                    isExpiringSoon,
                  ),
                ],
              ),

              SizedBox(height: 6.h),

              // شريط تقدم الاستهلاك
              ClipRRect(
                borderRadius: BorderRadius.circular(3.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4.h,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),

              SizedBox(height: 8.h),

              // شريط الشارات والمعلومات الإضافية (الهاتف، التجديد التلقائي، عدد التجديدات)
              Wrap(
                spacing: 6.w,
                runSpacing: 4.h,
                children: [
                  if (subscription.customerPhone != null &&
                      subscription.customerPhone!.trim().isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone,
                            size: 10.sp,
                            color: Colors.blue.shade700,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            subscription.customerPhone!,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (subscription.isAutoRenew)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.autorenew,
                            size: 10.sp,
                            color: Colors.green.shade700,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            'تجديد تلقائي',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (subscription.renewalCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Text(
                        'مُجدد ${subscription.renewalCount} مرات',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.purple.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 6.h),
              const Divider(height: 1),
              SizedBox(height: 4.h),

              // صف الإجراءات السريعة
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.subscriptionDetails,
                        arguments: subscription,
                      );
                    },
                    icon: Icon(Icons.visibility_outlined, size: 14.sp),
                    label: Text('التفاصيل', style: TextStyle(fontSize: 11.sp)),
                  ),
                  if (subscription.canRenew && _canEdit) ...[
                    SizedBox(width: 4.w),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                      onPressed: () {
                        _isRenewingSubscription = true;
                        RenewSubscriptionDialog.show(
                          context,
                          subscription,
                          context.read<SubscriptionBloc>(),
                        );
                      },
                      icon: Icon(Icons.refresh, size: 13.sp),
                      label: Text(
                        'تجديد',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (_canEdit) ...[
                    SizedBox(width: 4.w),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 16.sp,
                        color: Colors.blue.shade700,
                      ),
                      tooltip: 'تعديل',
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/subscriptions/edit',
                          arguments: subscription,
                        );
                      },
                    ),
                  ],
                  if (_canDelete) ...[
                    SizedBox(width: 8.w),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16.sp,
                        color: Colors.red.shade700,
                      ),
                      tooltip: 'حذف',
                      onPressed: () {
                        _showDeleteDialog(subscription);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(SubscriptionEntity subscription) {
    DeleteSubscriptionDialog.show(
      context,
      subscription,
      context.read<SubscriptionBloc>(),
      onDeleted: _loadSubscriptions,
    );
  }
}
