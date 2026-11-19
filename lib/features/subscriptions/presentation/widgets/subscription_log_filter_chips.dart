import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/assyrian_theme.dart';

/// ويدجت فلاتر سجل الاشتراكات
class SubscriptionLogFilterChips extends StatelessWidget {
  const SubscriptionLogFilterChips({
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
  final Function(String) onFilterChanged;
  final Function(String) onDateFilterChanged;
  final VoidCallback onExpandToggle;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        selectedFilter != 'all' || selectedDateFilter != 'all';

    return Column(
      children: [
        // شريط الفلاتر الأساسي
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            children: [
              // زر توسيع الفلاتر
              InkWell(
                onTap: onExpandToggle,
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: AssyrianTheme.primaryGold,
                        size: 18.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'الفلاتر',
                        style: TextStyle(
                          color: AssyrianTheme.primaryGold,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AssyrianTheme.primaryGold,
                        size: 18.sp,
                      ),
                      // مؤشر الفلاتر النشطة
                      if (hasActiveFilters) ...[
                        SizedBox(width: 4.w),
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // زر مسح الفلاتر
              if (hasActiveFilters)
                InkWell(
                  onTap: onClearFilters,
                  borderRadius: BorderRadius.circular(8.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear, color: Colors.red, size: 16.sp),
                        SizedBox(width: 4.w),
                        Text(
                          'مسح الفلاتر',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // الفلاتر الموسعة
        if (isExpanded) ...[
          Divider(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            height: 1,
          ),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // فلاتر نوع العملية
                Text(
                  'نوع العملية:',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildFilterChip(
                      label: 'الكل',
                      value: 'all',
                      isSelected: selectedFilter == 'all',
                      onSelected: () => onFilterChanged('all'),
                    ),
                    _buildFilterChip(
                      label: 'إنشاء',
                      value: 'create',
                      isSelected: selectedFilter == 'create',
                      onSelected: () => onFilterChanged('create'),
                      icon: Icons.add_circle,
                      color: Colors.blue,
                    ),
                    _buildFilterChip(
                      label: 'تحديث',
                      value: 'update',
                      isSelected: selectedFilter == 'update',
                      onSelected: () => onFilterChanged('update'),
                      icon: Icons.edit,
                      color: AssyrianTheme.primaryGold,
                    ),
                    _buildFilterChip(
                      label: 'حذف',
                      value: 'delete',
                      isSelected: selectedFilter == 'delete',
                      onSelected: () => onFilterChanged('delete'),
                      icon: Icons.delete,
                      color: Colors.red,
                    ),
                    _buildFilterChip(
                      label: 'تفعيل',
                      value: 'activate',
                      isSelected: selectedFilter == 'activate',
                      onSelected: () => onFilterChanged('activate'),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    _buildFilterChip(
                      label: 'إلغاء تفعيل',
                      value: 'deactivate',
                      isSelected: selectedFilter == 'deactivate',
                      onSelected: () => onFilterChanged('deactivate'),
                      icon: Icons.pause_circle,
                      color: Colors.orange,
                    ),
                    _buildFilterChip(
                      label: 'تجديد',
                      value: 'renew',
                      isSelected: selectedFilter == 'renew',
                      onSelected: () => onFilterChanged('renew'),
                      icon: Icons.refresh,
                      color: Colors.purple,
                    ),
                    _buildFilterChip(
                      label: 'إلغاء',
                      value: 'cancel',
                      isSelected: selectedFilter == 'cancel',
                      onSelected: () => onFilterChanged('cancel'),
                      icon: Icons.cancel,
                      color: Colors.red,
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // فلاتر التاريخ
                Text(
                  'الفترة الزمنية:',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildFilterChip(
                      label: 'الكل',
                      value: 'all',
                      isSelected: selectedDateFilter == 'all',
                      onSelected: () => onDateFilterChanged('all'),
                    ),
                    _buildFilterChip(
                      label: 'اليوم',
                      value: 'today',
                      isSelected: selectedDateFilter == 'today',
                      onSelected: () => onDateFilterChanged('today'),
                      icon: Icons.today,
                    ),
                    _buildFilterChip(
                      label: 'هذا الأسبوع',
                      value: 'week',
                      isSelected: selectedDateFilter == 'week',
                      onSelected: () => onDateFilterChanged('week'),
                      icon: Icons.date_range,
                    ),
                    _buildFilterChip(
                      label: 'هذا الشهر',
                      value: 'month',
                      isSelected: selectedDateFilter == 'month',
                      onSelected: () => onDateFilterChanged('month'),
                      icon: Icons.calendar_month,
                    ),
                    _buildFilterChip(
                      label: 'فترة مخصصة',
                      value: 'custom',
                      isSelected: selectedDateFilter == 'custom',
                      onSelected: () => onDateFilterChanged('custom'),
                      icon: Icons.calendar_today,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// بناء شريحة فلتر
  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onSelected,
    IconData? icon,
    Color? color,
  }) {
    final chipColor = color ?? AssyrianTheme.primaryGold;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? chipColor : chipColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected
                    ? chipColor
                    : chipColor.withValues(alpha: 0.7),
                size: 16.sp,
              ),
              SizedBox(width: 4.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? chipColor
                    : chipColor.withValues(alpha: 0.7),
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
