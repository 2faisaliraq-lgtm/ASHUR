import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum DeviceType { mobile, tablet, desktop, tv }

enum ScreenSize { small, medium, large, extraLarge }

/// مساعد الاستجابة لأنواع الشاشات المختلفة
// ignore: avoid_classes_with_only_static_members
class ResponsiveHelper {
  static void init(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;

    // تحديد حجم التصميم بناءً على نوع الجهاز
    Size designSize;
    if (shortestSide < 600) {
      designSize = const Size(375, 812); // Mobile
    } else if (shortestSide < 900) {
      designSize = const Size(768, 1024); // Tablet
    } else {
      designSize = const Size(1440, 900); // Desktop
    }

    ScreenUtil.init(
      context,
      designSize: designSize,
      minTextAdapt: true,
      splitScreenMode: true,
    );
  }

  // Screen size helpers - محسنة لجميع الأحجام
  static bool isMobile(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide < 600;
  }

  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    return shortestSide >= 600 && shortestSide < 900;
  }

  static bool isDesktop(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 900;
  }

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 480;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 1200;
  }

  static bool isTV(BuildContext context) {
    return MediaQuery.of(context).size.width > 1920;
  }

  // تحديد نوع الجهاز
  static DeviceType getDeviceType(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;

    if (size.width > 1920) return DeviceType.tv;
    if (shortestSide >= 900) return DeviceType.desktop;
    if (shortestSide >= 600) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  // تحديد حجم الشاشة
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 480) return ScreenSize.small;
    if (width < 768) return ScreenSize.medium;
    if (width < 1200) return ScreenSize.large;
    return ScreenSize.extraLarge;
  }

  // Responsive values - محسنة لجميع الأحجام
  static double getResponsiveWidth(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? tv,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.tv:
        return tv ?? desktop ?? tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }

  static double getResponsiveHeight(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? tv,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.tv:
        return tv ?? desktop ?? tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }

  // Responsive padding - محسنة لجميع الأحجام
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      // قيم ثابتة للوضع الأفقي لتجنب مشاكل ScreenUtil
      switch (deviceType) {
        case DeviceType.tv:
          return const EdgeInsets.symmetric(horizontal: 64, vertical: 24);
        case DeviceType.desktop:
          return const EdgeInsets.symmetric(horizontal: 48, vertical: 20);
        case DeviceType.tablet:
          return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
        case DeviceType.mobile:
          return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      }
    } else {
      // قيم متجاوبة للوضع العمودي
      switch (deviceType) {
        case DeviceType.tv:
          return EdgeInsets.symmetric(horizontal: 48.w, vertical: 40.h);
        case DeviceType.desktop:
          return EdgeInsets.symmetric(horizontal: 32.w, vertical: 32.h);
        case DeviceType.tablet:
          return EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h);
        case DeviceType.mobile:
          return EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h);
      }
    }
  }

  // Responsive font sizes - محسنة لجميع الأحجام
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? tv,
  }) {
    final deviceType = getDeviceType(context);
    double fontSize;

    switch (deviceType) {
      case DeviceType.tv:
        fontSize = tv ?? desktop ?? tablet ?? mobile;
        break;
      case DeviceType.desktop:
        fontSize = desktop ?? tablet ?? mobile;
        break;
      case DeviceType.tablet:
        fontSize = tablet ?? mobile;
        break;
      case DeviceType.mobile:
        fontSize = mobile;
        break;
    }

    return fontSize.sp;
  }

  // Grid columns based on screen size - محسنة لجميع الأحجام
  static int getGridColumns(BuildContext context) {
    final deviceType = getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;

    switch (deviceType) {
      case DeviceType.tv:
        return orientation == Orientation.landscape ? 6 : 4;
      case DeviceType.desktop:
        return orientation == Orientation.landscape ? 5 : 4;
      case DeviceType.tablet:
        return orientation == Orientation.landscape ? 4 : 3;
      case DeviceType.mobile:
        return orientation == Orientation.landscape ? 3 : 2;
    }
  }

  // Responsive layout builder - محسن لجميع الأحجام
  static Widget responsiveBuilder({
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
    Widget? tv,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = getDeviceType(context);

        switch (deviceType) {
          case DeviceType.tv:
            return tv ?? desktop ?? tablet ?? mobile;
          case DeviceType.desktop:
            return desktop ?? tablet ?? mobile;
          case DeviceType.tablet:
            return tablet ?? mobile;
          case DeviceType.mobile:
            return mobile;
        }
      },
    );
  }

  // Orientation-aware responsive builder
  static Widget orientationResponsiveBuilder({
    required Widget portraitMobile,
    required Widget landscapeMobile,
    Widget? portraitTablet,
    Widget? landscapeTablet,
    Widget? portraitDesktop,
    Widget? landscapeDesktop,
    Widget? portraitTV,
    Widget? landscapeTV,
  }) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final deviceType = getDeviceType(context);
        final isLandscape = orientation == Orientation.landscape;

        switch (deviceType) {
          case DeviceType.tv:
            return isLandscape
                ? (landscapeTV ??
                      landscapeDesktop ??
                      landscapeTablet ??
                      landscapeMobile)
                : (portraitTV ??
                      portraitDesktop ??
                      portraitTablet ??
                      portraitMobile);
          case DeviceType.desktop:
            return isLandscape
                ? (landscapeDesktop ?? landscapeTablet ?? landscapeMobile)
                : (portraitDesktop ?? portraitTablet ?? portraitMobile);
          case DeviceType.tablet:
            return isLandscape
                ? (landscapeTablet ?? landscapeMobile)
                : (portraitTablet ?? portraitMobile);
          case DeviceType.mobile:
            return isLandscape ? landscapeMobile : portraitMobile;
        }
      },
    );
  }

  // Safe area padding - محسن لجميع الأجهزة
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final deviceType = getDeviceType(context);

    // للأجهزة الكبيرة، قلل من padding الجانبي
    var horizontalMultiplier =
        deviceType == DeviceType.desktop || deviceType == DeviceType.tv
        ? 0.5
        : 1.0;

    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left * horizontalMultiplier,
      right: mediaQuery.padding.right * horizontalMultiplier,
    );
  }

  // Keyboard padding - محسن لجميع الأجهزة
  static EdgeInsets getKeyboardPadding(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final deviceType = getDeviceType(context);

    // للأجهزة الكبيرة، قلل من تأثير الكيبورد
    var keyboardMultiplier =
        deviceType == DeviceType.desktop || deviceType == DeviceType.tv
        ? 0.3
        : 1.0;

    return EdgeInsets.only(bottom: viewInsets.bottom * keyboardMultiplier);
  }

  // تحديد الحد الأقصى لعرض المحتوى
  static double getMaxContentWidth(BuildContext context) {
    final deviceType = getDeviceType(context);
    final screenWidth = MediaQuery.of(context).size.width;

    switch (deviceType) {
      case DeviceType.tv:
        return screenWidth * 0.7; // 70% من عرض الشاشة للتلفزيون
      case DeviceType.desktop:
        return screenWidth * 0.8; // 80% من عرض الشاشة للسطح المكتب
      case DeviceType.tablet:
        return screenWidth * 0.9; // 90% من عرض الشاشة للتابلت
      case DeviceType.mobile:
        return screenWidth; // العرض الكامل للموبايل
    }
  }

  // تحديد نسبة العرض إلى الارتفاع المناسبة للكروت
  static double getCardAspectRatio(BuildContext context) {
    final deviceType = getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      switch (deviceType) {
        case DeviceType.tv:
          return 2.5;
        case DeviceType.desktop:
          return 2;
        case DeviceType.tablet:
          return 1.8;
        case DeviceType.mobile:
          return 1.6;
      }
    } else {
      switch (deviceType) {
        case DeviceType.tv:
          return 1.8;
        case DeviceType.desktop:
          return 1.5;
        case DeviceType.tablet:
          return 1.3;
        case DeviceType.mobile:
          return 1.2;
      }
    }
  }

  // تحديد حجم الخط للآب بار بناءً على الاتجاه
  static double getAppBarFontSize(
    BuildContext context, {
    required double portraitSize,
    double? landscapeSize,
  }) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      // في الوضع الأفقي، استخدم حجم أصغر قليلاً لتجنب الفيض
      final calculatedSize = landscapeSize ?? (portraitSize * 0.8);
      return calculatedSize.sp;
    } else {
      // في الوضع العمودي، استخدم الحجم العادي
      return getResponsiveFontSize(context, mobile: portraitSize);
    }
  }

  // تحديد المسافات بين العناصر
  static double getSpacing(BuildContext context, {double baseSpacing = 16}) {
    final deviceType = getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      // قيم ثابتة للوضع الأفقي
      switch (deviceType) {
        case DeviceType.tv:
          return baseSpacing * 2.0;
        case DeviceType.desktop:
          return baseSpacing * 1.5;
        case DeviceType.tablet:
          return baseSpacing * 1.2;
        case DeviceType.mobile:
          return baseSpacing;
      }
    } else {
      // قيم متجاوبة للوضع العمودي
      switch (deviceType) {
        case DeviceType.tv:
          return (baseSpacing * 2.0).w;
        case DeviceType.desktop:
          return (baseSpacing * 1.5).w;
        case DeviceType.tablet:
          return (baseSpacing * 1.2).w;
        case DeviceType.mobile:
          return baseSpacing.w;
      }
    }
  }

  // تحديد ارتفاع الأزرار
  static double getButtonHeight(BuildContext context) {
    final deviceType = getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    final screenHeight = MediaQuery.of(context).size.height;

    if (isLandscape) {
      // استخدم نسبة من ارتفاع الشاشة للوضع الأفقي
      double height;
      switch (deviceType) {
        case DeviceType.tv:
          height = screenHeight * 0.08; // 8% من ارتفاع الشاشة
          break;
        case DeviceType.desktop:
          height = screenHeight * 0.07; // 7% من ارتفاع الشاشة
          break;
        case DeviceType.tablet:
          height = screenHeight * 0.06; // 6% من ارتفاع الشاشة
          break;
        case DeviceType.mobile:
          height = screenHeight * 0.05; // 5% من ارتفاع الشاشة
          break;
      }
      // تأكد من أن الارتفاع لا يقل عن حد أدنى
      return height.clamp(40.0, 80.0);
    } else {
      // قيم متجاوبة للوضع العمودي
      switch (deviceType) {
        case DeviceType.tv:
          return 64.h;
        case DeviceType.desktop:
          return 56.h;
        case DeviceType.tablet:
          return 52.h;
        case DeviceType.mobile:
          return 48.h;
      }
    }
  }

  // تحديد نصف قطر الحواف
  static double getBorderRadius(
    BuildContext context, {
    double baseRadius = 12,
  }) {
    final deviceType = getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      // قيم ثابتة للوضع الأفقي
      switch (deviceType) {
        case DeviceType.tv:
          return baseRadius * 1.5;
        case DeviceType.desktop:
          return baseRadius * 1.3;
        case DeviceType.tablet:
          return baseRadius * 1.1;
        case DeviceType.mobile:
          return baseRadius;
      }
    } else {
      // قيم متجاوبة للوضع العمودي
      switch (deviceType) {
        case DeviceType.tv:
          return (baseRadius * 1.5).r;
        case DeviceType.desktop:
          return (baseRadius * 1.3).r;
        case DeviceType.tablet:
          return (baseRadius * 1.1).r;
        case DeviceType.mobile:
          return baseRadius.r;
      }
    }
  }

  // تحديد حجم الأيقونات
  static double getIconSize(BuildContext context, {double baseSize = 24}) {
    final deviceType = getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      // قيم ثابتة للوضع الأفقي
      switch (deviceType) {
        case DeviceType.tv:
          return baseSize * 1.8;
        case DeviceType.desktop:
          return baseSize * 1.4;
        case DeviceType.tablet:
          return baseSize * 1.2;
        case DeviceType.mobile:
          return baseSize;
      }
    } else {
      // قيم متجاوبة للوضع العمودي
      switch (deviceType) {
        case DeviceType.tv:
          return (baseSize * 1.8).sp;
        case DeviceType.desktop:
          return (baseSize * 1.4).sp;
        case DeviceType.tablet:
          return (baseSize * 1.2).sp;
        case DeviceType.mobile:
          return baseSize.sp;
      }
    }
  }

  // إدارة الاتجاهات المدعومة - قفل على الوضع العمودي فقط
  static void setPreferredOrientations(BuildContext context) {
    // جميع الأجهزة تستخدم الوضع العمودي فقط
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
}

