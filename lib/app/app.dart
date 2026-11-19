import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as fl_localizations;
import 'package:get_it/get_it.dart';

import '../core/responsive/responsive_helper.dart';
import '../core/services/push_notification_service.dart';
import '../core/widgets/connection_monitor.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import 'auth/static_auth_wrapper.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

/// التطبيق الرئيسي
class AshurApp extends StatelessWidget {
  const AshurApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  // ignore: cascade_invitations
  Widget build(BuildContext context) {
    PushNotificationService.setNavigatorKey(navigatorKey);

    return BlocProvider<AuthBloc>(
      create: (context) => GetIt.instance<AuthBloc>()..add(CheckAuthStatus()),
      child: Builder(
        builder: (context) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // تحديد حجم التصميم بناءً على حجم الشاشة
              Size designSize;
              if (constraints.maxWidth < 600) {
                designSize = const Size(375, 812); // Mobile
              } else if (constraints.maxWidth < 1200) {
                designSize = const Size(768, 1024); // Tablet
              } else {
                designSize = const Size(1440, 900); // Desktop
              }

              return ScreenUtilInit(
                designSize: designSize,
                minTextAdapt: true,
                useInheritedMediaQuery: true,
                builder: (context, child) {
                  return MaterialApp(
                    navigatorKey: navigatorKey,
                    title: 'آشور - نظام إدارة المستخدمين',
                    debugShowCheckedModeBanner: false,

                    // إعدادات اللغة والاتجاه
                    locale: const Locale('ar', 'SA'),
                    supportedLocales: const [
                      Locale('ar', 'SA'),
                      Locale('en', 'US'),
                    ],
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      fl_localizations.GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],

                    // إعدادات الاتجاه
                    localeResolutionCallback: (locale, supportedLocales) {
                      return const Locale('ar', 'SA');
                    },

                    theme: AppTheme.lightTheme,
                    routes: AppRoutes.routes,
                    onGenerateRoute: AppRoutes.onGenerateRoute,
                    initialRoute: AppRoutes.splash,
                    onUnknownRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (context) => const StaticAuthWrapper(),
                        settings: settings,
                      );
                    },
                    builder: (context, widget) {
                      // تهيئة ResponsiveHelper
                      ResponsiveHelper.init(context);

                      final content = widget ?? const SizedBox();

                      // إضافة MediaQuery للتأكد من الاستجابة الصحيحة مع RTL
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(
                              ResponsiveHelper.isMobile(context)
                                  ? 1.0
                                  : ResponsiveHelper.isTablet(context)
                                  ? 1.1
                                  : 1.2,
                            ),
                          ),
                          child: ConnectionMonitor(child: content),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
