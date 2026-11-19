import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/invoice_stats_entity.dart';

/// قسم إحصائيات الفواتير
class InvoiceStatsSection extends StatefulWidget {
  const InvoiceStatsSection({
    required this.stats,
    required this.onFilterSelected,
    super.key,
  });
  final InvoiceStatsEntity? stats;
  final ValueChanged<String> onFilterSelected;

  @override
  State<InvoiceStatsSection> createState() => _InvoiceStatsSectionState();
}

class _InvoiceStatsSectionState extends State<InvoiceStatsSection>
    with AutomaticKeepAliveClientMixin {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// نستخدم AutomaticKeepAliveClientMixin للحفاظ على حالة الـ widget
  /// حتى عندما يتم إعادة بنائه. هذا يقلل من عدد عمليات إعادة البناء
  /// ويحسن الأداء عند التمرير في القوائم الطويلة.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final stats = widget.stats;
    final displayStats =
        stats ??
        const InvoiceStatsEntity(
          totalInvoices: 0,
          paidInvoices: 0,
          unpaidInvoices: 0,
          overdueInvoices: 0,
          totalRevenue: 0,
          totalPaid: 0,
          totalRemaining: 0,
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
            'إحصائيات اليوم',
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
                    'إجمالي الفواتير',
                    _formattingService.formatInteger(
                      displayStats.totalInvoices,
                    ),
                    Icons.receipt_long_outlined,
                    AssyrianTheme.deepBlue,
                    onTap: () => widget.onFilterSelected('all'),
                  ),
                  _buildStatCard(
                    'الفواتير المدفوعة',
                    _formattingService.formatInteger(displayStats.paidInvoices),
                    Icons.check_circle_outline,
                    Colors.green,
                    onTap: () => widget.onFilterSelected('paid'),
                  ),
                  _buildStatCard(
                    'فواتير غير مدفوعة',
                    _formattingService.formatInteger(
                      displayStats.unpaidInvoices,
                    ),
                    Icons.warning_amber_outlined,
                    Colors.orange,
                    onTap: () => widget.onFilterSelected('unpaid'),
                  ),
                  _buildStatCard(
                    'فواتير متأخرة',
                    _formattingService.formatInteger(
                      displayStats.overdueInvoices,
                    ),
                    Icons.error_outline,
                    Colors.red,
                    onTap: () => widget.onFilterSelected('overdue'),
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
