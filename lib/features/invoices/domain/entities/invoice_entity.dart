import 'package:equatable/equatable.dart';

import 'returned_item_entity.dart';

/// كيان الفاتورة
class InvoiceEntity extends Equatable {
  const InvoiceEntity({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.invoiceDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    required this.type,
    required this.items,
    required this.organizationEmail,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.customerId, // معرف العميل الثابت
    this.subscriptionId, // معرف الاشتراك (للفواتير من نوع subscription)
    this.notes,
    this.cashUserNote,
    this.cashTransactionType,
    this.cashAmount = 0,
    this.updatedBy,
    this.balanceBeforeInvoice, // الحساب قبل الفاتورة
    this.balanceAfterInvoice, // الحساب بعد الفاتورة
    this.isArchived = false, // حالة الأرشفة
    this.discountAmount = 0.0, // مبلغ الخصم
    this.taxAmount = 0.0, // مبلغ الضريبة
    this.taxes, // قائمة الضرائب التفصيلية [{name, rate, amount, isPercentage}]
    // حقول فاتورة مرجع البيع
    this.isSalesReturn = false,
    this.originalInvoiceId,
    this.refundMethod,
    this.returnedItems,
  });
  final String id;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final String? customerId; // معرف العميل الثابت
  final String? subscriptionId; // معرف الاشتراك (للفواتير من نوع subscription)
  final DateTime invoiceDate;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String status; // paid, partial, unpaid, cancelled
  final String type; // sales, purchase, cash
  final List<InvoiceItemEntity> items;
  final String? notes;

  /// نص الملاحظة التي كتبها المستخدم، منفصل عن وصف المعاملة النقدية.
  final String? cashUserNote;

  /// نوع إيصال الحساب النقدي: receipt (استلام)، payment (إعطاء)، clearance (تصفير).
  final String? cashTransactionType;

  /// مبلغ إيصال الحساب النقدي، منفصل عن قائمة المواد.
  final double cashAmount;

  /// يعيد نوع عملية الإيصال مع دعم الفواتير القديمة التي تخزن النوع في notes/paidAmount.
  /// المنطق مطابق تمامًا لشاشة قائمة الفواتير (_getCardBackgroundColor).
  String? get effectiveCashTransactionType {
    if (type != 'cash') return null;

    // 1. الأولوية المطلقة للحقل المخزّن صراحة في قاعدة البيانات
    if (cashTransactionType != null) {
      return cashTransactionType; // 'sale' | 'receipt' | 'payment' | 'clearance'
    }

    // 2. للفواتير القديمة بدون cashTransactionType، الاستنتاج من الملاحظات
    // (مطابق تمامًا لمنطق شاشة قائمة الفواتير _getCardBackgroundColor)
    final text = (notes ?? '').trim();
    if (customerId == null || customerId!.isEmpty) return 'sale';

    // يزيد الدين (أحمر في شاشة القائمة) → payment
    if (text.contains('عليه') ||
        text.contains('تسديد دين') ||
        text.contains('مدين') ||
        text.contains('إعطاء مبلغ نقدي للعميل')) {
      return 'payment';
    }

    // يقلل الدين (أخضر في شاشة القائمة) → receipt
    if (text.contains('له') ||
        text.contains('دفع مقدم') ||
        text.contains('دائن') ||
        text.contains('استلام مبلغ نقدي من العميل')) {
      return 'receipt';
    }

    // 3. خيار أخير فقط للفواتير القديمة جداً بدون ملاحظات واضحة
    return paidAmount < 0 ? 'payment' : 'receipt';
  }

  /// إيصالات العميل/تصفير الحساب تسجل مبلغاً وليس سلعاً.
  bool get isCashAccountReceipt {
    if (type != 'cash') return false;
    if (cashTransactionType == 'sale') return false;
    if (cashAmount > 0 &&
        cashTransactionType != null &&
        cashTransactionType != 'sale') {
      return true;
    }
    if (cashTransactionType == 'receipt' ||
        cashTransactionType == 'payment' ||
        cashTransactionType == 'clearance') {
      return true;
    }
    // إذا كانت هناك عناصر غير وصفية فهي فاتورة بيع نقدية، حتى لو
    // احتوت ملاحظاتها القديمة على كلمات استلام/إعطاء.
    if (items.isNotEmpty) {
      return items.every(
        (item) =>
            item.unit == 'مبلغ نقدي' ||
            item.productName.startsWith('مبلغ نقدي - ') ||
            item.productName.startsWith('تصفير حساب وأرشفة - '),
      );
    }
    if (customerId == null || customerId!.isEmpty) return false;
    final text = notes ?? '';
    return text.startsWith('إيصال نقدي - ') ||
        text.startsWith('فاتورة تصفير حساب') ||
        text.startsWith('فاتورة تصفير الحساب') ||
        text.contains('مبلغ نقدي - إعطاء مبلغ نقدي للعميل') ||
        text.contains('مبلغ نقدي - استلام مبلغ نقدي من العميل');
  }

