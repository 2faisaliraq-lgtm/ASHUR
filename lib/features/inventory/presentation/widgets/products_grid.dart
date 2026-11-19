import 'package:material_ui/material_ui.dart';

import '../../domain/entities/inventory_movement_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import 'product_card.dart';

/// شبكة المنتجات
class ProductsGrid extends StatelessWidget {
  const ProductsGrid({
    required this.products,
    required this.onProductTap,
    required this.onQuantityUpdate,
    super.key,
    this.isGridView = false,
  });
  final List<ProductEntity> products;
  final Function(ProductEntity) onProductTap;
  final Function(String, double, MovementType, String?) onQuantityUpdate;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'لا توجد منتجات',
          message: 'ابدأ بإضافة منتج جديد',
        ),
      );
    }

    // عرض المنتجات
    return isGridView ? _buildGridView(context) : _buildListView(context);
  }

  Widget _buildGridView(BuildContext context) {
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
          final product = products[index];
          return ProductCard(
            product: product,
            onTap: () => onProductTap(product),
            onQuantityUpdate: (newQuantity, movementType, reason) {
              onQuantityUpdate(product.id, newQuantity, movementType, reason);
            },
            isListView: false,
          );
        }, childCount: products.length),
      ),
    );
  }

  Widget _buildListView(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = products[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ProductCard(
              product: product,
              onTap: () => onProductTap(product),
              onQuantityUpdate: (newQuantity, movementType, reason) {
                onQuantityUpdate(product.id, newQuantity, movementType, reason);
              },
            ),
          );
        }, childCount: products.length),
      ),
    );
  }

}
