import 'package:equatable/equatable.dart';

/// كيان إحصائيات الفواتير
class InvoiceStatsEntity extends Equatable {

  const InvoiceStatsEntity({
    this.totalInvoices = 0,
    this.paidInvoices = 0,
    this.unpaidInvoices = 0,
    this.overdueInvoices = 0,
    this.totalRevenue = 0,
    this.totalPaid = 0,
    this.totalRemaining = 0,
  });
  final int totalInvoices;
  final int paidInvoices;
  final int unpaidInvoices;
  final int overdueInvoices;
  final double totalRevenue;
  final double totalPaid;
  final double totalRemaining;

  @override
  List<Object?> get props => [
    totalInvoices,
    paidInvoices,
    unpaidInvoices,
    overdueInvoices,
    totalRevenue,
    totalPaid,
    totalRemaining,
  ];
}
