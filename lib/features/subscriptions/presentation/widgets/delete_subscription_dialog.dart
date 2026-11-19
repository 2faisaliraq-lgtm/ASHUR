import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/subscription_entity.dart';
import '../bloc/subscription_bloc.dart';

// ignore: avoid_classes_with_only_static_members
class DeleteSubscriptionDialog {
  static Future<void> show(
    BuildContext context,
    SubscriptionEntity subscriptionEntity,
    SubscriptionBloc subscriptionBloc, {
    VoidCallback? onDeleted,
  }) async {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف الاشتراك',
      itemName: subscriptionEntity.name,
      description: 'هل أنت متأكد من حذف هذا الاشتراك؟',
      warningMessage: 'تحذير: لا يمكن التراجع عن هذا الإجراء',
      icon: Icons.subscriptions,
      iconColor: Colors.orange,
      onConfirm: () => _confirmDelete(
        context,
        subscriptionEntity,
        subscriptionBloc,
        onDeleted,
      ),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    SubscriptionEntity subscriptionEntity,
    SubscriptionBloc subscriptionBloc,
    VoidCallback? onDeleted,
  ) async {
    // حفظ Navigator قبل إغلاق حوار التأكيد
    final navigator = Navigator.of(context);

    // عرض حوار التحميل باستخدام LoadingWidget الموحد
    LoadingWidget.showLoadingDialog(
      context,
      message: 'جاري حذف الاشتراك',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    try {
      // استدعاء الحذف مباشرة من الـ repository
      final repository = subscriptionBloc.repository;
      final result = await repository.deleteSubscription(subscriptionEntity.id);

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
          // تسجيل العملية في السجل
          // ⚠️ ملاحظة توثيقية للمبرمجين المستقبليين: userId يُمرّر كنص ثابت
          // 'current_user' بدلاً من معرّف المستخدم الفعلي من FirebaseAuth أو SessionService.
          // يُنصح باستبداله بـ FirebaseAuth.instance.currentUser?.uid ?? 'unknown'
          // لضمان دقة السجل أو الجدي.
          // ignore: unawaited_futures
          repository.addSubscriptionLog(
            userId: 'current_user',
            actionType: 'delete_subscription',
            details: 'تم حذف الاشتراك',
            targetId: subscriptionEntity.id,
            targetType: 'subscription',
          );

          // عرض رسالة النجاح
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم حذف الاشتراك بنجاح'),
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
