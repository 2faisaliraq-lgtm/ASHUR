import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/returned_item_entity.dart';

/// نموذج الفاتورة
class InvoiceModel extends InvoiceEntity {
  const InvoiceModel({
    required super.id,
    required super.invoiceNumber,
    required super.customerName,
    required super.customerPhone,
    required super.invoiceDate,
    required super.totalAmount,
    required super.paidAmount,
    required super.remainingAmount,
    required super.status,
    required super.type,
    required super.items,
    required super.organizationEmail,
    required super.createdAt,
    required super.updatedAt,
    required super.createdBy,
    super.customerId,
    super.subscriptionId,
    super.notes,
    super.cashUserNote,
    super.cashTransactionType,
    super.cashAmount,
    super.updatedBy,
    super.balanceBeforeInvoice,
    super.balanceAfterInvoice,
    super.isArchived,
    super.discountAmount,
    super.taxAmount,
    super.taxes,
    super.isSalesReturn,
    super.originalInvoiceId,
    super.refundMethod,
    super.returnedItems,
  });

  factory InvoiceModel.fromEntity(InvoiceEntity entity) {
    return InvoiceModel(
      id: entity.id,
      invoiceNumber: entity.invoiceNumber,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      customerId: entity.customerId,
      subscriptionId: entity.subscriptionId,
      invoiceDate: entity.invoiceDate,
      totalAmount: entity.totalAmount,
      paidAmount: entity.paidAmount,
      remainingAmount: entity.remainingAmount,
      status: entity.status,
      type: entity.type,
      items: entity.items,
      notes: entity.notes,
      cashUserNote: entity.cashUserNote,
      cashTransactionType: entity.cashTransactionType,
      cashAmount: entity.cashAmount,
      organizationEmail: entity.organizationEmail,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      balanceBeforeInvoice: entity.balanceBeforeInvoice,
      balanceAfterInvoice: entity.balanceAfterInvoice,
      isArchived: entity.isArchived,
      discountAmount: entity.discountAmount,
      taxAmount: entity.taxAmount,
      taxes: entity.taxes,
      isSalesReturn: entity.isSalesReturn,
      originalInvoiceId: entity.originalInvoiceId,
      refundMethod: entity.refundMethod,
      returnedItems: entity.returnedItems,
    );
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      customerId: json['customerId'],
      subscriptionId: json['subscriptionId'],
      invoiceDate: _parseDate(json['invoiceDate']),
      totalAmount: _parseDouble(json['totalAmount']),
      paidAmount: _parseDouble(json['paidAmount']),
      remainingAmount: _parseDouble(json['remainingAmount']),
      status: json['status'] ?? 'unpaid',
      type: json['type'] ?? 'sales',
      items: _parseItems(json['items']),
      notes: json['notes'],
      cashUserNote: json['cashUserNote'],
      cashTransactionType: json['cashTransactionType'],
      cashAmount: _parseDouble(json['cashAmount']),
      organizationEmail: json['organizationEmail'] ?? '',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      createdBy: json['createdBy'] ?? 'المدير',
      updatedBy: json['updatedBy'],
      balanceBeforeInvoice: _parseDouble(json['balanceBeforeInvoice']),
      balanceAfterInvoice: _parseDouble(json['balanceAfterInvoice']),
      isArchived: json['isArchived'] ?? false,
      discountAmount: _parseDouble(json['discountAmount']),
      taxAmount: _parseDouble(json['taxAmount']),
      taxes: json['taxes'] != null
          ? (json['taxes'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList()
          : null,
      isSalesReturn: json['isSalesReturn'] ?? false,
      originalInvoiceId: json['originalInvoiceId'],
      refundMethod: json['refundMethod'],
      returnedItems: _parseReturnedItems(json['returnedItems']),
    );
  }

  factory InvoiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) throw Exception('المستند فارغ');
    final mapData = data as Map<String, dynamic>;
    return InvoiceModel(
      id: doc.id,
      invoiceNumber: mapData['invoiceNumber'] ?? '',
      customerName: mapData['customerName'] ?? '',
      customerPhone: mapData['customerPhone'] ?? '',
      customerId: mapData['customerId'], // معرف العميل الثابت
      subscriptionId: mapData['subscriptionId'], // معرف الاشتراك
      invoiceDate: _parseDate(mapData['invoiceDate']),
      totalAmount: _parseDouble(mapData['totalAmount']),
      paidAmount: _parseDouble(mapData['paidAmount']),
      remainingAmount: _parseDouble(mapData['remainingAmount']),
      status: mapData['status'] ?? 'unpaid',
      type: mapData['type'] ?? 'sales',
      items: _parseItems(mapData['items']),
      notes: mapData['notes'],
      cashUserNote: mapData['cashUserNote'],
      cashTransactionType: mapData['cashTransactionType'],
      cashAmount: _parseDouble(mapData['cashAmount']),
      organizationEmail: mapData['organizationEmail'] ?? '',
      createdAt: _parseDate(mapData['createdAt']),
      updatedAt: _parseDate(mapData['updatedAt']),
      createdBy: mapData['createdBy'] ?? 'المدير',
      updatedBy: mapData['updatedBy'],
      balanceBeforeInvoice: _parseDouble(mapData['balanceBeforeInvoice']),
      balanceAfterInvoice: _parseDouble(mapData['balanceAfterInvoice']),
      isArchived: mapData['isArchived'] ?? false,
      discountAmount: _parseDouble(mapData['discountAmount']),
      taxAmount: _parseDouble(mapData['taxAmount']),
      taxes: data['taxes'] != null
          ? (data['taxes'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList()
          : null,
      isSalesReturn: data['isSalesReturn'] ?? false,
      originalInvoiceId: data['originalInvoiceId'],
      refundMethod: data['refundMethod'],
      returnedItems: _parseReturnedItems(data['returnedItems']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerId': customerId, // معرف العميل الثابت
      'subscriptionId': subscriptionId, // معرف الاشتراك
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'status': status,
      'type': type,
      'items': items
          .map(
            (item) => {
              'productName': item.productName,
              'productId': item.productId,
              'quantity': item.quantity,
              'unit': item.unit,
              'unitPrice': item.unitPrice,
              'totalPrice': item.totalPrice,
              'purchasePrice': item.purchasePrice,
              'sellingPrice': item.sellingPrice,
              // حقول الإرجاع
              'itemId': item.itemId,
              'originalInvoiceId': item.originalInvoiceId,
              'originalInvoiceNumber': item.originalInvoiceNumber,
              'originalSaleDate': item.originalSaleDate != null
                  ? Timestamp.fromDate(item.originalSaleDate!)
                  : null,
              'isReturned': item.isReturned,
              'returnedQuantity': item.returnedQuantity,
            },
          )
          .toList(),
      'notes': notes,
      if (cashUserNote != null) 'cashUserNote': cashUserNote,
      if (cashTransactionType != null)
        'cashTransactionType': cashTransactionType,
      if (cashAmount > 0) 'cashAmount': cashAmount,
      'organizationEmail': organizationEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'balanceBeforeInvoice': balanceBeforeInvoice,
      'balanceAfterInvoice': balanceAfterInvoice,
      'isArchived': isArchived,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      if (taxes != null && taxes!.isNotEmpty) 'taxes': taxes,
      // حقول فاتورة مرجع البيع
      if (isSalesReturn) 'isSalesReturn': isSalesReturn,
      if (originalInvoiceId != null) 'originalInvoiceId': originalInvoiceId,
      if (refundMethod != null) 'refundMethod': refundMethod,
      if (returnedItems != null && returnedItems!.isNotEmpty)
        'returnedItems': returnedItems!.map((item) => item.toMap()).toList(),
    };
  }

  /// تحليل تاريخ من بيانات Firestore
  ///
  /// ⚠️ ملاحظة للمبرمجين المستقبليين:
  /// تُعيد هذه الدالة DateTime(2000, 1, 1) للقيم الفارغة أو غير الصالحة بدلاً من إلقاء استثناء.
  /// هذا يمنع انهيار التطبيق عند قراءة بيانات تالفة، لكنه قد يخفي مشاكل في التواريخ.
  /// إذا كان التاريخ مهم للحسابات المالية، يُنصح بالتحقق منه قبل الاستدعاء.
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime(2000, 1, 1);
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime(2000, 1, 1);
    }
    return DateTime(2000, 1, 1);
  }

