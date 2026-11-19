import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/cashbox_transaction_entity.dart';

/// موديل حركة الصندوق للعرض
class CashboxTransactionViewModel extends CashboxTransactionEntity {
  const CashboxTransactionViewModel({
    required super.id,
    required super.type,
    required super.amount,
    required super.source,
    required super.referenceId,
    required super.description,
    required super.timestamp,
    required super.createdBy,
  });

  factory CashboxTransactionViewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CashboxTransactionViewModel(
      id: doc.id,
      type: data['type']?.toString() ?? 'in',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      source: data['source']?.toString() ?? 'manual',
      referenceId: data['referenceId']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy']?.toString() ?? '',
    );
  }

  factory CashboxTransactionViewModel.fromEntity(
    CashboxTransactionEntity entity,
  ) {
    return CashboxTransactionViewModel(
      id: entity.id,
      type: entity.type,
      amount: entity.amount,
      source: entity.source,
      referenceId: entity.referenceId,
      description: entity.description,
      timestamp: entity.timestamp,
      createdBy: entity.createdBy,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'amount': amount,
      'source': source,
      'referenceId': referenceId,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdBy': createdBy,
    };
  }

  @override
  CashboxTransactionViewModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? source,
    String? referenceId,
    String? description,
    DateTime? timestamp,
    String? createdBy,
  }) {
    return CashboxTransactionViewModel(
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
}
