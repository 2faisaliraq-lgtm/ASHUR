import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/navigation/main_navigation_page.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/services/one_signal_notification_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../users/domain/entities/role_entity.dart';
import '../../../users/domain/entities/user_management_entity.dart';

class RoleSwitchDialog extends StatefulWidget {
  const RoleSwitchDialog({super.key});

  @override
  State<RoleSwitchDialog> createState() => _RoleSwitchDialogState();
}

class _RoleSwitchDialogState extends State<RoleSwitchDialog> {
  final TextEditingController roleCodeController = TextEditingController();
  final _emailService = EmailNormalizationService();
  bool isLoading = false;
  bool obscureText = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    roleCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Row(
        children: [
          Icon(Icons.swap_horiz, color: AssyrianTheme.primaryGold, size: 24.sp),
          SizedBox(width: 8.w),
          Text(
            'تبديل الدور',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل رمز الوصول للتبديل إليه:',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 16.h),
            _buildRoleCodeField(),
            SizedBox(height: 16.h),
            _buildInfoContainer(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'إلغاء',
            style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
          ),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _handleRoleSwitch,
          style: ElevatedButton.styleFrom(
            backgroundColor: AssyrianTheme.primaryGold,
            foregroundColor: AssyrianTheme.deepBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: LoadingWidget(),
                )
              : Text(
                  'تبديل',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRoleCodeField() {
    return TextFormField(
      controller: roleCodeController,
      obscureText: obscureText,
      enabled: !isLoading,
      decoration: InputDecoration(
        labelText: 'رمز الوصول',
        hintText: 'أدخل رمز الوصول الخاص بالمستخدم',
        prefixIcon: Icon(
          Icons.key,
          size: 20.sp,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            size: 20.sp,
            color: AssyrianTheme.primaryGold,
          ),
          onPressed: () {
            setState(() {
              obscureText = !obscureText;
            });
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
        ),
        labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
      ),
    );
  }

  Widget _buildInfoContainer() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AssyrianTheme.primaryGold,
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'سيتم البحث عن المستخدم المطابق للرمز وتبديل الدور إليه',
              style: TextStyle(fontSize: 12.sp, color: AssyrianTheme.deepBlue),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRoleSwitch() async {
    final roleCode = roleCodeController.text.trim();

    if (roleCode.isEmpty) {
      _showErrorSnackBar('يرجى إدخال رمز الوصول');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await _switchToUserByCodeDirect(roleCode);
    } on Exception catch (_) {
      if (mounted) {
        _showErrorSnackBar('حدث خطأ أثناء التبديل');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// التبديل المباشر بدون استخدام UsersBloc
  Future<void> _switchToUserByCodeDirect(String roleCode) async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        if (mounted) {
          _showErrorSnackBar('المستخدم غير مسجل دخول');
          setState(() => isLoading = false);
        }
        return;
      }

      // تطبيع البريد الإلكتروني
      final organizationId = _emailService.normalize(authState.user.email);

      // البحث عن المستخدم في قاعدة البيانات
      final firestore = FirebaseFirestore.instance;

      var usersQuery = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .where('accessCode', isEqualTo: roleCode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      // إذا لم نجد بـ accessCode، جرب البحث بـ roleCode
      if (usersQuery.docs.isEmpty) {
        usersQuery = await firestore
            .collection(organizationId)
            .doc('users')
            .collection('users')
            .where('roleCode', isEqualTo: roleCode)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();
      }

      if (usersQuery.docs.isEmpty) {
        if (mounted) {
          _showErrorSnackBar('لم يتم العثور على مستخدم برمز الوصول: ****');
          setState(() => isLoading = false);
        }
        return;
      }

      final targetUserDoc = usersQuery.docs.first;
      final targetUserData = targetUserDoc.data();
      final targetRoleIds = List<String>.from(targetUserData['roleIds'] ?? []);

      if (targetRoleIds.isEmpty) {
        if (mounted) {
          _showErrorSnackBar('المستخدم المرتبط برمز الوصول ليس له أدوار صالحة');
          setState(() => isLoading = false);
        }
        return;
      }

      // الحصول على بيانات الأدوار (تقسيم إلى دفعات من 10 لأن Firestore يحد whereIn بـ 10 عناصر)
      final List<QueryDocumentSnapshot> allRoleDocs = [];
      for (int i = 0; i < targetRoleIds.length; i += 10) {
        final batch = targetRoleIds.sublist(i, min(i + 10, targetRoleIds.length));
        final batchQuery = await FirebaseFirestore.instance
            .collection(organizationId)
            .doc('users')
            .collection('roles')
            .where(FieldPath.documentId, whereIn: batch)
            .where('isActive', isEqualTo: true)
            .get();
        allRoleDocs.addAll(batchQuery.docs);
      }

      if (allRoleDocs.isEmpty) {
        if (mounted) {
          _showErrorSnackBar('الأدوار المرتبطة برمز الوصول غير صالحة');
          setState(() => isLoading = false);
        }
        return;
      }

      // إنشاء قائمة الأدوار
      final roles = allRoleDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'id': doc.id,
          'name': data?['name'] ?? '',
          'displayName': data?['displayName'] ?? '',
          'permissions': List<String>.from(data?['permissions'] ?? []),
        };
      }).toList();

      // ✅ الحصول على الصلاحيات المخصصة
      final customPermissions = List<String>.from(
        targetUserData['customPermissions'] ??
            targetUserData['additionalPermissions'] ??
            [],
      );

      // حفظ بيانات المستخدم المبدل
      final userData = {
        'id': targetUserDoc.id,
        'email': targetUserData['email'] ?? '',
        'name': targetUserData['name'] ?? 'مستخدم غير معروف',
        'accessCode': roleCode,
        'roles': roles,
        'customPermissions': customPermissions, // ✅ الصلاحيات المخصصة
        'switchedAt': DateTime.now().toUtc().toIso8601String(),
      };

      // إنشاء UserManagementEntity لاستخدام SessionService.setSwitchedUser
      final tempUser = UserManagementEntity(
        id: targetUserDoc.id,
        email: targetUserData['email'] ?? '',
        name: targetUserData['name'] ?? 'مستخدم غير معروف',
        roleCode: roleCode,
        customPermissions: customPermissions, // ✅ الصلاحيات المخصصة
        roles: roles
            .map(
              (r) => RoleEntity(
                id: r['id'] as String,
                name: r['name'] as String,
                displayName: r['displayName'] as String,
                permissions: List<String>.from(r['permissions'] as List),
                createdAt: DateTime.now(),
              ),
            )
            .toList(),
        createdAt: targetUserData['createdAt']?.toDate() ?? DateTime.now(),
      );

      // استخدام SessionService.setSwitchedUser لضمان تحديث الذاكرة
      // ✅ مسح الجلسة القديمة أولاً
      await SessionService.clearRolePermanently();

      await SessionService.setSwitchedUser(tempUser);

      final organizationEmail = FirebaseAuth.instance.currentUser?.email;

      if (organizationEmail != null && organizationEmail.isNotEmpty) {
        await OneSignalNotificationService.registerPlayerIdForUser(
          uid: targetUserDoc.id,
          organizationEmail: organizationEmail,
        );
      }

      // مسح ذاكرة الصلاحيات المؤقتة
      final permissionChecker = PermissionChecker();
      permissionChecker.clearCache();

      if (!mounted) return;

      // إغلاق الحوار أولاً
      Navigator.of(context).pop();

      // عرض رسالة النجاح
      _showSuccessSnackBar(userData);

      // الانتقال فوراً بدون انتظار
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainNavigationPage(
            key: ValueKey('switched_${DateTime.now().millisecondsSinceEpoch}'),
          ),
        ),
        (route) => false,
      );
    } on Exception catch (_) {
      if (mounted) {
        _showErrorSnackBar('حدث خطأ أثناء التبديل');
        setState(() => isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  void _showSuccessSnackBar(dynamic targetUser) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تم التبديل بنجاح إلى:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
                color: AssyrianTheme.deepBlue,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'الاسم: ${targetUser is Map ? targetUser['name'] : targetUser.name ?? 'غير محدد'}',
              style: const TextStyle(color: AssyrianTheme.deepBlue),
            ),
            if ((targetUser is Map ? targetUser['email'] : targetUser.email) !=
                null)
              Text(
                'البريد: ${targetUser is Map ? targetUser['email'] : targetUser.email}',
                style: const TextStyle(color: AssyrianTheme.deepBlue),
              ),
            if ((targetUser is Map ? targetUser['roles'] : targetUser.roles) !=
                    null &&
                (targetUser is Map
                    ? (targetUser['roles'] as List).isNotEmpty
                    : targetUser.roles.isNotEmpty))
              Text(
                'الأدوار: ${targetUser is Map ? (targetUser['roles'] as List).map((r) => r['displayName']).join(', ') : targetUser.roles.map((r) => r.displayName).join(', ')}',
                style: const TextStyle(color: AssyrianTheme.deepBlue),
              ),
          ],
        ),
        backgroundColor: AssyrianTheme.primaryGold,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }
}

