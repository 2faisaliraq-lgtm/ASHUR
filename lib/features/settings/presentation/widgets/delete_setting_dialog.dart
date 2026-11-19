import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/setting_entity.dart';
import '../bloc/setting_bloc.dart';

/// نافذة حوار حذف الإعداد
// ignore: avoid_classes_with_only_static_members
class DeleteSettingDialog {
  /// عرض نافذة حوار الحذف
  static Future<void> show(
    BuildContext context,
    SettingEntity setting,
    SettingBloc settingBloc, {
    VoidCallback? onDeleted,
  }) {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف الإعداد',
      itemName: setting.key,
      description: setting.description?.isNotEmpty ?? false
          ? setting.description
          : 'القيمة: ${setting.value}',
      icon: Icons.settings,
      iconColor: Colors.grey,
      warningMessage: 'تحذير: حذف الإعداد قد يؤثر على سلوك التطبيق',
      onConfirm: () => _confirmDelete(context, setting, settingBloc, onDeleted),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    SettingEntity setting,
    SettingBloc settingBloc,
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
      message: 'جاري حذف الإعداد',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    // تنفيذ عملية الحذف عبر BLoC
    settingBloc.add(
      DeleteSettingEvent(
        settingId: setting.id,
        organizationEmail: currentUser.email!,
      ),
    );

    // انتظار نجاح العملية أو فشلها
    bool completed = false;
    final subscription = settingBloc.stream.listen((state) {
      if (completed) return;

      if (state is SettingError) {
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
      } else if (state is SettingOperationSuccess) {
        completed = true;
        // إغلاق حوار التحميل
        if (navigator.canPop()) navigator.pop();

        // عرض رسالة النجاح
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم حذف الإعداد بنجاح'),
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

    // إلغاء الاشتراك بعد فترة زمنية
    await Future.delayed(const Duration(seconds: 10));
    subscription.cancel();
  }
}
