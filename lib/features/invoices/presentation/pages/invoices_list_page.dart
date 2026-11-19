import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/returned_item_entity.dart';
import '../bloc/invoice_bloc.dart';
import '../widgets/delete_invoice_dialog.dart';
import '../widgets/invoice_drawer.dart';

/// صفحة عرض جميع الفواتير
class InvoicesListPage extends StatefulWidget {
  const InvoicesListPage({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  State<InvoicesListPage> createState() => _InvoicesListPageState();
}

class _InvoicesListPageState extends State<InvoicesListPage> {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final TextEditingController _searchController = TextEditingController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  Map<String, bool> _userPermissions = {};
  String _selectedFilter = 'all';
  bool _waitingForInitialFilterData = false;
  bool _isFilterExpanded = false;
  String? _customerId; // معرف العميل للفلترة
  String? _customerName; // اسم العميل للعرض في العنوان فقط
  String? _customerPhone; // هاتف العميل لتعيينه تلقائياً عند إنشاء فاتورة
  String? _cachedCustomerId; // تخزين customerId في الذاكرة لتحسين الأداء
  SharedPreferences? _prefs; // تخزين SharedPreferences مؤقتاً
  String? _templateId; // معرف القالب المحدد لتصدير PDF
  final ScrollController _scrollController = ScrollController();
  bool _canCreate = false;
  bool _canViewArchive = false;
  bool _canExportHistory = false;
  bool _isExporting = false;
  bool _initialized = false; // لمنع التحميل المتكرر
  List<InvoiceEntity> _cachedInvoices =
      []; // حفظ الفواتير مؤقتًا لمنع اختفائها عند التصدير
  late InvoiceBloc _bloc; // حفظ reference للـ bloc

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
      _waitingForInitialFilterData = true;
    }
    // حفظ reference للـ bloc
    _bloc = context.read<InvoiceBloc>();
    _scrollController.addListener(_onScroll);
    _loadPermissions();
    _loadPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // تنفيذ مرة واحدة فقط لتجنب التحميل المتكرر
    if (_initialized) return;

    // قراءة customerId من arguments
    final routeArguments = ModalRoute.of(context)?.settings.arguments;
    final args = routeArguments is Map<String, dynamic> ? routeArguments : null;
    if (routeArguments is String) {
      _selectedFilter = routeArguments;
      _waitingForInitialFilterData = true;
    }
    _customerId = args?['customerId'] as String?;
    _customerName = args?['customerName'] as String?;
    _customerPhone = args?['customerPhone'] as String?;

    // تخزين في الذاكرة للوصول السريع
    _cachedCustomerId = _customerId;

    // تحميل البيانات مع customerId (أو بدونه لعرض كل الفواتير)
    _loadInvoicesPaginated(isRefresh: true);

    // بدء الاستماع للتحديثات الفورية للفواتير
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _bloc.add(StartInvoicesStreamEvent(user.email!));
    }

