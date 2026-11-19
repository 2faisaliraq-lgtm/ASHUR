import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/inventory_bloc.dart';

/// نافذة حوار حذف الفئة
// ignore: avoid_classes_with_only_static_members
class DeleteCategoryDialog {
  /// عرض نافذة حوار الحذف
  static Future<void> show(
    BuildContext context,
    CategoryEntity category,
    InventoryBloc inventoryBloc, {
    VoidCallback? onDeleted,
  }) {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف الفئة',
      itemName: category.name,
      description: category.description?.isNotEmpty ?? false
          ? category.description
          : null,
      icon: Icons.category,
      iconColor: Colors.amber,
      warningMessage: 'تحذير: حذف الفئة سيؤثر على جميع المنتجات المرتبطة بها',
      onConfirm: () =>
          _confirmDelete(context, category, inventoryBloc, onDeleted),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    CategoryEntity category,
    InventoryBloc inventoryBloc,
    VoidCallback? onDeleted,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('خطأ في المصادقة'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      return;
    }

    // حفظ Navigator قبل إغلاق حوار التأكيد
    final navigator = Navigator.of(context);

    // عرض حوار التحميل باستخدام LoadingWidget الموحد
    LoadingWidget.showLoadingDialog(
      context,
      message: 'جاري حذف الفئة',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    // تنفيذ عملية الحذف عبر BLoC
    inventoryBloc.add(
      DeleteCategoryEvent(
        categoryId: category.id,
        organizationEmail: currentUser.email!,
      ),
    );

    // انتظار نجاح العملية أو فشلها
    bool completed = false;
    final subscription = inventoryBloc.stream.listen((state) {
      if (completed) return;

      if (state is InventoryError) {
        completed = true;
        // إغلاق حوار التحميل
        if (navigator.canPop()) navigator.pop();

        // عرض رسالة الخطأ
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else if (state is InventoryOperationSuccess) {
        completed = true;
        // إغلاق حوار التحميل
        if (navigator.canPop()) navigator.pop();

        // عرض رسالة النجاح
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم حذف الفئة بنجاح'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }

        // استدعاء callback إذا كان متوفراً
        if (onDeleted != null) onDeleted();
      }
    });

    // ⚠️ ملاحظة للمبرمجين المستقبليين: يتم إلغاء الاشتراك بعد 10 ثوانٍ
    // بغض النظر عن whether اكتملت العملية أم لا. إذا استغرقت عملية الحذف
    // أكثر من 10 ثوانٍ، لن يتلقى المستخدم أي تعليق (نجاح أو فشل). يُنصح
    // بإلغاء الاشتراك فقط عند استقبال حالة InventoryError أو
    // InventoryOperationSuccess، أو استخدام Completer مع timeout مناسب.
    await Future.delayed(const Duration(seconds: 10));
    subscription.cancel();
  }
}
