import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/invoices/domain/entities/returned_item_entity.dart';
import '../utils/smart_number_formatter.dart';

/// خدمة إرسال رسائل الواتساب
// ignore: avoid_classes_with_only_static_members
class WhatsAppService {
  static const String _whatsappApiUrl = 'https://api.whatsapp.com/send';

  /// تنسيق المبلغ للعرض
  static String _formatAmount(double amount) {
    // إذا كان الرقم صحيحاً (بدون أرقام عشرية)
    if (amount == amount.toInt()) {
      return SmartNumberFormatter.format(amount);
    }
    // إذا كان هناك أرقام عشرية
    return SmartNumberFormatter.format(amount);
  }

  /// تنسيق رقم للعرض (بدون أصفار زائدة)
  static String _formatNumber(double value) {
    // إذا كان الرقم صحيحاً (بدون أرقام عشرية)
    if (value == value.toInt()) {
      return SmartNumberFormatter.format(value);
    }
    // إذا كان هناك أرقام عشرية
    return SmartNumberFormatter.format(value);
  }

  /// إرسال رسالة عبر الواتساب باستخدام URL Scheme
  static Future<bool> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // تنظيف رقم الهاتف
      final cleanPhone = _cleanPhoneNumber(phoneNumber);

      // إنشاء رابط الواتساب
      final encodedMessage = Uri.encodeComponent(message);

