import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/report_log_entity.dart';

/// بطاقة عرض سجل نشاط التقارير
class ReportLogCard extends StatelessWidget {
  const ReportLogCard({required this.log, this.onTap, super.key});

  final ReportLogEntity log;
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
      case 'generate':
        return Icons.assessment;
      case 'view':
        return Icons.visibility;
      case 'download':
        return Icons.download;
      case 'export':
        return Icons.file_download;
      case 'share':
        return Icons.share;
      case 'schedule':
        return Icons.schedule;
      case 'delete':
        return Icons.delete;
      default:
        return Icons.assessment;
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType) {
      case 'generate':
        return Colors.blue;
      case 'view':
        return AssyrianTheme.deepBlue;
      case 'download':
        return Colors.green;
      case 'export':
        return Colors.orange;
      case 'share':
        return Colors.purple;
      case 'schedule':
        return Colors.teal;
      case 'delete':
        return Colors.red;
      default:
        return AssyrianTheme.primaryGold;
    }
  }

  String _getActionTitle(String actionType) {
    switch (actionType) {
      case 'generate':
        return 'إنشاء تقرير';
      case 'view':
        return 'عرض تقرير';
      case 'download':
        return 'تحميل تقرير';
      case 'export':
        return 'تصدير تقرير';
      case 'share':
        return 'مشاركة تقرير';
      case 'schedule':
        return 'جدولة تقرير';
      case 'delete':
        return 'حذف تقرير';
      default:
        return actionType;
    }
  }

  String _getTargetTypeTitle(String targetType) {
    // ⚠️ توحيد قيم targetType بين الكيان والبطاقة.
    // القيم في الكيان: 'report', 'dashboard', 'chart', 'analytics', 'schedule', 'template', 'export'
    // القيم في البطاقة: 'financial_report', 'sales_report', 'inventory_report', 'customer_report', 'expense_report'
    // هذه الدالة تدعم كلا Gruppي القيم لضمان الترجمة الصحيحة بغض النظر عن المصدر.
    switch (targetType) {
      case 'report':
        return 'تقرير';
      case 'dashboard':
        return 'لوحة تحكم';
      case 'chart':
        return 'مخطط';
      case 'analytics':
        return 'تحليلات';
      case 'schedule':
        return 'جدولة تقرير';
      case 'template':
        return 'قالب تقرير';
      case 'export':
        return 'تصدير';
      case 'financial_report':
        return 'تقرير مالي';
      case 'sales_report':
        return 'تقرير مبيعات';
      case 'inventory_report':
        return 'تقرير مخزون';
      case 'customer_report':
        return 'تقرير عملاء';
      case 'expense_report':
        return 'تقرير مصروفات';
      default:
        return targetType;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
