import 'package:equatable/equatable.dart';

import '../validators/subscription_validator.dart';

/// كيان الاشتراك
class SubscriptionEntity extends Equatable {
  const SubscriptionEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.duration,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.organizationEmail,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.customerId,
    this.customerName,
    this.customerPhone, // رقم هاتف العميل
    this.customDays,
    this.description,
    this.features,
    this.updatedBy,
    this.isAutoRenew = false,
    this.isPaid = false,
    this.renewalCount = 0,
    this.lastRenewalDate,
    this.nextBillingDate,
    this.totalPaid = 0.0,
    this.remainingAmount = 0.0,
    this.discountAmount = 0.0, // مبلغ الخصم
    this.taxAmount = 0.0, // مبلغ الضريبة
    this.taxes, // قائمة الضرائب التفصيلية [{name, rate, amount, isPercentage}]
    this.subscriptionTypeId, // معرف نوع الاشتراك للربط
    this.priceAtCreation, // السعر وقت الإنشاء (للتاريخ)
    this.currentPrice, // السعر الحالي (يجلب من النوع عند القراءة)
  });
  final String id;
  final String name;
  final String type;
  final double price;
  final String duration; // daily, weekly, monthly, quarterly, yearly, custom
  final int? customDays; // عدد الأيام للمدة المخصصة
  final String status; // active, expired, cancelled, suspended, pending
  final DateTime startDate;
  final DateTime endDate;
  final String organizationEmail;
  final String? customerId; // معرف العميل
  final String? customerName; // اسم العميل للعرض
  final String? customerPhone; // رقم هاتف العميل
  final String? description;
  final Map<String, dynamic>? features;
  final DateTime createdAt; // تاريخ الإنشاء
  final DateTime updatedAt; // تاريخ آخر تحديث
  final String createdBy;
  final String? updatedBy;
  final bool isAutoRenew; // التجديد التلقائي
  final bool isPaid; // تم الدفع
  final int renewalCount; // عدد مرات التجديد
  final DateTime? lastRenewalDate; // تاريخ آخر تجديد
  final DateTime? nextBillingDate; // تاريخ الفاتورة التالية
  final double totalPaid; // إجمالي المدفوع
  final double remainingAmount; // المبلغ المتبقي
  final double discountAmount; // مبلغ الخصم
  final double taxAmount; // مبلغ الضريبة
  final List<Map<String, dynamic>>? taxes; // قائمة الضرائب التفصيلية
  final String? subscriptionTypeId; // معرف نوع الاشتراك للربط
  final double? priceAtCreation; // السعر وقت الإنشاء (للتاريخ)
  final double? currentPrice; // السعر الحالي (يجلب من النوع عند القراءة)

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    price,
    duration,
    customDays,
    status,
    startDate,
    endDate,
    organizationEmail,
    customerId,
    customerName,
    customerPhone,
    description,
    features,
    createdAt,
    updatedAt,
    createdBy,
    updatedBy,
    isAutoRenew,
    isPaid,
    renewalCount,
    lastRenewalDate,
    nextBillingDate,
    totalPaid,
    remainingAmount,
    discountAmount,
    taxAmount,
    taxes,
    subscriptionTypeId,
    priceAtCreation,
    currentPrice,
  ];

  /// نسخ الكيان مع تحديث بعض الحقول
  SubscriptionEntity copyWith({
    String? id,
    String? name,
    String? type,
    double? price,
    String? duration,
    int? customDays,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? organizationEmail,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? description,
    Map<String, dynamic>? features,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    bool? isAutoRenew,
    bool? isPaid,
    int? renewalCount,
    DateTime? lastRenewalDate,
    DateTime? nextBillingDate,
    double? totalPaid,
    double? remainingAmount,
    double? discountAmount,
    double? taxAmount,
    List<Map<String, dynamic>>? taxes,
    String? subscriptionTypeId,
    double? priceAtCreation,
    double? currentPrice,
  }) {
    return SubscriptionEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      customDays: customDays ?? this.customDays,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      description: description ?? this.description,
      features: features ?? this.features,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      isAutoRenew: isAutoRenew ?? this.isAutoRenew,
      isPaid: isPaid ?? this.isPaid,
      renewalCount: renewalCount ?? this.renewalCount,
      lastRenewalDate: lastRenewalDate ?? this.lastRenewalDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      totalPaid: totalPaid ?? this.totalPaid,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      taxes: taxes ?? this.taxes,
      subscriptionTypeId: subscriptionTypeId ?? this.subscriptionTypeId,
      priceAtCreation: priceAtCreation ?? this.priceAtCreation,
      currentPrice: currentPrice ?? this.currentPrice,
    );
  }

  /// التحقق من انتهاء الاشتراك
  /// ⚠️ ملاحظة توثيقية للمبرمجين المستقبليين: تُقارن التواريخ بالتوقيت العالمي (UTC)
  /// حيث today = بداية اليوم UTC و end = بداية تاريخ النهاية UTC. لذلك أي اشتراك
  /// ends في اليوم نفسه يُعتبر منتهياً (end.isBefore(today)）→ إذا endDate في
  /// منتصف الليل UTC والنظام في منطقة توقيت أخرى قد تظهر نتيجة غير متوقعة.
  /// كما أن expired تعتمد على الحقل status == 'expired' OR التاريخ منقضي —
  /// اشتراك حالته 'active' but endDate مضى يُعتبر منتهي هنا.
  bool get isExpired {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    return status == 'expired' || end.isBefore(today);
  }

  /// التحقق من قرب انتهاء الاشتراك (خلال 3 أيام أو اليوم)
  bool get isExpiringSoon {
    if (isExpired || status == 'cancelled' || status == 'suspended') {
      return false;
    }
    final days = daysRemaining;
    return days >= 0 && days <= 3;
  }

  /// حساب الأيام المتبقية (قيمة موجبة للأيام المتبقية، 0 لليوم الحالي، سالبة إذا انتهى)
  int get daysRemaining {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    return end.difference(today).inDays;
  }

  /// حساب نسبة الاستخدام
  /// جميع التواريخ تُقارن بالتوقيت العالمي (UTC) لتجنب divergence بين التوقيت
  /// المحلي والUTC بالقرب من تغيير التوقيت الصيفي أو عند اختلاف منطقة النظام.
  double get usagePercentage {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    final totalDays = end.difference(start).inDays;
    final usedDays = today.difference(start).inDays;

    if (totalDays <= 0) return 0;
    if (usedDays <= 0) return 0; // إذا كان التاريخ الحالي قبل تاريخ البدء
    if (usedDays >= totalDays) return 1;

    return usedDays / totalDays;
  }

  /// التحقق من إمكانية التجديد
  bool get canRenew => status == 'active' || status == 'expired';

  /// حساب تاريخ التجديد التالي
  DateTime get nextRenewalDate {
    final now = DateTime.now().toUtc();
    final endUtc = DateTime.utc(endDate.year, endDate.month, endDate.day);
    final baseDate = now.isAfter(endUtc) ? now : endUtc;

    return _calculateEndDateFromStart(baseDate, duration, customDays);
  }

  /// حساب تاريخ النهاية من تاريخ البداية
  static DateTime _calculateEndDateFromStart(
    DateTime startDate,
    String duration,
    int? customDays,
  ) {
    switch (duration) {
      case 'daily':
        return startDate.add(const Duration(days: 1));
      case 'weekly':
        return startDate.add(const Duration(days: 7));
      case 'monthly':
        // إضافة شهر واحد مع معالجة تجاوز عدد أيام الشهر
        return _addMonthsToDate(startDate, 1);
      case 'quarterly':
        // إضافة 3 أشهر مع معالجة تجاوز عدد أيام الشهر
        return _addMonthsToDate(startDate, 3);
      case 'yearly':
        // إضافة سنة واحدة (12 شهر) مع معالجة تجاوز عدد أيام الشهر
        return _addMonthsToDate(startDate, 12);
      case 'custom':
        if (customDays == null || customDays <= 0) {
          throw ArgumentError('عدد الأيام المخصصة يجب أن يكون أكبر من صفر');
        }
        return startDate.add(Duration(days: customDays));
      default:
        return _addMonthsToDate(startDate, 1);
    }
  }

  /// إضافة عدد من الأشهر مع معالجة تجاوز عدد أيام الشهر
  /// مثال: 31 يناير + شهر = 28 فبراير (وليس 3 مارس)
  static DateTime _addMonthsToDate(DateTime date, int months) {
    // حساب السنة والشهر الجديد
    var newYear = date.year;
    var newMonth = date.month + months;

    // معالجة تجاوز الأشهر (أكثر من 12)
    while (newMonth > 12) {
      newMonth -= 12;
      newYear += 1;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear -= 1;
    }

    // الحصول على آخر يوم في الشهر الجديد
    var lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;

    // استخدام اليوم الأصلي أو آخر يوم في الشهر (أيهما أقل)
    var newDay = date.day > lastDayOfNewMonth ? lastDayOfNewMonth : date.day;

    // إنشاء التاريخ الجديد مع الحفاظ على الوقت
    return DateTime(
      newYear,
      newMonth,
      newDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  /// حساب تاريخ النهاية للاشتراك الجديد
  static DateTime calculateEndDate(
    DateTime startDate,
    String duration,
    int? customDays,
  ) {
    return _calculateEndDateFromStart(startDate, duration, customDays);
  }

  /// التحقق من صحة بيانات الاشتراك
  String? validate() {
    // التحقق من الاسم
    final nameError = SubscriptionValidator.validateName(name);
    if (nameError != null) return nameError;

    // التحقق من النوع
    final typeError = SubscriptionValidator.validateType(type);
    if (typeError != null) return typeError;

    // التحقق من السعر
    final priceError = SubscriptionValidator.validatePrice(price);
    if (priceError != null) return priceError;

    // التحقق من المدة
    final durationError = SubscriptionValidator.validateDuration(duration);
    if (durationError != null) return durationError;

    // التحقق من المدة المخصصة
    final customDaysError = SubscriptionValidator.validateCustomDays(
      customDays,
      duration,
    );
    if (customDaysError != null) return customDaysError;

    // التحقق من التواريخ
    final datesError = SubscriptionValidator.validateDates(startDate, endDate);
    if (datesError != null) return datesError;

    // التحقق من الحالة
    final statusError = SubscriptionValidator.validateStatus(status);
    if (statusError != null) return statusError;

    // التحقق من معلومات الدفع
    final paymentError = SubscriptionValidator.validatePayment(
      totalPaid,
      price,
      remainingAmount,
    );
    if (paymentError != null) return paymentError;

    return null;
  }

  /// التحقق من صحة انتقال الحالة
  bool canTransitionTo(String newStatus) {
    switch (status) {
      case 'pending':
        return ['active', 'cancelled'].contains(newStatus);
      case 'active':
        return ['expired', 'cancelled', 'suspended'].contains(newStatus);
      case 'suspended':
        return ['active', 'cancelled'].contains(newStatus);
      case 'expired':
        return ['active', 'cancelled'].contains(newStatus);
      case 'cancelled':
        return ['active', 'pending'].contains(newStatus);
      default:
        return false;
    }
  }

  /// تحويل الكيان إلى JSON
  /// ⚠️ ملاحظة مهمة للمبرمجين المستقبليين:
  /// هذه الدالة تستخدم لتحويل الكيان إلى Map
  /// لاستخدامه في Firestore أو في سجلات الاشتراكات.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'price': price,
      'duration': duration,
      'customDays': customDays,
      'status': status,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'organizationEmail': organizationEmail,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'description': description,
      'features': features,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'isAutoRenew': isAutoRenew,
      'isPaid': isPaid,
      'renewalCount': renewalCount,
      'lastRenewalDate': lastRenewalDate?.toIso8601String(),
      'nextBillingDate': nextBillingDate?.toIso8601String(),
      'totalPaid': totalPaid,
      'remainingAmount': remainingAmount,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'taxes': taxes,
      'subscriptionTypeId': subscriptionTypeId,
      'priceAtCreation': priceAtCreation,
      'currentPrice': currentPrice,
    };
  }
}
