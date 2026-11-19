import '../../domain/entities/invoice_template_entity.dart';
import '../templates/classic_invoice_template.dart';
import '../templates/colorful_invoice_template.dart';
import '../templates/elegant_invoice_template.dart';
import '../templates/minimal_invoice_template.dart';

/// القوالب الافتراضية للفواتير
// ignore: avoid_classes_with_only_static_members
class DefaultInvoiceTemplates {
  /// الحصول على جميع القوالب الافتراضية
  static List<InvoiceTemplateEntity> getAllDefaultTemplates() {
    return [
      getSalesTemplate(),
      getPurchaseTemplate(),
      getSubscriptionTemplate(),
      getMaintenanceTemplate(),
      getRentalTemplate(),
      getCashTemplate(),
      // القوالب الجديدة
      getColorfulTemplate(),
      getElegantTemplate(),
      getMinimalTemplate(),
    ];
  }

  /// القالب الملون - تصميم حيوي وجذاب
  static InvoiceTemplateEntity getColorfulTemplate() {
    return ColorfulInvoiceTemplate.create();
  }

  /// القالب الأنيق - تصميم راقي وهادئ
  static InvoiceTemplateEntity getElegantTemplate() {
    return ElegantInvoiceTemplate.create();
  }

  /// القالب البسيط - تصميم نظيف وواضح
  static InvoiceTemplateEntity getMinimalTemplate() {
    return MinimalInvoiceTemplate.create();
  }

  /// قالب فواتير المبيعات - يستخدم القالب الكلاسيكي
  static InvoiceTemplateEntity getSalesTemplate() {
    return ClassicInvoiceTemplate.create().copyWith(
      id: 'default_sales',
      type: 'sales',
      isDefault: true,
    );
  }

  /// قالب فواتير المشتريات - يستخدم القالب الكلاسيكي
  static InvoiceTemplateEntity getPurchaseTemplate() {
    return ClassicInvoiceTemplate.create().copyWith(
      id: 'default_purchase',
      type: 'purchase',
      headerColor: '#2E7D32',
      accentColor: '#66BB6A',
      footerText: 'فاتورة مشتريات - شكراً لتعاونكم',
      isDefault: true,
    );
  }

  /// قالب فواتير الاشتراكات - يستخدم القالب الكلاسيكي
  static InvoiceTemplateEntity getSubscriptionTemplate() {
    return ClassicInvoiceTemplate.create().copyWith(
      id: 'default_subscription',
      type: 'subscription',
      headerColor: '#D4AF37',
      accentColor: '#1B365D',
      logoPosition: 'center',
      footerText: 'شكراً لاشتراككم معنا - نتطلع لخدمتكم',
      isDefault: true,
    );
  }

  /// قالب فواتير الصيانة - يستخدم القالب الكلاسيكي
  static InvoiceTemplateEntity getMaintenanceTemplate() {
    return ClassicInvoiceTemplate.create().copyWith(
      id: 'default_maintenance',
      type: 'maintenance',
      headerColor: '#F57C00',
      accentColor: '#FFB74D',
      showSignature: true,
      footerText: 'فاتورة صيانة - نضمن جودة الخدمة',
      isDefault: true,
    );
  }

  /// قالب فواتير الإيجار - يستخدم القالب الكلاسيكي
  static InvoiceTemplateEntity getRentalTemplate() {
    return ClassicInvoiceTemplate.create().copyWith(
      id: 'default_rental',
      type: 'rental',
      headerColor: '#5E35B1',
      accentColor: '#9575CD',
      footerText: 'فاتورة إيجار - شكراً لثقتكم',
      isDefault: true,
    );
  }

  /// قالب الفواتير النقدية - يستخدم القالب الكلاسيكي
  static InvoiceTemplateEntity getCashTemplate() {
    return ClassicInvoiceTemplate.create().copyWith(
      id: 'default_cash',
      type: 'cash',
      showCustomerInfo: false,
      showNotes: false,
      footerText: 'فاتورة نقدية - تم الدفع',
      isDefault: true,
    );
  }
}
