import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/delete_confirmation_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/report_entity.dart';
import '../bloc/report_bloc.dart';

/// نافذة حوار حذف التقرير
// ignore: avoid_classes_with_only_static_members
class DeleteReportDialog {
  /// عرض نافذة حوار الحذف
  static Future<void> show(
    BuildContext context,
    ReportEntity report,
    ReportBloc reportBloc, {
    VoidCallback? onDeleted,
  }) {
    return DeleteConfirmationDialog.show(
      context,
      title: 'حذف التقرير',
      itemName: report.title,
      description: report.description.isNotEmpty
          ? report.description
          : 'النوع: ${report.type}',
      icon: Icons.assessment,
      iconColor: Colors.brown,
      onConfirm: () => _confirmDelete(context, report, reportBloc, onDeleted),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    ReportEntity report,
    ReportBloc reportBloc,
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
      message: 'جاري حذف التقرير',
      subtitle: 'الرجاء الانتظار ولا تغلق هذه النافذة...',
      icon: Icons.delete_forever,
      iconColor: Colors.red,
    );

    try {
      // تنفيذ الحذف مباشرة من الـ repository (لا عبر BLoC) — حذف
      // مستند واحد فذرية بطبيعته في Firestore (انظر سجل الذرية في
      // report_repository_impl.dart)، ولذلك يُوثَّق سجل الحذف هنا أيضاً.
      final repository = reportBloc.repository;
      final result = await repository.deleteReport(
        report.id,
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
          // تسجيل الحذف في سجل التدقيق — منفصل ومُحسَّن الجهد
          // (unawaited): فشل السجل لا يعطل الحذف (نفس نمط الـ BLoC
          // في سجل الذرية).
          unawaited(
            repository.addReportLog(
              userId: 'current_user',
              actionType: 'delete_report',
              details: 'تم حذف التقرير: ${report.title}',
              targetId: report.id,
              targetType: 'report',
            ),
          );

          // عرض رسالة النجاح
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم حذف التقرير بنجاح'),
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
