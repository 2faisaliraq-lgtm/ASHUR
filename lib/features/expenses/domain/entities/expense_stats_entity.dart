import 'package:equatable/equatable.dart';

/// كيان إحصائيات المصاريف
class ExpenseStatsEntity extends Equatable {
  const ExpenseStatsEntity({
    required this.totalExpenses,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    this.pendingExpenses = 0,
    this.approvedExpenses = 0,
    this.rejectedExpenses = 0,
    this.pendingAmount = 0.0,
    this.approvedAmount = 0.0,
  });
  final int totalExpenses;
  final int pendingExpenses;
  final int approvedExpenses;
  final int rejectedExpenses;
  final double totalAmount;
  final double pendingAmount;
  final double approvedAmount;
  final double paidAmount;
  final double remainingAmount;

  @override
  List<Object?> get props => [
    totalExpenses,
    pendingExpenses,
    approvedExpenses,
    rejectedExpenses,
    totalAmount,
    pendingAmount,
    approvedAmount,
    paidAmount,
    remainingAmount,
  ];
}
