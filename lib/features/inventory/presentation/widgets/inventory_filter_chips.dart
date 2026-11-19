import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/inventory_bloc.dart';

/// رقائق فلترة المخزون
class InventoryFilterChips extends StatelessWidget {
  const InventoryFilterChips({
    required this.categories,
    required this.onCategoryChanged,
    required this.onStockFilterChanged,
    super.key,
    this.selectedCategoryId,
    this.stockFilter,
  });
  final List<CategoryEntity> categories;
  final String? selectedCategoryId;
  final StockFilter? stockFilter;
  final Function(String?) onCategoryChanged;
  final Function(StockFilter?) onStockFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // فلاتر الفئات
          _buildFilterChip('الكل', null, selectedCategoryId, onCategoryChanged),
          ...categories.map(
            (category) => _buildFilterChip(
              category.name,
              category.id,
              selectedCategoryId,
              onCategoryChanged,
            ),
          ),
          const SizedBox(width: 16),
          // فلاتر حالة المخزون
          _buildStockFilterChip(
            'متوفر',
            StockFilter.inStock,
            stockFilter,
            onStockFilterChanged,
          ),
          _buildStockFilterChip(
            'مخزون منخفض',
            StockFilter.lowStock,
            stockFilter,
            onStockFilterChanged,
          ),
          _buildStockFilterChip(
            'نافد',
            StockFilter.outOfStock,
            stockFilter,
            onStockFilterChanged,
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

  Widget _buildStockFilterChip(
    String label,
    StockFilter value,
    StockFilter? selectedValue,
    Function(StockFilter?) onChanged,
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
