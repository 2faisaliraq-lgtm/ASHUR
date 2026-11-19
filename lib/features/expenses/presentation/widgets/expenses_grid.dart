import 'package:material_ui/material_ui.dart';

import '../../domain/entities/expense_entity.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import 'expense_card.dart';
/// شبكة المصاريف
class ExpensesGrid extends StatelessWidget {

  const ExpensesGrid({
    required this.expenses, required this.onExpenseTap, super.key,
    this.isGridView = false,
  });
  final List<ExpenseEntity> expenses;
  final Function(ExpenseEntity) onExpenseTap;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'لا توجد مصاريف',
          message: 'ابدأ بإضافة مصروف جديد',
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
          final expense = expenses[index];
          return ExpenseCard(
            expense: expense,
            onTap: () => onExpenseTap(expense),
            isListView: false,
          );
        }, childCount: expenses.length),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final expense = expenses[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ExpenseCard(
              expense: expense,
              onTap: () => onExpenseTap(expense),
            ),
          );
        }, childCount: expenses.length),
      ),
    );
  }
}
