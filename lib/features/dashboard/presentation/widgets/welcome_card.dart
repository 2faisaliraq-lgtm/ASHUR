import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/navigation/navigation_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/services/role_request_settings_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'role_switch_dialog.dart';

class WelcomeCard extends StatefulWidget {
  const WelcomeCard({super.key});

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canSwitchRole = false;
  final ValueNotifier<bool> _roleRequestEnabledNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // تحميل مسبق للصلاحيات بشكل متزامن لتجنب الانتظار في build
    _canSwitchRole = _permissionChecker
        .getCurrentPermissionsSync()
        .contains('role_switch');
    _loadRoleRequestState();
    // تحديث الصلاحيات في الخلفية إذا تغيرت
    _loadPermissions();
  }

  /// تحميل حالة شاشة رمز الوصول
  Future<void> _loadRoleRequestState() async {
    final isEnabled = await RoleRequestSettingsService.isAccessCodeScreenEnabled();
    _roleRequestEnabledNotifier.value = isEnabled;
  }

  @override
  void dispose() {
    _roleRequestEnabledNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final canSwitchRole = await _permissionChecker.hasPermission('role_switch');

    if (mounted) {
      setState(() {
        _canSwitchRole = canSwitchRole;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        var userEmail = '';

        if (authState is AuthAuthenticated) {
          userEmail = authState.user.email;
        }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AssyrianTheme.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AssyrianTheme.assyrianShadow,
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ValueListenableBuilder لبيانات المستخدم المبدل (محمل مسبقاً في NavigationService)
              ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: NavigationService().switchedUser,
                builder: (context, switchedUserData, _) {
                  var userName = 'المدير';
                  var isSwitched = false;

                  if (switchedUserData != null) {
                    userName = switchedUserData['name'] as String? ?? 'المدير';
                    isSwitched = true;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserInfoWidget(userName, userEmail, isSwitched),
                      SizedBox(height: 16.h),
                      _buildUserRolesFromData(switchedUserData),
                    ],
                  );
                },
              ),
              SizedBox(height: 20.h),
              _buildActionButtons(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserInfoWidget(
    String userName,
    String userEmail,
    bool isSwitched,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            isSwitched ? Icons.admin_panel_settings : Icons.person_outline,
            size: 24.sp,
            color: AssyrianTheme.primaryGold,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
              if (isSwitched) ...[
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'دور مبدل',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AssyrianTheme.deepBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserRolesFromData(Map<String, dynamic>? switchedUserData) {
    final roles = (switchedUserData?['roles'] as List<dynamic>?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'الأدوار الحالية:',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
        SizedBox(height: 8.h),
        if (switchedUserData == null) ...[
          // لا يوجد مستخدم مبدل - عرض رسالة افتراضية
          _buildNoRoleChip(),
        ] else ...[
          // عرض أدوار المستخدم المبدل
          if (roles.isEmpty)
            _buildNoRoleChip()
          else
            _buildRoleChips(roles, true),
        ],
      ],
    );
  }

  Widget _buildRoleChips(List<dynamic> roles, bool isSwitched) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: roles
          .map<Widget>(
            (role) => Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AssyrianTheme.primaryGold.withValues(
                  alpha: isSwitched ? 0.2 : 0.1,
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AssyrianTheme.primaryGold.withValues(
                    alpha: isSwitched ? 0.5 : 0.3,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSwitched) ...[
                    Icon(
                      Icons.swap_horiz,
                      size: 12.sp,
                      color: AssyrianTheme.deepBlue,
                    ),
                    SizedBox(width: 4.w),
                  ],
                  Text(
                    role['displayName'] ?? role['name'] ?? role.toString(),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildNoRoleChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 14.sp, color: Colors.orange[700]),
          SizedBox(width: 4.w),
          Text(
            'لا توجد أدوار محددة',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // زر تبديل الدور
        if (_canSwitchRole)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRoleSwitchDialog(context),
              icon: Icon(Icons.swap_horiz, size: 20.sp),
              label: Text(
                'تبديل الدور',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 2,
              ),
            ),
          ),

        if (_canSwitchRole) SizedBox(height: 12.h),

        // زر تشغيل/تعطيل شاشة رمز الوصول
        _buildRoleRequestToggleButton(context),
      ],
    );
  }

  Widget _buildRoleRequestToggleButton(BuildContext context) {
    // استخدام ValueNotifier للاستماع للتغييرات
    return ValueListenableBuilder<bool>(
      valueListenable: _roleRequestEnabledNotifier,
      builder: (context, isEnabled, _) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _toggleRoleRequestScreen(context),
            icon: Icon(
              isEnabled ? Icons.visibility : Icons.visibility_off,
              size: 18.sp,
            ),
            label: Text(
              isEnabled ? 'تعطيل شاشة رمز الوصول' : 'تفعيل شاشة رمز الوصول',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnabled
                  ? AssyrianTheme.crimsonRed.withValues(alpha: 0.8)
                  : Colors.green.withValues(alpha: 0.8),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              elevation: 1,
            ),
          ),
        );
      },
    );
  }

  void _showRoleSwitchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RoleSwitchDialog(),
    );
  }

  Future<void> _toggleRoleRequestScreen(BuildContext context) async {
    try {
      final newState =
          await RoleRequestSettingsService.toggleAccessCodeScreen();

      // تحديث ValueNotifier فوراً
      _roleRequestEnabledNotifier.value = newState;

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                newState ? Icons.visibility : Icons.visibility_off,
                color: Colors.white,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  newState
                      ? 'تم تفعيل شاشة رمز الوصول'
                      : 'تم تعطيل شاشة رمز الوصول',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: newState ? Colors.green : AssyrianTheme.crimsonRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          action: SnackBarAction(
            label: 'تراجع',
            textColor: Colors.white,
            onPressed: () async {
              await RoleRequestSettingsService.toggleAccessCodeScreen();
              // تحديث الحالة بعد التراجع
              final revertedState = await RoleRequestSettingsService.isAccessCodeScreenEnabled();
              _roleRequestEnabledNotifier.value = revertedState;
              if (mounted) {
                // الحالة محدثة بالفعل عبر ValueNotifier بعد التراجع
              }
            },
          ),
        ),
      );

      if (mounted) {
      }
    } on Exception catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تغيير الإعدادات'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }
  }
}
