import 'package:equatable/equatable.dart';

/// أحداث الصندوق
abstract class CashboxEvent extends Equatable {
  const CashboxEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل حساب الصندوق
class LoadCashboxBalance extends CashboxEvent {
  const LoadCashboxBalance({required this.organizationEmail});

  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// تحديث حساب الصندوق
class UpdateCashboxBalance extends CashboxEvent {
  const UpdateCashboxBalance({
    required this.organizationEmail,
    required this.amount,
    required this.type,
    required this.updatedBy,
  });

  final String organizationEmail;
  final double amount;
  final String type; // 'in' أو 'out'
  final String updatedBy;

  @override
  List<Object?> get props => [organizationEmail, amount, type, updatedBy];
}

/// تحميل حركات الصندوق
class LoadCashboxTransactions extends CashboxEvent {
  const LoadCashboxTransactions({
    required this.organizationEmail,
    this.startDate,
    this.endDate,
    this.limit = 20,
    this.page = 0,
  });

  final String organizationEmail;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;
  final int page;

  @override
  List<Object?> get props => [
    organizationEmail,
    startDate,
    endDate,
    limit,
    page,
  ];
}

/// تسجيل حركة يدوية
class RecordManualTransaction extends CashboxEvent {
  const RecordManualTransaction({
    required this.organizationEmail,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdBy,
  });

  final String organizationEmail;
  final String type;
  final double amount;
  final String description;
  final String createdBy;

  @override
  List<Object?> get props => [
    organizationEmail,
    type,
    amount,
    description,
    createdBy,
  ];
}

/// تحديث فترة التقرير
class UpdateCashboxReportPeriod extends CashboxEvent {
  const UpdateCashboxReportPeriod({
    required this.startDate,
    required this.endDate,
  });

  final DateTime startDate;
  final DateTime endDate;

  @override
  List<Object?> get props => [startDate, endDate];
}
