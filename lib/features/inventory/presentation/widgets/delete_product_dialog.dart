import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/inventory_bloc.dart';

/// نافذة حوار حذف المنتج
// ignore: avoid_classes_with_only_static_members
class DeleteProductDialog {
  /// عرض نافذة حوار الحذف
  static Future<void> show(
    BuildContext context,
    ProductEntity product,
    InventoryBloc inventoryBloc, {
    VoidCallback? onDeleted,
  }) async {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف المنتج',
      itemName: product.name,
      description: 'هل أنت متأكد من حذف هذا المنتج؟',
      warningMessage: 'تحذير: لا يمكن التراجع عن هذا الإجراء',
      icon: Icons.inventory_2,
      iconColor: Colors.blue,
      onConfirm: () =>
          _confirmDelete(context, product, inventoryBloc, onDeleted),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    ProductEntity product,
    InventoryBloc inventoryBloc,
    VoidCallback? onDeleted,
  ) async {
    // حفظ Navigator قبل إغلاق حوار التأكيد
    final navigator = Navigator.of(context);

    // عرض حوار التحميل باستخدام LoadingWidget الموحد
    LoadingWidget.showLoadingDialog(
      context,
      message: 'جاري حذف المنتج',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    try {
      // استدعاء الحذف مباشرة من الـ repository
      // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا الاستدعاء يتجاوز bloc ويتصل
      // بالمستودع مباشرة، مما يتجاوز فحص الصلاحية ('inventory_delete')
      // وتسجيل التدقيق الذي يُنفَّذ في _onDeleteProduct داخل البلوك.
      // يُنصح بإرسال DeleteProductEvent عبر البلوك بدلاً من استدعاء
      // repository مباشرة لتحقيق الاتساق والأمان.
      final repository = inventoryBloc.repository;
      final result = await repository.deleteProduct(
        id: product.id,
        organizationEmail: product.organizationEmail,
      );

      // إغلاق حوار التحميل
      if (navigator.canPop()) {
        navigator.pop();
      }

      // انتظار قصير للتأكد من إغلاق الحوار
      await Future.delayed(const Duration(milliseconds: 100));

      result.fold(
        (failure) {
          // عرض رسالة الخطأ
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failure.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        },
        (_) {
          // عرض رسالة النجاح
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم حذف المنتج بنجاح'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }

          // استدعاء callback مع تأخير صغير للتأكد من إغلاق الحوار
          if (onDeleted != null) {
            Future.delayed(const Duration(milliseconds: 100), () {
              onDeleted();
            });
          }
        },
      );
    } on Exception catch (e) {
      // إغلاق حوار التحميل
      if (navigator.canPop()) {
        navigator.pop();
      }

      // انتظار قصير للتأكد من إغلاق الحوار
      await Future.delayed(const Duration(milliseconds: 100));

      // عرض رسالة خطأ
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}
