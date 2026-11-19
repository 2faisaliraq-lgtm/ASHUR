import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/pdf/pdf_settings_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../domain/entities/subscription_entity.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}

/// بطاقة الاشتراك
class SubscriptionCard extends StatelessWidget {
  SubscriptionCard({
    required this.subscription,
    required this.onTap,
    super.key,
    this.isListView = false,
  });
  final SubscriptionEntity subscription;
  final VoidCallback onTap;
  final bool isListView;
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  /// التحقق مما إذا كان الاشتراك قريباً من الانتهاء (أقل من 7 أيام)
  bool get _isExpiringSoon {
    final now = DateTime.now();
    final daysRemaining = subscription.endDate.difference(now).inDays;
    return daysRemaining <= 7 &&
        daysRemaining >= 0 &&
        subscription.status == 'active';
  }

  /// إرسال رسالة تذكير بقرب انتهاء الاشتراك
  Future<void> _sendExpirationReminder(BuildContext context) async {
    try {
      // جلب رقم هاتف العميل من قاعدة البيانات (مثل التجديد)
      String? customerPhone = subscription.customerPhone;
      double? currentBalance;

      // إذا لم يوجد رقم هاتف في الاشتراك، نجلبه من قاعدة البيانات
      if (customerPhone == null || customerPhone.isEmpty) {
        // ⚡ أداء: قراءة مستند العميل واحد O(1) بدلاً من
        // جلب كل العملاء O(n) ثم firstWhere (نفس النتيجة)
        if (subscription.customerId != null &&
            subscription.customerId!.isNotEmpty) {
          final customerRepository = GetIt.instance<CustomerRepository>();
          final customerResult = await customerRepository.getCustomerById(
            subscription.customerId!,
          );
          customerResult.fold(
            (failure) {
              // فشل في جلب العميل
            },
            (customer) {
              customerPhone = customer.phone;
              currentBalance = customer.totalDebt; // جلب الحساب الحالي
            },
          );
        }
      }

      // التحقق من وجود رقم هاتف
      if (customerPhone == null || customerPhone!.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد رقم هاتف للعميل'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // حساب أيام المتبقية
      final daysRemaining = subscription.endDate
          .difference(DateTime.now())
          .inDays;

      // جلب اسم المؤسسة
      final organizationName = await _getOrganizationName(
        subscription.organizationEmail,
      );

      // إنشاء رسالة التذكير مع الحساب الحالي
      final message =
          WhatsAppService.createSubscriptionExpirationReminderMessage(
            customerName: subscription.customerName ?? 'عميلنا',
            subscriptionName: subscription.name,
            startDate: subscription.startDate,
            endDate: subscription.endDate,
            daysRemaining: daysRemaining,
            renewalPrice: subscription.price,
            invoiceNumber: 'RMD-${DateTime.now().millisecondsSinceEpoch}',
            organizationName: organizationName,
            currentBalance: currentBalance,
          );

      final success = await WhatsAppService.sendMessage(
        phoneNumber: customerPhone!,
        message: message,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال تذكير لـ ${subscription.customerName}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إرسال الرسالة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// جلب اسم المؤسسة من الإعدادات
  Future<String> _getOrganizationName(String organizationEmail) async {
    try {
      // محاولة جلب اسم المؤسسة من PdfSettingsService
      final pdfSettingsService = PdfSettingsService();
      final settings = await pdfSettingsService.getSettings(organizationEmail);
      if (settings.organizationName.isNotEmpty) {
        return settings.organizationName;
      }
    } on Exception catch (_) {
      // فشل في جلب اسم المؤسسة من الإعدادات
    }

    // إذا فشل جلب اسم المؤسسة، نستخدم البريد الإلكتروني
    if (organizationEmail.isNotEmpty) {
      // استخراج اسم المؤسسة من البريد الإلكتروني
      final parts = organizationEmail.split('@');
      if (parts.isNotEmpty) {
        return parts[0].capitalize();
      }
    }

    return 'المؤسسة'; // قيمة افتراضية
  }

  @override
  Widget build(BuildContext context) {
    return isListView ? _buildListCard(context) : _buildGridCard(context);
  }

  Widget _buildListCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // أيقونة الحالة على اليمين
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getMainIcon(),
                        size: 24.sp,
                        color: _getStatusColor().withValues(alpha: 0.5),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      left: 3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _getStatusColor(),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(),
                          color: Colors.white,
                          size: 10.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // المعلومات في المنتصف
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AssyrianTheme.deepBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 10.sp,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 3.w),
                               Text(
                                 _formattingService.formatDateTime(
                                   subscription.endDate,
                                 ),
                                 style: TextStyle(
                                   fontSize: 10.sp,
                                   color: Colors.grey[600],
                                 ),
                               ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6.w),
                        // زر تذكير بقرب انتهاء الاشتراك
                        if (_isExpiringSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: InkWell(
                              onTap: () => _sendExpirationReminder(context),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.message,
                                    size: 10.sp,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    'تذكير',
                                    style: TextStyle(
                                      fontSize: 8.sp,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // المبلغ والحالة على اليسار
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formattingService.formatCurrency(subscription.price),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  _buildStatusBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMainIcon() {
    return Icons.inventory_2;
  }

  IconData _getStatusIcon() {
    // ملاحظة للمبرمجين المستقبليين:
    // نعتمد على isExpired أولاً قبل فحص status لأن بعض الاشتراكات
    // قد تكون حالتها 'active' في قاعدة البيانات لكن تاريخ انتهائها منقضٍ.
    // هذا يمنع عرض الاشتراكات المنتهية erroneously كنشطة في البطاقة.
    if (subscription.isExpired) {
      return Icons.warning;
    }
    switch (subscription.status) {
      case 'active':
        return Icons.check;
      case 'expired':
        return Icons.warning;
      case 'cancelled':
        return Icons.close;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor() {
    // ملاحظة للمبرمجين المستقبليين:
    // نعتمد على isExpired أولاً قبل فحص status لأن بعض الاشتراكات
    // قد تكون حالتها 'active' في قاعدة البيانات لكن تاريخ انتهائها منقضٍ.
    // هذا يمنع عرض الاشتراكات المنتهية erroneously بلون أخضر.
    if (subscription.isExpired) {
      return Colors.orange;
    }
    switch (subscription.status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildGridCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIcon(),
                  const Spacer(),
                  _buildStatusBadge(),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                subscription.name,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Text(
                subscription.type,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                '${_formattingService.formatCurrency(subscription.price)}/${subscription.duration}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.primaryGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    // ملاحظة للمبرمجين المستقبليين:
    // نعتمد على isExpired أولاً قبل فحص status لأن بعض الاشتراكات
    // قد تكون حالتها 'active' في قاعدة البيانات لكن تاريخ انتهائها منقضٍ.
    // هذا يمنع عرض الاشتراكات المنتهية erroneously بلون أخضر.
    IconData icon;
    Color color;

    if (subscription.isExpired) {
      icon = Icons.warning_amber_outlined;
      color = Colors.orange;
    } else {
      switch (subscription.status) {
        case 'active':
          icon = Icons.check_circle_outline;
          color = Colors.green;
          break;
        case 'expired':
          icon = Icons.warning_amber_outlined;
          color = Colors.orange;
          break;
        case 'cancelled':
          icon = Icons.cancel_outlined;
          color = Colors.red;
          break;
        default:
          icon = Icons.subscriptions_outlined;
          color = Colors.grey[600]!;
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24.sp),
    );
  }

  Widget _buildStatusBadge() {
    // ملاحظة للمبرمجين المستقبليين:
    // نعتمد على isExpired أولاً قبل فحص status لأن بعض الاشتراكات
    // قد تكون حالتها 'active' في قاعدة البيانات لكن تاريخ انتهائها منقضٍ.
    // هذا يمنع عرض الاشتراكات المنتهية erroneously كـ 'متوفر'.
    var label = '';
    var color = _getStatusColor();

    if (subscription.isExpired) {
      label = 'منتهي';
    } else {
      switch (subscription.status) {
        case 'active':
          label = 'متوفر';
          break;
        case 'expired':
          label = 'منتهي';
          break;
        case 'cancelled':
          label = 'ملغي';
          break;
        default:
          label = subscription.status;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
