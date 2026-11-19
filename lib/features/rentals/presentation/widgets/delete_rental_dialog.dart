import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/rental_entity.dart';
import '../bloc/rental_bloc.dart';

/// نافذة حوار حذف الإيجار
// ignore: avoid_classes_with_only_static_members
class DeleteRentalDialog {
  /// عرض نافذة حوار الحذف
  static Future<void> show(
    BuildContext context,
    RentalEntity rental,
    RentalBloc rentalBloc, {
    VoidCallback? onDeleted,
  }) {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف عقد الإيجار',
      itemName: rental.itemName,
      description:
          'المستأجر: ${rental.renterName}\nسعر الإيجار: ${rental.rentalPrice}',
      icon: Icons.home,
      iconColor: Colors.teal,
      onConfirm: () => _confirmDelete(context, rental, rentalBloc, onDeleted),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    RentalEntity rental,
    RentalBloc rentalBloc,
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
      message: 'جاري حذف عقد الإيجار',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    try {
      // تنفيذ عملية الحذف مباشرة من الـ repository
      final repository = rentalBloc.repository;
      final result = await repository.deleteRental(
        rental.id,
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
          // ===== ملاحظة للمبرمجين المستقبليين (تحقق 2026-10-12) =====
          // لماذا يُكتب السجل والإشعار هنا وليس في الـ BLoC؟
          // لأن الحذف يتم من هذا الحوار مباشرة إلى المستودع
          // (deleteRental — معاملة ذرية: حذف العقد + تحرير
          // الوحدة) متجاوزاً حدث DeleteRentalEvent الذي لا
          // تُصدره أي صفحة حالياً. لذا تُكتب التأثيرات
          // الجانبية هنا لتطابق الإنشاء والتعديل (سجل
          // تدقيق + إشعار) — وهي fire-and-forget عمداً:
          // فشلها لا يتراجع عن الحذف ولا يمس رسالة النجاح.
          // (نفس قاعدة الذرية الموثقة في rental_bloc.dart)
          // ===============================================
          // تسجيل العملية في السجل (تأثير جانبي متعمد
          // خارج معاملة الحذف — انظر ملاحظة الذرية أعلاه)
          unawaited(
            rentalBloc.repository.addRentalLog(
              userId: 'current_user',
              actionType: 'delete_rental',
              details: 'تم حذف عقد الإيجار',
              targetId: rental.id,
              targetType: 'rental',
            ),
          );

          // إرسال إشعار تنظيمي بحذف عقد الإيجار
          final deleteRentalActorEmail = currentUser.email ?? '';
          if (deleteRentalActorEmail.isNotEmpty) {
            unawaited(() async {
              try {
                final isSectionEnabled =
                    await SectionNotificationService.isSectionNotificationsEnabled(
                  'rentals',
                );
                if (!isSectionEnabled) return;
                final isTypeEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                  'rental_notify_deleted',
                );
                if (!isTypeEnabled) return;
                await PushNotificationService.sendOrganizationNotification(
                  organizationEmail: rental.organizationEmail,
                  title: '🗑️ حذف عقد إيجار',
                  body: 'تم حذف عقد إيجار من النظام',
                  type: 'rental_deleted',
                  actorEmail: deleteRentalActorEmail,
                  data: {'rentalId': rental.id},
                );
              } on Exception catch (e) {
                debugPrint('Failed to send rental_deleted notification: $e');
              }
            }());
          }

          // عرض رسالة النجاح
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم حذف عقد الإيجار بنجاح'),
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
