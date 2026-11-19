import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/entities/user_management_entity.dart';
import '../../domain/repositories/users_repository.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/users_drawer.dart';

/// صفحة تفاصيل المستخدم
class UserDetailsPage extends StatefulWidget {
  const UserDetailsPage({required this.user, super.key});
  final UserManagementEntity user;

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage>
    with SaveOperationMixin<UserDetailsPage> {
  late UserManagementEntity currentUser;
  final Set<String> _searchedUserIds =
      {}; // cache للمستخدمين الذين تم البحث عنهم
  final Map<String, String> _userNamesCache = {}; // cache لأسماء المستخدمين
  String? _createdByName; // اسم منشئ المستخدم
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canManageStatus = false;
  bool _operationCompleted = false;
  bool _didInit = false;
  bool _isRefreshingUser = false; // منع طلبات متكررة متزامنة لنفس المستخدم

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    _loadPermissions();
    _loadCreatorName(); // تحميل اسم المنشئ
    _didInit = true;

    // تحديث بيانات المستخدم وتحميل جميع المستخدمين
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UsersBloc>().add(GetUserByIdEvent(widget.user.id));
      // ❌ تم إزالة StartUsersStreamEvent() هنا — بدء ستريم جميع المستخدمين
      // في صفحة تفاصيل مستخدم واحد غير ضروري ويزيد من استهلاك الشبكة
      // والموارد. يتم جلب المستخدم المحدد فقط عبر GetUserByIdEvent أعلاه.
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // عند العودة من شاشة التعديل، نتحقق مما إذا تم تحديث المستخدم
    // لا نستدعي هذا في المرة الأولى لأن initState سيقوم بالتحديث
    if (!_didInit) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // نتحقق من حالة الـ bloc الحالية أولاً
      final bloc = context.read<UsersBloc>();
      final currentState = bloc.state;

      // إذا كانت الحالة UserUpdated، نستخدم البيانات منها مباشرة
      if (currentState is UserUpdated &&
          currentState.user.id == widget.user.id) {
        setState(() {
          currentUser = currentState.user;
        });
      }
      // إذا كانت الحالة UsersLoaded، نبحث عن المستخدم في القائمة
      else if (currentState is UsersLoaded) {
        final updatedUser = currentState.users.firstWhere(
          (u) => u.id == widget.user.id,
          orElse: () => widget.user,
        );
        if (updatedUser.id == widget.user.id && updatedUser != currentUser) {
          setState(() {
            currentUser = updatedUser;
          });
        }
      }
      // إذا كانت الحالة UsersStreamActive، نبحث عن المستخدم في القائمة
      else if (currentState is UsersStreamActive) {
        final updatedUser = currentState.users.firstWhere(
          (u) => u.id == widget.user.id,
          orElse: () => widget.user,
        );
        if (updatedUser.id == widget.user.id && updatedUser != currentUser) {
          setState(() {
            currentUser = updatedUser;
          });
        }
      }

      // تجنب طلبات متكررة متزامنة لنفس المستخدم
      if (_isRefreshingUser) return;
      _isRefreshingUser = true;

      // نطلب تحديث بيانات المستخدم من السيرفر لضمان الحصول على أحدث البيانات
      bloc.add(GetUserByIdEvent(widget.user.id));
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final canEdit = await _permissionChecker.hasPermission('users_edit');
    final canDelete = await _permissionChecker.hasPermission('users_delete');
    final canManageStatus = await _permissionChecker.hasPermission(
      'users_manage_status',
    );

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
        _canDelete = canDelete;
        _canManageStatus = canManageStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: const UsersDrawer(currentRoute: AppRoutes.userDetails),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canEdit && currentUser.roles.isNotEmpty
          ? FloatingActionButton(
              heroTag: 'users_details_edit_fab',
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamed(AppRoutes.editUser, arguments: currentUser);
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.edit, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocListener<UsersBloc, UsersState>(
        listenWhen: (previous, current) {
          // نستمع لجميع الحالات المتعلقة بالمستخدم الحالي
          return current is UserLoaded ||
              current is UsersError ||
              current is UserUpdated ||
              current is UserDeleted ||
              current is UsersLoaded ||
              current is UsersStreamActive ||
              current is UsersOperationSuccess;
        },
        listener: (context, state) {
          if (state is UserLoaded) {
            // تحديث currentUser عند تحميل بيانات المستخدم (مستخدم واحد)
            // نتأكد أن المستخدم المحدّث هو نفس المستخدم الحالي
            if (state.user.id == widget.user.id) {
              setState(() {
                currentUser = state.user;
                // حفظ اسم المستخدم في الـ cache
                if (state.user.name != null) {
                  _userNamesCache[state.user.id] = state.user.name!;
                  if (state.user.email != null) {
                    _userNamesCache[state.user.email!] = state.user.name!;
                  }
                }
              });
              _isRefreshingUser = false;
            }
          } else if (state is UserUpdated) {
            // تحديث currentUser عند تحديث المستخدم - دائماً نقوم بالتحديث إذا كان نفس المستخدم
            if (state.user.id == widget.user.id) {
              setState(() {
                currentUser = state.user;
              });
            }
            // إظهار رسالة النجاح فقط إذا لم تكن العملية قد اكتملت من قبل
            // ✅ هذه شاشة تفاصيل: نعرض رسالة ونبقى فيها فقط،
            // ولا نستدعي completeSaveOperation لأنها تُغلق نافذة
            // تحميل غير موجودة هنا فتُغلق شاشة التفاصيل نفسها
            if (!_operationCompleted) {
              _operationCompleted = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('تم تحديث المستخدم بنجاح'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          } else if (state is UsersLoaded) {
            // تحديث currentUser من قائمة المستخدمين (من الـ stream أو LoadUsersEvent)
            final updatedUser = state.users.firstWhere(
              (u) => u.id == widget.user.id,
              orElse: () => widget.user,
            );
            if (updatedUser.id == widget.user.id &&
                updatedUser != currentUser) {
              setState(() {
                currentUser = updatedUser;
              });
            }
            // تحديث الـ cache
            for (final user in state.users) {
              if (user.name != null) {
                _userNamesCache[user.id] = user.name!;
                if (user.email != null) {
                  _userNamesCache[user.email!] = user.name!;
                }
              }
            }
          } else if (state is UsersStreamActive) {
            // تحديث currentUser من الـ stream النشط
            final updatedUser = state.users.firstWhere(
              (u) => u.id == widget.user.id,
              orElse: () => widget.user,
            );
            if (updatedUser.id == widget.user.id &&
                updatedUser != currentUser) {
              setState(() {
                currentUser = updatedUser;
              });
            }
          } else if (state is UsersError && !_operationCompleted) {
            // تجاهل أخطاء البحث عن المستخدمين (مثل "المستخدم غير موجود")
            // هذه الأخطاء تحدث عند البحث عن منشئ المستخدم
            // ✅ نعرض رسالة الخطأ ونبقى في شاشة التفاصيل، ولا
            // نستدعي failSaveOperation لأنها تُغلق نافذة تحميل
            // غير موجودة هنا فتُغلق شاشة التفاصيل نفسها عند
            // أي خطأ (كان الخطأ يُخرج المستخدم من الصفحة)
            if (!state.message.contains('المستخدم غير موجود')) {
              _operationCompleted = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          } else if (state is UserDeleted && !_operationCompleted) {
            _operationCompleted = true;
            // تم حذف المستخدم — نعرض رسالة ثم نعود للشاشة
            // السابقة (بدلاً من completeSaveOperation التي تُغلق
            // نافذة تحميل غير موجودة فتحدث إغلاقاً مزدوجاً)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم حذف المستخدم بنجاح'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
            Navigator.of(context).pop();
          }
        },
        child: BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            if (state is UsersLoading) {
              return LoadingWidget(message: 'جاري التحميل...');
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserHeader(),
                  const SizedBox(height: 6),
                  _buildPersonalInfoCard(),
                  const SizedBox(height: 6),
                  _buildRolesCard(),
                  const SizedBox(height: 6),
                  _buildPermissionsCard(),
                  const SizedBox(height: 6),
                  _buildAccountStatusCard(),
                  const SizedBox(height: 6),
                  _buildSystemInfoCard(),
                  const SizedBox(height: 6),
                  _buildActionButtons(),
                  const SizedBox(
                    height: 80,
                  ), // مساحة إضافية للـ floating action button
                ],
              ),
            );
          },
        ),
      ),
    );
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
                  'تفاصيل المستخدم',
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
                  currentUser.name ?? 'مستخدم',
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
        if (_canEdit)
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamed(AppRoutes.editUser, arguments: currentUser);
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل المستخدم',
          ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'toggle':
                if (_canManageStatus) _toggleUserStatus();
                break;
              case 'delete':
                if (_canDelete) _showDeleteDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            if (_canManageStatus)
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      currentUser.isActive ? Icons.block : Icons.check_circle,
                      size: 16.sp,
                      color: currentUser.isActive ? Colors.red : Colors.green,
                    ),
                    SizedBox(width: 8.w),
                    Text(currentUser.isActive ? 'إلغاء التفعيل' : 'تفعيل'),
                  ],
                ),
              ),
            if (_canDelete)
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16.sp, color: Colors.red),
                    SizedBox(width: 8.w),
                    const Text('حذف'),
                  ],
                ),
              ),
          ],
          icon: Icon(
            Icons.more_vert,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildUserHeader() {
    return DetailScreenHeader(
      title: currentUser.name ?? 'غير محدد',
      subtitle: _formatEmail(currentUser.email ?? 'غير محدد'),
      icon: Icons.person,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildPersonalInfoCard() {
    return InfoCard(
      title: 'المعلومات الشخصية',
      icon: Icons.person,
      children: [
        DetailRow(label: 'الاسم الكامل', value: currentUser.name ?? 'غير محدد'),
        DetailRow(
          label: 'البريد الإلكتروني',
          value: currentUser.email ?? 'غير محدد',
        ),
        DetailRow(
          label: 'رقم الهاتف',
          value: currentUser.phoneNumber ?? 'غير محدد',
        ),
        DetailRow(label: 'القسم', value: currentUser.department ?? 'غير محدد'),
        DetailRow(
          label: 'المسمى الوظيفي',
          value: currentUser.jobTitle ?? 'غير محدد',
        ),
      ],
    );
  }

  Widget _buildRolesCard() {
    return InfoCard(
      title: 'الأدوار',
      icon: Icons.admin_panel_settings,
      children: [
        if (currentUser.roles.isEmpty)
          Text(
            'لا توجد أدوار مخصصة',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ...currentUser.roles.map(_buildRoleChip),
      ],
    );
  }

  Widget _buildPermissionsCard() {
    // ✅ استخدام الصلاحيات المخصصة إذا كانت موجودة
    // إذا كانت فارغة، نستخدم صلاحيات الدور (للتوافق مع المستخدمين القدامى)
    final displayedPermissions = currentUser.customPermissions.isNotEmpty
        ? currentUser.customPermissions.toSet()
        : currentUser.allPermissions.toSet();

    return InfoCard(
      title: 'الصلاحيات',
      icon: Icons.security,
      children: [
        if (displayedPermissions.isEmpty)
          Text(
            'لا توجد صلاحيات',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: displayedPermissions.map(_buildPermissionChip).toList(),
          ),
      ],
    );
  }

  Widget _buildAccountStatusCard() {
    return InfoCard(
      title: 'حالة الحساب',
      icon: Icons.account_circle,
      children: [
        DetailRow(
          label: 'الحالة',
          value: currentUser.isActive ? 'نشط' : 'غير نشط',
        ),
        DetailRow(
          label: 'البريد محقق',
          value: currentUser.isEmailVerified ? 'نعم' : 'لا',
        ),
      ],
    );
  }

  Widget _buildSystemInfoCard() {
    return InfoCard(
      title: 'معلومات النظام',
      icon: Icons.info,
      children: [
        DetailRow(label: 'معرف المستخدم', value: _formatUserId(currentUser.id)),
        DetailRow(
          label: 'تاريخ الإنشاء',
          value: _formatDate(currentUser.createdAt),
        ),
        if (currentUser.createdBy?.isNotEmpty ?? false)
          DetailRow(
            label: 'أنشئ بواسطة',
            value: _createdByName ?? _getCreatorName(currentUser.createdBy!),
          ),
      ],
    );
  }

  Widget _buildRoleChip(RoleEntity role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 14.sp,
            color: AssyrianTheme.primaryGold,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.displayName,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                if (role.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    role.description!,
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionChip(String permission) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Text(
        _getPermissionDisplayName(permission),
        style: TextStyle(
          fontSize: 10.sp,
          color: Colors.blue[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_canManageStatus || _canDelete)
          Row(
            children: [
              if (_canManageStatus)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleUserStatus,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: currentUser.isActive
                          ? Colors.red
                          : Colors.green,
                      side: BorderSide(
                        color: currentUser.isActive ? Colors.red : Colors.green,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      currentUser.isActive ? Icons.block : Icons.check_circle,
                      size: 16.sp,
                    ),
                    label: Text(
                      currentUser.isActive ? 'إلغاء التفعيل' : 'تفعيل',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                  ),
                ),
              if (_canManageStatus && _canDelete) const SizedBox(width: 8),
              if (_canDelete)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showDeleteDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.delete, size: 16.sp),
                    label: Text('حذف', style: TextStyle(fontSize: 12.sp)),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  void _toggleUserStatus() {
    if (isSaving) return;
    _operationCompleted = false;
    context.read<UsersBloc>().add(
      ToggleUserStatusEvent(
        userId: currentUser.id,
        isActive: !currentUser.isActive,
      ),
    );
  }

  void _showDeleteDialog() {
    if (isSaving) return;
    _operationCompleted = false;
    // التحقق من كون المستخدم مدير
    final isAdmin = currentUser.roles.any((role) => role.name == 'admin');

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
            Icon(Icons.warning, color: Colors.red, size: 20.sp),
            const SizedBox(width: 6),
            Text(
              'حذف المستخدم',
              style: TextStyle(
                fontSize: 16.sp,
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
            Text(
              'هل أنت متأكد من حذف المستخدم "${currentUser.name}"؟',
              style: TextStyle(fontSize: 12.sp, color: AssyrianTheme.deepBlue),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
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
                      size: 14.sp,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'تحذير: هذا المستخدم له دور مدير. سيتم حذف جميع صلاحياته الإدارية.',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.red[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'هذا الإجراء لا يمكن التراجع عنه.',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AssyrianTheme.deepBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<UsersBloc>().add(DeleteUserEvent(currentUser.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatUserId(String userId) {
    // إذا كان المعرف طويل جداً، نعرض الأحرف الأولى والأخيرة فقط
    if (userId.length > 20) {
      return '${userId.substring(0, 8)}...${userId.substring(userId.length - 8)}';
    }
    return userId;
  }

  String _formatEmail(String email) {
    // إذا كان البريد الإلكتروني طويل جداً، نقصره
    if (email.length > 25) {
      final parts = email.split('@');
      if (parts.length == 2) {
        final username = parts[0];
        final domain = parts[1];
        if (username.length > 10) {
          return '${username.substring(0, 8)}...@$domain';
        }
      }
    }
    return email;
  }

  String _getCreatorName(String createdBy) {
    // التحقق من الـ cache أولاً
    if (_userNamesCache.containsKey(createdBy)) {
      return _userNamesCache[createdBy]!;
    }

    // البحث في قائمة المستخدمين المحملة أولاً
    final state = context.read<UsersBloc>().state;
    if (state is UsersLoaded) {
      // البحث بالمعرف أولاً
      for (final user in state.users) {
        if (user.id == createdBy && user.name != null) {
          // حفظ في الـ cache وتحديث الواجهة
          _userNamesCache[createdBy] = user.name!;
          return user.name!;
        }
      }

      // البحث بالبريد الإلكتروني
      for (final user in state.users) {
        if (user.email == createdBy && user.name != null) {
          // حفظ في الـ cache وتحديث الواجهة
          _userNamesCache[createdBy] = user.name!;
          return user.name!;
        }
      }
    }

    // إذا لم نجد المستخدم، نطلب البحث عنه بالمعرف
    _searchForUserById(createdBy);

    // إذا لم نجد المستخدم، نعرض المعرف كما هو
    return createdBy;
  }

  void _searchForUserById(String userId) {
    // تجنب البحث المتكرر عن نفس المستخدم
    if (_searchedUserIds.contains(userId)) {
      return;
    }

    _searchedUserIds.add(userId);

    // طلب البحث عن المستخدم بالمعرف من الـ bloc
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UsersBloc>().add(GetUserByIdEvent(userId));
      }
    });
  }

  String _getPermissionDisplayName(String permission) {
    const permissionNames = {
      // صلاحيات لوحة التحكم
      'dashboard_view': 'عرض لوحة التحكم',
      'role_switch': 'تبديل الأدوار',

      // صلاحيات المستخدمين
      'users_view': 'عرض المستخدمين',
      'users_create': 'إنشاء مستخدم',
      'users_edit': 'تعديل المستخدمين',
      'users_delete': 'حذف المستخدمين',
      'users_manage_status': 'إدارة حالة المستخدم',
      'users_reports_view': 'عرض تقارير المستخدمين',
      'users_logs_view': 'عرض سجل النشاطات',
      'users_settings_view': 'عرض إعدادات المستخدمين',
      'users_settings_manage': 'إدارة إعدادات المستخدمين',
      'roles_view': 'عرض الأدوار',
      'roles_create': 'إنشاء الأدوار',
      'roles_edit': 'تعديل الأدوار',
      'roles_delete': 'حذف الأدوار',
      'roles_manage': 'إدارة الأدوار',
      'permissions_view': 'عرض الصلاحيات',

      // صلاحيات العملاء
      'customers_view': 'عرض العملاء',
      'customers_create': 'إضافة عميل',
      'customers_edit': 'تعديل العملاء',
      'customers_delete': 'حذف العملاء',
      'customers_manage_status': 'إدارة حالة العميل',
      'customers_settings_view': 'عرض إعدادات العملاء',
      'customers_settings_manage': 'إدارة إعدادات العملاء',
      'customers_groups_view': 'عرض مجموعات العملاء',
      'customers_groups_create': 'إنشاء مجموعات العملاء',
      'customers_logs_view': 'عرض سجلات العملاء',
      'customers_reports_view': 'عرض تقارير العملاء',
      'customers_send_messages': 'إرسال رسائل للعملاء',

      // صلاحيات المخزون
      'inventory_view': 'عرض المخزون',
      'inventory_create': 'إضافة منتج',
      'inventory_edit': 'تعديل المنتجات',
      'inventory_delete': 'حذف المنتجات',
      'inventory_settings_view': 'عرض إعدادات المخزون',
      'inventory_settings_manage': 'إدارة إعدادات المخزون',
      'inventory_categories_view': 'عرض فئات المخزون',
      'inventory_shelves_view': 'عرض الأرفف',
      'inventory_logs_view': 'عرض سجلات المخزون',
      'inventory_tools_view': 'عرض أدوات المخزون',
      'inventory_barcode_scan': 'مسح الباركود',
      'inventory_reports_view': 'عرض تقارير المخزون',

      // صلاحيات الفواتير
      'invoices_sales_manage': 'إدارة فواتير المبيعات',
      'invoices_purchase_manage': 'إدارة فواتير المشتريات',
      'invoices_cash_manage': 'إدارة الفواتير النقدية',
      'invoices_subscription_manage': 'إدارة فواتير الاشتراكات',
      'invoices_sales_return_manage': 'إدارة فواتير مرجع البيع',
      'invoices_settings_view': 'عرض إعدادات الفواتير',
      'invoices_settings_manage': 'إدارة إعدادات الفواتير',
      'invoices_types_view': 'عرض أنواع الفواتير',
      'invoices_payments_view': 'عرض مدفوعات الفواتير',
      'invoices_logs_view': 'عرض سجلات الفواتير',
      'invoices_reports_view': 'عرض تقارير الفواتير',

      // صلاحيات الإيجارات
      'rentals_view': 'عرض الإيجارات',
      'rentals_create': 'إنشاء عقد إيجار',
      'rentals_edit': 'تعديل الإيجارات',
      'rentals_delete': 'حذف الإيجارات',
      'rentals_settings_view': 'عرض إعدادات الإيجارات',
      'rentals_settings_manage': 'إدارة إعدادات الإيجارات',
      'rentals_units_view': 'عرض الوحدات',
      'rentals_payments_view': 'عرض مدفوعات الإيجار',
      'rentals_logs_view': 'عرض سجلات الإيجارات',
      'rentals_reports_view': 'عرض تقارير الإيجارات',

      // صلاحيات المصروفات
      'expenses_view': 'عرض المصروفات',
      'expenses_create': 'إضافة مصروف',
      'expenses_edit': 'تعديل المصروفات',
      'expenses_delete': 'حذف المصروفات',
      'expenses_settings_view': 'عرض إعدادات المصروفات',
      'expenses_settings_manage': 'إدارة إعدادات المصروفات',
      'expenses_types_view': 'عرض أنواع المصروفات',
      'expenses_analysis_view': 'عرض تحليلات المصروفات',
      'expenses_reports_view': 'عرض تقارير المصروفات',

      // صلاحيات الصيانة
      'maintenance_view': 'عرض طلبات الصيانة',
      'maintenance_create': 'إنشاء طلب صيانة',
      'maintenance_edit': 'تعديل طلبات الصيانة',
      'maintenance_delete': 'حذف طلبات الصيانة',
      'maintenance_settings_view': 'عرض إعدادات الصيانة',
      'maintenance_settings_manage': 'إدارة إعدادات الصيانة',
      'maintenance_logs_view': 'عرض سجلات الصيانة',
      'maintenance_reports_view': 'عرض تقارير الصيانة',

      // صلاحيات الاشتراكات
      'subscriptions_view': 'عرض الاشتراكات',
      'subscriptions_create': 'إنشاء اشتراك',
      'subscriptions_edit': 'تعديل الاشتراكات',
      'subscriptions_delete': 'حذف الاشتراكات',
      'subscriptions_settings_view': 'عرض إعدادات الاشتراكات',
      'subscriptions_settings_manage': 'إدارة إعدادات الاشتراكات',
      'subscriptions_logs_view': 'عرض سجلات الاشتراكات',
      'subscription_types_view': 'عرض أنواع الاشتراكات',
      'subscriptions_reports_view': 'عرض تقارير الاشتراكات',

      // صلاحيات التقارير
      'reports_view': 'عرض التقارير',
      'reports_create': 'إنشاء التقارير',
      'reports_edit': 'تعديل التقارير',
      'reports_delete': 'حذف التقارير',
      'reports_export': 'تصدير التقارير',
      'reports_settings_view': 'عرض إعدادات التقارير',
      'reports_settings_manage': 'إدارة إعدادات التقارير',
      'reports_download': 'تحميل التقارير',
      'reports_share': 'مشاركة التقارير',
      'reports_print': 'طباعة التقارير',

      // صلاحيات الإعدادات
      'settings_view': 'عرض الإعدادات',
      'settings_manage': 'إدارة الإعدادات',
      'formatting_settings_view': 'عرض إعدادات التنسيق',
      'backup_settings_view': 'عرض إعدادات النسخ الاحتياطي',
    };

    return permissionNames[permission] ?? permission;
  }

  Future<void> _loadCreatorName() async {
    if (currentUser.createdBy == null || currentUser.createdBy!.isEmpty) {
      return;
    }

    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null &&
          switchedUser['id'] == currentUser.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await GetIt.instance<UsersRepository>().getUserNameById(currentUser.createdBy!);
    } on Exception catch (_) {
      createdByName = await GetIt.instance<UsersRepository>().getUserNameById(currentUser.createdBy!);
    }

    if (mounted) {
      setState(() {
        _createdByName = createdByName ?? 'غير محدد';
      });
    }
  }
}



