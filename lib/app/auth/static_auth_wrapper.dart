import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/splash/splash_screen.dart';

/// Static AuthWrapper - يعرض SplashScreen فقط
/// SplashScreen الآن تقوم بجميع عمليات التحقق
class StaticAuthWrapper extends StatefulWidget {
  const StaticAuthWrapper({super.key});

  @override
  State<StaticAuthWrapper> createState() => _StaticAuthWrapperState();
}

class _StaticAuthWrapperState extends State<StaticAuthWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          String cleanMessage = state.message
              .replaceAll('Exception:', '')
              .replaceAll('Instance of \'Exception\'', '')
              .replaceAll('Instance of "Exception"', '')
              .trim();

          final errorMessage = cleanMessage.isNotEmpty
              ? cleanMessage
              : 'حدث خطأ غير متوقع';

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                duration: const Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                action: SnackBarAction(
                  label: 'حسناً',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          // عرض SplashScreen - هي ستقوم بكل التحقق
          return const SplashScreen();
        },
      ),
    );
  }
}
