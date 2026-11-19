import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/assyrian_theme.dart';

class MaintenanceFilterChips extends StatelessWidget {
  const MaintenanceFilterChips({
    required this.onStatusChanged,
    required this.onPriorityChanged,
    super.key,
    this.selectedStatus,
    this.selectedPriority,
  });
  final String? selectedStatus;
  final String? selectedPriority;
  final Function(String?) onStatusChanged;
  final Function(String?) onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('الكل', null, selectedStatus, onStatusChanged),
          _buildFilterChip(
            'قيد الانتظار',
            'pending',
            selectedStatus,
            onStatusChanged,
          ),
          _buildFilterChip(
            'قيد التنفيذ',
            'in_progress',
            selectedStatus,
            onStatusChanged,
          ),
          _buildFilterChip(
            'مكتملة',
            'completed',
            selectedStatus,
            onStatusChanged,
          ),
          const SizedBox(width: 16),
          _buildFilterChip(
            'عادي',
            'medium',
            selectedPriority,
            onPriorityChanged,
          ),
          _buildFilterChip(
            'عاجل',
            'urgent',
            selectedPriority,
            onPriorityChanged,
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