      // استخدام API URL مباشرة (أكثر استقراراً)
      final whatsappUrl =
          '$_whatsappApiUrl?phone=$cleanPhone&text=$encodedMessage';
      final uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }

      return false;
    } on Exception catch (_) {
      return false;
    }
  }

  /// إرسال ملف مع رسالة عبر WhatsApp
  static Future<bool> sendFileWithMessage({
    required File file,
    required String message,
    String? phoneNumber,
  }) async {
    try {
      final xFile = XFile(file.path);

      // استخدام share_plus لإرسال الملف مع النص
      // share_plus سيدمج النص مع الملف في رسالة واحدة
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      final result = await Share.shareXFiles(
        [xFile],
        text: message,
        subject: 'فاتورة',
      );

      // إذا كان الإرسال ناجحاً
      if (result.status == ShareResultStatus.success) {
        return true;
      }

      return false;
    } on Exception catch (_) {
      return false;
    }
  }

  /// إنشاء رسالة فاتورة جديدة
  static String createInvoiceMessage({
    required String customerName,
    required String invoiceNumber,
    required double totalAmount,
    required String organizationName,
  }) {
    final formattedAmount = _formatAmount(totalAmount);
    return '''
السلام عليكم $customerName

تم إنشاء فاتورة جديدة لكم:

رقم الفاتورة: $invoiceNumber
المبلغ الإجمالي: $formattedAmount دينار

$organizationName
''';
  }

  /// تنظيف رقم الهاتف
  static String _cleanPhoneNumber(String phoneNumber) {
    // إزالة جميع الرموز غير الرقمية
    var cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // إضافة رمز الدولة إذا لم يكن موجوداً
    if (!cleaned.startsWith('+')) {
      // إضافة رمز دولة افتراضي (يمكن تخصيصه حسب البلد)
      if (cleaned.startsWith('0')) {
        cleaned = cleaned.substring(1);
      }
      // رمز العراق كمثال - يمكن تغييره
      cleaned = '964$cleaned';
    } else {
      cleaned = cleaned.substring(1);
    }

    return cleaned;
  }

  /// التحقق من وجود الواتساب على الجهاز
  static Future<bool> isWhatsAppInstalled() async {
    try {
      if (Platform.isAndroid) {
        final uri = Uri.parse('whatsapp://send');
        return await canLaunchUrl(uri);
      } else if (Platform.isIOS) {
        final uri = Uri.parse('whatsapp://send');
        return await canLaunchUrl(uri);
      }
      return false;
    } on Exception catch (_) {
      return false;
    }
  }

  /// فتح محادثة واتساب مع رقم معين
  static Future<bool> openChat(String phoneNumber) async {
    try {
      final cleanPhone = _cleanPhoneNumber(phoneNumber);

      // محاولة فتح الواتساب باستخدام URL scheme المباشر أولاً
      final whatsappScheme = 'whatsapp://send?phone=$cleanPhone';
      final schemeUri = Uri.parse(whatsappScheme);

      if (await canLaunchUrl(schemeUri)) {
        final launched = await launchUrl(
          schemeUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }

      // إذا فشل، استخدم API URL
      final whatsappUrl = '$_whatsappApiUrl?phone=$cleanPhone';
      final uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      return false;
    } on Exception catch (_) {
      return false;
    }
  }

  /// إنشاء رسالة فاتورة مفصلة مع الحساب
  static String createDetailedInvoiceMessage({
    required String customerName,
    required String invoiceNumber,
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
    required double balanceBeforeInvoice,
    required double balanceAfterInvoice,
    required String invoiceType,
    required DateTime invoiceDate,
    required String organizationName,
    List<String>? items,
    double discountAmount = 0.0,
  }) {
    final typeLabel = _getInvoiceTypeLabel(invoiceType);
    final itemsList = items != null && items.isNotEmpty
        ? '\n────────────────────\n          الأصناف\n────────────────────\n${items.map((item) => '• $item').join('\n')}'
        : '';

    // حساب التغير في الحساب
    final balanceChange = balanceAfterInvoice - balanceBeforeInvoice;
    final changeSymbol = balanceChange > 0 ? '+' : '';
    final changeText = balanceChange > 0
        ? 'زيادة'
        : balanceChange < 0
        ? 'نقصان'
        : 'لم يتغير';

    // حساب المبلغ الأصلي قبل الخصم
    final originalAmount = totalAmount - discountAmount;

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(invoiceDate)}
────────────────────
          تفاصيل $typeLabel
────────────────────
رقم $typeLabel: $invoiceNumber
التاريخ: ${_formatDate(invoiceDate)}
${discountAmount > 0 ? 'المبلغ الأصلي: ${_formatNumber(originalAmount)} دينار\nالخصم: ${_formatNumber(discountAmount)} دينار\n' : ''}المبلغ الإجمالي: ${_formatNumber(totalAmount)} دينار
المبلغ المدفوع: ${_formatNumber(paidAmount.abs())} دينار
المبلغ المتبقي: ${_formatNumber(remainingAmount > 0 ? remainingAmount : 0)} دينار$itemsList
────────────────────
          كشف الحساب
────────────────────
${balanceBeforeInvoice > 0
        ? 'الحساب السابق (عليك):'
        : balanceBeforeInvoice < 0
        ? 'الحساب السابق (لك):'
        : 'الحساب السابق:'} ${_formatNumber(balanceBeforeInvoice.abs())} دينار
${balanceAfterInvoice > 0
        ? 'الحساب الحالي (عليك):'
        : balanceAfterInvoice < 0
        ? 'الحساب الحالي (لك):'
        : 'الحساب الحالي:'} ${_formatNumber(balanceAfterInvoice.abs())} دينار
التغير: $changeSymbol${_formatNumber(balanceChange.abs())} دينار ($changeText)
════════════════════
''';
  }

  /// إنشاء رسالة اشتراك جديد
  static String createSubscriptionMessage({
    required String customerName,
    required String subscriptionName,
    required String subscriptionType,
    required double price,
    required DateTime startDate,
    required DateTime endDate,
    required String duration,
    required String organizationName,
    String? invoiceNumber,
    double? balanceBeforeInvoice,
    double? balanceAfterInvoice,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    List<Map<String, dynamic>>? taxes, // قائمة الضرائب التفصيلية
    List<String>? features, // ميزات الاشتراك
    int? customDays, // عدد الأيام المخصصة
  }) {
    final durationLabel = _getDurationLabel(duration, customDays: customDays);
    final invoiceInfo = invoiceNumber != null
        ? '\nرقم الفاتورة: $invoiceNumber'
        : '';

    // حساب السعر الأصلي (قبل الضريبة والخصم)
    final originalPrice = price - taxAmount + discountAmount;

    // معلومات الخصم والضرائب
    var taxesInfo = '';
    if (taxAmount > 0 || (taxes != null && taxes.isNotEmpty)) {
      taxesInfo = '\nالضريبة: ${_formatNumber(taxAmount)} دينار';
    }

    var discountInfo = '';
    if (discountAmount > 0) {
      discountInfo = '\nالخصم: -${_formatNumber(discountAmount)} دينار';
    }

    // معلومات الميزات
    String featuresInfo = '';
    if (features != null && features.isNotEmpty) {
      featuresInfo =
          '\n────────────────────\n          الميزات\n────────────────────\n${features.map((f) => '• $f').join('\n')}';
    }

    // معلومات الحساب (اختيارية)
    var balanceInfo = '';
    if (balanceBeforeInvoice != null && balanceAfterInvoice != null) {
      final balanceChange = balanceAfterInvoice - balanceBeforeInvoice;
      final changeSymbol = balanceChange > 0 ? '+' : '';
      final changeText = balanceChange > 0
          ? 'زيادة'
          : balanceChange < 0
          ? 'نقصان'
          : 'لم يتغير';

      final previousBalanceLabel = balanceBeforeInvoice > 0
          ? 'الحساب السابق (عليك):'
          : balanceBeforeInvoice < 0
          ? 'الحساب السابق (لك):'
          : 'الحساب السابق:';

      final currentBalanceLabel = balanceAfterInvoice > 0
          ? 'الحساب الحالي (عليك):'
          : balanceAfterInvoice < 0
          ? 'الحساب الحالي (لك):'
          : 'الحساب الحالي:';

      balanceInfo =
          '''
────────────────────
          كشف الحساب
────────────────────
$previousBalanceLabel ${_formatNumber(balanceBeforeInvoice.abs())} دينار
$currentBalanceLabel ${_formatNumber(balanceAfterInvoice.abs())} دينار
التغير: $changeSymbol${_formatNumber(balanceChange.abs())} دينار ($changeText)
''';
    }

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
        تفاصيل الاشتراك
────────────────────
الاشتراك: $subscriptionName
النوع: $subscriptionType
المدة: $durationLabel
تاريخ البداية: ${_formatDateTime(startDate)}
تاريخ النهاية: ${_formatDateTime(endDate)}
${discountAmount > 0 || taxAmount > 0 ? 'السعر الأساسي: ${_formatNumber(originalPrice)} دينار' : 'السعر: ${_formatNumber(price)} دينار'}$taxesInfo$discountInfo
────────────────────
السعر النهائي: ${_formatNumber(price)} دينار
$invoiceInfo$featuresInfo$balanceInfo════════════════════
''';
  }

  /// إنشاء رسالة اشتراك من فاتورة
  static String createSubscriptionFromInvoiceMessage({
    required String customerName,
    required String subscriptionName,
    required String subscriptionType,
    required String duration,
    required DateTime startDate,
    required DateTime endDate,
    required double basePrice,
    required double finalPrice,
    required String invoiceNumber,
    required String organizationName,
    double? balanceBeforeInvoice,
    double? balanceAfterInvoice,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    List<Map<String, dynamic>>? taxes, // قائمة الضرائب التفصيلية
    List<String>? features, // ميزات الاشتراك
    bool isUpdated = false,
    DateTime? updatedAt,
  }) {
    // معلومات الضرائب (بدون عنوان)
    String taxesInfo = '';
    if (taxAmount > 0 || (taxes != null && taxes.isNotEmpty)) {
      taxesInfo = '\nالضريبة: ${_formatNumber(taxAmount)} دينار';
    }

    var discountInfo = '';
    if (discountAmount > 0) {
      discountInfo = '\nالخصم: -${_formatNumber(discountAmount)} دينار';
    }

    // معلومات الميزات
    String featuresInfo = '';
    if (features != null && features.isNotEmpty) {
      featuresInfo =
          '\n────────────────────\n          الميزات\n────────────────────\n${features.map((f) => '• $f').join('\n')}';
    }

    // معلومات الحساب (اختيارية)
    var balanceInfo = '';
    if (balanceBeforeInvoice != null && balanceAfterInvoice != null) {
      final balanceChange = balanceAfterInvoice - balanceBeforeInvoice;
      final changeSymbol = balanceChange > 0 ? '+' : '';
      final changeText = balanceChange > 0
          ? 'زيادة'
          : balanceChange < 0
          ? 'نقصان'
          : 'لم يتغير';

      final previousBalanceLabel = balanceBeforeInvoice > 0
          ? 'الحساب السابق (عليك):'
          : balanceBeforeInvoice < 0
          ? 'الحساب السابق (لك):'
          : 'الحساب السابق:';

      final currentBalanceLabel = balanceAfterInvoice > 0
          ? 'الحساب الحالي (عليك):'
          : balanceAfterInvoice < 0
          ? 'الحساب الحالي (لك):'
          : 'الحساب الحالي:';

      balanceInfo =
          '''
────────────────────
          كشف الحساب
────────────────────
$previousBalanceLabel ${_formatNumber(balanceBeforeInvoice.abs())} دينار
$currentBalanceLabel ${_formatNumber(balanceAfterInvoice.abs())} دينار
التغير: $changeSymbol${_formatNumber(balanceChange.abs())} دينار ($changeText)
''';
    }

    // نص تنبيه التعديل
    var updateAlert = '';
    String? updateDate;
    if (isUpdated && updatedAt != null) {
      updateDate = _formatDateTime(updatedAt);
      updateAlert = '''

📢 إشعار: فاتورة معدلة 📢

هذه الفاتورة نسخة معدلة ومحدثة
وقد تم إلغاء الفاتورة السابقة
الصادرة بنفس الرقم

''';
    }

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
$updateAlert────────────────────
        تفاصيل الاشتراك
────────────────────
الاشتراك: $subscriptionName
النوع: $subscriptionType
المدة: $duration
تاريخ البداية: ${_formatDateTime(startDate)}
تاريخ النهاية: ${_formatDateTime(endDate)}
${discountAmount > 0 || taxAmount > 0 ? 'السعر الأساسي: ${_formatNumber(basePrice)} دينار' : 'السعر: ${_formatNumber(finalPrice)} دينار'}$taxesInfo$discountInfo
────────────────────
السعر النهائي: ${_formatNumber(finalPrice)} دينار
رقم الفاتورة: $invoiceNumber${isUpdated ? ' (معدلة)' : ''}${isUpdated ? '\nتاريخ التعديل: $updateDate' : ''}
$featuresInfo
$balanceInfo════════════════════
''';
  }

  /// إنشاء رسالة تذكير بقرب انتهاء الاشتراك
  static String createSubscriptionExpirationReminderMessage({
    required String customerName,
    required String subscriptionName,
    required DateTime startDate,
    required DateTime endDate,
    required int daysRemaining,
    required double renewalPrice,
    required String invoiceNumber,
    required String organizationName,
    double? currentBalance,
    List<String>? features,
  }) {
    // معلومات الحساب
    String balanceInfo = '';
    if (currentBalance != null) {
      final balanceLabel = currentBalance > 0
          ? 'الحساب الحالي (عليك):'
          : currentBalance < 0
          ? 'الحساب الحالي (لك):'
          : 'الحساب الحالي:';

      balanceInfo =
          '''
────────────────────
          كشف الحساب
────────────────────
$balanceLabel ${_formatNumber(currentBalance.abs())} دينار
''';
    }

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
        تنبيه انتهاء الاشتراك
────────────────────
الاشتراك: $subscriptionName
تاريخ البداية: ${_formatDateTime(startDate)}
تاريخ النهاية: ${_formatDateTime(endDate)}
⚠️ متبقي $daysRemaining أيام على الانتهاء
سعر التجديد: ${_formatNumber(renewalPrice)} دينار
$balanceInfo════════════════════
''';
  }

  /// إنشاء رسالة تجديد اشتراك
  static String createSubscriptionRenewalMessage({
    required String customerName,
    required String subscriptionName,
    required String subscriptionType,
    required DateTime startDate,
    required DateTime newEndDate,
    required double price,
    required String organizationName,
    String? invoiceNumber, // رقم الفاتورة
    double? balanceBeforeInvoice,
    double? balanceAfterInvoice,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    List<Map<String, dynamic>>? taxes, // قائمة الضرائب التفصيلية
    List<String>? features, // ميزات الاشتراك
  }) {
    // حساب السعر الأصلي (قبل الضريبة والخصم)
    final originalPrice = price - taxAmount + discountAmount;

    // معلومات الضرائب (بدون عنوان)
    String taxesInfo = '';
    if (taxAmount > 0 || (taxes != null && taxes.isNotEmpty)) {
      taxesInfo = '\nالضريبة: ${_formatNumber(taxAmount)} دينار';
    }

    var discountInfo = '';
    if (discountAmount > 0) {
      discountInfo = '\nالخصم: -${_formatNumber(discountAmount)} دينار';
    }

    // معلومات الميزات
    String featuresInfo = '';
    if (features != null && features.isNotEmpty) {
      featuresInfo =
          '\n────────────────────\n          الميزات\n────────────────────\n${features.map((f) => '• $f').join('\n')}';
    }

    // معلومات الحساب (اختيارية)
    var balanceInfo = '';
    if (balanceBeforeInvoice != null && balanceAfterInvoice != null) {
      final balanceChange = balanceAfterInvoice - balanceBeforeInvoice;
      final changeSymbol = balanceChange > 0 ? '+' : '';
      final changeText = balanceChange > 0
          ? 'زيادة'
          : balanceChange < 0
          ? 'نقصان'
          : 'لم يتغير';

      final previousBalanceLabel = balanceBeforeInvoice > 0
          ? 'الحساب السابق (عليك):'
          : balanceBeforeInvoice < 0
          ? 'الحساب السابق (لك):'
          : 'الحساب السابق:';

      final currentBalanceLabel = balanceAfterInvoice > 0
          ? 'الحساب الحالي (عليك):'
          : balanceAfterInvoice < 0
          ? 'الحساب الحالي (لك):'
          : 'الحساب الحالي:';

      balanceInfo =
          '''
────────────────────
          كشف الحساب
────────────────────
$previousBalanceLabel ${_formatNumber(balanceBeforeInvoice.abs())} دينار
$currentBalanceLabel ${_formatNumber(balanceAfterInvoice.abs())} دينار
التغير: $changeSymbol${_formatNumber(balanceChange.abs())} دينار ($changeText)
''';
    }

    // معلومات الفاتورة
    String invoiceInfo = '';
    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      invoiceInfo = '\nرقم الفاتورة: $invoiceNumber';
    }

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
        تجديد الاشتراك
