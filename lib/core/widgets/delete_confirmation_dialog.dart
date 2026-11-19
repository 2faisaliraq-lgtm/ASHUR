import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// نافذة حوار حذف عامة قابلة لإعادة الاستخدام
class DeleteConfirmationDialog extends StatelessWidget {
  const DeleteConfirmationDialog({
    required this.title,
    required this.itemName,
    required this.onConfirm,
    super.key,
    this.description,
    this.warningMessage,
    this.confirmButtonText = 'حذف نهائي',
    this.cancelButtonText = 'إلغاء',
    this.icon = Icons.delete_forever,
    this.iconColor = Colors.red,
    this.confirmButtonColor = Colors.red,
  });

  final String title;
  final String itemName;
  final String? description;
  final String? warningMessage;
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    warningMessage ?? 'تحذير: هذا الإجراء لا يمكن التراجع عنه',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'هل أنت متأكد من حذف العنصر التالي؟',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
          ),
          SizedBox(height: 12.h),
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
                if (description != null && description!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 16.sp,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'التفاصيل:',
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
                    description!,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'سيتم حذف جميع البيانات المرتبطة بهذا العنصر نهائياً.',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.red[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
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
              Icon(Icons.delete, size: 16.sp),
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

  /// عرض نافذة حوار الحذف
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String itemName,
    required VoidCallback onConfirm,
    String? description,
    String? warningMessage,
    String confirmButtonText = 'حذف نهائي',
    String cancelButtonText = 'إلغاء',
    IconData icon = Icons.delete_forever,
    Color iconColor = Colors.red,
    Color confirmButtonColor = Colors.red,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteConfirmationDialog(
        title: title,
        itemName: itemName,
        description: description,
        warningMessage: warningMessage,
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
