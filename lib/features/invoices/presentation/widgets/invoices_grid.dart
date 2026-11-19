import 'package:material_ui/material_ui.dart';
import '../../domain/entities/invoice_entity.dart';
import 'invoice_card.dart';
import '../../../../core/widgets/empty_state_widget.dart';

/// شبكة الفواتير
class InvoicesGrid extends StatelessWidget {

  const InvoicesGrid({
    required this.invoices, required this.onInvoiceTap, super.key,
    this.isGridView = false,
  });
  final List<InvoiceEntity> invoices;
  final Function(InvoiceEntity) onInvoiceTap;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'لا توجد فواتير',
          message: 'ابدأ بإضافة فاتورة جديدة',
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
          final invoice = invoices[index];
          return InvoiceCard(
            invoice: invoice,
            onTap: () => onInvoiceTap(invoice),
            isListView: false,
          );
        }, childCount: invoices.length),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final invoice = invoices[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: InvoiceCard(
              invoice: invoice,
              onTap: () => onInvoiceTap(invoice),
            ),
          );
        }, childCount: invoices.length),
      ),
    );
  }
}
