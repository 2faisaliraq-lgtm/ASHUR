import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/user_management_entity.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/delete_user_dialog.dart';
import '../widgets/users_drawer.dart';

/// صفحة عرض جميع المستخدمين
class UsersListPage extends StatefulWidget {
  const UsersListPage({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  bool _hasInitialized = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canViewReports = false;
  bool _canManageRoles = false;
  late UsersBloc _bloc; // حفظ reference للـ bloc

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
    }
    // حفظ reference للـ bloc
    _bloc = context.read<UsersBloc>();
    // إضافة مستمع للتمرير
    _scrollController.addListener(_onScroll);
    // تحميل البيانات فوراً عند بناء الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized) {
        _hasInitialized = true;
        _loadUsersPaginated();
        _loadPermissions();
      }
    });
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission('users_create');
    final canEdit = await _permissionChecker.hasPermission('users_edit');
    final canDelete = await _permissionChecker.hasPermission('users_delete');
    final canViewReports = await _permissionChecker.hasPermission(
      'users_reports_view',
    );
    final canManageRoles = await _permissionChecker.hasPermission(
      'roles_manage',
    );

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
        _canViewReports = canViewReports;
        _canManageRoles = canManageRoles;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // تحقق من الحالة الحالية قبل إعادة التحميل - فقط إذا لم يتم التهيئة بعد
    if (!_hasInitialized) {
      final currentState = context.read<UsersBloc>().state;
      if (currentState is UsersInitial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_hasInitialized) {
            _hasInitialized = true;
            _loadUsersPaginated();
          }
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    if (state is! UsersLoaded || !state.hasMore || state.isLoadingMore) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _bloc.add(LoadMoreUsersEvent(user.email!));
    }
  }

  void _loadUsersPaginated({bool isRefresh = false}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<UsersBloc>().add(
        LoadUsersPaginatedEvent(
          organizationEmail: user.email!,
          isRefresh: isRefresh,
        ),
      );
    }
  }

  void _loadUsers() {
    _loadUsersPaginated(isRefresh: true);
  }

  void _onSearchChanged(String query) {
    context.read<UsersBloc>().add(SearchUsersEvent(query));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<UserManagementEntity> _filterUsers(List<UserManagementEntity> users) {
    var filtered = users;

    // تطبيق الفلتر أولاً
    if (_selectedFilter == 'active') {
      filtered = filtered.where((user) => user.isActive).toList();
    } else if (_selectedFilter == 'inactive') {
      filtered = filtered.where((user) => !user.isActive).toList();
    } else if (_selectedFilter == 'admins') {
      filtered = filtered
          .where(
            (user) =>
                user.roleIds.contains('admin') ||
                user.roles.any(
                  (role) => role.id == 'admin' || role.name == 'admin',
                ),
          )
          .toList();
    }

    // ثم تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((user) {
        return (user.name?.toLowerCase().contains(query) ?? false) ||
            (user.email?.toLowerCase().contains(query) ?? false) ||
            (user.phoneNumber?.toLowerCase().contains(query) ?? false) ||
            user.roles.any((role) => role.name.toLowerCase().contains(query));
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const UsersDrawer(currentRoute: AppRoutes.users),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.createUser);
                if (result == true) _loadUsersPaginated(isRefresh: true);
              },
              heroTag: 'users_create_fab',
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<UsersBloc, UsersState>(
        listener: (context, state) {
          if (state is UsersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is UserCreated) {
            _loadUsersPaginated(isRefresh: true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إنشاء المستخدم بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            // لا حاجة لإعادة التحميل - الـ bloc يقوم بذلك تلقائياً
          } else if (state is UserUpdated) {
            _loadUsersPaginated(isRefresh: true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تحديث المستخدم بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            // لا حاجة لإعادة التحميل - الـ bloc يقوم بذلك تلقائياً
          } else if (state is UserDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حذف المستخدم بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            // لا حاجة لإعادة التحميل - الـ bloc يقوم بذلك تلقائياً
          }
        },
        builder: (context, state) {
          var allUsers = <UserManagementEntity>[];
          var isInitialLoading = false;

          // التعامل مع حالات مختلفة
          if (state is UsersInitial) {
            isInitialLoading = true;
          } else if (state is UsersLoading) {
            isInitialLoading = true;
          } else if (state is UsersRefreshing) {
            // في حالة التحديث، نعرض البيانات الحالية مع مؤشر تحديث
            allUsers = state.currentUsers;
          } else if (state is UsersLoaded) {
            allUsers = state.users.cast<UserManagementEntity>();
          } else if (state is UsersStreamActive) {
            allUsers = state.users.cast<UserManagementEntity>();
          } else if (state is UsersError) {
            // في حالة الخطأ، نتحقق إذا كانت هناك بيانات محفوظة
            if (state.message.contains('تم الاحتفاظ بالبيانات السابقة')) {
              // استخراج البيانات من رسالة الخطأ أو من حالة سابقة
              final bloc = context.read<UsersBloc>();
              if (bloc.state is UsersLoaded) {
                allUsers = (bloc.state as UsersLoaded).users;
              }
            } else {
              return Column(
                children: [
                  _buildSearchFilter(),
                  Expanded(child: _buildErrorState(state.message)),
                ],
              );
            }
          }

          // إذا كان التحميل الأولي ولا توجد بيانات
          if (isInitialLoading && allUsers.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل المستخدمين...'),
                ),
              ],
            );
          }

          final filteredUsers = _filterUsers(allUsers);

          // إذا لم توجد نتائج بعد الفلترة
          if (filteredUsers.isEmpty &&
              !isInitialLoading &&
              state is! UsersRefreshing) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    title: 'لا توجد مستخدمين',
                    message: 'ابدأ بإضافة مستخدم جديد',
                    icon: Icons.people_outline,
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              // مؤشر التحديث
              if (state is UsersRefreshing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LoadingWidget(size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'جاري التحديث...',
                        style: TextStyle(
                          color: AssyrianTheme.deepBlue,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filteredUsers.isEmpty
                    ? AppEmptyState(
                        title: 'لا توجد مستخدمين',
                        message: 'ابدأ بإضافة مستخدم جديد',
                        icon: Icons.people_outline,
                      )
                    : PaginatedListView<UserManagementEntity>(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(4),
                        items: filteredUsers,
                        hasMore: state is UsersLoaded && state.hasMore,
                        isLoadingMore:
                            state is UsersLoaded && state.isLoadingMore,
                        onLoadMore: _onScroll,
                        itemBuilder: (context, index) =>
                            _buildUserCard(filteredUsers[index]),
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
      actions: [
        if (_canViewReports)
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.usersReports),
            icon: Icon(
              Icons.analytics,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تقارير المستخدمين',
          ),
        if (_canManageRoles)
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.rolesManagement),
            icon: Icon(
              Icons.admin_panel_settings,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'إدارة الأدوار',
          ),
        // مؤشر التحديث في شريط التطبيق
        BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            if (state is UsersRefreshing) {
              return Padding(
                padding: EdgeInsets.all(12.w),
                child: SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: LoadingWidget(size: 20),
                ),
              );
            }
            return IconButton(
              onPressed: _loadUsers,
              icon: Icon(
                Icons.refresh,
                color: AssyrianTheme.primaryGold,
                size: 24.sp,
              ),
              tooltip: 'تحديث',
            );
          },
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
          // شريط البحث الرئيسي
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // حقل البحث
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _onSearchChanged(value);
                    },
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'البحث عن مستخدم...',
                      hintTextDirection: TextDirection.rtl,
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
                // زر الفلتر
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
          // قسم الفلاتر القابل للطي
          if (_isFilterExpanded) _buildFiltersSection(),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 8.h),
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
                'حالة المستخدم',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
              const Spacer(),
              if (_selectedFilter != 'all')
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFilter = 'all';
                    });
                  },
                  child: Text(
                    'مسح الفلتر',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AssyrianTheme.primaryGold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildFilterChip('الكل', 'all'),
              _buildFilterChip('نشط', 'active'),
              _buildFilterChip('غير نشط', 'inactive'),
              _buildFilterChip('المدراء', 'admins'),
            ],
          ),
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
      },
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
      checkmarkColor: AssyrianTheme.deepBlue,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.deepBlue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 14.sp,
      ),
      side: BorderSide(
        color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[400]!,
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red[400]),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.red[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              message,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadUsers,
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

  Widget _buildUserCard(UserManagementEntity user) {
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
            Navigator.of(
              context,
            ).pushNamed(AppRoutes.userDetails, arguments: user);
          },
          leading: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 100.w),
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.of(
                  context,
                ).pushNamed(AppRoutes.editUser, arguments: user);
              } else if (value == 'delete') {
                _confirmDelete(user);
              } else if (value == 'toggle_status') {
                _toggleUserStatus(user);
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
              if (_canEdit)
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(
                        user.isActive ? Icons.block : Icons.check_circle,
                        size: 16.sp,
                        color: user.isActive ? Colors.orange : Colors.green,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        user.isActive ? 'تعطيل' : 'تفعيل',
                        style: TextStyle(fontSize: 13.sp),
                      ),
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
              backgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              radius: 22.r,
              child: Text(
                (user.name?.isNotEmpty ?? false)
                    ? user.name![0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.primaryGold,
                ),
              ),
            ),
          ),
          title: Text(
            user.name ?? 'مستخدم غير معروف',
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
                user.email ?? 'غير محدد',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (user.roles.isNotEmpty) ...[
                SizedBox(height: 3.h),
                Wrap(
                  spacing: 4.w,
                  runSpacing: 4.h,
                  children: user.roles.take(2).map((role) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        role.displayName,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: AssyrianTheme.deepBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
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
                    color: user.isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    user.isActive ? 'نشط' : 'غير نشط',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: user.isActive ? Colors.green : Colors.red,
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

  void _toggleUserStatus(UserManagementEntity user) {
    context.read<UsersBloc>().add(
      ToggleUserStatusEvent(userId: user.id, isActive: !user.isActive),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          user.isActive ? 'تم تعطيل المستخدم' : 'تم تفعيل المستخدم',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmDelete(UserManagementEntity user) {
    DeleteUserDialog.show(
      context,
      user,
      context.read<UsersBloc>(),
      onDeleted: _loadUsers,
    );
  }
}
