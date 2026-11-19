import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/invoice_template_entity.dart';

class InvoiceTemplateModel extends InvoiceTemplateEntity {
  const InvoiceTemplateModel({
    required super.id,
    required super.name,
    required super.type,
    required super.headerColor,
    required super.accentColor,
    required super.showLogo,
    required super.logoPosition,
    required super.showCompanyInfo,
    required super.showCustomerInfo,
    required super.showItemsTable,
    required super.showNotes,
    required super.showSignature,
    required super.footerText,
    required super.isDefault,
    super.customFields,
  });

  factory InvoiceTemplateModel.fromJson(Map<String, dynamic> json) {
    return InvoiceTemplateModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      headerColor: json['headerColor'] as String,
      accentColor: json['accentColor'] as String,
      showLogo: json['showLogo'] as bool,
      logoPosition: json['logoPosition'] as String,
      showCompanyInfo: json['showCompanyInfo'] as bool,
      showCustomerInfo: json['showCustomerInfo'] as bool,
      showItemsTable: json['showItemsTable'] as bool,
      showNotes: json['showNotes'] as bool,
      showSignature: json['showSignature'] as bool,
      footerText: json['footerText'] as String,
      isDefault: json['isDefault'] as bool,
      customFields: json['customFields'] as Map<String, dynamic>?,
    );
  }

  factory InvoiceTemplateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return InvoiceTemplateModel.fromJson({...data, 'id': doc.id});
  }

  @override
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

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }
}