// Custom responsive widgets
class ResponsiveText extends StatelessWidget {
  const ResponsiveText(
    this.text, {
    required this.mobileFontSize,
    super.key,
    this.tabletFontSize,
    this.desktopFontSize,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final double mobileFontSize;
  final double? tabletFontSize;
  final double? desktopFontSize;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: ResponsiveHelper.getResponsiveFontSize(
          context,
          mobile: mobileFontSize,
          tablet: tabletFontSize,
          desktop: desktopFontSize,
        ),
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    required this.child,
    super.key,
    this.mobileWidth,
    this.tabletWidth,
    this.desktopWidth,
    this.mobileHeight,
    this.tabletHeight,
    this.desktopHeight,
    this.padding,
    this.margin,
    this.decoration,
  });
  final Widget child;
  final double? mobileWidth;
  final double? tabletWidth;
  final double? desktopWidth;
  final double? mobileHeight;
  final double? tabletHeight;
  final double? desktopHeight;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: mobileWidth != null
          ? ResponsiveHelper.getResponsiveWidth(
              context,
              mobile: mobileWidth!,
              tablet: tabletWidth,
              desktop: desktopWidth,
            )
          : null,
      height: mobileHeight != null
          ? ResponsiveHelper.getResponsiveHeight(
              context,
              mobile: mobileHeight!,
              tablet: tabletHeight,
              desktop: desktopHeight,
            )
          : null,
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );
  }
}
