import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// نافذة حوار تأكيد عامة قابلة لإعادة الاستخدام
class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    required this.title,
    required this.itemName,
    required this.onConfirm,
    super.key,
    this.description,
    this.infoMessage,
    this.additionalInfo,
    this.confirmButtonText = 'تأكيد',
    this.cancelButtonText = 'إلغاء',
    this.icon = Icons.check_circle,
    this.iconColor = Colors.blue,
    this.confirmButtonColor = Colors.blue,
  });

  final String title;
  final String itemName;
  final String? description;
  final String? infoMessage;
  final Map<String, String>? additionalInfo;
  final VoidCallback onConfirm;
  final String confirmButtonText;
  final String cancelButtonText;
  final IconData icon;
  final Color iconColor;
  final Color confirmButtonColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: iconColor, size: 24.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (infoMessage != null) ...[
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        infoMessage!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
            ],
            if (description != null) ...[
              Text(
                description!,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              ),
              SizedBox(height: 12.h),
            ],
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16.sp, color: Colors.grey[600]),
                      SizedBox(width: 6.w),
                      Text(
                        'العنصر:',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    itemName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (additionalInfo != null && additionalInfo!.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    ...additionalInfo!.entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getIconForKey(entry.key),
                                  size: 16.sp,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  '${entry.key}:',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: _getColorForKey(entry.key),
                                fontWeight: _isBoldForKey(entry.key)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          ),
          child: Text(
            cancelButtonText,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmButtonColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16.sp),
              SizedBox(width: 6.w),
              Text(
                confirmButtonText,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForKey(String key) {
    if (key.contains('عميل') || key.contains('العميل')) {
      return Icons.person;
    } else if (key.contains('سعر') ||
        key.contains('السعر') ||
        key.contains('مبلغ') ||
        key.contains('المبلغ')) {
      return Icons.attach_money;
    } else if (key.contains('تاريخ') || key.contains('التاريخ')) {
      return Icons.calendar_today;
    } else if (key.contains('نوع') || key.contains('النوع')) {
      return Icons.category;
    } else if (key.contains('حالة') || key.contains('الحالة')) {
      return Icons.info;
    } else {
      return Icons.description;
    }
  }

  Color _getColorForKey(String key) {
    if (key.contains('سعر') ||
        key.contains('السعر') ||
        key.contains('مبلغ') ||
        key.contains('المبلغ')) {
      return Colors.green[700]!;
    } else {
      return Colors.grey[700]!;
    }
  }

  bool _isBoldForKey(String key) {
    return key.contains('سعر') ||
        key.contains('السعر') ||
        key.contains('مبلغ') ||
        key.contains('المبلغ');
  }

  /// عرض نافذة حوار التأكيد
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String itemName,
    required VoidCallback onConfirm,
    String? description,
    String? infoMessage,
    Map<String, String>? additionalInfo,
    String confirmButtonText = 'تأكيد',
    String cancelButtonText = 'إلغاء',
    IconData icon = Icons.check_circle,
    Color iconColor = Colors.blue,
    Color confirmButtonColor = Colors.blue,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmationDialog(
        title: title,
        itemName: itemName,
        description: description,
        infoMessage: infoMessage,
        additionalInfo: additionalInfo,
        onConfirm: onConfirm,
        confirmButtonText: confirmButtonText,
        cancelButtonText: cancelButtonText,
        icon: icon,
        iconColor: iconColor,
        confirmButtonColor: confirmButtonColor,
      ),
    );
  }
}
