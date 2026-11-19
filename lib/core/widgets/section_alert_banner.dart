import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ويدجت موحد ومرن لعرض شريط التنبيهات العاجلة والتحذيرات أعلى صفحات الأقسام
class SectionAlertBanner extends StatelessWidget {
  const SectionAlertBanner({
    super.key,
    required this.title,
    required this.message,
    required this.count,
    required this.urgencyType,
    this.actionChips,
    this.onDismiss,
  });

  final String title;
  final String message;
  final int count;
  final String urgencyType; // 'critical', 'warning', 'info'
  final List<Widget>? actionChips;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final isCritical = urgencyType == 'critical';
    final isWarning = urgencyType == 'warning';
    final MaterialColor themeColor = isCritical
        ? Colors.red
        : isWarning
            ? Colors.orange
            : Colors.blue;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCritical
                      ? Icons.error_outline
                      : isWarning
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline,
                  color: themeColor,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: themeColor[900] ?? themeColor,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              if (onDismiss != null) ...[
                SizedBox(width: 4.w),
                IconButton(
                  icon: Icon(Icons.close, size: 18.sp, color: Colors.grey[600]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDismiss,
                ),
              ],
            ],
          ),
          if (message.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              message,
              style: TextStyle(
                fontSize: 12.sp,
                color: themeColor[900] ?? themeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (actionChips != null && actionChips!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: actionChips!,
            ),
          ],
        ],
      ),
    );
  }
}
