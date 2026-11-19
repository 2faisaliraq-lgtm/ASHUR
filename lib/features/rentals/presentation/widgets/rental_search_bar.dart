import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/assyrian_theme.dart';

class RentalSearchBar extends StatelessWidget {

  const RentalSearchBar({required this.onSearch, super.key});
  final Function(String) onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onSearch,
      decoration: InputDecoration(
        hintText: 'بحث في عقود الإيجار...',
        prefixIcon: const Icon(Icons.search, color: AssyrianTheme.primaryGold),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AssyrianTheme.primaryGold, width: 2),
        ),
      ),
    );
  }
}
