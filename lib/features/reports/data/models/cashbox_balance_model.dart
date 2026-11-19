import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/cashbox_balance_entity.dart';

/// موديل حساب الصندوق
class CashboxBalanceModel extends CashboxBalanceEntity {
  const CashboxBalanceModel({
    required super.currentBalance,
    required super.lastUpdated,
    required super.updatedBy,
  });

  factory CashboxBalanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CashboxBalanceModel(
      currentBalance: (data['currentBalance'] as num?)?.toDouble() ?? 0.0,
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: data['updatedBy']?.toString() ?? '',
    );
  }

  factory CashboxBalanceModel.fromEntity(CashboxBalanceEntity entity) {
    return CashboxBalanceModel(
      currentBalance: entity.currentBalance,
      lastUpdated: entity.lastUpdated,
      updatedBy: entity.updatedBy,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'currentBalance': currentBalance,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'updatedBy': updatedBy,
    };
  }

  @override
  CashboxBalanceModel copyWith({
    double? currentBalance,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return CashboxBalanceModel(
      currentBalance: currentBalance ?? this.currentBalance,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
