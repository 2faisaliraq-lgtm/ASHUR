import 'package:material_ui/material_ui.dart';

import '../../domain/entities/subscription_entity.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import 'subscription_card.dart';
/// شبكة الاشتراكات
class SubscriptionsGrid extends StatelessWidget {

  const SubscriptionsGrid({
    required this.subscriptions, required this.onSubscriptionTap, super.key,
    this.isGridView = false,
  });
  final List<SubscriptionEntity> subscriptions;
  final Function(SubscriptionEntity) onSubscriptionTap;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (subscriptions.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.subscriptions_outlined,
          title: 'لا توجد اشتراكات',
          message: 'ابدأ بإضافة اشتراك جديد',
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
          final subscription = subscriptions[index];
          return SubscriptionCard(
            subscription: subscription,
            onTap: () => onSubscriptionTap(subscription),
          );
        }, childCount: subscriptions.length),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final subscription = subscriptions[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SubscriptionCard(
              subscription: subscription,
              onTap: () => onSubscriptionTap(subscription),
              isListView: true,
            ),
          );
        }, childCount: subscriptions.length),
      ),
    );
  }
}
