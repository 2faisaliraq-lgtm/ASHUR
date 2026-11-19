import 'package:material_ui/material_ui.dart';

import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/customer_entity.dart';
import '../bloc/customer_bloc.dart';

/// نافذة حوار حذف العميل
// ignore: avoid_classes_with_only_static_members
class DeleteCustomerDialog {
  /// عرض نافذة حوار الحذف
  static Future<void> show(
    BuildContext context,
    CustomerEntity customer,
    CustomerBloc customerBloc, {
    VoidCallback? onDeleted,
  }) async {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف العميل',
      itemName: customer.name,
      description: 'هل أنت متأكد من حذف هذا العميل؟',
      warningMessage: 'تحذير: لا يمكن التراجع عن هذا الإجراء',
      icon: Icons.person,
      iconColor: Colors.blue,
      onConfirm: () =>
          _confirmDelete(context, customer, customerBloc, onDeleted),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    CustomerEntity customer,
    CustomerBloc customerBloc,
    VoidCallback? onDeleted,
  ) async {
    // حفظ Navigator قبل إغلاق حوار التأكيد
    final navigator = Navigator.of(context);

    // عرض حوار التحميل باستخدام LoadingWidget الموحد
    LoadingWidget.showLoadingDialog(
      context,
      message: 'جاري حذف العميل',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    try {
      // فحص صلاحية حذف العملاء
      final permissionChecker = PermissionChecker();
      final hasDeletePermission = await permissionChecker.hasPermission(
        'customers_delete',
      );
      if (!hasDeletePermission) {
        if (navigator.canPop()) {
          navigator.pop();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('ليس لديك صلاحية لحذف العملاء'),
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
      final repository = customerBloc.repository;
      final result = await repository.deleteCustomer(
        customer.id,
        customer.organizationEmail,
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
                content: const Text('تم حذف العميل بنجاح'),
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
