import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/role_entity.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/users_drawer.dart';

/// صفحة عرض جميع الأدوار
class RolesListPage extends StatefulWidget {
  const RolesListPage({super.key});

  @override
  State<RolesListPage> createState() => _RolesListPageState();
}

class _RolesListPageState extends State<RolesListPage> {
  final TextEditingController _searchController = TextEditingController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  late UsersBloc _bloc; // حفظ reference للـ bloc
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // حفظ reference للـ bloc
    _bloc = context.read<UsersBloc>();
    // تحميل جميع البيانات المطلوبة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRealTimeUpdates();
      _loadPermissions();
    });
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission('roles_create');
    final canEdit = await _permissionChecker.hasPermission('roles_edit');
    final canDelete = await _permissionChecker.hasPermission('roles_delete');

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
      });
    }
  }

  void _startRealTimeUpdates() {
    // بدء الاستماع للمستخدمين والأدوار مع التحديث الفوري
    context.read<UsersBloc>().add(const StartUsersStreamEvent());
    // بدء stream الأدوار للتحديث الفوري
    context.read<UsersBloc>().add(const StartRolesStreamEvent());
    // تحميل الصلاحيات بشكل صريح
    context.read<UsersBloc>().add(const LoadPermissionsEvent());
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    if (state is! UsersLoaded ||
        !state.hasMoreRolesData ||
        state.isLoadingMoreRoles) {
      return;
    }
    _bloc.add(const LoadMoreRolesEvent());
  }

  void forceRefresh() {
    _startRealTimeUpdates();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _startRealTimeUpdates();
  }

  void _loadRoles() {
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopUsersStreamEvent());
    _bloc.add(const StopRolesStreamEvent());
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<RoleEntity> _filterRoles(List<RoleEntity> roles) {
    var filtered = roles;

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((role) {
        return role.displayName.toLowerCase().contains(query) ||
            role.name.toLowerCase().contains(query) ||
            (role.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // تطبيق الفلتر (يمكن إضافة فلاتر للأدوار حسب الحاجة)
    // مثلاً: فلترة حسب عدد الصلاحيات أو نوع الدور

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const UsersDrawer(currentRoute: AppRoutes.rolesManagement),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'roles_create_fab',
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.createRole);
                if (result == true) forceRefresh();
              },
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
          } else if (state is RoleCreated) {
            forceRefresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إنشاء الدور بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            // لا حاجة لإعادة التحميل - الـ bloc يقوم بذلك تلقائياً
          } else if (state is RoleUpdated) {
            forceRefresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تحديث الدور بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            // لا حاجة لإعادة التحميل - الـ bloc يقوم بذلك تلقائياً
          } else if (state is RoleDeleted) {
            forceRefresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حذف الدور بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            // لا حاجة لإعادة التحميل - الـ bloc يقوم بذلك تلقائياً
          }
        },
        builder: (context, state) {
          // إذا كانت الحالة أولية أو تحميل، نعرض شاشة التحميل
          if (state is UsersInitial || state is UsersLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل الأدوار...'),
                ),
              ],
            );
          }

          // التحقق من الأخطاء أولاً قبل معالجة البيانات
          if (state is UsersError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          var allRoles = <RoleEntity>[];

          if (state is UsersLoaded) {
            allRoles = state.roles.cast<RoleEntity>();
          } else if (state is UsersStreamActive) {
            allRoles = state.roles.cast<RoleEntity>();
          }

          final filteredRoles = _filterRoles(allRoles);

          final bool hasMoreRolesData = state is UsersLoaded
              ? state.hasMoreRolesData
              : state is UsersStreamActive && state.hasMoreRolesData;
          final bool isLoadingMoreRoles = state is UsersLoaded
              ? state.isLoadingMoreRoles
              : state is UsersStreamActive && state.isLoadingMoreRoles;

          if (filteredRoles.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'لا توجد أدوار',
                    message: 'ابدأ بإضافة دور جديد',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: PaginatedListView<RoleEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredRoles,
                  hasMore: hasMoreRolesData,
                  isLoadingMore: isLoadingMoreRoles,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildRoleCard(filteredRoles[index]),
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
                  'قائمة الأدوار',
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
        IconButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.users),
          icon: Icon(
            Icons.people,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          tooltip: 'إدارة المستخدمين',
        ),
        IconButton(
          onPressed: _loadRoles,
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
                      setState(() {});
                    },
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'البحث عن دور...',
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
                'نوع الدور',
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
              _buildFilterChip('إداري', 'admin'),
              _buildFilterChip('مستخدم', 'user'),
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
            onPressed: _loadRoles,
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

  Widget _buildRoleCard(RoleEntity role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        onTap: () {
          _showRoleDetails(role);
        },
        leading: CircleAvatar(
          backgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
          radius: 25.r,
          child: Icon(
            Icons.admin_panel_settings,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
        ),
        title: Text(
          role.displayName,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              role.description ?? 'لا يوجد وصف',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              'الصلاحيات: ${role.permissions.length}',
              style: TextStyle(
                fontSize: 12.sp,
                color: AssyrianTheme.primaryGold,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                role.name,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 4.w),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.editRole, arguments: role);
                } else if (value == 'delete') {
                  _confirmDelete(role);
                }
              },
              itemBuilder: (context) => [
                if (_canEdit)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18.sp, color: Colors.blue),
                        SizedBox(width: 8.w),
                        const Text('تعديل'),
                      ],
                    ),
                  ),
                if (_canDelete)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18.sp, color: Colors.red),
                        SizedBox(width: 8.w),
                        const Text('حذف'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleDetails(RoleEntity role) {
    Navigator.of(context).pushNamed(AppRoutes.roleDetails, arguments: role);
  }

  void _confirmDelete(RoleEntity role) {
    // التحقق من الصلاحيات أولاً
    if (!_canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ليس لديك صلاحية لحذف الأدوار',
            style: TextStyle(fontSize: 12.sp),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // التأكد من تحميل بيانات المستخدمين أولاً
    final currentState = context.read<UsersBloc>().state;
    if (currentState is! UsersLoaded) {
      // تحميل البيانات إذا لم تكن محملة
      context.read<UsersBloc>().add(const StartUsersStreamEvent());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'جاري تحميل بيانات المستخدمين...',
            style: TextStyle(fontSize: 12.sp),
          ),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // التحقق من كون الدور هو دور المدير الرئيسي
    if (role.name == 'admin') {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AssyrianTheme.ivoryWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AssyrianTheme.primaryGold, width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 24.sp),
              SizedBox(width: 8.w),
              Text(
                'لا يمكن الحذف',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: Colors.red[700],
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'لا يمكن حذف دور المدير الرئيسي لأنه ضروري لعمل النظام.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.red[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'دور المدير الرئيسي محمي من الحذف للحفاظ على أمان النظام.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
              ),
              child: const Text('فهمت'),
            ),
          ],
        ),
      );
      return;
    }

    // البحث عن المستخدمين الذين لديهم هذا الدور
    final state = context.read<UsersBloc>().state;
    final usersWithRole = <String>[];

    if (state is UsersLoaded) {
      for (final user in state.users) {
        if (user.roles.any((userRole) => userRole.id == role.id)) {
          final userName = user.name ?? user.email ?? 'مستخدم غير معروف';
          usersWithRole.add(userName);
        }
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AssyrianTheme.ivoryWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AssyrianTheme.primaryGold, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24.sp),
            SizedBox(width: 8.w),
            Text(
              'تأكيد حذف الدور',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AssyrianTheme.deepBlue,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من حذف الدور "${role.displayName}"؟',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AssyrianTheme.deepBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16.h),

              // عرض المستخدمين المتأثرين
              if (usersWithRole.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            color: Colors.orange[700],
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'المستخدمون المتأثرون (${usersWithRole.length}):',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      ...usersWithRole
                          .take(5)
                          .map(
                            (userName) => Padding(
                              padding: EdgeInsets.only(bottom: 4.h),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 14.sp,
                                    color: Colors.orange[600],
                                  ),
                                  SizedBox(width: 6.w),
                                  Expanded(
                                    child: Text(
                                      userName,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (usersWithRole.length > 5)
                        Text(
                          'و ${usersWithRole.length - 5} مستخدمين آخرين...',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.orange[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_forever,
                        color: Colors.red[700],
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'تحذير: سيتم حذف جميع المستخدمين الذين لديهم هذا الدور فقط!',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.red[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[700],
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'لا يوجد مستخدمون لديهم هذا الدور.',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.green[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 12.h),
              Text(
                'هذا الإجراء لا يمكن التراجع عنه.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(color: AssyrianTheme.deepBlue, fontSize: 14.sp),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // استخدام context الأصلي بدلاً من dialogContext
              context.read<UsersBloc>().add(DeleteRoleEvent(role.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            ),
            child: Text(
              usersWithRole.isNotEmpty ? 'حذف الدور والمستخدمين' : 'حذف الدور',
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }
}
