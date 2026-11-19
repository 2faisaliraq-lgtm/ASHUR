import 'package:equatable/equatable.dart';

/// كيان حركة الصندوق
class CashboxTransactionEntity extends Equatable {
  const CashboxTransactionEntity({
    required this.id,
    required this.type,
    required this.amount,
    required this.source,
    required this.referenceId,
    required this.description,
    required this.timestamp,
    required this.createdBy,
  });

  final String id;
  final String type; // 'in' أو 'out'
  final double amount;
  final String source; // 'invoice', 'expense', 'subscription', 'manual'
  final String referenceId;
  final String description;
  final DateTime timestamp;
  final String createdBy;

  CashboxTransactionEntity copyWith({
    String? id,
    String? type,
    double? amount,
    String? source,
    String? referenceId,
    String? description,
    DateTime? timestamp,
    String? createdBy,
  }) {
    return CashboxTransactionEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      source: source ?? this.source,
      referenceId: referenceId ?? this.referenceId,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    amount,
    source,
    referenceId,
    description,
    timestamp,
    createdBy,
  ];
}