  double get cashTransactionAmount {
    if (cashAmount > 0) return cashAmount;
    if (isCashAccountReceipt && items.isNotEmpty) {
      return items.fold<double>(0, (sum, item) => sum + item.totalPrice.abs());
    }
    return paidAmount.abs() > 0 ? paidAmount.abs() : totalAmount.abs();
  }

  String? get displayNotes {
    if (type != 'cash') return notes;
    if (cashUserNote != null) return cashUserNote;

    // توافق مع الفواتير السابقة التي دمجت الوصف والملاحظة في حقل واحد.
    final text = notes?.trim();
    if (text == null || text.isEmpty) return null;
    final marker = RegExp(r'(?:^|\n)ملاحظة:\s*').firstMatch(text);
    if (marker != null) return text.substring(marker.end);
    final prefix = RegExp(
      r'^(?:إيصال نقدي - )?(?:استلام مبلغ نقدي من العميل|إعطاء مبلغ نقدي للعميل)\s*-\s*',
    ).firstMatch(text);
    if (prefix != null) return text.substring(prefix.end);
    if (text.startsWith('إيصال نقدي - ') ||
        text.startsWith('فاتورة تصفير حساب')) {
      return null;
    }
    return text;
  }

  final String organizationEmail;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? updatedBy;
  final double? balanceBeforeInvoice; // الحساب قبل الفاتورة
  final double? balanceAfterInvoice; // الحساب بعد الفاتورة
  final bool isArchived; // حالة الأرشفة
  final double discountAmount; // مبلغ الخصم
  final double taxAmount; // مبلغ الضريبة
  final List<Map<String, dynamic>>? taxes; // قائمة الضرائب التفصيلية
  // حقول فاتورة مرجع البيع
  final bool isSalesReturn; // هل هي فاتورة مرجع بيع
  final String? originalInvoiceId; // الفاتورة الأصلية المرجعة منها
  final String? refundMethod; // طريقة الاسترداد: 'credit' أو 'cash'
  final List<ReturnedItemEntity>? returnedItems; // المواد المرتجعة

  bool get isPaid => status == 'paid';
  bool get isPartiallyPaid => status == 'partial';
  bool get isUnpaid => status == 'unpaid';
  bool get isCancelled => status == 'cancelled';

  /// حساب المبلغ المتبقي (الذي لا يزال مستحقًا)
  /// 🔧 تم تعديلها: تُقصى القيمة عند الصفر لمنع ظهور المتبقي سالبًا
  /// عندما يزيد المبلغ المدفوع عن الإجمالي (مثل الفواتير النقدية الصادرة).
  /// ⚠️ ملاحظة للمبرمجين المستقبليين — استخدام القيمة المطلقة للمدفوع:
  // تُستخدم paidAmount.abs() في الحساب. إذا كانت paidAmount سالبة (دفع نقدي للعميل)،
  // فإن remaining = totalAmount - abs(paidAmount) ينقص المتبقي بدلاً من أن يزيده أو يتركه.
  // هذا التصميم مقصود للفواتير النقدية الصادرة لكنه قد يسبب ارتباكًا في حالات الدفع للعميل.
  // يجب توثيق هذا السلوك بوضوح في واجهة المستخدم إذا تغيرت متطلبات العمل.
  double calculateRemainingAmount() {
    // المبلغ المتبقي = المبلغ الإجمالي - المبلغ المدفوع
    final remaining = totalAmount - paidAmount.abs();
    return remaining < 0 ? 0 : remaining;
  }

  /// التحقق مما إذا كانت الفاتورة مغلقة (مدفوعة بالكامل أو ملغاة)
  bool get isClosed => isPaid || isCancelled;

  /// التحقق مما إذا كانت الفاتورة مفتوحة (غير مدفوعة بالكامل وغير ملغاة)
  /// ملاحظة: الحالة 'partial' تُعتبر مفتوحة لأنها لم تُسدَّد بالكامل.
  bool get isOpen => !isClosed;

  /// حساب النسبة المئوية للمدفوع من إجمالي الفاتورة
  /// ✅ تم الإصلاح: تستخدم paidAmount.abs() لتتوافق مع calculateRemainingAmount (السطر 80).
  /// هذا يضمن أن النسبة والمتبقي يعتمدان على القيمة المطلقة للمدفوع، لذلك إذا كان paidAmount سالباً
  /// (فواتير نقدية صادرة)، ستظهر النسبة موجبة والمتبقي يُقصى عند الصفر.
  double get paidPercentage {
    if (totalAmount == 0) return 0;
    return (paidAmount.abs() / totalAmount) * 100;
  }

  /// حساب النسبة المئوية للمتبقي من إجمالي الفاتورة
  double get remainingPercentage {
    if (totalAmount == 0) return 0;
    return (calculateRemainingAmount() / totalAmount) * 100;
  }

