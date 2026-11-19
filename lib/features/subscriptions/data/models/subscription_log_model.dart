import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/subscription_log_entity.dart';

/// نموذج سجل نشاطات الاشتراكات
class SubscriptionLogModel extends SubscriptionLogEntity {
  const SubscriptionLogModel({
    required super.id,
    required super.userId,
    required super.actionType,
    required super.timestamp,
    required super.isSuccess,
    super.userName,
    super.userEmail,
    super.details,
    super.ipAddress,
    super.userAgent,
    super.targetId,
    super.targetType,
    super.oldValues,
    super.newValues,
    super.sessionId,
    super.deviceInfo,
  });

  /// إنشاء من Entity
  factory SubscriptionLogModel.fromEntity(SubscriptionLogEntity entity) {
    return SubscriptionLogModel(
      id: entity.id,
      userId: entity.userId,
      userName: entity.userName,
      userEmail: entity.userEmail,
      actionType: entity.actionType,
      timestamp: entity.timestamp,
      details: entity.details,
      isSuccess: entity.isSuccess,
      ipAddress: entity.ipAddress,
      userAgent: entity.userAgent,
      targetId: entity.targetId,
      targetType: entity.targetType,
      oldValues: entity.oldValues,
      newValues: entity.newValues,
      sessionId: entity.sessionId,
      deviceInfo: entity.deviceInfo,
    );
  }

  /// إنشاء من JSON
  factory SubscriptionLogModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionLogModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'],
      userEmail: json['userEmail'],
      actionType: json['actionType'] ?? '',
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.parse(json['timestamp']),
      details: json['details'],
      isSuccess: json['isSuccess'] ?? false,
      ipAddress: json['ipAddress'],
      userAgent: json['userAgent'],
      targetId: json['targetId'],
      targetType: json['targetType'],
      oldValues: json['oldValues'] != null
          ? Map<String, dynamic>.from(json['oldValues'])
          : null,
      newValues: json['newValues'] != null
          ? Map<String, dynamic>.from(json['newValues'])
          : null,
      sessionId: json['sessionId'],
      deviceInfo: json['deviceInfo'] != null
          ? Map<String, dynamic>.from(json['deviceInfo'])
          : null,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'actionType': actionType,
      'timestamp': Timestamp.fromDate(timestamp),
      'details': details,
      'isSuccess': isSuccess,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'targetId': targetId,
      'targetType': targetType,
      'oldValues': oldValues,
      'newValues': newValues,
      'sessionId': sessionId,
      'deviceInfo': deviceInfo,
    };
  }

  /// تحويل إلى Entity
  SubscriptionLogEntity toEntity() {
    return SubscriptionLogEntity(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      actionType: actionType,
      timestamp: timestamp,
      details: details,
      isSuccess: isSuccess,
      ipAddress: ipAddress,
      userAgent: userAgent,
      targetId: targetId,
      targetType: targetType,
      oldValues: oldValues,
      newValues: newValues,
      sessionId: sessionId,
      deviceInfo: deviceInfo,
    );
  }
}
