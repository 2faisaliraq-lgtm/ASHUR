import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/middleware/admin_check_middleware.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/permissions/permissions_manager.dart';
import '../../../../core/services/enabled_modules_service.dart';
import '../../../../core/services/one_signal_notification_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../users/domain/entities/role_entity.dart';
import '../../../users/domain/entities/user_management_entity.dart';
import '../../../users/presentation/bloc/users_bloc.dart';
import '../../../users/presentation/bloc/users_event.dart';
import '../../../users/presentation/bloc/users_state.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';

class CreateAdminPage extends StatefulWidget {
  const CreateAdminPage({super.key});

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage>
    with SaveOperationMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleCodeController = TextEditingController();
  final _accountPasswordController =
      TextEditingController(); // كلمة مرور الحساب
  final _emailService = EmailNormalizationService();

  bool _isLoading = false;
  bool _hasNavigated = false;
  bool _isUsingCurrentUser = false;
  bool _isGoogleUser = false; // لتتبع ما إذا كان المستخدم سجل دخوله عبر Google
  bool _showAccountPassword = true; // إظهار حقل كلمة مرور الحساب للجميع
  bool _obscureAccountPassword = true; // إخفاء كلمة مرور الحساب
  late UsersBloc _usersBloc;

  // حالة الأقسام المفعلة
  Map<String, bool> _enabledModules = {};

