import 'package:material_ui/material_ui.dart';

import '../../core/theme/assyrian_theme.dart';

/// ثيم التطبيق مع دعم RTL والنمط الآشوري
// ignore: avoid_classes_with_only_static_members
class AppTheme {
  static const Color primaryColor = AssyrianTheme.primaryGold;

  /// الثيم الفاتح مع دعم RTL والنمط الآشوري
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: _createMaterialColor(primaryColor),
      primaryColor: primaryColor,
      fontFamily: 'Cairo',

      // خلفية التطبيق بلون أبيض نظيف
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,

      // ألوان مخصصة آشورية مع خلفية بيضاء
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: AssyrianTheme.primaryGold,
        secondary: AssyrianTheme.bronzeBrown,
        surface: Colors.white,
        onPrimary: AssyrianTheme.deepBlue,
        onSecondary: AssyrianTheme.ivoryWhite,
        onSurface: AssyrianTheme.deepBlue,
      ),

      // تخصيص AppBar مع النمط الآشوري
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AssyrianTheme.primaryGold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
          color: AssyrianTheme.primaryGold,
        ),
        iconTheme: IconThemeData(color: AssyrianTheme.primaryGold),
      ),

      // تخصيص الأزرار مع النمط الآشوري
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AssyrianTheme.primaryGold,
          foregroundColor: AssyrianTheme.deepBlue,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // تخصيص TextButton مع النمط الآشوري
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AssyrianTheme.deepBlue, // ✅ لون النص أزرق عميق
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // تخصيص OutlinedButton مع النمط الآشوري
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AssyrianTheme.deepBlue,
          side: const BorderSide(color: AssyrianTheme.deepBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // تخصيص الكروت مع النمط الآشوري
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white, // ✅ أبيض نقي للخلفية
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // تخصيص حقول الإدخال مع دعم RTL
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
        hintStyle: const TextStyle(fontFamily: 'Cairo'),
      ),

      // تخصيص النصوص مع دعم RTL
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Cairo'),
        displayMedium: TextStyle(fontFamily: 'Cairo'),
        displaySmall: TextStyle(fontFamily: 'Cairo'),
        headlineLarge: TextStyle(fontFamily: 'Cairo'),
        headlineMedium: TextStyle(fontFamily: 'Cairo'),
        headlineSmall: TextStyle(fontFamily: 'Cairo'),
        titleLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        titleMedium: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontFamily: 'Cairo'),
        bodyMedium: TextStyle(fontFamily: 'Cairo'),
        bodySmall: TextStyle(fontFamily: 'Cairo'),
        labelLarge: TextStyle(fontFamily: 'Cairo'),
        labelMedium: TextStyle(fontFamily: 'Cairo'),
        labelSmall: TextStyle(fontFamily: 'Cairo'),
      ),

      // تخصيص ListTile مع دعم RTL
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
          color: AssyrianTheme.deepBlue, // ✅ لون العنوان أزرق عميق
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AssyrianTheme.deepBlue, // ✅ لون الوصف أزرق عميق
        ),
      ),

      // تخصيص الـ Drawer مع دعم RTL
      drawerTheme: const DrawerThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
      ),

      // تخصيص الـ Dialog مع دعم RTL
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: AssyrianTheme.deepBlue, // ✅ لون العنوان أزرق عميق
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AssyrianTheme.deepBlue, // ✅ لون المحتوى أزرق عميق
        ),
      ),

      // تخصيص الـ BottomSheet مع دعم RTL
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // تخصيص الـ SnackBar مع دعم RTL
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white, // ✅ لون النص أبيض للـ SnackBar
        ),
      ),
    );
  }

  /// إنشاء MaterialColor من لون واحد
  static MaterialColor _createMaterialColor(Color color) {
    final colorValue =
        (color.a * 255).round() << 24 |
        (color.r * 255).round() << 16 |
        (color.g * 255).round() << 8 |
        (color.b * 255).round();

    return MaterialColor(colorValue, <int, Color>{
      50: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        .1,
      ),
      100: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        .2,
      ),
      200: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        .3,
      ),
      300: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        .4,
      ),
      400: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        .5,
      ),
      500: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        .6,
      ),
      600: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        .7,
      ),
      700: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        .8,
      ),
      800: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        .9,
      ),
      900: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        1,
      ),
    });
  }
}
