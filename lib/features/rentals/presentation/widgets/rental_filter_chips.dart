import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/assyrian_theme.dart';

class RentalFilterChips extends StatelessWidget {
  const RentalFilterChips({
    required this.onStatusChanged,
    super.key,
    this.selectedStatus,
  });
  final String? selectedStatus;
  final Function(String?) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('الكل', null, selectedStatus, onStatusChanged),
          _buildFilterChip('نشطة', 'active', selectedStatus, onStatusChanged),
          _buildFilterChip(
            'منتهية',
            'expired',
            selectedStatus,
            onStatusChanged,
          ),
          _buildFilterChip(
            'ملغية',
            'terminated',
            selectedStatus,
            onStatusChanged,
          ),
          _buildFilterChip(
            'قيد الانتظار',
            'pending',
            selectedStatus,
            onStatusChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String? value,
    String? selectedValue,
    Function(String?) onChanged,
  ) {
    final isSelected = selectedValue == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        key: ValueKey('filter_$label'),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        selected: isSelected,
        onSelected: (selected) => onChanged(selected ? value : null),
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
