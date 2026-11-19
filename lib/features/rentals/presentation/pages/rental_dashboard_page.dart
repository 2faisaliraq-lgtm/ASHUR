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
import '../bloc/rental_bloc.dart';
import '../widgets/rental_drawer.dart';
import '../widgets/rental_filter_chips.dart';
import '../widgets/rental_quick_actions.dart';
import '../widgets/rental_search_bar.dart';
import '../widgets/rental_stats_section.dart';
import '../widgets/rentals_grid.dart';

/// صفحة لوحة تحكم الإيجارات
class RentalDashboardPage extends StatefulWidget {
  const RentalDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<RentalDashboardPage> createState() => _RentalDashboardPageState();
}

class _RentalDashboardPageState extends State<RentalDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final PermissionChecker _permissionChecker = PermissionChecker();
  final ScrollController _scrollController = ScrollController();
  String? _selectedStatus;
  bool _isGridView = false;
  bool _canCreate = false;
  late RentalBloc _bloc;
  String? _currentOrganizationEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<RentalBloc>();
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
    final canCreate = await _permissionChecker.hasPermission('rentals_create');

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

    // بدء الاستماع للإيجارات مع التحديث الفوري - أول 20 إيجار فقط
    _currentOrganizationEmail = widget.organizationEmail;
    context.read<RentalBloc>().add(
      StartRentalsStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: 10,
      ),
    );
    // بدء الاستماع للإحصائيات مع التحديث الفوري
    context.read<RentalBloc>().add(
      const StartRentalsStatsStreamEvent(limit: null),
    );
  }

  // ===== ملاحظة للمبرمجين المستقبليين =====
  // لماذا _loadRentals لا يستدعي _startRealTimeUpdates مباشرة؟
  // لأن _startRealTimeUpdates يعيد تشغيل الـ streams مما يزيد
  // من احتمالية حدوث حالة السباق. بدلاً من ذلك، نستخدم
  // LoadRentalsEvent لتحميل البيانات يدوياً فقط عندما
  // نفشل في الحصول على البيانات من الـ streams.
  // ==========================================
  void _loadRentals() {
    // في الداشبورد، نستخدم Stream مع أول 20 إيجار للأداء
    _currentOrganizationEmail = widget.organizationEmail;
    context.read<RentalBloc>().add(
      StartRentalsStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: 10,
      ),
    );
    context.read<RentalBloc>().add(
      const StartRentalsStatsStreamEvent(limit: null),
    );
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopRentalsStreamEvent());
    _bloc.add(const StopRentalsStatsStreamEvent());
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
        drawer: RentalDrawer(
          currentRoute: 'dashboard',
          onAddRental: () => _navigateToAddRental(context),
          onSettings: () => _navigateToSettings(context),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        body: BlocBuilder<RentalBloc, RentalState>(
          builder: (context, state) {
            if (state is RentalError) {
              return AppErrorWidget(
                message: state.message,
                onRetry: _loadRentals,
              );
            }

            if (state is RentalsStreamActive) {
              return _buildRentalContent(context, state);
            }

            if (state is RentalLoaded) {
              return _buildRentalContent(context, state);
            }

            // بناء الهيكل فورًا مع بيانات فارغة أثناء التحميل الأول
            return _buildRentalContent(
              context,
              const RentalLoaded(rentals: [], filteredRentals: [], stats: {}),
            );
          },
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                heroTag: 'rentals_dashboard_create_fab',
                onPressed: () => _navigateToAddRental(context),
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                child: Icon(Icons.add, size: 28.sp),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildRentalContent(BuildContext context, dynamic state) {
    return RefreshIndicator(
      onRefresh: () async => _loadRentals(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // قسم الإحصائيات
          SliverToBoxAdapter(
            child: RentalStatsSection(
              stats: state.stats,
              onFilterSelected: (filter) => _openRentalsList(context, filter),
            ),
          ),

          // قسم الإجراءات السريعة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: RentalQuickActions(
                onAddRental: () => _navigateToAddRental(context),
                onRefresh: _loadRentals,
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
                  RentalSearchBar(
                    onSearch: (query) {
                      final orgEmail = _currentOrganizationEmail;
                      if (orgEmail != null && orgEmail.isNotEmpty) {
                        context.read<RentalBloc>().add(
                          StartRentalsStreamEvent(
                            organizationEmail: orgEmail,
                            limit: query.isEmpty ? 20 : null,
                            searchQuery: query.isEmpty ? null : query,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // فلاتر الإيجارات
                  RentalFilterChips(
                    selectedStatus: _selectedStatus,
                    onStatusChanged: (status) {
                      setState(() => _selectedStatus = status);
                      context.read<RentalBloc>().add(
                        FilterRentalsEvent(status: status),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // عنوان قائمة العقود مع عداد وزر التبديل
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
                          'آخر عقود الإيجار',
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
                          'آخر ${state.filteredRentals.length} عقد إيجار',
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
                            Navigator.pushNamed(context, AppRoutes.rentalsList),
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

          // شبكة/قائمة عقود الإيجار
          RentalsGrid(
            rentals: state.filteredRentals,
            onRentalTap: (rental) => _showRentalDetails(context, rental),
            isGridView: _isGridView,
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _openRentalsList(BuildContext context, String filter) {
    Navigator.of(context).pushNamed(AppRoutes.rentalsList, arguments: filter);
  }

  void _navigateToAddRental(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.createRental);
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.rentalsSettings);
  }

  void _showRentalDetails(BuildContext context, rental) {
    Navigator.pushNamed(context, AppRoutes.rentalDetails, arguments: rental);
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
                  'إدارة الإيجارات',
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
