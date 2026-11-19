import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/assyrian_theme.dart';

/// ويدجت التحميل المعياري بتصميم آشوري
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    super.key,
    this.message,
    this.size,
    this.maxSize = 80,
  });
  final String? message;
  final double? size;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
            final maxHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 300.0;
            final maxSpinnerSize = min(maxWidth, maxHeight);
            final requestedSize = size ?? maxSpinnerSize;
            final effectiveMax = maxSpinnerSize < 24.0 ? 24.0 : maxSpinnerSize;
            final safeSize = requestedSize.clamp(24.0, effectiveMax);
            final cappedSize = safeSize > maxSize ? maxSize : safeSize;

            if (maxSpinnerSize < 24.0) {
              return FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: maxSpinnerSize * 0.6,
                  height: maxSpinnerSize * 0.6,
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AssyrianTheme.primaryGold,
                    ),
                    strokeWidth: 3.w,
                  ),
                ),
              );
            }

            if (message != null) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AssyrianTheme.primaryGold,
                      ),
                      strokeWidth: 3.w,
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      message!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AssyrianTheme.deepBlue,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    const Text(
                      'الرجاء الانتظار...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              width: cappedSize,
              height: cappedSize,
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AssyrianTheme.primaryGold,
                ),
                strokeWidth: 3.w,
              ),
            );
          },
        ),
      ),
    );
  }

  /// عرض نافذة تحميل بتصميم احترافي
  static void showLoadingDialog(
    BuildContext context, {
    required String message,
    String? subtitle,
    IconData icon = Icons.hourglass_empty,
    Color iconColor = Colors.blue,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(
                      (iconColor.r * 255).round(),
                      (iconColor.g * 255).round(),
                      (iconColor.b * 255).round(),
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(icon, color: iconColor, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: const BoxDecoration(
                    color: Color(0x1AFFD700),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0x4DFFD700), width: 2),
                    ),
                  ),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AssyrianTheme.primaryGold,
                      ),
                      strokeWidth: 4.w,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  subtitle ?? 'الرجاء الانتظار...',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
