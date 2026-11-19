import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/assyrian_theme.dart';

class CustomerFilterChips extends StatefulWidget {
  const CustomerFilterChips({
    required this.onFilterChanged,
    super.key,
    this.selectedFilter,
  });
  final String? selectedFilter;
  final Function(String?) onFilterChanged;

  @override
  State<CustomerFilterChips> createState() => _CustomerFilterChipsState();
}

class _CustomerFilterChipsState extends State<CustomerFilterChips> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('الكل', null),
          _buildChip('نشط', 'active'),
          _buildChip('غير نشط', 'inactive'),
          _buildChip('محظور', 'blocked'),
          _buildChip('أفراد', 'individual'),
          _buildChip('شركات', 'company'),
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