  /// التحقق مما إذا كانت الفاتورة مدفوعة جزئيًا (الحالة partial)
  /// ⚠️ ملاحظة للمبرمجين: الاسم isPartiallyClosed قد يوحي بأنها مغلقة جزئيًا،
  /// لكنها تعني أن حالة الدفع هي 'partial' فقط، وليس أن الفاتورة مغلقة.
  /// استخدم isOpen لمعرفة ما إذا كانت الفاتورة لا تزال مفتوحة.
  bool get isPartiallyClosed => status == 'partial';

  /// التحقق مما إذا كانت الفاتورة مغلقة بالكامل (مدفوعة بالكامل)
  bool get isFullyClosed => isPaid;

  /// نسخ الكيان مع تعديل بعض الخصائص
  /// 🔧 تم تعديلها: لدعم تعيين حقل إلى null صراحةً، تُمرر قيمة خاصة
  /// (على سبيل المثال الرمز '\0' للنصوص، أو -1 للأعداد) لتشير إلى "تعيين إلى null".
  /// بدون هذا، لا يمكن إفراغ حقل مثل taxes أو refundMethod عبر copyWith.
  InvoiceEntity copyWith({
    String? id,
    String? invoiceNumber,
    String? customerName,
    String? customerPhone,
    String? customerId,
    String? subscriptionId,
    DateTime? invoiceDate,
    double? totalAmount,
    double? paidAmount,
    double? remainingAmount,
    String? status,
    String? type,
    List<InvoiceItemEntity>? items,
    String? notes,
    String? cashUserNote,
    String? cashTransactionType,
    double? cashAmount,
    String? organizationEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    double? balanceBeforeInvoice,
    double? balanceAfterInvoice,
    bool? isArchived,
    double? discountAmount,
    double? taxAmount,
    List<Map<String, dynamic>>? taxes,
    bool? isSalesReturn,
    String? originalInvoiceId,
    String? refundMethod,
    List<ReturnedItemEntity>? returnedItems,
  }) {
    return InvoiceEntity(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerId: customerId ?? this.customerId,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      type: type ?? this.type,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      cashUserNote: cashUserNote ?? this.cashUserNote,
      cashTransactionType: cashTransactionType ?? this.cashTransactionType,
      cashAmount: cashAmount ?? this.cashAmount,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      balanceBeforeInvoice: balanceBeforeInvoice ?? this.balanceBeforeInvoice,
      balanceAfterInvoice: balanceAfterInvoice ?? this.balanceAfterInvoice,
      isArchived: isArchived ?? this.isArchived,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      taxes: taxes ?? this.taxes,
      isSalesReturn: isSalesReturn ?? this.isSalesReturn,
      originalInvoiceId: originalInvoiceId ?? this.originalInvoiceId,
      refundMethod: refundMethod ?? this.refundMethod,
      returnedItems: returnedItems ?? this.returnedItems,
    );
  }

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    customerName,
    customerPhone,
    customerId,
    subscriptionId,
    invoiceDate,
    totalAmount,
    paidAmount,
    remainingAmount,
    status,
    type,
    items,
    notes,
    cashUserNote,
    cashTransactionType,
    cashAmount,
    organizationEmail,
    createdAt,
    updatedAt,
    createdBy,
    updatedBy,
    balanceBeforeInvoice,
    balanceAfterInvoice,
    isArchived,
    discountAmount,
    taxAmount,
    taxes,
    isSalesReturn,
    originalInvoiceId,
    refundMethod,
    returnedItems,
  ];
}

/// كيان عنصر الفاتورة
class InvoiceItemEntity extends Equatable {
  const InvoiceItemEntity({
    required this.productName,
    this.productId,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    // حقول الإرجاع
    this.itemId,
    this.originalInvoiceId,
    this.originalInvoiceNumber,
    this.originalSaleDate,
    this.isReturned = false,
    this.returnedQuantity,
    this.originalQuantity, // ✅ الكمية الأصلية المشتراة
    // حقول فاتورة الشراء
    this.purchasePrice,
    this.sellingPrice,
  });
  final String productName;
  final String?
  productId; // معرف المنتج في Firebase - يُستخدم لجلب المنتج داخل transaction
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  // حقول الإرجاع
  final String? itemId; // معرف المنتج الأصلي
  final String? originalInvoiceId; // الفاتورة الأصلية
  final String? originalInvoiceNumber; // رقم الفاتورة الأصلية
  final DateTime? originalSaleDate; // تاريخ البيع الأصلي
  final bool isReturned; // هل تم إرجاع هذا الصنف
  final int? returnedQuantity; // الكمية المرتجعة
  final double? originalQuantity; // ✅ الكمية الأصلية المشتراة
  // حقول فاتورة الشراء
  final double? purchasePrice; // سعر الشراء للوحدة
  final double? sellingPrice; // سعر البيع للوحدة

  @override
  List<Object?> get props => [
    productName,
    productId,
    quantity,
    unit,
    unitPrice,
    totalPrice,
    itemId,
    originalInvoiceId,
    originalInvoiceNumber,
    isReturned,
    returnedQuantity,
    originalQuantity,
    purchasePrice,
    sellingPrice,
  ];
}
