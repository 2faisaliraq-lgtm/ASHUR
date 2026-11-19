import 'package:equatable/equatable.dart';

/// كيان دفعة الإيجار
class RentalPaymentEntity extends Equatable {
  const RentalPaymentEntity({
    required this.id,
    required this.rentalId,
    required this.organizationEmail,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.paidDate,
    this.paymentMethod,
    this.receiptNumber,
    this.notes,
  });
  final String id;
  final String rentalId;
  final String organizationEmail;
  final double amount;
  final DateTime? paidDate;
  final String status; // pending, paid, overdue, cancelled
  final String? paymentMethod;
  final String? receiptNumber;
  final String? notes;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    rentalId,
    organizationEmail,
    amount,
    paidDate,
    status,
    paymentMethod,
    receiptNumber,
    notes,
    createdAt,
  ];

  RentalPaymentEntity copyWith({
    String? id,
    String? rentalId,
    String? organizationEmail,
    double? amount,
    DateTime? paidDate,
    String? status,
    String? paymentMethod,
    String? receiptNumber,
    String? notes,
    DateTime? createdAt,
  }) {
    return RentalPaymentEntity(
      id: id ?? this.id,
      rentalId: rentalId ?? this.rentalId,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      amount: amount ?? this.amount,
      paidDate: paidDate ?? this.paidDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isOverdue => status == 'overdue';
}
