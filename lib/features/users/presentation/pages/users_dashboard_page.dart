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
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/users_drawer.dart';
import '../widgets/users_filter_chips.dart';
import '../widgets/users_grid.dart';
import '../widgets/users_quick_actions.dart';
import '../widgets/users_search_bar.dart';
import '../widgets/users_stats_section.dart';
import '../../domain/entities/user_management_entity.dart';

/// صفحة لوحة تحكم المستخدمين
class UsersDashboardPage extends StatefulWidget {
  const UsersDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<UsersDashboardPage> createState() => _UsersDashboardPageState();
}

class _UsersDashboardPageState extends State<UsersDashboardPage>
    with AutomaticKeepAliveClientMixin {
  final PermissionChecker _permissionChecker = PermissionChecker();
  final ScrollController _scrollController = ScrollController();
  String? _selectedFilter;
  bool _isGridView = false;
  bool _canCreate = false;
  late UsersBloc _usersBloc;
  String? _currentOrganizationEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _usersBloc = context.read<UsersBloc>();
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
    final canCreate = await _permissionChecker.hasPermission('users_create');

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
    // لأن UsersBloc بالفعل يعيد تحميل البيانات بعد كل عملية
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

    // بدء الاستماع للمستخدمين مع التحديث الفوري - أول 20 مستخدم فقط
    _currentOrganizationEmail = widget.organizationEmail;
    context.read<UsersBloc>().add(
      StartUsersStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: 10,
      ),
    );

    // بدء الاستماع للإحصائيات مع التحديث الفوري
    context.read<UsersBloc>().add(
      StartUsersStatsStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: null,
      ),
    );

    // تحميل الأدوار (لا تحتاج stream لأنها لا تتغير كثيراً)
    context.read<UsersBloc>().add(const LoadRolesEvent());
  }

  void _loadUsers() {
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا لا نستدعي _startRealTimeUpdates() هنا؟
    // لأن _startRealTimeUpdates يعيد تشغيل الـ streams مما يزيد
    // من احتمالية حدوث حالة السباق. بدلاً من ذلك، نستخدم
    // StartUsersStreamEvent و StartUsersStatsStreamEvent
    // لتحميل البيانات يدوياً فقط عندما نفشل في الحصول على البيانات
    // من الـ streams.
    // ==========================================
    _currentOrganizationEmail = widget.organizationEmail;
    _usersBloc.add(
      StartUsersStreamEvent(
        organizationEmail: widget.organizationEmail,
        limit: 10,
      ),
    );
    _usersBloc.add(
      StartUsersStatsStreamEvent(organizationEmail: widget.organizationEmail),
    );
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _usersBloc.add(const StopUsersStreamEvent());
    _usersBloc.add(const StopUsersStatsStreamEvent());
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
        drawer: const UsersDrawer(currentRoute: AppRoutes.dashboard),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        body: BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            if (state is UsersError) {
              return AppErrorWidget(
                message: state.message,
                onRetry: _loadUsers,
              );
            }

            if (state is UsersStreamActive) {
              return _buildUsersContent(context, state);
            }

            if (state is UsersLoaded) {
              return _buildUsersContent(context, state);
            }

            if (state is UsersRefreshing) {
              return _buildUsersContent(
                context,
                UsersLoaded(users: state.currentUsers, statistics: null),
              );
            }

            // بناء الهيكل فورًا مع بيانات فارغة أثناء التحميل الأول
            return _buildUsersContent(context, const UsersLoaded(users: []));
          },
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton(
                heroTag: 'users_dashboard_create_fab',
                onPressed: () => _navigateToAddUser(context),
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                child: Icon(Icons.add, size: 28.sp),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  void _openUsersList(BuildContext context, String filter) {
    Navigator.of(context).pushNamed(AppRoutes.usersList, arguments: filter);
  }

  Widget _buildUsersContent(BuildContext context, dynamic state) {
    return RefreshIndicator(
      onRefresh: () async => _loadUsers(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // قسم الإحصائيات
          SliverToBoxAdapter(
            child: UsersStatsSection(
              users: state.users,
              statistics: state.statistics,
              onFilterSelected: (filter) => _openUsersList(context, filter),
            ),
          ),

          // قسم الإجراءات السريعة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: UsersQuickActions(
                onAddUser: () => _navigateToAddUser(context),
                onManageRoles: () => _navigateToManageRoles(context),
                onRefresh: _loadUsers,
                onSettings: () =>
                    Navigator.pushNamed(context, AppRoutes.usersSettings),
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
                  UsersSearchBar(
                    onSearch: (query) {
                      final orgEmail = _currentOrganizationEmail;
                      if (orgEmail != null && orgEmail.isNotEmpty) {
                        context.read<UsersBloc>().add(
                          StartUsersStreamEvent(
                            organizationEmail: orgEmail,
                            limit: query.isEmpty ? 20 : null,
                            searchQuery: query.isEmpty ? null : query,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // فلاتر المستخدمين
                  UsersFilterChips(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (filter) {
                      setState(() => _selectedFilter = filter);
                      // الفلترة ستتم لاحقاً
                    },
                  ),
                ],
              ),
            ),
          ),

          // عنوان قائمة المستخدمين مع عداد وزر التبديل
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
                          'آخر المستخدمين',
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
                          'آخر ${state.users.length} مستخدم',
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
                        onPressed: () => _openUsersList(context, 'all'),
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

          // قائمة/شبكة المستخدمين
          UsersGrid(
            users: _filterUsersByState(state),
            onUserTap: (user) => _showUserDetails(context, user),
            isGridView: _isGridView,
          ),

          // مساحة إضافية في الأسفل للـ FAB
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _navigateToAddUser(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.createUser);
  }

  void _navigateToManageRoles(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.rolesManagement);
  }

  void _showUserDetails(BuildContext context, user) {
    Navigator.of(context).pushNamed(AppRoutes.userDetails, arguments: user);
  }

  /// تصفية قائمة المستخدمين حسب الفلتر المحدد
  List<UserManagementEntity> _filterUsersByState(dynamic state) {
    final users = state.users.cast<UserManagementEntity>();
    if (_selectedFilter == null || _selectedFilter == 'all') return users;
    if (_selectedFilter == 'active') {
      return users.where((u) => u.isActive).toList();
    }
    if (_selectedFilter == 'inactive') {
      return users.where((u) => !u.isActive).toList();
    }
    // فلترة حسب دور (admin, editor, viewer)
    return users
        .where((u) => u.roles.any((role) => role.name == _selectedFilter))
        .toList();
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
                  'إدارة المستخدمين',
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
