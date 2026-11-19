import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'responsive_helper.dart' as helper;

class ResponsiveScaffold extends StatefulWidget {
  const ResponsiveScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset =
        true, // تم التغيير إلى true لمنع إعادة التحميل
    this.padding,
    this.enableSafeArea = true,
    this.forceShowDrawer = false, // خاصية جديدة لإجبار إظهار الـ drawer
  });

  // Constructor مخصص يتجاهل شروط الجهاز ويظهر الـ drawer دائماً
  const ResponsiveScaffold.withDrawer({
    required this.body,
    required Widget this.drawer,
    super.key,
    this.appBar,
    this.endDrawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset =
        true, // تم التغيير إلى true لمنع إعادة التحميل
    this.padding,
    this.enableSafeArea = true,
  }) : forceShowDrawer = true;
  final Widget? appBar;
  final Widget body;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;
  final EdgeInsets? padding;
  final bool enableSafeArea;
  final bool forceShowDrawer;

  @override
  State<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends State<ResponsiveScaffold> {
  @override
  Widget build(BuildContext context) {
    helper.ResponsiveHelper.setPreferredOrientations(context);

    final deviceType = helper.ResponsiveHelper.getDeviceType(context);
    final maxContentWidth = helper.ResponsiveHelper.getMaxContentWidth(context);
    final responsivePadding =
        widget.padding ?? helper.ResponsiveHelper.getResponsivePadding(context);

    var scaffoldBody = widget.body;

    // للأجهزة الكبيرة، اجعل المحتوى في المنتصف مع حد أقصى للعرض
    if (deviceType == helper.DeviceType.desktop ||
        deviceType == helper.DeviceType.tv) {
      scaffoldBody = Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: widget.body,
        ),
      );
    }

    // إضافة padding متجاوب
    scaffoldBody = Padding(padding: responsivePadding, child: scaffoldBody);

    // إضافة Safe Area إذا كان مطلوباً
    if (widget.enableSafeArea) {
      scaffoldBody = SafeArea(child: scaffoldBody);
    }

    // استخدام RepaintBoundary لعزل الـ drawer عن إعادة البناء
    final drawerWidget = widget.drawer != null
        ? RepaintBoundary(child: _buildResponsiveDrawer(context))
        : null;

    // استخدام RepaintBoundary للـ body أيضاً لمنع إعادة البناء
    final bodyWidget = RepaintBoundary(child: scaffoldBody);

    return Scaffold(
      appBar: widget.appBar != null ? _buildResponsiveAppBar(context) : null,
      body: bodyWidget,
      drawer: drawerWidget,
      endDrawer: widget.endDrawer,
      bottomNavigationBar: widget.bottomNavigationBar != null
          ? _buildResponsiveBottomNav(context)
          : null,
      floatingActionButton: widget.floatingActionButton != null
          ? _buildResponsiveFloatingActionButton(context)
          : null,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      backgroundColor: widget.backgroundColor,
      extendBody: widget.extendBody,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
    );
  }

  PreferredSizeWidget? _buildResponsiveAppBar(BuildContext context) {
    if (widget.appBar == null) return null;

    final deviceType = helper.ResponsiveHelper.getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    final screenHeight = MediaQuery.of(context).size.height;

    double height;
    if (isLandscape) {
      switch (deviceType) {
        case helper.DeviceType.tv:
          height = screenHeight * 0.12;
          break;
        case helper.DeviceType.desktop:
          height = screenHeight * 0.11;
          break;
        case helper.DeviceType.tablet:
          height = screenHeight * 0.10;
          break;
        case helper.DeviceType.mobile:
          height = screenHeight * 0.09;
          break;
      }
      height = height.clamp(60.0, 90.0);
    } else {
      switch (deviceType) {
        case helper.DeviceType.tv:
          height = 80.h;
          break;
        case helper.DeviceType.desktop:
          height = 70.h;
          break;
        case helper.DeviceType.tablet:
          height = 60.h;
          break;
        case helper.DeviceType.mobile:
          height = 56.h;
          break;
      }
    }

    return PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: widget.appBar!,
    );
  }

  Widget? _buildResponsiveDrawer(BuildContext context) {
    if (widget.drawer == null) return null;

    final deviceType = helper.ResponsiveHelper.getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // تحديد عرض الـ Drawer بناءً على نوع الجهاز والاتجاه
    double width;
    if (isLandscape) {
      // في الوضع الأفقي، استخدم قيم ثابتة
      switch (deviceType) {
        case helper.DeviceType.tv:
          width = 380.0;
          break;
        case helper.DeviceType.desktop:
          width = 320.0;
          break;
        case helper.DeviceType.tablet:
          width = 300.0;
          break;
        case helper.DeviceType.mobile:
          width = 280.0;
          break;
      }
    } else {
      // في الوضع العمودي، استخدم ScreenUtil
      switch (deviceType) {
        case helper.DeviceType.tv:
          width = 400.w;
          break;
        case helper.DeviceType.desktop:
          width = 350.w;
          break;
        case helper.DeviceType.tablet:
          width = 320.w;
          break;
        case helper.DeviceType.mobile:
          width = 280.w;
          break;
      }
    }

    return SizedBox(width: width, child: widget.drawer);
  }

  Widget? _buildResponsiveBottomNav(BuildContext context) {
    if (widget.bottomNavigationBar == null) return null;

    final deviceType = helper.ResponsiveHelper.getDeviceType(context);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // للأجهزة الكبيرة، قد نريد إخفاء Bottom Navigation أو تعديله
    if (deviceType == helper.DeviceType.desktop ||
        deviceType == helper.DeviceType.tv) {
      double height;
      if (isLandscape) {
        // قيمة ثابتة للوضع الأفقي
        height = helper.ResponsiveHelper.getButtonHeight(context) + 20.0;
      } else {
        height = helper.ResponsiveHelper.getButtonHeight(context) + 20.h;
      }

      return SizedBox(height: height, child: widget.bottomNavigationBar);
    }

    return widget.bottomNavigationBar;
  }

  Widget? _buildResponsiveFloatingActionButton(BuildContext context) {
    if (widget.floatingActionButton == null) return null;

    final deviceType = helper.ResponsiveHelper.getDeviceType(context);

    // للأجهزة الكبيرة، اجعل FAB أكبر
    double scale;
    switch (deviceType) {
      case helper.DeviceType.tv:
        scale = 1.5;
        break;
      case helper.DeviceType.desktop:
        scale = 1.3;
        break;
      case helper.DeviceType.tablet:
        scale = 1.1;
        break;
      case helper.DeviceType.mobile:
        scale = 1.0;
        break;
    }

    // إضافة heroTag فريد إذا لم يكن موجوداً
    Widget fabWithUniqueTag;
    if (widget.floatingActionButton is FloatingActionButton) {
      final fab = widget.floatingActionButton as FloatingActionButton;
      fabWithUniqueTag = FloatingActionButton(
        heroTag: fab.heroTag ?? 'fab_${DateTime.now().millisecondsSinceEpoch}',
        onPressed: fab.onPressed,
        backgroundColor: fab.backgroundColor,
        foregroundColor: fab.foregroundColor,
        elevation: fab.elevation,
        highlightElevation: fab.highlightElevation,
        tooltip: fab.tooltip,
        mini: fab.mini,
        shape: fab.shape,
        clipBehavior: fab.clipBehavior,
        focusColor: fab.focusColor,
        hoverColor: fab.hoverColor,
        splashColor: fab.splashColor,
        child: fab.child,
      );
    } else {
      fabWithUniqueTag = widget.floatingActionButton!;
    }

    return Transform.scale(scale: scale, child: fabWithUniqueTag);
  }
}

