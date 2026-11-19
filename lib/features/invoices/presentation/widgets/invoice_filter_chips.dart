import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/assyrian_theme.dart';

/// رقائق تصفية الفواتير
class InvoiceFilterChips extends StatelessWidget {
  const InvoiceFilterChips({
    required this.selectedFilter,
    required this.onFilterChanged,
    super.key,
  });
  final String? selectedFilter;
  final Function(String?) onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('الكل', null),
          _buildFilterChip('مدفوعة', 'paid'),
          _buildFilterChip('جزئية', 'partial'),
          _buildFilterChip('غير مدفوعة', 'unpaid'),
          _buildFilterChip('ملغية', 'cancelled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        key: ValueKey('filter_$label'),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        selected: isSelected,
        onSelected: (selected) => onFilterChanged(selected ? value : null),
        backgroundColor: Colors.white,
        selectedColor: const Color(0x33FFD700),
        checkmarkColor: AssyrianTheme.primaryGold,
        labelStyle: TextStyle(
          color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected
              ? AssyrianTheme.primaryGold
              : const Color(0x4DCCCCCC),
        ),
      ),
    );
  }
}
