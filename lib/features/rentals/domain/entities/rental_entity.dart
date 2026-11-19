import 'package:equatable/equatable.dart';

/// كيان عقد الإيجار
class RentalEntity extends Equatable {
  const RentalEntity({
    required this.id,
    required this.organizationEmail,
    required this.itemName,
    required this.renterName,
    required this.rentalPrice,
    required this.deposit,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.paymentFrequency,
    required this.paymentDay,
    required this.createdAt,
    required this.createdBy,
    this.itemDescription,
    this.renterPhone,
    this.renterEmail,
    this.customerId, // معرف العميل
    this.customerName, // اسم العميل للعرض
    this.unitId, // معرف الوحدة المؤجرة (اختياري)
    this.notes,
    this.attachments,
    this.updatedAt,
    this.updatedBy,
  });
  final String id;
  final String organizationEmail;
  final String itemName; // اسم الشيء المؤجر (سيارة، عقار، معدة، إلخ)
  final String? itemDescription; // وصف الشيء المؤجر
  final String renterName; // اسم المستأجر
  final String? renterPhone;
  final String? renterEmail;
  final String? customerId; // معرف العميل
  final String? customerName; // اسم العميل للعرض
  final String? unitId; // معرف الوحدة المؤجرة (اختياري)
  final double rentalPrice; // سعر الإيجار
  final double deposit; // التأمين/العربون
  final DateTime startDate;
  final DateTime endDate;
  final String status; // active, expired, terminated, pending
  final String paymentFrequency; // daily, weekly, monthly, quarterly, yearly
  final int paymentDay; // يوم الدفع من الشهر (أو الأسبوع)
  final String? notes;
  final List<String>? attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;

  @override
  List<Object?> get props => [
    id,
    organizationEmail,
    itemName,
    itemDescription,
    renterName,
    renterPhone,
    renterEmail,
    customerId,
    customerName,
    unitId,
    rentalPrice,
    deposit,
    startDate,
    endDate,
    status,
    paymentFrequency,
    paymentDay,
    notes,
    attachments,
    createdAt,
    updatedAt,
    createdBy,
    updatedBy,
  ];

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';
  bool get isTerminated => status == 'terminated';
  bool get isPending => status == 'pending';

  /// ملاحظة للمبرمجين المستقبليين: العداد يشمل اليوم صفر (>= 0)،
  /// فإذا انتهى العقد اليوم يعتبر "قريباً من الانتهاء". هذا متوافق مع daysRemaining.
  bool get isExpiringSoon {
    final daysUntilExpiry = endDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry >= 0;
  }

  int get daysRemaining => endDate.difference(DateTime.now()).inDays;

  RentalEntity copyWith({
    String? id,
    String? organizationEmail,
    String? itemName,
    String? itemDescription,
    String? renterName,
    String? renterPhone,
    String? renterEmail,
    String? customerId,
    String? customerName,
    String? unitId,
    double? rentalPrice,
    double? deposit,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? paymentFrequency,
    int? paymentDay,
    String? notes,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return RentalEntity(
      id: id ?? this.id,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      itemName: itemName ?? this.itemName,
      itemDescription: itemDescription ?? this.itemDescription,
      renterName: renterName ?? this.renterName,
      renterPhone: renterPhone ?? this.renterPhone,
      renterEmail: renterEmail ?? this.renterEmail,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      unitId: unitId ?? this.unitId,
      rentalPrice: rentalPrice ?? this.rentalPrice,
      deposit: deposit ?? this.deposit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      paymentDay: paymentDay ?? this.paymentDay,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
