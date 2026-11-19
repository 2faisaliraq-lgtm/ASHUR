import 'package:equatable/equatable.dart';

/// كيان تجديد الاشتراك
class SubscriptionRenewalEntity extends Equatable {

  const SubscriptionRenewalEntity({
    required this.id,
    required this.subscriptionId,
    required this.renewalDate,
    required this.status,
    required this.autoRenew,
    this.notes,
  });
  final String id;
  final String subscriptionId;
  final DateTime renewalDate;
  final String status;
  final bool autoRenew;
  final String? notes;

  @override
  List<Object?> get props => [
    id,
    subscriptionId,
    renewalDate,
    status,
    autoRenew,
    notes,
  ];
}
