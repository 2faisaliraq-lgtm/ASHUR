import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/product_log_entity.dart';

/// بطاقة عرض سجل حركة المنتج
class ProductLogCard extends StatelessWidget {
  const ProductLogCard({required this.log, super.key});

  final ProductLogEntity log;

  @override
  Widget build(BuildContext context) {
    final formattingService = FormattingService();
    final isPurchase = log.isPurchase;
    final isSale = log.isSale;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isPurchase
              ? Colors.green.withValues(alpha: 0.3)
              : isSale
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // الشريط العلوي
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isPurchase
                  ? Colors.green.withValues(alpha: 0.1)
                  : isSale
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.r),
                topRight: Radius.circular(10.r),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPurchase ? Icons.shopping_cart : Icons.point_of_sale,
                  size: 18.sp,
                  color: isPurchase
                      ? Colors.green[700]
                      : isSale
                          ? Colors.red[700]
                          : Colors.grey[700],
                ),
                SizedBox(width: 8.w),
                Text(
                  isPurchase ? 'فاتورة شراء' : 'فاتورة بيع',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: isPurchase
                        ? Colors.green[700]
                        : isSale
                            ? Colors.red[700]
                            : Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(log.date),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // التفاصيل
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              children: [
                // العميل والكمية
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'العميل',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            log.customerName,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AssyrianTheme.deepBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الكمية',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${log.quantity.toStringAsFixed(2)} ${log.unitPrice > 0 ? log.unitPrice == log.totalPrice / log.quantity ? log.unitPrice : log.unitPrice : ""}',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: isPurchase ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Divider(color: Colors.grey[300], height: 1),
                SizedBox(height: 12.h),
                // الأسعار
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سعر الوحدة',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            formattingService.formatProductPrice(log.unitPrice),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AssyrianTheme.primaryGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الإجمالي',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            formattingService.formatCurrency(log.totalPrice),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: isPurchase ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
