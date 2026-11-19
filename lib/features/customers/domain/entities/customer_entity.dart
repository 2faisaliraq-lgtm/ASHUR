import 'package:equatable/equatable.dart';

/// كيان العميل
class CustomerEntity extends Equatable {
  const CustomerEntity({
    required this.id,
    required this.organizationEmail,
    required this.name,
    required this.email,
    required this.phone,
    required this.totalPurchases,
    required this.totalDebt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.address,
    this.customerGroupId,
    this.customerGroupName,
    this.creditLimit,
    this.openingBalance,
    this.notes,
    this.createdBy,
    this.updatedBy,
    this.invoiceIds = const [],
    this.logIds = const [],
  });
  final String id;
  final String organizationEmail;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? customerGroupId; // معرف مجموعة العميل
  final String? customerGroupName; // اسم مجموعة العميل
  final double totalPurchases;
  final double totalDebt; // ⚠️ حقل تراكمي - يجب تحديثه ذرياً فقط داخل runTransaction أو عبر FieldValue.increment() لتجنب تحديثات مفقودة (lost updates) عند المعالجة المتزامنة. لا تحسب هذا الحقل خارج العمليات الذرية إلا إذا كنت تريد تعديله يدوياً في منطق الفواتير لاحقاً.
  final double? creditLimit; // حد الدين
  final double? openingBalance; // الحساب الافتتاحي
  final String status; // active, inactive, blocked
  final String? notes;
  final String? createdBy; // البريد الإلكتروني للمستخدم الذي أنشأ العميل
  final String? updatedBy; // معرف المستخدم الذي حدّث العميل
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> invoiceIds; // معرفات الفواتير المرتبطة - يُحدَّث ذرياً فقط باستخدام arrayUnion/arrayRemove لمنع نافذة السباق في deleteCustomer
  final List<String> logIds; // معرفات سجلات النشاط - يُحدَّث ذرياً فقط باستخدام arrayUnion/arrayRemove لمنع نافذة السباق في deleteCustomer

  bool get isActive => status == 'active';
  bool get isInactive => status == 'inactive';
  bool get isBlocked => status == 'blocked';
  bool get hasGroup => customerGroupId != null && customerGroupId!.isNotEmpty;

  /// هل العميل مدين (عليه مال)؟ (totalDebt > 0)
  bool get hasDebt => totalDebt > 0;

  /// هل العميل دائن (له مال)؟ (totalDebt < 0)
  bool get hasCredit => totalDebt < 0;

  /// هل العميل متعادل (لا دين عليه ولا له مال)؟ (totalDebt == 0)
  bool get isBalanced => totalDebt == 0;

  /// مقدار الدين (إذا كان مديناً)
  double get debtAmount {
    if (hasDebt) {
      return totalDebt;
    } else {
      return 0.0;
    }
  }

  /// مقدار الائتمان (إذا كان دائنًا) - كقيمة موجبة
  double get creditAmount {
    if (hasCredit) {
      return totalDebt.abs();
    } else {
      return 0.0;
    }
  }

  /// صافي الحساب (إيجابي = مدين، سالب = دائن، صفر = متوازن)
  double get netBalance => totalDebt;

  /// التحقق من إمكانية الانتقال من الحالة الحالية إلى الحالة الجديدة
  bool canTransitionToStatus(String newStatus) {
    // السماح بالبقاء في نفس الحالة
    if (newStatus == status) return true;

    // التحقق من صحة الحالة الجديدة
    if (!['active', 'inactive', 'blocked'].contains(newStatus)) {
      return false;
    }

    // قواعد الانتقال بين الحالات
    switch (status) {
      case 'active':
        // من النشط يمكن الانتقال إلى غير نشط أو محظور
        return newStatus == 'inactive' || newStatus == 'blocked';
      case 'inactive':
        // من غير النشط يمكن الانتقال إلى نشط أو محظور
        return newStatus == 'active' || newStatus == 'blocked';
      case 'blocked':
        // من المحظور يمكن فقط الانتقال إلى نشط أو غير نشط (يحتاج مراجعة إدارية)
        return newStatus == 'active' || newStatus == 'inactive';
      default:
        return false;
    }
  }

  /// نسخ الكيان مع تعديل بعض الخصائص
  CustomerEntity copyWith({
    String? id,
    String? organizationEmail,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? customerGroupId,
    String? customerGroupName,
    double? totalPurchases,
    double? totalDebt,
    double? creditLimit,
    double? openingBalance,
    String? status,
    String? notes,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? invoiceIds,
    List<String>? logIds,
  }) {
    return CustomerEntity(
      id: id ?? this.id,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      customerGroupId: customerGroupId ?? this.customerGroupId,
      customerGroupName: customerGroupName ?? this.customerGroupName,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalDebt: totalDebt ?? this.totalDebt,
      creditLimit: creditLimit ?? this.creditLimit,
      openingBalance: openingBalance ?? this.openingBalance,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      invoiceIds: invoiceIds ?? this.invoiceIds,
      logIds: logIds ?? this.logIds,
    );
  }

  @override
  List<Object?> get props => [
    id,
    organizationEmail,
    name,
    email,
    phone,
    address,
    customerGroupId,
    customerGroupName,
    totalPurchases,
    totalDebt,
    creditLimit,
    openingBalance,
    status,
    notes,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    invoiceIds,
    logIds,
  ];
}

extension CustomerBalanceExtension on CustomerEntity {
  /// هل يتجاوز العميل حد الائتمان الخاص به؟
  bool get exceedsCreditLimit {
    if (creditLimit == null || creditLimit! <= 0) return false;
    // يتجاوز الحد إذا كان الدين الموجب أكبر من الحد الائتماني
    return totalDebt > creditLimit!;
  }

  /// الحد الائتماني المتبقي (سالب إذا تجاوز الحد)
  double get remainingCreditLimit {
    if (creditLimit == null) return 0.0;
    // الحد المتبقي = الحد - الديون المطلوبة (الموجبة فقط)
    if (totalDebt > 0) {
      return creditLimit! - totalDebt;
    } else {
      return creditLimit!;
    }
  }
}
