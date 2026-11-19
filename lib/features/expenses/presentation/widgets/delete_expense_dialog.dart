import 'package:material_ui/material_ui.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';

/// نافذة حوار حذف المصروف
// ignore: avoid_classes_with_only_static_members
class DeleteExpenseDialog {
  /// عرض نافذة حوار الحذف
  static Future<void> show(
    BuildContext context,
    ExpenseEntity expense,
    ExpenseBloc expenseBloc, {
    VoidCallback? onDeleted,
  }) async {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف المصروف',
      itemName: expense.title,
      description: 'هل أنت متأكد من حذف هذا المصروف؟',
      warningMessage: 'تحذير: لا يمكن التراجع عن هذا الإجراء',
      icon: Icons.money_off,
      iconColor: Colors.orange,
      onConfirm: () => _confirmDelete(context, expense, expenseBloc, onDeleted),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    ExpenseEntity expense,
    ExpenseBloc expenseBloc,
    VoidCallback? onDeleted,
  ) async {
    // حفظ Navigator قبل إغلاق حوار التأكيد
    final navigator = Navigator.of(context);

    // عرض حوار التحميل باستخدام LoadingWidget الموحد
    LoadingWidget.showLoadingDialog(
      context,
      message: 'جاري حذف المصروف',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    try {
      // 🔒 التحقق من صلاحية الحذف قبل تنفيذها — الحذف
      // يُنفَّذ من هذا الحوار مباشرة (متجاوزاً معالج
      // الـ BLoC الذي يحمل نفس التحقق لكنه لا يُستدعى
      // أبداً)، فالتحقق هنا يمنع حذف من ليس لديه
      // صلاحية expenses_delete (مثل مستخدم لديه
      // صلاحية التعديل فقط) — بنفس تحقق صفحة
      // القائمة ومعالج الـ BLoC.
      final permissionChecker = PermissionChecker();
      final hasDeletePermission =
          await permissionChecker.hasPermission('expenses_delete');

      if (!hasDeletePermission) {
        // إغلاق حوار التحميل
        if (navigator.canPop()) {
          navigator.pop();
        }

        // انتظار قصير للتأكد من إغلاق الحوار
        await Future.delayed(const Duration(milliseconds: 100));

        // عرض رسالة الخطأ
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('ليس لديك صلاحية لحذف المصاريف'),
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

      // استدعاء الحذف مباشرة من الـ repository
      final repository = expenseBloc.repository;
      final result = await repository.deleteExpense(
        expense.id,
        expense.organizationEmail,
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
                content: const Text('تم حذف المصروف بنجاح'),
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