────────────────────
الاشتراك: $subscriptionName
النوع: $subscriptionType
تاريخ البداية: ${_formatDateTime(startDate)}
تاريخ النهاية: ${_formatDateTime(newEndDate)}
${discountAmount > 0 || taxAmount > 0 ? 'السعر الأساسي: ${_formatNumber(originalPrice)} دينار' : 'السعر: ${_formatNumber(price)} دينار'}$taxesInfo$discountInfo
────────────────────
السعر النهائي: ${_formatNumber(price)} دينار
$invoiceInfo$featuresInfo$balanceInfo════════════════════
''';
  }

  /// إنشاء رسالة تحديث دفعة
  static String createPaymentUpdateMessage({
    required String customerName,
    required String invoiceNumber,
    required double paidAmount,
    required double remainingAmount,
    required double currentBalance,
    required String organizationName,
    double? balanceBeforeInvoice,
    double? balanceAfterInvoice,
  }) {
    final status = remainingAmount == 0 ? 'تم الدفع بالكامل' : 'دفع جزئي';

    // معلومات الحساب (اختيارية)
    var balanceInfo = '';
    if (balanceBeforeInvoice != null && balanceAfterInvoice != null) {
      final balanceChange = balanceAfterInvoice - balanceBeforeInvoice;

      // إذا كان التغير صفر (الفاتورة دُفعت بالكامل)
      if (balanceChange == 0) {
        final currentBalanceLabel = currentBalance > 0
            ? 'الحساب الحالي (عليك):'
            : currentBalance < 0
            ? 'الحساب الحالي (لك):'
            : 'الحساب الحالي:';

        balanceInfo =
            '''
