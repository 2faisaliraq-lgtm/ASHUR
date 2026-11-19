import 'package:material_ui/material_ui.dart';

import '../../domain/entities/rental_entity.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import 'rental_card.dart';
class RentalsGrid extends StatelessWidget {

  const RentalsGrid({
    required this.rentals, required this.onRentalTap, super.key,
    this.isGridView = false,
  });
  final List<RentalEntity> rentals;
  final Function(RentalEntity) onRentalTap;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (rentals.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.home_work_outlined,
          title: 'لا توجد إيجارات',
          message: 'ابدأ بإضافة عقد إيجار جديد',
        ),
      );
    }

    if (isGridView) {
      return _buildGridView();
    } else {
      return _buildListView();
    }
  }

  Widget _buildGridView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final rental = rentals[index];
          return RentalCard(
            rental: rental,
            onTap: () => onRentalTap(rental),
            isListView: false,
          );
        }, childCount: rentals.length),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final rental = rentals[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: RentalCard(
              rental: rental,
              onTap: () => onRentalTap(rental),
            ),
          );
        }, childCount: rentals.length),
      ),
    );
  }
}
