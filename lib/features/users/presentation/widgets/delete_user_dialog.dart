import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/user_management_entity.dart';
import '../bloc/users_bloc.dart';

// ignore: avoid_classes_with_only_static_members
class DeleteUserDialog {
  static Future<void> show(
    BuildContext context,
    UserManagementEntity user,
    UsersBloc usersBloc, {
    VoidCallback? onDeleted,
  }) async {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف المستخدم',
      itemName: user.name ?? user.email ?? 'مستخدم غير معروف',
      description: 'هل أنت متأكد من حذف هذا المستخدم؟',
      warningMessage: 'تحذير: لا يمكن التراجع عن هذا الإجراء',
      icon: Icons.person,
      onConfirm: () => _confirmDelete(context, user, usersBloc, onDeleted),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    UserManagementEntity user,
    UsersBloc usersBloc,
    VoidCallback? onDeleted,
  ) async {
    // حفظ Navigator قبل إغلاق حوار التأكيد
    final navigator = Navigator.of(context);

    // عرض حوار التحميل باستخدام LoadingWidget الموحد
    LoadingWidget.showLoadingDialog(
      context,
      message: 'جاري حذف المستخدم',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    try {
      // استدعاء الحذف مباشرة من الـ repository
      final repository = usersBloc.repository;
      final result = await repository.deleteUser(user.id);

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
                content: const Text('تم حذف المستخدم بنجاح'),
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
