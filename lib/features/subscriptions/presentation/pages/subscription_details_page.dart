import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/pdf/pdf_settings_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../data/models/subscription_model.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/subscription_type_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/delete_subscription_dialog.dart';
import '../widgets/renew_subscription_dialog.dart';
import '../widgets/subscription_drawer.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}

/// صفحة تفاصيل الاشتراك
class SubscriptionDetailsPage extends StatefulWidget {
  const SubscriptionDetailsPage({required this.subscription, super.key});

  final SubscriptionEntity subscription;

  @override
  State<SubscriptionDetailsPage> createState() =>
      _SubscriptionDetailsPageState();
}

class _SubscriptionDetailsPageState extends State<SubscriptionDetailsPage>
    with SaveOperationMixin<SubscriptionDetailsPage> {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  bool _canDelete = false;
  bool? _hasCustomerPermission;
  late SubscriptionEntity currentSubscription;
  bool _operationCompleted = false;
  String? _createdByName;
  String? _updatedByName;
  SubscriptionBloc? _subscriptionBloc;

  /// التحقق مما إذا كان الاشتراك قريباً من الانتهاء (أقل من 7 أيام)
  bool get _isExpiringSoon {
    final now = DateTime.now();
    final daysRemaining = currentSubscription.endDate.difference(now).inDays;
    return daysRemaining <= 7 &&
        daysRemaining >= 0 &&
        currentSubscription.status == 'active';
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

  /// إرسال رسالة تذكير بقرب انتهاء الاشتراك
  Future<void> _sendExpirationReminder() async {
    try {
      // جلب رقم هاتف العميل من قاعدة البيانات (نفس طريقة الإنشاء/التجديد)
      // ⚡ أداء: قراءة مستند العميل واحد O(1) بدلاً من
      // جلب كل العملاء O(n) ثم firstWhere (نفس النتيجة)
      String? customerPhone;
      double? currentBalance;
      if (currentSubscription.customerId != null &&
          currentSubscription.customerId!.isNotEmpty) {
        final customerRepository = GetIt.instance<CustomerRepository>();
        final customerResult = await customerRepository.getCustomerById(
          currentSubscription.customerId!,
        );
        customerResult.fold(
          (failure) {
            // فشل في جلب العميل
          },
          (customer) {
            customerPhone = customer.phone;
            currentBalance = customer.totalDebt;
          },
        );
      }

      // التحقق من وجود رقم هاتف
      if (customerPhone == null || customerPhone!.isEmpty) {
        if (mounted) {
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
      final daysRemaining = currentSubscription.endDate
          .difference(DateTime.now())
          .inDays;

      // جلب اسم المؤسسة من الإعدادات
      final organizationName = await _getOrganizationName(
        currentSubscription.organizationEmail,
      );

      // إنشاء رسالة التذكير
      final message =
          WhatsAppService.createSubscriptionExpirationReminderMessage(
            customerName: currentSubscription.customerName ?? 'عميلنا',
            subscriptionName: currentSubscription.name,
            startDate: currentSubscription.startDate,
            endDate: currentSubscription.endDate,
            daysRemaining: daysRemaining,
            renewalPrice: currentSubscription.price,
            invoiceNumber: 'RMD-${DateTime.now().millisecondsSinceEpoch}',
            organizationName: organizationName,
            currentBalance: currentBalance,
          );

      final success = await WhatsAppService.sendMessage(
        phoneNumber: customerPhone!,
        message: message,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إرسال تذكير لـ ${currentSubscription.customerName}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إرسال الرسالة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// إرسال تفاصيل الاشتراك عبر الواتساب
  Future<void> _sendSubscriptionDetails() async {
    try {
      // جلب رقم هاتف العميل من قاعدة البيانات
      // ⚡ أداء: قراءة مستند العميل واحد O(1) بدلاً من
      // جلب كل العملاء O(n) ثم firstWhere (نفس النتيجة)
      String? customerPhone;
      double? currentBalance;
      if (currentSubscription.customerId != null &&
          currentSubscription.customerId!.isNotEmpty) {
        final customerRepository = GetIt.instance<CustomerRepository>();
        final customerResult = await customerRepository.getCustomerById(
          currentSubscription.customerId!,
        );
        customerResult.fold(
          (failure) {
            // فشل في جلب العميل
          },
          (customer) {
            customerPhone = customer.phone;
            currentBalance = customer.totalDebt;
          },
        );
      }

      // التحقق من وجود رقم هاتف
      if (customerPhone == null || customerPhone!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد رقم هاتف للعميل'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // جلب اسم المؤسسة من الإعدادات
      final organizationName = await _getOrganizationName(
        currentSubscription.organizationEmail,
      );

      // استخراج الميزات من الاشتراك
      List<String>? featuresList;
      if (currentSubscription.features != null &&
          currentSubscription.features!.isNotEmpty) {
        // الميزات مخزنة كـ {'items': ['ميزة 1', 'ميزة 2']}
        final items = currentSubscription.features!['items'];
        if (items is List) {
          featuresList = items.cast<String>().toList();
        }
      }

      // إنشاء رسالة تفاصيل الاشتراك
      final message = WhatsAppService.createSubscriptionMessage(
        customerName: currentSubscription.customerName ?? 'عميلنا',
        subscriptionName: currentSubscription.name,
        subscriptionType: currentSubscription.type,
        price: currentSubscription.price,
        startDate: currentSubscription.startDate,
        endDate: currentSubscription.endDate,
        duration: currentSubscription.duration,
        organizationName: organizationName,
        balanceBeforeInvoice: null, // لا نعرض الحساب السابق
        balanceAfterInvoice: currentBalance, // الحساب الحالي فقط
        discountAmount: currentSubscription.discountAmount,
        taxAmount: currentSubscription.taxAmount,
        taxes: currentSubscription.taxes,
        features: featuresList, // إضافة الميزات
        customDays: currentSubscription.customDays, // إضافة عدد الأيام المخصصة
      );

      final success = await WhatsAppService.sendMessage(
        phoneNumber: customerPhone!,
        message: message,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إرسال تفاصيل الاشتراك لـ ${currentSubscription.customerName}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إرسال الرسالة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // حفظ مرجع الـ bloc لاستخدامه بأمان في dispose
    _subscriptionBloc = context.read<SubscriptionBloc>();
  }

  @override
  void initState() {
    super.initState();
    currentSubscription = widget.subscription;
    _loadPermissions();
    _loadCustomerPermission();
    _loadUserNames();

    // بدء الاستماع للتحديثات الفورية للاشتراكات
    final subscriptionBloc = context.read<SubscriptionBloc>();
    subscriptionBloc.add(
      StartSubscriptionsStreamEvent(
        organizationEmail: widget.subscription.organizationEmail,
      ),
    );
  }

  Future<void> _loadPermissions() async {
    final canEdit = await _permissionChecker.hasPermission(
      'subscriptions_edit',
    );
    final canDelete = await _permissionChecker.hasPermission(
      'subscriptions_delete',
    );

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
        _canDelete = canDelete;
      });
    }
  }

  /// تحميل صلاحية الوصول إلى العملاء
  Future<void> _loadCustomerPermission() async {
    final hasPermission = await _permissionChecker.hasPermission(
      'customers_view',
    );

    if (mounted) {
      setState(() {
        _hasCustomerPermission = hasPermission;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: const SubscriptionDrawer(currentRoute: 'subscription_details'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listenWhen: (previous, current) {
          return current is SubscriptionError ||
              current is SubscriptionOperationSuccess ||
              current is SubscriptionLoaded;
        },
        listener: (context, state) {
          // ⚠️ ملاحظة للمبرمجين المستقبليين حول التنقل:
          // هذه شاشة تفاصيل (ليست شاشة إنشاء/تعديل
          // كاملة) وعملياتها (التجديد/تغيير الحالة/
          // الحذف) تُنفَّذ عبر نوافذ حوار تُغلق نافذة
          // التحميل بنفسها. لذلك لا تُستدعى
          // failSaveOperation/completeSaveOperation هنا
          // أبداً — كل منهما تُغلق نافذة تحميل أيضاً
          // فتقع إغلاقتان (double pop) تُغلقان شاشة
          // التفاصيل نفسها (كان التجديد ينتقل للشاشة
          // التي سبقت شاشة التفاصيل). القاعدة:
          // نافذة حوار = حدّث بيانات الشاشة الحالية
          // فقط وابقَ فيها؛ شاشة كاملة = احفظ وعُد
          // للشاشة السابقة.
          if (state is SubscriptionError && !_operationCompleted) {
            _operationCompleted = true;
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
          } else if (state is SubscriptionOperationSuccess &&
              !_operationCompleted) {
            _operationCompleted = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          } else if (state is SubscriptionLoaded ||
              state is SubscriptionsStreamActive) {
            final subscriptions = state is SubscriptionLoaded
                ? state.subscriptions
                : (state as SubscriptionsStreamActive).subscriptions;
            for (final updated in subscriptions) {
              if (updated.id == currentSubscription.id &&
                  updated != currentSubscription) {
                setState(() => currentSubscription = updated);
                _loadUserNames();
                break;
              }
            }
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSubscriptionHeader(),
                const SizedBox(height: 6),
                _buildSubscriptionInfoCard(),
                const SizedBox(height: 6),
                _buildCustomerInfoCard(),
                const SizedBox(height: 6),
                _buildStatusCard(),
                const SizedBox(height: 6),
                _buildPaymentInfoCard(),
                const SizedBox(height: 6),
                _buildSystemInfoCard(),
                const SizedBox(
                  height: 80,
                ), // مساحة إضافية للـ floating action button
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AssyrianTheme.backgroundGradient,
          boxShadow: [
            BoxShadow(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          AssyrianTheme.getLamassuForBackground(
            isDarkBackground: true,
            hasCircularBackground: false,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تفاصيل الاشتراك',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                    ),
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  currentSubscription.name,
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 10,
                    ),
                    color: AssyrianTheme.ivoryWhite,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editSubscription();
                break;
              case 'renew':
                _renewSubscription();
                break;
              case 'reminder':
                _sendExpirationReminder();
                break;
              case 'send_details':
                _sendSubscriptionDetails();
                break;
              case 'toggle_status':
                _toggleSubscriptionStatus();
                break;
              case 'delete':
                _deleteSubscription();
                break;
            }
          },
          itemBuilder: (context) => [
            if (_canEdit)
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('تعديل'),
                  ],
                ),
              ),
            if (currentSubscription.canRenew)
              const PopupMenuItem(
                value: 'renew',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.green),
                    SizedBox(width: 8),
                    Text('تجديد'),
                  ],
                ),
              ),
            if (_isExpiringSoon)
              const PopupMenuItem(
                value: 'reminder',
                child: Row(
                  children: [
                    Icon(Icons.message, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('تذكير'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'send_details',
              child: Row(
                children: [
                  Icon(Icons.share, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('إرسال التفاصيل'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_status',
              child: Row(
                children: [
                  Icon(
                    currentSubscription.status == 'active'
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: currentSubscription.status == 'active'
                        ? Colors.orange
                        : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentSubscription.status == 'active' ? 'إيقاف' : 'تفعيل',
                  ),
                ],
              ),
            ),
            if (_canDelete)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('حذف'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubscriptionHeader() {
    return DetailScreenHeader(
      title: currentSubscription.name,
      subtitle: '${currentSubscription.daysRemaining} يوم متبقي',
      icon: Icons.card_membership,
      iconBackgroundColor: _getStatusColor(
        currentSubscription.status,
      ).withValues(alpha: 0.2),
      iconForegroundColor: _getStatusColor(currentSubscription.status),
    );
  }

  Widget _buildSubscriptionInfoCard() {
    return InfoCard(
      title: 'معلومات الاشتراك',
      icon: Icons.card_membership,
      children: [
        DetailRow(label: 'الاسم', value: currentSubscription.name),
        InkWell(
          onTap: _navigateToSubscriptionTypeDetails,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120.w,
                  child: Text(
                    'النوع',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    currentSubscription.type,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AssyrianTheme.deepBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16.sp,
                  color: AssyrianTheme.primaryGold,
                ),
              ],
            ),
          ),
        ),
        // عرض السعر الأصلي والخصم والضرائب إذا وجدت
        if (currentSubscription.discountAmount > 0 ||
            currentSubscription.taxAmount > 0) ...[
          DetailRow(
            label: 'السعر الأصلي',
            value: _formattingService.formatCurrency(
              currentSubscription.price +
                  currentSubscription.discountAmount -
                  currentSubscription.taxAmount,
            ),
          ),
          // عرض تفاصيل الضرائب المتعددة
          if (currentSubscription.taxes != null &&
              currentSubscription.taxes!.isNotEmpty) ...[
            // عرض كل ضريبة بشكل منفصل
            ...currentSubscription.taxes!.map((tax) {
              final taxName = tax['name'] as String;
              final taxRate = tax['rate'] as double;
              final taxAmountValue = tax['amount'] as double;
              final isPercentage = tax['isPercentage'] as bool;

              return DetailRow(
                label: '• $taxName',
                value: isPercentage && taxRate > 0
                    ? '${_formattingService.formatCurrency(taxAmountValue)} (${taxRate.toStringAsFixed(1)}%)'
                    : _formattingService.formatCurrency(taxAmountValue),
                valueColor: Colors.orange,
              );
            }),
            // عرض إجمالي الضرائب
            DetailRow(
              label: 'إجمالي الضرائب',
              value: _formattingService.formatCurrency(
                currentSubscription.taxAmount,
              ),
              valueColor: Colors.orange,
              isBold: true,
            ),
          ] else if (currentSubscription.taxAmount > 0) ...[
            // ضريبة واحدة فقط (للخلف compatibility)
            Builder(
              builder: (context) {
                final originalPrice =
                    currentSubscription.price +
                    currentSubscription.discountAmount -
                    currentSubscription.taxAmount;
                final taxRate = originalPrice > 0
                    ? (currentSubscription.taxAmount / originalPrice) * 100
                    : 0;
                if (taxRate > 0) {
                  return DetailRow(
                    label: 'الضريبة (${taxRate.toStringAsFixed(1)}%)',
                    value:
                        '${_formattingService.formatCurrency(currentSubscription.taxAmount)} (${taxRate.toStringAsFixed(1)}%)',
                    valueColor: Colors.orange,
                  );
                } else {
                  return DetailRow(
                    label: 'الضريبة',
                    value: _formattingService.formatCurrency(
                      currentSubscription.taxAmount,
                    ),
                    valueColor: Colors.orange,
                  );
                }
              },
            ),
          ],
          // عرض الخصم
          if (currentSubscription.discountAmount > 0)
            DetailRow(
              label: 'الخصم',
              value:
                  '-${_formattingService.formatCurrency(currentSubscription.discountAmount)}',
              valueColor: Colors.red,
            ),
          // السعر النهائي
          DetailRow(
            label: 'السعر النهائي',
            value: _formattingService.formatCurrency(currentSubscription.price),
            isBold: true,
          ),
        ] else
          DetailRow(
            label: 'السعر',
            value: _formattingService.formatCurrency(currentSubscription.price),
          ),
        DetailRow(
          label: 'المدة',
          value: _getDurationLabel(currentSubscription.duration),
        ),
        if (currentSubscription.customDays != null)
          DetailRow(
            label: 'عدد الأيام',
            value: '${currentSubscription.customDays} يوم',
          ),
        DetailRow(
          label: 'تاريخ البداية',
          value: _formattingService.formatDateTime(
            currentSubscription.startDate,
          ),
        ),
        DetailRow(
          label: 'تاريخ النهاية',
          value: _formattingService.formatDateTime(currentSubscription.endDate),
        ),
        if (currentSubscription.description != null &&
            currentSubscription.description!.isNotEmpty)
          DetailRow(label: 'الوصف', value: currentSubscription.description!),
      ],
    );
  }

  Widget _buildCustomerInfoCard() {
    final canNavigateToCustomer = _hasCustomerPermission ?? false;

    if (currentSubscription.customerId == null) {
      return InfoCard(
        title: 'معلومات العميل',
        icon: Icons.person_off,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16.sp, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'لا يوجد عميل مرتبط بهذا الاشتراك',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return InfoCard(
      title: 'معلومات العميل',
      icon: Icons.person,
      children: [
        if (currentSubscription.customerName != null)
          canNavigateToCustomer
              ? InkWell(
                  onTap: _navigateToCustomerDetails,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120.w,
                          child: Text(
                            'اسم العميل',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            currentSubscription.customerName!,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AssyrianTheme.deepBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16.sp,
                          color: AssyrianTheme.primaryGold,
                        ),
                      ],
                    ),
                  ),
                )
              : DetailRow(
                  label: 'اسم العميل',
                  value: currentSubscription.customerName!,
                )
        else
          DetailRow(
            label: 'معرف العميل',
            value: currentSubscription.customerId!,
          ),
        // يمكن إضافة المزيد من معلومات العميل هنا
      ],
    );
  }

  /// الانتقال إلى شاشة تفاصيل العميل
  Future<void> _navigateToCustomerDetails() async {
    if (currentSubscription.customerId == null) return;

    try {
      // جلب بيانات العميل من قاعدة البيانات
      // ⚡ أداء: قراءة مستند العميل واحد O(1) بدلاً من
      // جلب كل العملاء O(n) ثم firstWhere (نفس النتيجة)
      final customerRepository = GetIt.instance<CustomerRepository>();
      final customerResult = await customerRepository.getCustomerById(
        currentSubscription.customerId!,
      );

      if (!mounted) return;

      customerResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل في جلب بيانات العميل: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (customer) async {
          if (!mounted) return;

          // الانتقال إلى شاشة تفاصيل العميل
          await Navigator.of(
            context,
          ).pushNamed(AppRoutes.customerDetails, arguments: customer);
        },
      );
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// الانتقال إلى شاشة تفاصيل نوع الاشتراك
  Future<void> _navigateToSubscriptionTypeDetails() async {
    try {
      // جلب نوع الاشتراك من قاعدة البيانات
      final subscriptionBloc = context.read<SubscriptionBloc>();
      final typesResult = await subscriptionBloc.repository
          .getSubscriptionTypes(currentSubscription.organizationEmail);

      if (!mounted) return;

      await typesResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل في جلب أنواع الاشتراك: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (types) async {
          try {
            SubscriptionTypeEntity? subscriptionType;

            // أولاً: محاولة البحث باستخدام subscriptionTypeId
            if (currentSubscription.subscriptionTypeId != null &&
                currentSubscription.subscriptionTypeId!.isNotEmpty) {
              try {
                subscriptionType = types.firstWhere(
                  (type) => type.id == currentSubscription.subscriptionTypeId,
                );
              } on Exception catch (_) {
                // لم يتم العثور على النوع باستخدام ID
              }
            }

            // ثانياً: إذا لم يتم العثور، البحث باستخدام اسم النوع
            if (subscriptionType == null) {
              try {
                subscriptionType = types.firstWhere(
                  (type) => type.name == currentSubscription.type,
                );
              } on Exception catch (_) {
                // لم يتم العثور على النوع باستخدام الاسم
              }
            }

            if (!mounted) return;

            if (subscriptionType == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('نوع الاشتراك غير موجود'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            // الانتقال إلى شاشة تفاصيل نوع الاشتراك
            await Navigator.of(context).pushNamed(
              AppRoutes.subscriptionTypeDetails,
              arguments: subscriptionType,
            );
          } on Exception catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('نوع الاشتراك غير موجود'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        },
      );
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatusCard() {
    final usagePercentage = currentSubscription.usagePercentage;
    final daysRemaining = currentSubscription.daysRemaining;

    var statusColor = _getStatusColor(currentSubscription.status);

    return InfoCard(
      title: 'حالة الاشتراك',
      icon: Icons.analytics,
      children: [
        DetailRow(
          label: 'الحالة',
          value: _getStatusText(currentSubscription.status),
          valueColor: statusColor,
        ),
        DetailRow(label: 'الأيام المتبقية', value: '$daysRemaining يوم'),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'نسبة الاستخدام',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                Text(
                  '${(usagePercentage * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: usagePercentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentInfoCard() {
    return InfoCard(
      title: 'معلومات الدفع',
      icon: Icons.payment,
      children: [
        DetailRow(
          label: 'إجمالي السعر',
          value: _formattingService.formatCurrency(currentSubscription.price),
        ),
        DetailRow(
          label: 'المدفوع',
          value: _formattingService.formatCurrency(
            currentSubscription.totalPaid,
          ),
        ),
        DetailRow(
          label: 'المتبقي',
          value: _formattingService.formatCurrency(
            currentSubscription.remainingAmount,
          ),
          valueColor: currentSubscription.remainingAmount > 0
              ? Colors.red
              : Colors.green,
        ),
        if (currentSubscription.renewalCount > 0)
          DetailRow(
            label: 'عدد التجديدات',
            value: '${currentSubscription.renewalCount}',
          ),
        if (currentSubscription.lastRenewalDate != null)
          DetailRow(
            label: 'آخر تجديد',
            value: _formattingService.formatDate(
              currentSubscription.lastRenewalDate!,
            ),
          ),
        if (currentSubscription.isAutoRenew)
          const DetailRow(
            label: 'التجديد التلقائي',
            value: 'مفعل',
            valueColor: Colors.green,
          )
        else
          const DetailRow(
            label: 'التجديد التلقائي',
            value: 'غير مفعل',
            valueColor: Colors.grey,
          ),
      ],
    );
  }

  Widget _buildSystemInfoCard() {
    return InfoCard(
      title: 'معلومات النظام',
      icon: Icons.info,
      children: [
        DetailRow(
          label: 'تاريخ الإنشاء',
          value: _formattingService.formatDate(currentSubscription.createdAt),
        ),
        DetailRow(
          label: 'آخر تحديث',
          value: _formattingService.formatDate(currentSubscription.updatedAt),
        ),
        DetailRow(label: 'أنشئ بواسطة', value: _createdByName ?? 'غير محدد'),
        if (currentSubscription.updatedBy != null)
          DetailRow(
            label: 'آخر تحديث بواسطة',
            value: _updatedByName ?? currentSubscription.updatedBy!,
          ),
        DetailRow(label: 'معرف الاشتراك', value: currentSubscription.id),
      ],
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (currentSubscription.canRenew)
          FloatingActionButton(
            heroTag: 'subscriptions_renew_fab',
            onPressed: _renewSubscription,
            backgroundColor: Colors.green,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'subscriptions_edit_fab',
          onPressed: _editSubscription,
          backgroundColor: AssyrianTheme.primaryGold,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return currentSubscription.isExpired
            ? Colors.red
            : currentSubscription.isExpiringSoon
            ? Colors.orange
            : Colors.green;
      case 'expired':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'suspended':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        if (currentSubscription.isExpired) return 'منتهي الصلاحية';
        if (currentSubscription.isExpiringSoon) return 'ينتهي قريباً';
        return 'نشط';
      case 'expired':
        return 'منتهي الصلاحية';
      case 'cancelled':
        return 'ملغي';
      case 'suspended':
        return 'معلق';
      case 'pending':
        return 'في الانتظار';
      default:
        return status;
    }
  }

  String _getDurationLabel(String duration) {
    const durationLabels = {
      'daily': 'يومي',
      'weekly': 'أسبوعي',
      'monthly': 'شهري',
      'quarterly': 'ربع سنوي',
      'yearly': 'سنوي',
      'custom': 'مخصص',
    };
    return durationLabels[duration] ?? duration;
  }

  void _renewSubscription() {
    // إعادة تعيين علم العملية لكل عملية تجديد
    // جديدة (كان لا يُعاد تعيينه فلا تظهر رسالة
    // نجاح/خطأ إلا في أول عملية تجديد فقط)
    _operationCompleted = false;
    RenewSubscriptionDialog.show(
      context,
      currentSubscription,
      context.read<SubscriptionBloc>(),
    );
  }

  void _toggleSubscriptionStatus() {
    final newStatus = currentSubscription.status == 'active'
        ? 'suspended'
        : 'active';
    final action = newStatus == 'active' ? 'تفعيل' : 'إيقاف';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action الاشتراك'),
        content: Text('هل تريد $action هذا الاشتراك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // إضافة منطق تغيير الحالة هنا
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('سيتم إضافة منطق $action قريباً')),
              );
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  /// تحميل أسماء المستخدمين من Firebase
  Future<void> _loadUserNames() async {
    // تحميل اسم المستخدم الذي أنشأ العنصر
    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null &&
          switchedUser['id'] == currentSubscription.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await _getUserNameFromFirebase(
        currentSubscription.createdBy,
      );
    } on Exception catch (_) {
      createdByName = await _getUserNameFromFirebase(
        currentSubscription.createdBy,
      );
    }

    // تحميل اسم المستخدم الذي حدّث العنصر
    String? updatedByName;
    if (currentSubscription.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null &&
            switchedUser['id'] == currentSubscription.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }

        updatedByName ??= await _getUserNameFromFirebase(
          currentSubscription.updatedBy!,
        );
      } on Exception catch (_) {
        updatedByName = await _getUserNameFromFirebase(
          currentSubscription.updatedBy!,
        );
      }
    }

    if (mounted) {
      setState(() {
        _createdByName = createdByName ?? 'غير محدد';
        _updatedByName = updatedByName;
      });
    }
  }

  /// تحميل اسم المستخدم من Firebase
  Future<String?> _getUserNameFromFirebase(String userId) async {
    if (userId.isEmpty) return null;

    // إذا كان البريد الإلكتروني، نستخرج اسم المستخدم
    if (userId.contains('@')) {
      final username = userId.split('@')[0];
      return username
          .replaceAll('.', ' ')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .split(' ')
          .map(
            (word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                : '',
          )
          .join(' ');
    }

    // تحميل من Firebase
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final emailService = EmailNormalizationService();
        final normalizedEmail = emailService.normalize(currentUser.email!);

        final userDoc = await FirebaseFirestore.instance
            .collection(normalizedEmail)
            .doc('users')
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            final name = userData['name'] as String?;
            if (name != null && name.isNotEmpty) {
              return name;
            }

            final email = userData['email'] as String?;
            if (email != null && email.isNotEmpty) {
              final username = email.split('@')[0];
              return username
                  .replaceAll('.', ' ')
                  .replaceAll('_', ' ')
                  .replaceAll('-', ' ')
                  .split(' ')
                  .map(
                    (word) => word.isNotEmpty
                        ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                        : '',
                  )
                  .join(' ');
            }
          }
        }
      }
    } on Exception catch (_) {
      // في حالة الخطأ، نعود للقيمة الافتراضية
    }

    return userId;
  }

  void _editSubscription() {
    Navigator.of(context)
        .pushNamed(AppRoutes.editSubscription, arguments: currentSubscription)
        .then((result) async {
          // إذا تم التحديث بنجاح، أعد تحميل البيانات من Firestore
          if (result == true && mounted) {
            await _reloadSubscription();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تحديث الاشتراك بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        });
  }

  /// إعادة تحميل بيانات الاشتراك من Firestore
  Future<void> _reloadSubscription() async {
    try {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(
        currentSubscription.organizationEmail,
      );

      final doc = await FirebaseFirestore.instance
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('subscriptions')
          .doc(currentSubscription.id)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        if (data == null) return;
        final mapData = Map<String, dynamic>.from(data);
        if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
          mapData['id'] = doc.id;
        }
        final updatedSubscription = SubscriptionModel.fromJson(mapData);
        setState(() {
          currentSubscription = updatedSubscription;
        });
      }
    } on Exception catch (_) {
      // تجاهل الخطأ
    }
  }

  @override
  void dispose() {
    // إيقاف الاستماع للتحديثات عند إغلاق الصفحة
    _subscriptionBloc?.add(const StopSubscriptionsStreamEvent());
    super.dispose();
  }

  void _deleteSubscription() {
    if (isSaving) return;
    _operationCompleted = false;
    DeleteSubscriptionDialog.show(
      context,
      currentSubscription,
      context.read<SubscriptionBloc>(),
      onDeleted: () {
        // العودة إلى الصفحة السابقة بعد الحذف مع تأخير صغير
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      },
    );
  }
}
