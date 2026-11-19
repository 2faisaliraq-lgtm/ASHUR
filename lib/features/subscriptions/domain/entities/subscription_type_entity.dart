import 'package:equatable/equatable.dart';

/// كيان نوع الاشتراك
class SubscriptionTypeEntity extends Equatable {
  const SubscriptionTypeEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.duration,
    required this.features,
    required this.isActive,
    this.customDays,
    this.activationQuantity = 0,
    this.linkedSubscriptionsCount = 0,
    this.createdBy = '',
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });
  final String id;
  final String name;
  final String description;
  final double price;
  final String duration; // daily, weekly, monthly, quarterly, yearly, custom
  final int? customDays; // عدد الأيام للمدة المخصصة
  final List<String> features;
  final bool isActive;
  final int activationQuantity; // حساب التفعيلات المتاح
  final int linkedSubscriptionsCount; // عدد الاشتراكات المرتبطة بهذا النوع
  final String createdBy; // معرف المستخدم الذي أنشأ النوع
  final String? updatedBy; // معرف المستخدم الذي حدّث النوع
  final DateTime? createdAt; // تاريخ الإنشاء
  final DateTime? updatedAt; // تاريخ آخر تحديث

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    price,
    duration,
    customDays,
    features,
    isActive,
    activationQuantity,
    linkedSubscriptionsCount,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
  ];

  SubscriptionTypeEntity copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? duration,
    int? customDays,
    List<String>? features,
    bool? isActive,
    int? activationQuantity,
    int? linkedSubscriptionsCount,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionTypeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      customDays: customDays ?? this.customDays,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
      activationQuantity: activationQuantity ?? this.activationQuantity,
      linkedSubscriptionsCount: linkedSubscriptionsCount ?? this.linkedSubscriptionsCount,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
