import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/assyrian_theme.dart';

/// شريط البحث في التقارير
class ReportSearchBar extends StatelessWidget {

  const ReportSearchBar({required this.onSearch, super.key, this.controller});
  final Function(String) onSearch;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onSearch,
      decoration: InputDecoration(
        hintText: 'بحث في التقارير...',
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
