import 'package:equatable/equatable.dart';

/// كيان دفعة الاشتراك
class SubscriptionPaymentEntity extends Equatable {

  const SubscriptionPaymentEntity({
    required this.id,
    required this.subscriptionId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.paymentDate,
    this.transactionId,
    this.notes,
  });
  final String id;
  final String subscriptionId;
  final double amount;
  final String paymentMethod;
  final String status;
  final DateTime paymentDate;
  final String? transactionId;
  final String? notes;

  @override
  List<Object?> get props => [
    id,
    subscriptionId,
    amount,
    paymentMethod,
    status,
    paymentDate,
    transactionId,
    notes,
  ];
}
