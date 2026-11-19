import 'package:equatable/equatable.dart';

/// كيان سجل حركة المنتج (بيع/شراء)
class ProductLogEntity extends Equatable {
  const ProductLogEntity({
    required this.id,
    required this.productId,
    required this.productName,
    required this.invoiceId,
    required this.invoiceType,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.customerName,
    required this.customerPhone,
    required this.date,
    required this.organizationEmail,
    required this.createdAt,
    required this.createdBy,
    this.notes,
  });

  final String id;
  final String productId; // معرف المنتج
  final String productName; // اسم المنتج
  final String invoiceId; // معرف الفاتورة
  final String invoiceType; // نوع الفاتورة: sales, purchase, cash
  final double quantity; // الكمية (موجبة للشراء، سالبة للبيع)
  final double unitPrice; // سعر الوحدة
  final double totalPrice; // السعر الإجمالي
  final String customerName; // اسم العميل
  final String customerPhone; // هاتف العميل
  final DateTime date; // تاريخ الحركة
  final String organizationEmail;
  final DateTime createdAt;
  final String createdBy;
  final String? notes;

  /// التحقق إذا كانت الحركة شراء
  bool get isPurchase => invoiceType == 'purchase';

  /// التحقق إذا كانت الحركة بيع
  bool get isSale => invoiceType == 'sales' || invoiceType == 'cash';

  /// نسخ الكيان مع تعديل بعض الخصائص
  ProductLogEntity copyWith({
    String? id,
    String? productId,
    String? productName,
    String? invoiceId,
    String? invoiceType,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    String? customerName,
    String? customerPhone,
    DateTime? date,
    String? organizationEmail,
    DateTime? createdAt,
    String? createdBy,
    String? notes,
  }) {
    return ProductLogEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceType: invoiceType ?? this.invoiceType,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      date: date ?? this.date,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        invoiceId,
        invoiceType,
        quantity,
        unitPrice,
        totalPrice,
        customerName,
        customerPhone,
        date,
        organizationEmail,
        createdAt,
        createdBy,
        notes,
      ];
}
