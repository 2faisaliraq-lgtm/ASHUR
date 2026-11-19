import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/expense_log_entity.dart';

/// بطاقة عرض سجل نشاط المصروفات
class ExpenseLogCard extends StatelessWidget {
  const ExpenseLogCard({required this.log, this.onTap, super.key});

  final ExpenseLogEntity log;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AssyrianTheme.cardGradient,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: AssyrianTheme.assyrianShadow,
              border: Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الصف الأول: الأيقونة والعنوان والحالة
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: _getActionColor(
                            log.actionType,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          _getActionIcon(log.actionType),
                          color: _getActionColor(log.actionType),
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getActionTitle(log.actionType),
                              style: AssyrianTheme.titleStyle.copyWith(
                                fontSize: 16.sp,
                                color: AssyrianTheme.deepBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (log.targetType != null)
                              Text(
                                _getTargetTypeTitle(log.targetType!),
                                style: AssyrianTheme.subtitleStyle.copyWith(
                                  fontSize: 12.sp,
                                  color: AssyrianTheme.deepBlue.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: log.isSuccess
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: log.isSuccess ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              log.isSuccess ? Icons.check_circle : Icons.error,
                              size: 12.sp,
                              color: log.isSuccess ? Colors.green : Colors.red,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              log.isSuccess ? 'نجح' : 'فشل',
                              style: TextStyle(
                                color: log.isSuccess
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // التفاصيل إذا كانت متوفرة
                  if (log.details != null && log.details!.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        log.details!,
                        style: AssyrianTheme.bodyStyle.copyWith(
                          fontSize: 13.sp,
                          color: AssyrianTheme.deepBlue.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 12.h),

                  // الصف الأخير: معلومات المستخدم والتاريخ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 14.sp,
                              color: AssyrianTheme.primaryGold,
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                log.userName ?? 'غير محدد',
                                style: AssyrianTheme.subtitleStyle.copyWith(
                                  fontSize: 12.sp,
                                  color: AssyrianTheme.deepBlue.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14.sp,
                            color: AssyrianTheme.primaryGold,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            _formatDate(log.timestamp),
                            style: AssyrianTheme.subtitleStyle.copyWith(
                              fontSize: 12.sp,
                              color: AssyrianTheme.deepBlue.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType) {
      case 'create':
        return Icons.add_circle;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'view':
        return Icons.visibility;
      case 'approve':
        return Icons.check_circle;
      case 'reject':
        return Icons.cancel;
      case 'pay':
        return Icons.payment;
      case 'refund':
        return Icons.money_off;
      default:
        return Icons.receipt_long;
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'view':
        return AssyrianTheme.deepBlue;
      case 'approve':
        return Colors.green;
      case 'reject':
        return Colors.red;
      case 'pay':
        return Colors.orange;
      case 'refund':
        return Colors.purple;
      default:
        return AssyrianTheme.primaryGold;
    }
  }

  String _getActionTitle(String actionType) {
    switch (actionType) {
      case 'create':
        return 'إنشاء مصروف';
      case 'update':
        return 'تحديث مصروف';
      case 'delete':
        return 'حذف مصروف';
      case 'view':
        return 'عرض مصروف';
      case 'approve':
        return 'موافقة على مصروف';
      case 'reject':
        return 'رفض مصروف';
      case 'pay':
        return 'دفع مصروف';
      case 'refund':
        return 'استرداد مصروف';
      default:
        return actionType;
    }
  }

  String _getTargetTypeTitle(String targetType) {
    switch (targetType) {
      case 'expense':
        return 'مصروف';
      case 'category':
        return 'فئة مصروف';
      case 'receipt':
        return 'إيصال';
      case 'approval':
        return 'موافقة';
      default:
        return targetType;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