  @override
  void initState() {
    super.initState();
    // إنشاء UsersBloc محلي
    _usersBloc = GetIt.instance<UsersBloc>();

    // تهيئة الأقسام المفعلة (افتراضياً جميع الأقسام مفعلة)
    final service = EnabledModulesService();
    _enabledModules = service.getDefaultModules();

    // تعيين قيم افتراضية مناسبة لإنشاء المدير الأول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setDefaultAdminInfo();
    });

    // الاستماع لحالة UsersBloc - تحسين لتجنب setState المتكرر
    _usersBloc.stream.listen((state) {
      if (!mounted || _hasNavigated) return;

      if (state is UsersLoading) {
        setState(() {
          _isLoading = true;
        });
      } else if (state is RoleCreated ||
          state is UserCreated ||
          state is UserUpdated ||
          state is UserDeleted ||
          state is UsersError) {
        setState(() {
          _isLoading = false;
        });
        _handleUsersState(state);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // محاولة إضافية لتحميل المعلومات
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      _setDefaultAdminInfo();
    }
  }

  /// تعيين معلومات افتراضية مناسبة لإنشاء المدير الأول
  Future<void> _setDefaultAdminInfo() async {
    if (mounted) {
      try {
        String? userName;
        String? userEmail;
        String? userProvider;

        // أولاً: محاولة الحصول على معلومات من AuthBloc
        try {
          final authBloc = context.read<AuthBloc>();
          final authState = authBloc.state;

          if (authState is AuthAuthenticated) {
            userName = authState.user.name;
            userEmail = authState.user.email;
            userProvider = authState.user.provider;
          }
        } on Exception catch (_) {
          // تجاهل الخطأ والمتابعة للطريقة التالية
        }

        if ((userName?.isEmpty ?? true) || (userEmail?.isEmpty ?? true)) {
          final currentUser = FirebaseAuth.instance.currentUser;

          if (currentUser != null) {
            userName ??= currentUser.displayName;
            userEmail ??= currentUser.email;

            // التحقق من provider
            final providerData = currentUser.providerData;
            for (final provider in providerData) {
              if (provider.providerId == 'google.com') {
                userProvider = 'google';
                break;
              }
            }
          }
        }

        // تحديد إذا كان مستخدم Google
        _isGoogleUser = (userProvider == 'google');

        // إظهار حقل كلمة مرور الحساب للجميع
        _showAccountPassword = true;

        // ثالثاً: استخدام القيم الافتراضية إذا لم توجد معلومات
        // تطبيق المعلومات المحصلة أو القيم الافتراضية
        if (_nameController.text.isEmpty) {
          if (userName?.isNotEmpty ?? false) {
            _nameController.text = userName!;
          } else if (userEmail?.isNotEmpty ?? false) {
            // استخدام جزء من البريد كاسم
            final emailName = userEmail!.split('@').first;
            _nameController.text = emailName.isNotEmpty
                ? emailName
                : 'المدير الأول';
          } else {
            _nameController.text = 'المدير الأول';
          }
        }

        // مستخدم Google لا يحتاج لإدخال البريد أو كلمة المرور
        if (!_isGoogleUser) {
          if (_emailController.text.isEmpty) {
            if (userEmail?.isNotEmpty ?? false) {
              _emailController.text = userEmail!;
            } else {
              _emailController.text = 'admin@ashur.local';
            }
          }
        } else {
          // مستخدم Google - نستخدم بريده الموجود
          if (_emailController.text.isEmpty &&
              (userEmail?.isNotEmpty ?? false)) {
            _emailController.text = userEmail!;
          }
        }

        // لا نضع كلمة مرور افتراضية للدور
        if (_roleCodeController.text.isEmpty) {
          _roleCodeController.text = '';
        }

        // إعادة بناء الواجهة بعد تحديد نوع المستخدم - setState واحد فقط
        if (mounted) {}
      } on Exception catch (_) {
        // في حالة الخطأ، استخدم قيم افتراضية
        if (_nameController.text.isEmpty) {
          _nameController.text = 'المدير الأول';
        }

        if (_emailController.text.isEmpty) {
          _emailController.text = 'admin@ashur.local';
        }

        if (_roleCodeController.text.isEmpty) {
          _roleCodeController.text = '';
        }
      }
    }
  }

  void _handleUsersState(UsersState state) {
    if (!mounted) return;

    if (state is RoleCreated) {
      // تم إنشاء دور المدير بنجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إنشاء دور المدير بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
      // انتظار قصير للتأكد من حفظ الدور
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          if (_isUsingCurrentUser) {
            // إذا كنا نستخدم المستخدم الحالي، نحدث بياناته بدلاً من إنشاء مستخدم جديد
            _updateCurrentUserAsAdmin();
          } else {
            // إنشاء مستخدم جديد
            _createAdminUser();
          }
        }
      });
    } else if (state is UserCreated) {
      // تم إنشاء المستخدم المدير بنجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إنشاء المدير الأول بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
      // مسح cache التحقق من المدير فوراً
      AdminCheckMiddleware.clearCache();

      // التحقق من إنشاء المدير بنجاح
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (mounted) {
          final hasAdmin = await AdminCheckMiddleware.forceCheckAdmin();
          if (hasAdmin && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم التأكد من إنشاء المدير بنجاح!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            );
          }
        }
      });

      // تسجيل دخول المدير تلقائياً
      _autoLoginAdmin();
    } else if (state is UserUpdated) {
      // تم تحديث المستخدم بنجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إصلاح المستخدم وإضافة دور المدير بنجاح!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
      // مسح cache التحقق من المدير
      AdminCheckMiddleware.clearCache();

      // منع الانتقال المتكرر
      if (!_hasNavigated) {
        _hasNavigated = true;

        // الانتقال للداشبورد بعد تأخير قصير
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && !_hasNavigated) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        });
      }
    } else if (state is UserDeleted) {
      // تم حذف المستخدم بنجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم حذف المستخدم، جاري إعادة الإنشاء...'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    } else if (state is UsersError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنشاء المدير: ${state.message}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleCodeController.dispose();
    _accountPasswordController.dispose();
    _usersBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AssyrianTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(12.w),
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
                            isLandscape: true,
                          ),
                        ),
                      ),

                      SizedBox(width: 4.w),

                      // نموذج إنشاء المدير - نصف الشاشة
                      Expanded(
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: Center(
                            child: SingleChildScrollView(
                              child: _buildCreateAdminFormLandscape(),
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
                            height: constraints.maxHeight * 0.7,
                            child: Center(
                              child: AssyrianTheme.getSimpleLamassuForAuth(
                                isDarkBackground: true,
                              ),
                            ),
                          ),
                        ),

                        // نموذج إنشاء المدير مع هامش سلبي
                        Transform.translate(
                          offset: Offset(0, -200.h),
                          child: _buildCreateAdminForm(),
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

  /// بناء نموذج إنشاء المدير للشاشة الأفقية (أحجام أصغر)
  Widget _buildCreateAdminFormLandscape() {
    return Column(
      children: [
        // قسم معلومات الحساب
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0.5.w),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عنوان قسم الحساب
              Row(
                children: [
                  Icon(Icons.account_circle, color: Colors.blue, size: 12.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'معلومات الحساب',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 0.3.h),

              // حقل البريد الإلكتروني - يظهر للجميع (لكن بتنسيق مختلف)
              if (_isGoogleUser) ...[
                // مستخدم Google - عرض البريد في إطار أخضر
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 0.4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 10.sp,
                        color: Colors.green,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          _emailController.text.isNotEmpty
                              ? _emailController.text
                              : 'admin@ashur.local',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 8.sp,
                            color: Colors.green[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.check_circle,
                        size: 8.sp,
                        color: Colors.green[600],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // مستخدم عادي - عرض البريد في إطار رمادي
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 0.4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 10.sp,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          _emailController.text.isNotEmpty
                              ? _emailController.text
                              : 'admin@ashur.local',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 8.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.lock_outline,
                        size: 8.sp,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 0.5.h),

              // ملاحظة لمستخدم Google
              if (_isGoogleUser)
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 10.sp,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          'يمكنك تسجيل الدخول عبر جوجل فقط',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 7.sp,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: 0.5.h),

        // قسم معلومات المدير
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0.5.w),
          decoration: BoxDecoration(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان قسم المدير
                Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: AssyrianTheme.primaryGold,
                      size: 12.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'معلومات المدير',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 0.3.h),

                // حقل اسم المدير
                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 8.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اسم المدير',
                    prefixIcon: Container(
                      margin: EdgeInsets.all(1.w),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 10.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: const BorderSide(
                        color: AssyrianTheme.primaryGold,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 0.4.h,
                    ),
                    hintStyle: TextStyle(
                      color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                      fontFamily: 'Cairo',
                      fontSize: 8.sp,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'اسم المدير مطلوب';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 0.3.h),

                // حقل كلمة مرور الوصول
                TextFormField(
                  controller: _roleCodeController,
                  obscureText: true,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 8.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                  decoration: InputDecoration(
                    hintText: 'كلمة مرور الوصول',
                    prefixIcon: Container(
                      margin: EdgeInsets.all(1.w),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                      child: Icon(
                        Icons.key_rounded,
                        size: 10.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: const BorderSide(
                        color: AssyrianTheme.primaryGold,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 0.4.h,
                    ),
                    hintStyle: TextStyle(
                      color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                      fontFamily: 'Cairo',
                      fontSize: 8.sp,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'كلمة مرور الوصول مطلوبة';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 0.3.h),

                // حقل كلمة مرور الحساب
                TextFormField(
                  controller: _accountPasswordController,
                  obscureText: _obscureAccountPassword,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 8.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                  decoration: InputDecoration(
                    hintText: 'كلمة مرور الحساب (لتسجيل الدخول)',
                    prefixIcon: Container(
                      margin: EdgeInsets.all(1.w),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 10.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureAccountPassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 10.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureAccountPassword = !_obscureAccountPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: const BorderSide(
                        color: AssyrianTheme.primaryGold,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 0.4.h,
                    ),
                    hintStyle: TextStyle(
                      color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                      fontFamily: 'Cairo',
                      fontSize: 8.sp,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'كلمة مرور الحساب مطلوبة';
                    }
                    if (value.length < 6) {
                      return 'يجب أن تكون 6 أحرف على الأقل';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 0.3.h),

                // ملاحظة توضيحية
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 8.sp),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          'كلمة مرور الوصول: للدخول إلى النظام\n'
                          'كلمة مرور الحساب: لتسجيل الدخول بالبريد',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 6.sp,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 0.5.h),

                // قسم تمكين الأقسام
                _buildModulesSectionLandscape(),

                SizedBox(height: 0.5.h),

                // زر إنشاء المدير
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AssyrianTheme.primaryGold,
                      foregroundColor: AssyrianTheme.deepBlue,
                      disabledBackgroundColor: AssyrianTheme.primaryGold
                          .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 0.4.h),
                      elevation: 3,
                      shadowColor: AssyrianTheme.primaryGold.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 12.w,
                                height: 12.h,
                                child: LoadingWidget(),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'جاري الإنشاء...',
                                style: TextStyle(
                                  fontSize: 7.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings, size: 12.sp),
                              SizedBox(width: 4.w),
                              Text(
                                'إنشاء المدير',
                                style: TextStyle(
                                  fontSize: 8.sp,
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
        ),
      ],
    );
  }

  /// بناء نموذج إنشاء المدير للشاشة العمودية
  Widget _buildCreateAdminForm() {
    return Column(
      children: [
        // قسم معلومات الحساب
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 1.w),
          decoration: AssyrianTheme.assyrianBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عنوان قسم الحساب
              Text(
                'معلومات الحساب',
                style: AssyrianTheme.titleStyle.copyWith(
                  fontSize: 16.sp,
                  color: AssyrianTheme.deepBlue,
                ),
              ),

              SizedBox(height: 1.h),

              // حقل البريد الإلكتروني - يظهر للجميع (لكن بتنسيق مختلف)
              if (_isGoogleUser) ...[
                // مستخدم Google - عرض البريد في إطار أخضر
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 40.w,
                    vertical: 1.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.green.shade300, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        margin: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Icon(
                          Icons.email_outlined,
                          size: 16.sp,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          _emailController.text.isNotEmpty
                              ? _emailController.text
                              : 'admin@ashur.local',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16.sp,
                            color: Colors.green[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.check_circle,
                        size: 16.sp,
                        color: Colors.green[600],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // مستخدم عادي - لا يظهر أي شيء متعلق بكلمة المرور
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 40.w,
                    vertical: 1.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        margin: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Icon(
                          Icons.email_outlined,
                          size: 16.sp,
                          color: AssyrianTheme.primaryGold,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          _emailController.text.isNotEmpty
                              ? _emailController.text
                              : 'admin@ashur.local',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.lock_outline,
                        size: 16.sp,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 1.h),

              // حقل كلمة مرور الحساب - يظهر للجميع
              if (_showAccountPassword) ...[
                Text(
                  'كلمة مرور الحساب *',
                  style: AssyrianTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 0.2.h),
                TextFormField(
                  controller: _accountPasswordController,
                  obscureText: _obscureAccountPassword,
                  keyboardType: TextInputType.visiblePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'كلمة مرور الحساب مطلوبة';
                    }
                    if (value.length < 6) {
                      return 'يجب أن تكون 6 أحرف على الأقل';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'أدخل كلمة مرور الحساب',
                    prefixIcon: Container(
                      margin: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 16.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                    suffixIcon: Container(
                      margin: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _obscureAccountPassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 16.sp,
                          color: AssyrianTheme.primaryGold,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureAccountPassword = !_obscureAccountPassword;
                          });
                        },
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
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
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2.5,
                      ),
                    ),
                    filled: true,
                    fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 40.w,
                      vertical: 1.h,
                    ),
                    hintStyle: TextStyle(
                      color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                      fontFamily: 'Cairo',
                      fontSize: 16.sp,
                    ),
                  ),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                SizedBox(height: 0.5.h),
                // ملاحظة لمستخدم Google
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 14.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'يمكنك تسجيل الدخول عبر جوجل فقط، أو استخدام كلمة المرور هذه لتسجيل الدخول بالبريد الإلكتروني لاحقاً',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 9.sp,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 1.h),

        // قسم معلومات المدير
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 1.w),
          decoration: AssyrianTheme.assyrianBorder,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان قسم المدير
                Text(
                  'معلومات المدير',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 16.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),

                SizedBox(height: 1.h),

                // حقل اسم المدير
                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اسم المدير',
                    prefixIcon: Container(
                      margin: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 16.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
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
                    filled: true,
                    fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 40.w,
                      vertical: 1.h,
                    ),
                    hintStyle: TextStyle(
                      color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                      fontFamily: 'Cairo',
                      fontSize: 16.sp,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'اسم المدير مطلوب';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 1.h),

                // حقل كلمة مرور الوصول
                TextFormField(
                  controller: _roleCodeController,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AssyrianTheme.deepBlue,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'كلمة مرور الوصول',
                    prefixIcon: Container(
                      margin: EdgeInsets.all(2.w),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
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
                    filled: true,
                    fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 40.w,
                      vertical: 1.h,
                    ),
                    hintStyle: TextStyle(
                      color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                      fontFamily: 'Cairo',
                      fontSize: 16.sp,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'كلمة مرور الوصول مطلوبة';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 1.h),

                // قسم تمكين الأقسام
                _buildModulesSection(),

                SizedBox(height: 1.h),

                // زر إنشاء المدير
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AssyrianTheme.primaryGold,
                      foregroundColor: AssyrianTheme.deepBlue,
                      disabledBackgroundColor: AssyrianTheme.primaryGold
                          .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      elevation: 4,
                      shadowColor: AssyrianTheme.primaryGold.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: LoadingWidget(),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'جاري إنشاء المدير...',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings, size: 20.sp),
                              SizedBox(width: 8.w),
                              Text(
                                'إنشاء المدير الأول',
                                style: TextStyle(
                                  fontSize: 16.sp,
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
        ),
      ],
    );
  }

  /// بناء قسم تمكين الأقسام للشاشة العمودية
  Widget _buildModulesSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.extension, color: Colors.blue, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'تمكين الأقسام',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'اختر الأقسام التي تريد تفعيلها في التطبيق',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 12.h),
          ...EnabledModulesService.availableModules.entries.map((entry) {
            final moduleId = entry.key;
            final moduleName = entry.value;
            final isCore = EnabledModulesService.coreModules.contains(moduleId);
            final isEnabled = _enabledModules[moduleId] ?? true;

            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Switch(
                    value: isEnabled,
                    onChanged: isCore
                        ? null
                        : (value) {
                            setState(() {
                              _enabledModules[moduleId] = value;
                            });
                          },
                    activeThumbColor: AssyrianTheme.primaryGold,
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    _getModuleIcon(moduleId),
                    size: 18.sp,
                    color: isEnabled ? AssyrianTheme.primaryGold : Colors.grey,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      moduleName,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: isCore
                            ? Colors.grey[600]
                            : AssyrianTheme.deepBlue,
                      ),
                    ),
                  ),
                  if (isCore)
                    Text(
                      'أساسي',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// بناء قسم تمكين الأقسام للشاشة الأفقية
  Widget _buildModulesSectionLandscape() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.extension, color: Colors.blue, size: 12.sp),
              SizedBox(width: 6.w),
              Text(
                'تمكين الأقسام',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ...EnabledModulesService.availableModules.entries.map((entry) {
            final moduleId = entry.key;
            final moduleName = entry.value;
            final isCore = EnabledModulesService.coreModules.contains(moduleId);
            final isEnabled = _enabledModules[moduleId] ?? true;

            return Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                children: [
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isEnabled,
                      onChanged: isCore
                          ? null
                          : (value) {
                              setState(() {
                                _enabledModules[moduleId] = value;
                              });
                            },
                      activeThumbColor: AssyrianTheme.primaryGold,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    _getModuleIcon(moduleId),
                    size: 10.sp,
                    color: isEnabled ? AssyrianTheme.primaryGold : Colors.grey,
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      moduleName,
                      style: TextStyle(
                        fontSize: 8.sp,
                        color: isCore
                            ? Colors.grey[600]
                            : AssyrianTheme.deepBlue,
                      ),
                    ),
                  ),
                  if (isCore)
                    Text(
                      'أساسي',
                      style: TextStyle(fontSize: 7.sp, color: Colors.grey[500]),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _getModuleIcon(String moduleId) {
    switch (moduleId) {
      case 'dashboard_view':
        return Icons.dashboard;
      case 'users_view':
        return Icons.people;
      case 'customers_view':
        return Icons.person;
      case 'inventory_view':
        return Icons.inventory_2;
      case 'subscriptions_view':
        return Icons.subscriptions;
      case 'maintenance_view':
        return Icons.build;
      case 'rentals_view':
        return Icons.home_work;
      case 'invoices_sales_manage':
      case 'invoices_purchase_manage':
      case 'invoices_cash_manage':
      case 'invoices_subscription_manage':
      case 'invoices_sales_return_manage':
        return Icons.receipt_long;
      case 'expenses_view':
        return Icons.money_off;
      case 'reports_view':
        return Icons.analytics;
      case 'settings_view':
        return Icons.settings;
      default:
        return Icons.extension;
    }
  }

  void _createAdmin() async {
    // تأكد من وجود القيم الافتراضية قبل التحقق
    if (_emailController.text.isEmpty) {
      _emailController.text = 'admin@ashur.local';
    }
    if (_nameController.text.isEmpty) {
      _nameController.text = 'المدير الأول';
    }

    try {
      // التحقق من صحة البيانات المدخلة
      if (_nameController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال اسم المدير'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      if (_emailController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال البريد الإلكتروني'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      if (_roleCodeController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال كلمة مرور الوصول'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      // التحقق من وجود مستخدم مسجل دخول بالفعل
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // المستخدم مسجل دخول بالفعل

        // أولاً: ربط حساب Google بكلمة المرور إذا كان مستخدم Google
        if (_isGoogleUser &&
            _accountPasswordController.text.trim().isNotEmpty) {
          try {
            final accountPassword = _accountPasswordController.text.trim();
            final userEmail = currentUser.email;

            // تطبيع البريد الإلكتروني قبل الربط
            final normalizedEmail = _emailService.normalize(userEmail!);

            // إنشاء بيانات اعتماد البريد الإلكتروني
            final emailCredential = EmailAuthProvider.credential(
              email: normalizedEmail, // ← استخدام البريد المطبّع
              password: accountPassword,
            );

            // ربط حساب Google بحساب البريد+كلمة المرور
            await currentUser.linkWithCredential(emailCredential);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ تم ربط كلمة المرور بنجاح!\n\n'
                    'البريد: $normalizedEmail\n'
                    'يمكنك الآن تسجيل الدخول باستخدام:\n'
                    '• جوجل\n'
                    '• البريد الإلكتروني وكلمة المرور',
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              );
            }
          } on FirebaseAuthException catch (e) {
            if (mounted) {
              String message;
              if (e.code == 'provider-already-linked') {
                message = 'الحساب مرتبط بالفعل بكلمة مرور';
              } else if (e.code == 'email-already-in-use') {
                message = 'البريد مستخدم بالفعل في حساب آخر';
              } else if (e.code == 'weak-password') {
                message = 'كلمة المرور ضعيفة (يجب 6 أحرف على الأقل)';
              } else if (e.code == 'requires-recent-login') {
                message = 'يجب تسجيل الدخول مؤخراً. سجل خروج ثم دخول مرة أخرى';
              } else {
                message = 'خطأ في ربط كلمة المرور: ${e.message}';
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              );
            }
          }
        }

        // ثانياً: حفظ بيانات المستخدم وإنشاء دور المدير
        try {
          // تطبيع البريد الإلكتروني
          final normalizedEmail = _emailService.normalize(currentUser.email!);

          // تحديث الاسم إذا كان مختلفاً
          if (currentUser.displayName != _nameController.text.trim()) {
            await currentUser.updateDisplayName(_nameController.text.trim());
          }

          // حفظ بيانات المستخدم في مجموعة المؤسسة فقط (البريد المطبّع)
          // ✅ set واحد بدمج — ذري تلقائياً، يسبق معاملة الدور ②
          final organizationId = _emailService.normalize(currentUser.email!);
          await FirebaseFirestore.instance
              .collection(organizationId)
              .doc('users')
              .collection('users')
              .doc(currentUser.uid)
              .set({
                'email': normalizedEmail, // حفظ البريد المطبّع
                'name': _nameController.text.trim(),
                'phoneNumber': currentUser.phoneNumber,
                'roleIds': ['admin'],
                'accessCode': _roleCodeController.text.trim(),
                'isActive': true,
                'isEmailVerified': currentUser.emailVerified,
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': _nameController.text.trim(),
              }, SetOptions(merge: true));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'تم استخدام الحساب الحالي. جاري إنشاء دور المدير...',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            );
          }

          // إنشاء دور المدير
          _createAdminRoleForCurrentUser();
        } on Exception {
          // تجاهل الأخطاء هنا - المستخدم موجود ونكمل العملية
          // نكمل إنشاء دور المدير حتى لو حدث خطأ
          _createAdminRoleForCurrentUser();
        }
      } else {
        // لا يوجد مستخدم مسجل دخول
        // يجب إنشاء حساب جديد بالبريد وكلمة المرور

        // التحقق من كلمة مرور الحساب
        if (_accountPasswordController.text.trim().isEmpty) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('يرجى إدخال كلمة مرور الحساب'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          );
          return;
        }

        // إنشاء حساب جديد في Firebase Auth
        try {
          final email = _emailController.text.trim();
          final accountPassword = _accountPasswordController.text.trim();

          // تطبيع البريد الإلكتروني قبل إنشاء الحساب
          final normalizedEmail = _emailService.normalize(email);

          // إنشاء الحساب
          final userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: normalizedEmail, // ← استخدام البريد المطبّع
                password: accountPassword,
              );

          // تحديث اسم المستخدم
          await userCredential.user!.updateDisplayName(
            _nameController.text.trim(),
          );

          // حفظ بيانات المستخدم في مجموعة المؤسسة (البريد المطبّع)
          // ✅ set واحد بدمج — ذري تلقائياً، يسبق معاملة الدور ②
          // (نفس مسار المستخدم الحالي أعلاه — بدونه كان
          // transaction.update في _createAdminRoleForCurrentUser
          // يرمي not-found لأن مستند المستخدم غير موجود)
          final organizationId = _emailService.normalize(email);
          await FirebaseFirestore.instance
              .collection(organizationId)
              .doc('users')
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
                'email': normalizedEmail,
                'name': _nameController.text.trim(),
                'phoneNumber': null,
                'roleIds': ['admin'],
                'accessCode': _roleCodeController.text.trim(),
                'isActive': true,
                'isEmailVerified': false,
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': _nameController.text.trim(),
              }, SetOptions(merge: true));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ تم إنشاء الحساب بنجاح!\n\n'
                  'البريد: $normalizedEmail\n'
                  'يمكنك الآن تسجيل الدخول بالبريد وكلمة المرور',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            );
          }

          // الآن إنشاء دور المدير
          _createAdminRoleForCurrentUser();
        } on FirebaseAuthException catch (e) {
          setState(() {
            _isLoading = false;
          });

          String errorMessage = 'فشل في إنشاء الحساب';
          if (e.code == 'email-already-in-use') {
            errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
          } else if (e.code == 'weak-password') {
            errorMessage = 'كلمة المرور ضعيفة جداً (يجب 6 أحرف على الأقل)';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'البريد الإلكتروني غير صحيح';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            );
          }
        } on Exception catch (_) {
          setState(() {
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطأ في إنشاء الحساب: حدث خطأ غير متوقع'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'فشل في إنشاء الحساب';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
      } else if (e.code == 'weak-password') {
        errorMessage = 'كلمة المرور ضعيفة جداً';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'البريد الإلكتروني غير صحيح';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    } on Exception catch (_) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء الحساب: حدث خطأ غير متوقع'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }

  /// إنشاء دور المدير للمستخدم الحالي
  // ✅ ذري: إنشاء الدور + تحديث roleIds في runTransaction واحدة
  // (all-or-nothing) — انظر الملاحظة العليا في
  // auth_repository_impl.dart (البند ②).
  void _createAdminRoleForCurrentUser() async {
    _isUsingCurrentUser = true; // نحن نستخدم المستخدم الحالي
    try {
      // التحقق من وجود مستخدم مسجل دخول
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'خطأ: لا يوجد مستخدم مسجل دخول. يرجى إنشاء حساب أولاً.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      // التحقق من صحة البيانات المدخلة
      if (_nameController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال اسم المدير'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      if (_roleCodeController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال كلمة مرور الوصول'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      // التحقق من كلمة مرور الحساب لمستخدمي Google
      if (_isGoogleUser && (_accountPasswordController.text.trim().isEmpty)) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال كلمة مرور الحساب'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جاري إنشاء دور المدير للمستخدم: ${currentUser.email}'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );

      // الحصول على جميع الصلاحيات من PermissionsManager
      final permissionsManager = PermissionsManager();
      final allPermissions = permissionsManager.getAllPermissions();
      final allPermissionIds = allPermissions.map((p) => p.id).toList();

      // حفظ الأقسام المفعلة
      final service = EnabledModulesService();
      service.saveEnabledModules(_enabledModules);

      // حفظ دور المدير في Firestore مباشرة
      if (currentUser.email == null) {
        throw Exception('البريد الإلكتروني غير موجود');
      }

      final organizationId = _emailService.normalize(currentUser.email!);

      // حفظ الدور في مجموعة roles (المسار الصحيح: organizationId/users/roles/admin)
      // + تحديث roleIds للمستخدم في معاملة واحدة (all-or-nothing)
      final roleRef = FirebaseFirestore.instance
          .collection(organizationId)
          .doc('users')
          .collection('roles')
          .doc('admin');
      final adminUserRef = FirebaseFirestore.instance
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .doc(currentUser.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(
          roleRef,
          {
            'name': 'admin',
            'displayName': 'المدير',
            'description': 'دور المدير الأساسي مع جميع الصلاحيات',
            'permissions': allPermissionIds,
            'isActive': true, // إضافة isActive
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        // ⚠️ set بدمج (لا update) — مستند المستخدم قد
        // لا يوجد بعد (مسار الحساب الجديد) وupdate
        // يرمي not-found فتُلغى المعاملة. set بدمج
        // ينشئه أو يدمجه — ذري مع إنشاء الدور.
        transaction.set(
          adminUserRef,
          {'roleIds': ['admin']},
          SetOptions(merge: true),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ تم إنشاء دور المدير بنجاح!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }

      // الانتقال للداشبورد مباشرة
      _autoLoginAdmin();
    } on Exception catch (_) {
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنشاء دور المدير: حدث خطأ غير متوقع'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }
  }

  Future<void> _createAdminUser() async {
    try {
      // التحقق من صحة البيانات
      if (_nameController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال اسم المدير'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      if (_roleCodeController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال كلمة مرور الوصول'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      if (_accountPasswordController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال كلمة مرور الحساب'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      // الحصول على معرف المستخدم الحالي
      String createdBy;
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] != null) {
          createdBy = switchedUser['id'] as String;
        } else {
          createdBy = FirebaseAuth.instance.currentUser?.uid ?? '';
        }
      } on Exception catch (_) {
        createdBy = FirebaseAuth.instance.currentUser?.uid ?? '';
      }

      final createUserEvent = CreateUserEvent(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        roleCode: _roleCodeController.text.trim(),
        roleIds: const ['admin'],
        accountPassword: _accountPasswordController.text.trim(),
        createdBy: createdBy, // إضافة معرف المنشئ
      );

      _usersBloc.add(createUserEvent);
    } on Exception catch (_) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء المستخدم المدير: حدث خطأ غير متوقع'),
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

  /// تحديث المستخدم الحالي ليصبح مدير
  void _updateCurrentUserAsAdmin() {
    try {
      // بدلاً من الانتقال مباشرة للداشبورد، ننشئ مستخدماً في قاعدة البيانات
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('خطأ: لا يوجد مستخدم مسجل دخول'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      // التحقق من صحة البيانات
      if (_nameController.text.trim().isEmpty &&
          (currentUser.displayName?.isEmpty ?? true)) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال اسم المدير'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      if (_roleCodeController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يرجى إدخال كلمة مرور الوصول'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      // إنشاء مستخدم في قاعدة البيانات مع دور المدير
      final createUserEvent = CreateUserEvent(
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : (currentUser.displayName ?? 'المدير الأول'),
        email: currentUser.email,
        roleCode: _roleCodeController.text.trim(),
        roleIds: const ['admin'], // ربط المستخدم بدور المدير
        useCurrentUser: true, // استخدام المستخدم الحالي لإنشاء المدير
        createdBy: currentUser.uid, // إضافة معرف المنشئ
      );

      _usersBloc.add(createUserEvent);
    } on Exception catch (_) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث المستخدم: حدث خطأ غير متوقع'),
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

  Future<void> _autoLoginAdmin() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // لا يوجد مستخدم مسجل دخول - خطأ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('خطأ: لا يوجد مستخدم مسجل دخول'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        return;
      }

      // إنشاء بيانات المستخدم المدير للتبديل
      // الحصول على جميع الصلاحيات من PermissionsManager
      final permissionsManager = PermissionsManager();
      final allPermissions = permissionsManager.getAllPermissions();
      final allPermissionIds = allPermissions.map((p) => p.id).toList();

      final adminUserEntity = UserManagementEntity(
        id: currentUser.uid,
        email: currentUser.email ?? _emailController.text.trim(),
        name: _nameController.text.trim(),
        roles: [
          RoleEntity(
            id: 'admin',
            name: 'admin',
            displayName: 'المدير',
            description: 'دور المدير الأساسي مع جميع الصلاحيات',
            permissions: allPermissionIds,
            createdAt: DateTime.now(),
          ),
        ],
        roleCode: _roleCodeController.text.trim(),
        createdAt: DateTime.now(),
      );

      // حفظ بيانات المستخدم المبدل (دور المدير) بشكل دائم
      // + تسجيل معرف الإشعارات بالتوازي — عمليتان مستقلتان
      // (يوفر وقت الانتقال للداشبورد)
      final registerFuture = () async {
        final organizationEmail = currentUser.email;
        if (organizationEmail != null && organizationEmail.isNotEmpty) {
          await OneSignalNotificationService.registerPlayerIdForUser(
            uid: currentUser.uid,
            organizationEmail: organizationEmail,
          );
        }
      }();

      await SessionService.setSwitchedUser(adminUserEntity);
      await registerFuture;

      final adminUser = UserEntity(
        id: currentUser.uid,
        email: currentUser.email ?? _emailController.text.trim(),
        name: _nameController.text.trim(),
        phoneNumber: currentUser.phoneNumber,
        photoUrl: currentUser.photoURL,
        provider: 'admin_creation',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      // مسح cache التحقق من المدير فوراً
      AdminCheckMiddleware.clearCache();

      // الانتقال للداشبورد مباشرة - المدير تم إنشاؤه بنجاح
      // لا حاجة للتحقق مرة أخرى لأننا أنشأنا المستخدم بالفعل
      if (!_hasNavigated && mounted) {
        _hasNavigated = true;

        final authBloc = context.read<AuthBloc>();
        authBloc.add(SwitchUserRequested(user: adminUser));

        // انتظار قصير للتأكد من حفظ البيانات
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // إظهار رسالة نجاح
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ تم إنشاء المدير بنجاح! جاري الانتقال...'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          );

          // مسح الـ cache مرة أخرى قبل الانتقال
          AdminCheckMiddleware.clearCache();

          // الانتقال للداشبورد
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (route) => false, // إزالة جميع المسارات السابقة
          );
        }
      }
    } on Exception catch (_) {
      // خطأ في تسجيل دخول المدير تلقائياً - الانتقال للداشبورد مباشرة
      AdminCheckMiddleware.clearCache();
      if (!_hasNavigated && mounted) {
        _hasNavigated = true;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء المدير بنجاح مع تحذير'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );

        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
              (route) => false,
            );
          }
        });
      }
    }
  }
}




