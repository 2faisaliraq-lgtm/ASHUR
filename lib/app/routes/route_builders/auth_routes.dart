import 'package:material_ui/material_ui.dart';

import '../../../features/auth/presentation/pages/create_admin_page.dart';
import '../../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../../features/auth/presentation/pages/login_page.dart';
import '../../../features/auth/presentation/pages/signup_page.dart';
import '../../auth/static_auth_wrapper.dart';
import '../../../features/splash/splash_screen.dart';
import '../route_paths.dart';

/// مسارات المصادقة
Map<String, WidgetBuilder> get authRoutes => {
      RoutePaths.splash: (context) => const SplashScreen(),
      RoutePaths.home: (context) => const StaticAuthWrapper(),
      RoutePaths.login: (context) => const LoginPage(),
      RoutePaths.signup: (context) => const SignupPage(),
      RoutePaths.forgotPassword: (context) => const ForgotPasswordPage(),
      RoutePaths.loading: (context) => const SplashScreen(),
      RoutePaths.createAdmin: (context) => const CreateAdminPage(),
    };
