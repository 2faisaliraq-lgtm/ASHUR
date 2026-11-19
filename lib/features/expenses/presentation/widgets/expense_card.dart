import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/expense_entity.dart';

class ExpenseCard extends StatelessWidget {
  ExpenseCard({
    required this.expense,
    required this.onTap,
    super.key,
    this.isListView = true,
  });
  final ExpenseEntity expense;
  final VoidCallback onTap;
  final bool isListView;
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

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
                        Icons.receipt_long,
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
                      expense.title,
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
                                DateFormat('yyyy-MM-dd').format(expense.date),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6.w),
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
                      _formattingService.formatExpenseAmount(expense.amount),
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
    switch (expense.status) {
      case 'approved':
        return Icons.check;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
        return Icons.close;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor() {
    switch (expense.status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
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
              SizedBox(height: 8.h),
              Text(
                expense.title,
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
                expense.category,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                _formattingService.formatExpenseAmount(expense.amount),
                style: TextStyle(
                  fontSize: 12.sp,
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

    switch (expense.status) {
      case 'approved':
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'pending':
        icon = Icons.pending_outlined;
        color = Colors.orange;
        break;
      case 'rejected':
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      default:
        icon = Icons.receipt_outlined;
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

    switch (expense.status) {
      case 'approved':
        label = 'معتمدة';
        break;
      case 'pending':
        label = 'قيد الانتظار';
        break;
      case 'rejected':
        label = 'مرفوضة';
        break;
      default:
        label = expense.status;
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
