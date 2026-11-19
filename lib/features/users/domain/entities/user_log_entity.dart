import 'package:equatable/equatable.dart';

/// كيان سجل نشاطات المستخدم
class UserLogEntity extends Equatable {
  const UserLogEntity({
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
  factory UserLogEntity.fromMap(Map<String, dynamic> map) {
    return UserLogEntity(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'],
      userEmail: map['userEmail'],
      actionType: map['actionType'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
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

  /// معرف السجل
  final String id;

  /// معرف المستخدم الذي قام بالعملية
  final String userId;

  /// اسم المستخدم
  final String? userName;

  /// بريد المستخدم الإلكتروني
  final String? userEmail;

  /// نوع العملية (login, logout, create, update, delete, view)
  final String actionType;

  /// وقت العملية
  final DateTime timestamp;

  /// تفاصيل إضافية عن العملية
  final String? details;

  /// هل نجحت العملية أم لا
  final bool isSuccess;

  /// عنوان IP الخاص بالمستخدم
  final String? ipAddress;

  /// معلومات المتصفح/التطبيق
  final String? userAgent;

  /// معرف الكائن المستهدف (إذا كانت العملية تتعلق بكائن محدد)
  final String? targetId;

  /// نوع الكائن المستهدف (user, customer, invoice, etc.)
  final String? targetType;

  /// القيم القديمة (للتحديثات)
  final Map<String, dynamic>? oldValues;

  /// القيم الجديدة (للتحديثات)
  final Map<String, dynamic>? newValues;

  /// معرف الجلسة
  final String? sessionId;

  /// معلومات الجهاز
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

  /// نسخ الكيان مع تعديل بعض القيم
  UserLogEntity copyWith({
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
    return UserLogEntity(
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

  /// الحصول على وصف مختصر للعملية
  String get actionDescription {
    switch (actionType) {
      case 'login':
        return 'تسجيل دخول';
      case 'logout':
        return 'تسجيل خروج';
      case 'create':
        return 'إنشاء ${_getTargetTypeText()}';
      case 'update':
        return 'تحديث ${_getTargetTypeText()}';
      case 'delete':
        return 'حذف ${_getTargetTypeText()}';
      case 'view':
        return 'عرض ${_getTargetTypeText()}';
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
      case 'user':
        return 'مستخدم';
      case 'customer':
        return 'عميل';
      case 'invoice':
        return 'فاتورة';
      case 'expense':
        return 'مصروف';
      case 'inventory':
        return 'مخزون';
      case 'rental':
        return 'إيجار';
      case 'maintenance':
        return 'صيانة';
      case 'report':
        return 'تقرير';
      case 'setting':
        return 'إعداد';
      default:
        return targetType ?? 'عنصر';
    }
  }

  /// الحصول على لون الحالة
  String get statusColor {
    return isSuccess ? 'success' : 'error';
  }

  /// الحصول على أيقونة العملية
  String get actionIcon {
    switch (actionType) {
      case 'login':
        return 'login';
      case 'logout':
        return 'logout';
      case 'create':
        return 'add';
      case 'update':
        return 'edit';
      case 'delete':
        return 'delete';
      case 'view':
        return 'visibility';
      case 'export':
        return 'download';
      case 'import':
        return 'upload';
      default:
        return 'info';
    }
  }

  @override
  String toString() {
    return 'UserLogEntity(id: $id, userId: $userId, actionType: $actionType, timestamp: $timestamp, isSuccess: $isSuccess)';
  }
}
