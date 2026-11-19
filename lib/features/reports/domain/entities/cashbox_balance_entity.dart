import 'package:equatable/equatable.dart';

/// كيان حساب الصندوق
class CashboxBalanceEntity extends Equatable {
  const CashboxBalanceEntity({
    required this.currentBalance,
    required this.lastUpdated,
    required this.updatedBy,
  });

  final double currentBalance;
  final DateTime lastUpdated;
  final String updatedBy;

  CashboxBalanceEntity copyWith({
    double? currentBalance,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return CashboxBalanceEntity(
      currentBalance: currentBalance ?? this.currentBalance,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props => [currentBalance, lastUpdated, updatedBy];
}
