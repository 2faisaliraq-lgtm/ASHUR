import 'package:firebase_auth/firebase_auth.dart';

import '../../core/widgets/loading_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../app/config/app_initializer.dart';
import '../../core/middleware/admin_check_middleware.dart';
import '../../core/navigation/main_navigation_page.dart';
import '../../core/navigation/navigation_service.dart';
import '../../core/permissions/permission_checker.dart';
import '../../core/services/auth_navigation_service.dart';
import '../../core/services/one_signal_notification_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/enabled_modules_service.dart';
import '../../core/theme/assyrian_theme.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/create_admin_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/role_access_code_page.dart';
import '../../features/users/presentation/bloc/users_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // حالة التحقق
  bool _isChecking = true;
  String _loadingText = 'جاري التحميل...';
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();

    // بدء جميع عمليات التحقق
    _performAllChecks();
  }

  /// إجراء جميع عمليات التحقق المطلوبة بسرعة فائقة مع إعادة محاولة تلقائية
  Future<void> _performAllChecks() async {
    final startTime = DateTime.now();
    const minDisplayDuration = Duration(milliseconds: 200);
    const maxRetries = 3;

    // التحقق من الاتصال بالإنترنت أولاً
    final hasInternet = await _checkInternetAccess();
    if (!hasInternet) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _nextScreen = _buildCheckErrorScreen(
            title: 'لا يوجد اتصال بالخادم',
            message: 'لا يوجد اتصال بالإنترنت.\nيرجى التحقق من الاتصال والمحاولة مرة أخرى.',
          );
        });
      }
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (mounted) {
        setState(() {
          _loadingText = attempt > 1
              ? 'جاري إعادة المحاولة... ($attempt/$maxRetries)'
              : 'جاري التحقق من المصادقة...';
        });
      }

      final nextScreen = await _attemptChecks(startTime, minDisplayDuration);
      if (nextScreen != null) {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _nextScreen = nextScreen;
          });
        }
        return;
      }

      if (attempt < maxRetries) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // بعد فشل 3 محاولات - نعرض نفس شاشة التحميل مع رسالة انقطاع الاتصال
    if (mounted) {
      setState(() {
        _loadingText = 'لا يوجد اتصال بالخادم';
      });
    }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _loadingText = 'جاري إعادة المحاولة...';
      });
    }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _loadingText = 'لا يوجد اتصال بالخادم';
      });
    }
    // إعادة المحاولة تلقائياً
    _performAllChecks();
  }

  Future<bool> _checkInternetAccess() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;

      if (result == ConnectivityResult.none) {
        return false;
      }

      final lookupResult = await InternetAddress.lookup('google.com');
      return lookupResult.isNotEmpty && lookupResult[0].rawAddress.isNotEmpty;
    } on Exception catch (_) {
      return false;
    }
  }

  Future<Widget?> _attemptChecks(DateTime startTime, Duration minDisplayDuration) async {
    try {
      await AppInitializer.ensureInitialized();

      if (mounted) {
        setState(() {
          _loadingText = 'جاري التحقق من المصادقة...';
        });
      }

      final authStateChanges = FirebaseAuth.instance.authStateChanges();

      final user = await authStateChanges
          .firstWhere(
            (user) => user != null,
            orElse: () => FirebaseAuth.instance.currentUser,
          )
          .timeout(
            const Duration(seconds: 1, milliseconds: 500),
            onTimeout: () => FirebaseAuth.instance.currentUser,
          );

      if (user == null) {
        await _waitForMinTime(startTime, minDisplayDuration);
        return const LoginPage();
      }

      // ⚠️ تسجيل Player ID في الخلفية (غير حاجب):
      // استدعاء شبكي (استعلام + batch في Firestore) كان
      // يُنتظر في المسار الحرج فيؤخر التوجيه ويسبب تجمد
      // البدء. التسجيل غير ضروري للتوجيه ومسجّل أيضاً
      // عبر مستمع authStateChanges داخل OneSignal.
      unawaited(
        OneSignalNotificationService.registerCurrentUserPlayerId()
            .catchError((Object _) {}),
      );

      final userEntity = UserEntity(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName,
        phoneNumber: user.phoneNumber,
        photoUrl: user.photoURL,
        provider: user.providerData.isEmpty ? null : user.providerData.first.providerId,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        lastLoginAt: user.metadata.lastSignInTime,
      );

      if (mounted) {
        setState(() {
          _loadingText = 'جاري تجهيز التطبيق...';
        });
      }

      final hasAdmin = await AdminCheckMiddleware.checkAdminWithDetails()
          .timeout(
            const Duration(milliseconds: 1200),
            onTimeout: () => const AdminCheckResult(
              hasAdmin: false,
              hasAnyUsers: false,
              usersCount: 0,
              adminsCount: 0,
              recommendedRoute: '/create-admin',
              checkFailed: true,
            ),
          );

      if (hasAdmin.checkFailed || !hasAdmin.hasAdmin) {
        await _waitForMinTime(startTime, minDisplayDuration);
        return null;
      }

      // ⚠️ مهلة 15 ثانية (لا 1.2s): checkAuthNavigation
      // يجري عدة استعلامات Firestore (مدير + دور
      // المستخدم + الأدوار) ولكل منها مهلة 10s
      // داخلياً، فمهلة 1.2s كانت تنقطع قبل اكتمالها
      // فتتجاهل شاشة رمز الوصول وتذهب للداشبورد.
      // وعند انتهاء المهلة الافتراضي شاشة رمز الوصول
      // (آمن) لا الداشبورد — لا تمنح الدخول دون تحقق.
      final result = await AuthNavigationService.checkAuthNavigation(userEntity)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => AuthNavigationResult.needsAccessCode(userEntity),
          );

      await _waitForMinTime(startTime, minDisplayDuration);

      switch (result.type) {
        case AuthNavigationType.needsAdminSetup:
          return BlocProvider<UsersBloc>(
            create: (context) => GetIt.instance<UsersBloc>(),
            child: const CreateAdminPage(),
          );
        case AuthNavigationType.needsAccessCode:
          return RoleAccessCodePage(
            userEmail: result.user?.email ?? userEntity.email,
            userName: result.user?.name ?? userEntity.name ?? '',
          );
        case AuthNavigationType.navigateToMain:
// تحميل مسبق للبيانات في شاشة السبلش لتسريع opening MainNavigationPage
          await _preloadNavigationData(userEntity);
          await _waitForMinTime(startTime, minDisplayDuration);
          return const MainNavigationPage();
        case AuthNavigationType.error:
          return _buildCheckErrorScreen(
            title: 'تعذر إتمام العملية',
            message: result.errorMessage ?? 'حدث خطأ أثناء التحقق من الحالة.\nيرجى المحاولة مرة أخرى.',
          );
      }
    } on Exception catch (_) {
      await _waitForMinTime(startTime, minDisplayDuration);
      return null;
    }
  }

  /// الانتظار للحد الأدنى من وقت العرض
  Future<void> _waitForMinTime(DateTime startTime, Duration minDuration) async {
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }
  }

  /// تحميل مسبق للبيانات في شاشة السبلش لتسريع opening MainNavigationPage
  Future<void> _preloadNavigationData(UserEntity userEntity) async {
    try {
      final permissionChecker = PermissionChecker();
      await permissionChecker.initialize();

      // تحميل مسبق للصلاحيات
      final permissions = await permissionChecker.getUserPermissions();

      // تحميل مسبق لبيانات المستخدم المبدل
      final navigationService = NavigationService();
      final hasSwitchedUser = await SessionService.hasSwitchedUser();
      Map<String, dynamic>? switchedUserData;
      if (hasSwitchedUser) {
        switchedUserData = await SessionService.getSwitchedUser();
      }
      navigationService.switchedUser.value = switchedUserData;

      // تحميل مسبق لعناصر التنقل مع الصلاحيات
      final isAdmin = permissions.contains('admin') ||
          permissions.contains('ADMIN') ||
          permissions.contains('users_manage');
      await navigationService.initializeNavigation(
        userPermissions: permissions,
        isAdmin: isAdmin,
      );

      // تحميل مسبق لوحدات النظام المفعلة
      final enabledModules = await EnabledModulesService().getEnabledModules();
      navigationService.enabledModulesNotifier.value = enabledModules;

      // تحميل مسبق لإعدادات الإجراءات السريعة من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedActions = prefs.getString('dashboard_quick_actions');
      final quickActionsSettings = <String, bool>{};
      if (savedActions != null) {
        try {
          final List<dynamic> decoded = jsonDecode(savedActions);
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              final id = item['id'];
              final enabled = item['enabled'];
              if (id is String && enabled is bool) {
                quickActionsSettings[id] = enabled;
              }
            }
          }
        } on Exception catch (_) {
          // إذا كانت البيانات تالفة، نستخدم الإعدادات الافتراضية
        }
      }
      navigationService.quickActionsSettings.value = quickActionsSettings;
    } on Exception catch (_) {
      // في حالة الخطأ، سيتم التحميل العادي عند opening MainNavigationPage
    }
  }

  /// بناء شاشة خطأ التحقق من النظام
  Widget _buildCheckErrorScreen({
    required String title,
    required String message,
  }) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AssyrianTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // أيقونة الخطأ
                Icon(
                  Icons.warning_amber_rounded,
                  size: 100.sp,
                  color: AssyrianTheme.primaryGold,
                ),
                SizedBox(height: 32.h),

                // عنوان الخطأ
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.ivoryWhite,
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),

                // وصف الخطأ
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.7),
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48.h),

                // زر إعادة المحاولة
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isChecking = true;
                      _nextScreen = null;
                    });
                    _performAllChecks();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AssyrianTheme.primaryGold,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                      horizontal: 32.w,
                      vertical: 16.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // إذا انتهت عمليات التحقق، نعرض الشاشة التالية
    if (!_isChecking && _nextScreen != null) {
      return _nextScreen!;
    }

    // أثناء التحقق، نعرض شاشة التحميل
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AssyrianTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // الشعار الآشوري الكبير
                      Expanded(
                        child: Center(
                          child: AssyrianTheme.getSimpleLamassuForAuth(
                            isDarkBackground: true,
                          ),
                        ),
                      ),

                      // اسم التطبيق
                      Text(
                        'آشور',
                        style: AssyrianTheme.titleStyle.copyWith(
                          fontSize: 48.sp,
                          color: AssyrianTheme.primaryGold,
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // وصف التطبيق
                      Text(
                        'نظام إدارة متكامل',
                        style: AssyrianTheme.subtitleStyle.copyWith(
                          fontSize: 20.sp,
                          color: AssyrianTheme.ivoryWhite.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),

                      SizedBox(height: 40.h),

                      // مؤشر التحميل
                      SizedBox(
                        width: 40.w,
                        height: 40.h,
                      child: LoadingWidget(size: 40),
                      ),

                      SizedBox(height: 16.h),

                      // نص حالة التحميل
                      Text(
                        _loadingText,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AssyrianTheme.ivoryWhite.withValues(
                            alpha: 0.7,
                          ),
                          fontFamily: 'Cairo',
                        ),
                      ),

                      SizedBox(height: 60.h),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}




