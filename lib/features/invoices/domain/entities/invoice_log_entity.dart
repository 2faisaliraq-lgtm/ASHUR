import 'package:equatable/equatable.dart';

/// كيان سجل نشاطات الفواتير
class InvoiceLogEntity extends Equatable {
  const InvoiceLogEntity({
    required this.id,
    required this.userId,
    required this.actionType,
    required this.timestamp,
    required this.isSuccess,
    this.userName,
    this.userEmail,
    this.details,
    this.ipAddress,
    this.userAgent,
    this.targetId,
    this.targetType,
    this.oldValues,
    this.newValues,
    this.sessionId,
    this.deviceInfo,
  });

  /// إنشاء من Map
  factory InvoiceLogEntity.fromMap(Map<String, dynamic> map) {
    return InvoiceLogEntity(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'],
      userEmail: map['userEmail'],
      actionType: map['actionType'] ?? '',
      // ⚠️ ملاحظة للمبرمجين المستقبليين:
      // DateTime.parse قد يلقي استثناء إذا كانت القيمة فارغة أو غير صالحة.
      // استخدم DateTime.tryParse مع قيمة افتراضية إذا كانت البيانات قد تكون تالفة.
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime(2000, 1, 1),
      details: map['details'],
      isSuccess: map['isSuccess'] ?? false,
      ipAddress: map['ipAddress'],
      userAgent: map['userAgent'],
      targetId: map['targetId'],
      targetType: map['targetType'],
      oldValues: map['oldValues'] != null
          ? Map<String, dynamic>.from(map['oldValues'])
          : null,
      newValues: map['newValues'] != null
          ? Map<String, dynamic>.from(map['newValues'])
          : null,
      sessionId: map['sessionId'],
      deviceInfo: map['deviceInfo'] != null
          ? Map<String, dynamic>.from(map['deviceInfo'])
          : null,
    );
  }

  // جميع الخصائص المطلوبة
  final String id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String actionType;
  final DateTime timestamp;
  final String? details;
  final bool isSuccess;
  final String? ipAddress;
  final String? userAgent;
  final String? targetId;
  final String? targetType;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? sessionId;
  final Map<String, dynamic>? deviceInfo;

  @override
  List<Object?> get props => [
    id,
    userId,
    userName,
    userEmail,
    actionType,
    timestamp,
    details,
    isSuccess,
    ipAddress,
    userAgent,
    targetId,
    targetType,
    oldValues,
    newValues,
    sessionId,
    deviceInfo,
  ];

  /// الحصول على وصف مختصر للعملية
  String get actionDescription {
    switch (actionType) {
      case 'create':
        return 'إنشاء ${_getTargetTypeText()}';
      case 'update':
        return 'تحديث ${_getTargetTypeText()}';
      case 'delete':
        return 'حذف ${_getTargetTypeText()}';
      case 'view':
        return 'عرض ${_getTargetTypeText()}';
      case 'send':
        return 'إرسال ${_getTargetTypeText()}';
      case 'pay':
        return 'دفع ${_getTargetTypeText()}';
      case 'cancel':
        return 'إلغاء ${_getTargetTypeText()}';
      case 'refund':
        return 'استرداد ${_getTargetTypeText()}';
      case 'export':
        return 'تصدير ${_getTargetTypeText()}';
      case 'import':
        return 'استيراد ${_getTargetTypeText()}';
      default:
        return actionType;
    }
  }

  /// الحصول على نص نوع الكائن المستهدف
  String _getTargetTypeText() {
    switch (targetType) {
      case 'invoice':
        return 'فاتورة';
      case 'payment':
        return 'دفعة';
      case 'refund':
        return 'استرداد';
      case 'reminder':
        return 'تذكير';
      case 'receipt':
        return 'إيصال';
      default:
        return targetType ?? 'عنصر';
    }
  }

  /// نسخ الكيان مع تعديل بعض القيم
  InvoiceLogEntity copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? actionType,
    DateTime? timestamp,
    String? details,
    bool? isSuccess,
    String? ipAddress,
    String? userAgent,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? sessionId,
    Map<String, dynamic>? deviceInfo,
  }) {
    return InvoiceLogEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      actionType: actionType ?? this.actionType,
      timestamp: timestamp ?? this.timestamp,
      details: details ?? this.details,
      isSuccess: isSuccess ?? this.isSuccess,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      oldValues: oldValues ?? this.oldValues,
      newValues: newValues ?? this.newValues,
      sessionId: sessionId ?? this.sessionId,
      deviceInfo: deviceInfo ?? this.deviceInfo,
    );
  }

  /// تحويل إلى Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'actionType': actionType,
      'timestamp': timestamp.toIso8601String(),
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

  @override
  String toString() {
    return 'InvoiceLogEntity(id: $id, userId: $userId, actionType: $actionType, timestamp: $timestamp, isSuccess: $isSuccess)';
  }
}
