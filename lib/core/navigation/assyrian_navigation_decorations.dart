import 'package:material_ui/material_ui.dart';
import '../theme/assyrian_theme.dart';

/// زخارف وعناصر التنقل الآشورية
// ignore: avoid_classes_with_only_static_members
class AssyrianNavigationDecorations {
  /// نقش آشوري مصغر للفواصل
  static Widget get assyrianDivider => Container(
    width: 2,
    height: 30,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          AssyrianTheme.primaryGold.withValues(alpha: 0.6),
          AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ),
      borderRadius: BorderRadius.circular(1),
    ),
  );

  /// نقش آشوري علوي للشريط
  static Widget get assyrianTopBorder => Container(
    height: 4,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          AssyrianTheme.primaryGold,
          AssyrianTheme.bronzeBrown,
          AssyrianTheme.primaryGold,
          AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ),
    ),
  );

  /// نمط آشوري للخلفية مع نقوش هندسية
  static Widget buildAssyrianBackground({
    required Widget child,
    double? height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AssyrianTheme.ivoryWhite,
            AssyrianTheme.ivoryWhite.withValues(alpha: 0.98),
            AssyrianTheme.primaryGold.withValues(alpha: 0.05),
          ],
        ),
        //   fit: BoxFit.cover,
        //   opacity: 0.03,
        // ),
      ),
      child: child,
    );
  }

  /// تأثير الضوء الآشوري للعناصر المحددة
  static BoxDecoration get assyrianGlow => BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      // توهج ذهبي داخلي
      BoxShadow(
        color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        blurRadius: 8,
        spreadRadius: -2,
      ),
      // توهج خارجي ناعم
      BoxShadow(
        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
        blurRadius: 15,
        offset: const Offset(0, 2),
        spreadRadius: 1,
      ),
    ],
  );

  /// نقش آشوري للزوايا
  static Widget buildCornerDecoration({
    required Alignment alignment,
    double size = 20,
  }) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// خط آشوري زخرفي
  static Widget get assyrianLine => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          AssyrianTheme.primaryGold.withValues(alpha: 0.5),
          AssyrianTheme.primaryGold,
          AssyrianTheme.primaryGold.withValues(alpha: 0.5),
          Colors.transparent,
        ],
      ),
    ),
  );

  /// نقطة آشورية زخرفية
  static Widget get assyrianDot => Container(
    width: 4,
    height: 4,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        colors: [AssyrianTheme.primaryGold, AssyrianTheme.bronzeBrown],
      ),
      boxShadow: [
        BoxShadow(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.5),
          blurRadius: 3,
          spreadRadius: 1,
        ),
      ],
    ),
  );

  /// نمط الحدود الآشورية المتقدم
  static BoxDecoration get advancedAssyrianBorder => BoxDecoration(
    border: Border.all(color: AssyrianTheme.primaryGold, width: 1.5),
    borderRadius: BorderRadius.circular(12),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AssyrianTheme.ivoryWhite,
        AssyrianTheme.ivoryWhite.withValues(alpha: 0.95),
        AssyrianTheme.primaryGold.withValues(alpha: 0.08),
      ],
    ),
    boxShadow: [
      // ظل ذهبي ناعم
      BoxShadow(
        color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
        blurRadius: 12,
        offset: const Offset(0, 4),
        spreadRadius: 1,
      ),
      // ظل داخلي للعمق
      BoxShadow(
        color: AssyrianTheme.deepBlue.withValues(alpha: 0.05),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
