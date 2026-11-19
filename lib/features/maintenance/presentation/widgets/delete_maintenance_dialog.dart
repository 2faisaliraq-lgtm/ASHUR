import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/maintenance_request_entity.dart';
import '../bloc/maintenance_bloc.dart';

/// نافذة حوار حذف طلب الصيانة
// ignore: avoid_classes_with_only_static_members
class DeleteMaintenanceDialog {
  /// عرض نافذة حوار الحذف
  static Future<void> show(
    BuildContext context,
    MaintenanceRequestEntity maintenanceRequest,
    MaintenanceBloc maintenanceBloc, {
    VoidCallback? onDeleted,
  }) {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف طلب الصيانة',
      itemName: maintenanceRequest.title,
      description: maintenanceRequest.description.isNotEmpty
          ? maintenanceRequest.description
          : null,
      icon: Icons.build,
      onConfirm: () => _confirmDelete(
        context,
        maintenanceRequest,
        maintenanceBloc,
        onDeleted,
      ),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    MaintenanceRequestEntity maintenanceRequest,
    MaintenanceBloc maintenanceBloc,
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
      message: 'جاري حذف طلب الصيانة',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    try {
      // تنفيذ عملية الحذف مباشرة من الـ repository
      final repository = maintenanceBloc.repository;
      final result = await repository.deleteMaintenanceRequest(
        maintenanceRequest.id,
        currentUser.email!,
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
                content: const Text('تم حذف طلب الصيانة بنجاح'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }

          // استدعاء callback إذا كان متوفراً
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
