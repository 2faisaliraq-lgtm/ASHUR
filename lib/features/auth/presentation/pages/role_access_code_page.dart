import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/navigation/main_navigation_page.dart';
import '../../../../core/navigation/navigation_service.dart';
import '../../../../core/services/one_signal_notification_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../features/users/domain/entities/role_entity.dart';
import '../../../../features/users/domain/entities/user_management_entity.dart';

/// شاشة إدخال رمز الوصول
class RoleAccessCodePage extends StatefulWidget {
  const RoleAccessCodePage({
    required this.userEmail,
    required this.userName,
    super.key,
  });
  final String userEmail;
  final String userName;

  @override
  State<RoleAccessCodePage> createState() => _RoleAccessCodePageState();
}

class _RoleAccessCodePageState extends State<RoleAccessCodePage>
    with AutomaticKeepAliveClientMixin {
  final _roleCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isVerifying = false;
  bool _obscureText = true;
  String? _errorMessage;
  final _emailService = EmailNormalizationService();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _roleCodeController.dispose();
    super.dispose();
  }

  /// التحقق من رمز الوصول وتبديل المستخدم
  Future<void> _verifyRoleCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final roleCode = _roleCodeController.text.trim();
      // تطبيع البريد الإلكتروني
      final organizationId = _emailService.normalize(widget.userEmail);

      // البحث عن المستخدم الذي يملك هذا رمز الوصول
      var usersQuery = await FirebaseFirestore.instance
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .where('accessCode', isEqualTo: roleCode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      // إذا لم نجد بـ accessCode، جرب البحث بـ roleCode (للتوافق مع البيانات القديمة)
      if (usersQuery.docs.isEmpty) {
        usersQuery = await FirebaseFirestore.instance
            .collection(organizationId)
            .doc('users')
            .collection('users')
            .where('roleCode', isEqualTo: roleCode)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));
      }

      if (usersQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'رمز الوصول غير صحيح أو غير مسجل لأي مستخدم نشط';
          _isVerifying = false;
        });
        return;
      }

      final targetUserDoc = usersQuery.docs.first;
      final targetUserData = targetUserDoc.data();
      final targetRoleIds = List<String>.from(targetUserData['roleIds'] ?? []);

      if (targetRoleIds.isEmpty) {
        setState(() {
          _errorMessage = 'المستخدم المرتبط برمز الوصول ليس له أدوار صالحة';
          _isVerifying = false;
        });
        return;
      }

      // الحصول على بيانات الأدوار
      final rolesQuery = await FirebaseFirestore.instance
          .collection(organizationId)
          .doc('users')
          .collection('roles')
          .where(FieldPath.documentId, whereIn: targetRoleIds)
          .where('isActive', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 10));

      if (rolesQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'الأدوار المرتبطة برمز الوصول غير صالحة';
          _isVerifying = false;
        });
        return;
      }

      // إنشاء قائمة الأدوار
      final roles = rolesQuery.docs.map((doc) {
        final data = doc.data();
        return RoleEntity(
          id: doc.id,
          name: data['name'] ?? '',
          displayName: data['displayName'] ?? '',
          permissions: List<String>.from(data['permissions'] ?? []),
          createdAt: DateTime.now(),
        );
      }).toList();

      // ✅ الحصول على الصلاحيات المخصصة من المستخدم (مثل RoleSwitchDialog)
      final customPermissions = List<String>.from(
        targetUserData['customPermissions'] ??
            targetUserData['additionalPermissions'] ??
            [],
      );

      // إنشاء كيان المستخدم المرجعي للتبديل
      final targetUserEntity = UserManagementEntity(
        id: targetUserDoc.id,
        email: targetUserData['email'] ?? '',
        name: targetUserData['name'] ?? 'مستخدم غير معروف',
        roleCode: roleCode,
        customPermissions: customPermissions, // ✅ الصلاحيات المخصصة
        roles: roles,
        createdAt: targetUserData['createdAt']?.toDate() ?? DateTime.now(),
      );

      // تبديل المستخدم
      if (mounted) {
        await SessionService.setSwitchedUser(targetUserEntity);

        // تحديث NavigationService.switchedUser.value لنافذة الترحيب والداشبورد
        NavigationService().switchedUser.value = {
          'id': targetUserDoc.id,
          'email': targetUserData['email'] ?? '',
          'name': targetUserData['name'] ?? '',
          'roles': roles.map((r) => {
            'id': r.id,
            'name': r.name,
            'displayName': r.displayName,
            'permissions': r.permissions,
          }).toList(),
          'switchedAt': DateTime.now().toIso8601String(),
        };

        final organizationEmail = FirebaseAuth.instance.currentUser?.email;
        if (organizationEmail != null && organizationEmail.isNotEmpty) {
          await OneSignalNotificationService.registerPlayerIdForUser(
            uid: targetUserDoc.id,
            organizationEmail: organizationEmail,
          );
        }

        // انتظار للتأكد من حفظ البيانات
        await Future.delayed(const Duration(milliseconds: 300));

        // عرض رسالة النجاح
        _showSuccessSnackBar(targetUserEntity);

        // الانتقال المباشر للداشبورد
        if (mounted) {
          await Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainNavigationPage()),
            (route) => false, // إزالة جميع الصفحات السابقة
          );
        }
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'حدث خطأ أثناء تبديل المستخدم. يرجى المحاولة مرة أخرى.';
          _isVerifying = false;
        });
      }
    }
  }

  /// عرض رسالة النجاح مع تفاصيل المستخدم
  void _showSuccessSnackBar(UserManagementEntity targetUser) {
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
                fontFamily: 'Cairo',
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'الاسم: ${targetUser.name}',
              style: const TextStyle(
                color: AssyrianTheme.deepBlue,
                fontFamily: 'Cairo',
              ),
            ),
            Text(
              'البريد: ${targetUser.email}',
              style: const TextStyle(
                color: AssyrianTheme.deepBlue,
                fontFamily: 'Cairo',
              ),
            ),
            Text(
              'رمز الوصول: ${targetUser.roleCode}',
              style: const TextStyle(
                color: AssyrianTheme.deepBlue,
                fontFamily: 'Cairo',
              ),
            ),
            if (targetUser.roles.isNotEmpty)
              Text(
                'الأدوار: ${targetUser.roles.map((r) => r.displayName).join(', ')}',
                style: const TextStyle(
                  color: AssyrianTheme.deepBlue,
                  fontFamily: 'Cairo',
                ),
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // مطلوب لـ AutomaticKeepAliveClientMixin

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AssyrianTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(12.w), // تقليل من 20 إلى 12
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    MediaQuery.of(context).orientation == Orientation.landscape;

                if (isLandscape) {
                  // تخطيط أفقي للشاشة الأفقية
                  return Row(
                    children: [
                      // الشعار الآشوري - نصف الشاشة
                      Expanded(
                        child: Center(
                          child: AssyrianTheme.getSimpleLamassuForAuth(
                            isDarkBackground: true,
                            isLandscape: true, // الشعار الكبير للأفقية
                          ),
                        ),
                      ),

                      SizedBox(width: 4.w),

                      // نموذج رمز الوصول - نصف الشاشة
                      Expanded(
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: Center(
                            child: SingleChildScrollView(
                              child:
                                  _buildRoleCodeFormLandscape(), // استخدام نسخة مخصصة للأفقية
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // تخطيط عمودي للشاشة العمودية
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // الشعار الآشوري - حجم محدود مع رفع للأعلى
                        Transform.translate(
                          offset: Offset(0, -80.h),
                          child: SizedBox(
                            width: double.infinity,
                            height:
                                constraints.maxHeight *
                                0.7, // زيادة من 60% إلى 70%
                            child: Center(
                              child: AssyrianTheme.getSimpleLamassuForAuth(
                                isDarkBackground: true,
                              ),
                            ),
                          ),
                        ),

                        // نموذج رمز الوصول مع هامش سلبي
                        Transform.translate(
                          offset: Offset(0, -200.h),
                          child: _buildRoleCodeForm(),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  /// بناء نموذج رمز الوصول للشاشة الأفقية (أحجام أصغر)
  Widget _buildRoleCodeFormLandscape() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12.w, // تقليل من 16
        vertical: 0.5.w, // تقليل من 1
      ),
      decoration: AssyrianTheme.assyrianBorder,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حقل رمز الوصول
            Text(
              'رمز الوصول *',
              style: AssyrianTheme.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 8.sp, // تقليل من 10
              ),
            ),

            SizedBox(height: 0.1.h), // تقليل من 0.2

            TextFormField(
              controller: _roleCodeController,
              obscureText: _obscureText,
              enabled: !_isVerifying,
              textAlign: TextAlign.center,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال رمز الوصول';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'أدخل رمز الوصول',
                prefixIcon: Container(
                  margin: EdgeInsets.all(1.w), // تقليل من 2
                  decoration: BoxDecoration(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3.r), // تقليل من 4
                  ),
                  child: Icon(
                    Icons.key_rounded,
                    size: 12.sp, // تقليل من 16
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
                suffixIcon: Container(
                  margin: EdgeInsets.all(1.w), // تقليل من 2
                  decoration: BoxDecoration(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3.r), // تقليل من 4
                  ),
                  child: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 12.sp, // تقليل من 16
                      color: AssyrianTheme.primaryGold,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r), // تقليل من 16
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                    width: 1.5, // تقليل من 2
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: AssyrianTheme.primaryGold,
                    width: 2, // تقليل من 2.5
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: Colors.red.withValues(alpha: 0.7),
                    width: 1.5, // تقليل من 2
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: Colors.red,
                    width: 2, // تقليل من 2.5
                  ),
                ),
                filled: true,
                fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 30.w, // تقليل من 40
                  vertical: 0.5.h, // تقليل من 1
                ),
                hintStyle: TextStyle(
                  color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                  fontFamily: 'Cairo',
                  fontSize: 12.sp, // تقليل من 16
                ),
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.sp, // تقليل من 16
                fontWeight: FontWeight.w600,
                color: AssyrianTheme.deepBlue,
                letterSpacing: 1.5, // تقليل من 2.0
              ),
            ),

            // رسالة الخطأ
            if (_errorMessage != null) ...[
              SizedBox(height: 6.h), // تقليل من 12
              Container(
                padding: EdgeInsets.all(6.w), // تقليل من 8
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r), // تقليل من 12
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(1.w), // تقليل من 2
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r), // تقليل من 6
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red.shade700,
                        size: 16.sp, // تقليل من 20
                      ),
                    ),
                    SizedBox(width: 6.w), // تقليل من 8
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 10.sp, // تقليل من 14
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 4.h), // تقليل من 8
            // زر التبديل
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyRoleCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AssyrianTheme.primaryGold,
                  foregroundColor: AssyrianTheme.deepBlue,
                  disabledBackgroundColor: AssyrianTheme.primaryGold.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r), // تقليل من 16
                  ),
                  padding: EdgeInsets.symmetric(vertical: 6.h), // تقليل من 8
                  elevation: 3, // تقليل من 4
                  shadowColor: AssyrianTheme.primaryGold.withValues(alpha: 0.4),
                ),
                child: _isVerifying
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16.w, // تقليل من 20
                            height: 16.h, // تقليل من 20
                            child: LoadingWidget(),
                          ),
                          SizedBox(width: 6.w), // تقليل من 8
                          Text(
                            'جاري التحقق...',
                            style: TextStyle(
                              fontSize: 10.sp, // تقليل من 14
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 16.sp, // تقليل من 20
                          ),
                          SizedBox(width: 6.w), // تقليل من 8
                          Text(
                            'دخول',
                            style: TextStyle(
                              fontSize: 12.sp, // تقليل من 16
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء نموذج رمز الوصول
  Widget _buildRoleCodeForm() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 1.w, // تقليل من 2 إلى 1
      ),
      decoration: AssyrianTheme.assyrianBorder,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حقل رمز الوصول
            Text(
              'رمز الوصول *',
              style: AssyrianTheme.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 10.sp, // تقليل من 12 إلى 10
              ),
            ),

            SizedBox(height: 0.2.h), // تقليل من 0.5 إلى 0.2

            TextFormField(
              controller: _roleCodeController,
              obscureText: _obscureText,
              enabled: !_isVerifying,
              textAlign: TextAlign.center, // توسيط النص
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال رمز الوصول';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'أدخل رمز الوصول',
                prefixIcon: Container(
                  margin: EdgeInsets.all(2.w), // تقليل من 4 إلى 2
                  decoration: BoxDecoration(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Icon(
                    Icons.key_rounded,
                    size: 16.sp,
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
                suffixIcon: Container(
                  margin: EdgeInsets.all(2.w), // تقليل من 4 إلى 2
                  decoration: BoxDecoration(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 16.sp,
                      color: AssyrianTheme.primaryGold,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r), // زيادة الانحناء
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(
                    color: AssyrianTheme.primaryGold,
                    width: 2.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide(
                    color: Colors.red.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(color: Colors.red, width: 2.5),
                ),
                filled: true,
                fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 40.w,
                  vertical: 1.h, // تقليل من 2 إلى 1
                ),
                hintStyle: TextStyle(
                  color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                  fontFamily: 'Cairo',
                  fontSize: 16.sp,
                ),
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16.sp, // تقليل من 18 إلى 16
                fontWeight: FontWeight.w600,
                color: AssyrianTheme.deepBlue,
                letterSpacing: 2, // مسافة بين الأحرف لرموز الوصول
              ),
            ),

            // رسالة الخطأ
            if (_errorMessage != null) ...[
              SizedBox(height: 12.h), // تقليل من 16 إلى 12
              Container(
                padding: EdgeInsets.all(8.w), // تقليل من 12 إلى 8
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(2.w), // تقليل من 4 إلى 2
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red.shade700,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 8.w), // تقليل من 16 إلى 8
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14.sp,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 8.h), // تقليل من 12 إلى 8
            // زر التبديل

            // زر التبديل
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyRoleCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AssyrianTheme.primaryGold,
                  foregroundColor: AssyrianTheme.deepBlue,
                  disabledBackgroundColor: AssyrianTheme.primaryGold.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      16.r,
                    ), // نفس انحناء مربع الإدخال
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: 8.h,
                  ), // تقليل من 10 إلى 8
                  elevation: 4,
                  shadowColor: AssyrianTheme.primaryGold.withValues(alpha: 0.4),
                ),
                child: _isVerifying
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: LoadingWidget(),
                          ),
                          SizedBox(width: 8.w), // تقليل من 16 إلى 8
                          Text(
                            'جاري التحقق...',
                            style: TextStyle(
                              fontSize: 14.sp, // تقليل من 16 إلى 14
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 20.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'دخول',
                            style: TextStyle(
                              fontSize: 16.sp, // تقليل من 18 إلى 16
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