    _initialized = true;
  }

  Future<void> _loadPermissions() async {
    final permissions = await _permissionChecker.getUserPermissions();
    final permissionsMap = <String, bool>{};

    for (final permission in permissions) {
      permissionsMap[permission] = true;
    }

    final canCreate =
        permissionsMap['invoices_sales_manage'] == true ||
        permissionsMap['invoices_purchase_manage'] == true ||
        permissionsMap['invoices_cash_manage'] == true ||
        permissionsMap['invoices_subscription_manage'] == true ||
        permissionsMap['invoices_sales_return_manage'] == true;
    final canViewArchive = permissionsMap['invoices_archive_view'] == true;
    final canExportHistory = permissionsMap['invoices_reports_view'] == true;

    if (mounted) {
      setState(() {
        _userPermissions = permissionsMap;
        _canCreate = canCreate;
        _canViewArchive = canViewArchive;
        _canExportHistory = canExportHistory;
      });
    }
  }

  /// تحميل تفضيلات المستخدم بما في ذلك القالب المحدد
  Future<void> _loadPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _templateId = _prefs?.getString('selected_template_id');
    } on Exception {
      // تجاهل الأخطاء
    }
  }

  /// التحقق من صلاحية تعديل فاتورة بناءً على نوعها
  bool _canEditInvoice(InvoiceEntity invoice) {
    switch (invoice.type) {
      case 'sales':
        return _userPermissions['invoices_sales_manage'] ?? false;
      case 'purchase':
        return _userPermissions['invoices_purchase_manage'] ?? false;
      case 'cash':
        return _userPermissions['invoices_cash_manage'] ?? false;
      case 'subscription':
        return _userPermissions['invoices_subscription_manage'] ?? false;
      case 'sales_return':
        return _userPermissions['invoices_sales_return_manage'] ?? false;
      default:
        // لا يوجد fallback لـ invoices_edit لأنها حذفت
        return false;
    }
  }

  /// ✅ تم الإصلاح: هذه الدالة الآن تتحقق من صلاحية "إدارة" كل نوع من الفواتير.
  /// إذا كان المقصود فصل العرض عن الإدارة، يجب إضافة صلاحيات منفصلة للعرض (view)
  /// لكل نوع (مثل invoices_sales_view، invoices_purchase_view، إلخ) واستخدامها هنا
  /// بدلاً من صلاحيات الإدارة.
  bool _canViewInvoice(InvoiceEntity invoice) {
    // التحقق من الصلاحية المحددة للنوع
    switch (invoice.type) {
      case 'sales':
        return _userPermissions['invoices_sales_manage'] == true;
      case 'purchase':
        return _userPermissions['invoices_purchase_manage'] == true;
      case 'cash':
        return _userPermissions['invoices_cash_manage'] == true;
      case 'subscription':
        return _userPermissions['invoices_subscription_manage'] == true;
      case 'sales_return':
        return _userPermissions['invoices_sales_return_manage'] == true;
      default:
        return false;
    }
  }

  /// التحقق من صلاحية حذف فاتورة بناءً على نوعها
  bool _canDeleteInvoice(InvoiceEntity invoice) {
    switch (invoice.type) {
      case 'sales':
        return _userPermissions['invoices_sales_manage'] ?? false;
      case 'purchase':
        return _userPermissions['invoices_purchase_manage'] ?? false;
      case 'cash':
        return _userPermissions['invoices_cash_manage'] ?? false;
      case 'subscription':
        return _userPermissions['invoices_subscription_manage'] ?? false;
      case 'sales_return':
        return _userPermissions['invoices_sales_return_manage'] ?? false;
      default:
        // لا يوجد fallback لـ invoices_delete لأنها حذفت
        return false;
    }
  }

  /// استيراد مواد من فاتورة وإنشاء فاتورة مرجع بيع
  Future<void> _importItemsFromInvoice(InvoiceEntity invoice) async {
    // ✅ حفظ الـ Bloc في متغير محلي في بداية الدالة قبل أي await
    final customerBloc = context.read<CustomerBloc>();

    if (invoice.customerId == null || invoice.customerId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن إرجاع مواد من فاتورة عميل نقدي'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // ✅ جلب جميع فواتير مرجع البيع السابقة لهذا العميل
    Map<String, int> previouslyReturnedQuantities = {};
    try {
      final allInvoicesResult = await _bloc.repository.getInvoices(
        invoice.organizationEmail,
      );
      await allInvoicesResult.fold((failure) {}, (allInvoices) async {
        // فلترة فواتير مرجع البيع لهذا العميل
        final salesReturnInvoices = allInvoices
            .where(
              (inv) =>
                  inv.isSalesReturn &&
                  inv.customerId == invoice.customerId &&
                  inv.originalInvoiceId == invoice.id &&
                  !inv.isArchived,
            )
            .toList();

        // حساب الكمية المرتجعة مسبقاً لكل مادة
        for (final returnInvoice in salesReturnInvoices) {
          if (returnInvoice.returnedItems != null) {
            for (final returnedItem in returnInvoice.returnedItems!) {
              final key =
                  '${returnedItem.itemId}_${returnedItem.originalInvoiceId}';
              final prevValue = previouslyReturnedQuantities[key] ?? 0;
              previouslyReturnedQuantities[key] =
                  prevValue + returnedItem.returnedQuantity;
            }
          }
        }
      });
    } on Exception catch (_) {
      // تجاهل الأخطاء والاستمرار
    }

    // ✅ إنشاء قائمة المواد القابلة للإرجاع (بعد طرح المرتجع مسبقاً)
    final returnedItems = <ReturnedItemEntity>[];
    for (final item in invoice.items) {
      if (item.quantity <= 0) continue;

      final key = '${item.itemId ?? item.productName}_${invoice.id}';
      final previouslyReturned = previouslyReturnedQuantities[key] ?? 0;
      final remainingQuantity = item.quantity.toInt() - previouslyReturned;

      // ✅ إضافة المادة فقط إذا كانت هناك كمية متبقية للإرجاع
      if (remainingQuantity > 0) {
        returnedItems.add(
          ReturnedItemEntity(
            itemId: item.itemId ?? item.productName,
            itemName: item.productName,
            purchasedQuantity: item.quantity.toInt(),
            returnedQuantity: remainingQuantity, // ✅ الكمية المتبقية فقط
            unitPrice: item.unitPrice,
            saleDate: invoice.invoiceDate,
            originalInvoiceId: invoice.id,
            originalInvoiceNumber: invoice.invoiceNumber,
          ),
        );
      }
    }

    if (returnedItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              previouslyReturnedQuantities.isNotEmpty
                  ? 'تم إرجاع جميع المواد من هذه الفاتورة مسبقاً'
                  : 'لا توجد مواد قابلة للإرجاع في هذه الفاتورة',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    CustomerEntity? customer;

    // الحصول على حالة العميل الحالية
    final customerState = customerBloc.state;
    if (customerState is CustomerLoaded) {
      try {
        customer = customerState.customers.firstWhere(
          (c) => c.id == invoice.customerId,
        );
      } on StateError {
        // العميل غير موجود
      }
    }

    if (customer == null) {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email;
      if (userEmail != null) {
        customerBloc.add(LoadCustomersEvent(userEmail, forceRefresh: false));
        await Future.delayed(const Duration(milliseconds: 500));

        // ✅ التحقق من mounted قبل استخدام context
        if (!mounted) return;

        final updatedState = customerBloc.state;
        if (updatedState is CustomerLoaded) {
          try {
            customer = updatedState.customers.firstWhere(
              (c) => c.id == invoice.customerId,
            );
          } on StateError {
            // العميل غير موجود
          }
        }
      }
    }

    if (!mounted) return;

    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('العميل غير موجود'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // عرض نافذة اختيار المواد
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.refresh, color: Colors.orange, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'استيراد مواد من فاتورة',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // معلومات الفاتورة
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 16.sp,
                              color: Colors.blue[700],
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'الفاتورة: ${invoice.invoiceNumber}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'العميل: ${invoice.customerName}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'التاريخ: ${_formattingService.formatInvoiceDate(invoice.invoiceDate)}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'اختر المواد المراد إرجاعها:',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // قائمة المواد
                  ...returnedItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isPartiallyReturned =
                        item.returnedQuantity < item.purchasedQuantity;
                    return CheckboxListTile(
                      title: Text(
                        item.itemName,
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'الكمية المشتراة: ${item.purchasedQuantity}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isPartiallyReturned) ...[
                                Icon(
                                  Icons.info_outline,
                                  size: 14.sp,
                                  color: Colors.orange[700],
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '(يمكن إرجاع ${item.returnedQuantity} فقط)',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'السعر: ${item.unitPrice.toStringAsFixed(2)} د.ع',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      value: true,
                      // ✅ تم الإصلاح: يمكن الآن إلغاء تحديد المواد بدلاً من أن تكون محددة افتراضياً وغير قابلة للتغيير
                      onChanged: (selected) {
                        setDialogState(() {
                          // يمكن تتبع المواد المختارة هنا إذا لزم الأمر لاحقًا
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
              child: Text('إلغاء', style: TextStyle(fontSize: 14.sp)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop({'items': returnedItems, 'customer': customer});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'إنشاء فاتورة مرجع بيع',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final items = result['items'] as List<ReturnedItemEntity>;
      final customerEntity = result['customer'] as CustomerEntity;

      await _createSalesReturnInvoice(customerEntity, items);
    }
  }

  Future<void> _createSalesReturnInvoice(
    CustomerEntity customer,
    List<ReturnedItemEntity> items,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    final totalAmount = items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );

    final refundMethod = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.payment, color: Colors.orange, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'طريقة الاسترداد',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'credit',
                // ignore: deprecated_member_use
                groupValue: 'credit',
                // ignore: deprecated_member_use
                onChanged: (value) {
                  Navigator.of(dialogContext).pop(value);
                },
              ),
              title: Text(
                'خصم من حساب العميل',
                style: TextStyle(fontSize: 14.sp),
              ),
              subtitle: Text(
                customer.totalDebt > 0
                    ? 'الحساب الحالي (عليك): ${customer.totalDebt.toStringAsFixed(2)} دينار'
                    : customer.totalDebt < 0
                    ? 'الحساب الحالي (لك): ${customer.totalDebt.abs().toStringAsFixed(2)} دينار'
                    : 'الحساب الحالي: ${customer.totalDebt.toStringAsFixed(2)} دينار',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
              ),
            ),
            ListTile(
              leading: Radio<String>(
                value: 'cash',
                // ignore: deprecated_member_use
                groupValue: 'cash',
                // ignore: deprecated_member_use
                onChanged: (value) {
                  Navigator.of(dialogContext).pop(value);
                },
              ),
              title: Text('رد نقداً', style: TextStyle(fontSize: 14.sp)),
              subtitle: Text(
                'سيتم رد المبلغ نقداً للعميل',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );

    if (refundMethod == null) return;

    final invoiceItems = items
        .map(
          (item) => InvoiceItemEntity(
            productName: item.itemName,
            quantity: -item.returnedQuantity.toDouble(),
            unit: '',
            unitPrice: item.unitPrice,
            totalPrice: -item.totalPrice,
            itemId: item.itemId,
            originalInvoiceId: item.originalInvoiceId,
            originalInvoiceNumber: item.originalInvoiceNumber,
            originalSaleDate: item.saleDate,
            isReturned: true,
            returnedQuantity: item.returnedQuantity,
          ),
        )
        .toList();

    final invoice = InvoiceEntity(
      id: '',
      invoiceNumber: 'RET-${DateTime.now().millisecondsSinceEpoch}',
      customerName: customer.name,
      customerPhone: customer.phone,
      customerId: customer.id,
      invoiceDate: DateTime.now(),
      totalAmount: totalAmount,
      paidAmount: totalAmount,
      remainingAmount: 0,
      status: 'paid',
      type: 'sales_return',
      isSalesReturn: true,
      originalInvoiceId: items.first.originalInvoiceId,
      refundMethod: refundMethod,
      returnedItems: items,
      items: invoiceItems,
      organizationEmail: user!.email!,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: user.email ?? 'المدير',
      balanceBeforeInvoice: customer.totalDebt,
      // ✅ تحديث الحساب فقط إذا كانت الطريقة خصم من الحساب
      balanceAfterInvoice: refundMethod == 'credit'
          ? customer.totalDebt - totalAmount
          : customer.totalDebt, // نقداً: لا يتغير الحساب
    );

    final invoiceBloc = GetIt.instance.get<InvoiceBloc>();
    invoiceBloc.add(AddInvoiceEvent(invoice, skipCreditCheck: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء فاتورة مرجع البيع بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      invoiceBloc.add(
        LoadInvoicesPaginatedEvent(
          organizationEmail: user.email!,
          isRefresh: true,
        ),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    final hasMore = state is InvoiceLoaded
        ? state.hasMore
        : state is InvoiceStreamActive
        ? state.hasMore
        : false;
    final isLoadingMore = state is InvoiceLoaded
        ? state.isLoadingMore
        : state is InvoiceStreamActive
        ? state.isLoadingMore
        : false;
    if (!hasMore || isLoadingMore) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _bloc.add(LoadMoreInvoicesEvent(user.email!, customerId: _customerId));
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  void _tryLoadMoreIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isBottom) _onScroll();
    });
  }

  void _loadInvoicesPaginated({bool isRefresh = false}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      if (_customerId == null || _customerId!.isEmpty) {
        context.read<InvoiceBloc>().add(
          LoadInvoicesPaginatedEvent(
            organizationEmail: user.email!,
            isRefresh: isRefresh,
            searchQuery: _searchController.text.isNotEmpty
                ? _searchController.text
                : null,
          ),
        );
      } else {
        context.read<InvoiceBloc>().add(
          LoadInvoicesPaginatedEvent(
            organizationEmail: user.email!,
            isRefresh: isRefresh,
            customerId: _customerId,
            searchQuery: _searchController.text.isNotEmpty
                ? _searchController.text
                : null,
          ),
        );
      }
    }
  }

  void forceRefresh() {
    _customerId = _cachedCustomerId;
    _loadInvoicesPaginated(isRefresh: true);
  }

  /// تصدير سجل الفواتير إلى ملف PDF واحد
  void _exportInvoicesHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    setState(() {
      _isExporting = true;
    });

    context.read<InvoiceBloc>().add(
      ExportInvoicesHistoryEvent(
        organizationEmail: user.email!,
        customerId: _customerId,
        customerName: _customerName,
        templateId: _templateId,
      ),
    );
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    forceRefresh();
  }

  void _loadInvoices() {
    forceRefresh();
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopInvoicesStreamEvent());
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<InvoiceEntity> _filterInvoices(List<InvoiceEntity> invoices) {
    // ✅ ملاحظة للمبرمجين المستقبليين:
    // تم دمج الفلاتر في سلسلة واحدة لتقليل عدد عمليات toList().
    // السبب: كل toList() ينشئ قائمة جديدة في الذاكرة.
    // الحل: استخدام where() بدون toList() ثم تحويل النتيجة إلى List مرة واحدة.
    return invoices.where((invoice) {
      // فلترة الفواتير حسب الصلاحيات - عرض فقط الفواتير المسموحة
      if (!_canViewInvoice(invoice)) return false;

      // إخفاء الفواتير المؤرشفة فقط (عند الضغط على أرشفة)
      if (invoice.isArchived == true) return false;

      // تطبيق البحث
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        if (!invoice.invoiceNumber.toLowerCase().contains(query) &&
            !invoice.customerName.toLowerCase().contains(query) &&
            !invoice.customerPhone.toLowerCase().contains(query)) {
          return false;
        }
      }

      // تطبيق الفلتر
      if (_selectedFilter != 'all') {
        // التمييز بين فلاتر الحالة وفلاتر النوع لتجنب الانهيار عند إضافة حالة تساوي اسم نوع.
        final statusFilters = {
          'paid',
          'unpaid',
          'partial',
          'cancelled',
          'overdue',
        };
        final typeFilters = {
          'sales',
          'purchase',
          'cash',
          'subscription',
          'sales_return',
        };

        if (statusFilters.contains(_selectedFilter)) {
          // فلتر حسب حالة الدفع
          switch (_selectedFilter) {
            case 'paid':
              if (!invoice.isPaid) return false;
              break;
            case 'unpaid':
              if (!(invoice.isUnpaid || invoice.isPartiallyPaid)) return false;
              break;
            case 'partial':
              if (!invoice.isPartiallyPaid) return false;
              break;
            case 'cancelled':
              if (!invoice.isCancelled) return false;
              break;
            case 'overdue':
              if (!(invoice.remainingAmount > 0 &&
                  (invoice.isUnpaid || invoice.isPartiallyPaid))) {
                return false;
              }
              break;
            default:
              break;
          }
        } else if (typeFilters.contains(_selectedFilter)) {
          // فلتر حسب نوع الفاتورة
          if (invoice.type != _selectedFilter) return false;
        } else {
          // فلتر غير معروف — لا يُفلتر شيئًا
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const InvoiceDrawer(currentRoute: 'invoices'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'invoices_list_create_fab',
              onPressed: () async {
                final Map<String, dynamic>? args =
                    _customerName != null && _customerId != null
                    ? {
                        'customerId': _customerId,
                        'customerName': _customerName,
                        'customerPhone': _customerPhone,
                      }
                    : null;
                final result = await Navigator.pushNamed(
                  context,
                  AppRoutes.createInvoice,
                  arguments: args,
                );
                if (result == true || result is InvoiceEntity) {
                  forceRefresh();
                }
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<InvoiceBloc, InvoiceState>(
        listener: (context, state) {
          if (_waitingForInitialFilterData &&
              (state is InvoiceLoaded || state is InvoiceStreamActive)) {
            _waitingForInitialFilterData = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _bloc.add(FilterInvoicesEvent(_selectedFilter));
              }
            });
          }
          if (state is InvoiceLoaded) {
            _cachedInvoices = state.invoices.cast<InvoiceEntity>();
            if (state.hasMore && !state.isLoadingMore) {
              _tryLoadMoreIfNeeded();
            }
          }
          if (state is InvoiceStreamActive) {
            _cachedInvoices = state.invoices.cast<InvoiceEntity>();
          }
          if (state is InvoiceError) {
            setState(() {
              _isExporting = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            // إعادة المحاولة بعد خطأ
            refreshWithDelay();
          }
          if (state is InvoiceHistoryExported) {
            setState(() {
              _isExporting = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('تم تصدير سجل الفواتير بنجاح'),
                  backgroundColor: Colors.green,
                  action: SnackBarAction(
                    label: 'مشاركة',
                    onPressed: () async {
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(state.pdfFile.path)],
                          subject:
                              'سجل الفواتير - ${DateTime.now().millisecondsSinceEpoch}.pdf',
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          }
        },
        builder: (context, state) {
          var allInvoices = _cachedInvoices;

          if (state is InvoiceLoaded) {
            allInvoices = state.invoices.cast<InvoiceEntity>();
          } else if (state is InvoiceStreamActive) {
            // ✅ إصلاح (2026-10-12): عند عرض فواتير عميل محدد
            // (_customerId من arguments) نأخذ state.invoices
            // مباشرة ثم نفلتر بالعميل بالأسفل. السبب: ستريم
            // الفواتير (StartInvoicesStreamEvent) لا يحمل
            // customerId و getInvoicesStream لا تقبله، فتصلك
            // InvoiceStreamActive بكل الفواتير و filteredInvoices
            // فيها أول 10 فواتير من الكل — لو فضلناها ولم تكن
            // فواتير العميل بينها يظهر الفراغ (البلاغ: تظهر
            // أحيانا كل الفواتير ثم اصبحت احيانا فارغة).
            // state.invoices إما فواتير العميل المحمّلة أو كل
            // الفواتير والفلتر يضيّقها للعميل. الفلتر على مستوى
            // الصفحة آمن لأنه لا يمس الستريم المشترك ولا
            // الداشبورد (بلا customerId) ويعمل مع الحالتين
            // InvoiceLoaded و InvoiceStreamActive.
            // ⚠️ لا تُرجع هذا الشرط ولا الفلتر — إزالتهما تعيدان البلاغين.
            allInvoices = (_customerId != null && _customerId!.isNotEmpty)
                ? state.invoices.cast<InvoiceEntity>()
                : (state.filteredInvoices.isNotEmpty
                      ? state.filteredInvoices.cast<InvoiceEntity>()
                      : state.invoices.cast<InvoiceEntity>());
          }

          if (_customerId != null && _customerId!.isNotEmpty) {
            allInvoices = allInvoices
                .where((invoice) => invoice.customerId == _customerId)
                .toList();
          }

          final filteredInvoices = _filterInvoices(allInvoices);

          // عرض التحميل فقط إذا لم يتم تحميل أي فواتير بعد
          if (state is InvoiceInitial ||
              (state is InvoiceLoading && allInvoices.isEmpty)) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل الفواتير...'),
                ),
              ],
            );
          }

          if (state is InvoiceError && allInvoices.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (filteredInvoices.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _customerName != null
                        ? 'لا توجد فواتير لهذا العميل'
                        : 'لا توجد فواتير',
                    message: _customerName != null
                        ? 'لم يتم إنشاء أي فواتير لـ $_customerName بعد.'
                        : 'ابدأ بإضافة فاتورة جديدة',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    forceRefresh();
                    // انتظار قصير للسماح للتحديث بالاكتمال
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: PaginatedListView<InvoiceEntity>(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(4),
                    items: filteredInvoices,
                    hasMore: state is InvoiceLoaded
                        ? state.hasMore
                        : state is InvoiceStreamActive
                        ? state.hasMore
                        : false,
                    isLoadingMore: state is InvoiceLoaded
                        ? state.isLoadingMore
                        : state is InvoiceStreamActive
                        ? state.isLoadingMore
                        : false,
                    onLoadMore: _onScroll,
                    itemBuilder: (context, index) =>
                        _buildInvoiceCard(filteredInvoices[index]),
                  ),
                ),
              ),
            ],
          );
        },
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _customerName != null
                      ? 'سجل فواتير العميل: $_customerName'
                      : 'إدارة الفواتير',
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
                  _customerName != null
                      ? 'عرض سجل فواتير العميل المحدد'
                      : 'نظام إدارة المتاجر الآشوري',
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
        if (_canViewArchive)
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.archivedInvoices,
                arguments: _customerId != null
                    ? {'customerId': _customerId, 'customerName': _customerName}
                    : null,
              );
            },
            icon: Icon(
              Icons.archive,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: _customerId != null
                ? 'أرشفة جميع الفواتير الحالية للعميل'
                : 'أرشفة جميع الفواتير',
          ),
        IconButton(
          onPressed: forceRefresh,
          icon: Icon(
            Icons.refresh,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          tooltip: 'تحديث القائمة',
        ),
        if (_canExportHistory)
          IconButton(
            onPressed: _isExporting ? null : _exportInvoicesHistory,
            icon: _isExporting
                ? SizedBox(
                    width: 20.sp,
                    height: 20.sp,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AssyrianTheme.primaryGold,
                    ),
                  )
                : Icon(
                    Icons.picture_as_pdf,
                    color: AssyrianTheme.primaryGold,
                    size: 24.sp,
                  ),
            tooltip: 'تصدير سجل الفواتير إلى PDF',
          ),
      ],
    );
  }

  Widget _buildSearchFilter() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث عن فاتورة...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AssyrianTheme.primaryGold,
                        size: 24.sp,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                              },
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey,
                                size: 20.sp,
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(
                          color: AssyrianTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _isFilterExpanded || _selectedFilter != 'all'
                        ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _isFilterExpanded || _selectedFilter != 'all'
                          ? AssyrianTheme.primaryGold
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _isFilterExpanded = !_isFilterExpanded;
                      });
                    },
                    icon: Stack(
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: _isFilterExpanded || _selectedFilter != 'all'
                              ? AssyrianTheme.primaryGold
                              : Colors.grey[600],
                          size: 24.sp,
                        ),
                        if (_selectedFilter != 'all')
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8.w,
                              height: 8.h,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    tooltip: 'فلترة النتائج',
                  ),
                ),
              ],
            ),
          ),
          if (_isFilterExpanded) _buildFilterOptions(),
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    // التحقق من أنواع الفواتير المسموحة - بدون invoices_view العامة
    final canViewSales = _userPermissions['invoices_sales_manage'] == true;
    final canViewPurchase =
        _userPermissions['invoices_purchase_manage'] == true;
    final canViewCash = _userPermissions['invoices_cash_manage'] == true;
    final canViewSubscription =
        _userPermissions['invoices_subscription_manage'] == true;
    final canViewSalesReturn =
        _userPermissions['invoices_sales_return_manage'] == true;

    // إذا لم يكن هناك أي صلاحية لعرض أي نوع من الفواتير
    if (!canViewSales &&
        !canViewPurchase &&
        !canViewCash &&
        !canViewSubscription &&
        !canViewSalesReturn) {
      return Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(
            top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.lock_outline, size: 48.sp, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'لا توجد فواتير متاحة للعرض',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'ليس لديك صلاحية للوصول إلى أي نوع من الفواتير',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          _buildFilterChip('الكل', 'all'),
          _buildFilterChip('مدفوعة', 'paid'),
          _buildFilterChip('جزئية', 'partial'),
          _buildFilterChip('غير مدفوعة', 'unpaid'),
          _buildFilterChip('ملغاة', 'cancelled'),
          if (canViewSales)
            _buildFilterChip(
              'مبيعات',
              'sales',
              requiredPermission: 'invoices_sales_manage',
            ),
          if (canViewPurchase)
            _buildFilterChip(
              'مشتريات',
              'purchase',
              requiredPermission: 'invoices_purchase_manage',
            ),
          if (canViewCash)
            _buildFilterChip(
              'نقدية',
              'cash',
              requiredPermission: 'invoices_cash_manage',
            ),
          if (canViewSubscription)
            _buildFilterChip(
              'اشتراكات',
              'subscription',
              requiredPermission: 'invoices_subscription_manage',
            ),
          if (canViewSalesReturn)
            _buildFilterChip(
              'مرجع بيع',
              'sales_return',
              requiredPermission: 'invoices_sales_return_manage',
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value, {
    String? requiredPermission,
  }) {
    final isSelected = _selectedFilter == value;
    // التحقق من الصلاحية إذا كانت مطلوبة
    final hasPermission =
        requiredPermission == null ||
        _userPermissions[requiredPermission] == true;

    if (!hasPermission) {
      return const SizedBox.shrink(); // إخفاء الفلتر إذا لم تكن هناك صلاحية
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.deepBlue,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.deepBlue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13.sp,
      ),
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80.sp, color: Colors.red[300]),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadInvoices,
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(InvoiceEntity invoice) {
    final statusColor = _getStatusColor(invoice.status);
    final statusText = _getStatusText(invoice.status);
    final typeColor = invoice.type == 'sales'
        ? Colors.green
        : invoice.type == 'purchase'
        ? Colors.blue
        : invoice.type == 'subscription'
        ? Colors.purple
        : invoice.type == 'sales_return'
        ? Colors.teal
        : Colors.orange;
    final typeText = invoice.type == 'sales'
        ? 'مبيعات'
        : invoice.type == 'purchase'
        ? 'مشتريات'
        : invoice.type == 'subscription'
        ? 'اشتراك'
        : invoice.type == 'sales_return'
        ? 'مرجع بيع'
        : 'نقدية';

    // تحديد لون الخلفية حسب تأثير الفاتورة على الدين
    final cardBackgroundColor = _getCardBackgroundColor(
      invoice.type,
      invoice.totalAmount,
      invoice.notes,
    );
    final borderColor = _getCardBorderColor(
      invoice.type,
      invoice.totalAmount,
      invoice.notes,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        minTileHeight: 72.h,
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.invoiceDetails, arguments: invoice);
        },
        leading: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 100.w),
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.of(
                context,
              ).pushNamed('/invoices/edit', arguments: invoice).then((result) {
                if (result == true || result is InvoiceEntity) {
                  forceRefresh();
                }
              });
            } else if (value == 'delete') {
              _showDeleteDialog(invoice);
            } else if (value == 'import_return') {
              _importItemsFromInvoice(invoice);
            }
          },
          itemBuilder: (context) => [
            if (_canEditInvoice(invoice))
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16.sp, color: Colors.blue),
                    SizedBox(width: 6.w),
                    Text('تعديل', style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
            if (_canDeleteInvoice(invoice))
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16.sp, color: Colors.red),
                    SizedBox(width: 6.w),
                    Text('حذف', style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
            // ✅ إظهار خيار استيراد مواد فقط للفواتير التي ليست مراجع بيع
            if (!invoice.isSalesReturn && invoice.type != 'sales_return')
              PopupMenuItem(
                value: 'import_return',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 16.sp, color: Colors.orange),
                    SizedBox(width: 6.w),
                    Text('استيراد للإرجاع', style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
          ],
          child: CircleAvatar(
            backgroundColor: typeColor.withValues(alpha: 0.1),
            radius: 22.r,
            child: Icon(Icons.receipt_long, color: typeColor, size: 20.sp),
          ),
        ),
        title: Text(
          invoice.invoiceNumber,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 3.h),
            Text(
              invoice.customerName,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 5.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    typeText,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: typeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.calendar_today,
                  size: 10.sp,
                  color: Colors.grey[500],
                ),
                SizedBox(width: 3.w),
                Text(
                  _formattingService.formatInvoiceDate(invoice.invoiceDate),
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
        trailing: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _getDisplayAmount(invoice),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AssyrianTheme.deepBlue,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
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

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'partial':
        return 'جزئية';
      case 'unpaid':
        return 'غير مدفوعة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  /// تحديد لون خلفية الكارت حسب تأثير الفاتورة على الدين
  Color _getCardBackgroundColor(
    String type,
    double totalAmount,
    String? notes,
  ) {
    // للفواتير النقدية، نعتمد على الملاحظات لتحديد التأثير على الدين
    if (type == 'cash' && notes != null) {
      if (notes.contains('عليه') ||
          notes.contains('تسديد دين') ||
          notes.contains('مدين') ||
          notes.contains('إعطاء مبلغ نقدي للعميل')) {
        // "عليه" (يزيد الدين) - لون أحمر فاتح
        return Colors.red.withValues(alpha: 0.05);
      } else if (notes.contains('له') ||
          notes.contains('دفع مقدم') ||
          notes.contains('دائن') ||
          notes.contains('استلام مبلغ نقدي من العميل')) {
        // "له" (يقلل الدين) - لون أخضر فاتح
        return Colors.green.withValues(alpha: 0.05);
      }
    } else if (type == 'sales') {
      // فواتير المبيعات تزيد الدين دائماً - لون أحمر فاتح
      return Colors.red.withValues(alpha: 0.05);
    } else if (type == 'subscription') {
      // فواتير الاشتراكات تزيد الدين دائماً - لون بنفسجي فاتح
      return Colors.purple.withValues(alpha: 0.05);
    } else if (type == 'sales_return') {
      // فواتير مرجع البيع تقلل الدين - لون أزرق مخضر فاتح
      return Colors.teal.withValues(alpha: 0.08);
    }

    // فواتير المشتريات أو أي نوع آخر - اللون الافتراضي
    return Colors.white;
  }

  /// تحديد لون حدود الكارت حسب تأثير الفاتورة على الدين
  Color _getCardBorderColor(String type, double totalAmount, String? notes) {
    // للفواتير النقدية، نعتمد على الملاحظات لتحديد التأثير على الدين
    if (type == 'cash' && notes != null) {
      if (notes.contains('عليه') ||
          notes.contains('تسديد دين') ||
          notes.contains('مدين') ||
          notes.contains('إعطاء مبلغ نقدي للعميل')) {
        // "عليه" (يزيد الدين) - حدود حمراء فاتحة
        return Colors.red.withValues(alpha: 0.3);
      } else if (notes.contains('له') ||
          notes.contains('دفع مقدم') ||
          notes.contains('دائن') ||
          notes.contains('استلام مبلغ نقدي من العميل')) {
        // "له" (يقلل الدين) - حدود خضراء فاتحة
        return Colors.green.withValues(alpha: 0.3);
      }
    } else if (type == 'sales') {
      // فواتير المبيعات تزيد الدين دائماً - حدود حمراء فاتحة
      return Colors.red.withValues(alpha: 0.3);
    } else if (type == 'subscription') {
      // فواتير الاشتراكات تزيد الدين دائماً - حدود بنفسجية فاتحة
      return Colors.purple.withValues(alpha: 0.3);
    } else if (type == 'sales_return') {
      // فواتير مرجع البيع تقلل الدين - حدود زرقاء مخضرة
      return Colors.teal.withValues(alpha: 0.4);
    }

    // فواتير المشتريات أو أي نوع آخر - الحدود الافتراضية
    return AssyrianTheme.primaryGold.withValues(alpha: 0.2);
  }

  void _showDeleteDialog(InvoiceEntity invoice) {
    DeleteInvoiceDialog.show(
      context,
      invoice,
      context.read<InvoiceBloc>(),
      onDeleted: _loadInvoices,
    );
  }

  /// تحديد المبلغ المناسب للعرض في القائمة
  String _getDisplayAmount(InvoiceEntity invoice) {
    // للفواتير النقدية "له" التي لها totalAmount = 0، نعرض المبلغ المدفوع بدون إشارة سالبة
    if (invoice.type == 'cash' &&
        invoice.isCashAccountReceipt &&
        invoice.totalAmount == 0 &&
        invoice.paidAmount != 0 &&
        invoice.notes != null &&
        (invoice.notes!.contains('له') ||
            invoice.notes!.contains('دفع مقدم') ||
            invoice.notes!.contains('دائن') ||
            invoice.notes!.contains('استلام مبلغ نقدي من العميل'))) {
      return _formattingService.formatInvoiceTotal(invoice.paidAmount.abs());
    }

    // للفواتير العادية، نعرض المبلغ الإجمالي
    return _formattingService.formatInvoiceTotal(invoice.totalAmount);
  }
}
