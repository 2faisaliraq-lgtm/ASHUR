import 'package:equatable/equatable.dart';

import '../../domain/entities/cashbox_transaction_entity.dart';

/// حالات الصندوق
abstract class CashboxState extends Equatable {
  const CashboxState();

  @override
  List<Object?> get props => [];
}

/// الحالة الابتدائية
class CashboxInitial extends CashboxState {
  const CashboxInitial();
}

/// جاري التحميل
class CashboxLoading extends CashboxState {
  const CashboxLoading();
}

/// تم التحميل بنجاح
class CashboxLoaded extends CashboxState {
  const CashboxLoaded({
    required this.balance,
    required this.transactions,
    required this.totalIn,
    required this.totalOut,
    this.totalCount = 0,
    this.startDate,
    this.endDate,
  });

  final double balance;
  final List<CashboxTransactionEntity> transactions;
  final double totalIn;
  final double totalOut;

  /// عدد الحركات الكلي في الفترة (من الستريم) —
  /// transactions تحتوي الصفحة المعروضة فقط،
  /// فيُستخدم هذا الحقل لحساب توفر المزيد
  /// للتحميل
  final int totalCount;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [
    balance,
    transactions,
    totalIn,
    totalOut,
    totalCount,
    startDate,
    endDate,
  ];

  CashboxLoaded copyWith({
    double? balance,
    List<CashboxTransactionEntity>? transactions,
    double? totalIn,
    double? totalOut,
    int? totalCount,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return CashboxLoaded(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      totalIn: totalIn ?? this.totalIn,
      totalOut: totalOut ?? this.totalOut,
      totalCount: totalCount ?? this.totalCount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

/// خطأ
class CashboxError extends CashboxState {
  const CashboxError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

/// نجاح العملية
class CashboxSuccess extends CashboxState {
  const CashboxSuccess({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
