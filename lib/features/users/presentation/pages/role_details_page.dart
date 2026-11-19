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
import '../../domain/entities/role_entity.dart';
import '../../domain/repositories/users_repository.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/users_drawer.dart';

/// صفحة تفاصيل الدور
class RoleDetailsPage extends StatefulWidget {
  const RoleDetailsPage({required this.role, super.key});
  final RoleEntity role;

  @override
  State<RoleDetailsPage> createState() => _RoleDetailsPageState();
}

class _RoleDetailsPageState extends State<RoleDetailsPage>
    with SaveOperationMixin<RoleDetailsPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  bool _canDelete = false;
  late RoleEntity currentRole;
  String? _createdByName; // اسم منشئ الدور

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  final Set<String> _searchedUserIds =
      {}; // cache للمستخدمين الذين تم البحث عنهم
  final Map<String, String> _userNamesCache = {}; // cache لأسماء المستخدمين

  @override
  void initState() {
    super.initState();
    currentRole = widget.role;
    _loadPermissions();
    _loadCreatorName(); // تحميل اسم المنشئ

    // تحديث بيانات الدور وتحميل جميع المستخدمين
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersBloc>().add(const LoadRolesEvent());
      context.read<UsersBloc>().add(const StartUsersStreamEvent());
    });
  }

  Future<void> _loadPermissions() async {
    final canEdit = await _permissionChecker.hasPermission('roles_edit');
    final canDelete = await _permissionChecker.hasPermission('roles_delete');

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
        _canDelete = canDelete;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: const UsersDrawer(currentRoute: AppRoutes.rolesManagement),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canEdit
          ? FloatingActionButton(
              heroTag: 'roles_edit_fab',
              onPressed: () async {
                final usersBloc = context.read<UsersBloc>();
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.editRole, arguments: currentRole);
                if (!mounted) return;
                if (result == true) {
                  usersBloc.add(const LoadRolesEvent());
                }
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.edit, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocListener<UsersBloc, UsersState>(
        listenWhen: (previous, current) {
          return current is UsersError ||
              current is RoleUpdated ||
              current is RoleDeleted ||
              current is UsersLoaded;
        },
        listener: (context, state) {
          // ✅ هذه شاشة تفاصيل: عملياتها (الحذف/التحديث) تُنفَّذ
          // عبر أحداث BLoC مباشرة دون نافذة تحميل من الصفحة،
          // لذلك لا نستدعي failSaveOperation/completeSaveOperation
          // (كلتاهما تُغلق نافذة تحميل غير موجودة فتُغلقان شاشة
          // التفاصيل نفسها). القاعدة: حدّث بيانات الشاشة وابقَ
          // فيها؛ والحذف = اعرض رسالة ثم ارجع للشاشة السابقة.
          if (state is UsersError && !_operationCompleted) {
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
          } else if (state is RoleUpdated && !_operationCompleted) {
            _operationCompleted = true;
            setState(() {
              currentRole = state.role;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم تحديث الدور بنجاح'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          } else if (state is RoleDeleted && !_operationCompleted) {
            _operationCompleted = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم حذف الدور بنجاح'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
            // تم حذف الدور — العودة للشاشة السابقة
            Navigator.of(context).pop();
          } else if (state is UsersLoaded) {
            // إعادة بناء الواجهة عند تحميل المستخدمين الجدد وتحديث الـ cache
            for (final user in state.users) {
              if (user.name != null) {
                _userNamesCache[user.id] = user.name!;
                if (user.email != null) {
                  _userNamesCache[user.email!] = user.name!;
                }
              }
            }
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
                  _buildRoleHeader(),
                  const SizedBox(height: 6),
                  _buildRoleInfoCard(),
                  const SizedBox(height: 6),
                  _buildPermissionsCard(),
                  const SizedBox(height: 6),
                  _buildUsersWithRoleCard(state),
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تفاصيل الدور',
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
                  currentRole.displayName,
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
              ).pushNamed(AppRoutes.editRole, arguments: currentRole);
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل الدور',
          ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'toggle':
                _toggleRoleStatus();
                break;
              case 'delete':
                _showDeleteDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    currentRole.isActive ? Icons.block : Icons.check_circle,
                    size: 16.sp,
                    color: currentRole.isActive ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(currentRole.isActive ? 'إلغاء التفعيل' : 'تفعيل'),
                ],
              ),
            ),
            if (_canDelete)
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16.sp, color: Colors.red),
                    const SizedBox(width: 8),
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

  Widget _buildRoleHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AssyrianTheme.primaryGold.withValues(alpha: 0.1),
            AssyrianTheme.deepBlue.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: AssyrianTheme.primaryGold,
            radius: 30,
            child: Icon(
              Icons.admin_panel_settings,
              size: 32.sp,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            currentRole.displayName,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            currentRole.name,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: currentRole.isActive
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: currentRole.isActive
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  currentRole.isActive ? Icons.check_circle : Icons.block,
                  size: 14.sp,
                  color: currentRole.isActive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  currentRole.isActive ? 'نشط' : 'غير نشط',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: currentRole.isActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleInfoCard() {
    return _buildInfoCard(
      title: 'معلومات الدور',
      icon: Icons.info,
      children: [
        _buildInfoRow('اسم الدور', currentRole.displayName),
        _buildInfoRow('الرمز', currentRole.name),
        if (currentRole.description?.isNotEmpty ?? false)
          _buildInfoRow('الوصف', currentRole.description!),
        _buildInfoRow('عدد الصلاحيات', '${currentRole.permissions.length}'),
      ],
    );
  }

  Widget _buildPermissionsCard() {
    return _buildInfoCard(
      title: 'الصلاحيات',
      icon: Icons.security,
      children: [
        if (currentRole.permissions.isEmpty)
          Text(
            'لا توجد صلاحيات مخصصة',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currentRole.permissions
                .map(_buildPermissionChip)
                .toList(),
          ),
      ],
    );
  }

  Widget _buildUsersWithRoleCard(UsersState state) {
    final usersWithRole = <String>[];

    if (state is UsersLoaded) {
      for (final user in state.users) {
        if (user.roles.any((role) => role.id == currentRole.id)) {
          usersWithRole.add(user.name ?? user.email ?? 'مستخدم غير معروف');
        }
      }
    }

    return _buildInfoCard(
      title: 'المستخدمون الذين لديهم هذا الدور',
      icon: Icons.people,
      children: [
        if (usersWithRole.isEmpty)
          Text(
            'لا يوجد مستخدمون لديهم هذا الدور',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: usersWithRole
                .map(
                  (userName) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16.sp,
                          color: AssyrianTheme.primaryGold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AssyrianTheme.deepBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildSystemInfoCard() {
    return _buildInfoCard(
      title: 'معلومات النظام',
      icon: Icons.info,
      children: [
        _buildInfoRow('معرف الدور', _formatRoleId(currentRole.id)),
        _buildInfoRow('تاريخ الإنشاء', _formatDate(currentRole.createdAt)),
        if (currentRole.createdBy?.isNotEmpty ?? false)
          _buildInfoRow(
            'أنشئ بواسطة',
            _createdByName ?? _getCreatorName(currentRole.createdBy!),
          ),
        if (currentRole.updatedAt != null)
          _buildInfoRow('آخر تحديث', _formatDate(currentRole.updatedAt!)),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18.sp,
                  color: AssyrianTheme.primaryGold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AssyrianTheme.deepBlue,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleRoleStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: currentRole.isActive
                      ? Colors.red
                      : Colors.green,
                  side: BorderSide(
                    color: currentRole.isActive ? Colors.red : Colors.green,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  currentRole.isActive ? Icons.block : Icons.check_circle,
                  size: 16.sp,
                ),
                label: Text(
                  currentRole.isActive ? 'إلغاء التفعيل' : 'تفعيل',
                  style: TextStyle(fontSize: 12.sp),
                ),
              ),
            ),
            const SizedBox(width: 8),
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

  void _toggleRoleStatus() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          currentRole.isActive ? 'تم إلغاء تفعيل الدور' : 'تم تفعيل الدور',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showDeleteDialog() {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

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
    if (currentRole.name == 'admin') {
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
              Icon(Icons.block, color: Colors.red, size: 20.sp),
              const SizedBox(width: 6),
              Text(
                'لا يمكن الحذف',
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
                      size: 16.sp,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'لا يمكن حذف دور المدير الرئيسي لأنه ضروري لعمل النظام.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.red[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'دور المدير الرئيسي محمي من الحذف للحفاظ على أمان النظام.',
                style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
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
        if (user.roles.any((userRole) => userRole.id == currentRole.id)) {
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
            Icon(Icons.warning, color: Colors.red, size: 20.sp),
            const SizedBox(width: 6),
            Text(
              'تأكيد حذف الدور',
              style: TextStyle(
                fontSize: 16.sp,
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
                'هل أنت متأكد من حذف الدور "${currentRole.displayName}"؟',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AssyrianTheme.deepBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // عرض المستخدمين المتأثرين
              if (usersWithRole.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8),
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
                            size: 14.sp,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'المستخدمون المتأثرون (${usersWithRole.length}):',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...usersWithRole
                          .take(3)
                          .map(
                            (userName) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 12.sp,
                                    color: Colors.orange[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      userName,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (usersWithRole.length > 3)
                        Text(
                          'و ${usersWithRole.length - 3} مستخدمين آخرين...',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.orange[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(8),
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
                        size: 14.sp,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'تحذير: سيتم حذف جميع المستخدمين الذين لديهم هذا الدور فقط!',
                          style: TextStyle(
                            fontSize: 11.sp,
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
                  padding: const EdgeInsets.all(8),
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
                        size: 14.sp,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'لا يوجد مستخدمون لديهم هذا الدور.',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.green[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
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
              // استخدام context الأصلي بدلاً من dialogContext
              context.read<UsersBloc>().add(DeleteRoleEvent(currentRole.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              usersWithRole.isNotEmpty ? 'حذف الدور والمستخدمين' : 'حذف الدور',
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatRoleId(String roleId) {
    // إذا كان المعرف طويل جداً، نعرض الأحرف الأولى والأخيرة فقط
    if (roleId.length > 20) {
      return '${roleId.substring(0, 8)}...${roleId.substring(roleId.length - 8)}';
    }
    return roleId;
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
    if (currentRole.createdBy == null || currentRole.createdBy!.isEmpty) {
      return;
    }

    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] == currentRole.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await GetIt.instance<UsersRepository>().getUserNameById(
        currentRole.createdBy!,
      );
    } on Exception catch (_) {
      createdByName = await GetIt.instance<UsersRepository>().getUserNameById(
        currentRole.createdBy!,
      );
    }

    if (mounted) {
      setState(() {
        _createdByName = createdByName ?? 'غير محدد';
      });
    }
  }
}
