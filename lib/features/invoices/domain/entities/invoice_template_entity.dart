import 'package:equatable/equatable.dart';

/// كيان قالب الفاتورة
class InvoiceTemplateEntity extends Equatable {
  const InvoiceTemplateEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.headerColor,
    required this.accentColor,
    required this.showLogo,
    required this.logoPosition,
    required this.showCompanyInfo,
    required this.showCustomerInfo,
    required this.showItemsTable,
    required this.showNotes,
    required this.showSignature,
    required this.footerText,
    required this.isDefault,
    this.customFields,
  });

  final String id;
  final String name; // اسم القالب (مثل: قالب المبيعات، قالب الاشتراكات)
  final String type; // نوع الفاتورة (sales, purchase, subscription, etc.)
  final String headerColor; // لون الهيدر (hex color)
  final String accentColor; // اللون الثانوي (hex color)
  final bool showLogo; // إظهار الشعار
  final String logoPosition; // موقع الشعار (left, center, right)
  final bool showCompanyInfo; // إظهار معلومات الشركة
  final bool showCustomerInfo; // إظهار معلومات العميل
  final bool showItemsTable; // إظهار جدول الأصناف
  final bool showNotes; // إظهار الملاحظات
  final bool showSignature; // إظهار التوقيع
  final String footerText; // نص التذييل
  final bool isDefault; // هل هذا القالب الافتراضي
  final Map<String, dynamic>? customFields; // حقول مخصصة إضافية

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        headerColor,
        accentColor,
        showLogo,
        logoPosition,
        showCompanyInfo,
        showCustomerInfo,
        showItemsTable,
        showNotes,
        showSignature,
        footerText,
        isDefault,
        customFields,
      ];

  InvoiceTemplateEntity copyWith({
    String? id,
    String? name,
    String? type,
    String? headerColor,
    String? accentColor,
    bool? showLogo,
    String? logoPosition,
    bool? showCompanyInfo,
    bool? showCustomerInfo,
    bool? showItemsTable,
    bool? showNotes,
    bool? showSignature,
    String? footerText,
    bool? isDefault,
    Map<String, dynamic>? customFields,
  }) {
    return InvoiceTemplateEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      headerColor: headerColor ?? this.headerColor,
      accentColor: accentColor ?? this.accentColor,
      showLogo: showLogo ?? this.showLogo,
      logoPosition: logoPosition ?? this.logoPosition,
      showCompanyInfo: showCompanyInfo ?? this.showCompanyInfo,
      showCustomerInfo: showCustomerInfo ?? this.showCustomerInfo,
      showItemsTable: showItemsTable ?? this.showItemsTable,
      showNotes: showNotes ?? this.showNotes,
      showSignature: showSignature ?? this.showSignature,
      footerText: footerText ?? this.footerText,
      isDefault: isDefault ?? this.isDefault,
      customFields: customFields ?? this.customFields,
    );
  }

  /// إنشاء كيان من Map (للاسترجاع من Firestore)
  factory InvoiceTemplateEntity.fromJson(Map<String, dynamic> json) {
    return InvoiceTemplateEntity(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'general',
      headerColor: json['headerColor'] ?? '#1B365D',
      accentColor: json['accentColor'] ?? '#D4AF37',
      showLogo: json['showLogo'] ?? true,
      logoPosition: json['logoPosition'] ?? 'right',
      showCompanyInfo: json['showCompanyInfo'] ?? true,
      showCustomerInfo: json['showCustomerInfo'] ?? true,
      showItemsTable: json['showItemsTable'] ?? true,
      showNotes: json['showNotes'] ?? true,
      showSignature: json['showSignature'] ?? false,
      footerText: json['footerText'] ?? 'شكراً لتعاملكم معنا',
      isDefault: json['isDefault'] ?? false,
      customFields: json['customFields'] != null
          ? Map<String, dynamic>.from(json['customFields'])
          : null,
    );
  }

  /// تحويل الكيان إلى Map (لحفظه في Firestore)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'headerColor': headerColor,
      'accentColor': accentColor,
      'showLogo': showLogo,
      'logoPosition': logoPosition,
      'showCompanyInfo': showCompanyInfo,
      'showCustomerInfo': showCustomerInfo,
      'showItemsTable': showItemsTable,
      'showNotes': showNotes,
      'showSignature': showSignature,
      'footerText': footerText,
      'isDefault': isDefault,
      'customFields': customFields,
    };
  }
}
