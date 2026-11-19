import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/pdf/pdf_settings_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/customer_entity.dart';

class CustomerCard extends StatelessWidget {
  CustomerCard({
    required this.customer,
    required this.onTap,
    super.key,
    this.isListView = true,
    this.showWhatsAppButton = true,
  });
  final CustomerEntity customer;
  final VoidCallback onTap;
  final bool isListView;
  final bool showWhatsAppButton;
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  @override
  Widget build(BuildContext context) {
    return isListView ? _buildListCard(context) : _buildGridCard(context);
  }

  Widget _buildListCard(BuildContext context) {
    final exceedingCreditLimit = customer.exceedsCreditLimit;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      color: exceedingCreditLimit
          ? Colors.red.withValues(alpha: 0.05)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: exceedingCreditLimit
            ? BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 2)
            : BorderSide.none,
      ),
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
                        customer.hasGroup ? Icons.group : Icons.person,
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
                      customer.name,
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
                        Expanded(
                          child: Container(
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
                                  Icons.phone,
                                  size: 10.sp,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 3.w),
                                Flexible(
                                  child: Text(
                                    customer.phone,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showWhatsAppButton && customer.totalDebt > 0)
                          SizedBox(width: 6.w),
                        if (showWhatsAppButton && customer.totalDebt > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: InkWell(
                              onTap: () => _sendDebtReminderWhatsApp(context),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.message,
                                    size: 10.sp,
                                    color: Colors.green,
                                  ),
                                  Text(
                                    'واتساب',
                                    style: TextStyle(
                                      fontSize: 8.sp,
                                      color: Colors.green,
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
                      color: exceedingCreditLimit
                          ? Colors.red.withValues(alpha: 0.1)
                          : AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getDebtDisplayText(),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: exceedingCreditLimit
                            ? Colors.red
                            : AssyrianTheme.primaryGold,
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

  Widget _buildGridCard(BuildContext context) {
    final exceedingCreditLimit = customer.exceedsCreditLimit;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      color: exceedingCreditLimit
          ? Colors.red.withValues(alpha: 0.05)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: exceedingCreditLimit
            ? BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 2)
            : BorderSide.none,
      ),
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
                  _buildStatusIconGrid(),
                  const Spacer(),
                  _buildStatusBadge(),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                customer.name,
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
                customer.phone,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                _getDebtDisplayText(),
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

  String _getDebtDisplayText() {
    if (customer.isBalanced) {
      return 'متعادل';
    } else if (customer.hasDebt) {
      return 'مدين: ${_formattingService.formatCurrency(customer.debtAmount)}';
    } else if (customer.hasCredit) {
      return 'دائن: ${_formattingService.formatCurrency(customer.creditAmount)}';
    } else {
      return 'متعادل';
    }
  }

  IconData _getStatusIcon() {
    switch (customer.status) {
      case 'active':
        return Icons.check;
      case 'inactive':
        return Icons.schedule;
      case 'blocked':
        return Icons.close;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor() {
    switch (customer.status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'blocked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusIconGrid() {
    IconData icon;
    Color color;

    switch (customer.status) {
      case 'active':
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'inactive':
        icon = Icons.pending_outlined;
        color = Colors.orange;
        break;
      case 'blocked':
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      default:
        icon = Icons.person_outline;
        color = Colors.grey[600]!;
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
    var label = '';
    var color = _getStatusColor();

    switch (customer.status) {
      case 'active':
        label = 'نشط';
        break;
      case 'inactive':
        label = 'غير نشط';
        break;
      case 'blocked':
        label = 'محظور';
        break;
      default:
        label = customer.status;
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

  /// إرسال رسالة تذكير بالدين عبر الواتساب
  Future<void> _sendDebtReminderWhatsApp(BuildContext context) async {
    try {
      // الحصول على البريد الإلكتروني للمؤسسة
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;

      // التحقق من تفعيل الإشعارات
      final notificationService = NotificationService();
      final isEnabled = await notificationService.isWhatsAppNotificationEnabled(
        user!.email!,
      );

      if (!isEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('إشعارات الواتساب معطلة في الإعدادات'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final isTypeEnabled = await notificationService.isNotificationTypeEnabled(
        user.email!,
        'debtReminder',
      );

      if (!isTypeEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('إشعارات التذكير بالدين معطلة في الإعدادات'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // التحقق من وجود رقم هاتف
      if (customer.phone.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد رقم هاتف للعميل'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // التحقق من وجود دين
      if (customer.totalDebt <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد دين على العميل'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // إنشاء رسالة التذكير
      final organizationName = await _getOrganizationName(
        customer.organizationEmail,
      );
      final message = WhatsAppService.createDebtReminderMessageSimple(
        customerName: customer.name,
        debtAmount: customer.totalDebt,
        organizationName: organizationName,
      );

      // إرسال الرسالة
      final success = await WhatsAppService.sendMessage(
        phoneNumber: customer.phone,
        message: message,
      );

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إرسال تذكير بالدين إلى ${customer.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل في إرسال الرسالة. تأكد من تثبيت الواتساب'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال الرسالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// جلب اسم المؤسسة من الإعدادات
  Future<String> _getOrganizationName(String organizationEmail) async {
    try {
      final pdfSettingsService = PdfSettingsService();
      final settings = await pdfSettingsService.getSettings(organizationEmail);
      if (settings.organizationName.isNotEmpty) {
        return settings.organizationName;
      }
    } on Exception catch (_) {
      // فشل في جلب اسم المؤسسة
    }

    // قيمة افتراضية
    return 'المؤسسة';
  }
}
