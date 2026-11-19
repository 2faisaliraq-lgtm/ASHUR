import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';

/// قسم النظرة العامة على المخزون
class InventoryStatsSection extends StatelessWidget {
  InventoryStatsSection({
    this.stats = const {},
    required this.onFilterSelected,
    super.key,
  });
  final Map<String, dynamic>? stats;
  final ValueChanged<String> onFilterSelected;
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  @override
  Widget build(BuildContext context) {
    final productsStats =
        (stats ?? const {})['products'] as Map<String, dynamic>? ?? {};

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
            'نظرة عامة على المخزون',
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
                    'إجمالي المنتجات',
                    _formattingService.formatInteger(
                      productsStats['totalProducts'] ?? 0,
                    ),
                    Icons.inventory_2_outlined,
                    AssyrianTheme.deepBlue,
                    onTap: () => onFilterSelected('all'),
                  ),
                  _buildStatCard(
                    'المنتجات النشطة',
                    _formattingService.formatInteger(
                      productsStats['activeProducts'] ?? 0,
                    ),
                    Icons.check_circle_outline,
                    Colors.green,
                    onTap: () => onFilterSelected('active'),
                  ),
                  _buildStatCard(
                    'مخزون منخفض',
                    _formattingService.formatInteger(
                      productsStats['lowStockProducts'] ?? 0,
                    ),
                    Icons.warning_amber_outlined,
                    Colors.orange,
                    onTap: () => onFilterSelected('low_stock'),
                  ),
                  _buildStatCard(
                    'مخزون نافد',
                    _formattingService.formatInteger(
                      productsStats['outOfStockProducts'] ?? 0,
                    ),
                    Icons.error_outline,
                    Colors.red,
                    onTap: () => onFilterSelected('out_of_stock'),
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
