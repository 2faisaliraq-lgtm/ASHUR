import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/customer_stats_entity.dart';

class CustomerStatsSection extends StatelessWidget {
  CustomerStatsSection({
    required this.stats,
    required this.onFilterSelected,
    super.key,
  });
  final CustomerStatsEntity? stats;
  final ValueChanged<String> onFilterSelected;
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  @override
  Widget build(BuildContext context) {
    final displayStats =
        stats ??
        const CustomerStatsEntity(
          totalCustomers: 0,
          activeCustomers: 0,
          inactiveCustomers: 0,
          netBalance: 0,
          totalDebtAmount: 0,
          totalCreditAmount: 0,
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
            'نظرة عامة على العملاء',
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
              int crossAxisCount;
              double childAspectRatio;

              if (availableWidth > 900) {
                crossAxisCount = 4;
                childAspectRatio = 4.5;
              } else if (availableWidth > 600) {
                crossAxisCount = 4;
                childAspectRatio = 4.0;
              } else {
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
                    'إجمالي العملاء',
                    _formattingService.formatInteger(
                      displayStats.totalCustomers,
                    ),
                    Icons.people_outline,
                    AssyrianTheme.deepBlue,
                    onTap: () => onFilterSelected('all'),
                  ),
                  _buildStatCard(
                    'عملاء نشطون',
                    _formattingService.formatInteger(
                      displayStats.activeCustomers,
                    ),
                    Icons.check_circle_outline,
                    Colors.green,
                    onTap: () => onFilterSelected('active'),
                  ),
                  _buildStatCard(
                    'لديهم مجموعة',
                    _formattingService.formatInteger(
                      displayStats.customersWithGroups,
                    ),
                    Icons.group_outlined,
                    Colors.blue,
                    onTap: () => onFilterSelected('with_group'),
                  ),
                  _buildStatCard(
                    'بدون مجموعة',
                    _formattingService.formatInteger(
                      displayStats.customersWithoutGroups,
                    ),
                    Icons.person_outline,
                    Colors.purple,
                    onTap: () => onFilterSelected('without_group'),
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
