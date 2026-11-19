import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/invoice_template_entity.dart';

class InvoiceTemplatePreviewPage extends StatefulWidget {
  const InvoiceTemplatePreviewPage({
    required this.template,
    this.allTemplates,
    super.key,
  });

  final InvoiceTemplateEntity template;
  final List<InvoiceTemplateEntity>? allTemplates;

  @override
  State<InvoiceTemplatePreviewPage> createState() =>
      _InvoiceTemplatePreviewPageState();

  // كاش ثابت على مستوى الكلاس - يُبنى مرة واحدة لكل قالب ويُحفظ في التخزين الدائم
  static const int _maxCachedPdfs = 20;
  static final Map<String, Uint8List> _staticCachedPdfs = {}; // كاش لكل قالب
  static final Map<String, bool> _isLoadingTemplates = {};
  static final Set<String> _loadedTemplateIds =
      {}; // القوالب المحملة من التخزين

  /// دالة عامة لتحميل المعاينة مسبقاً - تُستدعى مرة واحدة لكل قالب
  static Future<void> preloadTemplate(InvoiceTemplateEntity template) async {
    final templateId = template.id;

    // إذا كانت محملة في الذاكرة، لا حاجة لإعادة البناء
    if (_staticCachedPdfs.containsKey(templateId)) {
      return;
    }

    _isLoadingTemplates[templateId] = true;
    try {
      // محاولة التحميل من التخزين الدائم أولاً
      final storedPdf = await _loadFromStorage(templateId);
      if (storedPdf != null) {
        _staticCachedPdfs[templateId] = storedPdf;
        _loadedTemplateIds.add(templateId);
        return;
      }

      // إذا لم تكن موجودة في التخزين، نبنيها ونحفظها باستخدام pdf_service.dart
      final pdf = await _generateStaticPdfPreview(template);
      _staticCachedPdfs[templateId] = pdf;
      await _saveToStorage(templateId, pdf);
      _loadedTemplateIds.add(templateId);

      // 🔧 فرض الحد الأقصى على الكاش: إزالة الأقدم إذا تجاوز الحد
      if (_staticCachedPdfs.length > _maxCachedPdfs) {
        final firstKey = _staticCachedPdfs.keys.first;
        _staticCachedPdfs.remove(firstKey);
        _loadedTemplateIds.remove(firstKey);
      }
    } on Exception {
      // تجاهل الأخطاء
    } finally {
      _isLoadingTemplates[templateId] = false;
    }
  }

  /// تحميل من التخزين الدائم - خاص بكل قالب
  static Future<Uint8List?> _loadFromStorage(String templateId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/invoice_template_$templateId.pdf');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } on Exception {
      // تجاهل الأخطاء
    }
    return null;
  }

  /// حفظ في التخزين الدائم - خاص بكل قالب
  static Future<void> _saveToStorage(String templateId, Uint8List pdf) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/invoice_template_$templateId.pdf');
      await file.writeAsBytes(pdf);
    } on Exception {
      // تجاهل الأخطاء
    }
  }

  /// دالة لحذف الكاش المخزن لقالب معين - تُستخدم عند تغيير القالب
  static Future<void> clearCachedTemplate(String templateId) async {
    _staticCachedPdfs.remove(templateId);
    _loadedTemplateIds.remove(templateId);
    _isLoadingTemplates.remove(templateId);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/invoice_template_$templateId.pdf');
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception {
      // تجاهل الأخطاء
    }
  }

  /// دالة لحذف جميع القوالب المخزنة
  static Future<void> clearAllCachedTemplates() async {
    _staticCachedPdfs.clear();
    _loadedTemplateIds.clear();
    _isLoadingTemplates.clear();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .where(
            (f) =>
                f.path.contains('invoice_template_') && f.path.endsWith('.pdf'),
          )
          .toList();
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    } on Exception {
      // تجاهل الأخطاء
    }
  }

  /// توليد PDF للمعاينة باستخدام pdf_service.dart (مُوحَّد مع التوليد الفعلي)
  static Future<Uint8List> _generateStaticPdfPreview(
    InvoiceTemplateEntity template,
  ) async {
    final pdfService = PdfService();

    // إنشاء بيانات تجريبية للمعاينة
    final demoInvoice = InvoiceEntity(
      id: 'demo_001',
      invoiceNumber: 'INV-2024-001',
      customerName: 'عميل تجريبي',
      customerPhone: '+966500000000',
      customerId: 'customer_001',
      invoiceDate: DateTime.now(),
      type: 'sales',
      status: 'غير مدفوعة',
      totalAmount: 1500.00,
      paidAmount: 500.00,
      remainingAmount: 1000.00,
      organizationEmail: 'demo@company.com',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'system',
      items: [
        InvoiceItemEntity(
          productName: 'صنف تجريبي 1',
          quantity: 2,
          unit: 'قطعة',
          unitPrice: 500.00,
          totalPrice: 1000.00,
        ),
        InvoiceItemEntity(
          productName: 'صنف تجريبي 2',
          quantity: 1,
          unit: 'قطعة',
          unitPrice: 500.00,
          totalPrice: 500.00,
        ),
      ],
      notes: 'هذه فاتورة تجريبية لمعاينة القالب',
    );

    final orgInfo = await SettingsService.getOrganizationInfo();

    final pdfFile = await pdfService.generateInvoicePdf(
      invoice: demoInvoice,
      template: template,
      organizationName: orgInfo['name'] ?? 'اسم شركتك',
      organizationPhone: orgInfo['phone'] ?? '',
      organizationAddress: orgInfo['address'] ?? 'العنوان',
      logoBytes: null,
    );

    return pdfFile.readAsBytes();
  }
}