────────────────────
          كشف الحساب
────────────────────
$currentBalanceLabel ${_formatNumber(currentBalance.abs())} دينار
(لم يتغير - الفاتورة دُفعت منفصلة)
''';
      } else {
        final changeSymbol = balanceChange > 0 ? '+' : '';
        final changeText = balanceChange > 0
            ? 'زيادة'
            : balanceChange < 0
            ? 'نقصان'
            : 'لم يتغير';

        final previousBalanceLabel = balanceBeforeInvoice > 0
            ? 'الحساب السابق (عليك):'
            : balanceBeforeInvoice < 0
            ? 'الحساب السابق (لك):'
            : 'الحساب السابق:';

        final currentBalanceLabel = balanceAfterInvoice > 0
            ? 'الحساب الحالي (عليك):'
            : balanceAfterInvoice < 0
            ? 'الحساب الحالي (لك):'
            : 'الحساب الحالي:';

        balanceInfo =
            '''
────────────────────
          كشف الحساب
────────────────────
$previousBalanceLabel ${_formatNumber(balanceBeforeInvoice.abs())} دينار
$currentBalanceLabel ${_formatNumber(balanceAfterInvoice.abs())} دينار
التغير: $changeSymbol${_formatNumber(balanceChange.abs())} دينار ($changeText)
''';
      }
    } else {
      // إذا لم تتوفر معلومات الحساب المفصل، نعرض الحساب الحالي فقط
      final currentBalanceLabel = currentBalance > 0
          ? 'الحساب الحالي (عليك):'
          : currentBalance < 0
          ? 'الحساب الحالي (لك):'
          : 'الحساب الحالي:';

      balanceInfo =
          '''
