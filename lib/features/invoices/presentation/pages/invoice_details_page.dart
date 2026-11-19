import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/pdf/pdf_settings_service.dart';
import '../../../../core/services/pdf/pdf_sharing_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../inventory/domain/repositories/product_repository.dart';
import '../../../subscriptions/domain/entities/subscription_entity.dart';
import '../../../subscriptions/domain/repositories/subscription_repository.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/invoice_template_entity.dart';
import '../bloc/invoice_bloc.dart';
import '../widgets/invoice_drawer.dart';

/// صفحة تفاصيل الفاتورة
class InvoiceDetailsPage extends StatefulWidget {
  const InvoiceDetailsPage({required this.invoice, super.key});
  final InvoiceEntity invoice;

  @override
  State<InvoiceDetailsPage> createState() => _InvoiceDetailsPageState();
}

class _InvoiceDetailsPageState extends State<InvoiceDetailsPage> {
  late InvoiceEntity _invoice;

  void _applyUpdatedInvoice(InvoiceEntity invoice) {
    if (!mounted || invoice.id != _invoice.id || invoice == _invoice) return;
    setState(() => _invoice = invoice);
    _loadAllPermissionsAndData();
    _loadSubscriptionData();
  }

  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  bool? _hasInventoryPermission;
  bool? _hasCustomerPermission;
  SubscriptionEntity? _subscription; // بيانات الاشتراك المرتبط بالفاتورة
  bool _isLoadingSubscription = false;
  String? _createdByName;
  String? _updatedByName;
  InvoiceBloc? _invoiceBloc;
  SharedPreferences? _prefs; // ✅ تخزين SharedPreferences مؤقتاً

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // حفظ مرجع الـ bloc لاستخدامه بأمان في dispose
    _invoiceBloc = context.read<InvoiceBloc>();
  }

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    // تأجيل تحميل بيانات الاشتراك حتى يكون الـ Bloc متاحًا
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubscriptionData();
    });
    _loadAllPermissionsAndData();
    _loadPrefs();

    // بدء الاستماع للتحديثات الفورية للفواتير
    final invoiceBloc = context.read<InvoiceBloc>();
    invoiceBloc.add(StartInvoicesStreamEvent(_invoice.organizationEmail));
    // ⚠️ ملاحظة للمبرمجين المستقبليين: الستريم يُStarted هنا في initState
    // لكن لا يتم إيقافه في dispose() (السطر 56-59 لا يحتوي على
    // StopInvoicesStreamEvent). هذا يسبب تسريب StreamSubscription
    // واستمرار الاستماع للتغييرات حتى بعد إغلاق الصفحة.
    // الحل: إضافة _invoiceBloc.add(const StopInvoicesStreamEvent())
    // في dispose() قبل super.dispose().
  }

  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// تحميل SharedPreferences مرة واحدة وتخزينها في متغير.
  /// السبب: SharedPreferences.getInstance() هي عملية I/O بطيئة.
  /// الحل: تحميلها مرة واحدة في initState ثم استخدامها في جميع الدوال.
  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// تم دجم جميع عمليات التحميل في دالة واحدة لتقليل عدد عمليات setState.
  /// السبب: كل setState() يسبب rebuild كامل للصفحة.
  /// الحل: تحميل جميع البيانات ثم استدعاء setState() مرة واحدة فقط.
  Future<void> _loadAllPermissionsAndData() async {
    // تحميل جميع البيانات بشكل متوازٍ
    final results = await Future.wait([
      _permissionChecker.hasPermission(
        _invoice.type == 'sales'
            ? 'invoices_sales_manage'
            : _invoice.type == 'purchase'
            ? 'invoices_purchase_manage'
            : _invoice.type == 'cash'
            ? 'invoices_cash_manage'
            : _invoice.type == 'subscription'
            ? 'invoices_subscription_manage'
            : _invoice.type == 'sales_return'
            ? 'invoices_sales_return_manage'
            : '',
      ),
      _permissionChecker.hasPermission('inventory_view'),
      _permissionChecker.hasPermission('customers_view'),
      _loadUserNamesInternal(),
    ]);

    if (mounted) {
      setState(() {
        _canEdit = results[0] as bool;
        _hasInventoryPermission = results[1] as bool?;
        _hasCustomerPermission = results[2] as bool?;
        _createdByName = (results[3] as Map<String, String?>)['createdByName'];
        _updatedByName = (results[3] as Map<String, String?>)['updatedByName'];
      });
    }
  }

  /// تحميل أسماء المستخدمين بشكل داخلي (بدون setState)
  Future<Map<String, String?>> _loadUserNamesInternal() async {
    String? createdByName;
    String? updatedByName;

    // تحميل اسم المستخدم الذي أنشأ العنصر
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] == _invoice.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await _getUserNameFromFirebase(_invoice.createdBy);
    } on Exception catch (_) {
      createdByName = await _getUserNameFromFirebase(_invoice.createdBy);
    }

    // تحميل اسم المستخدم الذي حدّث العنصر
    if (_invoice.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] == _invoice.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }

        updatedByName ??= await _getUserNameFromFirebase(_invoice.updatedBy!);
      } on Exception catch (_) {
        updatedByName = await _getUserNameFromFirebase(_invoice.updatedBy!);
      }
    }

    return {
      'createdByName': createdByName ?? 'غير محدد',
      'updatedByName': updatedByName,
    };
  }

  /// تحميل بيانات الاشتراك إذا كانت الفاتورة من نوع subscription
  Future<void> _loadSubscriptionData() async {
    if (_invoice.type == 'subscription' && _invoice.subscriptionId != null) {
      setState(() {
        _isLoadingSubscription = true;
      });

      try {
        // استخدام GetIt للحصول على الـ Repository مباشرة
        final subscriptionRepository = GetIt.instance<SubscriptionRepository>();

        final result = await subscriptionRepository.getSubscriptions(
          _invoice.organizationEmail,
        );

        result.fold((failure) {}, (subscriptions) {
          try {
            final subscription = subscriptions.firstWhere(
              (s) => s.id == _invoice.subscriptionId,
            );
            setState(() {
              _subscription = subscription;
            });
          } on Exception catch (_) {
            // تجاهل الأخطاء
          }
        });
      } on Exception catch (_) {
        // تجاهل الأخطاء
      } finally {
        setState(() {
          _isLoadingSubscription = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvoiceBloc, InvoiceState>(
      listener: (context, state) {
        if (state is InvoicePdfGenerated) {
          // عرض خيارات المشاركة والطباعة
          _showPdfOptions(context, state.pdfFile);
        } else if (state is InvoiceError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is InvoiceLoaded || state is InvoiceStreamActive) {
          final invoices = state is InvoiceLoaded
              ? state.invoices
              : (state as InvoiceStreamActive).invoices;
          for (final invoice in invoices) {
            if (invoice.id == _invoice.id) {
              _applyUpdatedInvoice(invoice);
              break;
            }
          }
        }
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildAppBar(context),
        drawer: const InvoiceDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _buildInvoiceHeader(),
              const SizedBox(height: 6),
              _buildBasicInfoCard(),
              const SizedBox(height: 6),
              _buildCustomerInfoCard(),
              const SizedBox(height: 6),
              // إضافة قسم معلومات الاشتراك للفواتير من نوع subscription
              if (_invoice.type == 'subscription') ...[
                _buildSubscriptionInfoCard(),
                const SizedBox(height: 6),
              ],
              _buildItemsCard(),
              const SizedBox(height: 6),
              _buildAmountsCard(),
              const SizedBox(height: 6),
              _buildStatusCard(),
              const SizedBox(height: 6),
              _buildActionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
            child: Text(
              'تفاصيل الفاتورة',
              style: AssyrianTheme.titleStyle.copyWith(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 18,
                ),
                color: AssyrianTheme.primaryGold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        // زر توليد PDF
        IconButton(
          onPressed: () => _generatePdf(context),
          icon: Icon(Icons.picture_as_pdf, color: Colors.red, size: 24.sp),
          tooltip: 'توليد PDF',
        ),
        if (_canEdit)
          IconButton(
            onPressed: () async {
              final result = await Navigator.of(
                context,
              ).pushNamed(AppRoutes.editInvoice, arguments: _invoice);
              if (!mounted) return;
              if (result is InvoiceEntity) {
                _applyUpdatedInvoice(result);
              }
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل الفاتورة',
          ),
      ],
    );
  }

  Widget _buildInvoiceHeader() {
    return DetailScreenHeader(
      title: _invoice.invoiceNumber,
      subtitle: _invoice.customerName,
      icon: Icons.receipt_long,
      iconBackgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      iconForegroundColor: AssyrianTheme.primaryGold,
    );
  }

  Widget _buildBasicInfoCard() {
    // للفواتير النقدية، نعرض معلومات مختلفة
    if (_invoice.type == 'cash') {
      return _buildCashBasicInfoCard();
    }

    // للفواتير العادية
    return _buildRegularBasicInfoCard();
  }

  /// بناء كارت المعلومات الأساسية للفاتورة النقدية
  Widget _buildCashBasicInfoCard() {
    return InfoCard(
      title: 'معلومات المعاملة النقدية',
      icon: Icons.receipt_outlined,
      children: [
        DetailRow(label: 'رقم المعاملة', value: _invoice.invoiceNumber),
        const DetailRow(label: 'نوع المعاملة', value: 'معاملة نقدية'),
        DetailRow(
          label: 'تاريخ المعاملة',
          value: _formattingService.formatInvoiceDate(_invoice.invoiceDate),
        ),
        DetailRow(
          label: 'وقت التنفيذ',
          value: _formattingService.formatDateTime(_invoice.createdAt),
        ),
        // إضافة معلومة عن تأثير المعاملة
        _buildCashImpactRow(),
        DetailRow(
          label: 'ملاحظة',
          value: _invoice.displayNotes?.trim().isNotEmpty == true
              ? _invoice.displayNotes!
              : 'لا توجد ملاحظات',
        ),
      ],
    );
  }

  /// بناء كارت المعلومات الأساسية للفاتورة العادية
  Widget _buildRegularBasicInfoCard() {
    return InfoCard(
      title: 'المعلومات الأساسية',
      icon: Icons.info_outline,
      children: [
        DetailRow(label: 'رقم الفاتورة', value: _invoice.invoiceNumber),
        DetailRow(
          label: 'نوع الفاتورة',
          value: _invoice.isSalesReturn || _invoice.type == 'sales_return'
              ? 'فاتورة مرجع بيع'
              : _invoice.type == 'sales'
              ? 'فاتورة مبيعات'
              : _invoice.type == 'purchase'
              ? 'فاتورة مشتريات'
              : _invoice.type == 'subscription'
              ? 'فاتورة اشتراك'
              : 'فاتورة نقدية',
        ),
        DetailRow(
          label: 'تاريخ الفاتورة',
          value: _formattingService.formatInvoiceDate(_invoice.invoiceDate),
        ),
        DetailRow(
          label: 'الملاحظات',
          value: _invoice.notes?.trim().isNotEmpty == true
              ? _invoice.notes!.trim()
              : 'لا توجد ملاحظات',
        ),
      ],
    );
  }

  /// بناء صف تأثير المعاملة النقدية
  Widget _buildCashImpactRow() {
    String impactText;
    Color impactColor;
    IconData impactIcon;

    if (_invoice.notes != null) {
      if (_invoice.notes!.contains('إعطاء مبلغ نقدي للعميل') ||
          _invoice.notes!.contains('عليه')) {
        impactText = 'إعطاء مبلغ نقدي للعميل (عليه)';
        impactColor = Colors.red;
        impactIcon = Icons.trending_up;
      } else if (_invoice.notes!.contains('استلام مبلغ نقدي من العميل') ||
          _invoice.notes!.contains('له')) {
        impactText = 'استلام مبلغ نقدي من العميل (له)';
        impactColor = Colors.green;
        impactIcon = Icons.trending_down;
      } else if (_invoice.notes!.contains('تصفير حساب')) {
        impactText = 'تصفير حساب العميل';
        impactColor = Colors.indigo;
        impactIcon = Icons.clear_all;
      } else {
        impactText = 'تعديل حساب العميل';
        impactColor = Colors.blue;
        impactIcon = Icons.swap_horiz;
      }
    } else {
      impactText = 'تعديل حساب العميل';
      impactColor = Colors.blue;
      impactIcon = Icons.swap_horiz;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              'تأثير المعاملة',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: impactColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: impactColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(impactIcon, color: impactColor, size: 16.sp),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      impactText,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: impactColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    final canNavigateToCustomer = _hasCustomerPermission ?? false;

    return InfoCard(
      title: 'معلومات العميل',
      icon: Icons.person_outline,
      children: [
        if (canNavigateToCustomer)
          InkWell(
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
                      _invoice.customerName,
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
        else
          DetailRow(label: 'اسم العميل', value: _invoice.customerName),
        DetailRow(
          label: 'رقم الهاتف',
          value: _invoice.customerPhone.isNotEmpty
              ? _invoice.customerPhone
              : 'غير محدد',
        ),
      ],
    );
  }

  /// الانتقال إلى شاشة تفاصيل العميل
  Future<void> _navigateToCustomerDetails() async {
    if (_invoice.customerId == null || _invoice.customerId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد عميل مرتبط بهذه الفاتورة'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final customerRepository = GetIt.instance<CustomerRepository>();
      final customerResult = await customerRepository.getCustomers(
        _invoice.organizationEmail,
      );

      if (!mounted) return;

      await customerResult.fold(
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
        (customers) async {
          try {
            final customer = customers.firstWhere(
              (c) => c.id == _invoice.customerId,
            );

            if (!mounted) return;

            await Navigator.of(
              context,
            ).pushNamed(AppRoutes.customerDetails, arguments: customer);
          } on Exception catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('العميل غير موجود'),
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

  /// بناء كارت معلومات الاشتراك
  Widget _buildSubscriptionInfoCard() {
    if (_isLoadingSubscription) {
      return InfoCard(
        title: 'معلومات الاشتراك',
        icon: Icons.subscriptions,
        children: [
          LoadingWidget(message: 'جاري التحميل...'),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل معلومات الاشتراك...',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_subscription == null) {
      return InfoCard(
        title: 'معلومات الاشتراك',
        icon: Icons.subscriptions,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 20.sp),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'لم يتم العثور على معلومات الاشتراك المرتبط بهذه الفاتورة',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return InfoCard(
      title: 'معلومات الاشتراك',
      icon: Icons.subscriptions,
      children: [
        // معلومات أساسية عن الاشتراك
        DetailRow(label: 'اسم الاشتراك', value: _subscription!.name),
        DetailRow(label: 'نوع الاشتراك', value: _subscription!.type),
        if (_subscription!.description != null &&
            _subscription!.description!.isNotEmpty)
          DetailRow(label: 'الوصف', value: _subscription!.description!),

        const SizedBox(height: 12),

        // معلومات التواريخ والمدة
        _buildSubscriptionDatesSection(),

        const SizedBox(height: 12),

        // حالة الاشتراك
        _buildSubscriptionStatusSection(),

        const SizedBox(height: 12),

        // معلومات إضافية
        _buildSubscriptionAdditionalInfo(),
      ],
    );
  }

  /// بناء قسم تواريخ الاشتراك
  Widget _buildSubscriptionDatesSection() {
    final subscription = _subscription!;
    final startDate = subscription.startDate;
    final endDate = subscription.endDate;

    // حساب المدة الفعلية
    final actualDuration = endDate.difference(startDate).inDays;
    final currentMonth = startDate.month;
    final currentYear = startDate.year;
    final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withValues(alpha: 0.05),
            Colors.indigo.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.purple, size: 16.sp),
              const SizedBox(width: 8),
              Text(
                'فترة الاشتراك',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildDateInfoRow(
            'تاريخ التفعيل',
            _formattingService.formatDate(startDate),
            Icons.play_circle_outline,
            Colors.green,
          ),

          _buildDateInfoRow(
            'تاريخ الانتهاء',
            _formattingService.formatDate(endDate),
            Icons.stop_circle_outlined,
            Colors.red,
          ),

          _buildDateInfoRow(
            'مدة الاشتراك',
            '$actualDuration يوم',
            Icons.timelapse,
            Colors.blue,
          ),

          // معلومات إضافية عن الشهر
          if (actualDuration != daysInMonth) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber[700],
                    size: 14.sp,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ملاحظة: الاشتراك لمدة $actualDuration يوم، بينما الشهر الحالي (${_getMonthName(currentMonth)} $currentYear) يحتوي على $daysInMonth يوم',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.amber[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// بناء صف معلومات التاريخ
  Widget _buildDateInfoRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14.sp),
          const SizedBox(width: 8),
          SizedBox(
            width: 100.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء قسم حالة الاشتراك
  Widget _buildSubscriptionStatusSection() {
    final subscription = _subscription!;
    final now = DateTime.now();
    final isActive = subscription.status == 'active';
    final isExpired = now.isAfter(subscription.endDate);
    final daysRemaining = subscription.daysRemaining;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isExpired) {
      statusColor = Colors.red;
      statusText = 'منتهي الصلاحية';
      statusIcon = Icons.cancel;
    } else if (isActive) {
      if (daysRemaining <= 7) {
        statusColor = Colors.orange;
        statusText = 'ينتهي قريباً ($daysRemaining أيام متبقية)';
        statusIcon = Icons.warning;
      } else {
        statusColor = Colors.green;
        statusText = 'نشط ($daysRemaining يوم متبقي)';
        statusIcon = Icons.check_circle;
      }
    } else {
      statusColor = Colors.grey;
      statusText = _getSubscriptionStatusText(subscription.status);
      statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20.sp),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالة الاشتراك',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: statusColor,
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

  /// بناء معلومات إضافية عن الاشتراك
  Widget _buildSubscriptionAdditionalInfo() {
    final subscription = _subscription!;

    return Column(
      children: [
        if (subscription.isAutoRenew) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.autorenew, color: Colors.blue, size: 16.sp),
                const SizedBox(width: 8),
                Text(
                  'التجديد التلقائي مفعل',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (subscription.renewalCount > 0) ...[
          DetailRow(
            label: 'عدد مرات التجديد',
            value: '${subscription.renewalCount} مرة',
          ),
        ],

        if (subscription.lastRenewalDate != null) ...[
          DetailRow(
            label: 'آخر تجديد',
            value: _formattingService.formatDate(subscription.lastRenewalDate!),
          ),
        ],
      ],
    );
  }

  /// الحصول على اسم الشهر بالعربية
  String _getMonthName(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return months[month - 1];
  }

  /// الحصول على نص حالة الاشتراك
  String _getSubscriptionStatusText(String status) {
    switch (status) {
      case 'active':
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
        return 'غير محدد';
    }
  }

  Widget _buildItemsCard() {
    // للفواتير النقدية، نعرض معلومات مختلفة
    if (_invoice.type == 'cash') {
      return _buildCashInvoiceDetailsCard();
    }

    // ✅ لفاتورة مرجع البيع، نعرض المواد المرتجعة
    if (_invoice.isSalesReturn && _invoice.returnedItems != null) {
      return _buildReturnedItemsCard();
    }

    // للفواتير العادية، نعرض العناصر التقليدية
    return _buildRegularItemsCard();
  }

  /// ✅ بناء كارت عرض المواد المرتجعة (لفاتورة مرجع البيع)
  Widget _buildReturnedItemsCard() {
    return InfoCard(
      title: 'المواد المرتجعة',
      icon: Icons.assignment_return,
      children: [
        if (_invoice.returnedItems == null || _invoice.returnedItems!.isEmpty)
          Text(
            'لا توجد مواد مرتجعة',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ..._invoice.returnedItems!.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.assignment_return,
                            size: 14.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.itemName,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.deepBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildItemDetail(
                          'الكمية المشتراة',
                          _formattingService.formatInteger(
                            item.purchasedQuantity,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildItemDetail(
                          'الكمية المرتجعة',
                          _formattingService.formatInteger(
                            item.returnedQuantity,
                          ),
                          textColor: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildItemDetail(
                          'سعر الوحدة',
                          _formattingService.formatProductPrice(item.unitPrice),
                        ),
                      ),
                      Expanded(
                        child: _buildItemDetail(
                          'الإجمالي',
                          _formattingService.formatProductPrice(
                            item.totalPrice,
                          ),
                          textColor: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (item.originalInvoiceNumber != null)
                    _buildItemDetailWithIcon(
                      'رقم الفاتورة الأصلية',
                      item.originalInvoiceNumber!,
                      Icons.receipt_long,
                    ),
                  _buildItemDetailWithIcon(
                    'تاريخ البيع الأصلي',
                    _formattingService.formatDate(item.saleDate),
                    Icons.calendar_today,
                  ),
                ],
              ),
            );
          }),
        // عرض طريقة الاسترداد
        if (_invoice.refundMethod != null) ...[
          const Divider(height: 24),
          _buildRefundMethodRow(),
        ],
      ],
    );
  }

  /// ✅ بناء صف عرض طريقة الاسترداد
  Widget _buildRefundMethodRow() {
    final isCredit = _invoice.refundMethod == 'credit';
    return Row(
      children: [
        Icon(
          isCredit ? Icons.account_balance : Icons.money,
          size: 20.sp,
          color: isCredit ? Colors.blue : Colors.green,
        ),
        const SizedBox(width: 8),
        Text(
          'طريقة الاسترداد: ${isCredit ? 'خصم من الحساب' : 'نقداً'}',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: isCredit ? Colors.blue : Colors.green,
          ),
        ),
      ],
    );
  }

  /// بناء كارت تفاصيل الفاتورة النقدية
  Widget _buildCashInvoiceDetailsCard() {
    if (_invoice.effectiveCashTransactionType == 'sale') {
      return _buildRegularItemsCard();
    }
    if (!_invoice.isCashAccountReceipt) {
      return _buildRegularItemsCard();
    }
    final legacyReceiptItem = _invoice.items
        .cast<InvoiceItemEntity?>()
        .firstWhere(
          (item) =>
              item != null &&
              (item.unit == 'مبلغ نقدي' ||
                  item.productName.startsWith('مبلغ نقدي - ') ||
                  item.productName.startsWith('تصفير حساب وأرشفة - ')),
          orElse: () => null,
        );
    return InfoCard(
      title: 'تفاصيل المعاملة النقدية',
      icon: Icons.payments,
      children: [
        if (_invoice.items.isEmpty && _invoice.cashTransactionAmount > 0) ...[
          _buildCashDetailRow(
            'المبلغ',
            _formattingService.formatCurrency(_invoice.cashTransactionAmount),
            Icons.attach_money,
            Colors.green,
          ),
          _buildCashDetailRow(
            'نوع المعاملة',
            _getCashTransactionType(),
            _getCashTransactionIcon(),
            _getCashTransactionColor(),
          ),
          _buildCashDetailRow(
            'ملاحظة',
            _invoice.displayNotes?.trim().isNotEmpty == true
                ? _invoice.displayNotes!
                : 'لا توجد ملاحظات',
            Icons.note_alt_outlined,
            Colors.blue,
          ),
        ],
        if (_invoice.items.isEmpty && _invoice.cashTransactionAmount <= 0)
          Text(
            'لا توجد تفاصيل إضافية',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        if (_invoice.items.isNotEmpty)
          ..._invoice.items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.05),
                    Colors.green.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // عنوان المعاملة
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: AssyrianTheme.primaryGold,
                          size: 20.sp,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.productName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.deepBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // تفاصيل المعاملة النقدية
                  _buildCashDetailRow(
                    'نوع المعاملة',
                    _getCashTransactionType(),
                    _getCashTransactionIcon(),
                    _getCashTransactionColor(),
                  ),
                  _buildCashDetailRow(
                    'المبلغ',
                    _formattingService.formatCurrency(
                      _invoice.cashAmount > 0
                          ? _invoice.cashAmount
                          : (legacyReceiptItem?.totalPrice ?? item.totalPrice)
                                .abs(),
                    ),
                    Icons.attach_money,
                    Colors.green,
                  ),
                  _buildCashDetailRow(
                    'ملاحظة',
                    _invoice.displayNotes?.trim().isNotEmpty == true
                        ? _invoice.displayNotes!
                        : 'لا توجد ملاحظات',
                    Icons.note_alt_outlined,
                    Colors.blue,
                  ),

                  // معلومات إضافية للفواتير النقدية
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[600],
                          size: 16.sp,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذه معاملة نقدية تؤثر مباشرة على حساب العميل',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  /// بناء كارت العناصر للفواتير العادية
  Widget _buildRegularItemsCard() {
    return InfoCard(
      title: 'عناصر الفاتورة',
      icon: Icons.list_alt,
      children: [
        if (_invoice.items.isEmpty)
          Text(
            'لا توجد عناصر في الفاتورة',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ..._invoice.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final canNavigateToProduct = _canNavigateToProduct();

            return canNavigateToProduct
                ? InkWell(
                    onTap: () => _navigateToProductDetails(item.productName),
                    child: _buildItemContainer(item, index, showArrow: true),
                  )
                : _buildItemContainer(item, index, showArrow: false);
          }),
      ],
    );
  }

  /// التحقق من صلاحية الانتقال إلى تفاصيل المنتج
  bool _canNavigateToProduct() {
    return _hasInventoryPermission ?? false;
  }

  /// بناء حاوية عنصر الفاتورة
  Widget _buildItemContainer(
    InvoiceItemEntity item,
    int index, {
    required bool showArrow,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AssyrianTheme.primaryGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _formattingService.formatInteger(index + 1),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ),
              if (showArrow)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16.sp,
                  color: AssyrianTheme.primaryGold,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildItemDetail(
                  'الكمية',
                  '${_formattingService.formatNumber(item.quantity)} ${item.unit}',
                ),
              ),
              // عرض سعر الشراء والبيع لفواتير الشراء
              if (_invoice.type == 'purchase' &&
                  (item.purchasePrice != null ||
                      item.sellingPrice != null)) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.purchasePrice != null)
                        _buildItemDetail(
                          'سعر الشراء',
                          _formattingService.formatProductPrice(
                            item.purchasePrice!,
                          ),
                          textColor: Colors.red[700],
                        ),
                      if (item.sellingPrice != null)
                        _buildItemDetail(
                          'سعر البيع',
                          _formattingService.formatProductPrice(
                            item.sellingPrice!,
                          ),
                          textColor: Colors.green[700],
                        ),
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: _buildItemDetail(
                    'سعر الوحدة',
                    _formattingService.formatProductPrice(item.unitPrice),
                  ),
                ),
              ],
              Expanded(
                child: _buildItemDetail(
                  'المجموع',
                  _formattingService.formatCurrency(item.totalPrice),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// الانتقال إلى شاشة تفاصيل المنتج
  Future<void> _navigateToProductDetails(String productName) async {
    try {
      final productRepository = GetIt.instance<ProductRepository>();
      final productsResult = await productRepository.getProducts(
        organizationEmail: _invoice.organizationEmail,
      );

      if (!mounted) return;

      await productsResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل في جلب المنتجات: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (products) async {
          try {
            final product = products.firstWhere((p) => p.name == productName);

            if (!mounted) return;

            await Navigator.of(
              context,
            ).pushNamed(AppRoutes.productDetails, arguments: product);
          } on Exception catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('المنتج "$productName" غير موجود'),
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

  /// بناء صف تفاصيل المعاملة النقدية
  Widget _buildCashDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16.sp),
          const SizedBox(width: 8),
          SizedBox(
            width: 80.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// تحديد نوع المعاملة النقدية
  String _getCashTransactionType() {
    if (_invoice.isCashAccountReceipt) {
      switch (_invoice.effectiveCashTransactionType) {
        case 'receipt':
          return 'استلام مبلغ نقدي من العميل';
        case 'payment':
          return 'إعطاء مبلغ نقدي للعميل';
        case 'clearance':
          return 'تصفير حساب';
      }
      return 'معاملة نقدية';
    }
    return 'بيع نقدي';
  }

  /// تحديد أيقونة المعاملة النقدية
  IconData _getCashTransactionIcon() {
    if (_invoice.isCashAccountReceipt) {
      switch (_invoice.effectiveCashTransactionType) {
        case 'receipt':
          return Icons.trending_down;
        case 'payment':
          return Icons.trending_up;
        case 'clearance':
          return Icons.clear_all;
      }
      return Icons.swap_horiz;
    }
    return Icons.shopping_cart;
  }

  /// تحديد لون المعاملة النقدية
  Color _getCashTransactionColor() {
    if (_invoice.isCashAccountReceipt) {
      switch (_invoice.effectiveCashTransactionType) {
        case 'receipt':
          return Colors.green;
        case 'payment':
          return Colors.red;
        case 'clearance':
          return Colors.indigo;
      }
      return Colors.blue;
    }
    return Colors.blue;
  }

  Widget _buildItemDetail(String label, String value, {Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: textColor ?? AssyrianTheme.deepBlue,
          ),
        ),
      ],
    );
  }

  /// ✅ بناء تفصيل العنصر مع أيقونة
  Widget _buildItemDetailWithIcon(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: Colors.grey[600]),
        SizedBox(width: 4.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountsCard() {
    // للفواتير النقدية، نعرض معلومات مختلفة
    if (_invoice.type == 'cash') {
      return _buildCashAmountsCard();
    }

    // للفواتير العادية
    return _buildRegularAmountsCard();
  }

  /// بناء كارت المبالغ للفاتورة النقدية
  Widget _buildCashAmountsCard() {
    final isCashSale = _invoice.effectiveCashTransactionType == 'sale';
    return InfoCard(
      title: 'تفاصيل المبالغ',
      icon: Icons.account_balance_wallet,
      children: [
        // المبلغ الأساسي للمعاملة
        AmountRow(
          label: _invoice.isCashAccountReceipt
              ? 'مبلغ الإيصال'
              : 'إجمالي البيع النقدي',
          amount: _invoice.isCashAccountReceipt || isCashSale
              ? _invoice.cashTransactionAmount
              : (_invoice.totalAmount > 0
                    ? _invoice.totalAmount
                    : _invoice.items.fold<double>(
                        0,
                        (total, item) => total + item.totalPrice,
                      )),
          color: Colors.green,
        ),

        // تأثير المعاملة على الحساب
        if (_invoice.isCashAccountReceipt) _buildCashBalanceImpactRow(),

        // معلومات الحساب لإيصالات العميل أو مبيعات النقد المرتبطة بعميل.
        if (_invoice.isCashAccountReceipt ||
            (_invoice.customerId != null && !isCashSale))
          _buildCustomerBalanceRows(),

        const Divider(),
        DetailRow(
          label: 'نوع المعاملة',
          value: _invoice.isCashAccountReceipt
              ? _getCashTransactionType()
              : 'بيع نقدي',
        ),
        DetailRow(
          label: 'حالة المعاملة',
          value: _invoice.status == 'paid' ? 'مكتملة' : 'معلقة',
        ),
      ],
    );
  }

  /// بناء كارت المبالغ للفاتورة العادية
  Widget _buildRegularAmountsCard() {
    return InfoCard(
      title: 'المبالغ والحسابات',
      icon: Icons.calculate,
      children: [
        // عرض السعر الأصلي والضرائب والخصم إذا وجدت
        if (_invoice.discountAmount > 0 || _invoice.taxAmount > 0) ...[
          AmountRow(
            label: 'المجموع الأصلي',
            amount:
                _invoice.totalAmount +
                _invoice.discountAmount -
                _invoice.taxAmount,
            color: Colors.grey,
          ),
          // عرض تفاصيل الضرائب المتعددة
          if (_invoice.taxes != null && _invoice.taxes!.isNotEmpty) ...[
            // عرض كل ضريبة بشكل منفصل
            ..._invoice.taxes!.map((tax) {
              final taxName = tax['name'] as String;
              final taxRate = tax['rate'] as double;
              final taxAmountValue = tax['amount'] as double;
              final isPercentage = tax['isPercentage'] as bool;

              return AmountRow(
                label: '• $taxName',
                amount: taxAmountValue,
                color: Colors.orange,
                prefix: isPercentage && taxRate > 0
                    ? '(${taxRate.toStringAsFixed(1)}%) '
                    : '',
              );
            }),
            // عرض إجمالي الضرائب
            AmountRow(
              label: 'إجمالي الضرائب',
              amount: _invoice.taxAmount,
              color: Colors.orange,
              isBold: true,
            ),
          ] else if (_invoice.taxAmount > 0) ...[
            // ضريبة واحدة فقط (للخلف compatibility)
            AmountRow(
              label: 'الضريبة',
              amount: _invoice.taxAmount,
              color: Colors.orange,
            ),
          ],
          // عرض الخصم
          AmountRow(
            label: 'الخصم',
            amount: -_invoice.discountAmount,
            color: Colors.red,
          ),
          AmountRow(
            label: 'المجموع النهائي',
            amount: _invoice.totalAmount,
            color: AssyrianTheme.deepBlue,
            isBold: true,
          ),
        ] else
          AmountRow(
            label: 'المجموع الكلي',
            amount: _invoice.totalAmount,
            color: AssyrianTheme.deepBlue,
          ),
        AmountRow(
          label: 'المبلغ المدفوع',
          amount: _invoice.paidAmount.abs(),
          color: _invoice.paidAmount >= 0 ? Colors.green : Colors.red,
        ),
        // إضافة سطر توضيحي للحساب
        if (_invoice.type != 'cash' && _invoice.paidAmount != 0)
          _buildCalculationRow(),
        AmountRow(
          label: 'المبلغ المتبقي',
          amount: _invoice.calculateRemainingAmount(),
          color: _invoice.calculateRemainingAmount() <= 0 ? Colors.green : Colors.orange,
        ),
        _buildCustomerBalanceRows(),
        const Divider(),
        DetailRow(
          label: 'عدد العناصر',
          value:
              '${_formattingService.formatInteger(_invoice.items.length)} عنصر',
        ),
      ],
    );
  }

  /// بناء صف تأثير المعاملة النقدية على الحساب
  Widget _buildCashBalanceImpactRow() {
    final amount = _invoice.cashTransactionAmount;
    final transactionType = _invoice.effectiveCashTransactionType;

    String impactText;
    Color impactColor;
    IconData impactIcon;

    if (transactionType == 'payment') {
      impactText =
          'إعطاء مبلغ نقدي للعميل بمبلغ ${_formattingService.formatCurrency(amount)}';
      impactColor = Colors.red;
      impactIcon = Icons.add_circle_outline;
    } else if (transactionType == 'clearance') {
      impactText = 'تصفير الحساب بالكامل';
      impactColor = Colors.indigo;
      impactIcon = Icons.clear_all;
    } else {
      impactText =
          'استلام مبلغ نقدي من العميل بمبلغ ${_formattingService.formatCurrency(amount)}';
      impactColor = Colors.green;
      impactIcon = Icons.remove_circle_outline;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              'تأثير على الحساب',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: impactColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: impactColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(impactIcon, color: impactColor, size: 16.sp),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      impactText,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: impactColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerBalanceRows() {
    // استخدام القيم المحفوظة في الفاتورة مباشرة
    final balanceBeforeInvoice = _invoice.balanceBeforeInvoice ?? 0.0;
    final balanceAfterInvoice = _invoice.balanceAfterInvoice ?? 0.0;

    return Column(
      children: [
        _buildBalanceRow(
          balanceBeforeInvoice > 0
              ? 'الحساب قبل الفاتورة (عليك)'
              : balanceBeforeInvoice < 0
              ? 'الحساب قبل الفاتورة (لك)'
              : 'الحساب قبل الفاتورة',
          balanceBeforeInvoice.abs(),
        ),
        _buildBalanceRow(
          balanceAfterInvoice > 0
              ? 'الحساب بعد الفاتورة (عليك)'
              : balanceAfterInvoice < 0
              ? 'الحساب بعد الفاتورة (لك)'
              : 'الحساب بعد الفاتورة',
          balanceAfterInvoice.abs(),
        ),
      ],
    );
  }

  /// بناء سطر توضيحي للعملية الحسابية
  Widget _buildCalculationRow() {
    final totalAmount = _invoice.totalAmount;
    final paidAmount = _invoice.paidAmount.abs();
    final remaining = totalAmount - paidAmount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              'الحساب',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Text(
                '${_formattingService.formatCurrency(totalAmount)} - ${_formattingService.formatCurrency(paidAmount)} = ${_formattingService.formatCurrency(remaining)}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String label, double balance) {
    final balanceColor = balance == 0
        ? Colors.grey
        : balance > 0
        ? Colors.red
        : Colors.green;

    final balanceText = balance == 0
        ? 'لا يوجد حساب'
        : balance > 0
        ? 'عليه: ${_formattingService.formatCurrency(balance)}'
        : 'له: ${_formattingService.formatCurrency(balance.abs())}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: balanceColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: balanceColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                balanceText,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: balanceColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return InfoCard(
      title: 'معلومات النظام',
      icon: Icons.system_update,
      children: [
        DetailRow(
          label: 'تاريخ الإنشاء',
          value: _formattingService.formatDateTime(_invoice.createdAt),
        ),
        DetailRow(label: 'أنشئت بواسطة', value: _createdByName ?? 'غير محدد'),
        DetailRow(
          label: 'آخر تحديث',
          value: _formattingService.formatDateTime(_invoice.updatedAt),
        ),
        if (_invoice.updatedBy != null)
          DetailRow(
            label: 'آخر تحديث بواسطة',
            value: _updatedByName ?? _invoice.updatedBy!,
          ),
        StatusRow(
          label: 'حالة الفاتورة',
          value: _getStatusText(_invoice.status),
          color: _getStatusColor(_invoice.status),
        ),
        if (_invoice.remainingAmount > 0 && _invoice.isUnpaid)
          const StatusRow(
            label: 'تنبيه',
            value: 'فاتورة متأخرة السداد',
            color: Colors.red,
          ),
      ],
    );
  }

  Widget _buildActionsCard() {
    return ActionButtons(
      children: [
        Row(
          children: [
            if (_canEdit) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.editInvoice, arguments: _invoice);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('تعديل الفاتورة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AssyrianTheme.primaryGold,
                    foregroundColor: AssyrianTheme.deepBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _printInvoice(context),
                icon: const Icon(Icons.print),
                label: const Text('طباعة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AssyrianTheme.primaryGold,
                  side: const BorderSide(color: AssyrianTheme.primaryGold),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareInvoice(context),
                icon: const Icon(Icons.share),
                label: const Text('مشاركة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _generatePdf(context),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('تصدير PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
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

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'partial':
        return 'مدفوعة جزئياً';
      case 'unpaid':
        return 'غير مدفوعة';
      case 'cancelled':
        return 'ملغية';
      default:
        return 'غير محدد';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// عرض خيارات PDF
  void _showPdfOptions(BuildContext context, File pdfFile) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تم إنشاء الفاتورة بنجاح',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AssyrianTheme.deepBlue, // ✅ لون العنوان أزرق عميق
              ),
            ),
            SizedBox(height: 20.h),
            ListTile(
              leading: const Icon(Icons.share, color: AssyrianTheme.deepBlue),
              title: Text(
                'مشاركة',
                style: TextStyle(
                  color: AssyrianTheme.deepBlue, // ✅ لون النص أزرق عميق
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final pdfSharingService = PdfSharingService();
                await pdfSharingService.sharePdf(
                  pdfFile: pdfFile,
                  subject: 'فاتورة',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.print, color: AssyrianTheme.deepBlue),
              title: Text(
                'طباعة',
                style: TextStyle(
                  color: AssyrianTheme.deepBlue, // ✅ لون النص أزرق عميق
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final pdfSharingService = PdfSharingService();
                await pdfSharingService.printPdf(
                  pdfFile: pdfFile,
                  subject: 'طباعة',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// توليد PDF للفاتورة
  Future<void> _generatePdf(BuildContext context) async {
    // الحصول على القالب المحدد من الذاكرة المحلية
    String? templateId;
    try {
      templateId = _prefs?.getString('selected_template_id');
    } on Exception catch (_) {
      // تجاهل الأخطاء
    }

    if (!context.mounted) return;

    context.read<InvoiceBloc>().add(
      GenerateInvoicePdfEvent(
        invoice: _invoice,
        organizationEmail: _invoice.organizationEmail,
        templateId: templateId,
      ),
    );
  }

  /// طباعة الفاتورة مباشرة
  Future<void> _printInvoice(BuildContext context) async {
    // حفظ navigator و messenger قبل العمليات async
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<InvoiceBloc>();
    final repository = bloc.repository;

    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoadingWidget(message: 'جاري التحميل...'),
    );

    try {
      // الحصول على القالب المحدد
      String? templateId;
      try {
        templateId = _prefs?.getString('selected_template_id');
      } on Exception catch (_) {}

      if (!mounted) return;

      InvoiceTemplateEntity? template;
      if (templateId != null && templateId.isNotEmpty) {
        final result = await repository.getTemplateById(
          _invoice.organizationEmail,
          templateId,
        );
        template = result.fold((l) => null, (r) => r);
      }

      if (template == null) {
        final result = await repository.getTemplateByType(
          _invoice.organizationEmail,
          _invoice.type,
        );
        template = result.fold((l) => null, (r) => r);
      }

      if (template != null) {
        Uint8List? logoBytes;
        if (template.showLogo) {
          try {
            final data = await rootBundle.load('assets/images/lamassu2.png');
            logoBytes = data.buffer.asUint8List();
          } on Exception catch (_) {}
        }

        // جلب اسم المؤسسة من الإعدادات
        String organizationName = 'المؤسسة';
        String organizationPhone = '';
        String organizationAddress = '';
        try {
          final pdfSettingsService = PdfSettingsService();
          final settings = await pdfSettingsService.getSettings(
            _invoice.organizationEmail,
          );
          organizationName = settings.organizationName;
          organizationPhone = settings.organizationPhone;
          organizationAddress = settings.organizationAddress;
        } on Exception catch (_) {
          // فشل في جلب الإعدادات
        }

        final pdfService = PdfService();
        final pdfFile = await pdfService.generateInvoicePdf(
          invoice: _invoice,
          template: template,
          organizationName: organizationName,
          organizationPhone: organizationPhone,
          organizationAddress: organizationAddress,
          logoBytes: logoBytes,
        );

        if (!mounted) return;
        navigator.pop();
        final pdfSharingService = PdfSharingService();
        await pdfSharingService.printPdf(pdfFile: pdfFile, subject: 'طباعة');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('فشل في طباعة الفاتورة: $e')),
      );
    }
  }

  /// مشاركة الفاتورة مباشرة
  Future<void> _shareInvoice(BuildContext context) async {
    // حفظ navigator و messenger قبل العمليات async
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<InvoiceBloc>();
    final repository = bloc.repository;

    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoadingWidget(message: 'جاري التحميل...'),
    );

    try {
      // الحصول على القالب المحدد
      String? templateId;
      try {
        templateId = _prefs?.getString('selected_template_id');
      } on Exception catch (_) {}

      if (!mounted) return;

      InvoiceTemplateEntity? template;
      if (templateId != null && templateId.isNotEmpty) {
        final result = await repository.getTemplateById(
          _invoice.organizationEmail,
          templateId,
        );
        template = result.fold((l) => null, (r) => r);
      }

      if (template == null) {
        final result = await repository.getTemplateByType(
          _invoice.organizationEmail,
          _invoice.type,
        );
        template = result.fold((l) => null, (r) => r);
      }

      if (template != null) {
        Uint8List? logoBytes;
        if (template.showLogo) {
          try {
            final data = await rootBundle.load('assets/images/lamassu2.png');
            logoBytes = data.buffer.asUint8List();
          } on Exception catch (_) {}
        }

        final pdfService = PdfService();
        final orgInfo = await SettingsService.getOrganizationInfo();
        final pdfFile = await pdfService.generateInvoicePdf(
          invoice: _invoice,
          template: template,
          organizationName: orgInfo['name'] ?? 'اسم شركتك',
          organizationPhone: orgInfo['phone'] ?? '',
          organizationAddress: orgInfo['address'] ?? 'العنوان',
          logoBytes: logoBytes,
        );

        if (!mounted) return;
        navigator.pop();
        final pdfSharingService = PdfSharingService();
        await pdfSharingService.sharePdf(pdfFile: pdfFile, subject: 'فاتورة');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('فشل في مشاركة الفاتورة: $e')),
      );
    }
  }

  @override
  void dispose() {
    // إيقاف الاستماع للتحديثات عند إغلاق الصفحة
    _invoiceBloc?.add(const StopInvoicesStreamEvent());
    super.dispose();
  }
}
