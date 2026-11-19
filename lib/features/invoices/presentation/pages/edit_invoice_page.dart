import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/smart_number_formatter.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../inventory/domain/entities/shelf_entity.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/returned_item_entity.dart';
import '../bloc/invoice_bloc.dart';
import '../widgets/invoice_drawer.dart';

/// صفحة تعديل الفاتورة
class EditInvoicePage extends StatefulWidget {
  const EditInvoicePage({required this.invoice, super.key});
  final InvoiceEntity invoice;

  @override
  State<EditInvoicePage> createState() => _EditInvoicePageState();
}

class _EditInvoicePageState extends State<EditInvoicePage>
    with SaveOperationMixin<EditInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();

  // صلاحيات أنواع الفواتير
  bool _canEditSales = false;
  bool _canEditPurchase = false;
  bool _canEditCash = false;
  bool _canEditSubscription = false;
  bool _canEditSalesReturn = false;

  // Controllers للحقول النصية
  InvoiceEntity? _savedInvoice;
  final _notesController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _discountController = TextEditingController();
  final _taxAmountController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _manualReturnNameController = TextEditingController();
  final _manualReturnQuantityController = TextEditingController(text: '1');
  final _manualReturnPriceController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _editItemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _itemPriceController = TextEditingController();
  int? _editingItemIndex;

  // متغيرات للحقول الأخرى
  CustomerEntity? _selectedCustomer;
  ProductEntity? _selectedProduct;
  String? _selectedCustomerId;
  String? _selectedType;
  DateTime? _invoiceDate;
  double _taxAmount = 0.0;
  final List<Map<String, dynamic>> _taxes = [];
  String? _refundMethod;

  // متغيرات البحث والاختيار
  List<CustomerEntity> _filteredCustomers = [];
  List<ProductEntity> _filteredProducts = [];
  List<InvoiceItemEntity> _filteredSoldItems = [];
  InvoiceItemEntity? _selectedSoldItem;
  bool _showSoldItemsSuggestions = false;
  bool _showManualReturnForm = false;
  int _soldItemsLoadGeneration = 0;

  // قوائم للبيانات المرتبطة
  final List<CustomerEntity> _customers = [];
  final List<ProductEntity> _products = [];
  List<ShelfEntity> _shelves = []; // قائمة الرفوف
  List<InvoiceItemEntity> _invoiceItems = [];
  List<InvoiceItemEntity> _soldItems = []; // المواد المشتراة للعميل

  // متغيرات سعر الشراء والبيع لفواتير الشراء
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  double _defaultPurchasePrice = 0; // سعر الشراء الافتراضي من المخزون
  double _defaultSellingPrice = 0; // سعر البيع الافتراضي من المخزون

  // متغيرات المنتج الجديد
  final _newProductPurchasePriceController = TextEditingController();
  final _newProductSellingPriceController = TextEditingController();
  final _newProductQuantityController = TextEditingController();

  // متغيرات الفاتورة النقدية
  String _cashTransactionType =
      'receipt'; // 'receipt' = استلام، 'payment' = إعطاء
  final _cashAmountController = TextEditingController(); // حقل المبلغ النقدي
  double _cashAmount = 0; // المبلغ النقدي
  bool _isCashReceipt = false;

  // حسابات الفاتورة
  double _totalAmount = 0;

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

  // متغير لتتبع التغييرات
  bool _hasChanges = false;

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  // LayerLink و GlobalKey لعرض الاقتراحات
  final LayerLink _customerLayerLink = LayerLink();
  final GlobalKey _customerFieldKey = GlobalKey();
  final LayerLink _productLayerLink = LayerLink();
  final GlobalKey _productFieldKey = GlobalKey();

  /// تنسيق عرض الدين مع توضيح "له" أو "عليه"
  String _formatDebtDisplay(double debt) {
    if (debt == 0) {
      return 'لا يوجد حساب';
    } else if (debt > 0) {
      return 'عليه: ${_formattingService.formatCurrency(debt)}';
    } else {
      return 'له: ${_formattingService.formatCurrency(debt.abs())}';
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
          _selectedCustomerId = customer.id;
          _customerSearchController.text = customer.name;
        });
      },
      maxHeight: 200.h,
    );
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
          orElse: () => _filteredProducts.first,
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
          _hideProductSuggestionsOverlay();
        });
      },
      maxHeight: 200.h,
    );
  }

  /// إخفاء اقتراحات العملاء
  void _hideCustomerSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  /// إخفاء اقتراحات المنتجات
  void _hideProductSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _initializeFields();
    _setupChangeListeners();
    if (_selectedType == 'sales_return') {
      final customerId = widget.invoice.customerId;
      if (customerId != null && customerId.isNotEmpty) {
        _loadSoldItemsForCustomer(customerId);
      } else {
        _loadAllSoldItems();
      }
    }
  }

  Future<void> _loadPermissions() async {
    final canEditSales = await _permissionChecker.hasPermission(
      'invoices_sales_manage',
    );
    final canEditPurchase = await _permissionChecker.hasPermission(
      'invoices_purchase_manage',
    );
    final canEditCash = await _permissionChecker.hasPermission(
      'invoices_cash_manage',
    );
    final canEditSubscription = await _permissionChecker.hasPermission(
      'invoices_subscription_manage',
    );
    final canEditSalesReturn = await _permissionChecker.hasPermission(
      'invoices_sales_return_manage',
    );

    // تحديث الـ UI بعد تحميل الصلاحيات
    if (mounted) {
      setState(() {
        _canEditSales = canEditSales;
        _canEditPurchase = canEditPurchase;
        _canEditCash = canEditCash;
        _canEditSubscription = canEditSubscription;
        _canEditSalesReturn = canEditSalesReturn;
      });
    }
  }

  /// التحقق مما إذا كان يمكن تعديل الفاتورة بناءً على نوعها
  bool get _canEdit {
    switch (widget.invoice.type) {
      case 'sales':
        return _canEditSales;
      case 'purchase':
        return _canEditPurchase;
      case 'cash':
        return _canEditCash;
      case 'subscription':
        return _canEditSubscription;
      case 'sales_return':
        return _canEditSalesReturn;
      default:
        return false;
    }
  }

  void _initializeFields() {
    // عرض نص المستخدم فقط دون إعادة دمج وصف المعاملة عند كل تعديل.
    _notesController.text = widget.invoice.displayNotes ?? '';
    if (widget.invoice.cashUserNote != null) {
      _notesController.text = widget.invoice.cashUserNote!;
    }
    _paidAmountController.text = _formattingService.formatNumber(
      widget.invoice.paidAmount,
    );
    _selectedType = widget.invoice.type;
    _invoiceDate = widget.invoice.invoiceDate;
    _invoiceDateController.text = _formattingService.formatDate(
      widget.invoice.invoiceDate,
    );
    _selectedSoldItem = null;
    _invoiceItems = widget.invoice.items.map((item) {
      if (_selectedType == 'sales_return') {
        return item.itemId?.startsWith('manual_return_') == true ||
                item.originalInvoiceId == null
            ? item
            : InvoiceItemEntity(
                productName: item.productName,
                productId: item.productId,
                quantity: item.quantity.abs(),
                unit: item.unit,
                unitPrice: item.unitPrice.abs(),
                totalPrice: item.totalPrice.abs(),
                itemId: item.itemId,
                originalInvoiceId: item.originalInvoiceId,
                originalInvoiceNumber: item.originalInvoiceNumber,
                originalSaleDate: item.originalSaleDate,
                isReturned: item.isReturned,
                returnedQuantity: item.returnedQuantity,
                originalQuantity: item.originalQuantity,
                purchasePrice: item.purchasePrice,
                sellingPrice: item.sellingPrice,
              );
      }
      if (_selectedType != 'sales_return' ||
          item.originalInvoiceId != null ||
          (item.quantity >= 0 && item.totalPrice >= 0)) {
        return item;
      }
      // مسار المرتجع السريع القديم يخزن أسطر الفاتورة بإشارات سالبة،
      // بينما شاشة التعديل والمستودع يعتمدان على كميات وقيم موجبة.
      return InvoiceItemEntity(
        productName: item.productName,
        productId: item.productId,
        quantity: item.quantity.abs(),
        unit: item.unit,
        unitPrice: item.unitPrice.abs(),
        totalPrice: item.totalPrice.abs(),
        itemId: item.itemId,
        originalInvoiceId: item.originalInvoiceId,
        originalInvoiceNumber: item.originalInvoiceNumber,
        originalSaleDate: item.originalSaleDate,
        isReturned: item.isReturned,
        returnedQuantity: item.returnedQuantity,
        originalQuantity: item.originalQuantity,
        purchasePrice: item.purchasePrice,
        sellingPrice: item.sellingPrice,
      );
    }).toList();
    _calculateTotal();

    // إيصالات الحساب الجديدة تحفظ نوع العملية في حقل مخصص،
    // والقديمة تُتعرف من بياناتها الوصفية. استعد المبلغ لتعديلها.
    _isCashReceipt = widget.invoice.isCashAccountReceipt;
    final cashReceiptItem = _isCashReceipt
        ? widget.invoice.items.firstWhereOrNull(
            (item) =>
                item.unit == 'مبلغ نقدي' ||
                item.productName.startsWith('مبلغ نقدي - ') ||
                item.productName.startsWith('تصفير حساب وأرشفة - '),
          )
        : null;
    if (_isCashReceipt) {
      _cashAmount = widget.invoice.cashAmount > 0
          ? widget.invoice.cashAmount
          : (cashReceiptItem?.totalPrice.abs() ??
                widget.invoice.cashTransactionAmount);
      _cashAmountController.text = _formattingService.formatNumber(_cashAmount);
      final transactionType = widget.invoice.effectiveCashTransactionType;
      _cashTransactionType =
          transactionType == 'payment' || transactionType == 'clearance'
          ? 'payment'
          : 'receipt';
    } else {
      _cashAmount = 0;
      _cashAmountController.clear();
      _cashTransactionType = 'receipt';
    }

    // ✅ إصلاح (2026-10-09): استعادة طريقة الاسترداد الحالية
    // من الفاتورة. بدون هذا، تعديل فاتورة مرجع بيع دون
    // إعادة اختيار طريقة الاسترداد يفقد القيمة القديمة
    // (تصبح null) فيفقد أثر الرد النقدي على الصندوق
    // وأثر خصم الحساب على دين العميل عند التحديث.
    _refundMethod = widget.invoice.refundMethod;

    // تعبئة معلومات الخصم والضرائب
    if (widget.invoice.discountAmount > 0) {
      _discountController.text = _formattingService.formatNumber(
        widget.invoice.discountAmount,
      );
    }

    _taxAmount = widget.invoice.taxAmount;
    if (widget.invoice.taxes != null && widget.invoice.taxes!.isNotEmpty) {
      _taxes.addAll(widget.invoice.taxes!);
    }

    // لا نحتفظ بالعميل القديم كاختيار أثناء تعديل الفاتورة.
    // Customer is selected only from suggestions.
    _selectedCustomer = null;
    _selectedCustomerId = null;

    // استعادة اسم العميل في حقل البحث
    _customerSearchController.text = widget.invoice.customerName;

    // محاولة تحديث بيانات العميل من القائمة المحملة
    _findCustomerByNameAndPhone();
  }

  /// الحصول على الكمية المشتراة الأصلية لمنتج معين
  /// (نفس دالة صفحة الإنشاء — تُستخدم لبناء
  /// المواد المرتجعة عند حفظ فاتورة مرجع البيع)
  InvoiceItemEntity? _findSoldItemForReturn(InvoiceItemEntity item) {
    final selectedSoldItem = _selectedSoldItem;
    if (selectedSoldItem != null &&
        selectedSoldItem.productName == item.productName &&
        (item.originalInvoiceId == null ||
            selectedSoldItem.originalInvoiceId == item.originalInvoiceId)) {
      return selectedSoldItem;
    }

    // Without a source invoice, don't guess among duplicate product names.
    if (item.originalInvoiceId == null || item.originalInvoiceId!.isEmpty) {
      return null;
    }

    return _soldItems.firstWhereOrNull(
      (soldItem) =>
          soldItem.productName == item.productName &&
          soldItem.originalInvoiceId == item.originalInvoiceId,
    );
  }

  void _addManualReturnItem() {
    final name = _manualReturnNameController.text.trim();
    if (name.isNotEmpty &&
        _invoiceItems.any(
          (item) => item.productName.trim().toLowerCase() == name.toLowerCase(),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هذه المادة موجودة بالفعل في المرتجع؛ عدّل كميتها من القائمة',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final quantityText = SmartNumberFormatter.convertToEnglishNumbers(
      _manualReturnQuantityController.text
          .replaceAll(',', '')
          .replaceAll('،', '')
          .trim(),
    );
    final priceText = SmartNumberFormatter.convertToEnglishNumbers(
      _manualReturnPriceController.text
          .replaceAll(',', '')
          .replaceAll('،', '')
          .replaceAll(_formattingService.thousandsSeparator, '')
          .trim(),
    );
    final quantity = double.tryParse(quantityText);
    final unitPrice = double.tryParse(priceText);

    if (name.isEmpty ||
        quantity == null ||
        !quantity.isFinite ||
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
    if (quantity <= 0 || quantity != quantity.truncateToDouble()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كمية المرتجع يجب أن تكون عددًا صحيحًا أكبر من صفر'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final inventoryMatches = _products
        .where(
          (product) =>
              product.isActive &&
              product.name.trim().toLowerCase() == name.toLowerCase(),
        )
        .toList();
    final inventoryProduct = inventoryMatches.length == 1
        ? inventoryMatches.single
        : null;
    const resolvedUnit = '';
    final manualItemId =
        'manual_return_${DateTime.now().microsecondsSinceEpoch}';

    setState(() {
      _invoiceItems.add(
        InvoiceItemEntity(
          productName: name,
          productId: inventoryProduct?.id,
          quantity: quantity,
          unit: resolvedUnit,
          unitPrice: unitPrice,
          totalPrice: quantity * unitPrice,
          itemId: manualItemId,
        ),
      );
      _calculateTotal();
      _manualReturnNameController.clear();
      _manualReturnQuantityController.text = '1';
      _manualReturnPriceController.clear();
      _onFieldChanged();
    });

    final stockMessage = inventoryProduct?.trackQuantity == true
        ? ' وستُضاف الكمية إلى مخزون المنتج المطابق'
        : inventoryProduct == null && inventoryMatches.length > 1
        ? ' ولم يُربط بالمخزون لأن الاسم يطابق أكثر من منتج'
        : inventoryProduct == null
        ? ' ولم يُربط بمنتج في المخزون'
        : ' (المنتج لا يتتبع الكمية في المخزون)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('أُضيف العنصر المرتجع$stockMessage')),
    );
  }

  void _refreshReturnedItemsForCurrentInvoice() {
    if (_selectedType != 'sales_return') return;

    // Use the original invoice's customer relationship; never fall back to
    // returns belonging to other customers just because the search is empty.
    final originalCustomerId = widget.invoice.customerId;
    if (originalCustomerId != null && originalCustomerId.isNotEmpty) {
      _loadSoldItemsForCustomer(originalCustomerId);
    } else {
      _loadAllSoldItems();
    }
  }

  void _findCustomerByNameAndPhone() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      CustomerEntity? customer;

      // مطابقة اسم وهاتف العميل مع بيانات الفاتورة أولاً، لأن معرّف العميل
      // القديم قد يشير إلى شخص آخر إذا حُذفت بيانات العميل وأعيد استخدامها.
      customer = _customers.firstWhereOrNull(
        (c) =>
            c.name == widget.invoice.customerName &&
            c.phone == widget.invoice.customerPhone,
      );

      // ثم نستخدم المعرّف الثابت كخيار ثانٍ.
      if (customer == null &&
          widget.invoice.customerId != null &&
          widget.invoice.customerId!.isNotEmpty) {
        customer = _customers.firstWhereOrNull(
          (c) => c.id == widget.invoice.customerId,
        );
      }

      customer ??= _customers.firstWhereOrNull(
        (c) => c.name == widget.invoice.customerName,
      );

      if (customer != null && mounted) {
        final matchedCustomer = customer;
        setState(() {
          _selectedCustomer = matchedCustomer;
          _selectedCustomerId = matchedCustomer.id;
          _customerSearchController.text = matchedCustomer.name;
        });
      }
    });
  }

  /// إضافة عنصر إلى الفاتورة
  void _addInvoiceItem(ProductEntity product, double quantity) {
    // تحديد سعر الوحدة بناءً على نوع الفاتورة والأسعار المخصصة
    double unitPrice = 0;
    double purchasePrice = 0;
    double? sellingPrice = 0;
    double? costPrice = 0;
    final editingExistingItem =
        _editingItemIndex != null &&
        _editingItemIndex! >= 0 &&
        _editingItemIndex! < _invoiceItems.length;
    final originalEditingItem = editingExistingItem
        ? _invoiceItems[_editingItemIndex!]
        : null;

    // في وضع تعديل عنصر قائم، ابدأ بأسعاره الحالية ثم اسمح بتغييرها.
    final isManualReturnEdit =
        _selectedType == 'sales_return' &&
        editingExistingItem &&
        originalEditingItem!.itemId?.startsWith('manual_return_') == true;
    final editPrice = double.tryParse(
      SmartNumberFormatter.convertToEnglishNumbers(
        _itemPriceController.text
            .replaceAll(',', '')
            .replaceAll('،', '')
            .replaceAll(' ', '')
            .replaceAll(_formattingService.thousandsSeparator, '')
            .trim(),
      ),
    );
    final editPurchasePrice = double.tryParse(
      SmartNumberFormatter.convertToEnglishNumbers(
        _purchasePriceController.text
            .replaceAll(',', '')
            .replaceAll('،', '')
            .replaceAll(' ', '')
            .replaceAll(_formattingService.thousandsSeparator, '')
            .trim(),
      ),
    );
    final editSellingPrice = double.tryParse(
      SmartNumberFormatter.convertToEnglishNumbers(
        _sellingPriceController.text
            .replaceAll(',', '')
            .replaceAll('،', '')
            .replaceAll(' ', '')
            .replaceAll(_formattingService.thousandsSeparator, '')
            .trim(),
      ),
    );
    if (editingExistingItem) {
      purchasePrice = originalEditingItem!.purchasePrice ?? 0;
      costPrice = originalEditingItem.purchasePrice ?? 0;
      sellingPrice =
          originalEditingItem.sellingPrice ?? originalEditingItem.unitPrice;
      unitPrice = originalEditingItem.unitPrice;
    }

    // إذا كان المنتج جديد (مؤقت)، نستخدم أسعاره الخاصة مباشرة
    if (!editingExistingItem && product.id.startsWith('temp_')) {
      purchasePrice = product.costPrice ?? 0;
      sellingPrice = product.sellingPrice;
      costPrice = product.costPrice ?? 0;
    }

    final originalItem = editingExistingItem ? originalEditingItem : null;
    if (originalItem != null) {
      unitPrice = _selectedType == 'purchase'
          ? (editPurchasePrice ?? originalItem.unitPrice)
          : (isManualReturnEdit
                ? (editPrice ?? originalItem.unitPrice)
                : originalItem.unitPrice);
      sellingPrice = _selectedType == 'purchase'
          ? (editSellingPrice ??
                originalItem.sellingPrice ??
                originalItem.unitPrice)
          : (isManualReturnEdit
                ? (editPrice ?? originalItem.unitPrice)
                : originalItem.sellingPrice ?? originalItem.unitPrice);
      purchasePrice = _selectedType == 'purchase'
          ? (editPurchasePrice ?? originalItem.purchasePrice ?? unitPrice)
          : (originalItem.purchasePrice ?? 0);
      costPrice = purchasePrice;
    } else if (_selectedType == 'purchase') {
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
    } else if (editingExistingItem) {
      // السعر المعدل موجود في unitPrice أعلى الدالة.
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
        costPrice = product.costPrice ?? 0;
      }
    }

    final totalPrice = quantity * unitPrice;
    final editedItemName = _editItemNameController.text.trim().isNotEmpty
        ? _editItemNameController.text.trim()
        : product.name;

    // احتفظ ببيانات العنصر الأصلية عند تعديله، خصوصًا بيانات المرتجع.
    final existingItem =
        _editingItemIndex != null &&
            _editingItemIndex! >= 0 &&
            _editingItemIndex! < _invoiceItems.length
        ? _invoiceItems[_editingItemIndex!]
        : null;
    String? itemId = existingItem?.itemId;
    String? originalInvoiceId = existingItem?.originalInvoiceId;
    String? originalInvoiceNumber = existingItem?.originalInvoiceNumber;
    DateTime? originalSaleDate = existingItem?.originalSaleDate;
    double? originalUnitPrice = _selectedType == 'sales_return'
        ? existingItem?.unitPrice
        : null;
    final isManualReturnItem =
        _selectedType == 'sales_return' &&
        editingExistingItem &&
        originalEditingItem!.itemId?.startsWith('manual_return_') == true;

    final soldItem = _selectedType == 'sales_return' && !isManualReturnItem
        ? _findSoldItemForReturn(
            InvoiceItemEntity(
              productName: editedItemName,
              quantity: quantity,
              unit: product.unit,
              unitPrice: unitPrice,
              totalPrice: totalPrice,
              originalInvoiceId: originalEditingItem?.originalInvoiceId,
            ),
          )
        : null;
    if (_selectedType == 'sales_return') {
      // المادة اليدوية لا تُنسب إلى فاتورة بيع عند تعديل اسمها أو كميتها.
      // البحث عن المادة في المواد المشتراة للحصول على المعلومات الأصلية
      if (isManualReturnItem) {
        // سعر العنصر اليدوي قابل للتعديل، بخلاف سعر عنصر له فاتورة بيع أصلية.
        originalUnitPrice = null;
      }
      if (soldItem != null) {
        final alreadyReturnedOnThisInvoice = _invoiceItems
            .where(
              (returnedItem) =>
                  returnedItem.itemId == soldItem.itemId &&
                  returnedItem.originalInvoiceId == soldItem.originalInvoiceId,
            )
            .fold<double>(
              0,
              (sum, returnedItem) => sum + returnedItem.quantity,
            );
        final currentlyEditedReturnQuantity =
            editingExistingItem &&
                originalEditingItem!.itemId == soldItem.itemId &&
                originalEditingItem.originalInvoiceId ==
                    soldItem.originalInvoiceId
            ? originalEditingItem.quantity
            : 0.0;
        final maximumQuantityForThisLine =
            soldItem.quantity -
            alreadyReturnedOnThisInvoice +
            currentlyEditedReturnQuantity;
        if (quantity > maximumQuantityForThisLine) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'الكمية المتاحة لهذا المرتجع هي ${maximumQuantityForThisLine.clamp(0, double.infinity)} ${soldItem.unit}',
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
        originalUnitPrice = soldItem.unitPrice; // ✅ حفظ السعر الأصلي
      } else if (_editingItemIndex == null && itemId != null) {
        // المادة المرتجعة يدويًا لا تملك فاتورة بيع أصلية؛ احتفظ بربطها
        // بمنتج المخزون كي يستطيع المستودع زيادة الكمية وإلغاءها عند الحذف.
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
        : (_selectedType == 'sales_return' && soldItem != null)
        ? soldItem.unitPrice
        : (double.tryParse(
                SmartNumberFormatter.convertToEnglishNumbers(
                  _itemPriceController.text
                      .replaceAll(',', '')
                      .replaceAll('،', '')
                      .replaceAll(' ', '')
                      .replaceAll(_formattingService.thousandsSeparator, '')
                      .trim(),
                ),
              ) ??
              unitPrice);
    final double finalTotalPrice = quantity * finalUnitPrice;
    final updatedPurchasePrice =
        _selectedType == 'purchase' &&
            _purchasePriceController.text.trim().isNotEmpty
        ? double.tryParse(
            SmartNumberFormatter.convertToEnglishNumbers(
              _purchasePriceController.text
                  .replaceAll(',', '')
                  .replaceAll('،', '')
                  .replaceAll(' ', '')
                  .replaceAll(_formattingService.thousandsSeparator, '')
                  .trim(),
            ),
          )
        : (editingExistingItem
              ? originalEditingItem!.purchasePrice
              : costPrice);
    final updatedSellingPrice = _selectedType == 'purchase'
        ? (double.tryParse(
                SmartNumberFormatter.convertToEnglishNumbers(
                  _sellingPriceController.text
                      .replaceAll(',', '')
                      .replaceAll('،', '')
                      .replaceAll(' ', '')
                      .replaceAll(_formattingService.thousandsSeparator, '')
                      .trim(),
                ),
              ) ??
              sellingPrice)
        : finalUnitPrice;

    final manualReturnInventoryMatches = isManualReturnItem
        ? _products.where((candidate) {
            return candidate.isActive &&
                candidate.name.trim().toLowerCase() ==
                    editedItemName.toLowerCase();
          }).toList()
        : const <ProductEntity>[];
    final manualReturnInventoryProduct =
        manualReturnInventoryMatches.length == 1
        ? manualReturnInventoryMatches.single
        : null;
    final manualNameUnchanged =
        isManualReturnItem &&
        editedItemName.trim().toLowerCase() ==
            originalEditingItem.productName.trim().toLowerCase();
    final originalManualInventoryProduct = isManualReturnItem
        ? _products.firstWhereOrNull(
            (candidate) => candidate.id == originalEditingItem.productId,
          )
        : null;
    final updatedSoldItemId = isManualReturnItem ? null : soldItem?.itemId;
    final updatedProductId = isManualReturnItem
        ? manualReturnInventoryProduct?.id ??
              (manualNameUnchanged
                  ? originalManualInventoryProduct?.id ??
                        originalEditingItem.productId
                  : null)
        : _selectedType == 'sales_return'
        ? soldItem?.productId ?? originalEditingItem?.productId ?? product.id
        : _editingItemIndex != null && _editingItemIndex! < _invoiceItems.length
        ? _invoiceItems[_editingItemIndex!].productId
        : product.id.startsWith('temp_')
        ? null
        : product.id;
    final updatedUnit = isManualReturnItem
        ? originalEditingItem.unit
        : product.unit;

    final item = InvoiceItemEntity(
      productName: editedItemName,
      productId: updatedProductId,
      quantity: quantity,
      unit: updatedUnit,
      unitPrice: finalUnitPrice, // ✅ استخدام السعر الصحيح
      totalPrice: finalTotalPrice, // ✅ استخدام السعر الصحيح
      itemId: itemId,
      originalInvoiceId: originalInvoiceId,
      originalInvoiceNumber: originalInvoiceNumber,
      originalSaleDate: originalSaleDate,
      purchasePrice: updatedPurchasePrice,
      sellingPrice: updatedSellingPrice,
    );

    setState(() {
      if (_editingItemIndex != null &&
          _editingItemIndex! >= 0 &&
          _editingItemIndex! < _invoiceItems.length) {
        final originalItem = _invoiceItems[_editingItemIndex!];
        _invoiceItems[_editingItemIndex!] = InvoiceItemEntity(
          productName: item.productName,
          productId: isManualReturnItem
              ? item.productId
              : item.productId ?? originalItem.productId,
          quantity: item.quantity,
          unit: item.unit,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          itemId: updatedSoldItemId ?? item.itemId ?? originalItem.itemId,
          originalInvoiceId: isManualReturnItem
              ? null
              : item.originalInvoiceId ?? originalItem.originalInvoiceId,
          originalInvoiceNumber: isManualReturnItem
              ? null
              : item.originalInvoiceNumber ??
                    originalItem.originalInvoiceNumber,
          originalSaleDate: isManualReturnItem
              ? null
              : item.originalSaleDate ?? originalItem.originalSaleDate,
          isReturned: originalItem.isReturned,
          returnedQuantity: originalItem.returnedQuantity,
          originalQuantity: originalItem.originalQuantity,
          purchasePrice: item.purchasePrice ?? originalItem.purchasePrice,
          sellingPrice: item.sellingPrice ?? originalItem.sellingPrice,
        );
        _editingItemIndex = null;
      } else {
        _invoiceItems.add(item);
      }
      _calculateTotal();
      // تفريغ حقول الأسعار بعد الإضافة أو التحديث
      _purchasePriceController.clear();
      _sellingPriceController.clear();
      _itemPriceController.clear();
      _productSearchController.clear();
      _editItemNameController.clear();
      _quantityController.clear();
      _selectedProduct = null;
      _selectedSoldItem = null;
      _defaultPurchasePrice = 0;
      _defaultSellingPrice = 0;
    });
  }

  /// حساب المجموع الكلي
  void _calculateTotal() {
    _totalAmount = _invoiceItems.fold(
      0,
      (total, item) => total + item.totalPrice,
    );
  }

  List<InvoiceItemEntity> _applyPreviouslyReturnedQuantities(
    List<InvoiceItemEntity> soldItems,
    List<InvoiceEntity> invoices, {
    String? customerId,
  }) {
    final returnedBySaleItem = <String, double>{};
    for (final invoice in invoices) {
      if (!invoice.isSalesReturn ||
          invoice.id == widget.invoice.id ||
          (customerId != null && invoice.customerId != customerId)) {
        continue;
      }
      for (final returnedItem in invoice.returnedItems ?? const []) {
        if (returnedItem.originalInvoiceId.isEmpty) continue;
        final originalInvoice = invoices.firstWhereOrNull(
          (saleInvoice) =>
              saleInvoice.id == returnedItem.originalInvoiceId &&
              (customerId == null || saleInvoice.customerId == customerId),
        );
        if (originalInvoice == null) continue;
        final originalItem = originalInvoice.items.firstWhereOrNull(
          (saleItem) =>
              saleItem.itemId == returnedItem.itemId ||
              (saleItem.itemId == null &&
                  saleItem.productName == returnedItem.itemName),
        );
        if (originalItem == null) continue;
        final originalItemId = originalItem.itemId ?? originalItem.productName;
        final key = '${originalItemId}_${returnedItem.originalInvoiceId}';
        returnedBySaleItem.update(
          key,
          (quantity) => quantity + returnedItem.returnedQuantity,
          ifAbsent: () => returnedItem.returnedQuantity.toDouble(),
        );
      }
    }

    return soldItems.map((item) {
      final originalQuantity = item.originalQuantity ?? item.quantity;
      final returnedItemId = item.itemId ?? item.productName;
      final key = '${returnedItemId}_${item.originalInvoiceId ?? ''}';
      final returnedQuantity = returnedBySaleItem[key] ?? 0;
      // Other return invoices have already been subtracted above. Add this
      // invoice's own current return lines back so they can be edited/replaced.
      final currentReturnQuantity = _invoiceItems
          .where(
            (returnLine) =>
                returnLine.itemId == (item.itemId ?? item.productName) &&
                returnLine.originalInvoiceId == item.originalInvoiceId,
          )
          .fold<double>(0, (sum, returnLine) => sum + returnLine.quantity);
      final remainingQuantity =
          (originalQuantity - returnedQuantity + currentReturnQuantity).clamp(
            0.0,
            double.infinity,
          );
      return InvoiceItemEntity(
        productName: item.productName,
        productId: item.productId,
        quantity: remainingQuantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        totalPrice: remainingQuantity * item.unitPrice,
        itemId: item.itemId,
        originalInvoiceId: item.originalInvoiceId,
        originalInvoiceNumber: item.originalInvoiceNumber,
        originalSaleDate: item.originalSaleDate,
        returnedQuantity: returnedQuantity.toInt(),
        originalQuantity: originalQuantity,
      );
    }).toList();
  }

  /// جلب المواد المشتراة للعميل من الفواتير غير المؤرشفة
  Future<void> _loadSoldItemsForCustomer(String customerId) async {
    final generation = ++_soldItemsLoadGeneration;
    if (mounted) {
      setState(() {
        _soldItems = [];
        _filteredSoldItems = [];
        _selectedSoldItem = null;
      });
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;

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
          customerId: customerId,
        );
        if (!mounted || generation != _soldItemsLoadGeneration) return;
        setState(() {
          _soldItems = itemsWithReturnBalances;
          _filteredSoldItems = List.from(itemsWithReturnBalances);
        });
      });
    } on Exception catch (_) {
      // تجاهل أخطاء تحميل المواد المباعة.
    }
  }

  /// جلب جميع المواد المشتراة من جميع الفواتير (عند عدم تحديد عميل)
  Future<void> _loadAllSoldItems() async {
    final generation = ++_soldItemsLoadGeneration;
    if (mounted) {
      setState(() {
        _soldItems = [];
        _filteredSoldItems = [];
        _selectedSoldItem = null;
      });
    }
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
          _soldItems = itemsWithReturnBalances;
          _filteredSoldItems = List.from(itemsWithReturnBalances);
        });
      });
    } on Exception catch (_) {
      // تجاهل أخطاء تحميل المواد المباعة.
    }
  }

  void _setupChangeListeners() {
    // إضافة listeners لتتبع التغييرات
    _notesController.addListener(_onFieldChanged);
    _paidAmountController.addListener(_onFieldChanged);
    _discountController.addListener(_onFieldChanged);
    _cashAmountController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _hideCustomerSuggestionsOverlay();
    _hideProductSuggestionsOverlay();
    _notesController.dispose();
    _paidAmountController.dispose();
    _discountController.dispose();
    _taxAmountController.dispose();
    _taxRateController.dispose();
    _invoiceDateController.dispose();
    _manualReturnNameController.dispose();
    _manualReturnQuantityController.dispose();
    _manualReturnPriceController.dispose();
    _editItemNameController.dispose();
    _itemPriceController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _newProductPurchasePriceController.dispose();
    _newProductSellingPriceController.dispose();
    _newProductQuantityController.dispose();
    _cashAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CustomerBloc, CustomerState>(
          listenWhen: (previous, current) {
            return current is CustomerLoaded;
          },
          listener: (context, state) {
            if (state is CustomerLoaded) {
              _customers
                ..clear()
                ..addAll(state.customers);
              _filteredCustomers = List.from(_customers);

              // قد تصل قائمة العملاء بعد فتح الشاشة؛ لا نبحث إلا حين يكون
              // الحقل ما زال يعرض اسم الفاتورة الأصلية ولم يحرره المستخدم.
              if (_selectedCustomer == null &&
                  _customerSearchController.text.trim() ==
                      widget.invoice.customerName.trim()) {
                _findCustomerByNameAndPhone();
              }
            }
          },
        ),
        BlocListener<InventoryBloc, InventoryState>(
          listenWhen: (previous, current) {
            return current is InventoryLoaded;
          },
          listener: (context, state) {
            if (state is InventoryLoaded) {
              _products.clear();
              _products.addAll(state.products);
              _filteredProducts = List.from(_products);
              _shelves = state.shelves ?? [];
            }
          },
        ),
        BlocListener<InvoiceBloc, InvoiceState>(
          listenWhen: (previous, current) {
            return current is InvoiceError ||
                current is InvoiceOperationSuccess;
          },
          listener: (context, state) {
            if (state is InvoiceError && !_operationCompleted) {
              _operationCompleted = true;
              _handleError(state.message);
              failSaveOperation(errorMessage: state.message);
            } else if (state is InvoiceOperationSuccess &&
                !_operationCompleted) {
              _operationCompleted = true;
              // ✅ شاشة تعديل كاملة: بعد نجاح الحفظ
              // تعود للشاشة السابقة
              completeSaveOperation(successMessage: state.message);
              Navigator.of(context).pop(_savedInvoice);
              // أعد تحميل أرصدة المرتجع من البيانات المحفوظة بعد تحديث السجل.
              _refreshReturnedItemsForCurrentInvoice();
              // أرسل إشعار التحديث بعد نجاح العملية وببيانات العميل المحدّثة،
              // لا ببيانات الفاتورة القديمة.
              SectionNotificationService.notifyInvoiceUpdated(
                widget.invoice.copyWith(
                  customerId: _selectedCustomer?.id,
                  customerName:
                      _selectedCustomer?.name ??
                      _customerSearchController.text.trim(),
                  customerPhone:
                      _selectedCustomer?.phone ?? widget.invoice.customerPhone,
                ),
              );
            }
          },
        ),
      ],
      child: scaffold.ResponsiveScaffold(
        appBar: _buildAppBar(context),
        drawer: const InvoiceDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: BlocBuilder<InvoiceBloc, InvoiceState>(
          builder: (context, state) {
            final isLoading = state is InvoiceLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(context),
                  const SizedBox(height: 20),
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
                  'تعديل الفاتورة',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                    ),
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'نظام إدارة الفواتير الآشوري',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
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
      title: 'تعديل الفاتورة',
      subtitle: 'نظام إدارة الفواتير الآشوري',
      icon: Icons.edit,
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
            children: [
              _buildCustomerSearchField(),
              _buildInvoiceDateField(),
              _buildTypeDropdown(),
            ],
          ),
          const SizedBox(height: 20),

          // مبيعات النقد ذات العناصر تظهر عناصرها؛ إيصال الحساب منفصل عنها.
          if (_selectedType != 'cash' || !_isCashReceipt) ...[
            InfoCard(
              title: 'إضافة المنتجات',
              icon: Icons.shopping_cart,
              children: [
                _buildProductSearchField(),
                if (_selectedProduct != null && _editingItemIndex == null)
                  _buildSelectedProductDetailsCard(),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (_invoiceItems.isNotEmpty) ...[
            InfoCard(
              title: 'عناصر الفاتورة',
              icon: Icons.list_alt,
              children: [_buildInvoiceItemsList()],
            ),
            const SizedBox(height: 20),
          ],

          InfoCard(
            title: 'الملاحظات',
            icon: Icons.note,
            children: [_buildNotesField()],
          ),
          const SizedBox(height: 20),
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

          _buildActionButtons(isLoading),
        ],
      ),
    );
  }

  Widget _buildInvoiceDateField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        readOnly: true,
        controller: _invoiceDateController,
        decoration: InputDecoration(
          labelText: 'تاريخ الفاتورة',
          hintText: 'اختر تاريخ الفاتورة',
          prefixIcon: const Icon(
            Icons.calendar_month,
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
        onTap: () async {
          final currentDate = _invoiceDate ?? DateTime.now();
          final selectedDate = await showDatePicker(
            context: context,
            initialDate: currentDate,
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );
          if (selectedDate != null && mounted) {
            setState(() {
              _invoiceDate = selectedDate;
              _invoiceDateController.text = _formattingService.formatDate(
                selectedDate,
              );
              _onFieldChanged();
            });
          }
        },
      ),
    );
  }

  Widget _buildTypeDropdown() {
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
        items: const [
          DropdownMenuItem(value: 'sales', child: Text('فاتورة مبيعات')),
          DropdownMenuItem(value: 'purchase', child: Text('فاتورة مشتريات')),
          DropdownMenuItem(value: 'cash', child: Text('فاتورة نقدية')),
          DropdownMenuItem(value: 'subscription', child: Text('اشتراك')),
          DropdownMenuItem(value: 'sales_return', child: Text('مرتجع مبيعات')),
        ],
        onChanged: (value) {
          if (value != 'sales_return' &&
              _selectedType == 'sales_return' &&
              _invoiceItems.any(
                (item) => item.itemId?.startsWith('manual_return_') == true,
              )) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'احذف المواد المرتجعة اليدوية قبل تغيير نوع الفاتورة',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          final wasSalesReturn = _selectedType == 'sales_return';
          setState(() {
            _selectedType = value;
            if (value != 'sales_return') {
              _soldItemsLoadGeneration++;
              _soldItems = [];
              _filteredSoldItems = [];
              _selectedSoldItem = null;
              _showSoldItemsSuggestions = false;
              _productSearchController.clear();
              if (wasSalesReturn) {
                _invoiceItems.removeWhere(
                  (item) => item.itemId?.startsWith('manual_return_') == true,
                );
                _calculateTotal();
              }
            }
            _onFieldChanged();
          });
          if (value == 'sales_return') {
            _refreshReturnedItemsForCurrentInvoice();
          }
        },
      ),
    );
  }

  Widget _buildInvoiceItemsList() {
    return Column(
      children: [
        ...List.generate(_invoiceItems.length, (index) {
          final item = _invoiceItems[index];
          final isEditing = _editingItemIndex == index;
          final editColor = AssyrianTheme.primaryGold.withValues(alpha: 0.08);
          final editBorderColor = AssyrianTheme.primaryGold.withValues(
            alpha: 0.5,
          );
          return Column(
            children: [
              Container(
                margin: EdgeInsets.only(bottom: isEditing ? 0 : 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEditing ? editColor : Colors.grey[50],
                  borderRadius: isEditing
                      ? BorderRadius.vertical(top: Radius.circular(10.r))
                      : BorderRadius.circular(8),
                  border: Border.all(
                    color: isEditing ? editBorderColor : Colors.grey[200]!,
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
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${item.quantity} ${item.unit}',
                        style: TextStyle(fontSize: 12.sp),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formattingService.formatCurrency(item.unitPrice),
                        style: TextStyle(fontSize: 12.sp),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formattingService.formatCurrency(item.totalPrice),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AssyrianTheme.primaryGold,
                          fontWeight: FontWeight.w600,
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
              if (isEditing) ...[
                Container(
                  padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 12.h),
                  decoration: BoxDecoration(
                    color: editColor,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(10.r),
                    ),
                    border: Border(
                      left: BorderSide(color: editBorderColor),
                      right: BorderSide(color: editBorderColor),
                      bottom: BorderSide(color: editBorderColor),
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
      ],
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

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'ملاحظات',
        hintText: 'أدخل أي ملاحظات إضافية',
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
      onChanged: (value) => _onFieldChanged(),
    );
  }

  Widget _buildActionButtons(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: LoadingButton(
        text: 'حفظ التغييرات',
        onPressed: _canEdit ? _updateInvoice : null,
        isLoading: isLoading,
        icon: Icons.save,
        backgroundColor: _canEdit
            ? AssyrianTheme.primaryGold
            : Colors.grey[300]!,
        foregroundColor: _canEdit ? AssyrianTheme.deepBlue : Colors.grey[600]!,
      ),
    );
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
      _showSoldItemsSuggestions = false;
      _selectedProduct =
          product ??
          ProductEntity(
            id: item.productName.startsWith('temp_')
                ? item.productName
                : 'edit_${item.productName.hashCode.abs()}_${widget.invoice.id}',
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
      _itemPriceController.text = _selectedType == 'purchase'
          ? _formattingService.formatNumber(item.unitPrice)
          : _formattingService.formatNumber(item.unitPrice);
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
  }

  void _removeItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
      if (_editingItemIndex == index) {
        _editingItemIndex = null;
        _productSearchController.clear();
        _editItemNameController.clear();
        _quantityController.clear();
        _itemPriceController.clear();
        _selectedProduct = null;
      } else if (_editingItemIndex != null && _editingItemIndex! > index) {
        _editingItemIndex = _editingItemIndex! - 1;
      }
      // ✅ إعادة حساب الإجمالي بعد الحذف — بدونها يبقى
      // _totalAmount قديمًا ولا يطابق مجموع العناصر،
      // فيرفض الحفظ برسالة "إجمالي الفاتورة لا يساوي مجموع الأسعار".
      _calculateTotal();
      _onFieldChanged();
    });
  }

  Future<void> _updateInvoice() async {
    // التحقق من الصلاحية أولاً
    if (!_canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ليس لديك صلاحية لتعديل هذه الفاتورة'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    // إيصال الحساب يتطلب عميلاً؛ مبيعات النقد يمكن حفظها بلا عميل.
    if (_selectedType == 'cash' &&
        _isCashReceipt &&
        _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار عميل للفاتورة النقدية'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // تحقق مبلغ الإيصال فقط، لا مبلغ مبيعات المواد.
    if (_selectedType == 'cash' && _isCashReceipt && _cashAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إدخال مبلغ نقدي صحيح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // لا نحفظ اسمًا مكتوبًا يدويًا كعميل؛ يجب اختيار عميل من القائمة.
    // ذلك يمنع بقاء معرف العميل السابق وربط الفاتورة أو الإشعار به خطأً.
    if ((_selectedType != 'cash' || _isCashReceipt) &&
        _customerSearchController.text.trim().isNotEmpty &&
        _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار العميل من قائمة الاقتراحات'),
          backgroundColor: Colors.orange,
        ),
      );
      _showCustomerSuggestionsOverlay();
      return;
    }

    // إيصال العميل النقدي منفصل عن المواد؛ بقية الفواتير تتطلب عناصر.
    if (_invoiceItems.isEmpty &&
        _selectedType != 'cash' &&
        _selectedType != 'sales_return') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إضافة عنصر واحد على الأقل للفاتورة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
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

    String updatedBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        updatedBy = switchedUser['id'] as String;
      } else {
        updatedBy = currentUser.uid;
      }
    } on Exception catch (_) {
      updatedBy = currentUser.uid;
    }

    // الحصول على بيانات العميل المحدد
    final selectedCustomer =
        _selectedCustomer ??
        _customers.firstWhereOrNull(
          (customer) => customer.id == _selectedCustomerId,
        ) ??
        CustomerEntity(
          id: _selectedCustomerId ?? '',
          organizationEmail: '',
          name: _customerSearchController.text.trim().isNotEmpty
              ? _customerSearchController.text.trim()
              : widget.invoice.customerName,
          email: '',
          phone: widget.invoice.customerPhone,
          totalPurchases: 0,
          totalDebt: 0,
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    // حساب المجموع النهائي (بعد الخصم والضريبة)
    final totalAfterDiscount = _totalAmount - _currentDiscountAmount;
    final totalAfterDiscountAndTax = (totalAfterDiscount + _taxAmount).clamp(
      0.0,
      double.infinity,
    );

    final isCashReceipt =
        _selectedType == 'cash' && widget.invoice.isCashAccountReceipt;
    final isCashSale =
        _selectedType == 'cash' &&
        !isCashReceipt &&
        widget.invoice.cashAmount > 0;
    final cashAmount = isCashReceipt
        ? _cashAmount
        : isCashSale
        ? totalAfterDiscountAndTax
        : widget.invoice.totalAmount;
    final cashReceiptSign =
        isCashReceipt &&
            (_cashTransactionType == 'payment' ||
                _cashTransactionType == 'clearance')
        ? -1.0
        : 1.0;
    final totalAmount = _selectedType == 'cash'
        ? (isCashReceipt || isCashSale
              ? cashAmount
              : widget.invoice.totalAmount)
        : totalAfterDiscountAndTax;
    final currentPaid = _currentPaidAmount;

    // للفاتورة النقدية: استخدام الإشارة الصحيحة
    final paidAmount = _selectedType == 'cash'
        ? (isCashReceipt ? cashAmount * cashReceiptSign : totalAmount)
        : (_selectedType == 'purchase' || _selectedType == 'sales_return')
        ? totalAfterDiscountAndTax
        : currentPaid;

    final remainingAmount =
        (_selectedType == 'cash' ||
            _selectedType == 'purchase' ||
            _selectedType == 'sales_return')
        ? 0.0
        : (totalAfterDiscountAndTax - paidAmount).clamp(0.0, double.infinity);

    // حافظ على العناصر الوصفية لإيصالات العميل (المبلغ/تصفير الحساب)،
    // ولا تستبدل وصفها بعناصر فاتورة البيع النقدية عند تحديثها.
    final updatedItems = isCashReceipt
        ? const <InvoiceItemEntity>[]
        : _invoiceItems;

    final calculatedStatus =
        (_selectedType == 'cash' ||
            _selectedType == 'purchase' ||
            _selectedType == 'sales_return')
        ? 'paid'
        : (remainingAmount <= 0
              ? 'paid'
              : paidAmount > 0
              ? 'partial'
              : 'unpaid');

    // التحقق من حد الائتمان للفواتير غير المدفوعة (المبيعات والاشتراكات)
    if ((_selectedType == 'sales' || _selectedType == 'subscription') &&
        selectedCustomer.creditLimit != null) {
      // حساب الفرق في المبلغ المتبقي
      final oldRemainingAmount = widget.invoice.remainingAmount;
      final newRemainingAmount = remainingAmount;
      final debtChange = newRemainingAmount - oldRemainingAmount;

      if (debtChange > 0) {
        // إذا كان هناك زيادة في الدين
        final newTotalDebt = selectedCustomer.totalDebt + debtChange;
        // التحقق من حد الائتمان فقط إذا كان الحساب الجديد موجب (عليه)
        if (newTotalDebt > 0 && newTotalDebt > selectedCustomer.creditLimit!) {
          if (!mounted) return;

          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 24.sp),
                  SizedBox(width: 8.w),
                  const Text('تحذير حد الائتمان'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تجاوز حد الائتمان المسموح!',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    selectedCustomer.totalDebt > 0
                        ? 'الحساب الحالي (عليك): ${_formatDebtDisplay(selectedCustomer.totalDebt)}'
                        : selectedCustomer.totalDebt < 0
                        ? 'الحساب الحالي (لك): ${_formatDebtDisplay(selectedCustomer.totalDebt.abs())}'
                        : 'الحساب الحالي: ${_formatDebtDisplay(selectedCustomer.totalDebt)}',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  Text(
                    'زيادة الدين: ${_formattingService.formatCurrency(debtChange)}',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  Text(
                    'المجموع الجديد: عليه ${_formattingService.formatCurrency(newTotalDebt)}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'حد الائتمان: ${_formattingService.formatCurrency(selectedCustomer.creditLimit!)}',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'هل تريد المتابعة رغم ذلك؟',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.black),
                  ),
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
          if (shouldContinue != true) return;
        }
      }
    }

    // التحقق من حالة المخزون وإظهار تأكيد إذا لزم الأمر
    final isSalesType =
        _selectedType == 'sales' ||
        (_selectedType == 'cash' && !isCashReceipt) ||
        _selectedType == 'subscription';

    var stockIssues = [];

    for (final item in _invoiceItems) {
      final product = _products
          .where((p) => p.name == item.productName)
          .firstOrNull;
      if (product == null) continue;

      if (isSalesType && product.isOutOfStock) {
        stockIssues.add('• ${item.productName}: نافد من المخزون');
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
              const Text('تأكيد تعديل الفاتورة'),
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
                'هل تريد المتابعة وتعديل الفاتورة؟',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.black)),
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
      if (shouldContinue != true) return;
    }

    // حساب الحساب بعد الفاتورة المحدثة
    // يجب استخدام الفرق في remainingAmount وليس totalAmount
    final originalRemainingAmount = widget.invoice.remainingAmount;
    final newRemainingAmount = remainingAmount;
    final remainingAmountDifference =
        newRemainingAmount - originalRemainingAmount;

    // إعادة حساب الحساب بعد الفاتورة بناءً على نوع الفاتورة
    final originalBalanceAfter =
        widget.invoice.balanceAfterInvoice ??
        (widget.invoice.balanceBeforeInvoice ?? 0);
    double newBalanceAfter;
    if (_selectedType == 'sales' || _selectedType == 'subscription') {
      // إذا تغير العميل، احسب رصيد العميل الجديد انطلاقاً من رصيده الحالي.
      // أما عند بقاء العميل نفسه فنعدّل الرصيد السابق بفرق الفاتورة.
      final customerChanged = widget.invoice.customerId != selectedCustomer.id;
      newBalanceAfter = customerChanged
          ? selectedCustomer.totalDebt + remainingAmount
          : originalBalanceAfter + remainingAmountDifference;
    } else if (_selectedType == 'purchase') {
      // المشتريات تقلل الدين
      final oldTotal = widget.invoice.totalAmount;
      final newTotal = totalAfterDiscountAndTax;
      newBalanceAfter = originalBalanceAfter - (newTotal - oldTotal);
    } else if (_selectedType == 'sales_return') {
      // مرجع البيع
      final oldTotal = widget.invoice.totalAmount;
      final newTotal = totalAfterDiscountAndTax;
      newBalanceAfter = _refundMethod == 'credit'
          ? originalBalanceAfter - (newTotal - oldTotal)
          : originalBalanceAfter;
    } else if (_selectedType == 'cash') {
      // إيصالات الحساب تؤثر على دين العميل؛ بيع النقد لا يغيّر الدين.
      if (isCashReceipt) {
        final oldPaid = widget.invoice.paidAmount;
        newBalanceAfter = originalBalanceAfter - (paidAmount - oldPaid);
      } else if (isCashSale && widget.invoice.customerId != null) {
        final customerChanged =
            widget.invoice.customerId != selectedCustomer.id;
        newBalanceAfter = customerChanged
            ? selectedCustomer.totalDebt
            : originalBalanceAfter;
      } else {
        newBalanceAfter = originalBalanceAfter;
      }
    } else {
      newBalanceAfter = 0;
    }

    // ✅ إصلاح (2026-10-09): بناء المواد المرتجعة عند
    // مرجع البيع بنفس طريقة صفحة الإنشاء. بدون هذا،
    // كانت الفاتورة المحدثة تُرسل بدون isSalesReturn/
    // returnedItems/refundMethod، فتفقد عملية التحديث
    // أثر مرجع البيع على المخزون (لا تُعيد الكمية
    // المرتجعة) وعلى دين العميل (خصم الحساب) وعلى
    // الصندوق (الرد النقدي) — لأن المستودع يعتمد على
    // هذه الحقول لمعرفة أن الفاتورة مرجع بيع.
    List<ReturnedItemEntity>? returnedItems;
    if (_selectedType == 'sales_return') {
      returnedItems = _invoiceItems.map((item) {
        final isManualReturn =
            item.itemId?.startsWith('manual_return_') == true;
        final soldItem = isManualReturn ? null : _findSoldItemForReturn(item);
        final soldQuantity =
            soldItem?.originalQuantity ?? soldItem?.quantity ?? 0;
        final hasOriginalSale =
            item.originalInvoiceId != null &&
            item.originalInvoiceId!.isNotEmpty;
        final productId = isManualReturn
            ? item.productId
            : item.productId ?? soldItem?.productId;
        return ReturnedItemEntity(
          itemId: item.itemId ?? item.productName,
          itemName: item.productName,
          productId: productId,
          purchasedQuantity: hasOriginalSale ? soldQuantity.toInt() : 0,
          returnedQuantity: item.quantity.toInt(),
          unitPrice: item.unitPrice,
          saleDate: item.originalSaleDate ?? _invoiceDate ?? DateTime.now(),
          originalInvoiceId: item.originalInvoiceId ?? '',
          originalInvoiceNumber: item.originalInvoiceNumber,
        );
      }).toList();
    }

    // إنشاء الفاتورة المحدثة
    final updatedInvoice = InvoiceEntity(
      id: widget.invoice.id,
      invoiceNumber:
          widget.invoice.invoiceNumber, // الحفاظ على رقم الفاتورة الأصلي
      customerName: selectedCustomer.name,
      customerPhone: selectedCustomer.phone,
      customerId: selectedCustomer.id, // إضافة معرف العميل الثابت
      invoiceDate: _invoiceDate!,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      status: calculatedStatus,
      type: _selectedType!,
      items: updatedItems,
      cashTransactionType: _selectedType == 'cash'
          ? (isCashReceipt
                ? (widget.invoice.effectiveCashTransactionType == 'clearance'
                      ? 'clearance'
                      : _cashTransactionType)
                : 'sale')
          : null,
      cashAmount: _selectedType == 'cash'
          ? (isCashReceipt ? cashAmount : 0)
          : widget.invoice.cashAmount,
      cashUserNote: _selectedType == 'cash'
          ? (isCashReceipt
                ? _notesController.text.trim()
                : widget.invoice.cashUserNote)
          : null,
      notes: _selectedType == 'cash'
          ? (isCashReceipt
                ? (widget.invoice.effectiveCashTransactionType == 'clearance'
                      ? widget.invoice.notes
                      : '${_cashTransactionType == 'receipt' ? 'إيصال نقدي - استلام مبلغ نقدي من العميل' : 'إيصال نقدي - إعطاء مبلغ نقدي للعميل'}${_notesController.text.trim().isEmpty ? '' : '\nملاحظة: ${_notesController.text.trim()}'}')
                : widget.invoice.notes)
          : _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      organizationEmail: currentUser.email!,
      createdAt: widget.invoice.createdAt,
      updatedAt: DateTime.now(),
      createdBy: widget.invoice.createdBy,
      updatedBy: updatedBy,
      balanceBeforeInvoice: widget.invoice.balanceBeforeInvoice,
      balanceAfterInvoice: newBalanceAfter,
      isArchived: widget.invoice.isArchived, // الحفاظ على حالة الأرشفة الأصلية
      discountAmount: _currentDiscountAmount, // إضافة الخصم
      taxAmount: _taxAmount, // إضافة الضريبة
      taxes: _taxes.isNotEmpty ? _taxes : null, // إضافة قائمة الضرائب
      // ✅ إصلاح (2026-10-09): تمرير حقول مرجع البيع —
      // كانت مفقودة تماماً فتُفقد أثر المرتجع عند
      // التحديث. عند تحويل الفاتورة من مرجع بيع إلى
      // نوع آخر تُرسل بقيم فارغة ليحذفها المستودع
      // من المستند ولا تبقى عالقة تفسد العمليات
      // اللاحقة (الحذف/التحديث).
      isSalesReturn: _selectedType == 'sales_return',
      refundMethod: _selectedType == 'sales_return' ? _refundMethod : null,
      returnedItems: returnedItems,
      originalInvoiceId: _selectedType == 'sales_return'
          ? widget.invoice.originalInvoiceId
          : null,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ InvoiceBloc قبل العملية غير المتزامنة
    final invoiceBloc = context.read<InvoiceBloc>();

    // ✅ إصلاح (2026-10-11): حفظ المنتجات الجديدة
    // يسبق معاملة الفاتورة وبكمية صفرية.
    // المعاملة تقرأ المنتجات ثم تزيد كمية
    // الشراء ذرياً داخل runTransaction. لو
    // أُنشئ المنتج بعد المعاملة لم يكن في
    // لقطتها فُقد أثر الشراء، ولو أُنشئ بكمية
    // الشراء تضاعفت الكمية (مرة هنا ومرة في
    // المعاملة). الآن يُنشأ قبلها بصفر فتزيده
    // المعاملة مرة واحدة فقط.
    if (_selectedType == 'purchase') {
      await _saveNewProductsToInventory();
    }

    // استخدام النظام الجديد لإدارة عملية الحفظ
    performBlocSaveOperation(
      triggerSave: () {
        _savedInvoice = updatedInvoice;
        invoiceBloc.add(
          UpdateInvoiceEvent(updatedInvoice, previousInvoice: widget.invoice),
        );
      },
      successMessage: 'تم تحديث الفاتورة بنجاح',
      loadingMessage: 'جاري تحديث الفاتورة...',
    );
  }

  void _handleError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'إعادة المحاولة',
          textColor: Colors.white,
          onPressed: _updateInvoice,
        ),
      ),
    );
  }

  // ==================== Functions copied from CreateInvoicePage ====================

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
    final detailsBorder = Border(
      left: BorderSide(color: detailsColor),
      right: BorderSide(color: detailsColor),
      bottom: BorderSide(color: detailsColor),
    );

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
                              _selectedCustomerId = null;
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
                    // بمجرد بدء تعديل النص، لا نحتفظ بالعميل السابق كاختيار.
                    // يُعاد تحديده فقط عند اختيار اقتراح أو إدخال قيمة مطابقة.
                    _selectedCustomer = null;
                    _selectedCustomerId = null;
                    if (value.isEmpty) {
                      _filteredCustomers = List.from(_customers);
                      _hideCustomerSuggestionsOverlay();
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
                        _selectedCustomer = exactMatch;
                        _selectedCustomerId = exactMatch.id;
                        _hideCustomerSuggestionsOverlay();

                        // جلب المواد المباعة للعميل إذا كانت فاتورة مرجع بيع
                        if (_selectedType == 'sales_return') {
                          _loadSoldItemsForCustomer(exactMatch.id);
                        }
                      } else {
                        _selectedCustomer = null;
                        // عند إلغاء تحديد العميل في وضع مرجع البيع، تحميل جميع المواد
                        if (_selectedType == 'sales_return') {
                          _loadAllSoldItems();
                        }
                      }

                      // عرض الاقتراحات
                      _showCustomerSuggestionsOverlay();
                    }
                  });
                },
                onTap: () {
                  _showCustomerSuggestionsOverlay();
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
                border: detailsBorder,
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
                border: detailsBorder,
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
        if (_soldItems.isEmpty) ...[
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
                        _selectedSoldItem = null;
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
                _selectedSoldItem = null;
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

                // لا نختار أول فاتورة تلقائيًا عند تطابق الاسم؛ قد يكون
                // المنتج نفسه موجودًا في فواتير بيع متعددة. يجب أن يختار
                // المستخدم السطر الذي يعرض رقم الفاتورة وتاريخ البيع الصحيحين.
                _selectedSoldItem = null;
                _selectedProduct = null;
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
              itemCount: _filteredSoldItems.length,
              itemBuilder: (context, index) {
                final item = _filteredSoldItems[index];
                final isManualReturnItem =
                    item.itemId?.startsWith('manual_return_') == true;
                final currentInvoiceReturnQuantity = _invoiceItems
                    .where(
                      (returnedItem) =>
                          returnedItem.itemId == item.itemId &&
                          returnedItem.originalInvoiceId ==
                              item.originalInvoiceId,
                    )
                    .fold<double>(
                      0,
                      (sum, returnedItem) => sum + returnedItem.quantity,
                    );
                // This row holds the maximum allowed for this return invoice;
                // add back its current lines because editing replaces them.
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
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    tileColor:
                        (item.returnedQuantity != null &&
                                item.returnedQuantity! > 0) ||
                            item.itemId?.startsWith('manual_return_') == true
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
                                  (item.returnedQuantity != null &&
                                          item.returnedQuantity! > 0) ||
                                      item.itemId?.startsWith(
                                            'manual_return_',
                                          ) ==
                                          true
                                  ? Colors.orange[700]
                                  : AssyrianTheme.deepBlue,
                            ),
                          ),
                        ),
                        // ✅ أيقونة تمييز المواد المرتجعة مسبقاً
                        if ((item.returnedQuantity != null &&
                                item.returnedQuantity! > 0) ||
                            item.itemId?.startsWith('manual_return_') == true)
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
                                  item.itemId?.startsWith('manual_return_') ==
                                          true
                                      ? 'مرتجع يدوي'
                                      : 'تم إرجاع ${item.returnedQuantity}',
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
                                  // ✅ عرض الكمية المشتراة والمرتجعة
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.grey[700],
                                      ),
                                      children: [
                                        TextSpan(
                                          text: isManualReturnItem
                                              ? 'مرتجع يدوي'
                                              : 'المتبقي للإرجاع: ',
                                        ),
                                        TextSpan(
                                          text:
                                              '${isManualReturnItem ? item.quantity : availableReturnQuantity} ${item.unit} ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AssyrianTheme.deepBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ✅ عرض الكمية المرتجعة إن وجدت
                                  if (!isManualReturnItem &&
                                      item.returnedQuantity != null &&
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
                                                '${availableReturnQuantity.toStringAsFixed(2)} ${item.unit}',
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
                        if (item.itemId?.startsWith('manual_return_') == true ||
                            item.returnedQuantity == null ||
                            item.returnedQuantity == 0) ...[
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(Icons.inventory_2, size: 14.sp),
                              SizedBox(width: 4.w),
                              Text(
                                item.itemId?.startsWith('manual_return_') ==
                                        true
                                    ? 'كمية المرتجع: ${item.quantity} ${item.unit}'
                                    : 'الكمية الأصلية: ${item.quantity} ${item.unit}',
                              ),
                            ],
                          ),
                        ],
                        if (item.itemId?.startsWith('manual_return_') !=
                            true) ...[
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
                      ],
                    ),
                    onTap: availableReturnQuantity <= 0 || isManualReturnItem
                        ? null
                        : () {
                            setState(() {
                              // احفظ السطر المحدد من الفاتورة الأصلية بدقة.
                              _selectedSoldItem = item;
                              _selectedProduct = ProductEntity(
                                id:
                                    item.productId ??
                                    item.itemId ??
                                    item.productName,
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
                                    'REF:${item.originalInvoiceNumber ?? ''}',
                              );
                              _productSearchController.text = item.productName;
                              _quantityController.text = _formattingService
                                  .formatNumber(availableReturnQuantity);
                              _showSoldItemsSuggestions = false;
                            });
                          },
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        if (_showManualReturnForm) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة مادة مرتجعة يدويًا',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _manualReturnNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم المادة *',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
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
                        decoration: const InputDecoration(
                          labelText: 'الكمية *',
                        ),
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
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addManualReturnItem,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة إلى المرتجع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AssyrianTheme.primaryGold,
                      foregroundColor: AssyrianTheme.deepBlue,
                    ),
                  ),
                ),
                Text(
                  'إذا طابق الاسم منتجًا في المخزون، ستُضاف الكمية المرتجعة إليه تلقائيًا.',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ] else ...[
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _showManualReturnForm = true);
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text('إضافة مادة غير موجودة في الفواتير'),
          ),
        ],

        // حقول الإضافة لا تعرض بيانات العنصر الجاري تعديله.
        if (_selectedProduct != null && _editingItemIndex == null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
            ],
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
                id: 'edit_${index}_${widget.invoice.id}',
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

  Color get _productDetailsColor {
    final product = _selectedProduct;
    if (product == null || _editingItemIndex != null) {
      return AssyrianTheme.primaryGold;
    }
    if (product.id.startsWith('temp_')) return Colors.blue;
    if (product.isOutOfStock) return Colors.red;
    if (product.isLowStock) return Colors.orange;
    return Colors.blue;
  }

  Widget _buildNormalProductSearchField() {
    final hasAttachedDetails =
        _selectedProduct != null && _editingItemIndex == null;
    final searchBorderRadius = hasAttachedDetails
        ? BorderRadius.vertical(top: Radius.circular(10.r))
        : BorderRadius.circular(8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            bottom: _editingItemIndex != null || hasAttachedDetails ? 0 : 16.h,
          ),
          padding: EdgeInsets.zero,
          child: Row(
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
                        fillColor: _productDetailsColor.withValues(alpha: 0.1),
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
                                    _hideProductSuggestionsOverlay();
                                    _quantityController.clear();
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
                                  color: _productDetailsColor,
                                ),
                              )
                            : null,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: searchBorderRadius,
                          borderSide: BorderSide(
                            color: hasAttachedDetails
                                ? _productDetailsColor
                                : AssyrianTheme.primaryGold,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value.isEmpty) {
                            _filteredProducts = List.from(_products);
                            _hideProductSuggestionsOverlay();
                            _selectedProduct = null;
                          } else {
                            if (_editingItemIndex != null &&
                                _productSearchController.text ==
                                    _invoiceItems[_editingItemIndex!]
                                        .productName &&
                                value.trim() ==
                                    _invoiceItems[_editingItemIndex!]
                                        .productName) {
                              _selectedProduct = ProductEntity(
                                id: 'edit_${_editingItemIndex!}_${widget.invoice.id}',
                                organizationEmail: '',
                                name: value.trim(),
                                quantity: 0,
                                unit: _invoiceItems[_editingItemIndex!].unit,
                                sellingPrice:
                                    _invoiceItems[_editingItemIndex!].unitPrice,
                                minQuantity: 0,
                                costPrice: _invoiceItems[_editingItemIndex!]
                                    .purchasePrice,
                                createdBy: '',
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              );
                              return;
                            }
                            _selectedProduct = null;
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
                            final exactMatch = _filteredProducts
                                .firstWhereOrNull(
                                  (p) =>
                                      p.name.toLowerCase() ==
                                          value.toLowerCase() ||
                                      p.barcode?.toLowerCase() ==
                                          value.toLowerCase(),
                                );

                            // إذا لم يكن هناك تطابق تام، أنشئ منتجًا مؤقتًا
                            // فقط عند الإضافة؛ في التعديل نبقي اسم العنصر المكتوب.
                            if (exactMatch == null) {
                              if (_editingItemIndex != null) {
                                _selectedProduct = ProductEntity(
                                  id: 'edit_${_editingItemIndex!}_${widget.invoice.id}',
                                  organizationEmail: '',
                                  name: value.trim(),
                                  quantity: 0,
                                  unit: _invoiceItems[_editingItemIndex!].unit,
                                  sellingPrice:
                                      _invoiceItems[_editingItemIndex!]
                                          .unitPrice,
                                  minQuantity: 0,
                                  costPrice: _invoiceItems[_editingItemIndex!]
                                      .purchasePrice,
                                  createdBy: '',
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );
                              } else {
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
                                        FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid ??
                                        'unknown',
                                  );
                                  _quantityController.text = '1';
                                  _newProductQuantityController.text = '1';
                                  _itemPriceController.clear();
                                  _hideProductSuggestionsOverlay();
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
                                  if (_editingItemIndex == null) {
                                    _quantityController.text = '1';
                                    _itemPriceController.clear();
                                  }
                                  _newProductQuantityController.text = '1';
                                  _hideProductSuggestionsOverlay();
                                  _scrollProductDetailsIntoView();
                                });
                              } else {
                                setState(() {
                                  _selectedProduct = null;
                                });
                              }
                            }

                            // عرض الاقتراحات
                            if (_filteredProducts.isNotEmpty) {
                              _showProductSuggestionsOverlay();
                            } else {
                              _hideProductSuggestionsOverlay();
                            }
                            _scrollProductDetailsIntoView();
                          }
                        });
                      },
                      onTap: () {
                        _startProductSearch();
                        _showProductSuggestionsOverlay();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedProductDetailsCard() {
    final borderColor = _editingItemIndex != null
        ? _productDetailsColor.withValues(alpha: 0.5)
        : _productDetailsColor;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _productDetailsColor.withValues(
          alpha: _editingItemIndex != null ? 0.08 : 0.1,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.r)),
        border: Border(
          top: _editingItemIndex != null
              ? BorderSide(color: borderColor)
              : BorderSide.none,
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
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
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (_editingItemIndex == null)
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
                )
              else
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
                          (item) => item.productName == _selectedProduct!.name,
                        );
                        if (existingIndex != -1) {
                          final existingItem = _invoiceItems[existingIndex];
                          _invoiceItems[existingIndex] = InvoiceItemEntity(
                            productName: existingItem.productName,
                            quantity: newQuantity,
                            unit: existingItem.unit,
                            unitPrice: existingItem.unitPrice,
                            totalPrice: newQuantity * existingItem.unitPrice,
                            itemId: existingItem.itemId,
                            originalInvoiceId: existingItem.originalInvoiceId,
                            originalInvoiceNumber:
                                existingItem.originalInvoiceNumber,
                            originalSaleDate: existingItem.originalSaleDate,
                            isReturned: existingItem.isReturned,
                            returnedQuantity: existingItem.returnedQuantity,
                            originalQuantity: existingItem.originalQuantity,
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
              'تحذير: هذا المنتج نافد من المخزون',
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
          if (_editingItemIndex == null &&
              _selectedProduct!.id.startsWith('temp_')) ...[
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
                            _newProductPurchasePriceController.text.isEmpty) {
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
                            _newProductSellingPriceController.text.isNotEmpty) {
                          setState(() {
                            _newProductSellingPriceController.text = '';
                          });
                        }
                        // عند فقدان التركيز، إذا كان الحقل فارغاً يعود 0
                        if (!hasFocus &&
                            _newProductSellingPriceController.text.isEmpty) {
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
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        // عند التركيز على الحقل، يمسح السعر
                        if (hasFocus &&
                            _newProductSellingPriceController.text.isNotEmpty) {
                          setState(() {
                            _newProductSellingPriceController.text = '';
                          });
                        }
                        // عند فقدان التركيز، إذا كان الحقل فارغاً يعود 0
                        if (!hasFocus &&
                            _newProductSellingPriceController.text.isEmpty) {
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
                      if (hasFocus &&
                          _defaultPurchasePrice > 0 &&
                          _purchasePriceController.text.isNotEmpty) {
                        setState(() => _purchasePriceController.clear());
                      }
                      if (!hasFocus &&
                          _editingItemIndex == null &&
                          _defaultPurchasePrice > 0 &&
                          _purchasePriceController.text.isEmpty) {
                        setState(() {
                          _purchasePriceController.text = _formattingService
                              .formatProductPrice(_defaultPurchasePrice);
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
                        prefixIcon: const Icon(
                          Icons.shopping_basket,
                          color: AssyrianTheme.primaryGold,
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
                          _itemPriceController.text.isNotEmpty) {
                        setState(() => _itemPriceController.clear());
                      }
                      if (!hasFocus &&
                          _editingItemIndex == null &&
                          _defaultSellingPrice > 0 &&
                          _itemPriceController.text.isEmpty) {
                        setState(() {
                          _itemPriceController.text = _formattingService
                              .formatProductPrice(_defaultSellingPrice);
                        });
                      }
                    },
                    child: TextFormField(
                      controller: _itemPriceController,
                      decoration: InputDecoration(
                        labelText: 'سعر البيع',
                        hintText: _defaultSellingPrice > 0
                            ? _formattingService.formatProductPrice(
                                _defaultSellingPrice,
                              )
                            : '0.00',
                        prefixIcon: const Icon(
                          Icons.sell,
                          color: AssyrianTheme.primaryGold,
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
          ] else if (_selectedType == 'sales' || _selectedType == 'cash') ...[
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
            Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus &&
                    _defaultSellingPrice > 0 &&
                    _sellingPriceController.text.isNotEmpty) {
                  setState(() => _sellingPriceController.clear());
                }
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
                  prefixIcon: const Icon(
                    Icons.sell,
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [_formattingService.getPriceInputFormatter()],
              ),
            ),
          ],
          SizedBox(height: _editingItemIndex != null ? 0 : 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedProduct != null ? _addProductToInvoice : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
    final cashReceiptAmount = _cashAmountController.text.trim().isEmpty
        ? widget.invoice.cashTransactionAmount
        : _cashAmount;
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

        // مبلغ ونوع الإيصال الجديد أو القديم؛ لا تعرضه عند بيع المواد نقداً.
        if (_selectedType == 'cash' && _isCashReceipt) ...[
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_upward, size: 16.sp),
                            SizedBox(width: 4.w),
                            Text(
                              'إعطاء',
                              style: TextStyle(
                                fontSize: 13.sp,
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
                          ? (_isCashReceipt
                                ? 'المبلغ النقدي:'
                                : 'إجمالي البيع النقدي:')
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
                              ? (_isCashReceipt
                                    ? cashReceiptAmount
                                    : totalAfterDiscountAndTax)
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
              hintText: 'مثلاً: ضريبة قيمة مضافة',
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

  void _calculateTotalTax() {
    if (_taxes.isEmpty) {
      _taxAmount = 0.0;
      return;
    }

    // حساب تراكمي: كل ضريبة تُطبق على المبلغ الحالي
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

  void _addProductToInvoice() {
    if (_selectedProduct == null) {
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

    // في التعديل لا نغيّر الكمية إلى 1 إن أصبح الحقل فارغًا.
    final quantityText = _quantityController.text.isEmpty
        ? (_editingItemIndex == null
              ? '1'
              : _formattingService.formatNumber(
                  _invoiceItems[_editingItemIndex!].quantity,
                ))
        : _quantityController.text;
    final quantity =
        double.tryParse(
          SmartNumberFormatter.convertToEnglishNumbers(
            quantityText.replaceAll(',', '').replaceAll('،', '').trim(),
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
      // الانتقال للبحث يلغي التعديل غير المعتمد دون تغيير عنصر الفاتورة.
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
      _editingItemIndex = null;
      _productSearchController.clear();
      _editItemNameController.clear();
      _quantityController.clear();
      _itemPriceController.clear();
      _newProductQuantityController.clear();
      _selectedProduct = null;
      _selectedSoldItem = null;
      _hideProductSuggestionsOverlay();
      _showSoldItemsSuggestions = false;
      _purchasePriceController.clear();
      _sellingPriceController.clear();
      _defaultPurchasePrice = 0;
      _defaultSellingPrice = 0;
    });
  }

  /// بناء حقل كمية قابل لإعادة الاستخدام
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
        inputFormatters: [_formattingService.getQuantityInputFormatter()],
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

  // ==================== حفظ المنتجات في المخزن ====================

  /// حفظ المنتجات الجديدة في المخزون (فقط لفواتير الشراء)
  Future<void> _saveNewProductsToInventory() async {
    if (_selectedType != 'purchase') return;

    final productsToSave = <ProductEntity>[];
    for (final item in _invoiceItems) {
      // التحقق إذا كان المنتج مؤقت (جديد)
      if (item.productName.startsWith('temp_')) {
        final tempProduct = ProductEntity(
          id: '', // سيتم تعيينه بواسطة Firestore
          name: item.productName.replaceFirst('temp_', ''),
          description: 'منتج تمت إضافته من فاتورة شراء',
          unit: item.unit,
          // ✅ كمية صفرية: الكمية تُضاف ذرياً
          // داخل معاملة الفاتورة (نفس سبب
          // صفحة الإنشاء — إصلاح عدّ مزدوج).
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم حفظ ${productsToSave.length} منتجات جديدة في المخزون',
              ),
              backgroundColor: Colors.green,
            ),
          );
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
        rethrow;
      }
    }
  }

  // ⚠️ ملاحظة للمبرمجين المستقبليين (إصلاح 2026-10-09):
  // أُزيلت دالة _createProductLogs لأنها كانت تُنشئ
  // سجلات حركة منتجات مكررة ويتيمة. السبب:
  // InvoiceRepositoryImpl ينشئ سجلات الحركة ذرياً
  // داخل معاملة الفاتورة (عكس القديم + تطبيق
  // الجديد) في المجموعة العليا products_logs
  // (وهي التي يقرأها getProductLogs). هذه الدالة
  // كانت تستدعي createProductLog التي تكتب إلى
  // مجموعة فرعية تحت كل منتج لا يقرأها أحد،
  // فتُنشئ سجلات يتيمة بعد أن أنشأ المستودع
  // السجلات الحقيقية بالفعل — وتهدر قراءة وكتابة
  // إضافيتين لكل عنصر. لا تُنشئ سجلات حركة
  // المنتجات من الصفحة أبداً: المستودع يتولاها
  // ذرياً مع الفاتورة (All-or-Nothing).
}
