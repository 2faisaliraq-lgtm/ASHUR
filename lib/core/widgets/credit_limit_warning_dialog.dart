import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/formatting_service.dart';

/// نافذة تحذير من تجاوز حد الدين - قابلة لإعادة الاستخدام
class CreditLimitWarningDialog extends StatelessWidget {
  const CreditLimitWarningDialog({
    required this.customerName,
    required this.currentDebt,
    required this.creditLimit,
    required this.invoiceAmount,
    required this.newDebt,
    super.key,
    this.confirmButtonText = 'إضافة الفاتورة والحفظ',
    this.cancelButtonText = 'إلغاء الفاتورة والعودة',
    this.icon = Icons.warning_amber_rounded,
    this.iconColor = Colors.red,
    this.confirmButtonColor = Colors.red,
  });

  final String customerName;
  final double currentDebt;
  final double creditLimit;
  final double invoiceAmount;
  final double newDebt;
  final String confirmButtonText;
  final String cancelButtonText;
  final IconData icon;
  final Color iconColor;
  final Color confirmButtonColor;

  @override
  Widget build(BuildContext context) {
    final formattingService = FormattingService();

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
              'تحذير: تجاوز حد الدين',
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
            // مربع التحذير الرئيسي
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
                      'هذه الفاتورة ستتجاوز حد الدين المسموح للعميل',
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

            // معلومات العميل
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
                      Icon(Icons.person, size: 16.sp, color: Colors.grey[600]),
                      SizedBox(width: 6.w),
                      Text(
                        'العميل:',
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
                    customerName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // تفاصيل الحساب
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    currentDebt > 0
                        ? 'الحساب الحالي (عليك):'
                        : currentDebt < 0
                        ? 'الحساب الحالي (لك):'
                        : 'الحساب الحالي:',
                    formattingService.formatCurrency(currentDebt.abs()),
                    Colors.blue,
                  ),
                  SizedBox(height: 8.h),
                  _buildInfoRow(
                    'حد الحساب:',
                    formattingService.formatCurrency(creditLimit),
                    Colors.green,
                  ),
                  SizedBox(height: 8.h),
                  _buildInfoRow(
                    'مبلغ الفاتورة:',
                    formattingService.formatCurrency(invoiceAmount),
                    Colors.orange,
                  ),
                  Divider(height: 20.h, thickness: 1, color: Colors.grey[300]),
                  _buildInfoRow(
                    newDebt > 0
                        ? 'الحساب بعد الفاتورة (عليك):'
                        : newDebt < 0
                        ? 'الحساب بعد الفاتورة (لك):'
                        : 'الحساب بعد الفاتورة:',
                    formattingService.formatCurrency(newDebt.abs()),
                    Colors.red,
                    isBold: true,
                  ),
                  SizedBox(height: 8.h),
                  _buildInfoRow(
                    'التجاوز:',
                    formattingService.formatCurrency(
                      newDebt.abs() - creditLimit,
                    ),
                    Colors.red,
                    isBold: true,
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // رسالة السؤال
            Text(
              'هل تريد المتابعة وإضافة الفاتورة رغم تجاوز الحد؟',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // زر الإلغاء - أحمر (مثل زر الحفظ السابق)
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            elevation: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                cancelButtonText,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        // زر التأكيد - أخضر
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            elevation: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                confirmButtonText,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء صف معلومات
  Widget _buildInfoRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey[700],
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// عرض نافذة التحذير
  static Future<bool> show(
    BuildContext context, {
    required String customerName,
    required double currentDebt,
    required double creditLimit,
    required double invoiceAmount,
    required double newDebt,
    String confirmButtonText = 'إضافة الفاتورة والحفظ',
    String cancelButtonText = 'إلغاء الفاتورة والعودة',
    IconData icon = Icons.warning_amber_rounded,
    Color iconColor = Colors.red,
    Color confirmButtonColor = Colors.red,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => CreditLimitWarningDialog(
            customerName: customerName,
            currentDebt: currentDebt,
            creditLimit: creditLimit,
            invoiceAmount: invoiceAmount,
            newDebt: newDebt,
            confirmButtonText: confirmButtonText,
            cancelButtonText: cancelButtonText,
            icon: icon,
            iconColor: iconColor,
            confirmButtonColor: confirmButtonColor,
          ),
        ) ??
        false;
  }
}
