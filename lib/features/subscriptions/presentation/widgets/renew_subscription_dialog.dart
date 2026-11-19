import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/credit_limit_warning_dialog.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../domain/entities/subscription_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';

// ignore: avoid_classes_with_only_static_members
class RenewSubscriptionDialog {
  static Future<void> show(
    BuildContext context,
    SubscriptionEntity subscription,
    SubscriptionBloc subscriptionBloc,
  ) async {
    if (!context.mounted) return;

    final formattingService = GetIt.instance<FormattingService>();
    bool isPaid = false;

    final now = DateTime.now();
    final daysRemaining = subscription.daysRemaining;
    final hasRemainingDays =
        subscription.endDate.isAfter(now) && daysRemaining > 0;

    var newStartDate = hasRemainingDays ? subscription.endDate : now;
    var newEndDate = SubscriptionEntity.calculateEndDate(
      newStartDate,
      subscription.duration,
      subscription.customDays,
    );

    final originalPrice =
        subscription.price +
        subscription.discountAmount -
        subscription.taxAmount;

    var infoMessage = 'سيتم تجديد الاشتراك وإنشاء فاتورة جديدة';
    if (hasRemainingDays) {
      infoMessage +=
          '\n✓ سيتم إضافة الأيام المتبقية ($daysRemaining يوم) إلى الاشتراك الجديد';
    }

    Map<String, String> additionalInfo = {
      'العميل': subscription.customerName ?? 'غير محدد',
      'السعر النهائي': formattingService.formatCurrency(subscription.price),
      'تاريخ الانتهاء الحالي': formattingService.formatDateTime(
        subscription.endDate,
      ),
      if (hasRemainingDays) 'الأيام المتبقية': '$daysRemaining يوم',
    };

    if (subscription.discountAmount > 0 || subscription.taxAmount > 0) {
      additionalInfo['السعر الأصلي'] = formattingService.formatCurrency(
        originalPrice,
      );

      if (subscription.taxes != null && subscription.taxes!.isNotEmpty) {
        for (var tax in subscription.taxes!) {
          final taxName = tax['name'] as String;
          final taxRate = tax['rate'] as double;
          final taxAmountValue = tax['amount'] as double;
          final isPercentage = tax['isPercentage'] as bool;

          final taxDisplay = isPercentage && taxRate > 0
              ? '${formattingService.formatCurrency(taxAmountValue)} (${taxRate.toStringAsFixed(1)}%)'
              : formattingService.formatCurrency(taxAmountValue);

          additionalInfo['• $taxName'] = taxDisplay;
        }
        additionalInfo['إجمالي الضرائب'] = formattingService.formatCurrency(
          subscription.taxAmount,
        );
      } else if (subscription.taxAmount > 0) {
        final taxRate = originalPrice > 0
            ? (subscription.taxAmount / originalPrice) * 100
            : 0;
        if (taxRate > 0) {
          additionalInfo['الضريبة'] =
              '${formattingService.formatCurrency(subscription.taxAmount)} (${taxRate.toStringAsFixed(1)}%)';
        } else {
          additionalInfo['الضريبة'] = formattingService.formatCurrency(
            subscription.taxAmount,
          );
        }
      }

      if (subscription.discountAmount > 0) {
        additionalInfo['الخصم'] =
            '-${formattingService.formatCurrency(subscription.discountAmount)}';
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.refresh, color: Colors.green, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'تجديد الاشتراك',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          infoMessage,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  subscription.name,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (additionalInfo.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  ...additionalInfo.entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getIconForKey(entry.key),
                                size: 16.sp,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                '${entry.key}:',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: _getColorForKey(entry.key),
                              fontWeight: _isBoldForKey(entry.key)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                SizedBox(height: 16.h),
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: dialogContext,
                      initialDate: newStartDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AssyrianTheme.primaryGold,
                            onSurface: AssyrianTheme.deepBlue,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (pickedDate == null || !dialogContext.mounted) return;

                    final startDateForTime = newStartDate;
                    final pickedTime = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(startDateForTime),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AssyrianTheme.primaryGold,
                            onSurface: AssyrianTheme.deepBlue,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (pickedTime == null || !dialogContext.mounted) return;

                    setDialogState(() {
                      final updatedStartDate = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                      newStartDate = updatedStartDate;
                      newEndDate = SubscriptionEntity.calculateEndDate(
                        updatedStartDate,
                        subscription.duration,
                        subscription.customDays,
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(8.r),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'تاريخ ووقت بداية التجديد',
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        size: 20.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                      suffixIcon: Icon(
                        Icons.edit_calendar,
                        size: 18.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: const BorderSide(
                          color: AssyrianTheme.primaryGold,
                        ),
                      ),
                      labelStyle: const TextStyle(
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                    child: Text(
                      formattingService.formatDateTime(newStartDate),
                      style: TextStyle(
                        color: AssyrianTheme.deepBlue,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'تاريخ الانتهاء المتوقع: ${formattingService.formatDateTime(newEndDate)}',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                ),
                SizedBox(height: 12.h),
                CheckboxListTile(
                  value: isPaid,
                  onChanged: (value) {
                    setDialogState(() {
                      isPaid = value ?? false;
                    });
                  },
                  title: Text(
                    'تم الدفع',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
              child: Text(
                'إلغاء',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // ⚠️ ملاحظة للمبرمجين المستقبليين:
                // يُمرر سياق صفحة القائمة (context
                // الخارجي) وليس سياق حوار التأكيد —
                // لأن الحوار يُغلق قبل استدعاء
                // _confirmRenew فسياقه يصبح غير صالح
                // ولا تظهر نافذة جاري الحفظ (مثلما
                // تظهر عند إنشاء اشتراك).
                await _confirmRenew(
                  context,
                  subscription,
                  subscriptionBloc,
                  isPaid: isPaid,
                  customStartDate: newStartDate,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'تجديد الآن',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmRenew(
    BuildContext context,
    SubscriptionEntity subscription,
    SubscriptionBloc subscriptionBloc, {
    bool isPaid = false,
    required DateTime customStartDate,
  }) async {
    // التحقق من حساب التفعيلات قبل التجديد
    try {
      final typesResult = await subscriptionBloc.repository
          .getSubscriptionTypes(subscription.organizationEmail);

      await typesResult.fold((failure) async {}, (types) async {
        final subscriptionType = types.firstWhere(
          (type) => type.name == subscription.type,
          orElse: () => throw Exception('نوع الاشتراك غير موجود'),
        );

        if (subscriptionType.activationQuantity <= 0) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'لا يوجد تفعيلات متاحة لهذا النوع (${subscriptionType.name}). يرجى شحن التفعيلات أولاً.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'شحن الآن',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/subscriptions/recharge-activations',
                      arguments: subscriptionType,
                    );
                  },
                ),
              ),
            );
          }
          throw Exception('لا يوجد تفعيلات متاحة');
        }
      });
    } on Exception catch (e) {
      if (e.toString().contains('لا يوجد تفعيلات متاحة')) {
        return; // الخروج من الدالة
      }
      // نكمل في حالة وجود خطأ آخر
    }

    // التحقق من حد الائتمان بعد تأكيد التجديد
    if (subscription.customerId != null &&
        subscription.customerId!.isNotEmpty) {
      try {
        // ⚡ أداء: قراءة مستند العميل واحد O(1) بدلاً من
        // جلب كل العملاء O(n) ثم firstWhere (نفس النتيجة)
        final customerRepository = GetIt.instance<CustomerRepository>();
        final customerResult = await customerRepository.getCustomerById(
          subscription.customerId!,
        );

        CustomerEntity? customer;
        customerResult.fold((failure) {}, (customerEntity) {
          customer = customerEntity;
        });

        // إذا وجدنا العميل، نتحقق من حد الائتمان
        if (customer != null) {
          final currentDebt = customer!.totalDebt;
          final creditLimit = customer!.creditLimit ?? 0;
          final subscriptionPrice = subscription.price;
          final newDebt = currentDebt + subscriptionPrice;

          // إذا تجاوز حد الائتمان، عرض تحذير
          if (creditLimit > 0 && newDebt > creditLimit) {
            if (context.mounted) {
              final shouldContinue = await CreditLimitWarningDialog.show(
                context,
                customerName: customer!.name,
                currentDebt: currentDebt,
                creditLimit: creditLimit,
                invoiceAmount: subscriptionPrice,
                newDebt: newDebt,
              );

              if (!shouldContinue) {
                // المستخدم اختار الإلغاء - عرض رسالة توضيحية
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'تم إلغاء العملية - لم يتم تجديد الاشتراك',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
                return;
              }
            }
          }
        }
      } on Exception catch (_) {
        // نكمل بدون فحص حد الائتمان
      }
    }

    // عرض نافذة التحميل الموحدة
    if (context.mounted) {
      LoadingWidget.showLoadingDialog(
        context,
        message: 'جاري تجديد الاشتراك...',
        subtitle: 'الرجاء الانتظار...',
        icon: Icons.refresh,
        iconColor: Colors.green,
      );
    }

    try {
      // إرسال حدث التجديد
      subscriptionBloc.add(
        RenewSubscriptionEvent(
          subscriptionId: subscription.id,
          organizationEmail: subscription.organizationEmail,
          customStartDate: customStartDate,
          isPaid: isPaid,
        ),
      );

      // انتظار نجاح العملية مع مهلة زمنية لمنع التعليق إلى ما لا نهاية
      SubscriptionState? operationResult;
      try {
        operationResult = await subscriptionBloc.stream
            .firstWhere(
              (state) =>
                  state is SubscriptionOperationSuccess ||
                  state is SubscriptionError,
            )
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => SubscriptionError('انتهت مهلة العملية'),
            );
      } on TimeoutException {
        operationResult = const SubscriptionError('انتهت مهلة العملية');
      }

      // إغلاق نافذة التحميل
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // إعادة تحميل بيانات الاشتراكات عبر نفس الـ Bloc الذي نفذ التجديد.
      // قد لا يكون هو الـ instance المسجل في GetIt.
      if (operationResult is SubscriptionOperationSuccess && context.mounted) {
        subscriptionBloc.add(
          LoadSubscriptionsEvent(subscription.organizationEmail),
        );
      }
    } on Exception catch (_) {
      // إغلاق نافذة التحميل في حالة الخطأ
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    }
  }

  static IconData _getIconForKey(String key) {
    if (key.contains('عميل') || key.contains('العميل')) {
      return Icons.person;
    } else if (key.contains('سعر') ||
        key.contains('السعر') ||
        key.contains('مبلغ') ||
        key.contains('المبلغ')) {
      return Icons.attach_money;
    } else if (key.contains('تاريخ') || key.contains('التاريخ')) {
      return Icons.calendar_today;
    } else if (key.contains('نوع') || key.contains('النوع')) {
      return Icons.category;
    } else if (key.contains('حالة') || key.contains('الحالة')) {
      return Icons.info;
    } else {
      return Icons.description;
    }
  }

  static Color _getColorForKey(String key) {
    if (key.contains('سعر') ||
        key.contains('السعر') ||
        key.contains('مبلغ') ||
        key.contains('المبلغ')) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  static bool _isBoldForKey(String key) {
    return key.contains('سعر') ||
        key.contains('السعر') ||
        key.contains('مبلغ') ||
        key.contains('المبلغ');
  }
}