────────────────────
          كشف الحساب
────────────────────
$currentBalanceLabel ${_formatNumber(currentBalance.abs())} دينار
''';
    }

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
          تحديث الدفع
────────────────────
حالة الدفع: $status
رقم الفاتورة: $invoiceNumber
المبلغ المدفوع: ${_formatNumber(paidAmount)} دينار
المبلغ المتبقي: ${_formatNumber(remainingAmount)} دينار
$balanceInfo
════════════════════
''';
  }

  /// إنشاء رسالة تذكير متقدمة
  static String createAdvancedReminderMessage({
    required String customerName,
    required double totalDebt,
    required int overdueInvoicesCount,
    required String organizationName,
    List<String>? overdueInvoices,
  }) {
    final invoicesList = overdueInvoices != null && overdueInvoices.isNotEmpty
        ? '\n────────────────────\n        الفواتير المستحقة\n────────────────────\n${overdueInvoices.map((inv) => '• $inv').join('\n')}'
        : '';

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
        تذكير بالمبالغ المستحقة
────────────────────
إجمالي المبلغ المستحق: ${_formatNumber(totalDebt)} دينار
عدد الفواتير المستحقة: $overdueInvoicesCount فواتير$invoicesList
────────────────────
          ملاحظة مهمة
────────────────────
نرجو منكم تسديد المبلغ في أقرب وقت ممكن لتجنب تراكم الديون
════════════════════
''';
  }

  /// إنشاء رسالة تذكير بالدين (بسيطة)
  static String createDebtReminderMessageSimple({
    required String customerName,
    required double debtAmount,
    required String organizationName,
  }) {
    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
          تذكير
────────────────────
المبلغ المستحق: ${_formatNumber(debtAmount)} دينار
────────────────────
نرجو منكم تسديد المبلغ في أقرب وقت ممكن
════════════════════
''';
  }

  /// إنشاء رسالة طلب صيانة جديد
  static String createMaintenanceRequestMessage({
    required String customerName,
    required String title,
    required String description,
    required String priority,
    required String equipmentName,
    required DateTime requestDate,
    required String organizationName,
    DateTime? scheduledDate,
    double? estimatedCost,
    double? balanceBeforeInvoice,
    double? balanceAfterInvoice,
  }) {
    final priorityLabel = _getPriorityLabel(priority);
    final scheduledInfo = scheduledDate != null
        ? '\nموعد الصيانة: ${_formatDate(scheduledDate)}'
        : '';
    final costInfo = estimatedCost != null && estimatedCost > 0
        ? '\nالتكلفة المتوقعة: ${_formatNumber(estimatedCost)} دينار'
        : '';

    // معلومات الحساب (اختيارية)
    var balanceInfo = '';
    if (balanceBeforeInvoice != null && balanceAfterInvoice != null) {
      final balanceChange = balanceAfterInvoice - balanceBeforeInvoice;
      final changeSymbol = balanceChange > 0 ? '+' : '';
      final changeText = balanceChange > 0
          ? 'زيادة'
          : balanceChange < 0
          ? 'نقصان'
          : 'لم يتغير';

      final previousBalanceLabel = balanceBeforeInvoice > 0
          ? 'الحساب السابق (عليك):'
          : balanceBeforeInvoice < 0
          ? 'الحساب السابق (لك):'
          : 'الحساب السابق:';

      final currentBalanceLabel = balanceAfterInvoice > 0
          ? 'الحساب الحالي (عليك):'
          : balanceAfterInvoice < 0
          ? 'الحساب الحالي (لك):'
          : 'الحساب الحالي:';

      balanceInfo =
          '''
────────────────────
          كشف الحساب
────────────────────
$previousBalanceLabel ${_formatNumber(balanceBeforeInvoice.abs())} دينار
$currentBalanceLabel ${_formatNumber(balanceAfterInvoice.abs())} دينار
التغير: $changeSymbol${_formatNumber(balanceChange.abs())} دينار ($changeText)
''';
    }

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
        طلب صيانة جديد
────────────────────
العنوان: $title
الوصف: $description
المعدة: $equipmentName
الأولوية: $priorityLabel
تاريخ الطلب: ${_formatDate(requestDate)}$scheduledInfo$costInfo$balanceInfo
════════════════════
''';
  }

  /// إنشاء رسالة طلب إيجار جديد
  static String createRentalRequestMessage({
    required String customerName,
    required String itemName,
    required String itemDescription,
    required double rentalPrice,
    required double deposit,
    required DateTime startDate,
    required DateTime endDate,
    required String paymentFrequency,
    required String organizationName,
    double? balanceBeforeInvoice,
    double? balanceAfterInvoice,
  }) {
    final frequencyLabel = _getPaymentFrequencyLabel(paymentFrequency);
    final duration = endDate.difference(startDate).inDays;

    // معلومات الحساب (اختيارية)
    var balanceInfo = '';
    if (balanceBeforeInvoice != null && balanceAfterInvoice != null) {
      final balanceChange = balanceAfterInvoice - balanceBeforeInvoice;
      final changeSymbol = balanceChange > 0 ? '+' : '';
      final changeText = balanceChange > 0
          ? 'زيادة'
          : balanceChange < 0
          ? 'نقصان'
          : 'لم يتغير';

      final previousBalanceLabel = balanceBeforeInvoice > 0
          ? 'الحساب السابق (عليك):'
          : balanceBeforeInvoice < 0
          ? 'الحساب السابق (لك):'
          : 'الحساب السابق:';

      final currentBalanceLabel = balanceAfterInvoice > 0
          ? 'الحساب الحالي (عليك):'
          : balanceAfterInvoice < 0
          ? 'الحساب الحالي (لك):'
          : 'الحساب الحالي:';

      balanceInfo =
          '''
────────────────────
          كشف الحساب
────────────────────
$previousBalanceLabel ${_formatNumber(balanceBeforeInvoice.abs())} دينار
$currentBalanceLabel ${_formatNumber(balanceAfterInvoice.abs())} دينار
التغير: $changeSymbol${_formatNumber(balanceChange.abs())} دينار ($changeText)
''';
    }

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
        عقد إيجار جديد
────────────────────
العقار: $itemName
الوصف: $itemDescription
سعر الإيجار: ${_formatNumber(rentalPrice)} دينار
مبلغ التأمين: ${_formatNumber(deposit)} دينار
تاريخ البداية: ${_formatDate(startDate)}
تاريخ النهاية: ${_formatDate(endDate)}
المدة: $duration يوم
دورية الدفع: $frequencyLabel$balanceInfo
════════════════════
''';
  }

  // دوال مساعدة إضافية
  static String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'low':
        return 'منخفضة';
      case 'medium':
        return 'متوسطة';
      case 'high':
        return 'عالية';
      case 'urgent':
        return 'عاجلة';
      default:
        return priority;
    }
  }

  static String _getPaymentFrequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      case 'quarterly':
        return 'ربع سنوي';
      case 'yearly':
        return 'سنوي';
      default:
        return frequency;
    }
  }

  // دوال مساعدة خاصة
  static String _getInvoiceTypeLabel(String type) {
    switch (type) {
      case 'sales':
        return 'فاتورة مبيعات';
      case 'purchase':
        return 'فاتورة مشتريات';
      case 'subscription':
        return 'فاتورة اشتراك';
      case 'maintenance':
        return 'فاتورة صيانة';
      case 'rental':
        return 'فاتورة إيجار';
      case 'cash':
        return 'فاتورة نقدية';
      default:
        return 'فاتورة';
    }
  }

  static String _getDurationLabel(String duration, {int? customDays}) {
    switch (duration) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      case 'quarterly':
        return 'ربع سنوي';
      case 'yearly':
        return 'سنوي';
      case 'custom':
        if (customDays != null && customDays > 0) {
          return '$customDays يوم';
        }
        return 'مخصص';
      default:
        return duration;
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// إنشاء رسالة فاتورة مرجع بيع
  static String createSalesReturnMessage({
    required String customerName,
    required String invoiceNumber,
    required List<ReturnedItemEntity> items,
    required double totalAmount,
    required String refundMethod,
    required double balanceBefore,
    required double balanceAfter,
    required String organizationName,
  }) {
    final itemsList = items
        .map(
          (item) =>
              '''
 • ${item.itemName}
   الكمية: ${item.returnedQuantity} قطع
   السعر: ${_formatNumber(item.unitPrice)} دينار
   تاريخ البيع: ${_formatDate(item.saleDate)}
   الإجمالي: ${_formatNumber(item.totalPrice)} دينار''',
        )
        .join('\n\n');

    final balanceChange = balanceAfter - balanceBefore;
    final changeSymbol = balanceChange > 0 ? '+' : '';
    final changeText = balanceChange > 0
        ? 'زيادة'
        : balanceChange < 0
        ? 'نقصان'
        : 'لم يتغير';

    final previousBalanceLabel = balanceBefore > 0
        ? 'الحساب السابق (عليك):'
        : balanceBefore < 0
        ? 'الحساب السابق (لك):'
        : 'الحساب السابق:';

    final currentBalanceLabel = balanceAfter > 0
        ? 'الحساب الحالي (عليك):'
        : balanceAfter < 0
        ? 'الحساب الحالي (لك):'
        : 'الحساب الحالي:';

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
        فاتورة مرجع بيع
────────────────────
رقم الفاتورة: $invoiceNumber
طريقة الاسترداد: ${refundMethod == 'credit' ? 'خصم من الحساب' : 'رد نقداً'}
────────────────────
          المواد المرتجعة
────────────────────
$itemsList
────────────────────
          كشف الحساب
────────────────────
المبلغ المسترد: ${_formatNumber(totalAmount)} دينار
$previousBalanceLabel ${_formatNumber(balanceBefore.abs())} دينار
$currentBalanceLabel ${_formatNumber(balanceAfter.abs())} دينار
التغير: $changeSymbol${_formatNumber(balanceChange.abs())} دينار ($changeText)
────────────────────
          ملاحظة
────────────────────
${refundMethod == 'credit' ? 'تم خصم المبلغ من حسابك' : 'سيتم رد المبلغ نقداً عند الزيارة القادمة'}
════════════════════
''';
  }

  /// إنشاء رسالة تصفير الحساب
  static String createAccountClearanceMessage({
    required String customerName,
    required double clearedAmount,
    required String organizationName,
    String? invoiceNumber,
  }) {
    final directionLabel = clearedAmount > 0 ? 'عليك' : 'لك';
    final operationLabel = clearedAmount > 0 ? 'تصفير الدين المستحق عليه' : 'تصفير المبلغ المستحق له';

    return '''
════════════════════
        $organizationName
════════════════════
السلام عليكم $customerName
تاريخ الإرسال: ${_formatDate(DateTime.now())}
────────────────────
        تصفير حساب
────────────────────
$operationLabel: ${_formatNumber(clearedAmount.abs())} دينار
${invoiceNumber != null ? 'رقم الإيصال: $invoiceNumber\n' : ''}────────────────────
          كشف الحساب
────────────────────
الحساب السابق ($directionLabel): ${_formatNumber(clearedAmount.abs())} دينار
الحساب الحالي: 0.00 دينار
التغير: ${clearedAmount > 0 ? '-' : '+'}${_formatNumber(clearedAmount.abs())} دينار (تصفير)
────────────────────
          ملاحظة
────────────────-----
تم إغلاق الحساب وتصفير جميع الفواتير السابقة
════════════════════
''';
  }
}
