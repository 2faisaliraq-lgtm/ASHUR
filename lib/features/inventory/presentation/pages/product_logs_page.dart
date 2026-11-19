import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../bloc/inventory_bloc.dart';
import '../../domain/entities/product_log_entity.dart';
import '../widgets/product_log_card.dart';

/// صفحة عرض سجل حركة المنتج
class ProductLogsPage extends StatefulWidget {
  const ProductLogsPage({
    required this.productId,
    required this.productName,
    super.key,
  });

  final String productId;
  final String productName;

  @override
  State<ProductLogsPage> createState() => _ProductLogsPageState();
}

class _ProductLogsPageState extends State<ProductLogsPage> {
  String? _selectedType; // 'all', 'sales', 'purchase'

  @override
  void initState() {
    super.initState();
    _loadProductLogs();
  }

  void _loadProductLogs() {
    context.read<InventoryBloc>().add(
          LoadProductLogsEvent(
            productId: widget.productId,
            invoiceType: _selectedType == 'all' ? null : _selectedType,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AssyrianTheme.backgroundGradient,
            boxShadow: [
              BoxShadow(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            AssyrianTheme.getLamassuForBackground(
              isDarkBackground: true,
              hasCircularBackground: false,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سجل حركة المنتج',
                    style: AssyrianTheme.titleStyle.copyWith(
                      fontSize: 18.sp,
                      color: AssyrianTheme.primaryGold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    widget.productName,
                    style: AssyrianTheme.subtitleStyle.copyWith(
                      fontSize: 10.sp,
                      color: AssyrianTheme.ivoryWhite,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadProductLogs,
            icon: Icon(
              Icons.refresh,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is InventoryLoading) {
            return const LoadingWidget();
          }

          if (state is ProductLogsLoaded) {
            return _buildContent(state.logs);
          }

          return const LoadingWidget();
        },
      ),
    );
  }

  Widget _buildContent(List<ProductLogEntity> logs) {
    return Column(
      children: [
        // فلتر نوع الحركة
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFilterChip('الكل', 'all'),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildFilterChip('مبيعات', 'sales'),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildFilterChip('مشتريات', 'purchase'),
              ),
            ],
          ),
        ),
        // قائمة السجلات
        Expanded(
          child: logs.isEmpty
              ? AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'لا توجد سجلات حركة لهذا المنتج',
                  message: 'ستظهر هنا سجلات البيع والشراء للمنتج',
                )
              : ListView.separated(
                  padding: EdgeInsets.all(12.w),
                  itemCount: logs.length,
                  separatorBuilder: (context, index) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ProductLogCard(log: log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedType == value ||
        (_selectedType == null && value == 'all');
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedType = selected ? value : null;
        });
        _loadProductLogs();
      },
      backgroundColor: Colors.white,
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.primaryGold,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

}
