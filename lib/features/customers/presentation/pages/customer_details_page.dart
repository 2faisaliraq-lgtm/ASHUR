// ignore_for_file: use_build_context_synchronously

import 'dart:async';

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
import '../../../../core/services/invoice_numbering_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/pdf/pdf_settings_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/smart_number_formatter.dart';
import '../../../../core/widgets/credit_limit_warning_dialog.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../../invoices/presentation/bloc/invoice_bloc.dart';
import '../../domain/entities/customer_entity.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_drawer.dart';
import '../widgets/delete_customer_dialog.dart';

/// صفحة تفاصيل العميل
class CustomerDetailsPage extends StatefulWidget {
  const CustomerDetailsPage({required this.customer, super.key});
  final CustomerEntity customer;

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage>
    with SaveOperationMixin<CustomerDetailsPage> {
  late CustomerEntity currentCustomer;
  final FormattingService _formattingService = FormattingService();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canManageStatus = false;
  bool _canCreateSalesInvoice = false;
  bool _canCreateCashInvoice = false;
  bool _canCreateSalesReturn = false;
  bool _canSendMessages = false;
  bool _operationCompleted = false;
  String? _createdByName;
  CustomerBloc? _customerBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // حفظ مرجع الـ bloc لاستخدامه بأمان في dispose
    _customerBloc = context.read<CustomerBloc>();
  }

  @override
  void initState() {
    super.initState();
    _formattingService.initialize();
    currentCustomer = widget.customer;
    _loadPermissions();
    _loadUserNames();

    // بدء الاستماع للتحديثات الفورية للعملاء
    final customerBloc = context.read<CustomerBloc>();
    customerBloc.add(
      StartCustomersStreamEvent(widget.customer.organizationEmail),
    );
  }

