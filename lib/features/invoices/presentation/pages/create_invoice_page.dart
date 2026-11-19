import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/invoice_numbering_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/smart_number_formatter.dart';
import '../../../../core/widgets/credit_limit_warning_dialog.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../../inventory/data/models/product_model.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../inventory/domain/entities/shelf_entity.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/returned_item_entity.dart';
import '../bloc/invoice_bloc.dart';
import '../widgets/invoice_drawer.dart';

/// صفحة إضافة فاتورة جديدة
class CreateInvoicePage extends StatefulWidget {
  const CreateInvoicePage({super.key});

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage>
    with SaveOperationMixin<CreateInvoicePage> {
  // حماية من التنفيذ المكرر
  bool _operationCompleted = false;

  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  final _formKey = GlobalKey<FormState>();

  // صلاحيات أنواع الفواتير
  bool _canCreateSales = false;
  bool _canCreatePurchase = false;
  bool _canCreateCash = false;
  bool _canCreateSubscription = false;
  bool _canCreateSalesReturn = false;

  // Controllers للحقول النصية
  final _notesController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _editItemNameController = TextEditingController();
  final _paidAmountController = TextEditingController();
  int? _editingItemIndex;

  // متغيرات للحقول الأخرى
  CustomerEntity? _selectedCustomer;
  ProductEntity? _selectedProduct;
  String _selectedType = 'sales';
  final DateTime _invoiceDate = DateTime.now();
  final String _invoiceNumber = InvoiceNumberingService.generateNumberSync(
    section: 'sales',
  );
  String? _refundMethod; // لفاتورة مرجع البيع: 'credit' أو 'cash'

  // ✅ ملاحظة للمبرمجين المستقبليين: رقم الفاتورة المُنشأ تلقائياً (السطر 70-71)
  /// تم تعديل substring ليأخذ آخر 6 أرقام من الطابع الزمني بدلاً من substring(8) المتغير الطول.
  /// هذا يضمن طولاً ثابتاً للجزء العشري ويقلل احتمال التصادم، لكن لا يزال هناك احتمال نادر
  /// للتصادم إذا تم إنشاء فاتورتين في نفس الملي ثانية. لضمان فريدة مطلقة، يُنصح مستقبلاً
  /// باستخدام رقم تتابعي من الإعدادات (مثل _startingNumber في الإعدادات) أو إضافة حزمة uuid
  /// واستخدام const Uuid().v4() لتوليد معرّف فريد عالمياً.
  /// ⚠️ لا تُعدّل هذا المنطق دون اختبار التصادم تحت الأحمال العالية.
  // متغيرات المنتج الجديد
  final _newProductPurchasePriceController = TextEditingController();
  final _newProductSellingPriceController = TextEditingController();
  final _newProductQuantityController = TextEditingController();
  final _manualReturnNameController = TextEditingController();
  final _manualReturnQuantityController = TextEditingController(text: '1');
  final _manualReturnPriceController = TextEditingController();

  // متغيرات سعر الشراء والبيع لفواتير الشراء
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  double _defaultPurchasePrice = 0; // سعر الشراء الافتراضي من المخزون
  double _defaultSellingPrice = 0; // سعر البيع الافتراضي من المخزون

  // متغيرات الفاتورة النقدية
  String _cashTransactionType =
      'receipt'; // 'receipt' = استلام، 'payment' = إعطاء
  final _cashAmountController = TextEditingController(); // حقل المبلغ النقدي
  double _cashAmount = 0; // المبلغ النقدي

  // قوائم للبيانات المرتبطة
  List<CustomerEntity> _customers = [];
  List<CustomerEntity> _filteredCustomers = [];
  List<ProductEntity> _products = [];
  List<ProductEntity> _filteredProducts = [];
  List<ShelfEntity> _shelves = []; // قائمة الرفوف
  List<InvoiceItemEntity> _soldItems = []; // المواد المباعة للعميل
  List<InvoiceItemEntity> _filteredSoldItems = []; // المواد المفلترة
  InvoiceItemEntity? _selectedSoldItem;
  bool _showSoldItemsSuggestions = false;
  bool _showManualReturnForm = false;
  bool _isLoadingSoldItems = false;
  int _soldItemsLoadGeneration = 0;

  // LayerLink و GlobalKey لعرض اقتراحات العملاء
  final LayerLink _customerLayerLink = LayerLink();
  final GlobalKey _customerFieldKey = GlobalKey();

  // LayerLink و GlobalKey لعرض اقتراحات المنتجات
  final LayerLink _productLayerLink = LayerLink();
  final GlobalKey _productFieldKey = GlobalKey();

  // عناصر الفاتورة
  final List<InvoiceItemEntity> _invoiceItems = [];
  final List<GlobalKey> _invoiceItemKeys = [];

  InvoiceItemEntity? _findSoldItemForReturn(InvoiceItemEntity item) {
    final selectedSoldItem = _selectedSoldItem;
    if (selectedSoldItem != null &&
        selectedSoldItem.productName == item.productName &&
        (item.originalInvoiceId == null ||
            selectedSoldItem.originalInvoiceId == item.originalInvoiceId)) {
      return selectedSoldItem;
    }

    // Don't guess the source invoice when the same product was sold on
    // multiple invoices; the selected sold-item row identifies the right line.
    if (item.originalInvoiceId == null || item.originalInvoiceId!.isEmpty) {
      return null;
    }

    return _soldItems.firstWhereOrNull(
      (soldItem) =>
          soldItem.productName == item.productName &&
          soldItem.originalInvoiceId == item.originalInvoiceId,
    );
  }

  void _refreshSoldItemsForCurrentCustomer() {
    if (_selectedType != 'sales_return') return;
    final customerId = _selectedCustomer?.id;
    if (customerId == null || customerId.isEmpty) {
      _loadAllSoldItems();
    } else {
      _loadSoldItemsForCustomer(customerId);
    }
  }

  // حسابات الفاتورة
  double _totalAmount = 0;
  double _taxAmount = 0.0; // مبلغ الضريبة
  final List<Map<String, dynamic>> _taxes = []; // قائمة الضرائب
  final _discountController = TextEditingController(); // حقل الخصم
  final _taxAmountController = TextEditingController(); // حقل مبلغ الضريبة
  final _taxRateController = TextEditingController(); // حقل نسبة الضريبة
  // متغير لتتبع ما إذا تم تحميل البيانات المرسلة
  bool _argumentsProcessed = false;

  double get _currentPaidAmount {
    if (_paidAmountController.text.trim().isEmpty) return 0.0;
    final clean = SmartNumberFormatter.convertToEnglishNumbers(
      _paidAmountController.text
          .replaceAll(',', '')
          .replaceAll('،', '')
          .replaceAll(' ', '')
          .replaceAll(_formattingService.thousandsSeparator, '')
          .trim(),
    );
    return double.tryParse(clean) ?? 0.0;
  }

  double get _currentDiscountAmount {
    if (_discountController.text.trim().isEmpty) return 0.0;
    final clean = SmartNumberFormatter.convertToEnglishNumbers(
      _discountController.text
          .replaceAll(',', '')
          .replaceAll('،', '')
          .replaceAll(' ', '')
          .replaceAll(_formattingService.thousandsSeparator, '')
          .trim(),
    );
    return double.tryParse(clean) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _paidAmountController.addListener(() {
      if (mounted) setState(() {});
    });
    _discountController.addListener(() {
      if (mounted) setState(() {});
    });
    _cashAmountController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadPermissions();
    _loadRelatedData();
    if (_selectedType == 'sales_return') {
      _refreshSoldItemsForCurrentCustomer();
    }
  }

  Future<void> _loadPermissions() async {
    final canCreateSales = await _permissionChecker.hasPermission(
      'invoices_sales_manage',
    );
    final canCreatePurchase = await _permissionChecker.hasPermission(
      'invoices_purchase_manage',
    );
    final canCreateCash = await _permissionChecker.hasPermission(
      'invoices_cash_manage',
    );
    final canCreateSubscription = await _permissionChecker.hasPermission(
      'invoices_subscription_manage',
    );
    final canCreateSalesReturn = await _permissionChecker.hasPermission(
      'invoices_sales_return_manage',
    );

    // تحديث UI بعد تحميل الصلاحيات
    if (mounted) {
      setState(() {
        _canCreateSales = canCreateSales;
        _canCreatePurchase = canCreatePurchase;
        _canCreateCash = canCreateCash;
        _canCreateSubscription = canCreateSubscription;
        _canCreateSalesReturn = canCreateSalesReturn;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // معالجة البيانات المرسلة من الصفحة السابقة
    if (!_argumentsProcessed) {
      final arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (arguments != null) {
        // معالجة بيانات العميل المحدد (فاتورة عادية أو مرجع بيع)
        if (arguments.containsKey('customerId')) {
          final customerId = arguments['customerId'] as String?;
          final customerName = arguments['customerName'] as String?;
          final customerPhone = arguments['customerPhone'] as String?;
          final customerTotalDebt = arguments['customerTotalDebt'] as double?;
          final invoiceType = arguments['type'] as String? ?? 'sales';

          if (customerId != null && customerName != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // إذا لم يتم تحميل العملاء بعد، ننتظر حتى يتم تحميلهم
              if (_customers.isEmpty) {
                await Future.delayed(const Duration(milliseconds: 500));
              }
              if (mounted) {
                await _processCustomerArguments(
                  customerId,
                  customerName,
                  customerPhone,
                  invoiceType,
                  customerTotalDebt: customerTotalDebt,
                );
              }
            });
          }
        }
        if (arguments.containsKey('subscriptionData')) {
          _processSubscriptionData(
            arguments['subscriptionData'] as Map<String, dynamic>,
          );
        }
      }
      _argumentsProcessed = true;
    }
  }

  /// معالجة بيانات العميل المحدد (فاتورة عادية أو مرجع بيع)
  Future<void> _processCustomerArguments(
    String customerId,
    String customerName,
    String? customerPhone,
    String invoiceType, {
    double? customerTotalDebt,
  }) async {
    CustomerEntity? matchingCustomer;

    // 1) البحث في القائمة المحلية أولاً
    if (_customers.isNotEmpty) {
      matchingCustomer = _customers.firstWhereOrNull(
        (customer) => customer.id == customerId,
      );

      if (matchingCustomer == null && customerName.isNotEmpty) {
        matchingCustomer = _customers.firstWhereOrNull(
          (customer) => customer.name == customerName,
        );
      }
    }

    // 2) إذا لم يتم العثور على العميل، نجلب بياناته من السيرفر
    if (matchingCustomer == null && customerId.isNotEmpty) {
      try {
        final customerRepository = GetIt.instance<CustomerRepository>();
        final customerResult = await customerRepository.getCustomerById(
          customerId,
          forceRefresh: true,
        );
        matchingCustomer = customerResult.fold(
          (failure) => null,
          (customer) => customer,
        );
      } on Exception catch (_) {
        matchingCustomer = null;
      }
    }

    // 3) إذا لم يتم العثور على العميل حتى من السيرفر، ننشئ عميلاً مؤقتاً
    if (matchingCustomer == null) {
      final user = FirebaseAuth.instance.currentUser;
      matchingCustomer = CustomerEntity(
        id: customerId,
        organizationEmail: user?.email ?? '',
        name: customerName,
        email: '',
        phone: customerPhone ?? '',
        totalPurchases: 0,
        totalDebt: customerTotalDebt ?? 0,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    if (!mounted) return;

    setState(() {
      _selectedCustomer = matchingCustomer;
      _customerSearchController.text = matchingCustomer!.name;
      _selectedType = invoiceType;

      if (invoiceType == 'sales_return') {
        _loadSoldItemsForCustomer(customerId);
      }
    });
  }

  /// معالجة بيانات الاشتراك لإنشاء فاتورة اشتراك
  void _processSubscriptionData(Map<String, dynamic> subscriptionData) {
    final serviceName = subscriptionData['serviceName'] as String?;
    final monthlyFee = subscriptionData['monthlyFee'] as double?;

    if (serviceName != null && monthlyFee != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // إضافة خدمة الاشتراك كعنصر في الفاتورة
        final subscriptionItem = InvoiceItemEntity(
          productName: 'اشتراك - $serviceName',
          quantity: 1,
          unitPrice: monthlyFee,
          totalPrice: monthlyFee,
          unit: 'شهر',
        );

        setState(() {
          _invoiceItems.add(subscriptionItem);
          _calculateTotal();
        });
      });
    }
  }

  // إضافة ضريبة جديدة
  void _addTax() {
    final taxNameController = TextEditingController();
    final taxRateController = TextEditingController();
    final taxAmountController = TextEditingController();

    showDialog(
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
              child: Icon(Icons.add_circle, color: Colors.orange, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'إضافة ضريبة جديدة',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        content: _buildTaxDialogContent(
          taxNameController,
          taxRateController,
          taxAmountController,
        ),
        actionsPadding: EdgeInsets.all(16.w),
        actions: _buildTaxDialogActions(
          dialogContext,
          taxNameController,
          taxRateController,
          taxAmountController,
        ),
      ),
    );
  }

  Widget _buildTaxDialogContent(
    TextEditingController taxNameController,
    TextEditingController taxRateController,
    TextEditingController taxAmountController,
  ) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اسم الضريبة',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8.h),
          TextFormField(
            controller: taxNameController,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'مثالاً: ضريبة قيمة مضافة',
              hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
              prefixIcon: Icon(Icons.tag, color: Colors.orange, size: 22.sp),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.orange, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'قيمة الضريبة',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'النسبة %',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4.h),
                    TextFormField(
                      controller: taxRateController,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.percent,
                          color: Colors.orange,
                          size: 20.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        ),
                        suffixText: '%',
                        suffixStyle: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _formattingService.getNumberInputFormatter(),
                      ],
                      onChanged: (value) {
                        final rate =
                            double.tryParse(value.replaceAll(',', '')) ?? 0;
                        final basePrice = _totalAmount;
                        final amount = basePrice * (rate / 100);
                        taxAmountController.text = _formattingService
                            .formatNumber(amount);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المبلغ',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4.h),
                    TextFormField(
                      controller: taxAmountController,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.account_balance,
                          color: Colors.orange,
                          size: 20.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _formattingService.getNumberInputFormatter(),
                      ],
                      onChanged: (value) {
                        final amount =
                            double.tryParse(value.replaceAll(',', '')) ?? 0;
                        final basePrice = _totalAmount;
                        if (basePrice > 0) {
                          final rate = (amount / basePrice) * 100;
                          taxRateController.text = rate.toStringAsFixed(1);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTaxDialogActions(
    BuildContext dialogContext,
    TextEditingController taxNameController,
    TextEditingController taxRateController,
    TextEditingController taxAmountController,
  ) {
    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[400]!),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                'إلغاء',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                final name = taxNameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الضريبة')),
                  );
                  return;
                }

                final rate =
                    double.tryParse(
                      taxRateController.text.replaceAll(',', ''),
                    ) ??
                    0;
                final amount =
                    double.tryParse(
                      taxAmountController.text.replaceAll(',', ''),
                    ) ??
                    0;

                Navigator.of(dialogContext).pop();

                setState(() {
                  _taxes.add({
                    'name': name,
                    'rate': rate,
                    'amount': amount,
                    'isPercentage': rate > 0,
                  });
                  _calculateTotalTax();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                elevation: 2,
                shadowColor: Colors.orange.withValues(alpha: 0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle, size: 18.sp, color: Colors.white),
                  SizedBox(width: 6.w),
                  Text(
                    'إضافة الضريبة',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  // حساب إجمالي الضرائب (تراكمي - ضريبة تلو الأخرى)
  void _calculateTotalTax() {
    if (_taxes.isEmpty) {
      _taxAmount = 0.0;
      return;
    }

    // حساب تراكمي: كل ضريبة تُطبق على المبلغ بعد الضريبة السابقة
    double currentAmount = _totalAmount;
    double totalTax = 0.0;

    for (var tax in _taxes) {
      final taxAmountValue = tax['amount'] as double;
      final isPercentage = tax['isPercentage'] as bool;

      if (isPercentage && tax['rate'] as double > 0) {
        // ضريبة نسبة: تُحسب على المبلغ الحالي
        final rate = tax['rate'] as double;
        final calculatedTax = currentAmount * (rate / 100);
        totalTax += calculatedTax;
        currentAmount += calculatedTax;
      } else {
        // ضريبة مبلغ ثابت: تُضاف مباشرة
        totalTax += taxAmountValue;
        currentAmount += taxAmountValue;
      }
    }

    setState(() {
      _taxAmount = totalTax;
    });
  }

  void _loadRelatedData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // تحميل العملاء
      context.read<CustomerBloc>().add(LoadCustomersEvent(user.email!));
      // تحميل المنتجات
      context.read<InventoryBloc>().add(
        LoadInventoryData(organizationEmail: user.email!),
      );
    }
  }

  /// جلب المواد المباعة للعميل من الفواتير غير المؤرشفة
  Future<void> _loadSoldItemsForCustomer(String customerId) async {
    final generation = ++_soldItemsLoadGeneration;
    if (!mounted) return;
    setState(() {
      _isLoadingSoldItems = true;
      _soldItems = [];
      _filteredSoldItems = [];
      _selectedSoldItem = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        if (mounted && generation == _soldItemsLoadGeneration) {
          setState(() => _isLoadingSoldItems = false);
        }
        return;
      }

      final invoiceBloc = GetIt.instance.get<InvoiceBloc>();

      // جلب فواتير العميل
      final result = await invoiceBloc.repository.getInvoices(user!.email!);

      await result.fold((failure) async {}, (invoices) async {
        // فلترة فواتير العميل المحدد
        final customerInvoices = invoices
            .where(
              (invoice) =>
                  invoice.customerId == customerId &&
                  !invoice.isArchived &&
                  !invoice.isSalesReturn && // ✅ استبعاد فواتير مرجع البيع
                  invoice.type != 'sales_return', // ✅ استبعاد فواتير مرجع البيع
            )
            .toList();

        final items = <InvoiceItemEntity>[];
        for (final invoice in customerInvoices) {
          // إضافة المواد من كل فاتورة مع معلومات الفاتورة
          for (final item in invoice.items) {
            items.add(
              InvoiceItemEntity(
                productName: item.productName,
                productId: item.productId,
                originalQuantity: item.quantity.abs(),
                quantity: item.quantity.abs(),
                unit: item.unit,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
                itemId: item.itemId, // حفظ معرف المنتج
                originalInvoiceId: invoice.id,
                originalInvoiceNumber:
                    invoice.invoiceNumber, // حفظ رقم الفاتورة
                originalSaleDate: invoice.invoiceDate,
              ),
            );
          }
        }

        final itemsWithReturnBalances = _applyPreviouslyReturnedQuantities(
          items,
          invoices,
          customerId: customerId,
        );
        if (!mounted || generation != _soldItemsLoadGeneration) return;
        setState(() {
          _isLoadingSoldItems = false;
          _soldItems = itemsWithReturnBalances;
          _filteredSoldItems = List.from(itemsWithReturnBalances);
        });
      });
    } on Exception catch (_) {
      if (mounted && generation == _soldItemsLoadGeneration) {
        setState(() => _isLoadingSoldItems = false);
      }
    }
  }

  /// جلب جميع المواد المشتراة من جميع الفواتير (عند عدم تحديد عميل)
  Future<void> _loadAllSoldItems() async {
    final generation = ++_soldItemsLoadGeneration;
    if (!mounted) return;
    setState(() {
      _isLoadingSoldItems = true;
      _soldItems = [];
      _filteredSoldItems = [];
      _selectedSoldItem = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;

      final invoiceBloc = GetIt.instance.get<InvoiceBloc>();

      // جلب جميع الفواتير
      final result = await invoiceBloc.repository.getInvoices(user!.email!);

      await result.fold((failure) async {}, (invoices) async {
        final items = <InvoiceItemEntity>[];
        for (final invoice in invoices) {
          // تخطي الفواتير المؤرشفة وفواتير مرجع البيع
          if (invoice.isArchived ||
              invoice.isSalesReturn ||
              invoice.type == 'sales_return') {
            continue;
          }

          // إضافة المواد من كل فاتورة مع معلومات الفاتورة
          for (final item in invoice.items) {
            items.add(
              InvoiceItemEntity(
                productName: item.productName,
                productId: item.productId,
                originalQuantity: item.quantity.abs(),
                quantity: item.quantity.abs(),
                unit: item.unit,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
                itemId: item.itemId,
                originalInvoiceId: invoice.id,
                originalInvoiceNumber: invoice.invoiceNumber,
                originalSaleDate: invoice.invoiceDate,
              ),
            );
          }
        }

        final itemsWithReturnBalances = _applyPreviouslyReturnedQuantities(
          items,
          invoices,
        );
        if (!mounted || generation != _soldItemsLoadGeneration) return;
        setState(() {
          _isLoadingSoldItems = false;
          _soldItems = itemsWithReturnBalances;
          _filteredSoldItems = List.from(itemsWithReturnBalances);
        });
      });
    } on Exception catch (_) {
      if (mounted && generation == _soldItemsLoadGeneration) {
        setState(() => _isLoadingSoldItems = false);
      }
    }
  }

  /// عرض اقتراحات العملاء
  void _showCustomerSuggestionsOverlay() {
    if (_filteredCustomers.isEmpty) return;

    final suggestions = _filteredCustomers
        .take(5)
        .map(
          (customer) => customer.toSuggestionItem(
            formatCurrency: _formattingService.formatCurrency,
          ),
        )
        .toList();

    SuggestionsOverlay.show(
      context: context,
      anchorKey: _customerFieldKey,
      layerLink: _customerLayerLink,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        final customer = _filteredCustomers.firstWhere(
          (c) => c.name == value,
          orElse: () => _filteredCustomers.first,
        );
        setState(() {
          _selectedCustomer = customer;
          _customerSearchController.text = customer.name;

          // جلب المواد المباعة للعميل إذا كانت فاتورة مرجع بيع
          if (_selectedType == 'sales_return') {
            _loadSoldItemsForCustomer(customer.id);
          }
        });
      },
      maxHeight: 200.h,
    );
  }

  List<InvoiceItemEntity> _applyPreviouslyReturnedQuantities(
    List<InvoiceItemEntity> soldItems,
    List<InvoiceEntity> invoices, {
    String? customerId,
  }) {
    final returnedBySaleItem = <String, double>{};
    for (final returnInvoice in invoices) {
      if (!returnInvoice.isSalesReturn ||
          returnInvoice.isArchived ||
          (customerId != null && returnInvoice.customerId != customerId)) {
        continue;
      }
      for (final returnedItem in returnInvoice.returnedItems ?? const []) {
        if (returnedItem.originalInvoiceId.isEmpty ||
            returnedItem.itemId.startsWith('manual_return_')) {
          continue;
        }
        final saleInvoice = invoices.firstWhereOrNull(
          (invoice) =>
              invoice.id == returnedItem.originalInvoiceId &&
              !invoice.isArchived &&
              (customerId == null || invoice.customerId == customerId),
        );
        if (saleInvoice == null) continue;
        final sourceItem = saleInvoice.items.firstWhereOrNull(
          (item) =>
              item.itemId == returnedItem.itemId ||
              (item.itemId == null &&
                  item.productName == returnedItem.itemName),
        );
        if (sourceItem == null) continue;
        final sourceItemId = sourceItem.itemId ?? sourceItem.productName;
        final key = '${sourceItemId}_${saleInvoice.id}';
        returnedBySaleItem.update(
          key,
          (quantity) => quantity + returnedItem.returnedQuantity,
          ifAbsent: () => returnedItem.returnedQuantity.toDouble(),
        );
      }
    }

    return soldItems.map((item) {
      final originalQuantity = item.originalQuantity ?? item.quantity;
      final itemId = item.itemId ?? item.productName;
      final key = '${itemId}_${item.originalInvoiceId ?? ''}';
      final returnedQuantity = returnedBySaleItem[key] ?? 0;
      final remainingQuantity = (originalQuantity - returnedQuantity).clamp(
        0.0,
        double.infinity,
      );
      return InvoiceItemEntity(
        productName: item.productName,
        productId: item.productId,
        originalQuantity: originalQuantity,
        quantity: remainingQuantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        totalPrice: remainingQuantity * item.unitPrice,
        itemId: item.itemId,
        originalInvoiceId: item.originalInvoiceId,
        originalInvoiceNumber: item.originalInvoiceNumber,
        originalSaleDate: item.originalSaleDate,
        returnedQuantity: returnedQuantity.toInt(),
      );
    }).toList();
  }

  void _addManualReturnItem() {
    final name = _manualReturnNameController.text.trim();
    final quantity = double.tryParse(
      SmartNumberFormatter.convertToEnglishNumbers(
        _manualReturnQuantityController.text
            .replaceAll(',', '')
            .replaceAll('،', '')
            .trim(),
      ),
    );
    final unitPrice = double.tryParse(
      SmartNumberFormatter.convertToEnglishNumbers(
        _manualReturnPriceController.text
            .replaceAll(',', '')
            .replaceAll('،', '')
            .replaceAll(_formattingService.thousandsSeparator, '')
            .trim(),
      ),
    );
    if (name.isEmpty ||
        quantity == null ||
        !quantity.isFinite ||
        quantity <= 0 ||
        quantity != quantity.truncateToDouble() ||
        unitPrice == null ||
        !unitPrice.isFinite ||
        unitPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل اسم المادة والكمية وسعر الاسترداد بشكل صحيح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_invoiceItems.any(
      (item) => item.productName.trim().toLowerCase() == name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هذه المادة موجودة بالفعل في المرتجع؛ عدّلها من القائمة',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final matchingProducts = _products.where((product) {
      return product.isActive &&
          product.name.trim().toLowerCase() == name.toLowerCase();
    }).toList();
    final linkedProduct = matchingProducts.length == 1
        ? matchingProducts.single
        : null;
    setState(() {
      _invoiceItems.add(
        InvoiceItemEntity(
          productName: name,
          productId: linkedProduct?.id,
          quantity: quantity,
          unit: '',
          unitPrice: unitPrice,
          totalPrice: quantity * unitPrice,
          itemId: 'manual_return_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      _selectedSoldItem = null;
      _calculateTotal();
      _manualReturnNameController.clear();
      _manualReturnQuantityController.text = '1';
      _manualReturnPriceController.clear();
      _showManualReturnForm = false;
    });

    final stockMessage = linkedProduct?.trackQuantity == true
        ? ' وستُضاف الكمية إلى مخزون المنتج المطابق'
        : linkedProduct == null && matchingProducts.length > 1
        ? ' ولم يُربط بالمخزون لأن الاسم يطابق أكثر من منتج'
        : linkedProduct == null
        ? ' ولم يُربط بمنتج في المخزون'
        : ' (المنتج لا يتتبع الكمية في المخزون)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('أُضيف العنصر المرتجع$stockMessage')),
    );
  }

  /// إخفاء اقتراحات العملاء
  void _hideCustomerSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  /// عرض اقتراحات المنتجات
  void _showProductSuggestionsOverlay() {
    if (_filteredProducts.isEmpty) return;

    final suggestions = _filteredProducts.take(5).map((product) {
      // البحث عن اسم الرف
      String? shelfName;
      if (product.shelfId != null && product.shelfId!.isNotEmpty) {
        final shelf = _shelves.firstWhereOrNull((s) => s.id == product.shelfId);
        shelfName = shelf?.name;
      }

      return product.toProductSuggestionItem(
        formatCurrency: _formattingService.formatCurrency,
        shelfName: shelfName,
      );
    }).toList();

    SuggestionsOverlay.show(
      context: context,
      anchorKey: _productFieldKey,
      layerLink: _productLayerLink,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        final product = _filteredProducts.firstWhere(
          (p) => p.name == value,
          orElse: () => ProductModel.fromEntity(_filteredProducts.first),
        );
        setState(() {
          _selectedProduct = product;
          _productSearchController.text = product.name;
          _defaultPurchasePrice = product.costPrice ?? 0;
          _defaultSellingPrice = product.sellingPrice;
          _purchasePriceController.text = _formattingService.formatNumber(
            product.costPrice ?? 0,
          );
          _sellingPriceController.text = _formattingService.formatNumber(
            product.sellingPrice,
          );
          _quantityController.text = '1';
          _newProductQuantityController.text = '1';
        });
      },
      maxHeight: 200.h,
    );
  }

  /// إخفاء اقتراحات المنتجات
  void _hideProductSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  @override
  void dispose() {
    _hideCustomerSuggestionsOverlay();
    _hideProductSuggestionsOverlay();
    _notesController.dispose();
    _customerSearchController.dispose();
    _productSearchController.dispose();
    _quantityController.dispose();
    _itemPriceController.dispose();
    _editItemNameController.dispose();
    _paidAmountController.dispose();
    _newProductPurchasePriceController.dispose();
    _newProductSellingPriceController.dispose();
    _newProductQuantityController.dispose();
    _manualReturnNameController.dispose();
    _manualReturnQuantityController.dispose();
    _manualReturnPriceController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _discountController.dispose();
    _taxAmountController.dispose();
    _taxRateController.dispose();
    _cashAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const InvoiceDrawer(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: MultiBlocListener(
        listeners: [
          BlocListener<CustomerBloc, CustomerState>(
            listenWhen: (previous, current) {
              return current is CustomerLoaded;
            },
            listener: (context, state) {
              if (state is CustomerLoaded) {
                _customers = state.customers;
                _filteredCustomers = List.from(_customers);
              }
            },
          ),
          BlocListener<InventoryBloc, InventoryState>(
            listenWhen: (previous, current) {
              return current is InventoryLoaded;
            },
            listener: (context, state) {
              if (state is InventoryLoaded) {
                _products = state.products;
                _filteredProducts = List.from(_products);
                _shelves = state.shelves ?? [];
              }
            },
          ),
        ],
        child: BlocConsumer<InvoiceBloc, InvoiceState>(
          listenWhen: (previous, current) {
            return current is InvoiceError ||
                current is InvoiceOperationSuccess;
          },
          listener: (context, state) {
            if (state is InvoiceError && !_operationCompleted) {
              _operationCompleted = true;
              failSaveOperation(errorMessage: state.message);
            } else if (state is InvoiceOperationSuccess &&
                !_operationCompleted) {
              _operationCompleted = true;
              // ✅ شاشة إنشاء كاملة: بعد نجاح الحفظ
              // تعود للشاشة السابقة (navigateBackOnSuccess:
              // true) — كانت تبقى في شاشة الإنشاء لأن
              // completeSaveOperation افتراضيًا لا تعود
              // (navigateBackOnSuccess: false)
              completeSaveOperation(
                successMessage: state.message,
                navigateBackOnSuccess: true,
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is InvoiceLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _buildWelcomeCard(context),
                  const SizedBox(height: 6),
                  _buildFormCard(context, isLoading),
                ],
              ),
            );
          },
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة فاتورة جديدة',
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
                  'نظام إدارة الفواتير الآشوري',
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
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return const DetailScreenHeader(
      title: 'إضافة فاتورة جديدة',
      subtitle: 'إنشاء فاتورة جديدة وإضافتها إلى قاعدة البيانات',
      icon: Icons.receipt_long,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard(BuildContext context, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(
            title: 'المعلومات الأساسية',
            icon: Icons.info_outline,
            children: [_buildCustomerSearchField(), _buildTypeDropdown()],
          ),
          const SizedBox(height: 20),

          if (_selectedType == 'cash' && _selectedCustomer != null) ...[
            InfoCard(
              title: 'إيصال نقدي',
              icon: Icons.payments,
              children: [
                _buildCashTransactionTypeField(),
                _buildCashAmountField(),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (_selectedType != 'cash' || _selectedCustomer == null) ...[
            InfoCard(
              title: _selectedType == 'sales_return'
                  ? 'إضافة مواد مرتجعة'
                  : 'إضافة المنتجات',
              icon: _selectedType == 'sales_return'
                  ? Icons.assignment_return
                  : Icons.shopping_cart,
              children: [
                _buildProductSearchField(),
                if (_selectedType == 'sales_return') _buildManualReturnEntry(),
              ],
            ),
            const SizedBox(height: 20),
          ],

          if (_invoiceItems.isNotEmpty || _editingItemIndex != null) ...[
            InfoCard(
              title: 'عناصر الفاتورة',
              icon: Icons.list_alt,
              children: [
                if (_invoiceItems.isNotEmpty) _buildInvoiceItemsList(),
              ],
            ),
            const SizedBox(height: 20),
          ],

          InfoCard(
            title: 'الملاحظات',
            icon: Icons.note,
            children: [_buildNotesField()],
          ),
          const SizedBox(height: 20),

          // إخفاء قسم الدفع للفاتورة النقدية
          if (_selectedType != 'cash') ...[
            InfoCard(
              title: 'الدفع',
              icon: Icons.payment,
              children: [
                _buildPaidAmountField(),
                if (_selectedType == 'sales_return') ...[
                  const SizedBox(height: 12),
                  _buildRefundMethodField(),
                ],
              ],
            ),
            const SizedBox(height: 20),
          ],

          _buildTotalSection(),
          const SizedBox(height: 24),

          _buildSubmitButton(isLoading),
        ],
      ),
    );
  }

  Widget _buildCustomerSearchField() {
    final hasAttachedDetails =
        _selectedCustomer != null || _customerSearchController.text.isEmpty;
    final detailsColor = _selectedCustomer == null
        ? Colors.green
        : _isCustomerExceedingLimit(_selectedCustomer!)
        ? Colors.red
        : Colors.blue;
    final searchBorderRadius = hasAttachedDetails
        ? BorderRadius.vertical(top: Radius.circular(10.r))
        : BorderRadius.circular(8);

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'العميل',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          CompositedTransformTarget(
            link: _customerLayerLink,
            child: Container(
              key: _customerFieldKey,
              child: TextFormField(
                controller: _customerSearchController,
                decoration: InputDecoration(
                  hintText:
                      'ابحث عن العميل بالاسم أو رقم الهاتف... (اتركه فارغاً للعميل النقدي)',
                  filled: hasAttachedDetails,
                  fillColor: detailsColor.withValues(alpha: 0.1),
                  prefixIcon: const Icon(
                    Icons.person,
                    color: AssyrianTheme.primaryGold,
                  ),
                  suffixIcon: _customerSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _customerSearchController.clear();
                              _filteredCustomers = List.from(_customers);
                              _selectedCustomer = null;
                              _hideCustomerSuggestionsOverlay();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: searchBorderRadius,
                    borderSide: BorderSide(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: hasAttachedDetails
                      ? OutlineInputBorder(
                          borderRadius: searchBorderRadius,
                          borderSide: BorderSide(color: detailsColor),
                        )
                      : null,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: searchBorderRadius,
                    borderSide: BorderSide(
                      color: hasAttachedDetails
                          ? detailsColor
                          : AssyrianTheme.primaryGold,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      _filteredCustomers = List.from(_customers);
                      _hideCustomerSuggestionsOverlay();
                      _selectedCustomer = null;
                    } else {
                      _filteredCustomers = _customers
                          .where(
                            (customer) =>
                                customer.name.toLowerCase().contains(
                                  value.toLowerCase(),
                                ) ||
                                customer.phone.toLowerCase().contains(
                                  value.toLowerCase(),
                                ),
                          )
                          .toList();

                      final exactMatch = _filteredCustomers
                          .where(
                            (c) =>
                                c.name.toLowerCase() == value.toLowerCase() ||
                                c.phone.toLowerCase() == value.toLowerCase(),
                          )
                          .firstOrNull;

                      if (exactMatch != null) {
                        setState(() {
                          _selectedCustomer = exactMatch;
                          _hideCustomerSuggestionsOverlay();

                          // جلب المواد المباعة للعميل إذا كانت فاتورة مرجع بيع
                          if (_selectedType == 'sales_return') {
                            _loadSoldItemsForCustomer(exactMatch.id);
                          }
                        });
                      } else {
                        setState(() {
                          _selectedCustomer = null;
                          // عند إلغاء تحديد العميل في وضع مرجع البيع، تحميل جميع المواد
                          if (_selectedType == 'sales_return') {
                            _loadAllSoldItems();
                          }
                        });
                      }

                      // عرض الاقتراحات
                      if (_filteredCustomers.isNotEmpty) {
                        _showCustomerSuggestionsOverlay();
                      } else {
                        _hideCustomerSuggestionsOverlay();
                      }
                    }
                  });
                },
                onTap: () {
                  if (_customerSearchController.text.isNotEmpty &&
                      _filteredCustomers.isNotEmpty) {
                    _showCustomerSuggestionsOverlay();
                  }
                },
              ),
            ),
          ),

          // إظهار معلومات العميل المحدد أو العميل النقدي
          if (_selectedCustomer != null) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: detailsColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(10.r),
                ),
                border: Border(
                  left: BorderSide(color: detailsColor),
                  right: BorderSide(color: detailsColor),
                  bottom: BorderSide(color: detailsColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isCustomerExceedingLimit(_selectedCustomer!)
                            ? Icons.warning_amber_rounded
                            : Icons.person,
                        color: _isCustomerExceedingLimit(_selectedCustomer!)
                            ? Colors.red
                            : Colors.blue,
                        size: 16.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'معلومات العميل',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: _isCustomerExceedingLimit(_selectedCustomer!)
                              ? Colors.red
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'الاسم: ${_selectedCustomer!.name}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: _isCustomerExceedingLimit(_selectedCustomer!)
                          ? Colors.red[700]
                          : Colors.grey[700],
                    ),
                  ),
                  Text(
                    'الهاتف: ${_selectedCustomer!.phone}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: _isCustomerExceedingLimit(_selectedCustomer!)
                          ? Colors.red[700]
                          : Colors.grey[700],
                    ),
                  ),
                  Text(
                    'الحساب: ${_formatDebtDisplay(_selectedCustomer!.totalDebt)}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: _isCustomerExceedingLimit(_selectedCustomer!)
                          ? Colors.red[700]
                          : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_customerSearchController.text.isEmpty) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: detailsColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(10.r),
                ),
                border: Border(
                  left: BorderSide(color: detailsColor),
                  right: BorderSide(color: detailsColor),
                  bottom: BorderSide(color: detailsColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments, color: Colors.green, size: 16.sp),
                      SizedBox(width: 6.w),
                      Text(
                        'عميل نقدي',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'سيتم إنشاء الفاتورة كعميل نقدي (بدون ربط بعميل محدد)',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                  ),
                  Text(
                    'نوع الدفع: نقدي فوري',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
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

  Widget _buildManualReturnEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _showManualReturnForm = !_showManualReturnForm),
          icon: const Icon(Icons.playlist_add),
          label: const Text('إضافة مادة غير موجودة في الفواتير'),
        ),
        if (_showManualReturnForm) ...[
          SizedBox(height: 8.h),
          TextFormField(
            controller: _manualReturnNameController,
            decoration: const InputDecoration(labelText: 'اسم المادة *'),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _manualReturnQuantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    _formattingService.getQuantityInputFormatter(),
                  ],
                  decoration: const InputDecoration(labelText: 'الكمية *'),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: TextFormField(
                  controller: _manualReturnPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    _formattingService.getPriceInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'سعر الاسترداد للوحدة *',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addManualReturnItem,
              icon: const Icon(Icons.add),
              label: const Text('إضافة إلى المرتجع'),
            ),
          ),
          Text(
            'يُربط العنصر بالمخزون فقط عند وجود منتج نشط واحد مطابق للاسم.',
            style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
          ),
        ],
      ],
    );
  }

