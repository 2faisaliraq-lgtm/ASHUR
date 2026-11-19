import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/permissions/permission_checker.dart';
import '../../core/services/session_service.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import 'assyrian_bottom_navigation_bar.dart';
import 'navigation_item.dart';
import 'navigation_service.dart';

/// الصفحة الرئيسية مع نظام التنقل المبني على أدوار المستخدم الفعلية
class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  final NavigationService _navigationService = NavigationService();
  List<String> _userPermissions = [];
  bool _hasLoadedOnce = false; // منع إعادة التحميل
  final PermissionChecker _permissionChecker = PermissionChecker();
  StreamSubscription? _permissionsSubscription;

  @override
  void initState() {
    super.initState();

    // تهيئة PermissionChecker وانتظار اكتمال تحميل الصلاحيات قبل بناء الواجهة
    _permissionChecker.initialize().then((_) async {
      if (!mounted) return;

      // إذا كان هناك مستخدم مبدل (من شاشة رمز الوصول)، تجاهل البيانات المحملة مسبقاً
      // وقم بإعادة تحميل الصلاحيات للمستخدم المبدل
      final hasSwitched = await SessionService.hasSwitchedUser();
      if (hasSwitched) {
        _navigationService.resetPermissionsLoaded();

        // تحديث NavigationService.switchedUser.value لنافذة الترحيب والداشبورد
        final switchedData = await SessionService.getSwitchedUser();
        if (switchedData != null) {
          NavigationService().switchedUser.value = switchedData;
        }

        _loadUserPermissions();
        return;
      }

      // التحقق إذا كانت بيانات التنقل محملة مسبقاً من شاشة السبلس
      if (_navigationService.isNavigationPreloaded) {
        // البيانات محملة مسبقاً مع الصلاحية الصحيحة من السبلس، استخدمها مباشرة
        _userPermissions = List<String>.from(_navigationService.items
            .expand((item) => (item.requiredPermissions ?? <dynamic>[]).cast<String>())
            .toSet());
        // التحقق إذا كان هناك عناصر في القائمة
        if (_navigationService.items.isNotEmpty) {
          // البيانات جاهزة، لا نحتاج لإعادة التحميل
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _navigationService.preloadAllPages();
            }
          });
        } else {
          // القائمة فارغة رغم التحميل المسبق، قم بالتحميل العادي
          _loadUserPermissions();
        }
      } else {
        // البيانات غير محملة مسبقاً، قم بالتحميل العادي
        _loadUserPermissions();
      }
    });

    // الاستماع لتغييرات الصلاحيات
    _permissionsSubscription = _permissionChecker.permissionsStream.listen((
      permissions,
    ) {
      if (mounted) {
        setState(() {
          _userPermissions = permissions;
        });
        _navigationService.updatePermissions(permissions);
      }
    });
  }

  @override
  void dispose() {
    _permissionsSubscription?.cancel();
    super.dispose();
  }

  /// تحميل صلاحيات المستخدم الفعلية من قاعدة البيانات
  Future<void> _loadUserPermissions() async {
    // منع إعادة التحميل إذا تم التحميل مسبقاً
    if (_hasLoadedOnce) return;

    // وضع علامة التحميل فوراً
    _hasLoadedOnce = true;

    // تحميل الصلاحيات الفعلية في الخلفية بدون setState
    _loadActualPermissions();
  }

  /// تحميل الصلاحيات الفعلية في الخلفية
  /// باستخدام تحميل مسبق للصلاحيات من PermissionChecker (محفوظة مسبقاً في شاشة السبلش)
  Future<void> _loadActualPermissions() async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        // المستخدم غير مسجل دخول - العودة لشاشة تسجيل الدخول
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<AuthBloc>().add(CheckAuthStatus());
          }
        });
        return;
      }

      // تحميل مسبق للصلاحيات من PermissionChecker (محفوظة مسبقاً في شاشة السبلش)
      // مسح كاش الصلاحيات وإعادة التحميل للمستخدم المبدل إذا وجد
      await _permissionChecker.clearCache();
      await _permissionChecker.refreshPermissions();
      final permissions = await _permissionChecker.getUserPermissions();
      final isAdmin = permissions.contains('admin') ||
          permissions.contains('ADMIN') ||
          permissions.contains('users_manage');

      if (!mounted) return;

      setState(() {
        _userPermissions = permissions;
      });

      // تهيئة التنقل بالصلاحيات الفعلية
      await _navigationService.initializeNavigation(
        userPermissions: _userPermissions,
        isAdmin: isAdmin,
      );
    } on Exception catch (_) {
      // في حالة الخطأ، العودة لشاشة المصادقة بدلاً من إعطاء صلاحيات افتراضية
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AuthBloc>().add(CheckAuthStatus());
        }
      });
    }
  }

  /// إعادة تحميل صلاحيات المستخدم (مع مسح الجلسة المحفوظة)
  Future<void> refreshUserPermissions() async {
    if (!mounted) return;

    // مسح الجلسة المحفوظة لإجبار النظام على إعادة التحميل من قاعدة البيانات
    await SessionService.clearRolePermanently();

    if (!mounted) return;
    await _loadUserPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // الاستماع لتغييرات حالة المصادقة
        if (state is AuthUnauthenticated) {
          // المستخدم تم تسجيل خروجه - العودة لشاشة تسجيل الدخول
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            }
          });
        } else if (state is AuthError) {
          // خطأ في المصادقة - العودة لشاشة تسجيل الدخول
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            }
          });
        }
      },
      child: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    // عرض المحتوى مباشرة بدون تحميل

    return Scaffold(
      body: _buildMobileLayout(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// تخطيط الهواتف المحمولة
  Widget _buildMobileLayout() {
    return ValueListenableBuilder<List<NavigationItem>>(
      valueListenable: _navigationService.itemsNotifier,
      builder: (context, items, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _navigationService.currentIndexNotifier,
          builder: (context, currentIndex, _) {
            // التأكد من أن المؤشر ضمن النطاق الصحيح

            // تحميل مسبق لجميع الصفحات لتكون جاهزة عند التبديل بين الأقسام دون تأخير
            final pages = _navigationService.getAllPages();

            // التأكد من أن المؤشر ضمن نطاق الصفحات الفعلية
            final safePageIndex = pages.isNotEmpty
                ? currentIndex.clamp(0, pages.length - 1)
                : 0;

            return IndexedStack(
              index: pages.isNotEmpty ? safePageIndex : null,
              children: pages,
            );
          },
        );
      },
    );
  }

  /// شريط التنقل السفلي للهواتف
  Widget _buildBottomNavigationBar() {
    return ValueListenableBuilder(
      valueListenable: _navigationService.itemsNotifier,
      builder: (context, items, child) {
        return ValueListenableBuilder(
          valueListenable: _navigationService.currentIndexNotifier,
          builder: (context, currentIndex, child) {
            return SizedBox(
              height: kBottomNavigationBarHeight,
              child: AssyrianBottomNavigationBar(
                onTap: _navigationService.setCurrentIndex,
                currentIndex: currentIndex,
                items: items,
              ),
            );
          },
        );
      },
    );
  }
}
