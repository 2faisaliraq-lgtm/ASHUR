import 'package:material_ui/material_ui.dart';

import '../../domain/entities/customer_entity.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import 'customer_card.dart';

class CustomersGrid extends StatelessWidget {
  const CustomersGrid({
    required this.customers,
    required this.onCustomerTap,
    required this.isGridView,
    super.key,
  });
  final List<CustomerEntity> customers;
  final Function(CustomerEntity) onCustomerTap;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.people_outline,
          title: 'لا يوجد عملاء',
          message: 'ابدأ بإضافة عميل جديد',
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
          final customer = customers[index];
          return CustomerCard(
            customer: customer,
            onTap: () => onCustomerTap(customer),
            isListView: false,
          );
        }, childCount: customers.length),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final customer = customers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CustomerCard(
              customer: customer,
              onTap: () => onCustomerTap(customer),
            ),
          );
        }, childCount: customers.length),
      ),
    );
  }
}
