import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/assyrian_theme.dart';

/// رقائق تصفية الاشتراكات
class SubscriptionFilterChips extends StatelessWidget {
  const SubscriptionFilterChips({
    required this.selectedStatus,
    required this.selectedType,
    required this.subscriptionTypes,
    required this.onStatusChanged,
    required this.onTypeChanged,
    super.key,
  });
  final String? selectedStatus;
  final String? selectedType;
  final List<String> subscriptionTypes;
  final Function(String?) onStatusChanged;
  final Function(String?) onTypeChanged;

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
            'على وشك الانتهاء',
            'expiring_soon',
            selectedStatus,
            onStatusChanged,
          ),
          _buildFilterChip(
            'ملغية',
            'cancelled',
            selectedStatus,
            onStatusChanged,
          ),
          _buildFilterChip(
            'معلقة',
            'suspended',
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
