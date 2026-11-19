import 'package:equatable/equatable.dart';

/// كيان المصروف
class ExpenseEntity extends Equatable {
  const ExpenseEntity({
    required this.id,
    required this.organizationEmail,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.receiptUrl,
    this.approvedBy,
    this.approvedAt,
    this.updatedBy,
    this.paidAmount = 0.0,
  });
  final String id;
  final String organizationEmail;
  final String title;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String paymentMethod;
  final String? receiptUrl;
  final String status; // pending, approved, rejected
  // ⚠️ ملاحظة للمبرمجين المستقبليين — عدم اتساق في حالات الحالة:
  // كيان ExpenseEntity يعرف ثلاث حالات فقط: pending, approved, rejected.
  // لكن منطق الإحصائيات في expense_repository_impl.dart (getExpenseStatsStream
  // السطور 399-442، getExpenseStats السطور 734-750، computeExpenseStats السطور
  // 788-834) يتعامل مع حالة 'draft' والحالات غير المعروفة على أنها 'pending'.
  // هذا متفق عليه بين دوال الإحصائيات الثلاث نفسها، لكنه غير متوافق مع تعريف
  // الكيان هنا. إذا أُضيفت حالة جديدة مستقبلاً يجب تحديث الكيان ومنطق الإحصائيات
  // معًا للحفاظ على الاتساق. (ملاحظة توثيقية فقط، لا تعديل للمنطق)
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? updatedBy;
  final double paidAmount;

  bool get isPending => status == 'pending' || status == 'draft';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  double get remainingAmount => amount - paidAmount;
  // ملاحظة للمبرمجين المستقبليين: إذا كان paidAmount أكبر من amount،
  // ستكون remainingAmount سالبة. لإيقاف القيمة السالبة، استخدم effectiveRemainingAmount
  // الذي يقيد القيمة بصفر كحد أدنى.
  double get effectiveRemainingAmount => (amount - paidAmount) < 0 ? 0.0 : amount - paidAmount;

  ExpenseEntity copyWith({
    String? id,
    String? organizationEmail,
    String? title,
    String? description,
    double? amount,
    String? category,
    DateTime? date,
    String? paymentMethod,
    String? receiptUrl,
    String? status,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    double? paidAmount,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    organizationEmail,
    title,
    description,
    amount,
    category,
    date,
    paymentMethod,
    receiptUrl,
    status,
    approvedBy,
    approvedAt,
    createdAt,
    updatedAt,
    createdBy,
    updatedBy,
    paidAmount,
  ];
}
