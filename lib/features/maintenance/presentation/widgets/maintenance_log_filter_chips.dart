import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/assyrian_theme.dart';

/// رقائق فلترة سجلات الصيانة
class MaintenanceLogFilterChips extends StatelessWidget {
  const MaintenanceLogFilterChips({
    required this.selectedFilter,
    required this.selectedDateFilter,
    required this.isExpanded,
    required this.onFilterChanged,
    required this.onDateFilterChanged,
    required this.onExpandToggle,
    required this.onClearFilters,
    super.key,
  });

  final String selectedFilter;
  final String selectedDateFilter;
  final bool isExpanded;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onDateFilterChanged;
  final VoidCallback onExpandToggle;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط التحكم بالفلاتر
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الفلاتر',
                style: AssyrianTheme.titleStyle.copyWith(
                  fontSize: 16.sp,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
              Row(
                children: [
                  if (_hasActiveFilters())
                    TextButton.icon(
                      onPressed: onClearFilters,
                      icon: Icon(
                        Icons.clear_all,
                        size: 16.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                      label: Text(
                        'مسح الكل',
                        style: TextStyle(
                          color: AssyrianTheme.primaryGold,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: onExpandToggle,
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AssyrianTheme.primaryGold,
                      size: 20.sp,
                    ),
                    tooltip: isExpanded ? 'إخفاء الفلاتر' : 'إظهار الفلاتر',
                  ),
                ],
              ),
            ],
          ),

          if (isExpanded) ...[
            SizedBox(height: 12.h),

            // فلاتر الإجراءات
            Text(
              'نوع الإجراء:',
              style: AssyrianTheme.subtitleStyle.copyWith(
                fontSize: 14.sp,
                color: AssyrianTheme.deepBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                _buildFilterChip('all', 'الكل'),
                _buildFilterChip('create', 'إنشاء'),
                _buildFilterChip('update', 'تحديث'),
                _buildFilterChip('delete', 'حذف'),
                _buildFilterChip('schedule', 'جدولة'),
                _buildFilterChip('complete', 'إكمال'),
                _buildFilterChip('cancel', 'إلغاء'),
                _buildFilterChip('assign', 'تعيين'),
              ],
            ),

            SizedBox(height: 16.h),

            // فلاتر التاريخ
            Text(
              'الفترة الزمنية:',
              style: AssyrianTheme.subtitleStyle.copyWith(
                fontSize: 14.sp,
                color: AssyrianTheme.deepBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                _buildDateFilterChip('all', 'الكل'),
                _buildDateFilterChip('today', 'اليوم'),
                _buildDateFilterChip('week', 'هذا الأسبوع'),
                _buildDateFilterChip('month', 'هذا الشهر'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return selectedFilter != 'all' || selectedDateFilter != 'all';
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => onFilterChanged(value),
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.primaryGold,
      backgroundColor: AssyrianTheme.ivoryWhite,
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : AssyrianTheme.deepBlue.withValues(alpha: 0.3),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.primaryGold : AssyrianTheme.deepBlue,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12.sp,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    );
  }

  Widget _buildDateFilterChip(String value, String label) {
    final isSelected = selectedDateFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => onDateFilterChanged(value),
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.primaryGold,
      backgroundColor: AssyrianTheme.ivoryWhite,
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : AssyrianTheme.deepBlue.withValues(alpha: 0.3),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.primaryGold : AssyrianTheme.deepBlue,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12.sp,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    );
  }
}
