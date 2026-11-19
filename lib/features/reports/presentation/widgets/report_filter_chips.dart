import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/assyrian_theme.dart';

class ReportFilterChips extends StatefulWidget {
  const ReportFilterChips({
    required this.selectedFilter,
    required this.onFilterChanged,
    super.key,
  });
  final String? selectedFilter;
  final Function(String?) onFilterChanged;

  @override
  State<ReportFilterChips> createState() => _ReportFilterChipsState();
}

class _ReportFilterChipsState extends State<ReportFilterChips> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('الكل', null),
          _buildChip('قيد الانتظار', 'pending'),
          _buildChip('مكتملة', 'completed'),
          _buildChip('فاشلة', 'failed'),
          _buildChip('مالية', 'financial'),
          _buildChip('مخزون', 'inventory'),
          _buildChip('مبيعات', 'sales'),
          _buildChip('مصاريف', 'expenses'), // ⚠️ أُضيف لتطابق صفحة قائمة التقارير
        ],
      ),
    );
  }

  Widget _buildChip(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: _FilterChipWidget(
        label: label,
        value: value,
        isSelected: widget.selectedFilter == value,
        onSelected: (selected) =>
            widget.onFilterChanged(selected ? value : null),
      ),
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  const _FilterChipWidget({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final String? value;
  final bool isSelected;
  final Function(bool) onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 14, height: 1)),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Colors.white,
      selectedColor: const Color(0x33FFD700),
      checkmarkColor: AssyrianTheme.primaryGold,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        height: 1,
      ),
      side: BorderSide(
        color: isSelected ? AssyrianTheme.primaryGold : const Color(0x4DCCCCCC),
        width: 1.5,
      ),
    );
  }
}
