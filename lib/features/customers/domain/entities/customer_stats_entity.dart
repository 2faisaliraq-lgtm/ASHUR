import 'package:equatable/equatable.dart';

/// كيان إحصائيات العملاء
class CustomerStatsEntity extends Equatable {
  const CustomerStatsEntity({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.inactiveCustomers,
    required this.netBalance,
    required this.totalDebtAmount,
    required this.totalCreditAmount,
    this.blockedCustomers = 0,
    this.customersWithGroups = 0,
    this.customersWithoutGroups = 0,
    this.totalPurchases = 0.0,
  });

  /// إجمالي عدد العملاء
  final int totalCustomers;

  /// عدد العملاء النشطين
  final int activeCustomers;

  /// عدد العملاء غير النشطين
  final int inactiveCustomers;

  /// عدد العملاء المحظورين
  final int blockedCustomers;

  /// عدد العملاء المنتمين لمجموعات
  final int customersWithGroups;

  /// عدد العملاء غير المنتمين لمجموعات
  final int customersWithoutGroups;

  /// إجمالي المشتريات
  final double totalPurchases;

  /// صافي الحساب (موجب = لنا، سالب = علينا)
  final double netBalance;

  /// إجمالي الديون المستحقة لنا (موجب فقط)
  final double totalDebtAmount;

  /// إجمالي الائتمانات المستحقة علينا (موجب فقط)
  final double totalCreditAmount;

  @override
  List<Object?> get props => [
    totalCustomers,
    activeCustomers,
    inactiveCustomers,
    blockedCustomers,
    customersWithGroups,
    customersWithoutGroups,
    totalPurchases,
    netBalance,
    totalDebtAmount,
    totalCreditAmount,
  ];
}
