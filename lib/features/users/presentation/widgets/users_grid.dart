import 'package:material_ui/material_ui.dart';

import '../../domain/entities/user_management_entity.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import 'user_card.dart';

class UsersGrid extends StatelessWidget {
  const UsersGrid({
    required this.users,
    required this.onUserTap,
    super.key,
    this.isGridView = false,
  });
  final List<UserManagementEntity> users;
  final Function(UserManagementEntity) onUserTap;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.people_outline,
          title: 'لا يوجد مستخدمين',
          message: 'ابدأ بإضافة مستخدم جديد',
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
          final user = users[index];
          return UserCard(
            user: user,
            onTap: () => onUserTap(user),
            isListView: false,
          );
        }, childCount: users.length),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final user = users[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: UserCard(user: user, onTap: () => onUserTap(user)),
          );
        }, childCount: users.length),
      ),
    );
  }
}
