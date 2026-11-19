import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/invoice_numbering_service.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_group_entity.dart';
import '../../domain/entities/customer_groups_page.dart';
import '../../domain/entities/customer_log_entity.dart';
import '../../domain/entities/customer_stats_entity.dart';
import '../../domain/entities/customers_page.dart';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_group_model.dart';
import '../models/customer_log_model.dart';
import '../models/customer_model.dart';

// ════════════════════════════════════════════════════════════════════
// خريطة العمليات الذرية في قسم العملاء — للمبرمجين المستقبليين
// ────────────────────────────────────────────────────────────────────
// ✅ ذرية بالكامل (كل القراءات قبل كل الكتابات داخل runTransaction واحد):
//    • addCustomer : إنشاء عميل + فهرسي البريد/الهاتف + عضوية المجموعة
//      (لو فُصلت: عميل بلا فهرس أو عضو بلا تسجيل في مجموعته)
//    • addCustomerWithOpeningBalance : عميل + فاتورة افتتاحية + totalDebt
//      + invoiceIds (لو فُصلت: دين بلا فاتورة أو فاتورة بلا دين)
//    • updateCustomer : تحديث عميل + نقل عضوية مجموعة + فهارس البريد/الهاتف
//      (لو فُصلت: عميل مرتبط بمجموعة دون تسجيل أو العكس)
//    • addCustomerLog : إنشاء سجل + arrayUnion لـ logIds
//      (لو فُصلت: سجل يتيم لا يظهر في قائمة سجلات العميل)
//    • deleteCustomerLog : حذف سجل + arrayRemove لـ logIds
//      (لو فُصلت: مرجع معلق في logIds يشير إلى سجل محذوف)
//    • createCustomerGroup : مجموعة + مستند الاسم
//      (لو فُصلت: مجموعتان بنفس الاسم)
//    • updateCustomerGroup : تحديث مجموعة + نقل ملكية مستند الاسم
//    • clearCustomerLogs : حذف السجلات + تحديث logIds ذرياً لكل عميل
//      داخل runTransaction واحد (تُقرأ logIds من داخل المعاملة — لا
//      تحديث مفقود ولا مراجع معلقة لكل عميل) — المعاملات المتعددة
//      تبقى لأن حد المعاملة 500 عملية كتابة، والتعطل بينها يترك
//      كل عميل إما نظيفاً كاملاً أو لم يُمس
//
// ✅ ذرية بالكامل بعد الترحيل (2026-10-11):
//    • deleteCustomer : تُقرأ invoiceIds/logIds من داخل
//      الـ transaction — وللبيانات القديمة بلا
//      القوائم يُرحَّلُها أولاً
//      (_backfillLegacyCustomerTrackingFields: تُخزَّن
//      المعرفات في المستند كاملاً بدمج union داخل
//      معاملة) فتُقرأ من داخل معاملة الحذف وتُدمج
//      مع ما استُعلم عنه — لا نافذة سباق تُذكر
//    • deleteCustomerGroup : نفس النمط لحقل
//      customerIds (_backfillLegacyCustomerGroupTrackingFields)
//    ⚠️ نافذة متبقية ضئيلة لا تُغلق (قيد Firestore
//    SDK — لا يدعم استعلامات داخل runTransaction):
//    مرجع يُضاف أثناء رحلة (استعلام الترحيل ←
//    معاملته) ولا يُنشئ مساره الحقل لمستند بلاه
//    (addCustomerLog/addCustomer يحفظان الحقل إن
//    وُجد) — مصيره مرجع يتيم واحد بدلاً من نافذة
//    كاملة، وهو أفضل ما يمكن تحقيقه دون تغيير
//    الـ SDK. الترحيل أفضل-جهد: فشله لا يُفشل الحذف.
//    ⚠️ اقرأ الملاحظات التفصيلية داخل كل دالة قبل أي تعديل عليها.
//
//    🔍 سجل التحقق اليدوي من الذرية — للمبرمجين المستقبليين
//    (تحقق يدوي سطراً بسطر متكرر: 6 مرات
//    2026-10-08 + 3 مرات 2026-10-09 + 10 مرات
//    2026-10-11 + 6 مرات 2026-10-12 (الثاني
//    عشر والثالث عشر والرابع عشر والخامس
//    عشر والسادس عشر والسابع عشر — الأخير
//    اليوم)، مدمجة هنا لتجنب الإطالة —
//    بدون تعديل في المنطق إلا الإصلاحات
//    الموثقة أدناه).
//    القاعدة المفحوصة في كل تحقق هي القاعدة 1
//    أدناه (كل transaction.get() قبل كل
//    set/update/delete في نفس runTransaction —
//    all-or-nothing). ✅ النتيجة في كل تحقق
//    (السابع عشر 2026-10-12 أكدها مجدداً):
//    العمليات الاثنتا عشرة (العشر في الخريطة
//    أعلاه + الترحيلتين) ذرية فعلاً كما
//    وُثِّق — لا يوجد أي قراءة بعد أي كتابة
//    في أي معاملة، ولا استعلام داخل أي
//    معاملة، والحقول التراكمية
//    (totalDebt/invoiceIds/logIds/customerIds)
//    لا تُصان إلا داخل معاملة أو عبر
//    arrayUnion/arrayRemove، وما يجب أن يكون
//    ذرياً (وحدات متعددة المستندات يفشل
//    بعضها دون بعض — عميل بلا فهرس، دين بلا
//    فاتورة، عضو بلا تسجيل، سجل يتيم، مرجع
//    معلق، اسمان مكرران) ذري فعلاً.
//    ✅ تحقق السابع عشر (2026-10-12) بدقة
//    فائقة — أدلة مُفتَّشة مباشرة (لا
//    تقرير سابق): الفهرس المركب (targetId,
//    targetType) موجود فعلاً في
//    firestore.indexes.json، ولا كتابات خارج
//    طبقة المستودع في قسم العملاء
//    (customer_details_page تقرأ .get() فقط)،
//    وحراسات containsKey('invoiceIds') الستة
//    موجودة فعلاً (5 في invoice_repository_impl
//    + 1 في subscription_repository_impl).
//    ⚠️ نتيجة التحقق: لا تحسين أداء آمن
//    متبقٍّ يُجرى اليوم — orderBy('createdAt')
//    في getCustomers مرفوض لأن
//    DateParser.parse(null) يُرجع
//    DateTime.now() فمستندات قديمة بلا
//    createdAt تُرتَّب أخيراً في Firestore
//    لكن الأولى في الفرز المحلي — تغيير
//    الترتيب يُغيّر السلوك — السبب موثق
//    عند getCustomers نفسها.
//    ✅ أدلة التحقق المتقاطع (سليمة في كل
//    تحقق، أُعيد تأكيدها اليوم): (1) الكتابة
//    المزدوجة لمستند العميل في
//    addCustomerWithOpeningBalance (set كامل
//    ثم set بدمج arrayUnion) سلوك صحيح في
//    Firestore — العمليات تُطبَّق بالترتيب داخل
//    المعاملة، والنمط نفسه في
//    invoice_repository_impl.addInvoice، و
//    cloud_firestore 6.10.0 لا يرفض الكتابة
//    المتكررة لنفس المستند. (2) الفهرس المركب
//    (targetId, targetType) على مجموعة logs
//    موجود فعلاً في firestore.indexes.json
//    (collectionGroup: logs). (3)
//    invoice_repository_impl يصينع totalDebt
//    وinvoiceIds داخل معاملات الفواتير
//    (addInvoice/updateInvoice/deleteInvoice/
//    clearCustomerAccount — و
//    archiveCustomerInvoices و
//    clearCustomerAccount لهما توثيق ذرية
//    خاص بهما هناك) ويلتزم القاعدة الذهبية
//    لحقول التتبع (حراسات containsKey في
//    مواضع invoiceIds الستة: 5 في
//    invoice_repository_impl + 1 في
//    subscription_repository_impl
//    _createInvoiceInTransaction). (4)
//    customer_bloc يكتب سجل التدقيق عبر
//    unawaited كمعاملة منفصلة بعد العملية
//    الأساسية (مقصود بالتصميم — أفضل-جهد
//    ولا يُبطِل ذرية بيانات العملاء). (5)
//    customer_validator فحوصاته المسبقة
//    للواجهة فقط والفحص الذاتي النهائي داخل
//    runTransaction. (6) لا توجد كتابات خارج
//    طبقة المستودع في قسم العملاء
//    (customer_details_page تستخدم
//    FirebaseFirestore للقراءة فقط — get —
//    وصفحتا إنشاء/تعديل العميل لا تكتبان
//    مباشرة وأحداث BLoC فقط).
//    🔧 الإصلاحات التي طُبِّقت يدوياً من هذه
//    التحققات (قاعدة القراءات قبل الكتابات
//    لم تتغير في أي منها؛ السبب التفصيلي
//    لكل إصلاح موثق داخل تعليق دالته ولا
//    يُعاد هنا لتجنب الإطالة):
//    • 2026-10-08: deleteCustomer و
//      deleteCustomerGroup تقرآن المراجع داخل
//      المعاملة ويُحدَّث الموجود فقط (معرف
//      محذوف مسبقاً لم يعد يُفشل الحذف) +
//      تطبيع مسار الفواتير في
//      addCustomerWithOpeningBalance (فاتورة
//      الرصيد الافتتاحي لبريد يختلف بعد
//      التطبيع لم تعد تُكتب في مسار يتيم) +
//      إزالة متغيرين ميتين.
//    • 2026-10-09: فحص وجود المجموعة داخل
//      المعاملة في addCustomer و
//      addCustomerWithOpeningBalance (نفس نمط
//      updateCustomer — فشل الإنشاء عند حذف
//      المجموعة في نافذة سباق بدلاً من ربط
//      العميل بمرجع معلق: عقد العضوية
//      الذرية) + تهيئة invoiceIds/logIds
//      فارغة في addCustomer (نفس نمط
//      addCustomerWithOpeningBalance — ما يجعل
//      deleteCustomer ذرياً بالكامل للعملاء
//      الجدد).
//    • 2026-10-11: إصلاح اتساق البيانات
//      القديمة (فئة خلل واحدة: كتابة قائمة
//      تتبع فارغة فوق مستند قديم بلاها —
//      تُفقد كشف التوافق في
//      deleteCustomer/deleteCustomerGroup لأن
//      containsKey صار صحيحاً بينما القائمة
//      فارغة، فتجاوز الاستعلام الخارجي الذي
//      يجد المراجع الحقيقية فبقيت مراجع
//      يتيمة تشير لعميل/مجموعة محذوفَين) —
//      حراسات شرطية: (1) updateCustomer يحافظ
//      على غياب invoiceIds/logIds عند العميل
//      القديم (toJson يكتبهما دائماً و
//      fromJson تُرجعهما فارغين عند غيابهما).
//      (2) updateCustomer و deleteCustomer و
//      deleteCustomerLog و clearCustomerLogs
//      يُنفّذون arrayRemove/كتابة logIds أو
//      customerIds فقط إذا كان الحقل موجوداً
//      أصلاً (arrayRemove على حقل غائب يُنشئه
//      فارغاً — نفس الخلل). (3) addCustomerLog
//      و addCustomer و addCustomerWithOpeningBalance
//      و updateCustomer يُنفّذون arrayUnion لـ
//      logIds/customerIds فقط إذا كان الحقل
//      موجوداً أصلاً (arrayUnion على حقل غائب
//      يُنشئه بقائمة ناقصة — نفس الخلل: كشف
//      التوافق الخارجي يتجاوزه فتبقى
//      المراجع القديمة يتيمة).
//      ⚠️ القاعدة الذهبية المستخلصة: لا تُنشئ
//      حقول تتبع (invoiceIds/logIds/customerIds)
//      على مستند قديم بلاها أبداً — لا فارغة
//      (arrayRemove/كتابة مباشرة) ولا ناقصة
//      (arrayUnion) — غياب الحقل يُبقي كشف
//      التوافق الخارجي صحيحاً. ✅ الاستثناء
//      الوحيد (2026-10-11): ترحيل الحذف
//      (_backfillLegacyCustomerTrackingFields و
//      _backfillLegacyCustomerGroupTrackingFields)
//      يُنشئ الحقل كاملاً (union لكل
//      المعرفات المستعلم عنها + الموجودة) لا
//      ناقصاً — فلا يُفقد كشف التوافق بل
//      يُغلق نافذة السباق (تُقرأ القائمة من
//      داخل معاملة الحذف بعدها).
//    • 2026-10-11 (التحقق الخامس): إصلاح
//      نافذة السباق للبيانات القديمة في
//      deleteCustomer و deleteCustomerGroup
//      (فئتا خلل): (1) الدمج (union) — كانت
//      القائمة المخزنة الناقصة (تُنشأ
//      متزامناً عبر set مع merge من
//      addInvoice) تُظلِّل المراجع المستعلم
//      عنها خارج المعاملة فتبقى مراجع
//      يتيمة — الآن تُدمج المعرفات المخزنة
//      مع المستعلم عنها
//      (effectiveInvoiceIds/effectiveLogIds/
//      effectiveCustomerIds). (2) الترحيل
//      (_backfillLegacyCustomerTrackingFields و
//      _backfillLegacyCustomerGroupTrackingFields)
//      — تُخزَّن المعرفات في المستند كاملاً
//      قبل معاملة الحذف فتُقرأ من داخلها (ما
//      يجب أن يكون ذرياً الموثق أعلاه) —
//      أفضل-جهد وآمن بالدمج. النافذة
//      المتبقية ضئيلة (رحلة شبكة واحدة)
//      ومُوثقة في الخريطة أعلاه.
//    • 2026-10-11 (التحقق السادس): إصلاح
//      خرق القاعدة الذهبية في مُصانِعي
//      invoiceIds الخارجيين (addInvoice و
//      updateInvoice و clearCustomerAccount و
//      deleteInvoice في invoice_repository_impl
//      و _createInvoiceInTransaction في
//      subscription_repository_impl) — كانوا
//      يُنفّذون arrayUnion/arrayRemove على
//      invoiceIds بلا حراسة containsKey فيُنشئون
//      الحقل ناقصاً/فارغاً على عميل قديم
//      بلاه فيُفقد deleteCustomer كشفه
//      بالاستعلام الخارجي فتبقى فواتيره
//      يتيمة — الإصلاح: حراسة containsKey في
//      المواضع الستة (نفس نمط هذا الملف —
//      السبب التفصيلي موثق في كل موضع هناك
//      لإيجاز التكرار هنا).
//    • 2026-10-11 (التحقق العاشر): إصلاح
//      addCustomerLog — كانت تُنهي بـ
//      snapshot.data()! بعد المعاملة؛ لو
//      حُذف السجل متزامناً (deleteCustomerLog)
//      بين التزام المعاملة والقراءة، رُمي
//      Error لا يلتقطه on Exception catch
//      (Error ≠ Exception في Dart) فصار خطأ
//      غير معالج — الإصلاح: فحص صريح يُرجع
//      Left(ServerFailure) ضمن عقد Either
//      (لا علاقة له بالذرية — المعاملة نفسها
//      ذرية سليمة؛ الخلل في قراءة القيمة
//      المرجعة بعدها.)
//    ⚠️ لا تعتمد على أرقام الأسطر في التعليقات
//    أبداً (تصبح قديمة بعد كل إصلاح) — ابحث عن
//    الدالة باسمها. مواضع الإصلاحات: addCustomer
//    (تهيئة القوائم + فحص المجموعة + حراسة
//    arrayUnion للعضوية)، addCustomerWithOpeningBalance
//    (فحص المجموعة + تطبيع مسار الفواتير + حراسة
//    arrayUnion للعضوية)، deleteCustomer و
//    deleteCustomerGroup (قراءة المراجع داخل
//    المعاملة + دمج union مع المستعلم عنه +
//    الترحيل أفضل-جهد)، updateCustomer و
//    deleteCustomer و deleteCustomerLog و
//    clearCustomerLogs (الحفاظ على غياب حقول
//    التتبع عند البيانات القديمة)، addCustomerLog
//    (حراسة arrayUnion لـ logIds)، updateCustomer
//    (حراسة arrayUnion لعضوية المجموعة الجديدة)،
//    _backfillLegacyCustomerTrackingFields و
//    _backfillLegacyCustomerGroupTrackingFields
//    (ترحيل حقول التتبع للبيانات القديمة).
// 🔒 قواعد ذرية إلزامية في هذا الملف (لأي تعديل مستقبلي):
//    1. كل transaction.get() يجب أن يكون قبل كل set/update/delete في نفس
//       runTransaction، وإلا سيظهر الخطأ: '_commands.isEmpty'.
//    2. لا تستخدم استعلامات Query (where/orderBy) داخل runTransaction لأن
//       Firestore SDK لا يدعمها — استخدم مستندات بمعرف معروف بدلاً منها.
//    3. الحقول التراكمية (totalDebt, invoiceIds, logIds) لا تُحسب خارج
//       الـ transaction — إما داخل runTransaction أو عبر FieldValue.increment.
//    4. حد الـ transaction هو 500 عملية كتابة — لا تربط مستندات أكثر من ذلك.
//    5. العلاقات بين المستندات (مثل عضوية العميل في مجموعة) تُصانَع عبر
//       قائمة معرفات داخل المستند (نمط customerIds في مستند المجموعة)
//       لأن الاستعلامات غير مسموحة داخل runTransaction — أي علاقة
//       جديدة تحتاج ذرية كاملة يجب أن تتبع هذا النمط.
//    6. حافظ على فحصي وجود المجموعة (في addCustomer و
//       addCustomerWithOpeningBalance و updateCustomer) وعلى تهيئة
//       القوائم الفارغة (invoiceIds/logIds في addCustomer و
//       customerIds في createCustomerGroup) وعلى حراسات
//       containsKey لحقول التتبع عند القدامى (في addCustomer و
//       addCustomerWithOpeningBalance و updateCustomer و
//       addCustomerLog) وعلى دمج union للمعرفات المستعلم عنها
//       خارج المعاملة مع المخزنة (في deleteCustomer و
//       deleteCustomerGroup) وعلى الترحيل أفضل-جهد
//       (_backfillLegacyCustomerTrackingFields و
//       _backfillLegacyCustomerGroupTrackingFields) — إزالتها
//       تعيد فتح نافذة السباق أو تُنشئ حقول تتبع ناقصة على
//       مستندات قديمة أو تترك مراجع يتيمة وتكسر عقد العضوية
//       الذرية.
// ════════════════════════════════════════════════════════════════════

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl({required this.firestore});
  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();

  CollectionReference _getCustomersCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('customers')
        .collection('customers');
  }

  CollectionReference _getCustomerGroupsCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('customers')
        .collection('customer_groups');
  }

  CollectionReference _getCustomerGroupNamesCollection(
    String organizationEmail,
  ) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('customers')
        .collection('customer_group_names');
  }

  // ===== ملاحظة هامة للمبرمجين المستقبليين =====
  // هذه المجموعات منفصلة تُستخدم لمنع التكرار بشكل ذري بالكامل.
  // Firestore SDK لا يدعم استعلامات Query داخل runTransaction،
  // لذلك نستخدم مستندات حيث القيمة المطلوبة (البريد/الهاتف) هي معرف المستند.
  // هذا يضمن أن التحقق والكتابة يتمان كوحدة واحدة بدون نافذة سباق.
  //
  // ⚠️ قاعدة ذرية حاسمة: كل transaction.get() يجب أن يكون قبل كل transaction.set()/update()/delete()
  // داخل نفس المعاملة. انتهاك هذه القاعدة يسبب:
  //   '_commands.isEmpty': Transactions require all reads to be executed before all writes.
  // لا تضع أي قراءة بعد بدء الكتابة في نفس runTransaction.
  // ==========================================
  CollectionReference _getCustomerEmailsCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('customers')
        .collection('customer_emails');
  }

  CollectionReference _getCustomerPhonesCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('customers')
        .collection('customer_phones');
  }

  String _sanitizeForDocId(String value) {
    final bytes = utf8.encode(value);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// تطبيع رقم الهاتف لاستخدامه كمعرف مستند في فهرس customer_phones.
  /// يزيل المسافات والشرطات والمفتاح الدولي (+964 / 964) والصفر القيادي (0)
  /// بحيث تتطابق صيغرقام الهاتف المختلفة لنفس الرقم (مثلاً 07701234567 و +9647701234567).
  /// ملاحظة للمبرمجين المستقبليين: يجب استخدام نفس الت.Normalization في كل مكان
  /// يُستعمل فيه رقم الهاتف كمعرف مستند (addCustomer, addCustomerWithOpeningBalance,
  /// updateCustomer, isCustomerPhoneUnique, checkCustomerExists, checkCustomerExistsDetailed).
  String _normalizePhoneForIndex(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    var normalized = cleaned.trim();
    if (normalized.startsWith('+964')) {
      normalized = normalized.substring(4);
    } else if (normalized.startsWith('964')) {
      normalized = normalized.substring(3);
    }
    if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> getCustomers(
    String organizationEmail, {
    bool forceRefresh = false,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // إذا كان forceRefresh = true، نجلب البيانات من السيرفر مباشرة
      final snapshot = forceRefresh
          ? await _getCustomersCollection(
              normalizedEmail,
            ).get(const GetOptions(source: Source.server))
          : await _getCustomersCollection(normalizedEmail).get();

      final customers = <CustomerEntity>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) continue;
          final mapData = data as Map<String, dynamic>;
          // دائمًا نستخدم معرف المستند من Firestore كمعرف العميل
          mapData['id'] = doc.id;
          final customer = CustomerModel.fromJson(mapData);
          customers.add(customer);
        } on Exception catch (e) {
          // تجاهل المستندات التي فشل تحويلها مع تسجيل للتشخيص
          LoggerService.warning('CustomerRepositoryImpl.getCustomers: فشل تحويل مستند عميل: $e');
        }
      }

      // ⚠️ ملاحظة للمبرمجين المستقبليين (تحقق
      // الأداء 2026-10-12): الفرز محليٌّ
      // عمدًا — لا تستبدله بـ
      // orderBy('createdAt') في الـ query
      // تحسينًا للأداء دون تقبّل تغيير
      // السلوك: DateParser.parse(null)
      // يُرجع DateTime.now() فمستندات قديمة
      // بلا createdAt صالحة تُطبَّع إلى
      // الآن فتظهر الأولى هنا، بينما
      // Firestore يرتّب الحقل الغائب (null)
      // أخيراً في الترتيب التنازلي —
      // الاستبدال ينقل تلك المستندات من
      // الأول إلى الآخر (سلوك مختلف). هذا
      // الفرز هو سلوك getCustomers القائم
      // (ستريم getCustomersStream يستخدم
      // orderBy سيرفريًا بالفعل — اختلاف
      // معروف للبيانات القديمة). أُبقي
      // محليًا لأن تغيير ترتيب البيانات
      // القديمة تعديل في السلوك لا تحسين
      // في الأداء.
      customers.sort((a, b) {
        return b.createdAt.compareTo(a.createdAt);
      });

      return Right(customers);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, CustomersPage>> getCustomersPaginated({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
    String? searchQuery,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      var query = _getCustomersCollection(
        normalizedEmail,
      ).orderBy('createdAt', descending: true);

      // إذا كان هناك مستند أخير، نبدأ بعده
      if (lastDocument != null && lastDocument is DocumentSnapshot) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      var customers = <CustomerEntity>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) continue;
          final mapData = data as Map<String, dynamic>;
          mapData['id'] = doc.id;
          final customer = CustomerModel.fromJson(mapData);
          customers.add(customer);
        } on Exception catch (e) {
          // تجاهل المستندات التي فشل تحويلها مع تسجيل للتشخيص
          LoggerService.warning('CustomerRepositoryImpl: فشل تحويل مستند عميل (الاستعلام الثاني): $e');
        }
      }

      // تطبيق فلتر البحث في الذاكرة إذا كان موجوداً
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        customers = customers.where((customer) {
          final name = customer.name.toLowerCase();
          final phone = customer.phone.toLowerCase();
          final email = customer.email.toLowerCase();
          return name.contains(searchLower) ||
              phone.contains(searchLower) ||
              email.contains(searchLower);
        }).toList();
      }

      // ✅ تحسين (2026-10-12): نعيد مؤشر
      // الصفحة الأخيرة من نتيجة الاستعلام
      // نفسها (snapshot.docs.last) بدلاً
      // من جلب المستند مجدداً عبر
      // getCustomerDocument — كان يضيف
      // جولة شبكة زائدة بعد كل تحميل
      // صفحة (نفس تحسين قسم الفواتير).
      return Right(
        CustomersPage(
          customers: customers,
          lastDocument:
              snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  /// الحصول على DocumentSnapshot لعميل محدد
  Future<DocumentSnapshot?> getCustomerDocument(
    String organizationEmail,
    String customerId,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      return await _getCustomersCollection(
        normalizedEmail,
      ).doc(customerId).get();
    } on Exception catch (e) {
      // تجاهل خطأ جلب مستند العميل مع تسجيل للتشخيص
      LoggerService.warning('CustomerRepositoryImpl.getCustomerById: فشل جلب المستند: $e');
      return null;
    }
  }

  @override
  Stream<Either<Failure, List<CustomerEntity>>> getCustomersStream(
    String organizationEmail, {
    int? limit,
    String? searchQuery,
    String? statusFilter,
    String? groupFilter,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // 1. بناء الـ query الأساسي
      Query query = _getCustomersCollection(normalizedEmail);

      // 2. إضافة فلتر الحالة إذا كان موجوداً (قبل orderBy)
      if (statusFilter != null && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      // 3. الترتيب
      query = query.orderBy('createdAt', descending: true);

      // 4. ✅ عدم تطبيق الحد في الـ query - نريد كل البيانات للفلترة
      // التطبيق النهائي للحد سيكون في BLoC بعد الفلترة
      // if (limit != null) {
      //   query = query.limit(limit);
      // }

      // 5. الاستماع للتغييرات
      // ✅ تحسين (2026-10-12): نفس تحسين قسم الفواتير —
      // نحفظ العملاء المحللين في ذاكرة خاصة بهذا
      // الستريم ونحدّث المستندات المتغيرة فقط عبر
      // docChanges بدلاً من إعادة تحليل كل العملاء
      // مع كل لقطة — كان يسبب بطءاً ملحوظاً مع
      // كثرة العملاء عند كل تحديث. الحد لا يُطبَّق
      // في الـ query (نريد كل البيانات للفلترة في
      // الذاكرة) فالذاكرة تمثل نتيجة الاستعلام
      // كاملة ويُطبَّق الحد في الذاكرة بعد الفلترة.
      final streamCache = <String, CustomerEntity>{};
      const int maxStreamCacheSize = 1000;

      // ملاحظة للمبرمجين المستقبليين: يتم تحديد حجم الكاش لمنع نمو الذاكرة
      // غير المحدود مع تزايد عدد العملاء. إذا تجاوز عدد العملاء في الكاش الحد
      // الأقصى، يتم إزالة أقدم المدخلات (الأول insertion).
      void evictCacheIfNeeded() {
        while (streamCache.length > maxStreamCacheSize) {
          streamCache.remove(streamCache.keys.first);
        }
      }

      return query
          .snapshots()
          .map((snapshot) {
            try {
              // تحديث تدريجي: نعالج المستندات المتغيرة فقط
              for (final change in snapshot.docChanges) {
                final doc = change.doc;
                if (change.type == DocumentChangeType.removed) {
                  streamCache.remove(doc.id);
                  continue;
                }
                final data = doc.data();
                if (data == null) {
                  streamCache.remove(doc.id);
                  continue;
                }
                final mapData = Map<String, dynamic>.from(
                  data as Map<String, dynamic>,
                );
                // دائمًا نستخدم معرف المستند من Firestore كمعرف العميل
                mapData['id'] = doc.id;
                try {
                  streamCache[doc.id] =
                      CustomerModel.fromJson(mapData).toEntity();
                } on Exception catch (e) {
                  streamCache.remove(doc.id);
                  LoggerService.warning('CustomerRepositoryImpl: فشل تحويل مستند إلى كيان للكاش: $e');
                }
              }
              evictCacheIfNeeded();

              // 6. تطبيق فلتر البحث في الذاكرة — ⚡ تحسين
              // أداء (2026-10-12): حساب شرط البحث ونصه
              // المطبّع مرة واحدة قبل الحلقة (searchQuery
              // ثابت أثناء الحلقة) بدلاً من تكرارهما لكل عميل
              final hasSearch =
                  searchQuery != null && searchQuery.isNotEmpty;
              final searchQueryLower = searchQuery?.toLowerCase() ?? '';

              var customers = streamCache.values.toList()
                ..sort((a, b) {
                  final cmp = b.createdAt.compareTo(a.createdAt);
                  return cmp != 0 ? cmp : a.id.compareTo(b.id);
                });

              if (hasSearch) {
                customers = customers.where((customer) {
                  final name = customer.name.toLowerCase();
                  final email = customer.email.toLowerCase();
                  final phone = customer.phone.toLowerCase();
                  return name.contains(searchQueryLower) ||
                      email.contains(searchQueryLower) ||
                      phone.contains(searchQueryLower);
                }).toList();
              }

              // 7. تطبيق فلتر المجموعة في الذاكرة
              if (groupFilter != null && groupFilter != 'all') {
                customers = customers
                    .where(
                      (customer) => customer.customerGroupId == groupFilter,
                    )
                    .toList();
              }

              // 8. التأكد من عدم تجاوز الحد
              if (limit != null && customers.length > limit) {
                customers = customers.sublist(0, limit);
              }

              return Right<Failure, List<CustomerEntity>>(customers);
            } on Exception catch (e) {
              return Left<Failure, List<CustomerEntity>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, List<CustomerEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  /// تحويل آمن لقيمة رقمية من بيانات Firestore
  /// ✅ تحسين (2026-10-12): يُستخدم في حساب
  /// إحصائيات العملاء من البيانات الخام (بدلاً
  /// من بناء CustomerModel كامل). منطقه مطابق
  /// لـ CustomerModel.fromJson للقيم العددية
  /// ((json[x] as num?)?.toDouble() ?? 0.0) مع
  /// تسامح أكبر مع الأنواع غير المتوقعة.
  static double _parseStatsDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0;
  }

  @override
  Stream<Either<Failure, CustomerStatsEntity>> getCustomerStatsStream(
    String organizationEmail, {
    int? limit,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final collection = _getCustomersCollection(normalizedEmail);

      return collection
          .snapshots()
          .map((snapshot) {
            try {
              // ✅ تحسين (2026-10-12): حساب الإحصائيات
              // مباشرة من بيانات المستند الخام بدلاً
              // من بناء CustomerModel كامل لكل عميل —
              // الإحصائيات تحتاج 4 حقول فقط (status،
              // customerGroupId، totalPurchases، totalDebt)
              // فبناء النموذج كامل كان يهدر وقت المعالج
              // مع كثرة العملاء عند كل لقطة. منطق الحساب
              // مطابق تماماً للسابق (isActive = status ==
              // 'active' و isInactive = status == 'inactive'
              // و isBlocked = status == 'blocked' و hasGroup =
              // customerGroupId غير فارغ — انظر CustomerEntity).
              var activeCustomers = 0;
              var inactiveCustomers = 0;
              var blockedCustomers = 0;
              var customersWithGroups = 0;
              var customersWithoutGroups = 0;
              var totalPurchases = 0.0;
              var netBalance = 0.0;
              var totalDebtAmount = 0.0;
              var totalCreditAmount = 0.0;
              var totalCustomers = 0;

              for (final doc in snapshot.docs) {
                final data = doc.data();
                if (data == null) continue;
                final mapData = data as Map<String, dynamic>;

                final status = mapData['status']?.toString() ?? 'active';
                final customerGroupId =
                    mapData['customerGroupId']?.toString();
                final purchases =
                    _parseStatsDouble(mapData['totalPurchases']);
                final debt = _parseStatsDouble(mapData['totalDebt']);

                totalCustomers++;

                if (status == 'active') activeCustomers++;
                if (status == 'inactive') inactiveCustomers++;
                if (status == 'blocked') blockedCustomers++;
                if (customerGroupId != null &&
                    customerGroupId.isNotEmpty) {
                  customersWithGroups++;
                } else {
                  customersWithoutGroups++;
                }
                totalPurchases += purchases;
                // صافي الحساب = مجموع جميع totalDebt (الموجب والسالب)
                netBalance += debt;
                // إجمالي الديون المستحقة لنا (الموجب فقط - ما على العميل)
                if (debt > 0) {
                  totalDebtAmount += debt;
                } else if (debt < 0) {
                  // إجمالي الائتمانات المستحقة علينا (القيمة المطلقة للسالب - ما لنا على العميل)
                  totalCreditAmount += debt.abs();
                }
              }

              return Right<Failure, CustomerStatsEntity>(
                CustomerStatsEntity(
                  totalCustomers: totalCustomers,
                  activeCustomers: activeCustomers,
                  inactiveCustomers: inactiveCustomers,
                  blockedCustomers: blockedCustomers,
                  customersWithGroups: customersWithGroups,
                  customersWithoutGroups: customersWithoutGroups,
                  totalPurchases: totalPurchases,
                  netBalance: netBalance,
                  totalDebtAmount: totalDebtAmount,
                  totalCreditAmount: totalCreditAmount,
                ),
              );
            } on Exception catch (e) {
              return Left<Failure, CustomerStatsEntity>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, CustomerStatsEntity>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Stream<Either<Failure, List<CustomerGroupEntity>>> getCustomerGroupsStream() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل الدخول')),
        );
      }

      final normalizedEmail = _emailService.normalize(currentUser!.email!);
      final collection = _getCustomerGroupsCollection(normalizedEmail);

      return collection
          .snapshots()
          .map((snapshot) {
            try {
              final groups = <CustomerGroupEntity>[];
              for (final doc in snapshot.docs) {
                try {
                  final data = doc.data();
                  if (data == null) continue;
                  final mapData = Map<String, dynamic>.from(
                    data as Map<String, dynamic>,
                  );
                  mapData['id'] = doc.id;
                  final group = CustomerGroupModel.fromJson(mapData).toEntity();
                  groups.add(group);
                } on Exception catch (e) {
                  // تجاهل مجموعة العملاء التي فشل تحويلها مع تسجيل للتشخيص
                  LoggerService.warning('CustomerRepositoryImpl: فشل تحويل مستند مجموعة عملاء: $e');
                  continue;
                }
              }
              return Right<Failure, List<CustomerGroupEntity>>(groups);
            } on Exception catch (e) {
              return Left<Failure, List<CustomerGroupEntity>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, List<CustomerGroupEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> getCustomerById(
    String id, {
    bool forceRefresh = false,
  }) async {
    try {
      // الحصول على المستخدم الحالي للبحث في مؤسسته فقط
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل الدخول'));
      }

      // إذا كان forceRefresh = true، نجلب البيانات من السيرفر مباشرة
      final doc = forceRefresh
          ? await _getCustomersCollection(
              currentUser!.email!,
            ).doc(id).get(const GetOptions(source: Source.server))
          : await _getCustomersCollection(currentUser!.email!).doc(id).get();

      if (!doc.exists) {
        return const Left(ServerFailure(message: 'العميل غير موجود'));
      }

      final data = doc.data();
      if (data == null) return Left(ServerFailure(message: 'المستند فارغ'));
      final mapData = data as Map<String, dynamic>;
      mapData['id'] = doc.id;
      final customer = CustomerModel.fromJson(mapData);

      return Right(customer);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> addCustomer(
    CustomerEntity customer,
  ) async {
    try {
      // ===== ملاحظة للمبرمجين المستقبليين =====
      // هذه العملية ذرية بالكامل: يتم إنشاء مستند العميل داخل
      // runTransaction. إذا فشل أي جزء من العملية، تفشل العملية
      // بأكملها ولا يبقى عميل نصف منشأ.
      //
      // ⚠️ لماذا التحقق من وجود العميل والتكرار (بريد/هاتف) داخل
      // الـ transaction وليس خارجه؟ لأن التحقق خارج الـ transaction
      // يخلق نافذة سباق (race condition): يمكن لعميلين أن يتحققا
      // من عدم وجود نفس المعرف/البريد/الهاتف في نفس الوقت ثم
      // يحاولا إنشاءه معاً. بالتحقق داخل الـ transaction، نضمن
      // أن التحقق والإنشاء يتم كوحدة واحدة ولا يمكن لعميل آخر
      // أن يمر بينهما.
      //
      // ⚠️ حقل `totalDebt` تراكمي — قاعدته في رأس هذا الملف
      // (قاعدة 3): يُحدَّث ذرياً فقط داخل runTransaction أو
      // عبر FieldValue.increment.
      // ==========================================

      final model = CustomerModel.fromEntity(customer);

      final customerDoc = customer.id.isEmpty
          ? _getCustomersCollection(customer.organizationEmail).doc()
          : _getCustomersCollection(
              customer.organizationEmail,
            ).doc(customer.id);
      final customerId = customerDoc.id;

      final data = model.toJson();
      data['id'] = customerId;
      // ✅ تهيئة قوائم المراجع فارغة (إصلاح اتساق
      // 2026-10-09 — نفس نمط addCustomerWithOpeningBalance):
      // العميل الجديد لا يملك فواتير ولا سجلات. إجبار
      // القوائم على الفارغ يضمن أن مستند العميل يُنشأ
      // دائماً بحقلي invoiceIds و logIds — وهما ما يجعل
      // deleteCustomer ذرياً بالكامل (تُقرأ القوائم من
      // داخل المعاملة). بدونهما: يُصنَّف العميل "عميلاً
      // قديماً" في deleteCustomer ويُستعلم عن فواتيره
      // وسجلاته باستعلام خارج المعاملة (نافذة سباق).
      // ⚠️ لا تحذف هذه التهيئة ولا تعتمد على الكيان
      // الممرر — قد يحمل قوائم قديمة من نسخة عميل.
      data['invoiceIds'] = <String>[];
      data['logIds'] = <String>[];

      final firestoreInstance = FirebaseFirestore.instance;
      await firestoreInstance.runTransaction((transaction) async {
        if (customer.id.isNotEmpty) {
          final docSnapshot = await transaction.get(customerDoc);

          if (docSnapshot.exists) {
            throw Exception('العميل موجود مسبقاً');
          }
        }

        // التحقق من التكرار بالبريد الإلكتروني داخل الـ transaction
        // نستخدم مجموعة منفصلة customer_emails لمنع التكرار بشكل ذري بالكامل
        // ⚠️ لماذا نستخدم مجموعة منفصلة بدلاً من استعلام where().get()؟
        // لأن Firestore SDK لا يدعم استعلامات Query داخل runTransaction.
        // الاستعلام يُنفذ خارج نطاق الـ transaction، مما يخلق نافذة سباق.
        // باستخدام مجموعة منفصلة حيث يكون البريد الإلكتروني هو معرف المستند،
        // نضمن أن التحقق والكتابة يتمان كوحدة واحدة.
        final cleanEmail = customer.email.trim().toLowerCase();
        if (cleanEmail.isNotEmpty) {
          final emailDoc = _getCustomerEmailsCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanEmail));
          final emailSnapshot = await transaction.get(emailDoc);

          if (emailSnapshot.exists) {
            throw Exception('البريد الإلكتروني موجود مسبقاً');
          }
        }

        // التحقق من التكرار برقم الهاتف داخل الـ transaction
        // نستخدم مجموعة منفصلة customer_phones لمنع التكرار بشكل ذري بالكامل
        final cleanPhone = _normalizePhoneForIndex(customer.phone);
        if (cleanPhone.isNotEmpty) {
          final phoneDoc = _getCustomerPhonesCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanPhone));
          final phoneSnapshot = await transaction.get(phoneDoc);

          if (phoneSnapshot.exists) {
            throw Exception('رقم الهاتف موجود مسبقاً');
          }
        }

        // ✅ قراءة مستند مجموعة العميل (إذا وُجدت) داخل الـ
        // transaction — لصيانة قائمة الأعضاء (customerIds)
        // ذرياً. القراءة هنا (قبل كل الكتابات) تلتزم بقاعدة
        // Firestore: كل القراءات قبل كل الكتابات في المعاملة.
        // ⚠️ لماذا نقرأ المجموعة هنا؟
        // لأن deleteCustomerGroup لا يستطيع استعلام العملاء
        // المرتبطين داخل runTransaction (Firestore لا يدعم
        // استعلامات داخل المعاملات) — لذلك تُخزَّن معرفات
        // الأعضاء في مستند المجموعة نفسه (نمط customerIds)
        // وتُصانَع هنا ذرياً: إضافة العميل الجديد إلى قائمة
        // أعضاء مجموعته داخل نفس المعاملة التي تنشئه.
        final customerGroupId = customer.customerGroupId?.trim();
        DocumentSnapshot? groupSnapshot;
        if (customerGroupId != null && customerGroupId.isNotEmpty) {
          groupSnapshot = await transaction.get(
            _getCustomerGroupsCollection(
              customer.organizationEmail,
            ).doc(customerGroupId),
          );
          // ✅ فحص وجود المجموعة داخل المعاملة (إصلاح
          // ذرية 2026-10-09 — نفس نمط updateCustomer):
          // إذا حُذفت المجموعة بعد تحقق الـ BLoC وقبل
          // هذه المعاملة (نافذة سباق)، نفشل الإنشاء
          // بدلاً من ربط العميل بمجموعة محذوفة. بدون
          // هذا الفحص: يُنشأ عميل بـ customerGroupId
          // يشير لمجموعة غير موجودة (مرجع معلق) ولا
          // يُسجَّل عضواً في أي مجموعة — كسر لعقد
          // العضوية الذرية (عميل مرتبط بمجموعة ⟺ مسجَّل
          // في customerIds الخاصة بها).
          if (!groupSnapshot.exists) {
            throw Exception('المجموعة غير موجودة');
          }
        }

        // ✅ تم إزالة التحقق من التكرار بالاسم
        // لأنه غير ذري داخل runTransaction (لا يدعم Firestore استعلامات where)
        // التحقق من البريد/الهاتف يكفي لمنع التكرار بشكل ذري

        transaction.set(customerDoc, data);

        // ✅ صيانة قائمة أعضاء المجموعة ذرياً: أضف معرف العميل
        // الجديد إلى customerIds في مستند المجموعة — وجود
        // المجموعة مضمون هنا بالفحص أعلاه (المجموعة غير
        // الموجودة تُفشل المعاملة قبل هذا السطر، فلا
        // ننشئ مستند مجموعة وهمياً ولا نترك مرجعاً معلقاً).
        // هذا ما يتيح لـ deleteCustomerGroup قراءة الأعضاء
        // من داخل معاملتها بدلاً من استعلام خارجي
        // (نافذة سباق).
        // ✅ إصلاح اتساق البيانات القديمة (2026-10-11):
        // arrayUnion على مجموعة قديمة بلا حقل customerIds
        // يُنشئ الحقل بقائمة ناقصة (معرف العميل الجديد
        // فقط دون أعضائها القدامى غير المُتتبَّعين)
        // فيفقد deleteCustomerGroup كشف أعضائها (يُصبح
        // effectiveCustomerRefs ناقصاً فلا تُصفَّى
        // customerGroupId عنهم فتبقى تشير لمجموعة
        // محذوفة). نُنفّذه فقط إذا كانت المجموعة تملك
        // الحقل أصلاً — المجموعة القديمة تبقى بلا الحقل
        // ليُستعلم عن أعضائها خارج المعاملة كما هو
        // موثق (العميل يُربط بالمجموعة عبر customerGroupId
        // في مستنده في كل الأحوال).
        if (groupSnapshot != null &&
            groupSnapshot.exists &&
            (groupSnapshot.data() as Map<String, dynamic>?)
                    ?.containsKey('customerIds') ==
                true) {
          transaction.update(
            _getCustomerGroupsCollection(
              customer.organizationEmail,
            ).doc(customerGroupId),
            {
              'customerIds': FieldValue.arrayUnion([customerId]),
            },
          );
        }

        // إنشاء مستندات في المجموعات المنفصلة لمنع التكرار بشكل ذري
        if (cleanEmail.isNotEmpty) {
          final emailDoc = _getCustomerEmailsCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanEmail));
          transaction.set(emailDoc, {
            'customerId': customerId,
            'email': customer.email.trim(),
          });
        }

        if (cleanPhone.isNotEmpty) {
          final phoneDoc = _getCustomerPhonesCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanPhone));
          transaction.set(phoneDoc, {
            'customerId': customerId,
            'phone': customer.phone.trim(),
          });
        }
      });

      // إرجاع العميل مع المعرف الصحيح
      final savedCustomer = customer.copyWith(id: customerId);
      return Right(savedCustomer);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> addCustomerWithOpeningBalance({
    required CustomerEntity customer,
    required double openingBalance,
    required String createdBy,
  }) async {
    try {
      // ===== ملاحظة للمبرمجين المستقبليين =====
      // هذه العملية ذرية بالكامل:
      // 1. تنشئ مستند العميل.
      // 2. تنشئ الفاتورة الافتتاحية (إذا وجد رصيد افتتاحي).
      // 3. تحدث حقل `totalDebt` للعميل داخل نفس الـ transaction.
      // إذا فشل أي جزء، تفشل العملية بأكملها ولا يبقى عميل
      // بدون فاتورة افتتاحية.
      //
      // ⚠️ حقل دين العميل (totalDebt) تراكمي ويُحدَّث هنا تلقائياً
      // بناءً على الرصيد الافتتاحي — قاعدته في رأس هذا الملف
      // (قاعدة 3): لا تحسبه خارج هذه العملية إلا إذا كنت تريد
      // تعديله يدوياً في منطق الفواتير لاحقاً.
      //
      // ⚠️ التحقق من تكرار البريد/الهاتف داخل الـ transaction ذري
      // (نفس نمط addCustomer — راجع ملاحظاتها). لا حاجة لتحقق إضافي.
      // ==========================================

      final model = CustomerModel.fromEntity(customer);
      final customerDoc = customer.id.isEmpty
          ? _getCustomersCollection(customer.organizationEmail).doc()
          : _getCustomersCollection(
              customer.organizationEmail,
            ).doc(customer.id);
      final customerId = customerDoc.id;

      final data = model.toJson();
      data['id'] = customerId;
      data['totalDebt'] = openingBalance;
      data['invoiceIds'] = <String>[];
      data['logIds'] = <String>[];

      final firestoreInstance = FirebaseFirestore.instance;
      final savedCustomer = await firestoreInstance.runTransaction((
        transaction,
      ) async {
        if (customer.id.isNotEmpty) {
          final docSnapshot = await transaction.get(customerDoc);

          if (docSnapshot.exists) {
            throw Exception('العميل موجود مسبقاً');
          }
        }

        // التحقق من التكرار بالبريد الإلكتروني داخل الـ transaction
        // (نمط مجموعة customer_emails المنفصلة — راجع الملاحظة
        // التفصيلية في addCustomer: لماذا مجموعة منفصلة بدلاً من
        // استعلام where)
        final cleanEmail = customer.email.trim().toLowerCase();
        if (cleanEmail.isNotEmpty) {
          final emailDoc = _getCustomerEmailsCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanEmail));
          final emailSnapshot = await transaction.get(emailDoc);

          if (emailSnapshot.exists) {
            throw Exception('البريد الإلكتروني موجود مسبقاً');
          }
        }

        // التحقق من التكرار برقم الهاتف داخل الـ transaction
        // (نمط مجموعة customer_phones المنفصلة — نفس سبب البريد)
        final cleanPhone = _normalizePhoneForIndex(customer.phone);
        if (cleanPhone.isNotEmpty) {
          final phoneDoc = _getCustomerPhonesCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanPhone));
          final phoneSnapshot = await transaction.get(phoneDoc);

          if (phoneSnapshot.exists) {
            throw Exception('رقم الهاتف موجود مسبقاً');
          }
        }

        // ✅ قراءة مستند مجموعة العميل (إذا وُجدت) داخل الـ
        // transaction — لصيانة قائمة الأعضاء (customerIds)
        // ذرياً (نفس سبب addCustomer: deleteCustomerGroup
        // لا يستطيع استعلام الأعضاء داخل المعاملة، فتُخزَّن
        // المعرفات في مستند المجموعة وتُصانَع هنا ذرياً).
        // القراءة قبل كل الكتابات (قاعدة Firestore الإلزامية).
        final customerGroupId = customer.customerGroupId?.trim();
        DocumentSnapshot? groupSnapshot;
        if (customerGroupId != null && customerGroupId.isNotEmpty) {
          groupSnapshot = await transaction.get(
            _getCustomerGroupsCollection(
              customer.organizationEmail,
            ).doc(customerGroupId),
          );
          // ✅ فحص وجود المجموعة داخل المعاملة (نفس نمط
          // addCustomer): نفشل الإنشاء إذا حُذفت المجموعة
          // في نافذة سباق بدلاً من ربط العميل بمرجع معلق
          // (كسر لعقد العضوية الذرية).
          if (!groupSnapshot.exists) {
            throw Exception('المجموعة غير موجودة');
          }
        }

        // ✅ تم إزالة التحقق من التكرار بالاسم (غير ذري —
        // Firestore لا يدعم استعلامات where؛ البريد/الهاتف يكفيان)

        transaction.set(customerDoc, data);

        // ✅ صيانة قائمة أعضاء المجموعة ذرياً: أضف معرف العميل
        // الجديد إلى customerIds في مستند المجموعة (نفس
        // نمط addCustomer — وجود المجموعة مضمون بالفحص
        // أعلاه، وهذا ما يتيح لـ deleteCustomerGroup قراءة
        // الأعضاء من داخل معاملتها).
        // ✅ إصلاح اتساق البيانات القديمة (2026-10-11):
        // نفس حراسة addCustomer — arrayUnion على مجموعة
        // قديمة بلا حقل customerIds يُنشئه بقائمة ناقصة
        // فيفقد deleteCustomerGroup كشف أعضائها القدامى،
        // فنُنفّذه فقط إذا كانت تملك الحقل أصلاً (العميل
        // يُربط بالمجموعة عبر customerGroupId في مستنده
        // في كل الأحوال).
        if (groupSnapshot != null &&
            groupSnapshot.exists &&
            (groupSnapshot.data() as Map<String, dynamic>?)
                    ?.containsKey('customerIds') ==
                true) {
          transaction.update(
            _getCustomerGroupsCollection(
              customer.organizationEmail,
            ).doc(customerGroupId),
            {
              'customerIds': FieldValue.arrayUnion([customerId]),
            },
          );
        }

        if (openingBalance != 0) {
          // ⚠️ ملاحظة للمبرمجين المستقبليين (إصلاح
          // ذرية/اتساق 2026-10-08): مسار مجموعة الفواتير
          // هنا يجب أن يكون مطبّعاً (_emailService
          // .normalize) بنفس نمط _getInvoicesCollection
          // في invoice_repository_impl و deleteCustomer
          // أدناه. لماذا؟ لأن FirebaseAuth قد يُرجع
          // بريداً يختلف بعد التطبيع (مثال:
          // 'A.Hmed+test@gmail.com' → 'ahmed@gmail.com').
          // كان هذا المكان الوحيد في المشروع الذي يُكتب
          // فيه مسار مجموعة بمعرّف بريد خام — ففاتورة
          // الرصيد الافتتاحي كانت تُكتب في مسار يتيم
          // لا يقرأه أي كود: لا تظهر في قوائم الفواتير،
          // و invoiceIds في مستند العميل يشير إلى معرف
          // في مجموعة خاطئة، و deleteCustomer لا يجدها
          // لوضع علامة 'deleted_customer' عليها.
          // ⚠️ لا تُرجع هذا المسار للبريد الخام
          // (customer.organizationEmail) أبداً — ذلك
          // يعيد الفاتورة اليتيمة. الذرية نفسها سليمة
          // (المعاملة كلها تنجح أو تفشل معاً —
          // all-or-nothing) والتطبيع يُطبَّق قبل
          // بدء المعاملة (خارج runTransaction) لأنه
          // تحويل محلي بحت لا يحتاج قراءة من السيرفر.
          final invoiceCollection = firestoreInstance
              .collection(
                _emailService.normalize(customer.organizationEmail),
              )
              .doc('invoices')
              .collection('invoices');
          final invoiceDoc = invoiceCollection.doc();
          final invoiceId = invoiceDoc.id;

          final isDebit = openingBalance > 0;
          final isCredit = openingBalance < 0;
          const invoiceType = 'opening_balance';
          final description = isDebit
              ? 'حساب افتتاحي مدين (عليه)'
              : (isCredit ? 'حساب افتتاحي دائن (له)' : 'حساب افتتاحي متوازن');

          final now = DateTime.now();
          final invoiceNumber =
              InvoiceNumberingService.generateNumberSync(section: 'opening_balance');

          double totalAmount, paidAmount, remainingAmount;
          String status;
          String notes;

          if (isDebit) {
            totalAmount = openingBalance.abs();
            paidAmount = 0;
            remainingAmount = openingBalance.abs();
            status = 'unpaid';
            notes =
                'فاتورة حساب افتتاحي مدين - العميل عليه مبلغ ${openingBalance.abs()}';
          } else if (isCredit) {
            totalAmount = openingBalance.abs();
            paidAmount = openingBalance.abs();
            remainingAmount = 0;
            status = 'paid';
            notes =
                'فاتورة حساب افتتاحي دائن - العميل لديه مبلغ مسبق الدفع ${openingBalance.abs()}';
          } else {
            totalAmount = 0;
            paidAmount = 0;
            remainingAmount = 0;
            status = 'paid';
            notes = 'فاتورة حساب افتتاحي متوازن - لا يوجد دين';
          }

          final invoiceData = {
            'id': invoiceId,
            'invoiceNumber': invoiceNumber,
            'customerName': customer.name,
            'customerPhone': customer.phone,
            'customerId': customerId,
            'invoiceDate': Timestamp.fromDate(now),
            'totalAmount': totalAmount,
            'paidAmount': paidAmount,
            'remainingAmount': remainingAmount,
            'status': status,
            'type': invoiceType,
            'items': [
              {
                'productName': description,
                'quantity': 1,
                'unit': 'حساب',
                'unitPrice': openingBalance.abs(),
                'totalPrice': openingBalance.abs(),
              },
            ],
            'notes': notes,
            'organizationEmail': customer.organizationEmail,
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
            'createdBy': createdBy,
            'balanceBeforeInvoice': 0.0,
            'balanceAfterInvoice': openingBalance,
          };

          transaction.set(invoiceDoc, invoiceData);

          // ✅ تحديث قائمة الفواتير في مستند العميل ذرياً
          transaction.set(customerDoc, {
            'invoiceIds': FieldValue.arrayUnion([invoiceId]),
          }, SetOptions(merge: true));
        }

        // إنشاء مستندات في المجموعات المنفصلة لمنع التكرار بشكل ذري
        if (cleanEmail.isNotEmpty) {
          final emailDoc = _getCustomerEmailsCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanEmail));
          transaction.set(emailDoc, {
            'customerId': customerId,
            'email': customer.email.trim(),
          });
        }

        if (cleanPhone.isNotEmpty) {
          final phoneDoc = _getCustomerPhonesCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanPhone));
          transaction.set(phoneDoc, {
            'customerId': customerId,
            'phone': customer.phone.trim(),
          });
        }

        return customer.copyWith(id: customerId);
      });

      return Right(savedCustomer);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> updateCustomer(CustomerEntity customer) async {
    try {
      // ===== ملاحظة للمبرمجين المستقبليين =====
      // نمط Read-Modify-Write داخل runTransaction:
      // 1. نقرأ المستند داخل الـ transaction (transaction.get) للحصول على لقطة متسقة.
      // 2. نتحقق من وجود العميل - إذا لم يوجد، نرمي استثناء لتفشيل العملية.
      // 3. نحدث المستند داخل نفس الـ transaction.
      // هذا يضمن عزل اللقطات (snapshot isolation): إما أن تنجح كل التحديثات
      // أو تفشل كلها، ولا توجد حالة وسيطة حيث تمت القراءة دون التحديث.
      //
        // ⚠️ لماذا التحقق من عدم تكرار البريد/الهاتف داخل
        // الـ transaction؟ نفس سبب addCustomer (راجع
        // ملاحظتها): التحقق خارج الـ transaction يخلق
        // نافذة سباق — بالتحقق داخلها يصبح التحقق
        // والتحديث وحدة واحدة.
      //
      // ✅ تحقق الذرية (للمبرمجين المستقبليين) — نتيجة التحقق اليدوي:
      //   العملية ذرية بالكامل (كل القراءات قبل كل الكتابات داخل
      //   runTransaction واحد). حقل totalDebt التراكمي (قاعدته في
      //   رأس هذا الملف — قاعدة 3) يُحافظ على قيمة السيرفر من
      //   اللقطة المقروءة داخل المعاملة (docSnapshot.data() أدناه)
      //   وليس من الكيان: إذا تغير totalDebt على السيرفر (مثلاً
      //   عبر فاتورة جديدة في invoice_repository_impl) بين تحميل
      //   الشاشة وهذا التحديث، فقيمة السيرفر الطازجة هي التي
      //   تُحفظ وليس قيمة الشاشة القديمة — وهذا ما يفادي خطر
      //   التحديث المفقود (lost update).
      //   ⚠️ لا ترجع أبداً لكتابة totalDebt من الكيان
      //   (model.totalDebt) هنا — ذلك يعيد خطر التحديث المفقود.
      //   تحديث totalDebt يتم فقط في InvoiceRepositoryImpl داخل
      //   معاملتها الخاصة.
      // ==========================================

      final model = CustomerModel.fromEntity(customer);

      // استخدام Transaction لضمان الحفظ الذري
      // إما أن يحفظ كل البيانات أو يفشل كله
      final firestoreInstance = FirebaseFirestore.instance;
      await firestoreInstance.runTransaction((transaction) async {
        final customerDoc = _getCustomersCollection(
          customer.organizationEmail,
        ).doc(customer.id);

        // التحقق من وجود العميل قبل التحديث
        final docSnapshot = await transaction.get(customerDoc);

        if (!docSnapshot.exists) {
          throw Exception('العميل غير موجود');
        }

        final existingData = docSnapshot.data() as Map<String, dynamic>?;
        final existingEmail =
            (existingData?['email'] as String?)?.trim().toLowerCase() ?? '';
        final existingPhone = (existingData?['phone'] as String?)?.trim() ?? '';

        // التحقق من عدم تحديث البريد الإلكتروني إلى قيمة مكررة
        // (نمط مجموعة customer_emails المنفصلة — راجع الملاحظة
        // التفصيلية في addCustomer: لماذا مجموعة منفصلة بدلاً من
        // استعلام where)
        final cleanEmail = customer.email.trim().toLowerCase();
        if (cleanEmail.isNotEmpty) {
          final emailDoc = _getCustomerEmailsCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanEmail));
          final emailSnapshot = await transaction.get(emailDoc);

          // إذا كان هناك مستند بنفس البريد الإلكتروني ولا ينتمي لهذا العميل
          if (emailSnapshot.exists &&
              (emailSnapshot.data() as Map<String, dynamic>?)?['customerId'] !=
                  customer.id) {
            throw Exception('البريد الإلكتروني موجود مسبقاً لعميل آخر');
          }
        }

        // التحقق من عدم تحديث رقم الهاتف إلى قيمة مكررة
        // (نمط مجموعة customer_phones المنفصلة — نفس سبب البريد)
        final cleanPhone = _normalizePhoneForIndex(customer.phone);
        if (cleanPhone.isNotEmpty) {
          final phoneDoc = _getCustomerPhonesCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanPhone));
          final phoneSnapshot = await transaction.get(phoneDoc);

          // إذا كان هناك مستند بنفس رقم الهاتف ولا ينتمي لهذا العميل
          if (phoneSnapshot.exists &&
              (phoneSnapshot.data() as Map<String, dynamic>?)?['customerId'] !=
                  customer.id) {
            throw Exception('رقم الهاتف موجود مسبقاً لعميل آخر');
          }
        }

        // ✅ صيانة قائمة أعضاء المجموعة (customerIds) ذرياً:
        // نقرأ مستندي المجموعة القديمة والجديدة (بمعرف
        // معروف — لا استعلام داخل runTransaction) قبل أي
        // كتابة. إذا تغيرت مجموعة العميل، نزيله من قائمة
        // أعضاء المجموعة القديمة ونضيفه إلى الجديدة داخل
        // نفس المعاملة — هذا ما يتيح لـ deleteCustomerGroup
        // قراءة الأعضاء من داخل معاملتها بدلاً من استعلام
        // خارجي (الذي يخلق نافذة سباق).
        final existingGroupId = (existingData?['customerGroupId'] as String?)
            ?.trim();
        final existingGroupIdNormalized =
            (existingGroupId != null && existingGroupId.isNotEmpty)
            ? existingGroupId
            : null;
        final newGroupId = customer.customerGroupId?.trim();
        final newGroupIdNormalized =
            (newGroupId != null && newGroupId.isNotEmpty) ? newGroupId : null;

        DocumentSnapshot? oldGroupSnapshot;
        DocumentSnapshot? newGroupSnapshot;
        if (existingGroupIdNormalized != newGroupIdNormalized) {
          if (existingGroupIdNormalized != null) {
            oldGroupSnapshot = await transaction.get(
              _getCustomerGroupsCollection(
                customer.organizationEmail,
              ).doc(existingGroupIdNormalized),
            );
          }
          if (newGroupIdNormalized != null) {
            newGroupSnapshot = await transaction.get(
              _getCustomerGroupsCollection(
                customer.organizationEmail,
              ).doc(newGroupIdNormalized),
            );
            // ⚠️ فحص وجود المجموعة الجديدة داخل المعاملة:
            // إذا حُذفت المجموعة بعد تحقق الـ BLoC وقبل هذه
            // المعاملة (نافذة سباق)، نفشل التحديث هنا بدلاً
            // من ربط العميل بمجموعة محذوفة (مرجع معلق).
            // بدون هذا الفحص: عند إعادة محاولة المعاملة بعد
            // حذف المجموعة، تتجاوز الصيانة وتترك المرجع
            // معلقاً — لذلك الفحص إلزامي لإغلاق النافذة.
            if (!newGroupSnapshot.exists) {
              throw Exception('المجموعة غير موجودة');
            }
          }
        }

        // ✅ تحديث البيانات في نفس الـ transaction
        // نقرأ invoiceIds و logIds من المستند الحالي لضمان عدم فقدانها
        // ✅ إصلاح اتساق البيانات القديمة (2026-10-11):
        // العميل القديم الذي لا يملك حقلي invoiceIds/
        // logIds في مستنده (أُنشئ قبل تهيئة القوائم)
        // يجب أن يبقى بلاهما — toJson يكتبهما دائماً
        // و fromJson تُرجعهما فارغين عند غيابهما، فكان
        // التحديث يكتب لهما قائمتين فارغتين فيصير
        // containsKey صحيحاً في deleteCustomer فيتجاوز
        // استعلام التوافق الخارجي (الذي يجد فواتيره و
        // سجلاته الحقيقية) بينما القائمتان المخزنتان
        // فارغتان → effectiveInvoiceRefs/effectiveLogRefs
        // فارغتان → فواتيره وسجلاته الحقيقية تبقى يشير
        // إليها عميل محذوف (مراجع يتيمة). بالحفاظ على
        // غياب الحقلين عند القدامى يبقى كشف deleteCustomer
        // لهم صحيحاً. ⚠️ لا تُرجع كتابة القائمتين الفارغتين
        // للعملاء القدامى أبداً.
        final existingInvoiceIdsRaw =
            existingData?['invoiceIds'] as List<dynamic>?;
        final existingLogIdsRaw =
            existingData?['logIds'] as List<dynamic>?;

        final updateData = model.toJson();
        if (existingInvoiceIdsRaw != null) {
          updateData['invoiceIds'] =
              existingInvoiceIdsRaw.map((e) => e.toString()).toList();
        } else {
          updateData.remove('invoiceIds');
        }
        if (existingLogIdsRaw != null) {
          updateData['logIds'] =
              existingLogIdsRaw.map((e) => e.toString()).toList();
        } else {
          updateData.remove('logIds');
        }

        // ✅ حقل totalDebt تراكمي يملكه منطق الفواتير —
        // نحافظ على قيمة السيرفر من اللقطة داخل المعاملة
        // بدلاً من قيمة الكيان (التي قد تكون قديمة من
        // تحميل الشاشة)، لمنع التحديث المفقود (lost
        // update) إذا تغير الدين عبر فاتورة جديدة بين
        // تحميل الشاشة وهذا التحديث. تحديث totalDebt
        // يتم فقط في InvoiceRepositoryImpl داخل
        // معاملتها الخاصة.
        updateData['totalDebt'] =
            (existingData?['totalDebt'] as num?)?.toDouble() ?? model.totalDebt;

        transaction.update(customerDoc, updateData);

        // ✅ تحديث قوائم الأعضاء في المجموعتين القديمة والجديدة
        // (فقط إذا كان المستند موجوداً — لا ننشئ مستند مجموعة
        // وهمياً). هذه الكتابات داخل نفس المعاملة فتنجح أو
        // تفشل مع تحديث العميل معاً — لا يمكن أن يُربط عميل
        // بمجموعة دون أن يُسجَّل عضواً فيها أو العكس.
        // ✅ إصلاح اتساق البيانات القديمة (2026-10-11):
        // arrayRemove على مجموعة قديمة بلا حقل
        // customerIds يُنشئ الحقل فارغاً فيفقد
        // deleteCustomerGroup كشف أعضائها غير
        // المُتتبَّعين (يُصبح effectiveCustomerRefs
        // فارغاً فلا تُصفَّى customerGroupId عنهم).
        // نُنفّذه فقط إذا كانت المجموعة القديمة
        // تملك الحقل — المجموعة القديمة تبقى بلا
        // الحقل ليُستعلم عن أعضائها خارج المعاملة
        // كما هو موثق. مرجع العضو المنتقل يُحذف
        // من مستند العميل أعلاه (customerGroupId
        // الجديد) — ذلك هو المرجع المعتمد، و
        // customerIds فهرس ثانوي ذري للمجموعات
        // الحديثة فقط.
        if (oldGroupSnapshot != null &&
            oldGroupSnapshot.exists &&
            (oldGroupSnapshot.data() as Map<String, dynamic>?)
                    ?.containsKey('customerIds') ==
                true) {
          transaction.update(
            _getCustomerGroupsCollection(
              customer.organizationEmail,
            ).doc(existingGroupIdNormalized!),
            {
              'customerIds': FieldValue.arrayRemove([customer.id]),
            },
          );
        }
        // ✅ إصلاح اتساق البيانات القديمة (2026-10-11):
        // نفس حراسة arrayRemove أعلاه — arrayUnion على
        // مجموعة جديدة قديمة بلا حقل customerIds يُنشئه
        // بقائمة ناقصة فيفقد deleteCustomerGroup كشف
        // أعضائها القدامى، فنُنفّذه فقط إذا كانت تملك
        // الحقل أصلاً (العميل يُربط بالمجموعة عبر
        // customerGroupId في مستنده في كل الأحوال).
        if (newGroupSnapshot != null &&
            newGroupSnapshot.exists &&
            (newGroupSnapshot.data() as Map<String, dynamic>?)
                    ?.containsKey('customerIds') ==
                true) {
          transaction.update(
            _getCustomerGroupsCollection(
              customer.organizationEmail,
            ).doc(newGroupIdNormalized!),
            {
              'customerIds': FieldValue.arrayUnion([customer.id]),
            },
          );
        }

        // تحديث مستندات التكرار بشكل ذري
        // حذف المستند القديم للبريد الإلكتروني إذا تغير
        if (existingEmail.isNotEmpty && existingEmail != cleanEmail) {
          final oldEmailDoc = _getCustomerEmailsCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(existingEmail));
          transaction.delete(oldEmailDoc);
        }

        // حذف المستند القديم للهاتف إذا تغير
        if (existingPhone.isNotEmpty && existingPhone != cleanPhone) {
          final oldPhoneDoc = _getCustomerPhonesCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(existingPhone));
          transaction.delete(oldPhoneDoc);
        }

        // إنشاء/تحديث مستند البريد الإلكتروني الجديد
        if (cleanEmail.isNotEmpty) {
          final emailDoc = _getCustomerEmailsCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanEmail));
          transaction.set(emailDoc, {
            'customerId': customer.id,
            'email': customer.email.trim(),
          });
        }

        // إنشاء/تحديث مستند الهاتف الجديد
        if (cleanPhone.isNotEmpty) {
          final phoneDoc = _getCustomerPhonesCollection(
            customer.organizationEmail,
          ).doc(_sanitizeForDocId(cleanPhone));
          transaction.set(phoneDoc, {
            'customerId': customer.id,
            'phone': customer.phone.trim(),
          });
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCustomer(
    String id,
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;

      // ===== ملاحظة هامة للمبرمجين المستقبليين (تحقق الذرية) =====
      // حالة هذه العملية (نتيجة التحقق اليدوي الدقيق
      // + إصلاح 2026-10-11):
      //   ✅ ذرية بالكامل لكل العملاء — invoiceIds و
      //      logIds والبريد/الهاتف تُقرأ من داخل
      //      الـ transaction عبر transaction.get(customerDocRef)
      //      (أدناه) وتُبنى المراجع من تلك اللقطة
      //      الطازجة مدمجة (union) مع ما استُعلم
      //      عنه خارجها. للبيانات القديمة بلا
      //      القوائم: يُرحَّلُها
      //      _backfillLegacyCustomerTrackingFields أولاً
      //      (تُخزَّن المعرفات في المستند كاملاً)
      //      فتُقرأ من داخل معاملة الحذف — لا
      //      نافذة سباق تُذكر (راجع ملاحظة
      //      الترحيل أدناه).
      //
      // ما هو ذري فعلاً هنا:
      //   عمليات الكتابة داخل runTransaction (حذف فهرسي البريد/الهاتف،
      //   تحديث الفواتير المرتبطة، حذف السجلات المرتبطة، حذف العميل)
      //   تنجح كلها أو تفشل كلها معاً — لا توجد حالة وسيطة.
      //
      // ⚠️ النافذة المتبقية الضئيلة (قيد الـ SDK):
      //   Firestore لا يدعم استعلامات Query (where/orderBy)
      //   داخل runTransaction — يمكن فقط قراءة
      //   مستندات بمعرف معروف. الترحيل يستعلم
      //   خارج المعاملة (استعلام طازج مباشرة
      //   قبلها) فتبقى نافذة رحلة شبكة واحدة:
      //   مرجع يُضاف أثناءها ولا يُنشئ مساره
      //   الحقل لمستند بلاه (addCustomerLog يحفظ
      //   الحقل إن وُجد) — مصيره مرجع يتيم
      //   واحد بدلاً من نافذة كاملة. هذا أفضل
      //   ما يمكن تحقيقه دون تغيير الـ SDK.
      //
      // ✅ ما يجب أن يكون ذرياً (نُفِّذ 2026-10-11):
      //   خزّن معرفات الفواتير/السجلات المرتبطة داخل
      //   مستند العميل نفسه (نفس نمط invoiceIds/logIds
      //   الحالي) ثم اقرأها عبر transaction.get() داخل
      //   الـ transaction — هذا يغلق نافذة السباق
      //   تماماً دون الحاجة لاستعلام. نُفِّذ عبر
      //   _backfillLegacyCustomerTrackingFields أعلاه
      //   (أفضل-جهد: فشله لا يُفشل الحذف — يُكمل
      //   بالمسار القديم + الدمج وهو آمن).
      //
      // ⚠️ حدود إضافية يجب معرفتها:
      //   - الـ transaction محدود بـ 500 عملية كتابة: عميل لديه
      //     عدد كبير من الفواتير/السجلات قد يفشل كامل العملية.
      //   - استعلاما التوافق مع العملاء القدامى (where customerId/
      //     targetId) يُنفذان خارج الـ transaction — النافذة
      //     مُصغَّرة بالترحيل أعلاه.
      //
      // ⚠️ كيف يتم تحديث invoiceIds و logIds عادةً؟
      //   - عند إنشاء فاتورة جديدة: arrayUnion في invoice_repository_impl.
      //   - عند حذف فاتورة: arrayRemove في invoice_repository_impl.
      //   - عند إنشاء سجل جديد: arrayUnion في addCustomerLog أدناه.
      //   - عند حذف سجل: arrayRemove في deleteCustomerLog أدناه.
      //
      // ⚠️ تحذير: لا تقم بتحديث حقل `totalDebt` هنا إلا إذا كنت تفهم
      // تأثير ذلك على الفواتير المرتبطة. هذا الحقل تراكمي (قاعدته
      // في رأس هذا الملف — قاعدة 3) ويجب أن يتم تحديثه فقط في
      // منطق الفواتير.
      // ================================================

      // جلب بيانات العميل أولاً للتحقق من الوجود فقط
      // ⚠️ ملاحظة ذرية: invoiceIds و logIds والبريد/الهاتف تُقرأ
      // من داخل الـ transaction أدناه (من اللقطة الطازجة) وليس
      // من هذه القراءة الخارجية — هذا ما يغلق نافذة السباق.
      // هذه القراءة الخارجية تُستخدم فقط للتحقق من الوجود
      // وللكشف عن العملاء القدامى (بدون قوائم مخزنة).
      final customerDocRef = _getCustomersCollection(normalizedEmail).doc(id);
      final customerSnapshot = await customerDocRef.get();

      if (!customerSnapshot.exists) {
        return const Left(ServerFailure(message: 'العميل غير موجود'));
      }

      // بناء مراجع الفواتير والسجلات
      final invoicesCollection = firestoreInstance
          .collection(normalizedEmail)
          .doc('invoices')
          .collection('invoices');
      final logsCollection = firestoreInstance
          .collection(normalizedEmail)
          .doc('customers')
          .collection('logs');

      // كشف العملاء القدامى الذين لا يملكون حقول invoiceIds/logIds
      // (لاستخدام استعلام التوافق خارج المعاملة — نافذة السباق
      // تبقى لهذه الحالة فقط لأن Firestore لا يدعم استعلامات
      // داخل runTransaction).
      final legacyData = customerSnapshot.data() as Map<String, dynamic>?;
      final legacyHasInvoiceIds =
          legacyData?.containsKey('invoiceIds') ?? false;
      final legacyHasLogIds = legacyData?.containsKey('logIds') ?? false;

      List<String> legacyInvoiceIds = [];
      if (!legacyHasInvoiceIds) {
        // التوافق مع العملاء القدامى الذين لا يملكون
        // invoiceIds — نجمع المعرفات (لا المراجع)
        // لتُدمج مع invoiceIds المخزنة داخل المعاملة
        // أدناه (إصلاح نافذة السباق 2026-10-11).
        final linkedInvoicesSnapshot = await invoicesCollection
            .where('customerId', isEqualTo: id)
            .get();
        legacyInvoiceIds = linkedInvoicesSnapshot.docs
            .map((doc) => doc.id)
            .toList();
      }

      List<String> legacyLogIds = [];
      if (!legacyHasLogIds) {
        // التوافق مع العملاء القدامى الذين لا يملكون
        // logIds — نفس نمط الفواتير أعلاه (جمع
        // المعرفات للدمج داخل المعاملة).
        // ⚠️ ملاحظة للمبرمجين المستقبليين (فهرس مركب
        // إلزامي — أُضيف 2026-10-08): هذا الاستعلام
        // يصفّي على حقلين مختلفين (targetId و
        // targetType). Firestore يشترط فهرسًا مركبًا
        // (composite index) لأي استعلام بأكثر من where
        // على حقلين مختلفين ولا يجمع فهارس الحقل
        // الواحد — بدون الفهرس (targetId, targetType)
        // على مجموعة logs في firestore.indexes.json يفشل
        // الاستعلام وقت التشغيل بخطأ "The query
        // requires an index" ويُفشل حذف العميل كاملة.
        // ⚠️ لا تحذف ذلك الفهرس ولا تُعدِّل ترتيب
        // الحقلين في الاستعلام دون مراجعة الفهرس.
        final linkedLogsSnapshot = await logsCollection
            .where('targetId', isEqualTo: id)
            .where('targetType', isEqualTo: 'customer')
            .get();
        legacyLogIds = linkedLogsSnapshot.docs
            .map((doc) => doc.id)
            .toList();
      }

      // ✅ ترحيل حقول التتبع للبيانات القديمة (إصلاح
      // نافذة السباق 2026-10-11 — "ما يجب أن يكون ذرياً"
      // الموثق في رأس هذا الملف): نخزّن معرفات الفواتير/
      // السجلات المرتبطة في مستند العميل نفسه (دمجاً
      // كاملاً لا ناقصاً) قبل معاملة الحذف — بعدها
      // تُقرأ القوائم من داخل المعاملة فتُغلق نافذة
      // السباق. الترحيل أفضل-جهد: فشله لا يُفشل الحذف
      // (يُكمل بالمسار القديم + الدمج أدناه وهو آمن).
      // ⚠️ هذا استثناء مقصود من القاعدة الذهبية (لا
      // تُنشئ حقول تتبع على مستند قديم): الترحيل يُنشئ
      // الحقل كاملاً (union) لا ناقصاً (arrayUnion) فلا
      // يُفقد كشف التوافق الخارجي — بل يُغلق النافذة.
      if (!legacyHasInvoiceIds || !legacyHasLogIds) {
        try {
          await _backfillLegacyCustomerTrackingFields(
            customerDocRef: customerDocRef,
            invoicesCollection: invoicesCollection,
            logsCollection: logsCollection,
            customerId: id,
            backfillInvoiceIds: !legacyHasInvoiceIds,
            backfillLogIds: !legacyHasLogIds,
          );
        } on Exception catch (e) {
          // الترحيل أفضل-جهد — فشله لا يُفشل الحذف
          // (المسار القديم + الدمج أدناه آمنان).
          LoggerService.warning('CustomerRepositoryImpl.deleteCustomer: فشل الترحيل الأفضل-جهد: $e');
        }
      }

      await firestoreInstance.runTransaction((transaction) async {
        // ✅ قراءة مستند العميل داخل الـ transaction للحصول على لقطة
        // طازجة من invoiceIds و logIds والبريد/الهاتف — لأن القوائم
        // مخزنة في نفس المستند الذي نحذفه، فلا يمكن أن تتغير بين
        // القراءة والكتابة داخل المعاملة. هذا يغلق نافذة السباق
        // لجميع العملاء الذين يملكون قوائم مخزنة.
        final customerSnapshotInTx = await transaction.get(customerDocRef);
        if (!customerSnapshotInTx.exists) {
          throw Exception('العميل غير موجود');
        }

        final customerDataInTx =
            customerSnapshotInTx.data() as Map<String, dynamic>?;
        final storedInvoiceIds =
            (customerDataInTx?['invoiceIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList();
        final storedLogIds = (customerDataInTx?['logIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
        final customerEmail =
            (customerDataInTx?['email'] as String?)?.trim().toLowerCase() ?? '';
        final customerPhone =
            _normalizePhoneForIndex((customerDataInTx?['phone'] as String?) ?? '');
        final customerGroupId =
            (customerDataInTx?['customerGroupId'] as String?)?.trim();

        // ✅ قراءة مستند مجموعة العميل (إذا وُجدت) داخل الـ
        // transaction — لإزالة العميل من قائمة الأعضاء
        // (customerIds) ذرياً عند حذفه. القراءة قبل كل
        // الكتابات (قاعدة Firestore الإلزامية).
        DocumentSnapshot? groupSnapshot;
        if (customerGroupId != null && customerGroupId.isNotEmpty) {
          groupSnapshot = await transaction.get(
            _getCustomerGroupsCollection(normalizedEmail).doc(customerGroupId),
          );
        }

        // ✅ دمج المعرفات المخزنة مع المعرفات المستعلم عنها
        // خارج المعاملة (إصلاح نافذة السباق 2026-10-11):
        // لو أُنشئ حقل التتبع متزامناً (مثلاً addInvoice
        // يكتب invoiceIds عبر set مع merge لعميل قديم
        // بلا الحقل) بين الاستعلام الخارجي وقراءة هذه
        // المعاملة، كانت القائمة المخزنة (الناقصة —
        // معرف الفاتورة الجديدة فقط) تُظلِّل المراجع
        // المستعلم عنها فتبقى فواتير العميل القديمة
        // تشير لعميل محذوف (مراجع يتيمة). بالدمج
        // (union) تُحدَّث المرجعتان معاً — لا يتيمة.
        // للعملاء غير القدامى القائمتان المستعلمتان
        // فارغتان (لم يُستعلم عنهما) فالدمج = القائمة
        // المخزنة فقط (سلوك مطابق تماماً للسابق).
        final effectiveInvoiceIds = <String>{
          ...?storedInvoiceIds,
          ...legacyInvoiceIds,
        }.toList();
        final effectiveInvoiceRefs = effectiveInvoiceIds
            .map((invoiceId) => invoicesCollection.doc(invoiceId))
            .toList();
        final effectiveLogIds = <String>{
          ...?storedLogIds,
          ...legacyLogIds,
        }.toList();
        final effectiveLogRefs = effectiveLogIds
            .map((logId) => logsCollection.doc(logId))
            .toList();

        // ✅ إصلاح ذرية (من التحقق اليدوي 2026-10-08):
        // قراءة جميع مراجع الفواتير المرتبطة داخل المعاملة
        // (قبل أي كتابة — قاعدة Firestore الإلزامية: كل
        // القراءات قبل كل الكتابات) والتحقق من وجود كل
        // فاتورة. السبب: transaction.update() تشترط وجود
        // المستند، فإذا كان أحد معرفات الفواتير المخزنة
        // (invoiceIds) يشير إلى فاتورة حُذفت مسبقاً عبر
        // مسار لا يصانِع القائمة، كانت المعاملة تفشل كاملة
        // ويُرفض حذف العميل. بالقراءة أولاً نُحدِّث الفواتير
        // الموجودة فقط ونُتجاهل المراجع المعلقة — سلوك مرن
        // مع الحفاظ على الذرية all-or-nothing (إما تُحدَّث
        // الفواتير الموجودة ويُحذف العميل معاً، أو يفشل
        // كل شيء معاً). ⚠️ لا تُصلح هذا بـ transaction.set()
        // مع merge لأن ذلك يُنشئ مستند فاتورة وهمياً
        // (phantom) ببيانات خاطئة. ⚠️ ملاحظة حد المعاملة:
        // القراءات تُحتسب ضمن حد 500 عملية للمعاملة، فإذا
        // كان للعميل عدد كبير جداً من الفواتير قد تفشل
        // المعاملة بسبب الحد — وهذا أفضل من فشل صامت
        // يترك فواتير تشير إلى عميل محذوف.
        final existingInvoiceRefs = <DocumentReference>[];
        for (final invoiceRef in effectiveInvoiceRefs) {
          final invoiceSnapshot = await transaction.get(invoiceRef);
          if (invoiceSnapshot.exists) {
            existingInvoiceRefs.add(invoiceRef);
          }
        }

        // حذف مستندات التكرار المرتبطة بالعميل
        if (customerEmail.isNotEmpty) {
          final emailDoc = _getCustomerEmailsCollection(
            normalizedEmail,
          ).doc(_sanitizeForDocId(customerEmail));
          transaction.delete(emailDoc);
        }

        if (customerPhone.isNotEmpty) {
          final phoneDoc = _getCustomerPhonesCollection(
            normalizedEmail,
          ).doc(_sanitizeForDocId(customerPhone));
          transaction.delete(phoneDoc);
        }

        // تحديث الفواتير المرتبطة الموجودة فقط داخل نفس
        // الـ transaction (المراجع المعلقة على فواتير
        // محذوفة مسبقاً تُتجاهل — راجع ملاحظة القراءة
        // أولاً أعلاه).
        for (final invoiceRef in existingInvoiceRefs) {
          transaction.update(invoiceRef, {
            'customerId': 'deleted_customer',
            'customerName': 'عميل محذوف',
            'customerPhone': '',
            'customerEmail': '',
          });
        }

        // حذف جميع السجلات المرتبطة داخل نفس الـ transaction
        for (final logRef in effectiveLogRefs) {
          transaction.delete(logRef);
        }

        // ✅ إزالة العميل من قائمة أعضاء مجموعته ذرياً
        // (فقط إذا كان مستند المجموعة موجوداً — لا نفشل
        // حذف العميل إذا كانت مجموعته محذوفة بالفعل).
        // ✅ إصلاح اتساق البيانات القديمة (2026-10-11):
        // نُنفّذ arrayRemove فقط إذا كانت المجموعة
        // تملك حقل customerIds — arrayRemove على
        // حقل غائب (مجموعة قديمة) يُنشئه فارغاً
        // فيفقد deleteCustomerGroup كشف أعضائها
        // غير المُتتبَّعين (يُصبح
        // effectiveCustomerRefs فارغاً فلا تُصفَّى
        // customerGroupId عنهم). المجموعة القديمة
        // تبقى بلا الحقل ليُستعلم عن أعضائها
        // خارج المعاملة كما هو موثق.
        if (groupSnapshot != null &&
            groupSnapshot.exists &&
            (groupSnapshot.data() as Map<String, dynamic>?)
                    ?.containsKey('customerIds') ==
                true) {
          transaction.update(
            _getCustomerGroupsCollection(normalizedEmail).doc(customerGroupId),
            {
              'customerIds': FieldValue.arrayRemove([id]),
            },
          );
        }

        // حذف العميل
        transaction.delete(customerDocRef);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ===== ترحيل حقول التتبع للبيانات القديمة (إصلاح نافذة السباق) =====

  /// ✅ ملاحظة للمبرمجين المستقبليين (ذرية الترحيل —
  /// لماذا هذا الشكل ولا غيره):
  /// هذه الدالة تُغلق نافذة السباق الموثقة سابقاً
  /// في deleteCustomer للبيانات القديمة (التي
  /// أُنشئت قبل تهيئة حقول التتبع invoiceIds/
  /// logIds). كيف تعمل:
  /// 1. تستعلم عن المرتبطات (فواتير/سجلات) خارج
  ///    المعاملة — لأن Firestore SDK لا يدعم
  ///    استعلامات داخل runTransaction (قيد الـ
  ///    SDK، لا مفر منه). الاستعلام طازج (مباشرة
  ///    قبل المعاملة) لتقليص النافذة المتبقية
  ///    لأدنى حد.
  /// 2. داخل runTransaction تقرأ مستند العميل
  ///    وتدمج (union) المعرفات المستعلم عنها مع
  ///    ما هو موجود في الحقل أصلاً (لو أُنشئ
  ///    متزامناً) ثم تكتب الحقل كاملاً.
  /// لماذا الدمج آمن ذرياً: معاملات Firestore
  /// متفائلة (optimistic concurrency) — لو كُتب
  /// الحقل متزامناً (arrayUnion/set مع merge من
  /// addInvoice) بين قراءة المعاملة وكتابتها،
  /// أُعيدت المعاملة تلقائياً فأعادت القراءة
  /// والدمج فلا يُفقد أي معرف.
  /// ⚠️ هذا استثناء مقصود من القاعدة الذهبية
  /// (لا تُنشئ حقول تتبع على مستند قديم بلاها):
  /// الترحيل يُنشئ الحقل كاملاً (union) لا ناقصاً
  /// (arrayUnion) — القاعدة تمنع الإنشاء الناقص
  /// لأنه يُفقد كشف التوافق الخارجي، أما الإنشاء
  /// الكامل فيُغلق النافذة تماماً (تُقرأ القائمة
  /// من داخل معاملة الحذف بعدها).
  /// ⚠️ النافذة المتبقية (لا تُغلق دون تغيير
  /// الـ SDK): سجل يُضاف بين استعلام الترحيل
  /// وكتابة معاملته لا يُدرج (addCustomerLog لا
  /// يُنشئ الحقل لمستند بلاه) — نافذة رحلة
  /// شبكة واحدة ومصيرها مرجع يتيم واحد بدلاً
  /// من نافذة كاملة.
  /// ⚠️ الترحيل أفضل-جهد: مَن يستدعيها يلتقط
  /// الاستثناء ويُكمل بالمسار القديم (الاستعلام
  /// الخارجي + الدمج داخل معاملة الحذف) — فشل
  /// الترحيل لا يُفشل الحذف.
  Future<void> _backfillLegacyCustomerTrackingFields({
    required DocumentReference customerDocRef,
    required CollectionReference invoicesCollection,
    required CollectionReference logsCollection,
    required String customerId,
    required bool backfillInvoiceIds,
    required bool backfillLogIds,
  }) async {
    List<String> freshInvoiceIds = <String>[];
    if (backfillInvoiceIds) {
      final snapshot = await invoicesCollection
          .where('customerId', isEqualTo: customerId)
          .get();
      freshInvoiceIds = snapshot.docs.map((doc) => doc.id).toList();
    }

    List<String> freshLogIds = <String>[];
    if (backfillLogIds) {
      final snapshot = await logsCollection
          .where('targetId', isEqualTo: customerId)
          .where('targetType', isEqualTo: 'customer')
          .get();
      freshLogIds = snapshot.docs.map((doc) => doc.id).toList();
    }

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(customerDocRef);
      if (!snapshot.exists) {
        return; // حُذف العميل متزامناً — لا ترحيل
      }
      final data = snapshot.data() as Map<String, dynamic>?;
      final updates = <String, dynamic>{};
      if (backfillInvoiceIds) {
        final current = (data?['invoiceIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{};
        final merged = current.union(freshInvoiceIds.toSet()).toList();
        if (merged.length != current.length) {
          updates['invoiceIds'] = merged;
        }
      }
      if (backfillLogIds) {
        final current = (data?['logIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{};
        final merged = current.union(freshLogIds.toSet()).toList();
        if (merged.length != current.length) {
          updates['logIds'] = merged;
        }
      }
      if (updates.isNotEmpty) {
        transaction.update(customerDocRef, updates);
      }
    });
  }

  @override
  Future<Either<Failure, CustomerStatsEntity>> getCustomerStats(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final snapshot = await _getCustomersCollection(normalizedEmail).get();

      // ⚡ تحسين أداء (2026-10-12): حساب الإحصائيات مباشرة من بيانات المستند الخام
      // بدلاً من إنشاء CustomerModel كامل لكل عميل — نفس منطق الحساب
      // المطابق تمامًا لـ getCustomerStats_stream. هذا يقلل استهلاك المعالج
      // والذاكرة مع كثرة العملاء.
      var activeCustomers = 0;
      var inactiveCustomers = 0;
      var blockedCustomers = 0;
      var customersWithGroups = 0;
      var customersWithoutGroups = 0;
      var totalPurchases = 0.0;
      var netBalance = 0.0;
      var totalDebtAmount = 0.0;
      var totalCreditAmount = 0.0;
      var totalCustomers = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;

        final status = mapData['status']?.toString() ?? 'active';
        final customerGroupId = mapData['customerGroupId']?.toString();
        final purchases = _parseStatsDouble(mapData['totalPurchases']);
        final debt = _parseStatsDouble(mapData['totalDebt']);

        totalCustomers++;

        if (status == 'active') activeCustomers++;
        if (status == 'inactive') inactiveCustomers++;
        if (status == 'blocked') blockedCustomers++;
        if (customerGroupId != null && customerGroupId.isNotEmpty) {
          customersWithGroups++;
        } else {
          customersWithoutGroups++;
        }
        totalPurchases += purchases;
        // صافي الحساب = مجموع جميع totalDebt (الموجب والسالب)
        netBalance += debt;
        // إجمالي الديون المستحقة لنا (الموجب فقط - ما على العميل)
        if (debt > 0) {
          totalDebtAmount += debt;
        } else if (debt < 0) {
          // إجمالي الائتمانات المستحقة علينا (القيمة المطلقة للسالب - ما لنا على العميل)
          totalCreditAmount += debt.abs();
        }
      }

      final stats = CustomerStatsEntity(
        totalCustomers: totalCustomers,
        activeCustomers: activeCustomers,
        inactiveCustomers: inactiveCustomers,
        blockedCustomers: blockedCustomers,
        customersWithGroups: customersWithGroups,
        customersWithoutGroups: customersWithoutGroups,
        totalPurchases: totalPurchases,
        netBalance: netBalance,
        totalDebtAmount: totalDebtAmount,
        totalCreditAmount: totalCreditAmount,
      );

      return Right(stats);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<String>>> searchCustomerNames({
    required String query,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل الدخول'));
      }

      final queryLower = query.toLowerCase();

      // ⚠️ ملاحظة للمبرمجين المستقبليين (إصلاح
      // حساسية الحالة 2026-10-12): أُزيل استعلام
      // النطاق (where >= و <=) وحد النتائج لأن
      // النطاق كان حساساً لحالة الأحرف (بحث
      // "ahmed" لا يجد "Ahmed") ويطابق البداية
      // فقط بينما الفحص أدناه يطابق أي موضع
      // (contains) — فكان يستبعد نتائج صحيحة
      // قبل وصولها للفحص. البحث يجلب المستندات
      // ويصفّيها محلياً (case-insensitive) — نفس
      // نمط بحث الأسماء في صفحتي الإنشاء/التعديل
      // (getCustomers + تصفية محلية). لا تُرجع
      // استعلام النطاق هنا.
      final snapshot =
          await _getCustomersCollection(currentUser!.email!).get();

      final names =
          snapshot.docs
              .map(
                (doc) =>
                    (doc.data() as Map<String, dynamic>)['name'] as String?,
              )
              .where(
                (name) =>
                    name != null && name.toLowerCase().contains(queryLower),
              )
              .map((name) => name!)
              .toSet()
              .toList()
            ..sort();

      return Right(names);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<String>>> searchCustomerEmails({
    required String query,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل الدخول'));
      }

      final queryLower = query.toLowerCase();

      // (نفس ملاحظة searchCustomerNames: أُزيل
      // استعلام النطاق وحد النتائج — حساسية
      // الحالة)
      final snapshot =
          await _getCustomersCollection(currentUser!.email!).get();

      final emails =
          snapshot.docs
              .map(
                (doc) =>
                    (doc.data() as Map<String, dynamic>)['email'] as String?,
              )
              .where(
                (email) =>
                    email != null && email.toLowerCase().contains(queryLower),
              )
              .map((email) => email!)
              .toSet()
              .toList()
            ..sort();

      return Right(emails);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<String>>> searchCustomerPhones({
    required String query,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل الدخول'));
      }

      final queryLower = query.toLowerCase();

      // (نفس ملاحظة searchCustomerNames: أُزيل
      // استعلام النطاق وحد النتائج — حساسية
      // الحالة)
      final snapshot =
          await _getCustomersCollection(currentUser!.email!).get();

      final phones =
          snapshot.docs
              .map(
                (doc) =>
                    (doc.data() as Map<String, dynamic>)['phone'] as String?,
              )
              .where(
                (phone) =>
                    phone != null && phone.toLowerCase().contains(queryLower),
              )
              .map((phone) => phone!)
              .toSet()
              .toList()
            ..sort();

      return Right(phones);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, bool>> checkCustomerExists({
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل الدخول'));
      }

      final cleanEmail = email.trim().toLowerCase();
      final cleanPhone = _normalizePhoneForIndex(phone);
      final cleanName = name.trim().toLowerCase();

      // التحقق من التكرار بالبريد الإلكتروني باستخدام المجموعة المنفصلة
      if (cleanEmail.isNotEmpty) {
        final emailDoc = _getCustomerEmailsCollection(
          currentUser!.email!,
        ).doc(_sanitizeForDocId(cleanEmail));
        final emailSnapshot = await emailDoc.get();
        if (emailSnapshot.exists) {
          return const Right(true);
        }
      }

      // التحقق من التكرار برقم الهاتف باستخدام المجموعة المنفصلة
      if (cleanPhone.isNotEmpty) {
        final phoneDoc = _getCustomerPhonesCollection(
          currentUser!.email!,
        ).doc(_sanitizeForDocId(cleanPhone));
        final phoneSnapshot = await phoneDoc.get();
        if (phoneSnapshot.exists) {
          return const Right(true);
        }
      }

      // التحقق من التكرار بالاسم (غير ذري لكنه للقراءة فقط)
      if (cleanName.isNotEmpty &&
          (cleanEmail.isNotEmpty || cleanPhone.isNotEmpty)) {
        final collection = _getCustomersCollection(currentUser!.email!);
        final nameSnapshot = await collection
            .where('name', isEqualTo: name.trim())
            .limit(20)
            .get();

        for (final doc in nameSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final docEmail =
              (data['email'] as String?)?.trim().toLowerCase() ?? '';
          final docPhone = _normalizePhoneForIndex((data['phone'] as String?) ?? '');

          if ((cleanEmail.isNotEmpty && docEmail == cleanEmail) ||
              (cleanPhone.isNotEmpty && docPhone == cleanPhone)) {
            return const Right(true);
          }
        }
      }

      return const Right(false);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'خطأ في التحقق من التكرار: ${_readableError(e)}'),
      );
    }
  }

  /// دالة للحصول على تفاصيل التكرار
  @override
  Future<Either<Failure, Map<String, dynamic>>> checkCustomerExistsDetailed({
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل الدخول'));
      }

      final duplicates = <String>[];
      final cleanEmail = email.trim().toLowerCase();
      final cleanPhone = _normalizePhoneForIndex(phone);
      final cleanName = name.trim().toLowerCase();

      // التحقق من التكرار بالبريد الإلكتروني باستخدام المجموعة المنفصلة
      if (cleanEmail.isNotEmpty) {
        final emailDoc = _getCustomerEmailsCollection(
          currentUser!.email!,
        ).doc(_sanitizeForDocId(cleanEmail));
        final emailSnapshot = await emailDoc.get();
        if (emailSnapshot.exists) {
          duplicates.add('البريد الإلكتروني');
        }
      }

      // التحقق من التكرار برقم الهاتف باستخدام المجموعة المنفصلة
      if (cleanPhone.isNotEmpty) {
        final phoneDoc = _getCustomerPhonesCollection(
          currentUser!.email!,
        ).doc(_sanitizeForDocId(cleanPhone));
        final phoneSnapshot = await phoneDoc.get();
        if (phoneSnapshot.exists) {
          duplicates.add('رقم الهاتف');
        }
      }

      // التحقق من التكرار بالاسم (غير ذري لكنه للقراءة فقط)
      if (cleanName.isNotEmpty &&
          (cleanEmail.isNotEmpty || cleanPhone.isNotEmpty)) {
        final collection = _getCustomersCollection(currentUser!.email!);
        final nameSnapshot = await collection
            .where('name', isEqualTo: name.trim())
            .limit(20)
            .get();

        for (final doc in nameSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final docEmail =
              (data['email'] as String?)?.trim().toLowerCase() ?? '';
          final docPhone = _normalizePhoneForIndex((data['phone'] as String?) ?? '');

          if ((cleanEmail.isNotEmpty && docEmail == cleanEmail) ||
              (cleanPhone.isNotEmpty && docPhone == cleanPhone)) {
            if (!duplicates.contains('الاسم')) {
              duplicates.add('الاسم');
            }
            break;
          }
        }
      }

      return Right({
        'exists': duplicates.isNotEmpty,
        'duplicateFields': duplicates,
        'message': duplicates.isEmpty
            ? 'البيانات متاحة'
            : 'يوجد تكرار في: ${duplicates.join(', ')}',
      });
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'خطأ في التحقق من التكرار: ${_readableError(e)}'),
      );
    }
  }

  /// ⚡ تحسين الأداء (2026-10-12): التحقق من تفرد بريد عميل عبر
  /// قراءة مستند واحد من فهرس customer_emails (معرف المستند =
  /// البريد المطبّع) بدلاً من تحميل كل العملاء من السيرفر —
  /// قراءة O(1) لمستند واحد بدلاً من O(N) مستند. يُستخدم كفحص
  /// مسبق للواجهة فقط؛ الفحص الذري النهائي داخل runTransaction
  /// في addCustomer/updateCustomer يستخدم نفس الفهرس (راجع
  /// ملاحظاتهما) — فالفهرس هو مصدر الحقيقة للتكرار.
  /// excludeCustomerId يستثني العميل نفسه عند التعديل (مالك
  /// المستند هو العميل المستثنى → فريد).
  @override
  Future<Either<Failure, bool>> isCustomerEmailUnique(
    String email,
    String organizationEmail, {
    String? excludeCustomerId,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      if (cleanEmail.isEmpty) {
        return const Right(true);
      }
      final emailDoc = _getCustomerEmailsCollection(
        organizationEmail,
      ).doc(_sanitizeForDocId(cleanEmail));
      final snapshot = await emailDoc.get();
      if (!snapshot.exists) {
        return const Right(true);
      }
      final ownerId =
          (snapshot.data() as Map<String, dynamic>?)?['customerId'] as String?;
      // مالك المستند هو العميل المستثنى (نفسه عند التعديل) → فريد
      if (ownerId != null &&
          ownerId.isNotEmpty &&
          ownerId == excludeCustomerId) {
        return const Right(true);
      }
      return const Right(false);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  /// ⚡ تحسين الأداء (2026-10-12): نفس نمط isCustomerEmailUnique
  /// مطبّقاً على فهرس customer_phones (معرف المستند = الهاتف
  /// المقطّع من المسافات).
  @override
  Future<Either<Failure, bool>> isCustomerPhoneUnique(
    String phone,
    String organizationEmail, {
    String? excludeCustomerId,
  }) async {
    try {
      final cleanPhone = _normalizePhoneForIndex(phone);
      if (cleanPhone.isEmpty) {
        return const Right(true);
      }
      final phoneDoc = _getCustomerPhonesCollection(
        organizationEmail,
      ).doc(_sanitizeForDocId(cleanPhone));
      final snapshot = await phoneDoc.get();
      if (!snapshot.exists) {
        return const Right(true);
      }
      final ownerId =
          (snapshot.data() as Map<String, dynamic>?)?['customerId'] as String?;
      if (ownerId != null &&
          ownerId.isNotEmpty &&
          ownerId == excludeCustomerId) {
        return const Right(true);
      }
      return const Right(false);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ===== Customer Groups Methods =====

  @override
  Future<Either<Failure, List<CustomerGroupEntity>>> getCustomerGroups(
    String organizationEmail,
  ) async {
    try {
      final snapshot = await _getCustomerGroupsCollection(
        organizationEmail,
      ).orderBy('name').get();

      final groups = <CustomerGroupEntity>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) continue;
          final mapData = data as Map<String, dynamic>;
          // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
          if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
            mapData['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
          }
          final group = CustomerGroupModel.fromJson(mapData);
          groups.add(group);
        } on Exception catch (e) {
          // تجاهل المستندات التي فشل تحويلها مع تسجيل للتشخيص
          LoggerService.warning('CustomerRepositoryImpl: فشل تحويل مستند مجموعة عملاء (الاستعلام الثاني): $e');
        }
      }

      return Right(groups);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, CustomerGroupsPage>> getCustomerGroupsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  }) async {
    try {
      var query = _getCustomerGroupsCollection(
        organizationEmail,
      ).orderBy('name');

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      final groups = <CustomerGroupEntity>[];
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) continue;
          final mapData = data as Map<String, dynamic>;
          if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
            mapData['id'] = doc.id;
          }
          final group = CustomerGroupModel.fromJson(mapData);
          groups.add(group);
        } on Exception catch (e) {
          LoggerService.warning('CustomerRepositoryImpl: فشل تحويل مستند مجموعة عملاء (التقسيم): $e');
        }
      }

      return Right(
        CustomerGroupsPage(
          groups: groups,
          lastDocument: querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.last
              : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> createCustomerGroup(
    CustomerGroupEntity group,
  ) async {
    try {
      final model = CustomerGroupModel.fromEntity(group);
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationEmail = currentUser?.email ?? '';
      final collection = _getCustomerGroupsCollection(organizationEmail);
      final groupNamesCollection = _getCustomerGroupNamesCollection(
        organizationEmail,
      );
      final groupDoc = group.id.isEmpty
          ? collection.doc()
          : collection.doc(group.id);

      final data = model.toJson();
      data['id'] = groupDoc.id;

      // ===== ملاحظة للمبرمجين المستقبليين =====
      // هذه العملية الآن ذرية بالكامل: نستخدم مجموعة منفصلة customer_group_names
      // لمنع التكرار بالاسم. كل اسم مجموعة يكون له مستند في هذه المجموعة.
      // عندما نريد إنشاء مجموعة، نحاول إنشاء مستند في customer_group_names
      // بنفس الاسم. إذا نجح، ننشئ المجموعة. إذا فشل، هناك مجموعة بنفس الاسم.
      // هذا يلغي مشكلة race condition تماماً.
      //
      // ⚠️ لماذا نستخدم مجموعة منفصلة (customer_group_names) بدلاً من التحقق
      // داخل collection المجموعات الرئيسية؟
      // لأن التحقق داخل نفس المجموعة يخلق نافذة سباق:
      // يمكن لمجموعتين أن تتحققا من عدم وجود نفس الاسم في نفس الوقت،
      // ثم تنشئا مجموعتين بنفس الاسم. باستخدام مجموعة منفصلة حيث
      // كل اسم هو معرّف مستند (document ID)، نضمن أن إنشاء مستند
      // بنفس المعرف سيفشل تلقائياً إذا كان موجوداً.
      //
      // ✅ تحقق الذرية (للمبرمجين المستقبليين):
      //   العملية ذرية بالكامل الآن: تفرّد الاسم مُنفَّذ
      //   فعلاً عبر قراءة مستند الاسم داخل الـ transaction
      //   (أدناه) وإذا وُجد فأرينا استثناء. هذا ضروري
      //   لأن transaction.set(nameDoc, ...) يستبدل
      //   المستند الموجود بصمت دون فشل — بدون القراءة
      //   أولاً، يمكن لعمليتي إنشاء متزامنتين بنفس
      //   الاسم أن تنجحا معاً → مجموعتان بنفس الاسم.
      //   بالقراءة أولاً يصبح التحقق والإنشاء وحدة
      //   واحدة لا يمكن اختراقها.
      // ==========================================

      final normalizedName = group.name.trim().toLowerCase();

      await firestore.runTransaction((transaction) async {
        // ✅ التحقق من عدم وجود مجموعة بنفس المعرف أولاً
        final docSnapshot = await transaction.get(groupDoc);
        if (docSnapshot.exists) {
          throw Exception('اسم المجموعة موجود مسبقًا');
        }

        // ✅ التحقق من عدم وجود مجموعة بنفس الاسم عبر
        // مستند الاسم — هذا ما يُنفّذ تفرّد الاسم ذرياً
        // (transaction.set يستبدل بصمت، لذلك يجب القراءة
        // أولاً وإذا وُجد المستند فأرينا استثناء).
        final nameDoc = groupNamesCollection.doc(normalizedName);
        final nameSnapshot = await transaction.get(nameDoc);
        if (nameSnapshot.exists) {
          throw Exception('اسم المجموعة موجود مسبقًا');
        }

        // إنشاء مستند الاسم
        transaction.set(nameDoc, {
          'groupId': groupDoc.id,
          'name': group.name,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // إنشاء المجموعة
        // ✅ تهيئة قائمة الأعضاء (customerIds) فارغة — هذه
        // القائمة تُصانَع ذرياً في addCustomer و
        // addCustomerWithOpeningBalance و updateCustomer و
        // deleteCustomer، وتُقرأ داخل deleteCustomerGroup
        // لإغلاق نافذة السباق (لا يمكن استعلام العملاء
        // المرتبطين داخل runTransaction لأن Firestore لا
        // يدعم استعلامات داخل المعاملات).
        transaction.set(groupDoc, {
          ...data,
          'customerIds': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return const Right(null);
    } on Exception catch (e) {
      if (e.toString().contains('موجود مسبقًا')) {
        return const Left(ServerFailure(message: 'اسم المجموعة موجود مسبقًا'));
      }
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> updateCustomerGroup(
    CustomerGroupEntity group,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationEmail = currentUser?.email ?? '';
      final collection = _getCustomerGroupsCollection(organizationEmail);
      final groupNamesCollection = _getCustomerGroupNamesCollection(
        organizationEmail,
      );
      final groupDoc = collection.doc(group.id);
      final model = CustomerGroupModel.fromEntity(group);

      // ===== ملاحظة للمبرمجين المستقبليين (تحقق الذرية) =====
      // هذه العملية ذرية من حيث البنية باستخدام مجموعة
      // منفصلة customer_group_names (قراءات قبل كتابات
      // داخل runTransaction واحد).
      //
      // ⚠️ كيف نتحقق من عدم وجود مجموعة أخرى بنفس الاسم؟
      // نقرأ المستند في customer_group_names ونقارن groupId المخزن به
      // مع معرف المجموعة الحالية. إذا كان مختلفاً، فهناك مجموعة أخرى
      // بنفس الاسم. إذا كان نفس المعرف، فهذا هو نفس المجموعة ونسمح بالتحديث.
      //
      // ✅ تحقق الذرية (للمبرمجين المستقبليين):
      //   العملية ذرية بالكامل الآن: يُفحص مستند الاسم
      //   القديم (ملكية الاسم الحالي) ومستند الاسم
      //   الجديد (أدناه) داخل الـ transaction. فحص
      //   الاسم الجديد كان مفقوداً: بدونه، إعادة تسمية
      //   المجموعة A إلى اسم مملوك للمجموعة B تستبدل
      //   مستند اسم B بصمت → مجموعتان بنفس الاسم.
      //   الآن نقرأ مستند الاسم الجديد وإذا وُجد وملكه
      //   لمجموعة أخرى فأرينا استثناء — فيصبح
      //   التحقق والتحديث وحدة واحدة لا يمكن اختراقها.
      // ==========================================

      final normalizedName = group.name.trim().toLowerCase();

      await firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(groupDoc);
        if (!docSnapshot.exists) {
          throw Exception('المجموعة غير موجودة');
        }

        final existingData = docSnapshot.data() as Map<String, dynamic>?;
        final existingNormalizedName = existingData != null
            ? (existingData['name'] as String? ?? '').trim().toLowerCase()
            : '';

        // إذا تغير الاسم، نتحقق من عدم وجود مجموعة أخرى بنفس الاسم
        if (existingNormalizedName != normalizedName) {
          final existingNameDoc = groupNamesCollection.doc(
            existingNormalizedName,
          );
          final existingNameSnapshot = await transaction.get(existingNameDoc);
          if (existingNameSnapshot.exists &&
              (existingNameSnapshot.data()
                      as Map<String, dynamic>?)?['groupId'] !=
                  group.id) {
            throw Exception('اسم المجموعة موجود مسبقًا');
          }

          // ✅ التحقق من أن الاسم الجديد غير مأخوذ بمجموعة
          // أخرى — نقرأ مستند الاسم الجديد وإذا وُجد
          // وملكه لمجموعة أخرى فأرينا استثناء (هذا
          // الفحص كان مفقوداً وكان يسمح باستبدال مستند
          // اسم مجموعة أخرى بصمت).
          final newNameDoc = groupNamesCollection.doc(normalizedName);
          final newNameSnapshot = await transaction.get(newNameDoc);
          if (newNameSnapshot.exists &&
              (newNameSnapshot.data() as Map<String, dynamic>?)?['groupId'] !=
                  group.id) {
            throw Exception('اسم المجموعة موجود مسبقًا');
          }

          // إنشاء مستند جديد للاسم
          transaction.set(newNameDoc, {
            'groupId': group.id,
            'name': group.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // حذف المستند القديم للاسم
          transaction.delete(existingNameDoc);
        }

        transaction.update(groupDoc, {
          ...model.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return const Right(null);
    } on Exception catch (e) {
      if (e.toString().contains('موجود مسبقًا')) {
        return const Left(ServerFailure(message: 'اسم المجموعة موجود مسبقًا'));
      }
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCustomerGroup(
    String groupId,
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;
      final customersCollection = _getCustomersCollection(normalizedEmail);
      final groupDoc = _getCustomerGroupsCollection(
        normalizedEmail,
      ).doc(groupId);
      final groupNamesCollection = _getCustomerGroupNamesCollection(
        normalizedEmail,
      );

      // ===== ملاحظة للمبرمجين المستقبليين (تحقق الذرية) =====
      // حالة هذه العملية (نتيجة الإصلاح اليدوي
      // + إصلاح 2026-10-11):
      //   ✅ ذرية بالكامل لكل المجموعات — قائمة
      //      الأعضاء تُقرأ من داخل الـ transaction
      //      عبر transaction.get(groupDoc) أدناه
      //      وتُبنى المراجع من تلك اللقطة
      //      الطازجة مدمجة (union) مع ما استُعلم
      //      عنه خارجها. إذا رُبط عميل بهذه
      //      المجموعة عبر addCustomer/updateCustomer
      //      أثناء المعاملة، يُضاف إلى customerIds
      //      داخل معاملته الخاصة، فيعيد Firestore
      //      تنفيذ هذه المعاملة (retry) فتشمل
      //      العضو الجديد — لا نافذة سباق.
      //      للمجموعات القديمة بلا الحقل:
      //      يُرحَّلُه
      //      _backfillLegacyCustomerGroupTrackingFields
      //      أولاً (تُخزَّن المعرفات في المستند
      //      كاملاً) فتُقرأ من داخل معاملة
      //      الحذف — لا نافذة سباق تُذكر
      //      (راجع ملاحظة الترحيل أدناه).
      //
      // ما هو ذري فعلاً هنا:
      //   عمليات الكتابة داخل runTransaction (تحديث
      //   العملاء الأعضاء، حذف مستند الاسم من
      //   group_names، حذف المجموعة) تنجح كلها أو
      //   تفشل كلها معاً — لا توجد حالة وسيطة.
      //
      // ⚠️ النافذة المتبقية الضئيلة (قيد الـ SDK):
      //   الترحيل يستعلم خارج المعاملة (استعلام
      //   طازج مباشرة قبلها) فتبقى نافذة رحلة
      //   شبكة واحدة: عميل يُربط بالمجموعة
      //   أثناءها ولا يُنشئ مساره الحقل لمجموعة
      //   بلاه (addCustomer يحفظ الحقل إن وُجد)
      //   — مصيره مرجع يتيم واحد بدلاً من نافذة
      //   كاملة. أفضل ما يمكن تحقيقه دون تغيير
      //   الـ SDK.
      //
      // ✅ قاعدة ذهبية (للمبرمجين المستقبليين):
      //   حقل customerIds في مستند المجموعة يُصانَع
      //   ذرياً في addCustomer و addCustomerWithOpeningBalance
      //   و updateCustomer و deleteCustomer — لا تحذفه
      //   ولا تستبدله خارج تلك المعاملات، ولا تُزل
      //   الترحيل أعلاه، وإلا انفتحت نافذة
      //   السباق من جديد.
      //
      // ⚠️ حدود إضافية يجب معرفتها:
      //   - الـ transaction محدود بـ 500 عملية كتابة:
      //     مجموعة لديها عدد كبير من الأعضاء قد تفشل
      //     كامل العملية.
      // ==========================================

      // قراءة مستند المجموعة أولاً (خارج المعاملة) للتحقق
      // من الوجود وللكشف عن المجموعات القديمة التي لا
      // تملك حقل customerIds — هذه القراءة تُستخدم فقط
      // لهذا الكشف؛ الأعضاء يُقرأون من داخل المعاملة
      // أدناه من اللقطة الطازجة وليس من هذه القراءة.
      final groupPreSnapshot = await groupDoc.get();
      if (!groupPreSnapshot.exists) {
        return const Left(ServerFailure(message: 'المجموعة غير موجودة'));
      }

      final groupPreData = groupPreSnapshot.data() as Map<String, dynamic>?;
      final legacyHasCustomerIds =
          groupPreData?.containsKey('customerIds') ?? false;

      // التوافق مع المجموعات القديمة التي لا تملك
      // customerIds — نجمع المعرفات (لا المراجع)
      // لتُدمج مع customerIds المخزنة داخل المعاملة
      // أدناه (إصلاح نافذة السباق 2026-10-11).
      List<String> legacyCustomerIds = [];
      if (!legacyHasCustomerIds) {
        final linkedCustomersSnapshot = await customersCollection
            .where('customerGroupId', isEqualTo: groupId)
            .get();
        legacyCustomerIds = linkedCustomersSnapshot.docs
            .map((doc) => doc.id)
            .toList();
      }

      // ✅ ترحيل حقل customerIds للبيانات القديمة
      // (إصلاح نافذة السباق 2026-10-11 — نفس سبب
      // ترحيل العميل في deleteCustomer: نخزّن معرفات
      // الأعضاء في مستند المجموعة نفسه كاملاً قبل
      // معاملة الحذف فتُقرأ من داخلها وتُغلق نافذة
      // السباق. أفضل-جهد: فشله لا يُفشل الحذف —
      // يُكمل بالمسار القديم + الدمج).
      if (!legacyHasCustomerIds) {
        try {
          await _backfillLegacyCustomerGroupTrackingFields(
            groupDocRef: groupDoc,
            customersCollection: customersCollection,
            groupId: groupId,
          );
        } on Exception catch (e) {
          // الترحيل أفضل-جهد — فشله لا يُفشل الحذف.
          LoggerService.warning('CustomerRepositoryImpl.deleteCustomerGroup: فشل الترحيل الأفضل-جهد: $e');
        }
      }

      await firestoreInstance.runTransaction((transaction) async {
        // ✅ قراءة مستند المجموعة داخل الـ transaction للحصول
        // على لقطة طازجة من customerIds — لأن القائمة مخزنة
        // في نفس المستند الذي نحذفه، فلا يمكن أن تتغير بين
        // القراءة والكتابة داخل المعاملة. هذا يغلق نافذة
        // السباق لجميع المجموعات التي تملك الحقل.
        final groupSnapshot = await transaction.get(groupDoc);
        if (!groupSnapshot.exists) {
          throw Exception('المجموعة غير موجودة');
        }

        final groupData = groupSnapshot.data() as Map<String, dynamic>?;
        final customerIds = (groupData?['customerIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();

        // ✅ دمج المعرفات المخزنة مع المعرفات
        // المستعلم عنها خارج المعاملة (نفس
        // إصلاح deleteCustomer: لو أُنشئ حقل
        // customerIds متزامناً بين الاستعلام
        // الخارجي وقراءة هذه المعاملة، كانت
        // القائمة المخزنة الناقصة تُظلِّل
        // الأعضاء المستعلم عنهم فتبقى عملاء
        // تشير لمجموعة محذوفة — بالدمج تُحدَّث
        // المرجعتان معاً. للغير قدامى القائمة
        // المستعلم عنها فارغة فالدمج = المخزنة
        // فقط كالسابق).
        final effectiveCustomerIds = <String>{
          ...?customerIds,
          ...legacyCustomerIds,
        }.toList();
        final effectiveCustomerRefs = effectiveCustomerIds
            .map((customerId) => customersCollection.doc(customerId))
            .toList();

        // ✅ إصلاح ذرية (من التحقق اليدوي 2026-10-08):
        // قراءة جميع مراجع العملاء الأعضاء داخل المعاملة
        // (قبل أي كتابة — قاعدة Firestore الإلزامية: كل
        // القراءات قبل كل الكتابات) والتحقق من وجود كل
        // عميل. السبب: transaction.update() تشترط وجود
        // المستند، فإذا كان أحد معرفات الأعضاء المخزنة
        // (customerIds) يشير إلى عميل حُذف مسبقاً عبر
        // مسار لا يصانِع القائمة، كانت المعاملة تفشل
        // كاملة ويُرفض حذف المجموعة. بالقراءة أولاً
        // نُحدِّث العملاء الموجودين فقط ونُتجاهل المراجع
        // المعلقة — سلوك مرن مع الحفاظ على الذرية
        // all-or-nothing (إما تُحدَّث العملاء وتُحذف
        // المجموعة معاً، أو يفشل كل شيء معاً). ⚠️ لا
        // تُصلح هذا بـ transaction.set() مع merge لأن
        // ذلك يُنشئ مستند عميل وهمياً (phantom).
        // ⚠️ ملاحظة حد المعاملة: القراءات تُحتسب ضمن
        // حد 500 عملية للمعاملة، فإذا كانت المجموعة
        // تملك عدداً كبيراً جداً من الأعضاء قد تفشل
        // المعاملة بسبب الحد — وهذا أفضل من فشل صامت
        // يترك أعضاء مرتبطين بمجموعة محذوفة.
        final existingCustomerRefs = <DocumentReference>[];
        for (final customerRef in effectiveCustomerRefs) {
          final customerSnapshot = await transaction.get(customerRef);
          if (customerSnapshot.exists) {
            existingCustomerRefs.add(customerRef);
          }
        }

        // تحديث العملاء الأعضاء الموجودين فقط داخل نفس
        // الـ transaction (customerIds تُصانَع ذرياً مع
        // حذف العميل في deleteCustomer — arrayRemove من
        // customerIds وحذف مستند العميل في معاملة واحدة
        // — فلا توجد معرفات معلقة في القائمة عادةً).
        // المراجع المعلقة على عملاء محذوفين مسبقاً
        // تُتجاهل — راجع ملاحظة القراءة أولاً أعلاه.
        for (final customerRef in existingCustomerRefs) {
          transaction.update(customerRef, {
            'customerGroupId': null,
            'customerGroupName': null,
          });
        }

        // حذف المستند من مجموعة group_names
        final groupName =
            (groupSnapshot.data() as Map<String, dynamic>?)?['name'] as String?;
        if (groupName != null) {
          final normalizedName = groupName.trim().toLowerCase();
          final nameDoc = groupNamesCollection.doc(normalizedName);
          transaction.delete(nameDoc);
        }

        // حذف المجموعة
        transaction.delete(groupDoc);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  /// ✅ ملاحظة للمبرمجين المستقبليين: نفس نمط
  /// _backfillLegacyCustomerTrackingFields (راجع
  /// ملاحظتها التفصيلية) مطبّقاً على حقل
  /// customerIds في مستندات المجموعات القديمة
  /// بلا الحقل — تُخزَّن معرفات الأعضاء كاملاً
  /// (union) قبل معاملة حذف المجموعة فتُقرأ
  /// من داخلها. النافذة المتبقية: عميل يُربط
  /// بالمجموعة بين استعلام الترحيل وكتابة
  /// معاملته (addCustomer لا يُنشئ الحقل
  /// لمجموعة بلاه) — رحلة شبكة واحدة.
  /// أفضل-جهد: فشلها لا يُفشل حذف المجموعة.
  Future<void> _backfillLegacyCustomerGroupTrackingFields({
    required DocumentReference groupDocRef,
    required CollectionReference customersCollection,
    required String groupId,
  }) async {
    final snapshot = await customersCollection
        .where('customerGroupId', isEqualTo: groupId)
        .get();
    final freshCustomerIds = snapshot.docs.map((doc) => doc.id).toList();

    await firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupDocRef);
      if (!groupSnapshot.exists) {
        return; // حُذفت المجموعة متزامناً — لا ترحيل
      }
      final data = groupSnapshot.data() as Map<String, dynamic>?;
      final current = (data?['customerIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};
      final merged = current.union(freshCustomerIds.toSet()).toList();
      if (merged.length != current.length) {
        transaction.update(groupDocRef, {'customerIds': merged});
      }
    });
  }

  @override
  Future<Either<Failure, List<String>>> searchCustomerGroupNames({
    required String query,
  }) async {
    try {
      // الحصول على المستخدم الحالي للبحث في مؤسسته فقط
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل الدخول'));
      }

      // البحث في مجموعات عملاء المؤسسة الحالية فقط
      final snapshot = await _getCustomerGroupsCollection(
        currentUser!.email!,
      ).get();

      final names = <String>[];
      // ⚡ تحسين أداء (2026-10-12): حساب query.toLowerCase()
      // مرة واحدة قبل الحلقة بدلاً من تكراره لكل مستند
      final queryLower = query.toLowerCase();
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final name = data['name'] as String?;
          if (name != null && name.toLowerCase().contains(queryLower)) {
            if (!names.contains(name)) {
              names.add(name);
            }
          }
        } on Exception catch (e) {
          // تجاهل المستندات التي فشل تحويلها مع تسجيل للتشخيص
          LoggerService.warning('CustomerRepositoryImpl: فشل استخراج أسماء العملاء: $e');
        }
      }

      return Right(names);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ===== Customer Logs Methods =====

  String? _getCurrentOrganizationId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;
    // ✅ إصلاح ذرية/اتساق (2026-10-08): معرف المؤسسة
    // هو البريد المطبّع — نفس قاعدة
    // EmailNormalizationService.getOrganizationId ونفس
    // تنفيذ _getCurrentOrganizationId في
    // invoice_repository_impl. سجلات العملاء تُخزن
    // تحت المسار المطبّع (addCustomerLog و
    // getCustomerLogs يطبّعان)، فبدون التطبيع هنا
    // كان deleteCustomerLog و clearCustomerLogs يقرآن
    // من مسار خاطئ (مثال: Gmail بنقاط أو +) فلا
    // يجدان السجلات — لا تُحذف ولا تُحدَّث logIds
    // وتبقى مراجع معلقة. لا تُرجع هذا التطبيع أبداً.
    return _emailService.normalize(user!.email!);
  }

  @override
  Future<Either<Failure, List<CustomerLogEntity>>> getCustomerLogs({
    required String organizationEmail,
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // ⚡ تحسين/إصلاح (2026-10-12): حساب شرط البحث
      // ونصه المطبّع مرة واحدة قبل بناء الـ query
      // (searchQuery ثابت) — الحد يُطبَّق في الـ query
      // فقط عندما لا يوجد بحث (بحث contains غير
      // مدعوم في استعلامات Firestore فيُطبَّق في
      // الذاكرة). عند وجود بحث لا يُطبَّق الحد في
      // الـ query (لو طُبِّق تُفقد سجلات مطابقة بعد
      // الحد لأن الفلترة تُجرى في الذاكرة) — يُحمَّل
      // كل البيانات ويُصفَّى في الذاكرة ثم يُحدَّد
      // الحد بعد الفلترة.
      final hasSearch = searchQuery != null && searchQuery.isNotEmpty;
      final searchQueryLower = searchQuery?.toLowerCase() ?? '';

      Query query = firestore
          .collection(normalizedEmail)
          .doc('customers')
          .collection('logs');

      // تطبيق الفلاتر
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (actionFilter != null && actionFilter != 'all') {
        query = query.where('actionType', isEqualTo: actionFilter);
      }

      // فلتر التاريخ
      if (dateFilter != null && dateFilter != 'all') {
        final now = DateTime.now();
        DateTime filterDate;

        switch (dateFilter) {
          case 'today':
            filterDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            filterDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            filterDate = now.subtract(const Duration(days: 30));
            break;
          default:
            filterDate = DateTime(2000);
        }

        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(filterDate),
        );
      }

      // فلتر التاريخ المخصص
      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(endOfDay),
        );
      }

      // تطبيق الحد في الـ query فقط عندما لا يوجد
      // بحث (عنده لا توجد فلترة في الذاكرة فالحد
      // آمن — نفس النتيجة مع تحميل مستندات أقل).
      // عند وجود بحث يُطبَّق الحد في الذاكرة بعد
      // الفلترة (أدناه).
      if (limit != null && !hasSearch) {
        query = query.limit(limit);
      }

      // ترتيب النتائج
      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();
      final logs = <CustomerLogEntity>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final log = CustomerLogModel.fromJson({
          'id': doc.id,
          ...?data,
        }).toEntity();

        // تطبيق البحث النصي
        if (hasSearch) {
          final matchesSearch =
              (log.userName?.toLowerCase().contains(searchQueryLower) ??
                  false) ||
              (log.userEmail?.toLowerCase().contains(searchQueryLower) ??
                  false) ||
              (log.actionType.toLowerCase().contains(searchQueryLower)) ||
              (log.details?.toLowerCase().contains(searchQueryLower) ?? false);

          if (matchesSearch) {
            logs.add(log);
          }
        } else {
          logs.add(log);
        }

        // ⚡ تطبيق الحد في الذاكرة عند وجود بحث (الحد
        // لم يُطبَّق في الـ query في هذه الحالة — راجع
        // الملاحظة أعلاه)
        if (hasSearch && limit != null && logs.length >= limit) {
          break;
        }
      }

      return Right(logs);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Stream<Either<Failure, List<CustomerLogEntity>>> getCustomerLogsStream({
    required String organizationEmail,
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // ⚡ تحسين/إصلاح (2026-10-12): حساب شرط البحث
      // ونصه المطبّع مرة واحدة قبل بناء الـ query
      // (searchQuery ثابت) — الحد يُطبَّق في الـ query
      // فقط عندما لا يوجد بحث (بحث contains غير
      // مدعوم في استعلامات Firestore فيُطبَّق في
      // الذاكرة). عند وجود بحث لا يُطبَّق الحد في
      // الـ query (لو طُبِّق تُفقد سجلات مطابقة بعد
      // الحد لأن الفلترة تُجرى في الذاكرة) — يُحمَّل
      // كل البيانات ويُصفَّى في الذاكرة ثم يُحدَّد
      // الحد بعد الفلترة.
      final hasSearch = searchQuery != null && searchQuery.isNotEmpty;
      final searchQueryLower = searchQuery?.toLowerCase() ?? '';

      Query query = firestore
          .collection(normalizedEmail)
          .doc('customers')
          .collection('logs');

      // تطبيق الفلاتر (نفس فلاتر getCustomerLogs)
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (actionFilter != null && actionFilter != 'all') {
        query = query.where('actionType', isEqualTo: actionFilter);
      }

      // فلتر التاريخ
      if (dateFilter != null && dateFilter != 'all') {
        final now = DateTime.now();
        DateTime filterDate;

        switch (dateFilter) {
          case 'today':
            filterDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            filterDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            filterDate = now.subtract(const Duration(days: 30));
            break;
          default:
            filterDate = DateTime(2000);
        }

        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(filterDate),
        );
      }

      // فلتر التاريخ المخصص
      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(endOfDay),
        );
      }

      // تطبيق الحد في الـ query فقط عندما لا يوجد
      // بحث (عنده لا توجد فلترة في الذاكرة فالحد
      // آمن — نفس النتيجة مع تحميل مستندات أقل).
      // عند وجود بحث يُطبَّق الحد في الذاكرة بعد
      // الفلترة (أدناه).
      if (limit != null && !hasSearch) {
        query = query.limit(limit);
      }

      // ترتيب النتائج
      query = query.orderBy('timestamp', descending: true);

      // ✅ أداء (2026-10-12): كاش تدريجي
      // خاص بهذا الستريم فقط يعالج
      // docChanges بدلاً من إعادة تحليل
      // كل السجلات مع كل لقطة — سجلات
      // العملاء تنمو بلا حدود فكان
      // إعادة بناء كل CustomerLogEntity
      // عند كل عملية جديدة هو الهدر
      // الأكبر هنا. يُستخدم فقط عندما
      // يكون الاستعلام غير محدود (عند
      // وجود بحث لا يُطبَّق الحد في
      // الـ query — راجع الملاحظة أعلاه —
      // أو عند غياب الحد) لأن نافذة
      // الحد المحدودة تتحرك وقد لا
      // يُصدر المستند الخارج تغييراً
      // من نوع removed بشكل موثوق.
      final streamCache = <String, CustomerLogEntity>{};
      const int maxStreamCacheSize = 1000;

      void evictCacheIfNeeded() {
        while (streamCache.length > maxStreamCacheSize) {
          streamCache.remove(streamCache.keys.first);
        }
      }

      return query
          .snapshots()
          .map((snapshot) {
            try {
              if (hasSearch || limit == null) {
                for (final change in snapshot.docChanges) {
                  final doc = change.doc;
                  if (change.type == DocumentChangeType.removed) {
                    streamCache.remove(doc.id);
                    continue;
                  }
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) {
                    streamCache.remove(doc.id);
                    continue;
                  }
                  try {
                    streamCache[doc.id] = CustomerLogModel.fromJson({
                      'id': doc.id,
                      ...data,
                    }).toEntity();
                  } on Exception catch (e) {
                    streamCache.remove(doc.id);
                    LoggerService.warning('CustomerRepositoryImpl: فشل تحويل مستند إلى كيان للكاش (الستريم): $e');
                  }
                }
                evictCacheIfNeeded();

                // الحفاظ على ترتيب الاستعلام
                // (timestamp تنازلي) عبر المرور
                // على مستندات اللقطة مرتبة
                // وأخذ الكيان المحلل من
                // الكاش — أدق من إعادة
                // الترتيب في الذاكرة لأن
                // ترتيب Firestore الحقيقي
                // (بما في ذلك كسر التعادل)
                // يُحفظ كما هو
                var logs = <CustomerLogEntity>[];
                for (final doc in snapshot.docs) {
                  final cachedLog = streamCache[doc.id];
                  if (cachedLog != null) {
                    logs.add(cachedLog);
                  }
                }

                // تطبيق البحث النصي في الذاكرة
                if (hasSearch) {
                  logs = logs
                      .where(
                        (log) =>
                            (log.userName
                                    ?.toLowerCase()
                                    .contains(searchQueryLower) ??
                                false) ||
                            (log.userEmail
                                    ?.toLowerCase()
                                    .contains(searchQueryLower) ??
                                false) ||
                            (log.actionType
                                .toLowerCase()
                                .contains(searchQueryLower)) ||
                            (log.details
                                    ?.toLowerCase()
                                    .contains(searchQueryLower) ??
                                false),
                      )
                      .toList();
                }

                // ⚡ تطبيق الحد في الذاكرة عند
                // وجود بحث (الحد لم يُطبَّق
                // في الـ query في هذه الحالة —
                // راجع الملاحظة أعلاه)
                if (hasSearch && limit != null && logs.length > limit) {
                  logs = logs.sublist(0, limit);
                }

                return Right<Failure, List<CustomerLogEntity>>(logs);
              }

              // الستريم المحدود بلا بحث: تحليل
              // كامل (السلوك الأصلي — الحد
              // مُطبَّق في الـ query)
              final logs = <CustomerLogEntity>[];

              for (final doc in snapshot.docs) {
                final data = doc.data() as Map<String, dynamic>?;
                final log = CustomerLogModel.fromJson({
                  'id': doc.id,
                  ...?data,
                }).toEntity();

                logs.add(log);
              }

              return Right<Failure, List<CustomerLogEntity>>(logs);
            } on Exception catch (e) {
              return Left<Failure, List<CustomerLogEntity>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, List<CustomerLogEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Future<Either<Failure, CustomerLogEntity>> addCustomerLog({
    required String organizationEmail,
    required String userId,
    required String actionType,
    String? userName,
    String? userEmail,
    String? details,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
    Map<String, dynamic>? deviceInfo,
    bool isSuccess = true,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // استخدام المستخدم الحالي إذا لم يتم تحديد معرف المستخدم
      final currentUser = FirebaseAuth.instance.currentUser;
      final actualUserId = userId == 'current_user' && currentUser != null
          ? currentUser.uid
          : userId;
      final actualUserName = userName ?? currentUser?.displayName;
      final actualUserEmail = userEmail ?? currentUser?.email;
      final logData = {
        'userId': actualUserId,
        'userName': actualUserName,
        'userEmail': actualUserEmail,
        'actionType': actionType,
        'timestamp': FieldValue.serverTimestamp(),
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

      // ===== ملاحظة للمبرمجين المستقبليين =====
      // لماذا تم جعل addCustomerLog ذرية بالكامل داخل runTransaction؟
      // لأن هذه العملية تتكون من جزئين:
      // 1. إنشاء مستند السجل.
      // 2. تحديث قائمة السجلات (logIds) في مستند العميل.
      // إذا لم نجعلهما داخل نفس runTransaction، يمكن أن يحدث:
      // - ينشأ السجل بنجاح.
      // - يفشل تحديث logIds لسبب ما (مثل انقطاع الشبكة).
      // النتيجة: سجل موجود في قاعدة البيانات لكنه غير مدرج في قائمة العميل.
      // هذا يسبب تناقض في البيانات عند عرض سجلات العميل لاحقاً.
      // بالتحقق داخل runTransaction، نضمن أن الإنشاء والتحديث يتمان كوحدة واحدة.
      // ==========================================

      // نستخدم معرف يدوي لضمان اتساقه داخل الـ transaction
      final docRef = firestore
          .collection(normalizedEmail)
          .doc('customers')
          .collection('logs')
          .doc();

      await firestore.runTransaction((transaction) async {
        // ✅ قراءة بيانات العميل قبل أي عملية كتابة لضمان الامتثال مع Firestore
        // (يجب أن تكون جميع القراءات قبل جميع العمليات الكتابية في المعاملة)
        DocumentReference? customerDocRef;
        DocumentSnapshot? customerSnapshot;
        if (targetType == 'customer' &&
            targetId != null &&
            targetId.isNotEmpty) {
          customerDocRef = _getCustomersCollection(
            normalizedEmail,
          ).doc(targetId);
          customerSnapshot = await transaction.get(customerDocRef);
        }

        final logDataWithId = {...logData, 'id': docRef.id};

        transaction.set(docRef, logDataWithId);

        // ✅ تحديث قائمة السجلات في مستند العميل ذرياً باستخدام القراءة المسبقة
        // ✅ إصلاح اتساق البيانات القديمة (2026-10-11، نفس
        // فئة إصلاح deleteCustomerLog أعلاه): arrayUnion
        // على عميل قديم بلا حقل logIds يُنشئ الحقل بقائمة
        // ناقصة (معرف السجل الجديد فقط دون سجلاته القديمة
        // غير المُتتبَّعة) فيفقد deleteCustomer كشفه لسجلاته
        // (يُصبح effectiveLogRefs ناقصاً فلا تُحذف سجلاته
        // القديمة المرتبطة فتبقى تشير لعميل محذوف). نُنفّذه
        // فقط إذا كان العميل يملك الحقل أصلاً — العميل
        // القديم يبقى بلا الحقل ليُستعلم عن سجلاته خارج
        // المعاملة كما هو موثق (السجل يُنشأ في كل الأحوال).
        if (customerDocRef != null &&
            customerSnapshot != null &&
            customerSnapshot.exists &&
            (customerSnapshot.data() as Map<String, dynamic>?)
                    ?.containsKey('logIds') ==
                true) {
          transaction.update(customerDocRef, {
            'logIds': FieldValue.arrayUnion([docRef.id]),
          });
        }
      });

      final snapshot = await docRef.get();
      // ✅ ملاحظة للمبرمجين المستقبليين (إصلاح
      // 2026-10-11): لا تُرجع snapshot.data()! هنا
      // أبداً — لو حُذف السجل متزامناً (deleteCustomerLog)
      // بين التزام المعاملة وهذه القراءة، ترمي عملية
      // النفي (!) Errorاً لا يلتقطه on Exception catch
      // (Error و Exception سلسلتان منفصلتان في Dart)
      // فيصبح خطأ غير معالج. الفحص الصريح يُرجع فشلاً
      // ضمن عقد Either بدلاً من خطأ غير ملتقط.
      final snapshotData = snapshot.data();
      if (snapshotData == null) {
        return Left(
          ServerFailure(message: 'فشل قراءة سجل التدقيق بعد إنشائه'),
        );
      }
      final log = CustomerLogModel.fromJson({
        'id': docRef.id,
        ...snapshotData,
      }).toEntity();

      return Right(log);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCustomerLog(String logId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // ===== ملاحظة للمبرمجين المستقبليين =====
      // لماذا تم جعل deleteCustomerLog ذرية بالكامل داخل
      // runTransaction؟ نفس سبب addCustomerLog (راجع
      // ملاحظتها): العملية جزئان (حذف مستند السجل +
      // تحديث logIds في مستند العميل) — إذا فُصلا
      // وفشل الثاني بقي السجل محذوفاً لكنه مدرج في
      // logIds (مرجع معلق يسبب خطأ عند عرض السجل
      // لاحقاً). بالتحقق داخل runTransaction يتمان
      // كوحدة واحدة.
      // ==========================================

      await firestore.runTransaction((transaction) async {
        final logDocRef = firestore
            .collection(organizationId)
            .doc('customers')
            .collection('logs')
            .doc(logId);

        // قراءة السجل داخل الـ transaction للحصول على targetId و targetType
        final logDoc = await transaction.get(logDocRef);
        final logData = logDoc.data();
        final targetId = logData?['targetId'] as String?;
        final targetType = logData?['targetType'] as String?;

        // تحديث قائمة السجلات في مستند العميل ذرياً
        // ✅ إصلاح اتساق البيانات القديمة (2026-10-11):
        // نُنفّذ arrayRemove فقط إذا كان مستند
        // العميل يملك حقل logIds — arrayRemove على
        // حقل غائب (عميل قديم) يُنشئه فارغاً
        // فيفقد deleteCustomer كشفه لسجلاته
        // غير المُتتبَّعة (يُصبح effectiveLogRefs
        // فارغاً فلا تُحذف سجلاته المرتبطة).
        // العميل القديم يبقى بلا الحقل ليُستعلم
        // عن سجلاته خارج المعاملة كما هو موثق.
        if (targetType == 'customer' &&
            targetId != null &&
            targetId.isNotEmpty) {
          final customerDocRef = _getCustomersCollection(
            organizationId,
          ).doc(targetId);
          final customerSnapshot = await transaction.get(customerDocRef);
          if (customerSnapshot.exists &&
              (customerSnapshot.data() as Map<String, dynamic>?)
                      ?.containsKey('logIds') ==
                  true) {
            transaction.update(customerDocRef, {
              'logIds': FieldValue.arrayRemove([logId]),
            });
          }
        }

        // حذف السجل
        transaction.delete(logDocRef);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> clearCustomerLogs({
    String? userId,
    DateTime? beforeDate,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // ===== ملاحظة للمبرمجين المستقبليين (تحقق الذرية) =====
      // حالة هذه العملية (نتيجة الإصلاح اليدوي):
      //   ✅ ذرية لكل عميل داخل runTransaction واحد:
      //      حذف سجلات العميل + تحديث logIds يتمان
      //      في نفس المعاملة — ينجحان أو يفشلان
      //      معاً. تُقرأ logIds من داخل المعاملة
      //      (لقطة طازجة) وتُصفّى ثم تُكتب — لا
      //      توجد قراءة-تعديل-كتابة غير محمية،
      //      فإذا أُضيف سجل جديد للعميل عبر
      //      addCustomerLog (arrayUnion) أثناء
      //      المعاملة، يُحفظ معرفه (لا تحديث
      //      مفقود — lost update).
      //
      // ما هو ذري فعلاً هنا:
      //   - كل معاملة عميل: حذف دفعة سجلات العميل
      //     + تحديث logIds — وحدة ذرية واحدة.
      //   - دفعات WriteBatch للسجلات غير المرتبطة
      //     بعملاء (لا تملك logIds تُحدَّث).
      //
      // ⚠️ لماذا تبقى معاملات متعددة (وليست معاملة
      //   واحدة)؟
      //   لأن الـ transaction محدود بـ 500 عملية
      //   كتابة. إذا كان لديك أكثر من ذلك من السجلات،
      //   نقسم إلى دفعات. التعطل بين دفعات العملاء
      //   يترك حالة متسقة: كل عميل إما نُظّف كاملاً
      //   (سجلات محذوفة + logIds محدّثة) أو لم يُمس
      //   بعد — وإعادة المحاولة تُكمل ما تبقى لأن
      //   حذف مستند غير موجود عملية صامتة ناجحة
      //   وتصفية logIds لمعرف محذوف مسبقاً لا تغيّر
      //   شيئاً (العملية idempotent).
      //
      // ⚠️ تنبيه هام: السجلات المرتبطة بالعملاء لم
      //   تعد تُحذف عبر WriteBatch منفصل — بل داخل
      //   معاملة كل عميل. لا تفصل الحذف عن تحديث
      //   logIds في دفعات منفصلة مرة أخرى، وإلا
      //   عادت المراجع المعلقة (سجلات محذوفة لا تزال
      //   مدرجة في logIds) عند التعطل بين الدفعتين.
      // ==========================================

      Query query = firestore
          .collection(organizationId)
          .doc('customers')
          .collection('logs');

      // فلتر المستخدم
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      // فلتر التاريخ
      if (beforeDate != null) {
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(beforeDate),
        );
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      // ✅ جمع معرفات السجلات المرتبطة بالعملاء لحذفها
      // وتحديث logIds داخل معاملات العملاء أدناه
      final customerLogIdsToRemove = <String, List<String>>{};
      // ✅ السجلات غير المرتبطة بعميل (لا تملك logIds
      // تُحدَّث) تُحذف بدفعات WriteBatch مباشرة
      final unlinkedLogRefs = <DocumentReference>[];
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final targetType = data?['targetType'] as String?;
        final targetId = data?['targetId'] as String?;
        final isLinkedToCustomer =
            targetType == 'customer' && targetId != null && targetId.isNotEmpty;
        if (isLinkedToCustomer) {
          customerLogIdsToRemove.putIfAbsent(targetId, () => []).add(doc.id);
        } else {
          unlinkedLogRefs.add(doc.reference);
        }
      }

      // حذف السجلات غير المرتبطة بالعملاء بدفعات
      // WriteBatch (كل دفعة ذرية — لا تملك logIds
      // في مستندات عملاء تُحدَّث).
      const batchSize = 500;
      for (var i = 0; i < unlinkedLogRefs.length; i += batchSize) {
        final batch = firestore.batch();
        final batchRefs = unlinkedLogRefs.skip(i).take(batchSize).toList();
        for (final ref in batchRefs) {
          batch.delete(ref);
        }
        await batch.commit();
      }

      // ✅ حذف سجلات كل عميل + تحديث logIds ذرياً داخل
      // runTransaction واحد لكل عميل: تُقرأ logIds من
      // داخل المعاملة (لقطة طازجة) وتُصفّى من معرفات
      // السجلات المحذوفة ثم تُكتب — لا تحديث مفقود.
      // وحذف السجلات وتحديث logIds في نفس المعاملة
      // يعني أنهما ينجحان أو يفشلان معاً — لا مراجع
      // معلقة عند تعطل التطبيق بينهما.
      //
      // ⚠️ لماذا 499 سجلاً لكل دفعة داخل المعاملة؟
      // لأن الـ transaction محدود بـ 500 عملية كتابة:
      // 499 حذف سجل + 1 تحديث logIds = 500.
      const customerLogChunkSize = 499;
      final logsCollection = firestore
          .collection(organizationId)
          .doc('customers')
          .collection('logs');

      for (final entry in customerLogIdsToRemove.entries) {
        final customerId = entry.key;
        final logIdsToRemove = entry.value;
        final customerDocRef = _getCustomersCollection(
          organizationId,
        ).doc(customerId);

        for (var i = 0; i < logIdsToRemove.length; i += customerLogChunkSize) {
          final chunk = logIdsToRemove
              .skip(i)
              .take(customerLogChunkSize)
              .toList();
          final chunkSet = chunk.toSet();

          await firestore.runTransaction((transaction) async {
            // ✅ قراءة مستند العميل داخل المعاملة (قبل
            // أي كتابة — قاعدة Firestore الإلزامية)
            // للحصول على logIds الطازجة
            final customerSnapshot = await transaction.get(customerDocRef);

            // ✅ إصلاح اتساق البيانات القديمة
            // (2026-10-11): نكتب logIds فقط إذا
            // كان العميل يملك الحقل أصلاً — العميل
            // القديم بلا الحقل لا نُنشئ له قائمة
            // فارغة (نفس سبب إصلاح updateCustomer:
            // القائمة الفارغة تُفقد deleteCustomer
            // كشفه لسجلاته غير المُتتبَّعة فتُصبح
            // effectiveLogRefs فارغة فلا تُحذف).
            // سجلات هذا العميل المرتبطة تُحذف
            // أدناه داخل هذه المعاملة، وبقاء
            // المستند بلا الحقل يبقي كشف
            // deleteCustomer له صحيحاً.
            final currentLogIdsRaw =
                (customerSnapshot.data() as Map<String, dynamic>?)?['logIds']
                    as List<dynamic>?;
            if (customerSnapshot.exists && currentLogIdsRaw != null) {
              final updatedLogIds = currentLogIdsRaw
                  .where((id) => !chunkSet.contains(id.toString()))
                  .map((id) => id.toString())
                  .toList();
              transaction.update(customerDocRef, {'logIds': updatedLogIds});
            }

            // حذف سجلات هذا العميل داخل نفس المعاملة
            for (final logId in chunk) {
              transaction.delete(logsCollection.doc(logId));
            }
          });
        }
      }

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, bool>> isCustomerGroupValid(
    String groupId,
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      if (groupId.isEmpty) {
        return const Right(false); // معرف المجموعة فارغ
      }

      // التحقق من أن المستخدم لديه حق الوصول إلى هذه المنظمة
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.email == null ||
          currentUser!.email != normalizedEmail) {
        return const Left(
          ServerFailure(message: 'لا تملك صلاحية الوصول إلى هذه المنظمة'),
        );
      }

      // ⚡ تحسين أداء (2026-10-12): قراءة مستند المجموعة
      // مباشرة بمعرفه بدلاً من استعلام where('id', ...)
      // — قراءة O(1) لمستند واحد بدلاً من مسح فهرس
      // المجموعة. آمن سلوكياً لأن معرف المستند هو
      // نفسه حقل id (createCustomerGroup يضبط
      // data['id'] = groupDoc.id دائماً ولا يوجد
      // مسار كتابة آخر يغير الحقل) — نفس النتيجة
      // تماماً مع قراءة أسرع ولا يعتمد على فهرس
      // الحقل. لا تُرجع لاستعلام where هنا.
      final groupDoc = await _getCustomerGroupsCollection(
        normalizedEmail,
      ).doc(groupId).get();

      if (!groupDoc.exists) {
        return const Right(false); // المجموعة غير موجودة
      }

      final groupData = groupDoc.data() as Map<String, dynamic>?;
      final isActive = groupData?['isActive'] as bool? ?? false;

      return Right(isActive);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }
}

/// استخراج رسالة خطأ مفهومة للمستخدم من أي استثناء.
String _readableError(dynamic e) {
  final message = (e as dynamic).message;
  if (message is String && message.isNotEmpty) {
    return message;
  }
  final errorString = e.toString();
  if (errorString.startsWith('Exception: ')) {
    return errorString.substring('Exception: '.length);
  }
  return 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى';
}