// ويدجت مساعد للمحتوى المتجاوب
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.decoration,
    this.alignment,
  });
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final deviceType = helper.ResponsiveHelper.getDeviceType(context);
    final maxWidth = helper.ResponsiveHelper.getMaxContentWidth(context);

    return Container(
      width: width,
      height: height,
      constraints: BoxConstraints(
        maxWidth: deviceType == helper.DeviceType.mobile
            ? double.infinity
            : maxWidth,
      ),
      padding: padding ?? helper.ResponsiveHelper.getResponsivePadding(context),
      margin: margin,
      decoration: decoration,
      alignment: alignment,
      child: child,
    );
  }
}

// ويدجت للنصوص المتجاوبة
class ResponsiveText extends StatelessWidget {
  const ResponsiveText(
    this.text, {
    required this.mobileFontSize,
    super.key,
    this.tabletFontSize,
    this.desktopFontSize,
    this.tvFontSize,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final double mobileFontSize;
  final double? tabletFontSize;
  final double? desktopFontSize;
  final double? tvFontSize;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final fontSize = helper.ResponsiveHelper.getResponsiveFontSize(
      context,
      mobile: mobileFontSize,
      tablet: tabletFontSize,
      desktop: desktopFontSize,
      tv: tvFontSize,
    );

    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

// ويدجت للأزرار المتجاوبة
class ResponsiveButton extends StatelessWidget {
  const ResponsiveButton({
    required this.child,
    super.key,
    this.onPressed,
    this.style,
    this.isPrimary = true,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final buttonHeight = helper.ResponsiveHelper.getButtonHeight(context);
    final borderRadius = helper.ResponsiveHelper.getBorderRadius(context);

    final buttonStyle =
        (style ??
                (isPrimary
                    ? ElevatedButton.styleFrom()
                    : OutlinedButton.styleFrom()))
            .copyWith(
              minimumSize: WidgetStateProperty.all(
                Size(double.infinity, buttonHeight),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
            );

    if (isPrimary) {
      return ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: child,
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: child,
      );
    }
  }
}

// ويدجت للكروت المتجاوبة
class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? elevation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = helper.ResponsiveHelper.getBorderRadius(context);
    final responsivePadding =
        padding ?? helper.ResponsiveHelper.getResponsivePadding(context);

    return Card(
      color: color,
      elevation: elevation,
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(padding: responsivePadding, child: child),
      ),
    );
  }
}
