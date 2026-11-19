import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/invoice_entity.dart';

class InvoiceCard extends StatelessWidget {
  InvoiceCard({
    required this.invoice,
    required this.onTap,
    super.key,
    this.isListView = true,
  });
  final InvoiceEntity invoice;
  final VoidCallback onTap;
  final bool isListView;
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  @override
  Widget build(BuildContext context) {
    return isListView ? _buildListCard(context) : _buildGridCard(context);
  }

  Widget _buildListCard(BuildContext context) {
    // ✅ ملاحظة للمبرمجين المستقبليين:
    // تم تخزين نتائج دوال الحالة في متغيرات محلية لتقليل الاستدعاءات المتكررة.
    // السبب: كل استدعاء لـ _getStatusColor() أو _getStatusIcon() أو _formattingService.formatInvoiceTotal()
    // يسبب عمليات حسابية غير ضرورية في كل build.
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();
    final formattedTotal = _formattingService.formatInvoiceTotal(invoice.totalAmount);
    final showOverdue = invoice.remainingAmount > 0 && invoice.isUnpaid;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // أيقونة الحالة على اليمين
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.receipt_long,
                        size: 24.sp,
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      left: 3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusIcon,
                          color: Colors.white,
                          size: 10.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // المعلومات في المنتصف
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.customerName,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AssyrianTheme.deepBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt,
                                size: 10.sp,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                invoice.invoiceNumber,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (showOverdue)
                          SizedBox(width: 6.w),
                        if (showOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 10.sp,
                                  color: Colors.red,
                                ),
                                Text(
                                  'متأخر',
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
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

              SizedBox(width: 8.w),

              // المبلغ والحالة على اليسار
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      formattedTotal,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  _buildStatusBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (invoice.status) {
      case 'paid':
        return Icons.check;
      case 'partial':
        return Icons.schedule;
      case 'unpaid':
        return Icons.warning;
      case 'cancelled':
        return Icons.close;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor() {
    switch (invoice.status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.blue;
      case 'unpaid':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildGridCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIcon(),
                  const Spacer(),
                  _buildStatusBadge(),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                invoice.customerName,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3.h),
              Text(
                invoice.invoiceNumber,
                style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                _formattingService.formatInvoiceTotal(invoice.totalAmount),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.primaryGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (invoice.status) {
      case 'paid':
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'partial':
        icon = Icons.pending_outlined;
        color = Colors.blue;
        break;
      case 'unpaid':
        icon = Icons.warning_amber_outlined;
        color = Colors.orange;
        break;
      case 'cancelled':
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      default:
        icon = Icons.receipt_outlined;
        color = Colors.grey[600]!;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 18.sp),
    );
  }

  Widget _buildStatusBadge() {
    var label = '';
    var color = _getStatusColor();

    switch (invoice.status) {
      case 'paid':
        label = 'مدفوعة';
        break;
      case 'partial':
        label = 'جزئية';
        break;
      case 'unpaid':
        label = 'غير مدفوعة';
        break;
      case 'cancelled':
        label = 'ملغية';
        break;
      default:
        label = invoice.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
