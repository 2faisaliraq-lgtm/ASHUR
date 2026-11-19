import 'package:material_ui/material_ui.dart';
import '../../domain/entities/maintenance_request_entity.dart';
import 'maintenance_card.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class MaintenanceRequestsGrid extends StatelessWidget {

  const MaintenanceRequestsGrid({
    required this.requests, required this.onRequestTap, super.key,
    this.isGridView = false,
  });
  final List<MaintenanceRequestEntity> requests;
  final Function(MaintenanceRequestEntity) onRequestTap;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.build_outlined,
          title: 'لا توجد طلبات صيانة',
          message: 'ابدأ بإضافة طلب صيانة جديد',
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
          final request = requests[index];
          return MaintenanceCard(
            request: request,
            onTap: () => onRequestTap(request),
            isListView: false,
          );
        }, childCount: requests.length),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final request = requests[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: MaintenanceCard(
              request: request,
              onTap: () => onRequestTap(request),
            ),
          );
        }, childCount: requests.length),
      ),
    );
  }
}
