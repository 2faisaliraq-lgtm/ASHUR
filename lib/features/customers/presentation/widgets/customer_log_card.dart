import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/customer_log_entity.dart';

/// بطاقة عرض سجل نشاط العميل
class CustomerLogCard extends StatelessWidget {
  const CustomerLogCard({required this.log, super.key, this.onTap});

  final CustomerLogEntity log;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: AssyrianTheme.cardGradient,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                // أيقونة العملية
                _buildActionIcon(),
                SizedBox(width: 12.w),

                // معلومات السجل
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // معرف العميل ونوع العملية
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log.targetId ?? 'عميل غير محدد',
                              style: AssyrianTheme.titleStyle.copyWith(
                                fontSize:
                                    ResponsiveHelper.getResponsiveFontSize(
                                      context,
                                      mobile: 16,
                                    ),
                                color: AssyrianTheme.deepBlue,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          _buildStatusBadge(),
                        ],
                      ),

                      SizedBox(height: 4.h),

                      // وصف العملية
                      Text(
                        log.actionDescription,
                        style: AssyrianTheme.subtitleStyle.copyWith(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobile: 14,
                          ),
                          color: AssyrianTheme.deepBlue.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),

                      SizedBox(height: 4.h),

                      // المستخدم والتاريخ
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log.userName ?? 'مستخدم غير محدد',
                              style: AssyrianTheme.subtitleStyle.copyWith(
                                fontSize:
                                    ResponsiveHelper.getResponsiveFontSize(
                                      context,
                                      mobile: 12,
                                    ),
                                color: AssyrianTheme.deepBlue.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            _formatDateTime(log.timestamp),
                            style: AssyrianTheme.subtitleStyle.copyWith(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                mobile: 12,
                              ),
                              color: AssyrianTheme.deepBlue.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // التفاصيل (إذا وجدت)
                      if (log.details != null && log.details!.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          log.details!,
                          style: AssyrianTheme.subtitleStyle.copyWith(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(
                              context,
                              mobile: 11,
                            ),
                            color: AssyrianTheme.deepBlue.withValues(
                              alpha: 0.5,
                            ),
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),

                // سهم للتفاصيل
                Icon(
                  Icons.chevron_left,
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.7),
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء أيقونة العملية
  Widget _buildActionIcon() {
    IconData iconData;
    Color backgroundColor;
    Color iconColor;

    switch (log.actionType) {
      case 'create':
        iconData = Icons.person_add;
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        iconColor = Colors.green;
        break;
      case 'update':
        iconData = Icons.edit;
        backgroundColor = AssyrianTheme.primaryGold.withValues(alpha: 0.1);
        iconColor = AssyrianTheme.primaryGold;
        break;
      case 'delete':
        iconData = Icons.person_remove;
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        iconColor = Colors.red;
        break;
      case 'view':
        iconData = Icons.visibility;
        backgroundColor = Colors.purple.withValues(alpha: 0.1);
        iconColor = Colors.purple;
        break;
      case 'contact':
        iconData = Icons.contact_phone;
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        iconColor = Colors.blue;
        break;
      case 'quote':
        iconData = Icons.request_quote;
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        iconColor = Colors.orange;
        break;
      case 'follow_up':
        iconData = Icons.follow_the_signs;
        backgroundColor = Colors.teal.withValues(alpha: 0.1);
        iconColor = Colors.teal;
        break;
      default:
        iconData = Icons.people;
        backgroundColor = AssyrianTheme.deepBlue.withValues(alpha: 0.1);
        iconColor = AssyrianTheme.deepBlue;
    }

    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Icon(iconData, color: iconColor, size: 24.sp),
    );
  }

  /// بناء شارة الحالة
  Widget _buildStatusBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: log.isSuccess
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: log.isSuccess
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            log.isSuccess ? Icons.check_circle : Icons.error,
            color: log.isSuccess ? Colors.green : Colors.red,
            size: 12.sp,
          ),
          SizedBox(width: 4.w),
          Text(
            log.isSuccess ? 'نجح' : 'فشل',
            style: TextStyle(
              fontSize: 10.sp,
              color: log.isSuccess ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// تنسيق التاريخ والوقت
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