  Widget _buildProductSearchField() {
    // لفاتورة مرجع البيع - البحث في المواد المباعة
    if (_selectedType == 'sales_return') {
      return _buildSoldItemsSearchField();
    }

    // للفواتير العادية - البحث في المخزون
    return _buildNormalProductSearchField();
  }

  Widget _buildSoldItemsSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'ابحث عن المواد المشتراة سابقاً',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.orange[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoadingSoldItems) ...[
          SizedBox(height: 12.h),
          const Center(child: CircularProgressIndicator()),
        ] else if (_soldItems.isEmpty) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لا توجد مواد مشتراة',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'لا توجد مواد مشتراة سابقاً لهذا العميل. يمكنك إنشاء فواتير مبيعات أولاً.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 12.h),
        TextFormField(
          controller: _productSearchController,
          decoration: InputDecoration(
            labelText: 'البحث عن مادة مشتراة',
            hintText: 'اكتب اسم المادة...',
            prefixIcon: const Icon(
              Icons.history,
              color: AssyrianTheme.primaryGold,
            ),
            suffixIcon: _productSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _productSearchController.clear();
                        _filteredSoldItems = List.from(_soldItems);
                        _selectedProduct = null;
                        _showSoldItemsSuggestions = false;
                        _quantityController.clear();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AssyrianTheme.primaryGold,
                width: 2,
              ),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _selectedSoldItem = null;
              if (value.isEmpty) {
                _filteredSoldItems = List.from(_soldItems);
                _showSoldItemsSuggestions = false;
                _selectedProduct = null;
                _quantityController.clear();
              } else {
                _filteredSoldItems = _soldItems
                    .where(
                      (item) =>
                          item.productName.toLowerCase().contains(
                            value.toLowerCase(),
                          ) ||
                          (item.originalInvoiceNumber?.toLowerCase().contains(
                                value.toLowerCase(),
                              ) ??
                              false),
                    )
                    .toList();
                _showSoldItemsSuggestions = _filteredSoldItems.isNotEmpty;

                final exactMatches = _filteredSoldItems
                    .where(
                      (i) =>
                          i.productName.toLowerCase() == value.toLowerCase() ||
                          (i.originalInvoiceNumber?.toLowerCase() ==
                              value.toLowerCase()),
                    )
                    .toList();

                // لا نختار فاتورة تلقائيًا إذا تكرر الاسم؛ قد يكون المنتج
                // نفسه موجودًا في فواتير بيع متعددة، ويجب أن يختار المستخدم
                // السطر الذي يعرض رقم الفاتورة وتاريخ البيع الصحيحين.
                final repeatedItem = _invoiceItems.any(
                  (item) =>
                      item.productName.trim().toLowerCase() ==
                          value.trim().toLowerCase() &&
                      (item.itemId?.startsWith('manual_return_') == true ||
                          _soldItems.any(
                            (sold) =>
                                sold.productName == item.productName &&
                                sold.originalInvoiceId ==
                                    item.originalInvoiceId,
                          )),
                );

                if (exactMatches.length == 1 &&
                    !repeatedItem &&
                    _editingItemIndex == null) {
                  final exactMatch = exactMatches.single;
                  setState(() {
                    _selectedSoldItem = exactMatch;
                    _selectedProduct = ProductEntity(
                      id: exactMatch.productId ?? exactMatch.productName,
                      organizationEmail: '',
                      name: exactMatch.productName,
                      quantity: exactMatch.quantity,
                      unit: exactMatch.unit,
                      sellingPrice: exactMatch.unitPrice,
                      minQuantity: 0,
                      createdBy: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    _quantityController.text = '1'; // الكمية الافتراضية 1
                    _showSoldItemsSuggestions = false;
                  });
                } else {
                  setState(() {
                    _selectedSoldItem = null;
                    _selectedProduct = null;
                  });
                }
              }
            });
          },
          onTap: () {
            _startProductSearch();
            setState(() {
              _showSoldItemsSuggestions =
                  _productSearchController.text.isNotEmpty &&
                  _filteredSoldItems.isNotEmpty;
            });
          },
        ),

        // قائمة المقترحات للمواد المباعة
        if (_showSoldItemsSuggestions && _filteredSoldItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredSoldItems.length > 5
                  ? 5
                  : _filteredSoldItems.length,
              itemBuilder: (context, index) {
                final item = _filteredSoldItems[index];
                final currentInvoiceReturnQuantity = _invoiceItems
                    .where(
                      (line) =>
                          line.itemId == item.itemId &&
                          line.originalInvoiceId == item.originalInvoiceId,
                    )
                    .fold<double>(0, (sum, line) => sum + line.quantity);
                final availableReturnQuantity =
                    (item.quantity - currentInvoiceReturnQuantity).clamp(
                      0.0,
                      double.infinity,
                    );
                return DecoratedBox(
                  decoration: BoxDecoration(
                    border:
                        index <
                            (_filteredSoldItems.length > 5
                                ? 4
                                : _filteredSoldItems.length - 1)
                        ? Border(bottom: BorderSide(color: Colors.grey[200]!))
                        : null,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    tileColor:
                        item.returnedQuantity != null &&
                            item.returnedQuantity! > 0
                        ? Colors.orange.withValues(alpha: 0.05)
                        : null, // ✅ تمييز المواد المرتجعة مسبقاً
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color:
                                  item.returnedQuantity != null &&
                                      item.returnedQuantity! > 0
                                  ? Colors.orange[700]
                                  : AssyrianTheme.deepBlue,
                            ),
                          ),
                        ),
                        // ✅ أيقونة تمييز المواد المرتجعة مسبقاً
                        if (item.returnedQuantity != null &&
                            item.returnedQuantity! > 0)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 12.sp,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'تم إرجاع ${item.returnedQuantity}',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 14.sp,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              _formattingService.formatCurrency(item.unitPrice),
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              size: 14.sp,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ عرض الكمية المشتراة والمرجعة
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.grey[700],
                                      ),
                                      children: [
                                        TextSpan(text: 'الكمية المشتراة: '),
                                        TextSpan(
                                          text:
                                              '${(item.originalQuantity ?? item.quantity).toStringAsFixed(2)} ${item.unit} ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AssyrianTheme.deepBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ✅ عرض الكمية المرتجعة إن وجدت
                                  if (item.returnedQuantity != null &&
                                      item.returnedQuantity! > 0)
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: Colors.grey[600],
                                        ),
                                        children: [
                                          TextSpan(text: '(تم إرجاع '),
                                          TextSpan(
                                            text:
                                                '${item.returnedQuantity} ${item.unit} ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                          TextSpan(text: '، المتبقي '),
                                          TextSpan(
                                            text:
                                                '${item.quantity.toStringAsFixed(2)} ${item.unit}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                          TextSpan(text: ')'),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 14.sp,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                'فاتورة: ${item.originalInvoiceNumber ?? 'غير متوفر'}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14.sp,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'تاريخ البيع: ${_formattingService.formatDate(item.originalSaleDate ?? DateTime.now())}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: availableReturnQuantity <= 0
                        ? null
                        : () {
                            setState(() {
                              _selectedSoldItem = item;
                              _selectedProduct = ProductEntity(
                                id:
                                    item.itemId ??
                                    item.productName, // استخدام itemId إن وجد
                                organizationEmail: '',
                                name: item.productName,
                                quantity: item.quantity,
                                unit: item.unit,
                                sellingPrice: item.unitPrice,
                                minQuantity: 0,
                                createdBy: '',
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                                description:
                                    'REF:${item.originalInvoiceNumber ?? ''}', // حفظ رقم الفاتورة في الوصف
                              );
                              _productSearchController.text = item.productName;
                              _quantityController.text = availableReturnQuantity
                                  .toString();
                              _showSoldItemsSuggestions = false;
                            });
                          },
                  ),
                );
              },
            ),
          ),
        ],

        // حقل الكمية وزر الإضافة
        if (_selectedProduct != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'الكمية المرتجعة',
                    hintText: '1',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AssyrianTheme.primaryGold,
                        width: 2,
                      ),
                    ),
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      final quantity = double.tryParse(value);
                      if (quantity != null && quantity > 0) {
                        // القيمة صحيحة
                      }
                    }
                  },
                ),
              ),
              SizedBox(width: 12.w),
              ElevatedButton(
                onPressed:
                    _selectedProduct != null &&
                        _quantityController.text.isNotEmpty
                    ? _addProductToInvoice
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                ),
                child: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNormalProductSearchField() {
    final hasAttachedDetails =
        _selectedProduct != null &&
        _selectedType != 'cash' &&
        _editingItemIndex == null;
    final productDetailsColor =
        _selectedProduct == null || _editingItemIndex != null
        ? AssyrianTheme.primaryGold
        : _selectedProduct!.id.startsWith('temp_')
        ? Colors.blue
        : _selectedProduct!.isOutOfStock
        ? Colors.red
        : _selectedProduct!.isLowStock
        ? Colors.orange
        : Colors.blue;
    final searchBorderRadius = hasAttachedDetails
        ? BorderRadius.vertical(top: Radius.circular(10.r))
        : BorderRadius.circular(8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: CompositedTransformTarget(
                link: _productLayerLink,
                child: Container(
                  key: _productFieldKey,
                  child: TextFormField(
                    controller: _productSearchController,
                    decoration: InputDecoration(
                      labelText: 'البحث عن منتج',
                      hintText: 'ابحث عن المنتج بالاسم أو الباركود...',
                      filled: hasAttachedDetails,
                      fillColor: productDetailsColor.withValues(alpha: 0.1),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AssyrianTheme.primaryGold,
                      ),
                      suffixIcon: _productSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _productSearchController.clear();
                                  _filteredProducts = List.from(_products);
                                  _selectedProduct = null;
                                  _quantityController.clear();
                                  if (_editingItemIndex != null) {
                                    _editingItemIndex = null;
                                    _editItemNameController.clear();
                                    _itemPriceController.clear();
                                  }
                                  SuggestionsOverlay.hide();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: searchBorderRadius,
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      enabledBorder: hasAttachedDetails
                          ? OutlineInputBorder(
                              borderRadius: searchBorderRadius,
                              borderSide: BorderSide(
                                color: productDetailsColor,
                              ),
                            )
                          : null,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: searchBorderRadius,
                        borderSide: BorderSide(
                          color: hasAttachedDetails
                              ? productDetailsColor
                              : AssyrianTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value.isEmpty) {
                          _filteredProducts = List.from(_products);
                          _selectedProduct = null;
                          SuggestionsOverlay.hide();
                        } else {
                          _filteredProducts = _products
                              .where(
                                (product) =>
                                    product.name.toLowerCase().contains(
                                      value.toLowerCase(),
                                    ) ||
                                    (product.barcode?.toLowerCase().contains(
                                          value.toLowerCase(),
                                        ) ??
                                        false),
                              )
                              .toList();

                          // التحقق من وجود تطابق تام
                          final exactMatch = _filteredProducts.firstWhereOrNull(
                            (p) =>
                                p.name.toLowerCase() == value.toLowerCase() ||
                                p.barcode?.toLowerCase() == value.toLowerCase(),
                          );

                          // إذا لم يكن هناك تطابق تام، ننشئ منتج مؤقت
                          if (exactMatch == null) {
                            // أثناء تعديل عنصر موجود، لا نستبدل العنصر بمنتج مؤقت
                            // لمجرد تغيير اسمه.
                            if (_editingItemIndex != null) {
                              final editingItem =
                                  _invoiceItems[_editingItemIndex!];
                              _selectedProduct = ProductEntity(
                                id: 'edit_${_editingItemIndex!}',
                                name: value.trim(),
                                unit: editingItem.unit,
                                quantity: 0,
                                minQuantity: 0,
                                costPrice: editingItem.purchasePrice,
                                sellingPrice: editingItem.unitPrice,
                                organizationEmail: '',
                                createdAt: DateTime.now(),
                                createdBy: '',
                              );
                            } else {
                              // إنشاء منتج مؤقت
                              setState(() {
                                _selectedProduct = ProductEntity(
                                  id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                                  name: _productSearchController.text.trim(),
                                  description:
                                      'منتج جديد - غير موجود في المخزون',
                                  unit: 'قطعة',
                                  quantity: 0,
                                  minQuantity: 10,
                                  costPrice: 0,
                                  sellingPrice: 0,
                                  organizationEmail:
                                      FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.email ??
                                      '',
                                  createdAt: DateTime.now(),
                                  createdBy:
                                      FirebaseAuth.instance.currentUser?.uid ??
                                      'unknown',
                                );
                                _quantityController.text = '1';
                                _newProductQuantityController.text = '1';
                                SuggestionsOverlay.hide();
                                _scrollProductDetailsIntoView();
                              });
                            }
                          } else {
                            final exactMatch = _filteredProducts
                                .where(
                                  (p) =>
                                      p.name.toLowerCase() ==
                                          value.toLowerCase() ||
                                      p.barcode?.toLowerCase() ==
                                          value.toLowerCase(),
                                )
                                .firstOrNull;

                            if (exactMatch != null) {
                              setState(() {
                                _selectedProduct = exactMatch;
                                if (_selectedType == 'sales_return') {
                                  _selectedSoldItem = null;
                                }
                                if (_editingItemIndex == null) {
                                  _quantityController.text = '1';
                                  _newProductQuantityController.text = '1';
                                }
                                SuggestionsOverlay.hide();
                                _scrollProductDetailsIntoView();
                              });
                            } else {
                              setState(() {
                                _selectedProduct = null;
                              });
                            }
                          }
                        }

                        // عرض الاقتراحات
                        if (_filteredProducts.isNotEmpty) {
                          _showProductSuggestionsOverlay();
                        } else {
                          SuggestionsOverlay.hide();
                        }
                        _scrollProductDetailsIntoView();
                      });
                    },
                    onTap: () {
                      _startProductSearch();
                      if (_productSearchController.text.isNotEmpty &&
                          _filteredProducts.isNotEmpty) {
                        _showProductSuggestionsOverlay();
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),

        // إظهار معلومات المنتج المحدد عند الإضافة فقط؛ حقول التعديل موجودة ضمن العنصر.
        if (_selectedProduct != null &&
            _selectedType != 'cash' &&
            _editingItemIndex == null) ...[
          if (_editingItemIndex != null) SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: productDetailsColor.withValues(
                alpha: _editingItemIndex != null ? 0.08 : 0.1,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(10.r),
              ),
              border: Border(
                top: _editingItemIndex != null
                    ? BorderSide(
                        color: productDetailsColor.withValues(alpha: 0.5),
                      )
                    : BorderSide.none,
                left: BorderSide(
                  color: _editingItemIndex != null
                      ? productDetailsColor.withValues(alpha: 0.5)
                      : productDetailsColor,
                ),
                right: BorderSide(
                  color: _editingItemIndex != null
                      ? productDetailsColor.withValues(alpha: 0.5)
                      : productDetailsColor,
                ),
                bottom: BorderSide(
                  color: _editingItemIndex != null
                      ? productDetailsColor.withValues(alpha: 0.5)
                      : productDetailsColor,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _selectedProduct!.id.startsWith('temp_')
                          ? Icons.add_circle
                          : _selectedProduct!.isOutOfStock
                          ? Icons.warning
                          : _selectedProduct!.isLowStock
                          ? Icons.info
                          : Icons.check_circle,
                      color: _selectedProduct!.id.startsWith('temp_')
                          ? Colors.blue
                          : _selectedProduct!.isOutOfStock
                          ? Colors.red
                          : _selectedProduct!.isLowStock
                          ? Colors.orange
                          : Colors.green,
                      size: 16.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      _selectedProduct!.id.startsWith('temp_')
                          ? 'منتج جديد (غير موجود في المخزون)'
                          : 'معلومات المنتج',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (_editingItemIndex != null)
                      Expanded(
                        child: TextFormField(
                          controller: _itemPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            _formattingService.getPriceInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'سعر الوحدة',
                            isDense: true,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          'السعر: ${_formattingService.formatProductPrice(_selectedProduct!.sellingPrice)}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color:
                                _selectedProduct!.isOutOfStock ||
                                    _selectedProduct!.isLowStock
                                ? Colors.red
                                : Colors.blueGrey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: _buildQuantityInput(
                        controller: _quantityController,
                        onChanged: (value) {
                          setState(() {
                            if (_selectedProduct != null) {
                              final newQuantity = double.tryParse(value) ?? 1;
                              final existingIndex = _invoiceItems.indexWhere(
                                (item) =>
                                    item.productName == _selectedProduct!.name,
                              );
                              if (existingIndex != -1) {
                                final existingItem =
                                    _invoiceItems[existingIndex];
                                _invoiceItems[existingIndex] =
                                    InvoiceItemEntity(
                                      productName: existingItem.productName,
                                      quantity: newQuantity,
                                      unit: existingItem.unit,
                                      unitPrice: existingItem.unitPrice,
                                      totalPrice:
                                          newQuantity * existingItem.unitPrice,
                                      itemId: existingItem.itemId,
                                      originalInvoiceId:
                                          existingItem.originalInvoiceId,
                                      originalInvoiceNumber:
                                          existingItem.originalInvoiceNumber,
                                      originalSaleDate:
                                          existingItem.originalSaleDate,
                                      isReturned: existingItem.isReturned,
                                      returnedQuantity:
                                          existingItem.returnedQuantity,
                                      originalQuantity:
                                          existingItem.originalQuantity,
                                      purchasePrice: existingItem.purchasePrice,
                                      sellingPrice: existingItem.sellingPrice,
                                    );
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (_selectedProduct!.shelfId != null &&
                        _selectedProduct!.shelfId!.isNotEmpty)
                      Expanded(
                        child: Text(
                          'الرف: ${_getShelfName(_selectedProduct!.shelfId!)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _selectedProduct!.isOutOfStock
                                ? Colors.red
                                : _selectedProduct!.isLowStock
                                ? Colors.orange
                                : const Color(0xFF0D47A1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                    SizedBox(width: 4.w),
                    if (!_selectedProduct!.id.startsWith('temp_'))
                      Expanded(
                        child: Text(
                          'الكمية المتاحة: ${_selectedProduct!.quantity.toInt()} ${_selectedProduct!.unit}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: _selectedProduct!.isOutOfStock
                                ? Colors.red
                                : _selectedProduct!.isLowStock
                                ? Colors.orange
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
                if (_selectedProduct!.isOutOfStock)
                  Text(
                    'تحذير: هذا المنتج نافذ من المخزون',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (_selectedProduct!.isLowStock)
                  Text(
                    'تنبيه: كمية هذا المنتج قليلة في المخزون',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                // إظهار حقول الأسعار للمنتج الجديد
                if (_selectedProduct!.id.startsWith('temp_')) ...[
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    'أسعار المنتج الجديد',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // حقول سعر الشراء والبيع (متجاورة)
                  Row(
                    children: [
                      if (_selectedType == 'purchase')
                        Expanded(
                          child: Focus(
                            onFocusChange: (hasFocus) {
                              // عند التركيز على الحقل، يمسح السعر
                              if (hasFocus &&
                                  _newProductPurchasePriceController
                                      .text
                                      .isNotEmpty) {
                                setState(() {
                                  _newProductPurchasePriceController.text = '';
                                });
                              }
                              // عند فقدان التركيز، إذا كان الحقل فارغاً يعود 0
                              if (!hasFocus &&
                                  _newProductPurchasePriceController
                                      .text
                                      .isEmpty) {
                                setState(() {
                                  _newProductPurchasePriceController.text = '0';
                                });
                              }
                            },
                            child: TextFormField(
                              controller: _newProductPurchasePriceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                _formattingService.getPriceInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: 'سعر الشراء *',
                                hintText: '0.00',
                                prefixIcon: Icon(
                                  Icons.shopping_basket,
                                  color: AssyrianTheme.primaryGold.withValues(
                                    alpha: 1,
                                  ),
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AssyrianTheme.primaryGold.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AssyrianTheme.primaryGold,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: Focus(
                            onFocusChange: (hasFocus) {
                              // عند التركيز على الحقل، يمسح السعر
                              if (hasFocus &&
                                  _newProductSellingPriceController
                                      .text
                                      .isNotEmpty) {
                                setState(() {
                                  _newProductSellingPriceController.text = '';
                                });
                              }
                              // عند فقدان التركيز، إذا كان الحقل فارغاً يعود 0
                              if (!hasFocus &&
                                  _newProductSellingPriceController
                                      .text
                                      .isEmpty) {
                                setState(() {
                                  _newProductSellingPriceController.text = '0';
                                });
                              }
                            },
                            child: TextFormField(
                              controller: _newProductSellingPriceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                _formattingService.getPriceInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: 'سعر البيع *',
                                hintText: '0.00',
                                prefixIcon: Icon(
                                  Icons.sell,
                                  color: AssyrianTheme.primaryGold.withValues(
                                    alpha: 1,
                                  ),
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AssyrianTheme.primaryGold.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AssyrianTheme.primaryGold,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 8.h,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_selectedType == 'purchase')
                        Expanded(
                          child: TextFormField(
                            controller: _newProductSellingPriceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              _formattingService.getPriceInputFormatter(),
                            ],
                            decoration: InputDecoration(
                              labelText: 'سعر البيع *',
                              hintText: '0.00',
                              prefixIcon: Icon(
                                Icons.sell,
                                color: AssyrianTheme.primaryGold.withValues(
                                  alpha: 1,
                                ),
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AssyrianTheme.primaryGold.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AssyrianTheme.primaryGold,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else
                // إظهار حقول الأسعار بناءً على نوع الفاتورة
                if (_selectedType == 'purchase') ...[
                  // لفواتير الشراء: إظهار سعر الشراء وسعر البيع
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    'أسعار الشراء والبيع',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // حقول سعر الشراء والبيع (متجاورة)
                  Row(
                    children: [
                      Expanded(
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            // عند التركيز على الحقل، يمسح السعر
                            if (hasFocus &&
                                _defaultPurchasePrice > 0 &&
                                _purchasePriceController.text.isNotEmpty) {
                              setState(() {
                                _purchasePriceController.text = '';
                              });
                            }
                            // عند فقدان التركيز، إذا كان الحقل فارغاً يعود السعر الافتراضي
                            if (!hasFocus &&
                                _defaultPurchasePrice > 0 &&
                                _purchasePriceController.text.isEmpty) {
                              setState(() {
                                _purchasePriceController.text =
                                    _formattingService.formatProductPrice(
                                      _defaultPurchasePrice,
                                    );
                              });
                            }
                          },
                          child: TextFormField(
                            controller: _purchasePriceController,
                            decoration: InputDecoration(
                              labelText: 'سعر الشراء',
                              hintText: _defaultPurchasePrice > 0
                                  ? _formattingService.formatProductPrice(
                                      _defaultPurchasePrice,
                                    )
                                  : '0.00',
                              prefixIcon: Icon(
                                Icons.shopping_basket,
                                color: AssyrianTheme.primaryGold.withValues(
                                  alpha: 1,
                                ),
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AssyrianTheme.primaryGold.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AssyrianTheme.primaryGold,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              _formattingService.getPriceInputFormatter(),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            // عند التركيز على الحقل، يمسح السعر
                            if (hasFocus &&
                                _defaultSellingPrice > 0 &&
                                _sellingPriceController.text.isNotEmpty) {
                              setState(() {
                                _sellingPriceController.text = '';
                              });
                            }
                            // عند فقدان التركيز، إذا كان الحقل فارغاً يعود السعر الافتراضي
                            if (!hasFocus &&
                                _defaultSellingPrice > 0 &&
                                _sellingPriceController.text.isEmpty) {
                              setState(() {
                                _sellingPriceController.text =
                                    _formattingService.formatProductPrice(
                                      _defaultSellingPrice,
                                    );
                              });
                            }
                          },
                          child: TextFormField(
                            controller: _sellingPriceController,
                            decoration: InputDecoration(
                              labelText: 'سعر البيع',
                              hintText: _defaultSellingPrice > 0
                                  ? _formattingService.formatProductPrice(
                                      _defaultSellingPrice,
                                    )
                                  : '0.00',
                              prefixIcon: Icon(
                                Icons.sell,
                                color: AssyrianTheme.primaryGold.withValues(
                                  alpha: 1,
                                ),
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AssyrianTheme.primaryGold.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AssyrianTheme.primaryGold,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              _formattingService.getPriceInputFormatter(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_selectedType == 'sales' ||
                    _selectedType == 'cash') ...[
                  // لفواتير المبيعات والنقدية: إظهار سعر البيع فقط
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    'سعر البيع',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // حقل سعر البيع فقط (بنفس أسلوب حقل الكمية)
                  Focus(
                    onFocusChange: (hasFocus) {
                      // عند التركيز على الحقل، يمسح السعر
                      if (hasFocus &&
                          _defaultSellingPrice > 0 &&
                          _sellingPriceController.text.isNotEmpty) {
                        setState(() {
                          _sellingPriceController.text = '';
                        });
                      }
                      // عند فقدان التركيز، إذا كان الحقل فارغاً يعود السعر الافتراضي
                      if (!hasFocus &&
                          _defaultSellingPrice > 0 &&
                          _sellingPriceController.text.isEmpty) {
                        setState(() {
                          _sellingPriceController.text = _formattingService
                              .formatProductPrice(_defaultSellingPrice);
                        });
                      }
                    },
                    child: TextFormField(
                      controller: _sellingPriceController,
                      decoration: InputDecoration(
                        labelText: 'سعر البيع',
                        hintText: _defaultSellingPrice > 0
                            ? _formattingService.formatProductPrice(
                                _defaultSellingPrice,
                              )
                            : '0.00',
                        prefixIcon: Icon(
                          Icons.sell,
                          color: AssyrianTheme.primaryGold.withValues(alpha: 1),
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: AssyrianTheme.primaryGold.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AssyrianTheme.primaryGold,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _formattingService.getPriceInputFormatter(),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: _editingItemIndex != null ? 0 : 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedProduct != null
                        ? _addProductToInvoice
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AssyrianTheme.primaryGold,
                      foregroundColor: AssyrianTheme.deepBlue,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _editingItemIndex == null ? Icons.add : Icons.save,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          _editingItemIndex == null
                              ? 'إضافة للفاتورة'
                              : 'تحديث العنصر',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemEditFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _editItemNameController,
          decoration: const InputDecoration(
            labelText: 'اسم العنصر',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          onChanged: (value) {
            final index = _editingItemIndex;
            if (index == null || index >= _invoiceItems.length) return;
            final original = _invoiceItems[index];
            setState(() {
              _selectedProduct = ProductEntity(
                id: 'edit_$index',
                organizationEmail: '',
                name: value,
                quantity: 0,
                unit: original.unit,
                sellingPrice: original.unitPrice,
                minQuantity: 0,
                costPrice: original.purchasePrice,
                createdBy: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
            });
          },
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_formattingService.getPriceInputFormatter()],
                decoration: const InputDecoration(labelText: 'الكمية'),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: TextFormField(
                controller: _itemPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_formattingService.getPriceInputFormatter()],
                decoration: InputDecoration(
                  labelText: _selectedType == 'purchase'
                      ? 'سعر الشراء'
                      : 'سعر الوحدة',
                ),
              ),
            ),
          ],
        ),
        if (_selectedType == 'purchase') ...[
          SizedBox(height: 8.h),
          TextFormField(
            controller: _sellingPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_formattingService.getPriceInputFormatter()],
            decoration: const InputDecoration(labelText: 'سعر البيع'),
          ),
        ],
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _selectedProduct == null ? null : _addProductToInvoice,
            icon: const Icon(Icons.save_outlined),
            label: const Text('تحديث العنصر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    // بناء قائمة العناصر بناءً على الصلاحيات
    final items = <DropdownMenuItem<String>>[];

    if (_canCreateSales) {
      items.add(
        const DropdownMenuItem(value: 'sales', child: Text('فاتورة مبيعات')),
      );
    }
    if (_canCreatePurchase) {
      items.add(
        const DropdownMenuItem(
          value: 'purchase',
          child: Text('فاتورة مشتريات'),
        ),
      );
    }
    if (_canCreateCash) {
      items.add(
        const DropdownMenuItem(value: 'cash', child: Text('فاتورة نقدية')),
      );
    }
    if (_canCreateSubscription) {
      items.add(
        const DropdownMenuItem(
          value: 'subscription',
          child: Text('فاتورة اشتراك'),
        ),
      );
    }
    if (_canCreateSalesReturn) {
      items.add(
        const DropdownMenuItem(
          value: 'sales_return',
          child: Text('فاتورة مرجع بيع'),
        ),
      );
    }

    // إذا لم يكن لدى المستخدم أي صلاحية، نضيف مبيعات كافتراضي
    if (items.isEmpty) {
      items.add(
        const DropdownMenuItem(value: 'sales', child: Text('فاتورة مبيعات')),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _selectedType,
        decoration: InputDecoration(
          labelText: 'نوع الفاتورة',
          hintText: 'اختر نوع الفاتورة',
          prefixIcon: const Icon(
            Icons.receipt,
            color: AssyrianTheme.primaryGold,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AssyrianTheme.primaryGold,
              width: 2,
            ),
          ),
        ),
        items: items,
        onChanged: (value) {
          setState(() {
            _selectedType = value!;

            // عند اختيار فاتورة مرجع بيع، تحميل المواد المشتراة
            if (_selectedType == 'sales_return') {
              if (_selectedCustomer != null) {
                // تحميل مواد العميل المحدد
                _loadSoldItemsForCustomer(_selectedCustomer!.id);
              } else {
                // تحميل جميع المواد من جميع الفواتير
                _loadAllSoldItems();
              }
            } else if (_selectedType != 'sales_return') {
              // تفريغ قائمة المواد المشتراة عند الخروج من وضع المرجع
              setState(() {
                _soldItems = [];
                _filteredSoldItems = [];
                _productSearchController.clear();
                _selectedProduct = null;
              });
            }
          });
        },
      ),
    );
  }

  Widget _buildInvoiceItemsList() {
    return Column(
      children: [
        ...List.generate(_invoiceItems.length, (index) {
          final item = _invoiceItems[index];
          if (_invoiceItemKeys.length <= index) {
            _invoiceItemKeys.addAll(
              List.generate(
                index + 1 - _invoiceItemKeys.length,
                (_) => GlobalKey(),
              ),
            );
          }
          return Column(
            key: _invoiceItemKeys[index],
            children: [
              Container(
                margin: EdgeInsets.only(
                  bottom: _editingItemIndex == index ? 0 : 8,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _editingItemIndex == index
                      ? AssyrianTheme.primaryGold.withValues(alpha: 0.08)
                      : Colors.grey[50],
                  borderRadius: _editingItemIndex == index
                      ? BorderRadius.vertical(top: Radius.circular(10.r))
                      : BorderRadius.circular(8),
                  border: Border.all(
                    color: _editingItemIndex == index
                        ? AssyrianTheme.primaryGold.withValues(alpha: 0.5)
                        : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AssyrianTheme.deepBlue,
                            ),
                          ),
                          // إظهار تسمية للمنتجات المؤقتة
                          if (item.productName.startsWith('temp_') ||
                              _products.any(
                                (p) =>
                                    p.id.startsWith('temp_') &&
                                    p.name == item.productName,
                              )) ...[
                            SizedBox(height: 4.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: Colors.blue),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_circle,
                                    size: 12.sp,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'منتج جديد',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // إظهار حالة المخزون للمنتج
                          Builder(
                            builder: (context) {
                              final product = _products
                                  .where((p) => p.name == item.productName)
                                  .firstOrNull;
                              // ✅ إظهار التحذير فقط في فواتير البيع والنقدية
                              final isSalesType =
                                  _selectedType == 'sales' ||
                                  _selectedType == 'cash' ||
                                  _selectedType == 'subscription';
                              if (product != null &&
                                  isSalesType &&
                                  (product.isOutOfStock ||
                                      item.quantity > product.quantity)) {
                                return Container(
                                  margin: EdgeInsets.only(top: 4.h),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        size: 12.sp,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        product.isOutOfStock
                                            ? 'نافذ من المخزون'
                                            : 'كمية أكبر من المتاح',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_editingItemIndex == index)
                      Expanded(
                        child: Text(
                          '${item.quantity} ${item.unit}',
                          style: TextStyle(fontSize: 12.sp),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    // عرض سعر الشراء والبيع لفواتير الشراء
                    if (_selectedType == 'purchase' &&
                        (item.purchasePrice != null ||
                            item.sellingPrice != null)) ...[
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.purchasePrice != null)
                              Text(
                                'شراء: ${_formattingService.formatProductPrice(item.purchasePrice!)}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (item.sellingPrice != null)
                              Text(
                                'بيع: ${_formattingService.formatProductPrice(item.sellingPrice!)}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Text(
                          _formattingService.formatProductPrice(item.unitPrice),
                          style: TextStyle(fontSize: 12.sp),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        _formattingService.formatCurrency(item.totalPrice),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AssyrianTheme.primaryGold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 40.w,
                      child: IconButton(
                        tooltip: 'تعديل العنصر',
                        onPressed: () => _editItem(index),
                        icon: Icon(
                          Icons.edit_outlined,
                          color: AssyrianTheme.primaryGold,
                          size: 20.sp,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40.w,
                      child: IconButton(
                        tooltip: 'حذف العنصر',
                        onPressed: () => _removeItem(index),
                        icon: Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_editingItemIndex == index) ...[
                Container(
                  padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 12.h),
                  decoration: BoxDecoration(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(10.r),
                    ),
                    border: Border(
                      left: BorderSide(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.5),
                      ),
                      right: BorderSide(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.5),
                      ),
                      bottom: BorderSide(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildItemEditFields(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _clearProductSelection,
                          icon: const Icon(Icons.close),
                          label: const Text('إلغاء التعديل'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        }),

        // ملخص حالة المخزون
        if (_invoiceItems.isNotEmpty) ...[
          SizedBox(height: 16.h),
          _buildStockSummary(),
        ],
      ],
    );
  }

  Widget _buildStockSummary() {
    var outOfStockItems = 0;
    var lowStockItems = 0;
    var overQuantityItems = 0;

    // ✅ التحقق من نوع الفاتورة - لا إظهار تحذير في المشتريات
    final isSalesType =
        _selectedType == 'sales' ||
        _selectedType == 'cash' ||
        _selectedType == 'subscription';

    for (final item in _invoiceItems) {
      // تجاهل المنتجات المؤقتة في ملخص المخزون
      if (item.productName.startsWith('temp_') ||
          _products.any(
            (p) => p.id.startsWith('temp_') && p.name == item.productName,
          )) {
        continue;
      }

      final product = _products
          .where((p) => p.name == item.productName)
          .firstOrNull;
      if (product == null) continue;

      if (isSalesType && product.isOutOfStock) {
        outOfStockItems++;
      } else if (isSalesType && product.isLowStock) {
        lowStockItems++;
      }

      if (isSalesType && item.quantity > product.quantity) {
        overQuantityItems++;
      }
    }

    if (outOfStockItems == 0 && lowStockItems == 0 && overQuantityItems == 0) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              'جميع المنتجات متوفرة في المخزون',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'تنبيهات المخزون',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          if (outOfStockItems > 0)
            Text(
              '• $outOfStockItems منتج نافد من المخزون',
              style: TextStyle(fontSize: 12.sp, color: Colors.red),
            ),
          if (lowStockItems > 0)
            Text(
              '• $lowStockItems منتج بكمية قليلة',
              style: TextStyle(fontSize: 12.sp, color: Colors.orange),
            ),
          if (overQuantityItems > 0)
            Text(
              '• $overQuantityItems منتج بكمية أكبر من المتاح',
              style: TextStyle(fontSize: 12.sp, color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'الملاحظات',
        hintText: 'أدخل أي ملاحظات إضافية (اختياري)',
        prefixIcon: const Icon(Icons.note, color: AssyrianTheme.primaryGold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AssyrianTheme.primaryGold,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildPaidAmountField() {
    // إخفاء الحقل عند عدم اختيار عميل أو في الفواتير النقدية والمشتريات
    if (_selectedCustomer == null ||
        _selectedType == 'cash' ||
        _selectedType == 'purchase') {
      return const SizedBox.shrink();
    }
    // إخفاء الحقل لفاتورة مرجع البيع (لأنها مدفوعة بالكامل)
    if (_selectedType == 'sales_return') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'فاتورة مرجع بيع',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  'المبلغ مسترد بالكامل - سيتم خصمه من حساب العميل أو رده نقداً',
                  style: TextStyle(fontSize: 12.sp, color: Colors.orange[900]),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // حساب المجموع النهائي بعد الخصم والضريبة
    final netTotal = (_totalAmount - _currentDiscountAmount + _taxAmount).clamp(
      0.0,
      double.infinity,
    );
    // حساب المتبقي
    final currentPaid = _currentPaidAmount;
    final remainingAmount = (netTotal - currentPaid).clamp(
      0.0,
      double.infinity,
    );
    final hasRemaining = remainingAmount > 0;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AssyrianTheme.primaryGold.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: hasRemaining
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: hasRemaining
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  hasRemaining ? Icons.payment : Icons.check_circle,
                  color: hasRemaining ? Colors.orange : Colors.green,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'المبلغ المدفوع',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _paidAmountController,
                  decoration: InputDecoration(
                    labelText: 'أدخل المبلغ الواصل',
                    hintText: '0.00',
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet,
                      color: AssyrianTheme.primaryGold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AssyrianTheme.primaryGold,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    _formattingService.getPriceInputFormatter(),
                  ],
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final cleanValue =
                          SmartNumberFormatter.convertToEnglishNumbers(
                            value.replaceAll(
                              _formattingService.thousandsSeparator,
                              '',
                            ),
                          );
                      final amount = double.tryParse(cleanValue);
                      if (amount == null || amount < 0) {
                        return 'يرجى إدخال مبلغ صحيح';
                      }
                      if (amount > netTotal && netTotal > 0) {
                        return 'المبلغ المدفوع أكبر من المجموع النهائي';
                      }
                    }
                    return null;
                  },
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _paidAmountController.text = _formattingService
                        .formatNumber(netTotal);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AssyrianTheme.primaryGold,
                  foregroundColor: AssyrianTheme.deepBlue,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 12.h,
                  ),
                  minimumSize: Size(70.w, 46.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 1,
                ),
                icon: Icon(Icons.done_all, size: 16.sp),
                label: Text(
                  'الكامل',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: hasRemaining
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: hasRemaining
                    ? Colors.orange.withValues(alpha: 0.3)
                    : Colors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    hasRemaining ? 'المبلغ المتبقي:' : 'حالة الدفع:',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: hasRemaining
                          ? Colors.orange[900]
                          : Colors.green[900],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hasRemaining
                          ? _formattingService.formatCurrency(remainingAmount)
                          : '✅ مدفوع بالكامل',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: hasRemaining
                            ? Colors.orange[900]
                            : Colors.green[900],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundMethodField() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.replay, color: Colors.orange, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Text(
                'طريقة استرداد المبلغ',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  // ignore: deprecated_member_use
                  leading: Radio<String>(
                    value: 'credit',
                    // ignore: deprecated_member_use
                    groupValue: _refundMethod,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setState(() {
                        _refundMethod = value;
                      });
                    },
                  ),
                  title: Text(
                    'خصم من حساب العميل',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[900],
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      _selectedCustomer != null
                          ? _selectedCustomer!.totalDebt > 0
                                ? 'الحساب الحالي (عليك): ${_formattingService.formatCurrency(_selectedCustomer!.totalDebt)}'
                                : _selectedCustomer!.totalDebt < 0
                                ? 'الحساب الحالي (لك): ${_formattingService.formatCurrency(_selectedCustomer!.totalDebt.abs())}'
                                : 'الحساب الحالي: ${_formattingService.formatCurrency(_selectedCustomer!.totalDebt)}'
                          : 'لا يوجد عميل محدد',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: false,
                  visualDensity: VisualDensity.compact,
                  onTap: () {
                    setState(() {
                      _refundMethod = 'credit';
                    });
                  },
                ),
                SizedBox(height: 8.h),
                ListTile(
                  // ignore: deprecated_member_use
                  leading: Radio<String>(
                    value: 'cash',
                    // ignore: deprecated_member_use
                    groupValue: _refundMethod,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setState(() {
                        _refundMethod = value;
                      });
                    },
                  ),
                  title: Text(
                    'رد نقداً',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[900],
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      'سيتم رد المبلغ نقداً للعميل',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: false,
                  visualDensity: VisualDensity.compact,
                  onTap: () {
                    setState(() {
                      _refundMethod = 'cash';
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashAmountField() {
    return TextFormField(
      controller: _cashAmountController,
      validator: (value) {
        final parsed = double.tryParse(
          SmartNumberFormatter.convertToEnglishNumbers(
            (value ?? '')
                .replaceAll(',', '')
                .replaceAll('،', '')
                .replaceAll(' ', '')
                .replaceAll(_formattingService.thousandsSeparator, '')
                .trim(),
          ),
        );
        if (parsed == null || parsed <= 0) {
          return 'أدخل مبلغاً صحيحاً أكبر من صفر';
        }
        return null;
      },
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_formattingService.getPriceInputFormatter()],
      decoration: const InputDecoration(
        labelText: 'المبلغ النقدي',
        prefixIcon: Icon(Icons.attach_money),
      ),
      onChanged: (value) {
        final normalized = SmartNumberFormatter.convertToEnglishNumbers(
          value
              .replaceAll(',', '')
              .replaceAll('،', '')
              .replaceAll(' ', '')
              .replaceAll(_formattingService.thousandsSeparator, ''),
        );
        _cashAmount = double.tryParse(normalized) ?? 0;
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildCashTransactionTypeField() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => _cashTransactionType = 'receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cashTransactionType == 'receipt'
                  ? Colors.green
                  : Colors.grey[200],
              foregroundColor: _cashTransactionType == 'receipt'
                  ? Colors.white
                  : Colors.grey[700],
            ),
            child: const Text('استلام'),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => _cashTransactionType = 'payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cashTransactionType == 'payment'
                  ? Colors.red
                  : Colors.grey[200],
              foregroundColor: _cashTransactionType == 'payment'
                  ? Colors.white
                  : Colors.grey[700],
            ),
            child: const Text('إعطاء'),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSection() {
    final discount = _currentDiscountAmount;
    final totalAfterDiscount = _totalAmount - discount;
    final totalAfterDiscountAndTax = (totalAfterDiscount + _taxAmount).clamp(
      0.0,
      double.infinity,
    );
    final currentPaid = _currentPaidAmount;
    final remainingAmount = (totalAfterDiscountAndTax - currentPaid).clamp(
      0.0,
      double.infinity,
    );
    final isCustomerSelected = _selectedCustomer != null;
    final showPaymentDetails =
        isCustomerSelected &&
        _selectedType != 'cash' &&
        _selectedType != 'purchase' &&
        _selectedType != 'sales_return';

    return Column(
      children: [
        // إخفاء المجموع الكلي للفاتورة النقدية
        if (_selectedType != 'cash') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'المجموع الكلي:',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                ),
                Text(
                  _formattingService.formatCurrency(_totalAmount),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
              ],
            ),
          ),
        ],

        // إخفاء الخصم والضريبة للفاتورة النقدية
        if (_selectedType != 'cash') ...[
          const SizedBox(height: 12),
          // حقل الخصم
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'الخصم:',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _discountController,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AssyrianTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      prefixIcon: const Icon(
                        Icons.discount,
                        color: AssyrianTheme.primaryGold,
                        size: 20,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      _formattingService.getNumberInputFormatter(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        // تحويل القيمة المنسقة إلى رقم
                        final cleanValue =
                            SmartNumberFormatter.convertToEnglishNumbers(
                              value.replaceAll(
                                _formattingService.thousandsSeparator,
                                '',
                              ),
                            );
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // قسم الضرائب
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الضرائب',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                    IconButton(
                      onPressed: _addTax,
                      icon: const Icon(Icons.add_circle),
                      color: Colors.orange,
                      tooltip: 'إضافة ضريبة',
                    ),
                  ],
                ),
                // عرض قائمة الضرائب
                if (_taxes.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: _taxes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final tax = entry.value;
                        final taxName = tax['name'] as String;
                        final taxRate = tax['rate'] as double;
                        final taxAmountValue = tax['amount'] as double;
                        final isPercentage = tax['isPercentage'] as bool;

                        return ListTile(
                          dense: true,
                          title: Text(
                            taxName,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            isPercentage && taxRate > 0
                                ? '${_formattingService.formatCurrency(taxAmountValue)} (${taxRate.toStringAsFixed(1)}%)'
                                : _formattingService.formatCurrency(
                                    taxAmountValue,
                                  ),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[700],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _taxes.removeAt(index);
                                _calculateTotalTax();
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // عرض إجمالي الضرائب
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'إجمالي الضرائب:',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                        Text(
                          _formattingService.formatCurrency(_taxAmount),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text(
                      'لا توجد ضرائب مضافة',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // مبلغ ونوع إيصال العميل فقط؛ بيع النقد يعتمد على عناصر الفاتورة.
        if (_selectedType == 'cash' && _selectedCustomer != null) ...[
          const SizedBox(height: 12),
          // حقل نوع العملية
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نوع العملية:',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // استلام (موجب)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _cashTransactionType = 'receipt';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cashTransactionType == 'receipt'
                              ? Colors.green
                              : Colors.grey[200],
                          foregroundColor: _cashTransactionType == 'receipt'
                              ? Colors.white
                              : Colors.grey[600],
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            side: BorderSide(
                              color: _cashTransactionType == 'receipt'
                                  ? Colors.green
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_downward, size: 16.sp),
                            SizedBox(width: 4.w),
                            Text(
                              'استلام',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // إعطاء (سالب)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _cashTransactionType = 'payment';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cashTransactionType == 'payment'
                              ? Colors.red
                              : Colors.grey[200],
                          foregroundColor: _cashTransactionType == 'payment'
                              ? Colors.white
                              : Colors.grey[600],
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            side: BorderSide(
                              color: _cashTransactionType == 'payment'
                                  ? Colors.red
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward, size: 16.sp),
                            SizedBox(width: 6.w),
                            Text(
                              'إعطاء للعميل',
                              style: TextStyle(
                                fontSize: 14.sp,
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
          const SizedBox(height: 12),
          // حقل المبلغ النقدي
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'المبلغ النقدي:',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _cashAmountController,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AssyrianTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      prefixIcon: const Icon(
                        Icons.attach_money,
                        color: AssyrianTheme.primaryGold,
                        size: 20,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      _formattingService.getPriceInputFormatter(),
                    ],
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: _cashTransactionType == 'receipt'
                          ? Colors.green
                          : Colors.red,
                    ),
                    onChanged: (value) {
                      setState(() {
                        final cleanValue =
                            SmartNumberFormatter.convertToEnglishNumbers(
                              value.replaceAll(
                                _formattingService.thousandsSeparator,
                                '',
                              ),
                            );
                        _cashAmount = double.tryParse(cleanValue) ?? 0;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        // المجموع النهائي وتفاصيل الدفع والمتبقي
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedType == 'cash'
                          ? 'المبلغ النقدي:'
                          : 'إجمالي قيمة الفاتورة:',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formattingService.formatCurrency(
                          _selectedType == 'cash'
                              ? _cashAmount
                              : totalAfterDiscountAndTax,
                        ),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showPaymentDetails) ...[
                if (currentPaid > 0) ...[
                  const Divider(height: 14, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'المبلغ المدفوع (الواصل):',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '- ${_formattingService.formatCurrency(currentPaid)}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 14, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        currentPaid > 0
                            ? 'المتبقي للدفع:'
                            : 'المجموع النهائي المطلوب:',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: remainingAmount > 0
                              ? Colors.orange[900]
                              : Colors.green[900],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          remainingAmount > 0
                              ? _formattingService.formatCurrency(
                                  remainingAmount,
                                )
                              : '0.00 د.ع (مدفوع بالكامل)',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: remainingAmount > 0
                                ? Colors.orange[900]
                                : Colors.green[900],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: LoadingButton(
        text: 'إنشاء الفاتورة',
        onPressed: isSaving ? null : _createInvoice,
        isLoading: isSaving,
        icon: Icons.receipt_long,
        backgroundColor: AssyrianTheme.primaryGold,
        foregroundColor: AssyrianTheme.deepBlue,
      ),
    );
  }

  Widget _buildQuantityInput({
    required TextEditingController controller,
    String label = 'الكمية',
    ValueChanged<String>? onChanged,
  }) {
    return Focus(
      onFocusChange: (hasFocus) {
        // عند التركيز على الحقل، يمسح الكمية
        if (hasFocus && controller.text.isNotEmpty) {
          setState(() {
            controller.text = '';
          });
        }
        // عند فقدان التركيز، إذا كان الحقل فارغاً يعود 1
        if (!hasFocus && controller.text.isEmpty) {
          setState(() {
            controller.text = '1';
          });
        }
      },
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [_formattingService.getPriceInputFormatter()],
        decoration: InputDecoration(
          labelText: label,
          hintText: '1',
          prefixIcon: const Icon(
            Icons.production_quantity_limits,
            color: AssyrianTheme.primaryGold,
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AssyrianTheme.primaryGold,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        ),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        onChanged: onChanged,
      ),
    );
  }

  void _addProductToInvoice() {
    if (_selectedProduct == null) {
      return;
    }

    // عند تعديل عنصر قائم، نتحقق من الاسم والكمية والسعر ثم نستبدله.
    if (_editingItemIndex != null && _selectedType != 'sales_return') {
      final index = _editingItemIndex!;
      if (index < 0 || index >= _invoiceItems.length) return;

      String cleanNumber(String value) =>
          SmartNumberFormatter.convertToEnglishNumbers(
            value
                .replaceAll(',', '')
                .replaceAll('،', '')
                .replaceAll(' ', '')
                .replaceAll(_formattingService.thousandsSeparator, '')
                .trim(),
          );
      final quantity = double.tryParse(cleanNumber(_quantityController.text));
      final itemPrice = double.tryParse(cleanNumber(_itemPriceController.text));
      final sellingPrice = double.tryParse(
        cleanNumber(_sellingPriceController.text),
      );
      if (quantity == null ||
          quantity <= 0 ||
          itemPrice == null ||
          itemPrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال كمية وسعر صحيحين'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_selectedType == 'purchase' &&
          _sellingPriceController.text.trim().isNotEmpty &&
          sellingPrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال سعر بيع صحيح'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final original = _invoiceItems[index];
      final name = _editItemNameController.text.trim();
      final updatedItem = InvoiceItemEntity(
        productName: name.isEmpty ? _selectedProduct!.name : name,
        productId: original.productId,
        quantity: quantity,
        unit: original.unit,
        unitPrice: itemPrice,
        totalPrice: quantity * itemPrice,
        itemId: original.itemId,
        originalInvoiceId: original.originalInvoiceId,
        originalInvoiceNumber: original.originalInvoiceNumber,
        originalSaleDate: original.originalSaleDate,
        isReturned: original.isReturned,
        returnedQuantity: original.returnedQuantity,
        originalQuantity: original.originalQuantity,
        purchasePrice: _selectedType == 'purchase'
            ? itemPrice
            : original.purchasePrice,
        sellingPrice: _selectedType == 'purchase'
            ? (sellingPrice ?? original.sellingPrice)
            : itemPrice,
      );
      setState(() {
        _invoiceItems[index] = updatedItem;
        _editingItemIndex = null;
        _calculateTotal();
        _purchasePriceController.clear();
        _sellingPriceController.clear();
        _itemPriceController.clear();
        _editItemNameController.clear();
        _quantityController.clear();
        _productSearchController.clear();
        _selectedProduct = null;
        _filteredProducts = List.from(_products);
      });
      return;
    }

    // إذا كان المنتج جديد (مؤقت)، نتحقق من الأسعار
    if (_selectedProduct!.id.startsWith('temp_')) {
      final isPurchaseType = _selectedType == 'purchase';

      // في المشتريات: التحقق من سعر الشراء والبيع
      double? purchasePrice;
      if (isPurchaseType) {
        purchasePrice = double.tryParse(
          _newProductPurchasePriceController.text.replaceAll(',', ''),
        );
        if (purchasePrice == null || purchasePrice <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى إدخال سعر شراء صحيح'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final sellingPrice = double.tryParse(
        _newProductSellingPriceController.text.replaceAll(',', ''),
      );

      if (sellingPrice == null || sellingPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال سعر بيع صحيح'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // تحديث أسعار المنتج المؤقت
      _selectedProduct = ProductEntity(
        id: _selectedProduct!.id,
        name: _selectedProduct!.name,
        description: 'منتج مؤقت - لا يُحفظ في المخزون',
        unit: 'قطعة',
        quantity: 0,
        minQuantity: 10,
        costPrice: purchasePrice ?? 0,
        sellingPrice: sellingPrice,
        organizationEmail: FirebaseAuth.instance.currentUser?.email ?? '',
        createdAt: DateTime.now(),
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      );
    }

    // إذا كان الحقل فارغاً، نعتبر الكمية 1
    final quantityText = _quantityController.text.isEmpty
        ? '1'
        : _quantityController.text;
    final quantity =
        double.tryParse(
          SmartNumberFormatter.convertToEnglishNumbers(
            quantityText
                .replaceAll(',', '')
                .replaceAll('،', '')
                .replaceAll(' ', '')
                .replaceAll(_formattingService.thousandsSeparator, '')
                .trim(),
          ),
        ) ??
        1;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كمية صحيحة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // البيع النقدي العام فقط يحتوي على عناصر؛ إيصال الحساب منفصل.
    if (_selectedType == 'cash' && _selectedCustomer != null) {
      final parsedCashAmount = double.tryParse(
        SmartNumberFormatter.convertToEnglishNumbers(
          _cashAmountController.text
              .replaceAll(',', '')
              .replaceAll('،', '')
              .replaceAll(' ', '')
              .replaceAll(_formattingService.thousandsSeparator, '')
              .trim(),
        ),
      );
      if (parsedCashAmount == null || parsedCashAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال مبلغ نقدي صحيح'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() {
        _cashAmount = parsedCashAmount;
        _invoiceItems.clear();
        _totalAmount = 0;
      });
      return;
    }

    // ✅ التحقق من نوع الفاتورة - في المشتريات نضيف مباشرة بدون تحذير
    final isSalesType =
        _selectedType == 'sales' ||
        _selectedType == 'cash' ||
        _selectedType == 'subscription';

    // في المشتريات: إضافة مباشرة بدون التحقق من المخزون
    if (!isSalesType) {
      _addInvoiceItem(_selectedProduct!, quantity);
      _clearProductSelection();
      return;
    }

    // في البيع: التحقق من المخزون وإظهار تحذير إذا لزم الأمر
    final hasStockIssue =
        !_selectedProduct!.id.startsWith('temp_') &&
        (_selectedProduct!.isOutOfStock ||
            quantity > _selectedProduct!.quantity);

    if (hasStockIssue) {
      _showStockWarningDialog(quantity);
    } else {
      // إضافة المنتج مباشرة إذا كان متوفر أو مؤقت
      _addInvoiceItem(_selectedProduct!, quantity);
      _clearProductSelection();
    }
  }

  void _showStockWarningDialog(double quantity) {
    // ✅ التحقق من نوع الفاتورة - لا إظهار تحذير في المشتريات
    final isSalesType =
        _selectedType == 'sales' ||
        _selectedType == 'cash' ||
        _selectedType == 'subscription';

    if (!isSalesType) {
      // في المشتريات، لا نظهر تحذير المخزون
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24.sp),
            SizedBox(width: 8.w),
            const Text('تحذير المخزون'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedProduct!.isOutOfStock)
              Text(
                'هذا المنتج نافد من المخزون (الكمية المتاحة: ${_selectedProduct!.quantity.toInt()} ${_selectedProduct!.unit})',
                style: TextStyle(fontSize: 14.sp, color: Colors.red),
              )
            else if (quantity > _selectedProduct!.quantity)
              Text(
                'الكمية المطلوبة (${quantity.toInt()}) أكبر من المتاح في المخزون (${_selectedProduct!.quantity.toInt()} ${_selectedProduct!.unit})',
                style: TextStyle(fontSize: 14.sp, color: Colors.orange),
              ),
            SizedBox(height: 12.h),
            Text(
              'هل تريد المتابعة وإضافة المنتج للفاتورة؟',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _addInvoiceItem(_selectedProduct!, quantity);
              _clearProductSelection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  /// الحصول على اسم الرف من الـ ID
  String? _getShelfName(String shelfId) {
    try {
      final shelf = _shelves.firstWhereOrNull((s) => s.id == shelfId);
      return shelf?.name;
    } on Exception {
      return null;
    }
  }

  void _startProductSearch() {
    if (_editingItemIndex != null) {
      // إلغاء التعديل غير المعتمد قبل استخدام بحث إضافة منتج.
      _clearProductSelection();
    }
    _scrollProductDetailsIntoView();
  }

  void _scrollProductDetailsIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fieldContext = _productFieldKey.currentContext;
      if (fieldContext == null) return;
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  void _clearProductSelection() {
    setState(() {
      _productSearchController.clear();
      _quantityController.clear();
      if (_editingItemIndex != null) {
        _editingItemIndex = null;
        _editItemNameController.clear();
        _itemPriceController.clear();
        _purchasePriceController.clear();
        _sellingPriceController.clear();
        _defaultPurchasePrice = 0;
        _defaultSellingPrice = 0;
      }
      _selectedProduct = null;
      _filteredProducts = List.from(_products);
      _filteredSoldItems = List.from(_soldItems);
      _showSoldItemsSuggestions = false;
      _hideProductSuggestionsOverlay();
    });
  }

  void _addInvoiceItem(ProductEntity product, double quantity) {
    // تحديد سعر الوحدة بناءً على نوع الفاتورة والأسعار المخصصة
    double unitPrice = 0;
    double purchasePrice = 0;
    double? sellingPrice = 0;
    double? costPrice = 0;
    final editingItem =
        _editingItemIndex != null &&
            _editingItemIndex! >= 0 &&
            _editingItemIndex! < _invoiceItems.length
        ? _invoiceItems[_editingItemIndex!]
        : null;
    final isEditingManualReturn =
        _selectedType == 'sales_return' &&
        editingItem?.itemId?.startsWith('manual_return_') == true;

    // إذا كان المنتج جديد (مؤقت)، نستخدم أسعاره الخاصة مباشرة
    if (product.id.startsWith('temp_')) {
      purchasePrice = product.costPrice ?? 0;
      sellingPrice = product.sellingPrice;
      costPrice = product.costPrice ?? 0;
    }

    if (_selectedType == 'purchase') {
      // لفواتير الشراء: استخدام سعر الشراء من الحقل أو من المنتج
      if (!product.id.startsWith('temp_')) {
        final cleanPurchasePrice = SmartNumberFormatter.convertToEnglishNumbers(
          _purchasePriceController.text.trim().replaceAll(
            _formattingService.thousandsSeparator,
            '',
          ),
        );
        final cleanSellingPrice = SmartNumberFormatter.convertToEnglishNumbers(
          _sellingPriceController.text.trim().replaceAll(
            _formattingService.thousandsSeparator,
            '',
          ),
        );
        final customPurchasePrice = double.tryParse(cleanPurchasePrice);
        final customSellingPrice = double.tryParse(cleanSellingPrice);

        purchasePrice = customPurchasePrice ?? _defaultPurchasePrice;
        sellingPrice = customSellingPrice ?? _defaultSellingPrice;
        costPrice = purchasePrice;
      }

      // سعر الوحدة هو سعر الشراء
      unitPrice = purchasePrice;
    } else if (isEditingManualReturn) {
      final editedPrice = double.tryParse(
        SmartNumberFormatter.convertToEnglishNumbers(
          _itemPriceController.text
              .replaceAll(',', '')
              .replaceAll('،', '')
              .replaceAll(' ', '')
              .replaceAll(_formattingService.thousandsSeparator, '')
              .trim(),
        ),
      );
      if (editedPrice == null || !editedPrice.isFinite || editedPrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال سعر استرداد صحيح'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      unitPrice = editedPrice;
      sellingPrice = editedPrice;
    } else {
      // لفواتير المبيعات: استخدام سعر البيع
      if (!product.id.startsWith('temp_')) {
        final cleanSellingPrice = SmartNumberFormatter.convertToEnglishNumbers(
          _sellingPriceController.text.trim().replaceAll(
            _formattingService.thousandsSeparator,
            '',
          ),
        );
        final customSellingPrice = double.tryParse(cleanSellingPrice);
        unitPrice = customSellingPrice ?? _defaultSellingPrice;
        sellingPrice = unitPrice;
        costPrice = product.costPrice ?? 0;
      } else {
        final customPrice = double.tryParse(
          SmartNumberFormatter.convertToEnglishNumbers(
            _itemPriceController.text
                .replaceAll(',', '')
                .replaceAll('،', '')
                .replaceAll(' ', '')
                .replaceAll(_formattingService.thousandsSeparator, '')
                .trim(),
          ),
        );
        unitPrice = customPrice ?? product.sellingPrice;
        sellingPrice = unitPrice;
      }
    }

    final totalPrice = quantity * unitPrice;

    // للمواد المرتجعة: حفظ المعلومات الأصلية واستخدام السعر الأصلي
    String? itemId;
    String? originalInvoiceId;
    String? originalInvoiceNumber;
    DateTime? originalSaleDate;
    double? originalUnitPrice; // ✅ السعر الأصلي من الفاتورة

    final currentItem = editingItem;
    final isManualReturn = isEditingManualReturn;
    final InvoiceItemEntity? soldItem =
        _selectedType == 'sales_return' && !isManualReturn
        ? _findSoldItemForReturn(
            InvoiceItemEntity(
              productName: product.name,
              quantity: quantity,
              unit: product.unit,
              unitPrice: unitPrice,
              totalPrice: totalPrice,
              originalInvoiceId: currentItem?.originalInvoiceId,
            ),
          )
        : null;

    if (_selectedType == 'sales_return') {
      if (isManualReturn) {
        if (quantity <= 0 || quantity != quantity.truncateToDouble()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'كمية المرتجع يجب أن تكون عددًا صحيحًا أكبر من صفر',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        // تبقى المواد اليدوية غير مرتبطة بسطر بيع، ويمكن تعديل سعرها.
        originalUnitPrice = null;
      } else if (soldItem != null) {
        final alreadyReturnedOnThisInvoice = _invoiceItems
            .where(
              (line) =>
                  line.itemId == soldItem.itemId &&
                  line.originalInvoiceId == soldItem.originalInvoiceId,
            )
            .fold<double>(0, (sum, line) => sum + line.quantity);
        final editedLineQuantity =
            currentItem != null &&
                currentItem.itemId == soldItem.itemId &&
                currentItem.originalInvoiceId == soldItem.originalInvoiceId
            ? currentItem.quantity
            : 0.0;
        final availableQuantity =
            soldItem.quantity -
            alreadyReturnedOnThisInvoice +
            editedLineQuantity;
        if (quantity > availableQuantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'الكمية المتاحة لهذا المرتجع هي ${availableQuantity.clamp(0, double.infinity)} ${soldItem.unit}',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        itemId = soldItem.itemId;
        originalInvoiceId = soldItem.originalInvoiceId;
        originalInvoiceNumber = soldItem.originalInvoiceNumber;
        originalSaleDate = soldItem.originalSaleDate;
        originalUnitPrice = soldItem.unitPrice;
      } else if (currentItem == null) {
        itemId = null;
        originalInvoiceId = null;
        originalInvoiceNumber = null;
        originalSaleDate = null;
        originalUnitPrice = null;
      }
    }

    // ✅ للمواد المرتجعة: استخدام السعر الأصلي بدلاً من السعر الحالي
    final double finalUnitPrice =
        (_selectedType == 'sales_return' && originalUnitPrice != null)
        ? originalUnitPrice
        : unitPrice;
    final double finalTotalPrice = quantity * finalUnitPrice;

    final item = InvoiceItemEntity(
      productName: _editItemNameController.text.trim().isNotEmpty
          ? _editItemNameController.text.trim()
          : product.name,
      productId: isManualReturn
          ? (product.id.startsWith('temp_') || product.id.startsWith('edit_')
                ? currentItem?.productId
                : product.id)
          : _selectedType == 'sales_return'
          ? soldItem?.productId ?? currentItem?.productId ?? product.id
          : product.id,
      quantity: quantity,
      unit: isManualReturn ? currentItem!.unit : soldItem?.unit ?? product.unit,
      unitPrice: finalUnitPrice,
      totalPrice: finalTotalPrice,
      itemId: isManualReturn
          ? currentItem!.itemId
          : itemId ?? currentItem?.itemId,
      originalInvoiceId: isManualReturn ? null : originalInvoiceId,
      originalInvoiceNumber: isManualReturn ? null : originalInvoiceNumber,
      originalSaleDate: isManualReturn ? null : originalSaleDate,
      isReturned: currentItem?.isReturned ?? false,
      returnedQuantity: currentItem?.returnedQuantity,
      originalQuantity: currentItem?.originalQuantity,
      purchasePrice: _selectedType == 'purchase'
          ? costPrice
          : currentItem?.purchasePrice,
      sellingPrice: _selectedType == 'purchase'
          ? sellingPrice
          : currentItem?.sellingPrice ?? sellingPrice,
    );

    setState(() {
      if (_editingItemIndex != null &&
          _editingItemIndex! >= 0 &&
          _editingItemIndex! < _invoiceItems.length) {
        _invoiceItems[_editingItemIndex!] = item;
        _editingItemIndex = null;
      } else {
        _invoiceItems.add(item);
      }
      _selectedSoldItem = null;
      _calculateTotal();
      // تفريغ حقول الأسعار بعد الإضافة
      _purchasePriceController.clear();
      _sellingPriceController.clear();
      _itemPriceController.clear();
      _editItemNameController.clear();
      _quantityController.clear();
      _productSearchController.clear();
      _selectedProduct = null;
      _defaultPurchasePrice = 0;
      _defaultSellingPrice = 0;
    });
  }

  void _editItem(int index) {
    final item = _invoiceItems[index];
    final product =
        _products.firstWhereOrNull(
          (candidate) => candidate.id == item.productId,
        ) ??
        _products.firstWhereOrNull(
          (candidate) => candidate.name == item.productName,
        );

    FocusScope.of(context).unfocus();
    setState(() {
      _editingItemIndex = index;
      _productSearchController.clear();
      _selectedSoldItem = item.originalInvoiceId == null
          ? null
          : _soldItems.firstWhereOrNull(
              (sold) =>
                  sold.itemId == item.itemId &&
                  sold.originalInvoiceId == item.originalInvoiceId,
            );
      _showSoldItemsSuggestions = false;
      _selectedProduct =
          product ??
          ProductEntity(
            id: 'edit_$index',
            organizationEmail: '',
            name: item.productName,
            quantity: 0,
            unit: item.unit,
            sellingPrice: item.unitPrice,
            minQuantity: 0,
            costPrice: item.purchasePrice,
            createdBy: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
      _editItemNameController.text = item.productName;
      _quantityController.text = _formattingService.formatNumber(item.quantity);
      _itemPriceController.text = _formattingService.formatNumber(
        item.unitPrice,
      );
      _purchasePriceController.text = item.purchasePrice == null
          ? ''
          : _formattingService.formatNumber(item.purchasePrice!);
      _sellingPriceController.text = _formattingService.formatNumber(
        item.sellingPrice ?? item.unitPrice,
      );
      _defaultPurchasePrice = item.purchasePrice ?? 0;
      _defaultSellingPrice = item.sellingPrice ?? item.unitPrice;
      _filteredProducts = List.from(_products);
      _hideProductSuggestionsOverlay();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _invoiceItemKeys.length) return;
      final itemContext = _invoiceItemKeys[index].currentContext;
      if (itemContext != null) {
        Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 300),
          alignment: 0.2,
        );
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
      if (_editingItemIndex == index) {
        _editingItemIndex = null;
        _productSearchController.clear();
        _editItemNameController.clear();
        _itemPriceController.clear();
        _quantityController.clear();
        _selectedProduct = null;
      } else if (_editingItemIndex != null && _editingItemIndex! > index) {
        _editingItemIndex = _editingItemIndex! - 1;
      }
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _totalAmount = _invoiceItems.fold(
      0,
      (total, item) => total + item.totalPrice,
    );
  }

  // ⚠️ ملاحظة للمبرمجين المستقبليين (إصلاح 2026-10-09):
  // أُزيلت دالة _createProductLogs لأنها كانت تُنشئ
  // سجلات حركة منتجات مكررة ويتيمة. السبب:
  // InvoiceRepositoryImpl ينشئ سجلات الحركة ذرياً
  // داخل معاملة الفاتورة في المجموعة العليا
  // products_logs (وهي التي يقرأها getProductLogs).
  // هذه الدالة كانت تستدعي createProductLog التي
  // تكتب إلى مجموعة فرعية تحت كل منتج لا يقرأها
  // أحد، فتُنشئ سجلات يتيمة بعد أن أنشأ المستودع
  // السجلات الحقيقية بالفعل — وتهدر قراءة وكتابة
  // إضافيتين لكل عنصر. لا تُنشئ سجلات حركة
  // المنتجات من الصفحة أبداً: المستودع يتولاها
  // ذرياً مع الفاتورة (All-or-Nothing).

  Future<void> _createInvoice() async {
    // حماية من التنفيذ المكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    // إيصال العميل يتطلب مبلغاً؛ فاتورة البيع النقدية تستخدم مجموع المواد.
    if (_selectedType == 'cash' &&
        _selectedCustomer != null &&
        _cashAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إدخال مبلغ نقدي صحيح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // فواتير البيع النقدي والآجل تتطلب عناصر؛ إيصال العميل منفصل عن المواد.
    if (_invoiceItems.isEmpty &&
        _selectedType != 'sales_return' &&
        (_selectedType != 'cash' || _selectedCustomer == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إضافة منتج واحد على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // حفظ المنتجات الجديدة في المخزون (فقط لفواتير الشراء)
    final productsToSave = <ProductEntity>[];
    if (_selectedType == 'purchase') {
      // فقط في فواتير الشراء: حفظ المنتجات الجديدة في المخزون
      for (final item in _invoiceItems) {
        // التحقق إذا كان المنتج مؤقت (جديد)
        if (item.productName.startsWith('temp_')) {
          // البحث عن المنتج في العناصر لمعرفة أسعاره
          final tempProduct = ProductEntity(
            id: '', // سيتم تعيينه بواسطة Firestore
            name: item.productName.replaceFirst('temp_', ''),
            description: 'منتج تمت إضافته من فاتورة شراء',
            unit: item.unit,
            // ✅ كمية صفرية (إصلاح عدّ مزدوج 2026-10-11):
            // كمية الشراء تُضاف ذرياً داخل معاملة
            // الفاتورة (_applyInventoryUpdatesForInvoice
            // تزيد كمية المنتج بمقدار كمية العنصر).
            // كان يُنشأ هنا بـ item.quantity فحُسبت
            // الكمية مرتين (مرة عند الإنشاء ومرة في
            // المعاملة) — انحراف مزمن في المخزون.
            quantity: 0,
            minQuantity: 10,
            costPrice: item.purchasePrice ?? 0,
            sellingPrice: item.sellingPrice ?? item.unitPrice,
            organizationEmail: FirebaseAuth.instance.currentUser?.email ?? '',
            createdAt: DateTime.now(),
            createdBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          );
          productsToSave.add(tempProduct);
        }
      }

      // حفظ المنتجات الجديدة في المخزون
      if (productsToSave.isNotEmpty) {
        try {
          final inventoryBloc = context.read<InventoryBloc>();
          for (final product in productsToSave) {
            await inventoryBloc.repository.createProduct(product: product);
          }
        } on Exception catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل حفظ المنتجات في المخزون'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    }

    // التحقق من حالة المخزون وإظهار تأكيد إذا لزم الأمر
    // ✅ التحقق من نوع الفاتورة - لا إظهار تحذير في المشتريات
    final isSalesType =
        _selectedType == 'sales' ||
        _selectedType == 'cash' ||
        _selectedType == 'subscription';

    var stockIssues = [];

    for (final item in _invoiceItems) {
      final product = _products
          .where((p) => p.name == item.productName)
          .firstOrNull;
      if (product == null) continue;

      if (isSalesType && product.isOutOfStock) {
        stockIssues.add('• ${item.productName}: نافذ من المخزون');
      } else if (isSalesType && item.quantity > product.quantity) {
        stockIssues.add(
          '• ${item.productName}: مطلوب ${item.quantity.toInt()} ومتاح ${product.quantity.toInt()}',
        );
      }
    }

    // إظهار تأكيد إذا كانت هناك مشاكل في المخزون
    if (stockIssues.isNotEmpty) {
      if (!mounted) return;

      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 24.sp),
              SizedBox(width: 8.w),
              const Text('تأكيد إنشاء الفاتورة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحتوي هذه الفاتورة على منتجات بها مشاكل في المخزون:',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12.h),
              ...stockIssues.map(
                (issue) => Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Text(
                    issue,
                    style: TextStyle(fontSize: 12.sp, color: Colors.red),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'هل تريد المتابعة وإنشاء الفاتورة؟',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('متابعة'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (shouldContinue != true) {
        return;
      }
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // الحصول على اسم المستخدم
    String createdBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        createdBy = switchedUser['id'] as String;
      } else {
        createdBy = currentUser.uid;
      }
    } on Exception catch (_) {
      createdBy = currentUser.uid;
    }

    try {
      // تحديد ما إذا كان العميل محدد أم نقدي
      final isCustomerSelected = _selectedCustomer != null;
      final selectedCustomer = _selectedCustomer;

      // التحقق من حد الائتمان قبل الحفظ (فقط لفواتير المبيعات والاشتراكات)
      if (isCustomerSelected &&
          selectedCustomer != null &&
          (_selectedType == 'sales' || _selectedType == 'subscription')) {
        final currentDebt = selectedCustomer.totalDebt;
        final creditLimit = selectedCustomer.creditLimit ?? 0;
        final invoiceAmount = _totalAmount;
        final newDebt = currentDebt + invoiceAmount;

        // إذا تجاوز حد الائتمان، عرض تحذير
        if (creditLimit > 0 && newDebt > creditLimit) {
          if (mounted) {
            final shouldContinue = await CreditLimitWarningDialog.show(
              context,
              customerName: selectedCustomer.name,
              currentDebt: currentDebt,
              creditLimit: creditLimit,
              invoiceAmount: invoiceAmount,
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
                            'تم إلغاء العملية - لم يتم إنشاء الفاتورة',
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

      // تحديد حالة الدفع والأرشفة
      var paidAmount = 0.0;
      var remainingAmount = 0.0;
      var status = 'unpaid';
      var invoiceType = _selectedType;
      var isArchived = false;

      // حساب المجموع النهائي (بعد الخصم والضريبة)
      final totalAfterDiscount = _totalAmount - _currentDiscountAmount;
      final totalAfterDiscountAndTax = (totalAfterDiscount + _taxAmount).clamp(
        0.0,
        double.infinity,
      );
      final currentPaid = _currentPaidAmount;
      if (_selectedType == 'cash' && isCustomerSelected) {
        // إيصال حساب عميل؛ المبلغ ونوع العملية حقول مستقلة عن المواد.
        paidAmount = _cashTransactionType == 'receipt'
            ? _cashAmount
            : -_cashAmount;
        remainingAmount = 0;
        status = 'paid';
        invoiceType = 'cash';
        isArchived = false;
      } else if (_selectedType == 'cash') {
        // بيع نقدي بلا عميل؛ (التحقق من وجود العناصر يسبق الحفظ).
        paidAmount = totalAfterDiscountAndTax;
        remainingAmount = 0;
        status = 'paid';
        invoiceType = 'cash';
        isArchived = false;
      } else if (!isCustomerSelected && _selectedType != 'purchase') {
        // فواتير غير نقدية بدون عميل (مثل مرتجع البيع) - مدفوعة بالكامل
        paidAmount = totalAfterDiscountAndTax;
        remainingAmount = 0;
        status = 'paid';
        // لا نغير النوع إذا كان مرجع بيع أو شراء
        if (_selectedType != 'sales_return') {
          invoiceType = 'cash';
        }
        // الأرشفة الذكية: الفواتير النقدية تُؤرشف إلا آخر 10 أيام
        final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
        isArchived = _invoiceDate.isBefore(tenDaysAgo);
      } else if (_selectedType == 'purchase') {
        // فاتورة مشتريات - التاجر يدفع للعميل
        // في المشتريات: التاجر يشتري من العميل، فيدفع التاجر للعميل
        paidAmount = totalAfterDiscountAndTax; // المبلغ كامل للعميل
        remainingAmount = 0;
        status = 'paid'; // تُعتبر مدفوعة لأنها دين على التاجر للعميل
        isArchived = false;
      } else if (_selectedType == 'sales_return') {
        // فاتورة مرجع بيع
        paidAmount = totalAfterDiscountAndTax; // مدفوعة بالكامل
        remainingAmount = 0;
        status = 'paid';
        isArchived = false;
      } else {
        // فاتورة عادية مع عميل (مبيعات أو اشتراك)
        paidAmount = currentPaid;
        remainingAmount = (totalAfterDiscountAndTax - currentPaid).clamp(
          0.0,
          double.infinity,
        );
        status = remainingAmount <= 0
            ? 'paid'
            : paidAmount > 0
            ? 'partial'
            : 'unpaid';
        isArchived = false;
      }
      // إنشاء الفاتورة
      List<ReturnedItemEntity>? returnedItems;
      if (_selectedType == 'sales_return') {
        // إنشاء قائمة المواد المرتجعة من عناصر الفاتورة
        returnedItems = _invoiceItems.map((item) {
          final isManualReturn =
              item.itemId?.startsWith('manual_return_') == true;
          final soldItem = isManualReturn ? null : _findSoldItemForReturn(item);
          final hasOriginalSale =
              item.originalInvoiceId != null &&
              item.originalInvoiceId!.isNotEmpty;
          return ReturnedItemEntity(
            itemId: item.itemId ?? item.productName,
            itemName: item.productName,
            productId: isManualReturn
                ? item.productId
                : item.productId ?? soldItem?.productId,
            purchasedQuantity: hasOriginalSale
                ? (soldItem?.originalQuantity ?? soldItem?.quantity ?? 0)
                      .toInt()
                : 0,
            returnedQuantity: item.quantity.toInt(),
            unitPrice: item.unitPrice,
            saleDate: item.originalSaleDate ?? _invoiceDate,
            originalInvoiceId: item.originalInvoiceId ?? '',
            originalInvoiceNumber: item.originalInvoiceNumber,
          );
        }).toList();
      }
      final invoice = InvoiceEntity(
        id: '',
        invoiceNumber: _invoiceNumber,
        customerName: isCustomerSelected ? selectedCustomer!.name : 'عميل نقدي',
        customerPhone: isCustomerSelected ? selectedCustomer!.phone : '',
        customerId: isCustomerSelected ? selectedCustomer!.id : null,
        invoiceDate: _invoiceDate,
        totalAmount: _selectedType == 'cash'
            ? (isCustomerSelected ? _cashAmount : totalAfterDiscountAndTax)
            : totalAfterDiscountAndTax,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        status: status,
        type: invoiceType,
        items: _selectedType == 'cash' && isCustomerSelected
            ? const []
            : _invoiceItems,
        cashTransactionType: _selectedType == 'cash' && isCustomerSelected
            ? _cashTransactionType
            : (_selectedType == 'cash' ? 'sale' : null),
        cashAmount: _selectedType == 'cash'
            ? (isCustomerSelected ? _cashAmount : totalAfterDiscountAndTax)
            : 0,
        cashUserNote: _selectedType == 'cash' && isCustomerSelected
            ? _notesController.text.trim()
            : null,
        notes: _selectedType == 'cash'
            ? '${_cashTransactionType == 'receipt' ? 'استلام مبلغ نقدي من العميل' : 'إعطاء مبلغ نقدي للعميل'} - ${_notesController.text.trim().isEmpty ? '' : _notesController.text.trim()}'
            : _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        organizationEmail: currentUser.email!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: createdBy,
        isArchived: isArchived,
        isSalesReturn: _selectedType == 'sales_return',
        refundMethod: _refundMethod,
        returnedItems: returnedItems,
        balanceBeforeInvoice: isCustomerSelected
            ? selectedCustomer!.totalDebt
            : 0,
        balanceAfterInvoice: isCustomerSelected
            ? (_selectedType == 'sales' || _selectedType == 'subscription'
                  ? selectedCustomer!.totalDebt + remainingAmount
                  : _selectedType == 'purchase'
                  ? selectedCustomer!.totalDebt - totalAfterDiscountAndTax
                  : _selectedType == 'sales_return'
                  ? (_refundMethod == 'credit'
                        ? selectedCustomer!.totalDebt - totalAfterDiscountAndTax
                        : selectedCustomer!.totalDebt)
                  : _selectedType == 'cash'
                  ? selectedCustomer!.totalDebt - paidAmount
                  : selectedCustomer!.totalDebt)
            : 0,
        discountAmount: _currentDiscountAmount, // إضافة الخصم
        taxAmount: _taxAmount, // إضافة الضريبة
        taxes: _taxes.isNotEmpty ? _taxes : null, // إضافة قائمة الضرائب
      );

      if (!mounted) return;

      // الحصول على مرجع لـ InvoiceBloc قبل العملية غير المتزامنة
      final invoiceBloc = context.read<InvoiceBloc>();

      // استخدام النظام الجديد لإدارة عملية الحفظ
      await performBlocSaveOperation(
        triggerSave: () {
          invoiceBloc.add(AddInvoiceEvent(invoice, skipCreditCheck: true));
        },
        successMessage: 'تم إنشاء الفاتورة بنجاح',
        loadingMessage: 'جاري إنشاء الفاتورة...',
      );
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء الفاتورة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDebtDisplay(double debt) {
    if (debt > 0) {
      return 'عليه ${_formattingService.formatCurrency(debt)}';
    } else if (debt < 0) {
      return 'له ${_formattingService.formatCurrency(debt.abs())}';
    } else {
      return 'متوازن';
    }
  }

  /// التحقق من تجاوز العميل للحد الدين أو كونه محظوراً
  bool _isCustomerExceedingLimit(CustomerEntity customer) {
    // إذا كان محظوراً
    if (customer.status == 'blocked') {
      return true;
    }

    // إذا كان لديه حد دين وتجاوزه
    if (customer.creditLimit != null && customer.creditLimit! > 0) {
      if (customer.totalDebt > customer.creditLimit!) {
        return true;
      }
    }

    return false;
  }
}
