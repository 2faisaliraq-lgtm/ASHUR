import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/report_entity.dart';

class ReportCard extends StatelessWidget {
  const ReportCard({
    required this.report,
    required this.onTap,
    super.key,
    this.isListView = true,
  });
  final ReportEntity report;
  final VoidCallback onTap;
  final bool isListView;

  @override
  Widget build(BuildContext context) {
    return isListView ? _buildListCard(context) : _buildGridCard(context);
  }

  Widget _buildListCard(BuildContext context) {
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
                  color: _getStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.assessment,
                        size: 24.sp,
                        color: _getStatusColor().withValues(alpha: 0.5),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      left: 3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _getStatusColor(),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(),
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
                      report.title,
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
                                Icons.calendar_today,
                                size: 10.sp,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd',
                                ).format(report.startDate),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.grey[600],
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

              // نوع التقرير والحالة على اليسار
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
                      color: _getTypeColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getTypeLabel(),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: _getTypeColor(),
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
    switch (report.status) {
      case 'completed':
        return Icons.check;
      case 'pending':
        return Icons.schedule;
      case 'failed':
        return Icons.close;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor() {
    switch (report.status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor() {
    switch (report.type) {
      case 'financial':
        return AssyrianTheme.primaryGold;
      case 'inventory':
        return Colors.blue;
      case 'sales':
        return Colors.green;
      case 'expenses':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel() {
    switch (report.type) {
      case 'financial':
        return 'مالي';
      case 'inventory':
        return 'مخزون';
      case 'sales':
        return 'مبيعات';
      case 'expenses':
        return 'مصاريف';
      default:
        return report.type;
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
                  _buildStatusIconWidget(),
                  const Spacer(),
                  _buildStatusBadge(),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                report.title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Text(
                _getTypeLabel(),
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                DateFormat('yyyy-MM-dd').format(report.startDate),
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIconWidget() {
    IconData icon;
    Color color;

    switch (report.status) {
      case 'completed':
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'pending':
        icon = Icons.pending_outlined;
        color = Colors.orange;
        break;
      case 'failed':
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      default:
        icon = Icons.assessment_outlined;
        color = Colors.grey[600]!;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24.sp),
    );
  }

  Widget _buildStatusBadge() {
    var label = '';
    var color = _getStatusColor();

    switch (report.status) {
      case 'completed':
        label = 'مكتمل';
        break;
      case 'pending':
        label = 'قيد الانتظار';
        break;
      case 'failed':
        label = 'فشل';
        break;
      default:
        label = report.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