  Future<void> _loadPermissions() async {
    final canEdit = await _permissionChecker.hasPermission('customers_edit');
    final canDelete = await _permissionChecker.hasPermission(
      'customers_delete',
    );
    final canManageStatus = await _permissionChecker.hasPermission(
      'customers_manage_status',
    );
    final canCreateSalesInvoice = await _permissionChecker.hasPermission(
      'invoices_sales_manage',
    );
    final canCreateCashInvoice = await _permissionChecker.hasPermission(
      'invoices_cash_manage',
    );
    final canCreateSalesReturn = await _permissionChecker.hasPermission(
      'invoices_sales_return_manage',
    );
    final canSendMessages = await _permissionChecker.hasPermission(
      'customers_send_messages',
    );

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
        _canDelete = canDelete;
        _canManageStatus = canManageStatus;
        _canCreateSalesInvoice = canCreateSalesInvoice;
        _canCreateCashInvoice = canCreateCashInvoice;
        _canCreateSalesReturn = canCreateSalesReturn;
        _canSendMessages = canSendMessages;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: const CustomerDrawer(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<CustomerBloc, CustomerState>(
        listener: (context, state) {
          // ✅ هذه شاشة تفاصيل: عملياتها (التفعيل/التحديث)
          // تُنفَّذ عبر أحداث BLoC مباشرة دون نافذة تحميل
          // من الصفحة، وأخطاء الستريم تصل كـ CustomerError.
          // لذلك لا نستدعي failSaveOperation لأنها تُغلق
          // نافذة تحميل غير موجودة فتُغلق شاشة التفاصيل
          // نفسها عند أي خطأ. القاعدة: اعرض رسالة وابقَ
          // في الصفحة.
          if (state is CustomerError && !_operationCompleted) {
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
          } else if (state is CustomerLoaded || state is CustomerStreamActive) {
            // ===== ملاحظة للمبرمجين المستقبليين =====
            // لماذا نتعامل مع CustomerStreamActive هنا؟
            // هذه الصفحة تبدأ ستريم العملاء في initState
            // للتحديث الفوري، والستريم يُصدر
            // CustomerStreamActive (لا CustomerLoaded).
            // بدون التعامل معها كانت الصفحة تعرض بيانات
            // قديمة رغم تشغيل الستريم.
            // ==========================================
            final customers = state is CustomerLoaded
                ? state.customers
                : (state as CustomerStreamActive).customers;

            // التحقق من وجود العميل في القائمة المحدثة
            final customerExists = customers.any(
              (customer) => customer.id == currentCustomer.id,
            );
            if (!customerExists && _operationCompleted) {
              // العميل تم حذفه، العودة إلى الصفحة السابقة
              // (بدلاً من completeSaveOperation التي تُغلق نافذة
              // تحميل غير موجودة فتحدث إغلاقاً مزدوجاً)
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
              Navigator.of(context).pop();
              return;
            }

            // تحديث بيانات العميل دائماً
            final updatedCustomer = customers.firstWhere(
              (customer) => customer.id == currentCustomer.id,
              orElse: () => currentCustomer,
            );

            if (mounted) {
              setState(() {
                currentCustomer = updatedCustomer;
              });
            }
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerHeader(),
                const SizedBox(height: 6),
                _buildPersonalInfoCard(),
                const SizedBox(height: 6),
                _buildFinancialInfoCard(),
                const SizedBox(height: 6),
                _buildAccountStatusCard(),
                const SizedBox(height: 6),
                _buildSystemInfoCard(),
                const SizedBox(height: 6),
                _buildViewInvoicesButton(),
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
                  'تفاصيل العميل',
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
                  currentCustomer.name,
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
                Navigator.of(context)
                    .pushNamed(
                      AppRoutes.editCustomer,
                      arguments: currentCustomer,
                    )
                    .then((_) {
                      if (mounted) {
                        context.read<CustomerBloc>().add(
                          LoadCustomersEvent(
                            currentCustomer.organizationEmail,
                            forceRefresh: true,
                          ),
                        );
                      }
                    });
                break;
              case 'toggle_status':
                _toggleCustomerStatus();
                break;
              case 'archive_invoices':
                _archiveAllInvoices();
                break;
              case 'delete':
                DeleteCustomerDialog.show(
                  context,
                  currentCustomer,
                  context.read<CustomerBloc>(),
                  onDeleted: () {
                    Navigator.of(context).pop();
                  },
                );
                break;
            }
          },
          itemBuilder: (context) => [
            if (_canEdit)
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: AssyrianTheme.primaryGold),
                    SizedBox(width: 8),
                    Text('تعديل'),
                  ],
                ),
              ),
            if (_canManageStatus)
              PopupMenuItem(
                value: 'toggle_status',
                child: Row(
                  children: [
                    Icon(
                      currentCustomer.status == 'active'
                          ? Icons.block
                          : Icons.check_circle,
                      color: currentCustomer.status == 'active'
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentCustomer.status == 'active'
                          ? 'إلغاء التفعيل'
                          : 'تفعيل',
                    ),
                  ],
                ),
              ),
            if (_canManageStatus) // إذن إدارة الحالة يشمل الأرشفة أيضاً
              const PopupMenuItem(
                value: 'archive_invoices',
                child: Row(
                  children: [
                    Icon(Icons.archive, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('أرشفة جميع الفواتير الحالية'),
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

  Widget _buildCustomerHeader() {
    return DetailScreenHeader(
      title: currentCustomer.name,
      subtitle: _formatEmail(currentCustomer.email),
      icon: Icons.person,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildPersonalInfoCard() {
    return InfoCard(
      title: 'المعلومات الشخصية',
      icon: Icons.person,
      children: [
        DetailRow(label: 'الاسم الكامل', value: currentCustomer.name),
        DetailRow(label: 'البريد الإلكتروني', value: currentCustomer.email),
        DetailRow(label: 'رقم الهاتف', value: currentCustomer.phone),
        if (currentCustomer.address != null &&
            currentCustomer.address!.isNotEmpty)
          DetailRow(label: 'العنوان', value: currentCustomer.address!)
        else
          const DetailRow(
            label: 'العنوان',
            value: 'غير محدد',
            valueColor: Colors.grey,
          ),
        if (currentCustomer.customerGroupName != null &&
            currentCustomer.customerGroupName!.isNotEmpty)
          DetailRow(
            label: 'مجموعة العملاء',
            value: currentCustomer.customerGroupName!,
          )
        else
          const DetailRow(
            label: 'مجموعة العملاء',
            value: 'بدون مجموعة',
            valueColor: Colors.grey,
          ),
      ],
    );
  }

  Widget _buildFinancialInfoCard() {
    return InfoCard(
      title: 'المعلومات المالية',
      icon: Icons.account_balance_wallet,
      children: [
        if (currentCustomer.creditLimit != null)
          DetailRow(
            label: 'حد الدين',
            value: _formattingService.formatCurrency(
              currentCustomer.creditLimit!,
            ),
          )
        else
          const DetailRow(
            label: 'حد الدين',
            value: 'غير محدد',
            valueColor: Colors.grey,
          ),
        DetailRow(
          key: ValueKey(
            'debt_${currentCustomer.totalDebt}_${currentCustomer.updatedAt}',
          ),
          label: 'الحساب',
          value: _formatDebtDisplay(currentCustomer.totalDebt),
          valueColor: _getDebtColor(currentCustomer.totalDebt),
        ),
      ],
    );
  }

  Widget _buildAccountStatusCard() {
    return InfoCard(
      title: 'حالة الحساب',
      icon: Icons.account_circle,
      children: [
        DetailRow(
          label: 'الحالة',
          value: _getStatusText(currentCustomer.status),
          valueColor: _getStatusColor(currentCustomer.status),
        ),
        if (currentCustomer.notes != null && currentCustomer.notes!.isNotEmpty)
          DetailRow(label: 'ملاحظات', value: currentCustomer.notes!)
        else
          const DetailRow(
            label: 'ملاحظات',
            value: 'لا توجد ملاحظات',
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
          value: _formatDate(currentCustomer.createdAt),
        ),
        DetailRow(
          label: 'آخر تحديث',
          value: _formatDate(currentCustomer.updatedAt),
        ),
        DetailRow(label: 'أنشئ بواسطة', value: _createdByName ?? 'غير محدد'),
      ],
    );
  }

  /// بناء زر عرض سجل فواتير العميل
  Widget _buildViewInvoicesButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pushNamed(
            AppRoutes.invoicesList,
            arguments: {
              'customerId': currentCustomer.id,
              'customerName': currentCustomer.name,
              'customerPhone': currentCustomer.phone,
            },
          );
        },
        icon: const Icon(Icons.receipt_long),
        label: const Text('سجل فواتير العميل'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AssyrianTheme.primaryGold,
          foregroundColor: AssyrianTheme.deepBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'نشط';
      case 'inactive':
        return 'غير نشط';
      case 'blocked':
        return 'محظور';
      default:
        return 'غير محدد';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatEmail(String email) {
    if (email.length > 25) {
      return '${email.substring(0, 22)}...';
    }
    return email;
  }

  /// تنسيق عرض الدين مع توضيح "له" أو "عليه" وحساب الحد الائتماني
  String _formatDebtDisplay(double debt) {
    if (debt == 0) {
      return 'لا يوجد حساب';
    } else if (debt > 0) {
      // موجب = العميل عليه دين (مدين)
      if (currentCustomer.creditLimit != null &&
          currentCustomer.creditLimit! > 0) {
        final remainingCredit = currentCustomer.creditLimit! - debt;
        if (remainingCredit < 0) {
          return 'عليه: ${_formattingService.formatCurrency(debt)}, تجاوز الحد: ${_formattingService.formatCurrency(remainingCredit.abs())}';
        } else {
          return 'عليه: ${_formattingService.formatCurrency(debt)}, متبقي: ${_formattingService.formatCurrency(remainingCredit)}';
        }
      } else {
        return 'عليه: ${_formattingService.formatCurrency(debt)}';
      }
    } else {
      // سالب = العميل لديه حساب (دائن)
      return 'له: ${_formattingService.formatCurrency(debt.abs())}';
    }
  }

  /// تحديد لون الدين
  Color _getDebtColor(double debt) {
    if (debt == 0) {
      return Colors.grey;
    } else if (debt > 0) {
      return Colors.red; // عليه = أحمر
    } else {
      return Colors.green; // له = أخضر
    }
  }

  /// تحميل أسماء المستخدمين من Firebase
  Future<void> _loadUserNames() async {
    // تحميل اسم المستخدم الذي أنشأ العنصر
    String? createdByName;
    if (currentCustomer.createdBy != null &&
        currentCustomer.createdBy!.isNotEmpty) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null &&
            switchedUser['id'] == currentCustomer.createdBy) {
          createdByName = switchedUser['name'] as String?;
        }

        createdByName ??= await _getUserNameFromFirebase(
          currentCustomer.createdBy!,
        );
      } on Exception catch (_) {
        createdByName = await _getUserNameFromFirebase(
          currentCustomer.createdBy!,
        );
      }
    }

    if (mounted) {
      setState(() {
        _createdByName = createdByName ?? 'غير محدد';
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
      // في حالة الخطأ، نعود للقيمة الافتراضية مع تسجيل للتشخيص
      debugPrint('Failed to load user name for $userId');
    }

    return userId;
  }

  void _toggleCustomerStatus() {
    if (isSaving) return;
    _operationCompleted = false;
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      // تحديد الحالة الجديدة بناءً على الحالة الحالية
      // دورة الانتقال: نشط → غير نشط → محظور → نشط
      var newStatus = currentCustomer.status == 'active'
          ? 'inactive'
          : (currentCustomer.status == 'inactive' ? 'blocked' : 'active');

      // التحقق من إمكانية الانتقال إلى الحالة الجديدة
      if (!currentCustomer.canTransitionToStatus(newStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن الانتقال من الحالة ${currentCustomer.status} إلى $newStatus',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final updatedCustomer = CustomerEntity(
        id: currentCustomer.id,
        organizationEmail: currentCustomer.organizationEmail,
        name: currentCustomer.name,
        email: currentCustomer.email,
        phone: currentCustomer.phone,
        address: currentCustomer.address,
        customerGroupId: currentCustomer.customerGroupId,
        customerGroupName: currentCustomer.customerGroupName,
        creditLimit: currentCustomer.creditLimit,
        openingBalance: currentCustomer.openingBalance,
        totalPurchases: currentCustomer.totalPurchases,
        totalDebt: currentCustomer.totalDebt,
        status: newStatus,
        notes: currentCustomer.notes,
        createdBy: currentCustomer.createdBy,
        createdAt: currentCustomer.createdAt,
        updatedAt: DateTime.now(),
        invoiceIds: currentCustomer.invoiceIds,
        logIds: currentCustomer.logIds,
      );

      // إرسال الحدث لتحديث العميل
      context.read<CustomerBloc>().add(UpdateCustomerEvent(updatedCustomer));

      // تحديث الحالة المحلية فوراً لتحسين تجربة المستخدم
      setState(() {
        currentCustomer = updatedCustomer;
      });
    }
  }

  /// بناء الأزرار العائمة
  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر إرسال رسالة واتساب للدين
        if (currentCustomer.totalDebt > 0 && _canSendMessages)
          FloatingActionButton.extended(
            onPressed: _sendDebtReminderWhatsApp,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            heroTag: 'whatsapp_debt',
            icon: Icon(Icons.message, size: 20.sp),
            label: Text(
              'تذكير بالدين',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
          ),
        if (currentCustomer.totalDebt > 0 && _canSendMessages)
          SizedBox(height: 12.h),
        // زر الإيصال النقدي
        if (_canCreateCashInvoice)
          FloatingActionButton.extended(
            onPressed: _navigateToCashReceipts,
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            heroTag: 'cash_receipt',
            icon: Icon(Icons.payments, size: 20.sp),
            label: Text(
              'مبلغ نقدي',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
          ),
        if (_canCreateCashInvoice) SizedBox(height: 12.h),
        // زر إنشاء فاتورة مبيعات
        if (_canCreateSalesInvoice)
          FloatingActionButton.extended(
            onPressed: _navigateToCreateInvoice,
            backgroundColor: AssyrianTheme.primaryGold,
            foregroundColor: AssyrianTheme.deepBlue,
            heroTag: 'create_invoice',
            icon: Icon(Icons.receipt_long, size: 20.sp),
            label: Text(
              'فاتورة مبيعات',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
          ),
        if (_canCreateSalesInvoice) SizedBox(height: 8.h),
        // زر فاتورة مرجع بيع
        if (_canCreateSalesReturn)
          FloatingActionButton.extended(
            onPressed: _navigateToSalesReturnInvoice,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            heroTag: 'sales_return',
            icon: Icon(Icons.refresh, size: 20.sp),
            label: Text(
              'فاتورة مرجع بيع',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  /// أرشفة جميع فواتير العميل بدون تصفير الحساب
  void _archiveAllInvoices() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.archive, color: Colors.indigo, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'أرشفة جميع الفواتير الحالية',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'تفاصيل عملية الأرشفة:',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '• أرشفة جميع الفواتير الحالية في القائمة',
                    style: TextStyle(fontSize: 13.sp, color: Colors.blue[700]),
                  ),
                  Text(
                    '• تحديث حالة الفواتير إلى "مدفوعة"',
                    style: TextStyle(fontSize: 13.sp, color: Colors.blue[700]),
                  ),
                  Text(
                    '• نقل الفواتير إلى الأرشيف',
                    style: TextStyle(fontSize: 13.sp, color: Colors.blue[700]),
                  ),
                  Text(
                    '• الحساب يبقى كما هو (لا يتم تصفيره)',
                    style: TextStyle(fontSize: 13.sp, color: Colors.blue[700]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'هل تريد أرشفة جميع فواتير العميل الحالية؟',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            ),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _executeArchiveInvoices();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.archive, size: 16.sp),
                SizedBox(width: 6.w),
                Text(
                  'أرشفة جميع الفواتير الحالية',
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
    );
  }

  /// تنفيذ أرشفة الفواتير بدون تصفير الحساب
  Future<void> _executeArchiveInvoices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;

      // أرشفة جميع فواتير العميل
      final archiveSuccess = await _payAllCustomerInvoices();

      // إعادة تحميل الفواتير للتأكد من تطبيق التحديثات
      final invoiceBloc = GetIt.instance.get<InvoiceBloc>();
      invoiceBloc.add(LoadInvoicesEvent(user!.email!));

      // انتظار قصير للتأكد من تطبيق التحديثات - تم تقليله من 1000 إلى 300
      await Future.delayed(const Duration(milliseconds: 300));

      // عرض رسالة نجاح فقط إذا نجحت الأرشفة
      if (mounted && archiveSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'تم أرشفة الفواتير بنجاح',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                const Text('• تم أرشفة جميع فواتير العميل'),
                const Text('• تم نقل الفواتير إلى الأرشيف'),
                const Text('• الحساب لم يتغير'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted && !archiveSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في أرشفة الفواتير'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء أرشفة الفواتير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// الانتقال إلى صفحة الإيصالات النقدية
  void _navigateToCashReceipts() {
    _showCashReceiptDialog();
  }

  /// عرض نافذة المبلغ النقدي
  void _showCashReceiptDialog() {
    var amountController = TextEditingController();
    var notesController = TextEditingController();
    var selectedColor = Colors.grey; // لون محايد - لا شيء محدد افتراضياً
    bool? isDebit; // null = غير محدد، true = مدين (عليه), false = دائن (له)

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                child: Icon(Icons.payments, color: Colors.green, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'مبلغ نقدي',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400.w,
            child: SingleChildScrollView(
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
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'حدد نوع المبلغ والقيمة المطلوبة',
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
                    'أدخل المبلغ:',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8.h),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: selectedColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        _formattingService.getPriceInputFormatter(),
                      ],
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: selectedColor,
                      ),
                      decoration: InputDecoration(
                        hintText: _formattingService.formatCurrency(0),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: selectedColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: selectedColor.withValues(alpha: 0.05),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'ملاحظات (اختياري):',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8.h),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextField(
                      controller: notesController,
                      keyboardType: TextInputType.text,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[800],
                      ),
                      decoration: InputDecoration(
                        hintText: 'أضف ملاحظة حول هذا المبلغ النقدي...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.note, color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'اختر نوع المبلغ:',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      // مدين (عليه)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isDebit = true;
                              selectedColor = Colors.red;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDebit == true
                                ? Colors.red
                                : Colors.grey[200],
                            foregroundColor: isDebit == true
                                ? Colors.white
                                : Colors.red,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              side: BorderSide(
                                color: isDebit == true
                                    ? Colors.red
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 16.sp,
                                color: isDebit == true
                                    ? Colors.white
                                    : Colors.red,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'عليه',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDebit == true
                                      ? Colors.white
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(width: 12.w),

                      // دائن (له)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isDebit = false;
                              selectedColor = Colors.green;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDebit == false
                                ? Colors.green
                                : Colors.grey[200],
                            foregroundColor: isDebit == false
                                ? Colors.white
                                : Colors.green,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              side: BorderSide(
                                color: isDebit == false
                                    ? Colors.green
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.trending_down,
                                size: 16.sp,
                                color: isDebit == false
                                    ? Colors.white
                                    : Colors.green,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'له',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDebit == false
                                      ? Colors.white
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final amount = amountController.text.trim();
                        final notes = notesController.text.trim();
                        if (amount.isNotEmpty && isDebit != null) {
                          Navigator.of(context).pop();
                          final type = isDebit! ? 'payment' : 'receipt';
                          _processCashReceipt(amount, type, notes: notes);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'حفظ المبلغ النقدي',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // الزر المدمج
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _clearAccountAndArchive();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment_outlined, size: 18.sp),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'تصفير الحساب وأرشفة جميع الفواتير الحالية',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(Icons.archive_outlined, size: 18.sp),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
              child: Text(
                'إلغاء',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// معالجة الإيصال النقدي
  Future<void> _processCashReceipt(
    String amount,
    String type, {
    String? notes,
  }) async {
    try {
      // عرض نافذة التحميل
      if (mounted) {
        LoadingWidget.showLoadingDialog(
          context,
          message: 'جاري معالجة الإيصال النقدي...',
          subtitle: 'الرجاء الانتظار...',
          icon: Icons.payments,
          iconColor: Colors.green,
        );
      }

      // إزالة التنسيق وتحويل إلى رقم
      final textAmount = SmartNumberFormatter.convertToEnglishNumbers(amount);
      final cleanAmount = textAmount
          .replaceAll(_formattingService.thousandsSeparator, '')
          .replaceAll(_formattingService.decimalSeparator, '.');
      final parsedAmount = double.parse(cleanAmount);

      if (parsedAmount <= 0) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // الحصول على اسم المستخدم الفعلي
      String createdBy;
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] != null) {
          createdBy = switchedUser['id'] as String;
        } else {
          createdBy = user!.uid;
        }
      } on Exception catch (_) {
        createdBy = user!.uid;
      }

      // إنشاء فاتورة مبلغ نقدي وانتظار اكتمال العملية
      final invoiceCreated = await _createCashReceiptInvoice(
        amount: type == 'payment'
            ? -parsedAmount // سالب لزيادة الدين (عليه)
            : parsedAmount, // موجب لتقليل الدين (له)
        type: type,
        notes: notes,
        organizationEmail: user!.email!,
        createdBy: createdBy,
      );

      // إذا تم إلغاء الفاتورة، أغلق نافذة التحميل وارجع
      if (!invoiceCreated) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // إعادة تحميل بيانات العميل من Firebase مع إجبار التحديث من السيرفر
      if (mounted) {
        final customerBloc = context.read<CustomerBloc>();
        customerBloc.add(LoadCustomersEvent(user.email!, forceRefresh: true));

        final invoiceBloc = GetIt.instance.get<InvoiceBloc>();
        invoiceBloc.add(LoadInvoicesEvent(user.email!));
      }

      // عرض رسالة نجاح
      String typeText;
      if (type == 'payment') {
        typeText = 'مبلغ عليه (إعطاء مبلغ نقدي للعميل)';
      } else {
        typeText = 'مبلغ له (استلام مبلغ نقدي من العميل)';
      }

      // إغلاق نافذة التحميل
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء إيصال $typeText بمبلغ ${_formattingService.formatNumber(parsedAmount)}\nتم تحديث الحساب',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on Exception catch (e) {
      // إغلاق نافذة التحميل
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } on Exception {
          // تجاهل الأخطاء
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء معالجة الإيصال: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// تصفير الحساب وأرشفة جميع الفواتير الحالية
  void _clearAccountAndArchive() {
    if (currentCustomer.totalDebt != 0) {
      final debtAmount = _formattingService.formatNumber(
        currentCustomer.totalDebt.abs(),
      );
      final isDebit = currentCustomer.totalDebt > 0; // عليه

      // عرض تأكيد للمستخدم
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.payment, color: Colors.indigo, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'تأكيد تصفير الحساب',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'تفاصيل عملية التصفير:',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.blue[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      isDebit
                          ? '• تصفير الدين المستحق عليه: $debtAmount'
                          : '• تصفير المبلغ المستحق له: $debtAmount',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      '• إنشاء فاتورة نقدية لتوثيق العملية',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      '• أرشفة جميع فواتير العميل (تحديث الحالة إلى مدفوعة)',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      '• إغلاق الحساب وتصفير الحساب نهائياً',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                isDebit
                    ? 'هل تريد تصفير دين العميل وأرشفة جميع فواتيره؟'
                    : 'هل تريد تصفير المبلغ المستحق للعميل وأرشفة جميع فواتيره؟',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
              child: Text(
                'إلغاء',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _executeClearAccountAndArchive(debtAmount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 16.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'تصفير الحساب',
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
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الحساب مصفر بالفعل\nالحساب الحالي: ${_formatDebtDisplay(currentCustomer.totalDebt)}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// تنفيذ تصفير الحساب وأرشفة جميع الفواتير الحالية
  ///
  /// ملاحظة للمبرمجين المستقبليين:
  /// هذه العملية الآن ذرية بالكامل داخل InvoiceRepositoryImpl:
  /// 1. أرشفة جميع الفواتير غير المؤرشفة للعميل.
  /// 2. إنشاء فاتورة التصفير.
  /// 3. تحديث دين العميل إلى 0.
  /// 4. تحديث الصندوق.
  /// إذا فشل أي جزء، تفشل العملية بأكملها دون أي تعديل.
  /// لا تنفذ هذه العملية يدوياً خارج الـ Repository لأن ذلك سيعيد المشكلة القديمة.
  Future<void> _executeClearAccountAndArchive(String debtAmount) async {
    // عرض نافذة التحميل بتصميم احترافي
    LoadingWidget.showLoadingDialog(
      context,
      message: 'جاري تصفير الحساب',
      subtitle: 'يرجى الانتظار حتى يتم تصفير الحساب وأرشفة الفواتير...',
      icon: Icons.account_balance_wallet,
      iconColor: Colors.indigo,
    );

    // انتظار قصير للتأكد من ظهور مؤشر التحميل
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
      final userEmail = user.email!;

      final debtAmountDouble =
          double.tryParse(debtAmount.replaceAll(',', '')) ?? 0;

      if (debtAmountDouble == 0) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      String createdBy;
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] != null) {
          createdBy = switchedUser['id'] as String;
        } else {
          createdBy = user.uid;
        }
      } on Exception catch (_) {
        createdBy = user.uid;
      }

      final invoiceRepository = GetIt.instance.get<InvoiceRepository>();
      final result = await invoiceRepository.clearCustomerAccount(
        organizationEmail: userEmail,
        customerId: currentCustomer.id,
        customerName: currentCustomer.name,
        customerPhone: currentCustomer.phone,
        createdBy: createdBy,
        debtAmount: debtAmountDouble,
      );

      final success = result.isRight();
      final clearanceInvoiceNumber = result.fold(
        (failure) => '',
        (data) => data['invoiceNumber'] as String? ?? '',
      );

      // إعادة تحميل بيانات العملاء بشكل أفضل
      if (mounted) {
        context.read<CustomerBloc>().add(
          LoadCustomersEvent(userEmail, forceRefresh: true),
        );
      }

      // إعادة تحميل الفواتير
      if (mounted) {
        final invoiceBloc = GetIt.instance.get<InvoiceBloc>();
        invoiceBloc.add(LoadInvoicesEvent(userEmail));
      }

      // إرسال إشعار تصفير الحساب للعميل
      if (mounted) {
        unawaited(() async {
          try {
            final notificationService = NotificationService();
            await notificationService.sendAccountClearanceNotification(
              organizationEmail: userEmail,
              customerPhone: currentCustomer.phone,
              customerName: currentCustomer.name,
              clearedAmount: debtAmountDouble,
              invoiceNumber: clearanceInvoiceNumber,
            );
          } on Exception catch (_) {
            // تجاهل أخطاء الإشعار
          }
        }());
      }

      // إغلاق مؤشر التحميل
      if (mounted) {
        Navigator.of(context).pop();
      }

      // عرض رسالة نجاح شاملة
      if (mounted && success) {
        final isCustomerOwesUs = currentCustomer.totalDebt > 0;
        final operationText = isCustomerOwesUs
            ? 'تصفير الدين المستحق عليه'
            : 'تصفير المبلغ المستحق له';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'تم تصفير الحساب بنجاح',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text('• تم $operationText: $debtAmount'),
                const Text(
                  '• تم إنشاء إيصال تصفير الحساب وأرشفة جميع الفواتير الحالية',
                ),
                const Text('• تم أرشفة جميع الفواتير السابقة'),
                const Text('• تم إغلاق الحساب وتصفير الحساب نهائياً'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
          ),
        );
      } else if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في تصفير الحساب'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        // إغلاق مؤشر التحميل
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تصفير الحساب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// دفع جميع فواتير العميل وأرشفتها
  ///
  /// ملاحظة للمبرمجين المستقبليين:
  /// هذه العملية الآن ذرية بالكامل داخل InvoiceRepositoryImpl:
  /// 1. أرشفة جميع الفواتير غير المؤرشفة للعميل.
  /// 2. تحديث دين العميل إلى 0.
  /// إذا فشل أي جزء، تفشل العملية بأكملها دون أي تعديل.
  /// لا تنفذ هذه العملية يدوياً خارج الـ Repository لأن ذلك سيعيد المشكلة القديمة.
  Future<bool> _payAllCustomerInvoices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email;
      if (userEmail == null) return false;

      final invoiceRepository = GetIt.instance.get<InvoiceRepository>();
      final result = await invoiceRepository.archiveCustomerInvoices(
        organizationEmail: userEmail,
        customerId: currentCustomer.id,
        customerName: currentCustomer.name,
        customerPhone: currentCustomer.phone,
        createdBy: user!.uid,
      );

      final success = result.isRight();

      if (success) {
        final invoiceBloc = GetIt.instance.get<InvoiceBloc>();
        invoiceBloc.add(LoadInvoicesEvent(userEmail));
      }

      return success;
    } on Exception catch (e) {
      // في حالة الفشل، نعيد تحميل الفواتير ونُسجِّل الخطأ للتشخيص
      debugPrint('Failed to archive customer invoices: $e');
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email;
      if (userEmail != null) {
        final invoiceBloc = GetIt.instance.get<InvoiceBloc>();
        invoiceBloc.add(LoadInvoicesEvent(userEmail));
      }
      return false;
    }
  }

  /// الانتقال إلى صفحة إنشاء فاتورة جديدة للعميل
  void _navigateToCreateInvoice() {
    Navigator.of(context).pushNamed(
      AppRoutes.createInvoice,
      arguments: {
        'customerId': currentCustomer.id,
        'customerName': currentCustomer.name,
        'customerPhone': currentCustomer.phone,
        'customerTotalDebt': currentCustomer.totalDebt,
      },
    );
  }

  /// الانتقال إلى شاشة إنشاء فاتورة مرجع بيع
  void _navigateToSalesReturnInvoice() {
    Navigator.of(context).pushNamed(
      AppRoutes.createInvoice,
      arguments: {
        'type': 'sales_return',
        'customerId': currentCustomer.id,
        'customerName': currentCustomer.name,
        'customerPhone': currentCustomer.phone,
        'customerTotalDebt': currentCustomer.totalDebt,
      },
    );
  }

  /// إنشاء فاتورة مبلغ نقدي
  /// Returns true if invoice was created, false if cancelled
  Future<bool> _createCashReceiptInvoice({
    required double amount,
    required String type,
    required String organizationEmail,
    required String createdBy,
    String? notes, // ملاحظات اختيارية على الفاتورة النقدية
    bool isAccountClearance = false, // معامل لتحديد عملية تصفير الحساب
  }) async {
    bool success = false;
    try {
      // التحقق من حد الائتمان قبل إنشاء فاتورة payment (إعطاء مبلغ نقدي)
      if (type == 'payment' && !isAccountClearance) {
        final currentDebt = currentCustomer.totalDebt;
        final creditLimit = currentCustomer.creditLimit ?? 0;
        final paymentAmount = amount.abs();
        final newDebt = currentDebt + paymentAmount;

        // إذا تجاوز حد الائتمان، عرض تحذير
        if (creditLimit > 0 && newDebt > creditLimit) {
          if (mounted) {
            final shouldContinue = await CreditLimitWarningDialog.show(
              context,
              customerName: currentCustomer.name,
              currentDebt: currentDebt,
              creditLimit: creditLimit,
              invoiceAmount: paymentAmount,
              newDebt: newDebt,
            );

            if (!shouldContinue) {
              if (mounted) {
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
                            'تم إلغاء العملية - لم يتم إنشاء الفاتورة النقدية',
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
              return false; // تم الإلغاء
            }
          }
        }
      }

      final invoiceBloc = GetIt.instance.get<InvoiceBloc>();

      // الحصول على اسم المستخدم الفعلي بنفس طريقة إنشاء الفواتير الأخرى
      String createdBy;

      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] != null) {
          createdBy = switchedUser['id'] as String;
        } else {
          createdBy = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
        }
      } on Exception catch (_) {
        createdBy = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      }

      // تحديد نوع الإيصال والوصف
      final isPayment = type == 'payment'; // زيادة دين

      String description;
      if (isAccountClearance) {
        description = 'تصفير حساب وأرشفة - إغلاق نهائي للحساب';
      } else if (isPayment) {
        description = 'مبلغ نقدي - إعطاء مبلغ نقدي للعميل (عليه)';
      } else {
        description = 'مبلغ نقدي - استلام مبلغ نقدي من العميل (له)';
      }

      // إنشاء رقم الإيصال باستخدام نظام الترقيم الموحد
      final now = DateTime.now();
      String section;
      if (isAccountClearance) {
        section = 'account_clearance'; // CLR = Account Clearance
      } else {
        section = isPayment
            ? 'payment'
            : 'receipt'; // PAY = Payment, REC = Receipt
      }
      final invoiceNumber = InvoiceNumberingService.generateNumberSync(
        section: section,
      );

      // تحديد المبالغ حسب نوع العملية
      double totalAmount, paidAmount, remainingAmount;
      String status;

      if (isAccountClearance) {
        // فواتير تصفير الحساب - نحتفظ بالإشارة الأصلية
        totalAmount = amount.abs();
        paidAmount = amount; // نحتفظ بالإشارة: موجب للاستلام، سالب للإعطاء
        remainingAmount = 0;
        status = 'paid';
      } else if (isPayment) {
        // "عليه" - زيادة دين: نستخدم مبلغ سالب في paidAmount
        // invoice_bloc سيستخدم هذا المبلغ السالب لزيادة الدين
        totalAmount = amount.abs();
        paidAmount = -amount.abs(); // سالب لزيادة الدين
        remainingAmount = 0;
        status = 'paid';
      } else {
        // "له" - تقليل دين: فاتورة مدفوعة بمبلغ سالب
        totalAmount = amount.abs();
        paidAmount = amount.abs(); // استخدام القيمة المطلقة
        remainingAmount = 0;
        status = 'paid';
      }

      // حساب الحساب قبل وبعد الفاتورة
      final balanceBeforeInvoice = currentCustomer.totalDebt;
      double balanceAfterInvoice;

      if (isAccountClearance) {
        // في حالة تصفير الحساب، الحساب بعد الفاتورة يصبح صفر
        balanceAfterInvoice = 0.0;
      } else {
        // للمعاملات النقدية العادية، نحسب التأثير على الحساب
        // إذا كانت العملية "payment" (زيادة دين)، نزيد الحساب
        // إذا كانت العملية "receipt" (تقليل دين)، ننقص الحساب
        balanceAfterInvoice = isPayment
            ? balanceBeforeInvoice +
                  amount
                      .abs() // زيادة الدين (موجب)
            : balanceBeforeInvoice - amount.abs(); // تقليل الدين (سالب)
      }

      // إنشاء الفاتورة
      final invoice = InvoiceEntity(
        id: '', // سيتم إنشاء معرف تلقائياً
        invoiceNumber: invoiceNumber,
        customerName: currentCustomer.name,
        customerPhone: currentCustomer.phone,
        customerId: currentCustomer.id,
        invoiceDate: DateTime.now(),
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        status: status,
        type: 'cash', // فاتورة نقدية
        items: const [],
        cashTransactionType: isAccountClearance
            ? 'clearance'
            : (isPayment ? 'payment' : 'receipt'),
        cashAmount: amount.abs(),
        cashUserNote: isAccountClearance ? null : (notes?.trim() ?? ''),
        notes: isAccountClearance
            ? 'فاتورة تصفير حساب - تم تصفير الحساب وأرشفة جميع الفواتير'
            : '${isPayment ? 'إيصال نقدي - إعطاء مبلغ نقدي للعميل' : 'إيصال نقدي - استلام مبلغ نقدي من العميل'} بمبلغ ${amount.abs()}${notes?.trim().isNotEmpty == true ? '\nملاحظة: ${notes!.trim()}' : ''}',
        organizationEmail: organizationEmail,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: createdBy, // استخدام اسم المستخدم الفعلي
        balanceBeforeInvoice: balanceBeforeInvoice,
        balanceAfterInvoice: balanceAfterInvoice,
        // أرشفة فاتورة تصفير الحساب فوراً
        isArchived: isAccountClearance,
      );

      // تم فحص حد الائتمان أعلاه، وتم أخذ موافقة المستخدم عند التجاوز؛
      // تخطي الفحص المكرر في InvoiceBloc حتى لا يمنع الحفظ بعد الموافقة.
      invoiceBloc.add(AddInvoiceEvent(invoice, skipCreditCheck: true));

      // انتظار حتى يكتمل حفظ الفاتورة وتحديث الحساب
      // نستخدم stream للاستماع لحالة InvoiceBloc
      success = false;
      try {
        final state = await invoiceBloc.stream
            .firstWhere(
              (state) =>
                  state is InvoiceLoaded ||
                  state is InvoiceOperationSuccess ||
                  state is InvoiceError,
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => InvoiceError('انتهت مهلة العملية'),
            );
        success = state is InvoiceLoaded || state is InvoiceOperationSuccess;
      } on TimeoutException {
        success = false;
      }

      // انتظار إضافي لضمان تحديث Firebase
      await Future.delayed(const Duration(milliseconds: 1000));

      // إعادة تحميل بيانات العميل
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        context.read<CustomerBloc>().add(
          LoadCustomersEvent(user.email!, forceRefresh: true),
        );
      }

      // إظهار رسالة النجاح أو الخطأ بناءً على الحالة
      if (mounted) {
        if (success) {
          // نجاح الحفظ - إرسال إشعار مع شعار
          // لا نُظهر الإشعار للمنشئ نفسه
          final currentUser = FirebaseAuth.instance.currentUser;
          final bool shouldNotifyLocal =
              currentUser == null || currentUser.uid != createdBy;

          final switchedUser = await SessionService.getSwitchedUser();

          // إظهار رسالة نجاح
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم ${isPayment ? 'إعطاء' : 'استلام'} المبلغ بنجاح',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // فشل الحفظ
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في حفظ الفاتورة'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } on Exception catch (_) {
      // خطأ في إنشاء فاتورة المبلغ النقدي
      return false;
    }
    return success; // تم إنشاء الفاتورة بنجاح
  }

  /// إرسال رسالة تذكير بالدين عبر الواتساب
  Future<void> _sendDebtReminderWhatsApp() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;

      // التحقق من تفعيل الإشعارات
      final notificationService = NotificationService();
      final isEnabled = await notificationService.isWhatsAppNotificationEnabled(
        user!.email!,
      );

      if (!isEnabled) {
        if (mounted) {
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
        if (mounted) {
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
      if (currentCustomer.phone.isEmpty) {
        if (mounted) {
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
      if (currentCustomer.totalDebt <= 0) {
        if (mounted) {
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
        currentCustomer.organizationEmail,
      );
      final message = WhatsAppService.createDebtReminderMessageSimple(
        customerName: currentCustomer.name,
        debtAmount: currentCustomer.totalDebt,
        organizationName: organizationName,
      );

      // إرسال الرسالة
      final success = await WhatsAppService.sendMessage(
        phoneNumber: currentCustomer.phone,
        message: message,
      );

      if (mounted) {
        // إعادة تحميل البيانات عند العودة من الواتساب

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم إرسال تذكير بالدين إلى ${currentCustomer.name}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل في إرسال الرسالة. تأكد من تثبيت الواتساب'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        // إعادة تحميل البيانات عند العودة من الواتساب

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

  @override
  void dispose() {
    // إيقاف الاستماع للتحديثات عند إغلاق الصفحة
    _customerBloc?.add(const StopCustomersStreamEvent());
    super.dispose();
  }
}
