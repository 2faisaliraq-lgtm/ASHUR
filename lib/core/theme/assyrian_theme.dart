import 'package:material_ui/material_ui.dart';

// ignore: avoid_classes_with_only_static_members
class AssyrianTheme {
  // الألوان الآشورية التقليدية
  static const Color primaryGold = Color(0xFFD4AF37); // الذهبي الآشوري
  static const Color deepBlue = Color(0xFF1B365D); // الأزرق العميق
  static const Color royalPurple = Color(0xFF4B0082); // البنفسجي الملكي
  static const Color crimsonRed = Color(0xFFDC143C); // الأحمر القرمزي
  static const Color ivoryWhite = Color(0xFFFFFFF0); // الأبيض العاجي
  static const Color bronzeBrown = Color(0xFFCD7F32); // البرونزي
  static const Color emeraldGreen = Color(0xFF50C878); // الأخضر الزمردي

  // تدرجات الألوان
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGold, bronzeBrown],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepBlue, Color(0xFF2C5F7C)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ivoryWhite, Color(0xFFF5F5DC)],
  );

  // ألوان النظام
  static const Color success = emeraldGreen;
  static const Color error = crimsonRed;
  static const Color warning = Color(0xFFFF9800);
  static const Color info = primaryGold;

  // ألوان النصوص
  static const Color textPrimary = deepBlue;
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);

  // ألوان الخلفيات
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFFAFAFA);

  // ألوان الحدود والفواصل
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // ظلال آشورية
  static List<BoxShadow> get assyrianShadow => [
    BoxShadow(
      color: primaryGold.withValues(alpha: 0.3),
      blurRadius: 15,
      offset: const Offset(0, 5),
      spreadRadius: 2,
    ),
    BoxShadow(
      color: deepBlue.withValues(alpha: 0.1),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get assyrianShadowRich => assyrianShadow;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      spreadRadius: 1,
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  // الحدود الآشورية
  static BoxDecoration get assyrianBorder => BoxDecoration(
    border: Border.all(color: primaryGold, width: 2),
    borderRadius: BorderRadius.circular(12),
    gradient: cardGradient,
    boxShadow: assyrianShadow,
  );

  // أنماط النصوص الآشورية مع دعم RTL
  static TextStyle get titleStyle => const TextStyle(
    fontFamily: 'Cairo', // خط عربي محسن
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: primaryGold,
    shadows: [Shadow(color: deepBlue, offset: Offset(2, 2), blurRadius: 4)],
  );

  static TextStyle get subtitleStyle => const TextStyle(
    fontFamily: 'Cairo',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: ivoryWhite,
  );

  static TextStyle get bodyStyle =>
      const TextStyle(fontFamily: 'Cairo', fontSize: 16, color: deepBlue);

  static TextStyle get buttonStyle => const TextStyle(
    fontFamily: 'Cairo',
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.black, // أسود
  );

  // أزرار آشورية
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: ivoryWhite,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(25),
      side: const BorderSide(color: primaryGold, width: 2),
    ),
  );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: primaryGold,
    side: const BorderSide(color: primaryGold, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
  );

  // حقول الإدخال الآشورية مع دعم RTL
  static InputDecoration getInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: deepBlue,
        fontFamily: 'Cairo',
        fontSize: 16,
      ),
      prefixIcon: Icon(icon, color: primaryGold, size: 24),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: primaryGold, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: bronzeBrown, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: primaryGold, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: crimsonRed, width: 2),
      ),
      filled: true,
      fillColor: ivoryWhite.withValues(alpha: 0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  // الزخارف الآشورية
  static Widget get assyrianPattern => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryGold.withValues(alpha: 0.02),
          deepBlue.withValues(alpha: 0.02),
          primaryGold.withValues(alpha: 0.02),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
    ),
  );

  // شعار الثور المجنح الآشوري الأصيل (استخدام الصورة مباشرة)
  static Widget get assyrianLamassu => Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: primaryGradient,
      boxShadow: assyrianShadow,
    ),
    child: ClipOval(
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/images/lamassu2.png',
          width: 64,
          height: 64,
          fit: BoxFit.contain,
          // بدون تلوين لإظهار الشعار بألوانه الأصلية
          errorBuilder: (context, error, stackTrace) {
            // في حالة عدم وجود الصورة، استخدم أيقونة بديلة
            return const Icon(
              Icons.account_balance,
              size: 40,
              color: ivoryWhite,
            );
          },
        ),
      ),
    ),
  );

  // شعار للخلفيات الفاتحة (مع تلوين ذهبي)
  static Widget get assyrianLamassuForLight => Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: primaryGradient,
      boxShadow: [
        BoxShadow(
          color: deepBlue.withValues(alpha: 0.3),
          blurRadius: 15,
          offset: const Offset(0, 5),
          spreadRadius: 2,
        ),
      ],
    ),
    child: ClipOval(
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/images/lamassu2.png',
          width: 64,
          height: 64,
          fit: BoxFit.contain,
          color: primaryGold, // تلوين ذهبي للخلفيات الفاتحة
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.account_balance,
              size: 40,
              color: primaryGold,
            );
          },
        ),
      ),
    ),
  );

  // شعار للخلفيات الداكنة (مع تلوين فاتح)
  static Widget get assyrianLamassuForDark => Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: primaryGradient,
      boxShadow: assyrianShadow,
    ),
    child: ClipOval(
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/images/lamassu2.png',
          width: 64,
          height: 64,
          fit: BoxFit.contain,
          color: ivoryWhite, // تلوين فاتح للخلفيات الداكنة
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.account_balance,
              size: 40,
              color: ivoryWhite,
            );
          },
        ),
      ),
    ),
  );

  // نسخة كبيرة من شعار الثور المجنح للصفحات الرئيسية
  static Widget get assyrianLamassuLarge => Container(
    width: 120,
    height: 120,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: primaryGradient,
      boxShadow: [
        BoxShadow(
          color: primaryGold.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 3,
        ),
        BoxShadow(
          color: deepBlue.withValues(alpha: 0.2),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ClipOval(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          'assets/images/lamassu2.png',
          width: 96,
          height: 96,
          fit: BoxFit.contain,
          // بدون تلوين لإظهار الشعار بألوانه الأصلية
          errorBuilder: (context, error, stackTrace) {
            // في حالة عدم وجود الصورة، استخدم أيقونة بديلة
            return const Icon(
              Icons.account_balance,
              size: 60,
              color: ivoryWhite,
            );
          },
        ),
      ),
    ),
  );

  // نسخة كبيرة للخلفيات الفاتحة
  static Widget get assyrianLamassuLargeForLight => Container(
    width: 120,
    height: 120,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [deepBlue, royalPurple],
      ),
      boxShadow: [
        BoxShadow(
          color: deepBlue.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 3,
        ),
      ],
    ),
    child: ClipOval(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          'assets/images/lamassu2.png',
          width: 96,
          height: 96,
          fit: BoxFit.contain,
          color: primaryGold, // تلوين ذهبي للخلفيات الفاتحة
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.account_balance,
              size: 60,
              color: primaryGold,
            );
          },
        ),
      ),
    ),
  );

  // نسخة كبيرة للخلفيات الداكنة
  static Widget get assyrianLamassuLargeForDark => Container(
    width: 120,
    height: 120,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: primaryGradient,
      boxShadow: [
        BoxShadow(
          color: primaryGold.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 3,
        ),
        BoxShadow(
          color: deepBlue.withValues(alpha: 0.2),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ClipOval(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          'assets/images/lamassu2.png',
          width: 96,
          height: 96,
          fit: BoxFit.contain,
          color: ivoryWhite, // تلوين فاتح للخلفيات الداكنة
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.account_balance,
              size: 60,
              color: ivoryWhite,
            );
          },
        ),
      ),
    ),
  );

  // للتوافق مع الكود الموجود - يشير الآن للثور المجنح
  static Widget get assyrianLion => assyrianLamassu;

  // شعار محسن لصفحات المصادقة - للخلفيات الداكنة (خلفية أصلية)
  static Widget get assyrianLamassuAuth => Container(
    width: 120,
    height: 120,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: primaryGradient, // الخلفية الأصلية الذهبية
      boxShadow: [
        BoxShadow(
          color: primaryGold.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 3,
        ),
        BoxShadow(
          color: deepBlue.withValues(alpha: 0.2),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ClipOval(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          'assets/images/lamassu2.png',
          width: 96,
          height: 96,
          fit: BoxFit.contain,
          color: ivoryWhite, // لون أبيض عاجي للشعار
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.account_balance,
              size: 60,
              color: ivoryWhite,
            );
          },
        ),
      ),
    ),
  );

  // شعار محسن لصفحات المصادقة - للخلفيات الفاتحة (خلفية أصلية)
  static Widget get assyrianLamassuAuthLight => Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: primaryGradient, // الخلفية الأصلية الذهبية
      boxShadow: assyrianShadow, // الظلال الأصلية
    ),
    child: ClipOval(
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/images/lamassu2.png',
          width: 64,
          height: 64,
          fit: BoxFit.contain,
          color: ivoryWhite, // لون أبيض عاجي للشعار
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.account_balance,
              size: 40,
              color: ivoryWhite,
            );
          },
        ),
      ),
    ),
  );
  // دالة مساعدة لاختيار الشعار المناسب حسب نوع الخلفية
  static Widget getLamassuForBackground({
    required bool isDarkBackground,
    bool isLarge = false,
    bool hasCircularBackground = true,
  }) {
    if (hasCircularBackground) {
      if (isLarge) {
        return isDarkBackground
            ? assyrianLamassuLargeForDark
            : assyrianLamassuLargeForLight;
      } else {
        return isDarkBackground
            ? assyrianLamassuForDark
            : assyrianLamassuForLight;
      }
    } else {
      if (isLarge) {
        return isDarkBackground
            ? assyrianLamassuPlainLargeForDark
            : assyrianLamassuPlainLargeForLight;
      } else {
        return isDarkBackground
            ? assyrianLamassuPlainForDark
            : assyrianLamassuPlainForLight;
      }
    }
  }

  // دالة محسنة خاصة لصفحات المصادقة
  static Widget getLamassuForAuth({
    required bool isDarkBackground,
    bool isLarge = true,
  }) {
    if (isDarkBackground) {
      return isLarge ? assyrianLamassuAuth : assyrianLamassuAuthLight;
    } else {
      return assyrianLamassuAuthLight;
    }
  }

  // شعار بسيط ومتناسق للمصادقة - بدون دائرة مع استخدام اللون الذهبي للشعار
  static Widget getSimpleLamassuForAuth({
    required bool isDarkBackground,
    bool isLarge = true,
    bool isLandscape = false, // إضافة معامل للشاشة الأفقية
  }) {
    double size;
    if (isLandscape && isLarge) {
      size = 2400.0; // تكبير أكثر للشاشة الأفقية (800 × 3)
    } else {
      size = isLarge ? 800.0 : 500.0;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/lamassu2.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: primaryGold, // استخدام اللون الذهبي (لون الدائرة السابق) للشعار
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.account_balance,
            size: size * 0.6,
            color: primaryGold, // استخدام اللون الذهبي للأيقونة البديلة أيضاً
          );
        },
      ),
    );
  }

  // شعار الثور المجنح بدون خلفية دائرية (للاستخدام في الأماكن التي تحتاج شفافية)
  static Widget get assyrianLamassuPlain => Image.asset(
    'assets/images/lamassu2.png',
    width: 80,
    height: 80,
    fit: BoxFit.contain,
    // بدون تلوين لإظهار الألوان الأصلية
    errorBuilder: (context, error, stackTrace) {
      return const Icon(Icons.account_balance, size: 40, color: primaryGold);
    },
  );

  // شعار بدون خلفية للخلفيات الفاتحة
  static Widget get assyrianLamassuPlainForLight => RepaintBoundary(
    child: Image.asset(
      'assets/images/lamassu2.png',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      color: primaryGold,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.account_balance, size: 40, color: deepBlue);
      },
    ),
  );

  // شعار بدون خلفية للخلفيات الداكنة
  static Widget get assyrianLamassuPlainForDark => RepaintBoundary(
    child: Image.asset(
      'assets/images/lamassu2.png',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      color: primaryGold,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.account_balance, size: 40, color: primaryGold);
      },
    ),
  );

  // نسخة كبيرة من الشعار بدون خلفية دائرية
  static Widget get assyrianLamassuPlainLarge => RepaintBoundary(
    child: Image.asset(
      'assets/images/lamassu2.png',
      width: 120,
      height: 120,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.account_balance, size: 60, color: primaryGold);
      },
    ),
  );

  // نسخة كبيرة بدون خلفية للخلفيات الفاتحة
  static Widget get assyrianLamassuPlainLargeForLight => RepaintBoundary(
    child: Image.asset(
      'assets/images/lamassu2.png',
      width: 120,
      height: 120,
      fit: BoxFit.contain,
      color: deepBlue,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.account_balance, size: 60, color: deepBlue);
      },
    ),
  );

  // نسخة كبيرة بدون خلفية للخلفيات الداكنة
  static Widget get assyrianLamassuPlainLargeForDark => RepaintBoundary(
    child: Image.asset(
      'assets/images/lamassu2.png',
      width: 120,
      height: 120,
      fit: BoxFit.contain,
      color: primaryGold,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.account_balance, size: 60, color: primaryGold);
      },
    ),
  );

  // بطاقة آشورية
  static Widget assyrianCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: assyrianBorder,
      child: child,
    );
  }

  // خلفية آشورية
  static Widget assyrianBackground({required Widget child}) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: backgroundGradient),
      child: Stack(children: [assyrianPattern, child]),
    );
  }
}
