import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// تأثيرات التنقل الآشورية
// ignore: avoid_classes_with_only_static_members
class AssyrianNavigationEffects {
  /// تأثير الاهتزاز عند النقر
  static void playHapticFeedback() {
    HapticFeedback.lightImpact();
  }

  /// تأثير الاهتزاز القوي للعنصر المحدد
  static void playSelectionHaptic() {
    HapticFeedback.selectionClick();
  }

  /// تأثير صوتي للنقر
  static void playClickSound() {
    SystemSound.play(SystemSoundType.click);
  }

  /// تأثير الانتقال السلس بين الصفحات
  static PageRouteBuilder<T> createAssyrianPageTransition<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // تأثير انزلاق آشوري مع تلاشي
        const begin = Offset(1, 0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        var offsetAnimation = animation.drive(tween);
        var fadeAnimation = Tween<double>(
          begin: 0,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: curve));

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
    );
  }

  /// تأثير النبضة للعنصر المحدد
  static Widget createPulseEffect({
    required Widget child,
    required bool isActive,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    if (!isActive) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      builder: (context, value, child) {
        final pulseValue = 1.0 + 0.1 * (1.0 - (value * 2 - 1).abs());
        return Transform.scale(scale: pulseValue, child: child);
      },
      child: child,
    );
  }

  /// تأثير التوهج للعنصر المحدد
  static Widget createGlowEffect({
    required Widget child,
    required bool isActive,
    required Color glowColor,
  }) {
    if (!isActive) return child;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.1),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }

  /// تأثير الموجة عند النقر
  static Widget createRippleEffect({
    required Widget child,
    required VoidCallback onTap,
    Color? rippleColor,
  }) {
    final splashColor =
        rippleColor?.withValues(alpha: 0.2) ?? const Color(0x33FFD700);
    final highlightColor =
        rippleColor?.withValues(alpha: 0.1) ?? const Color(0x1AFFD700);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          playHapticFeedback();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: splashColor,
        highlightColor: highlightColor,
        child: child,
      ),
    );
  }

  /// تأثير الانتقال المتدرج للألوان
  static AnimatedContainer createColorTransition({
    required Widget child,
    required bool isSelected,
    required Color selectedColor,
    required Color unselectedColor,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? selectedColor : unselectedColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  /// تأثير الدوران الناعم للأيقونات
  static Widget createRotationEffect({
    required Widget child,
    required bool isActive,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return AnimatedRotation(
      turns: isActive ? 0.05 : 0.0, // دوران خفيف 18 درجة
      duration: duration,
      curve: Curves.easeInOutCubic,
      child: child,
    );
  }

  /// تأثير الارتداد عند النقر
  static Widget createBounceEffect({
    required Widget child,
    required bool isPressed,
  }) {
    return AnimatedScale(
      scale: isPressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: child,
    );
  }
}
