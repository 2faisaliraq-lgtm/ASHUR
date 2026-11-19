import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/report_stats_entity.dart';

/// قسم إحصائيات التقارير
class ReportStatsSection extends StatelessWidget {
  ReportStatsSection({
    required this.stats,
    required this.onFilterSelected,
    super.key,
  });
  final ReportStatsEntity? stats;
  final ValueChanged<String> onFilterSelected;
  // ⚠️ استخدام GetIt.instance مباشرة في حقل الفئة قد يسبب مشاكل إذا لم يكن
  // FormattingService مسجلاً في GetIt قبل إنشاء هذه القطعة. يُنصح بت Right
  // تمرير FormattingService كمعامل إنشاء أو استخدام BlocProvider للوصول إليه.
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  @override
  Widget build(BuildContext context) {
    final displayStats =
        stats ??
        const ReportStatsEntity(
          totalReports: 0,
          pendingReports: 0,
          completedReports: 0,
          failedReports: 0,
          financialReports: 0,
          inventoryReports: 0,
          salesReports: 0,
          monthlyReports: 0, // ⚠️ أُضيف لتطابق الحقل في الكيان
        );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AssyrianTheme.primaryGold,
            AssyrianTheme.primaryGold.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نظرة عامة على التقارير',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              // تحديد عدد الأعمدة بناءً على العرض المتاح
              int crossAxisCount;
              double childAspectRatio;

              if (availableWidth > 900) {
                // على الشاشات الكبيرة، 4 كروت في سطر واحد
                crossAxisCount = 4;
                childAspectRatio = 4.5;
              } else if (availableWidth > 600) {
                // على الأجهزة اللوحية، 4 كروت في سطر واحد
                crossAxisCount = 4;
                childAspectRatio = 4.0;
              } else {
                // على الجوال، كرتين في كل سطر
                crossAxisCount = 2;
                childAspectRatio = 2.5;
              }

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildStatCard(
                    'إجمالي التقارير',
                    _formattingService.formatInteger(displayStats.totalReports),
                    Icons.analytics_outlined,
                    AssyrianTheme.deepBlue,
                    onTap: () => onFilterSelected('all'),
                  ),
                  _buildStatCard(
                    'قيد الإنشاء',
                    _formattingService.formatInteger(
                      displayStats.pendingReports,
                    ),
                    Icons.pending_outlined,
                    Colors.orange,
                    onTap: () => onFilterSelected('pending'),
                  ),
                  _buildStatCard(
                    'مكتملة',
                    _formattingService.formatInteger(
                      displayStats.completedReports,
                    ),
                    Icons.check_circle_outline,
                    Colors.green,
                    onTap: () => onFilterSelected('completed'),
                  ),
                  _buildStatCard(
                    'فاشلة',
                    _formattingService.formatInteger(
                      displayStats.failedReports,
                    ),
                    Icons.error_outline,
                    Colors.red,
                    onTap: () => onFilterSelected('failed'),
                  ),
                  _buildStatCard(
                    'مالية',
                    _formattingService.formatInteger(
                      displayStats.financialReports,
                    ),
                    Icons.attach_money,
                    Colors.green,
                    onTap: () => onFilterSelected('financial'),
                  ),
                  _buildStatCard(
                    'مخزون',
                    _formattingService.formatInteger(
                      displayStats.inventoryReports,
                    ),
                    Icons.inventory,
                    Colors.blue,
                    onTap: () => onFilterSelected('inventory'),
                  ),
                  _buildStatCard(
                    'مبيعات',
                    _formattingService.formatInteger(displayStats.salesReports),
                    Icons.trending_up,
                    Colors.orange,
                    onTap: () => onFilterSelected('sales'),
                  ),
                  _buildStatCard(
                    'هذا الشهر',
                    _formattingService.formatInteger(
                      displayStats.monthlyReports,
                    ),
                    Icons.calendar_today,
                    Colors.purple,
                    onTap: () => onFilterSelected('this_month'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // الاسم في الجهة اليمنى
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(width: 8.w),
            // الرقم في الجهة اليسرى
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