  /// تحليل قيمة رقمية من بيانات Firestore
  ///
  /// ⚠️ ملاحظة للمبرمجين المستقبليين:
  /// تُعيد هذه الدالة 0 للقيم الفارغة أو غير الصالحة بدلاً من إلقاء استثناء.
  /// هذا يمنع انهيار التطبيق عند قراءة بيانات تالفة، لكنه قد يخفي مشاكل في البيانات.
  /// إذا كانت القيمة مهمة للحسابات المالية، يُنصح بالتحقق منها قبل الاستدعاء.
  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0;
  }

  static List<InvoiceItemEntity> _parseItems(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];

    return value
        .map((item) {
          if (item is! Map<String, dynamic>) return null;
          return InvoiceItemEntity(
            productName: item['productName'] ?? '',
            productId: item['productId'] as String?,
            quantity: _parseDouble(item['quantity']),
            unit: item['unit'] ?? '',
            unitPrice: _parseDouble(item['unitPrice']),
            totalPrice: _parseDouble(item['totalPrice']),
            purchasePrice: _parseDouble(item['purchasePrice']),
            sellingPrice: _parseDouble(item['sellingPrice']),
            // حقول الإرجاع
            itemId: item['itemId'],
            originalInvoiceId: item['originalInvoiceId'],
            originalInvoiceNumber: item['originalInvoiceNumber'],
            originalSaleDate: item['originalSaleDate'] is Timestamp
                ? (item['originalSaleDate'] as Timestamp).toDate()
                : null,
            isReturned: item['isReturned'] ?? false,
            returnedQuantity: item['returnedQuantity'] as int?,
          );
        })
        .whereType<InvoiceItemEntity>()
        .toList();
  }

  static List<ReturnedItemEntity> _parseReturnedItems(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];

    return value
        .map((item) {
          if (item is! Map<String, dynamic>) return null;
          return ReturnedItemEntity(
            itemId: item['itemId'] ?? '',
            itemName: item['itemName'] ?? '',
            productId: item['productId'] as String?,
            purchasedQuantity: (item['purchasedQuantity'] ?? 0).toInt(),
            returnedQuantity: (item['returnedQuantity'] ?? 0).toInt(),
            unitPrice: (item['unitPrice'] ?? 0.0).toDouble(),
            saleDate: item['saleDate'] is Timestamp
                ? (item['saleDate'] as Timestamp).toDate()
                : item['saleDate'] is String
                ? DateTime.tryParse(item['saleDate'] as String) ??
                      DateTime(
                        1970,
                        1,
                        1,
                      ) // ✅ قيمة افتراضية واضحة بدلاً من DateTime.now() الذي يضلل
                : DateTime(
                    1970,
                    1,
                    1,
                  ), // ✅ نفس الشيء: عدم استخدام DateTime.now() كقيمة افتراضية لتاريخ البيع
            originalInvoiceId: item['originalInvoiceId'] ?? '',
            originalInvoiceNumber: item['originalInvoiceNumber'],
          );
        })
        .whereType<ReturnedItemEntity>()
        .toList();
  }
}
