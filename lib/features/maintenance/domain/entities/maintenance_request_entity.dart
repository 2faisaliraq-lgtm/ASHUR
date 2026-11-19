import 'package:equatable/equatable.dart';

/// كيان طلب الصيانة
class MaintenanceRequestEntity extends Equatable {
  // تغيير إلى اختياري لدعم البيانات القديمة

  const MaintenanceRequestEntity({
    required this.id,
    required this.organizationEmail,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.requestDate,
    required this.requestedBy,
    required this.createdAt,
    this.assignedTo,
    this.equipmentId,
    this.equipmentName,
    this.location,
    this.customerId, // معرف العميل
    this.customerName, // اسم العميل للعرض
    this.scheduledDate,
    this.completedDate,
    this.estimatedCost,
    this.actualCost,
    this.attachments,
    this.notes,
    this.updatedAt,
    this.updatedBy,
    this.createdBy, // تغيير إلى اختياري
  });
  final String id;
  final String organizationEmail;
  final String title;
  final String description;
  final String status; // pending, in_progress, completed, cancelled
  final String priority; // low, medium, high, urgent
  final String? assignedTo;
  final String? equipmentId;
  final String? equipmentName;
  final String? location;
  final String? customerId; // معرف العميل
  final String? customerName; // اسم العميل للعرض
  final DateTime requestDate;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final String requestedBy;
  final double? estimatedCost;
  final double? actualCost;
  final List<String>? attachments;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? createdBy;

  @override
  List<Object?> get props => [
    id,
    organizationEmail,
    title,
    description,
    status,
    priority,
    assignedTo,
    equipmentId,
    equipmentName,
    location,
    customerId,
    customerName,
    requestDate,
    scheduledDate,
    completedDate,
    requestedBy,
    estimatedCost,
    actualCost,
    attachments,
    notes,
    createdAt,
    updatedAt,
    updatedBy,
    createdBy, // إضافة createdBy إلى props
  ];

  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isUrgent => priority == 'urgent';

  /// التحقق من التأخير مقابل وقت محدد (الافتراضي وقت النظام)
  bool isOverdueAt(DateTime currentTime) =>
      scheduledDate != null &&
      scheduledDate!.isBefore(currentTime) &&
      !isCompleted;

  /// التحقق من التأخير باستخدام وقت النظام الحالي (للاستخدام العام)
  bool get isOverdue => isOverdueAt(DateTime.now());

  /// التحقق من إمكانية الانتقال إلى حالة معينة
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين (محدث 2026-10-20):
  /// هذه الدالة تستخدم نفس قواعد الانتقال في
  /// MaintenanceValidator.validateStatusTransition.
  /// ``allowedTransitions`` هو مصدر الحقيقة الوحيد لكل منهما.
  /// عند تغيير قاعدة انتقال، غيّر ``allowedTransitions`` فقط.
  static Map<String, List<String>> get allowedTransitions => {
    'pending': ['in_progress', 'cancelled'],
    'in_progress': ['completed', 'cancelled', 'pending'],
    'completed': [], // حالة نهائية — لا انتقال منها
    'cancelled': ['pending'], // يمكن إعادة تفعيل الطلب الملغي
  };

  bool canTransitionTo(String newStatus) {
    final allowed = allowedTransitions[status] ?? [];
    return allowed.contains(newStatus);
  }

  MaintenanceRequestEntity copyWith({
    String? id,
    String? organizationEmail,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assignedTo,
    String? equipmentId,
    String? equipmentName,
    String? location,
    String? customerId,
    String? customerName,
    DateTime? requestDate,
    DateTime? scheduledDate,
    DateTime? completedDate,
    String? requestedBy,
    double? estimatedCost,
    double? actualCost,
    List<String>? attachments,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    String? createdBy,
  }) {
    return MaintenanceRequestEntity(
      id: id ?? this.id,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      location: location ?? this.location,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      requestDate: requestDate ?? this.requestDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      requestedBy: requestedBy ?? this.requestedBy,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