class _InvoiceTemplatePreviewPageState
    extends State<InvoiceTemplatePreviewPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  List<InvoiceTemplateEntity> get _templates =>
      widget.allTemplates ?? [widget.template];

  @override
  void initState() {
    super.initState();
    _currentIndex = _templates.indexWhere((t) => t.id == widget.template.id);
    if (_currentIndex == -1) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
    // تحميل جميع القوالب مسبقاً في الخلفية
    for (final template in _templates) {
      InvoiceTemplatePreviewPage.preloadTemplate(template);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Uint8List? get _cachedPdf {
    final template = _templates[_currentIndex];
    return InvoiceTemplatePreviewPage._staticCachedPdfs[template.id];
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // لا نستدعي onTemplateChanged هنا لأن المستخدم لم يحدد بعد
    // فقط نحمل القالب في الخلفية
    final newTemplate = _templates[index];
    InvoiceTemplatePreviewPage.preloadTemplate(newTemplate);
  }

  Future<void> _rebuildCurrentTemplate() async {
    final oldTemplate = _templates[_currentIndex];

    // إظهار جارٍ التحميل
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20.w,
                height: 20.h,
                child: LoadingWidget(size: 20),
              ),
              SizedBox(width: 12.w),
              Expanded(child: Text('جاري إعادة بناء "${oldTemplate.name}"...')),
            ],
          ),
          backgroundColor: AssyrianTheme.primaryGold,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // مسح الكاش القديم
    InvoiceTemplatePreviewPage._staticCachedPdfs.remove(oldTemplate.id);
    InvoiceTemplatePreviewPage._loadedTemplateIds.remove(oldTemplate.id);

    // حذف الملف من التخزين
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/invoice_template_${oldTemplate.id}.pdf');
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception {
      // تجاهل الأخطاء
    }

    // إعادة البناء بالبيانات المحدثة
    await InvoiceTemplatePreviewPage.preloadTemplate(oldTemplate);

    // تحديث الشاشة
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم تحديث وإعادة بناء "${oldTemplate.name}" بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _goToPreviousTemplate() {
    if (_currentIndex > 0) {
      _pageController.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextTemplate() {
    if (_currentIndex < _templates.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showTemplateInfoDialog() {
    final template = _templates[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('معلومات القالب'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('الاسم', template.name),
              _infoRow('النوع', _getInvoiceTypeName(template.type)),
              _infoRow('لون الهيدر', template.headerColor),
              _infoRow('اللون الثانوي', template.accentColor),
              _infoRow('إظهار الشعار', template.showLogo ? 'نعم' : 'لا'),
              _infoRow(
                'إظهار معلومات الشركة',
                template.showCompanyInfo ? 'نعم' : 'لا',
              ),
              _infoRow(
                'إظهار معلومات العميل',
                template.showCustomerInfo ? 'نعم' : 'لا',
              ),
              _infoRow(
                'إظهار جدول الأصناف',
                template.showItemsTable ? 'نعم' : 'لا',
              ),
              _infoRow('إظهار الملاحظات', template.showNotes ? 'نعم' : 'لا'),
              _infoRow('افتراضي', template.isDefault ? 'نعم' : 'لا'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _getInvoiceTypeName(String type) {
    switch (type) {
      case 'sales':
        return 'مبيعات';
      case 'purchase':
        return 'مشتريات';
      case 'subscription':
        return 'اشتراك';
      case 'maintenance':
        return 'صيانة';
      case 'rental':
        return 'إيجار';
      case 'cash':
        return 'نقدية';
      default:
        return 'عامة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleTemplates = _templates.length > 1;

    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: Column(
        children: [
          // الشريط العلوي
          Container(
            decoration: BoxDecoration(
              gradient: AssyrianTheme.backgroundGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 0.h),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: AssyrianTheme.primaryGold,
                        size: 22.sp,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'رجوع',
                      padding: EdgeInsets.all(0.w),
                      constraints: BoxConstraints(
                        minWidth: 28.w,
                        minHeight: 28.h,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'معاينة PDF - قياس A4',
                            style: AssyrianTheme.titleStyle.copyWith(
                              color: AssyrianTheme.primaryGold,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasMultipleTemplates)
                            Text(
                              '${_currentIndex + 1} / ${_templates.length}',
                              style: TextStyle(
                                color: AssyrianTheme.ivoryWhite.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 12.sp,
                              ),
                            )
                          else
                            Text(
                              'معاينة قبل الطباعة',
                              style: TextStyle(
                                color: AssyrianTheme.ivoryWhite.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 12.sp,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.info_outline,
                        color: AssyrianTheme.primaryGold,
                        size: 22.sp,
                      ),
                      onPressed: _showTemplateInfoDialog,
                      tooltip: 'معلومات',
                      padding: EdgeInsets.all(0.w),
                      constraints: BoxConstraints(
                        minWidth: 28.w,
                        minHeight: 28.h,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: AssyrianTheme.primaryGold,
                        size: 22.sp,
                      ),
                      onPressed: _rebuildCurrentTemplate,
                      tooltip: 'إعادة بناء القالب',
                      padding: EdgeInsets.all(0.w),
                      constraints: BoxConstraints(
                        minWidth: 28.w,
                        minHeight: 28.h,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // معاينة PDF مع PageView للتنقل
          Expanded(
            child: hasMultipleTemplates
                ? Stack(
                    children: [
                      // الخلفية البيضاء
                      Positioned.fill(child: Container(color: Colors.white)),
                      // PageView للعرض
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _templates.length,
                        onPageChanged: _onPageChanged,
                        physics: NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final template = _templates[index];
                          final cachedPdf = InvoiceTemplatePreviewPage
                              ._staticCachedPdfs[template.id];
                          // إذا لم يكن الكاش جاهزاً، اعرض شاشة بيضاء
                          if (cachedPdf == null) {
                            return Container(color: Colors.white);
                          }
                          return _buildPdfPreviewForTemplate(cachedPdf);
                        },
                      ),
                      // زر التنقل لليسار (التالي)
                      Positioned(
                        right: 0.w,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _buildNavButton(
                            icon: Icons.chevron_left,
                            size: 80,
                            onPressed: _currentIndex > 0
                                ? _goToPreviousTemplate
                                : null,
                          ),
                        ),
                      ),
                      // زر التنقل لليمين (السابق)
                      Positioned(
                        left: 0.w,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _buildNavButton(
                            icon: Icons.chevron_right,
                            size: 80,
                            onPressed: _currentIndex < _templates.length - 1
                                ? _goToNextTemplate
                                : null,
                          ),
                        ),
                      ),
                      // مؤشرات التنقل
                      Positioned(
                        bottom: 80.h,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _templates.length,
                            (index) => Container(
                              width: 10.w,
                              height: 10.h,
                              margin: EdgeInsets.symmetric(horizontal: 5.w),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentIndex == index
                                    ? AssyrianTheme.primaryGold
                                    : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // زر تحديد القالب العائم
                      _buildFloatingSelectButton(),
                    ],
                  )
                : _cachedPdf != null
                ? _buildPdfPreviewForTemplate(_cachedPdf!)
                : _buildLoadingState(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSelectButton() {
    return Positioned(
      bottom: 16.h,
      left: 16.w,
      right: 16.w,
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: () {
            final currentTemplate = _templates[_currentIndex];
            Navigator.pop(context, currentTemplate.id);
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AssyrianTheme.primaryGold,
                  AssyrianTheme.primaryGold.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 24.sp),
                SizedBox(width: 12.w),
                Text(
                  'تحديد والعودة',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 80,
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: onPressed != null ? Colors.white : Colors.grey,
            size: size * 0.7,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfPreviewForTemplate(Uint8List pdf) {
    // PdfPreview معطل - استخدام Container كبديل
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 80.sp, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'معاينة ملف PDF غير متاحة',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'تم إنشاء ملف PDF وحفظه في وحدة التخزين',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _cachedPdf == null
              ? Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red[700],
                    size: 40.sp,
                  ),
                )
              : LoadingWidget(size: 20),
          SizedBox(height: 24.h),
          Text(
            _cachedPdf == null
                ? 'حدث خطأ في التحميل'
                : 'جاري تحضير المعاينة...',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_cachedPdf == null) ...[
            SizedBox(height: 8.h),
            Text(
              'يرجى المحاولة مرة أخرى',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () {
                // إعادة محاولة التحميل
                InvoiceTemplatePreviewPage.preloadTemplate(
                  _templates[_currentIndex],
                );
              },
              icon: Icon(Icons.refresh, size: 20.sp),
              label: Text(
                'إعادة المحاولة',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 4,
              ),
            ),
          ] else ...[
            SizedBox(height: 8.h),
            Text(
              'يرجى الانتظار...',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }
}
