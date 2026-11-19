import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/services/invoice_numbering_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../features/inventory/domain/entities/product_entity.dart';
import '../../../../features/inventory/domain/entities/product_log_entity.dart';
import '../../../../features/inventory/data/models/product_log_model.dart';
import '../../../../features/inventory/data/models/product_model.dart';
import '../../../../features/inventory/domain/repositories/product_repository.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/returned_item_entity.dart';
import '../../domain/entities/invoice_log_entity.dart';
import '../../domain/entities/invoice_stats_entity.dart';
import '../../domain/entities/invoice_template_entity.dart';
import '../../domain/entities/invoices_page.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../models/invoice_log_model.dart';
import '../models/invoice_model.dart';
import '../templates/classic_invoice_template.dart';
import '../templates/colorful_invoice_template.dart';
import '../templates/elegant_invoice_template.dart';
import '../templates/minimal_invoice_template.dart';
import '../templates/modern_invoice_template.dart';
import '../templates/professional_invoice_template.dart';

/// ✅ ملاحظة هامة للمبرمجين المستقبليين حول العمليات الذرية (Atomic Operations) في قسم الفواتير:
///
/// العمليات الذرية مطلوبة عندما تعدّل أكثر من مستند (Document)
/// في Firestore لضمان إما نجاح الكل أو فشل الكل (All-or-Nothing).
/// كل العمليات التالية تُنفذ داخل runTransaction واحد لأنه يوفر
/// Read-Modify-Write atomically، ويضمن all-or-nothing، ويعيد
/// المعاملة تلقائياً عند تعارضها مع تعديل متزامن (يمنع lost
/// update و race conditions)، ويمنع الحالات المتوسطة
/// (intermediate states) التي تسبب بيانات غير متسقة:
///
/// **ما يجب أن يكون ذرياً ولماذا (لا تفككه أبداً إلى عمليات منفصلة):**
/// 1. `addInvoice` — الفاتورة + المخزون + سجلات حركة المنتجات +
///    الصندوق + دين العميل + invoiceIds + relatedInvoiceIds +
///    سجل النشاط. السبب: إذا فشل تحديث المخزون بعد إنشاء
///    الفاتورة، تظهر فاتورة بلا مخزون مطابق.
/// 2. `updateInvoice` — عكس تأثير القديمة (مخزون + صندوق + دين) +
///    تطبيق تأثير الجديدة + نقل invoiceIds بين العملاء +
///    relatedInvoiceIds + سجل النشاط. السبب: إذا فشل العكس
///    بعد تطبيق الجديد، يتضاعف التأثير على الصندوق أو الدين.
/// 3. `deleteInvoice` — عكس الصندوق + عكس الدين + عكس المخزون +
///    حذف invoiceIds + relatedInvoiceIds + سجل النشاط + حذف
///    الفاتورة. السبب: إذا حُذفت الفاتورة دون عكس تأثيرها،
///    يبقى الدين والصندوق والمخزون محسوبة لفاتورة غير موجودة.
/// 4. `archiveCustomerInvoices` — أرشفة الكل + سجل النشاط.
///    السبب: أرشفة جزئية تفقد تتبع فواتير العميل.
/// 5. `clearCustomerAccount` — أرشفة الكل + فاتورة التصفير +
///    تصفير الدين + الصندوق + سجل النشاط. السبب: تصفير الدين
///    دون أرشفة الفواتير يخفي التاريخ، وأرشفة دون تصفير
///    يبقي الدين ظاهراً.
///
/// **قواعد Firestore للمعاملات (انتهاكها يسبب أخطاء):**
/// 1. جميع عمليات القراءة (transaction.get) قبل جميع عمليات
///    الكتابة (set/update/delete) داخل نفس المعاملة. انتهاكها
///    يسبب خطأ: '_commands.isEmpty': Transactions require all
///    reads to be executed before all writes. الحل: رتب جميع
///    transaction.get() في بداية المعاملة ثم نفذ جميع الكتابات
///    بعدها. الترتيب مُتحقَّق يدوياً بأسماء الدوال (حدّثه
///    يدوياً عند النقل): `addInvoice`: invoiceDoc (شرطي) ثم
///    customerDocRef (شرطي) ثم productSnapshots — كلها قبل أول
///    كتابة transaction.set(invoiceDoc). `updateInvoice`:
///    invoiceDoc ثم customerDocs old/new ثم productSnapshots —
///    كلها قبل أول كتابة (عكس المخزون). التحقق من التغيير
///    الصافي حساب بحت بلا transaction.get.
///    `archiveCustomerInvoices`: جلب الفواتير خارج المعاملة
///    إجبارياً (لا استعلامات داخل transaction)، لا قراءات داخل
///    المعاملة، فقط كتابات (أرشفة + سجل النشاط).
///    `clearCustomerAccount`: جلب الفواتير خارج المعاملة، القراءة
///    customerDoc قبل أول كتابة (أرشفة الفواتير).
///    `deleteInvoice`: invoiceDoc ثم customerDocRef (دائماً
///    عند customerId.isNotEmpty) ثم productSnapshots —
///    كلها قبل أول كتابة (تحديث الصندوق).
/// 2. لا يمكن استعلام Collection (where/orderBy/جلب قائمة
///    كاملة) داخل transaction. اجلب البيانات المطلوبة قبل
///    بدء المعاملة واستخدم transaction.get بالمعرف داخلها.
/// 3. maximum 500 reads/writes per transaction — لذلك
///    تفشل archiveCustomerInvoices و clearCustomerAccount
///    بأمان كاملتين (لا أرشفة/تصفير جزئي) عند تجاوز
///    فواتير العميل ~499؛ لا تُجزئهما إلى دفعات لأن
///    ذلك يكسر الذرية (انظر القاعدة الذهبية أدناه).
/// 4. اجمع التغييرات حسب المعرف وطبقها مرة واحدة لتجنب مشكلة
///    عزل اللقطة (snapshot isolation): إذا استدعيت دالة تحديث
///    عدة مرات لنفس المنتج داخل نفس المعاملة، كل استدعاء يقرأ
///    نفس الكمية الأولية فيأخذ effect الأخير فقط. نفس المشكلة
///    تحدث عند قراءة وكتابة نفس مستند العميل مرتين في
///    updateInvoice (عكس القديمة ثم تطبيق الجديدة) — الحل:
///    دمج الحساب القديم والجديد في عملية قراءة/كتابة واحدة
///    لنفس العميل.
///
/// **ما لا يحتاج إلى atomic operation:** القراءة فقط (get, stream) —
/// الحذف المجمع لسجلات بدون قراءة مسبقة (يمكن استخدام batch، مثل
/// clearInvoiceLogs) — العمليات التي تعدل مجموعة واحدة فقط (لكن يفضل
/// استخدام transaction للأمان).
///
/// ✅ ملاحظة للمبرمجين المستقبليين: جميع العمليات التي تحتاج قراءة ثم كتابة
/// تستخدم runTransaction لضمان اتساق البيانات (عملية ذرية). لا تقم بفك التجزئة
/// إلى عمليات منفصلة لأن ذلك قد يؤدي إلى بيانات غير متسقة في حالة فشل جزء من العملية.
///
/// 📋 ملخص الإشعارات والتقارير والسجلات والإحصائيات:
/// - الإشعارات: تُرسل بعد نجاح المعاملة في BLoc، وليست داخل transaction.
///   إذا فشل الإرسال، تظل الفاتورة محفوظة but الإشعار يضيع (مقبول لأن الإشعارات HTTP خارج Firestore).
/// - التقارير: دالات التصدير (PDF/Excel/Print) في invoices_reports_page.dart هي stubs فقط.
/// - السجلات: clearInvoiceLogs تستخدم Write Batch (ليست Transaction) لأنها تحذف وثائق متعددة بدون قراءة مسبقة.
/// - الإحصائيات: getInvoiceStats تحسب overdue كأي فاتورة لها remainingAmount > 0 وحالتها unpaid/partial،
///   دون التحقق من تاريخ الاستحقاق الفعلي.
///
/// 📋 ملاحظة إضافية عن الإشعارات والتقارير والسجلات:
/// - الإشعارات (Push Notification) تُرسل بعد نجاح المعاملة في BLoC، وليست داخلها.
///   إذا فشل الإرسال، تظل الفاتورة محفوظة but الإشعار يضيع. هذا مقبول لأن الإشعارات
///   تتطلب عمليات HTTP خارج Firestore ولا يمكن وضعها داخل transaction.
/// - التقارير (Reports page): دالات التصدير (PDF/Excel/Print) هي stubs فقط ولا تنفذ شيئاً فعلياً.
/// - السجلات (Invoice Logs): clearInvoiceLogs تستخدم Write Batch (ليست Transaction)
///   لأنها تحذف وثائق متعددة بدون قراءة مسبقة، وهذا آمن وآداء أفضل.
/// - الإحصائيات (Stats): getInvoiceStats و getInvoiceStatsStream تحسبان
///   overdue كأي فاتورة لها remainingAmount > 0 وحالتها unpaid أو partial،
///   بدون التحقق من تاريخ الاستحقاق الفعلي. هذا يعني أن فاتورة غير مدفوعة
///   منذ سنة تُعتبر "متأخرة" فوراً بغض النظر عن تاريخ الاستحقاق.
///
/// ============================================================
/// ✅ نتيجة التحقق اليدوي (أُعيد التحقق
/// يدوياً بالقراءة فقط 2026-10-12 —
/// ثاني تحقق اليوم والثالث إجمالاً
/// بعد 2026-10-11، وكلها بنفس النتيجة،
/// والتعليقات المكررة مدمجة هنا مصدراً
/// واحداً للحقيقة لتجنب الإطالة):
/// الذرية سليمة بالكامل —
/// كل العمليات الخمس متعددة المستندات (addInvoice/
/// updateInvoice/deleteInvoice/archiveCustomerInvoices/
/// clearCustomerAccount) داخل runTransaction واحد وكل
/// القراءات قبل الكتابات فيها، و clearInvoiceLogs بـ
/// Write Batch بلا قراءات، ولا كتابات فواتير/مالية خارج
/// هذا المستودع: BLoC بلا كتابات مباشرة (دواله غير
/// المستخدمة محمية بتحذير unused_element)، صفحة التفاصيل
/// تقرأ FirebaseFirestore فقط، وخدمتا PDF والإشعارات
/// تكتبان إعداتهما و Firebase Storage فقط — لا تمس
/// الفواتير/المخزون/الصندوق/الدين (وخدمة تذكير الدين
/// تقرأ الفواتير فقط). UseCases الخمسة وكلاء
/// فقط للمستودع، وحقن productRepository سليم في
/// injection_container.dart (الإصلاح 9)، وصفحة
/// edit_invoice_page.dart تمرر حقول مرجع البيع كلها، وأقسام
/// العملاء والاشتراكات تستخدم runTransaction في عملياتها
/// متعددة المستندات التي تلمس الفواتير (deleteCustomer و
/// deleteSubscription تقرآن المراجع داخل المعاملة قبل
/// الكتابات). ✅ النتيجة: كل المعاملات تنجح أو تفشل
/// معاً، لا تعديل مطلوب.
///
/// الدوال المساعدة (مُتحقَّق يدوياً — ترتيب القراءات/
/// الكتابات في القاعدة 1 أعلاه): _readProductSnapshotsInTransaction
/// هي الوحيدة التي تحتوي transaction.get وتُستدعى قبل
/// الكتابات فقط. أما _applyInventoryUpdatesForInvoice و
/// _reverseInventoryImpactInTransaction و
/// _computeInventoryChangeForInvoice و
/// _createInvoiceLogInTransaction و
/// _updateProductQuantityInTransaction و
/// _applySalesReturnInventoryInTransaction و
/// _reverseSalesReturnInventoryInTransaction و
/// _reverseNormalInventoryInTransaction فلا تحتوي أي قراءة
/// (كتابات فقط)، لذلك آمنة بعد الكتابات. الدوال
/// _updateCustomerDebt و _updateInventoryForInvoice و
/// _reverseInventoryImpact في BLoC غير مستخدمة ومحمية
/// بتحذير (Read-Modify-Write خارج معاملة — لا تستخدمها
/// أبداً).
///
/// **إصلاحات أُجريت (لا تُرجعها) — ملخص موحد مع تحذيراتها:**
/// 1. كمية المخزون تُكتب بـ FieldValue.increment(quantityChange)
///    لا بالقيمة المطلقة (كان خطأ سابقاً يكتب quantityChange
///    مباشرة فوق الكمية الحقيقية — بيع 5 من 100 كان يكتب 5)،
///    فتراكم العكس والتطبيق بشكل صحيح في updateInvoice
///    (النهائي = اللقطة + عكس القديمة + تطبيق الجديدة). في
///    addInvoice و deleteInvoice (كتابة واحدة) الناتج مطابق
///    للقيمة المطلقة. كميات المنتجات تُقرأ من لقطات حية داخل
///    المعاملة (_readProductSnapshotsInTransaction) قبل أي
///    كتابة لضمان عزل التعديلات المتزامنة على نفس المنتج.
///    ⚠️ لا تُرجع _updateProductQuantityInTransaction إلى كتابة
///    القيمة المطلقة، ولا حذف التحقق من التغيير الصافي،
///    ولا حذف معاملات reverseChanges/applyChanges.
/// 2. _computeInventoryChangeForInvoice تحسب التغيير الصافي
///    (عكس القديمة + تطبيق الجديدة) لكل منتج بدون كتابة،
///    ويُتحقق في updateInvoice من أن التغيير الصافي لا يجعل
///    أي كمية سالبة قبل بدء الكتابات. إذا فشل التحقق تفشل
///    المعاملة بالكامل. دوال العكس/التطبيق تقبل معاملات
///    اختيارية (reverseChanges عند التطبيق، applyChanges عند
///    العكس) حتى تحسب الحراس المفردة الكمية النهائية الحقيقية
///    لا اللقطة وحدها (Firestore تفرض القراءات قبل الكتابات،
///    فاللقطة لا تعكس أثر خطوة العكس عند خطوة التطبيق).
/// 3. مرجع البيع يزيد المخزون دائماً
///    (_applySalesReturnInventoryInTransaction) لأن المواد
///    المرتجعة تعود إلى المخزون، وعكسه ينقصها. لا تتجاهل
///    فواتير مرجع البيع أبداً (كان خطأ سابقاً يتجاهلها
///    فلا تُعيد الكمية إلى المخزون).
///    ⚠️ لا تُرجع _applyInventoryUpdatesForInvoice إلى تجاهل
///    مرجع البيع، ولا تحذف _applySalesReturnInventoryInTransaction.
/// 4. updateInvoice ينقل invoiceIds بين مستندي العميل عند
///    تغيير عميل الفاتورة (arrayRemove من القديم + arrayUnion
///    للجديد)، ويحدّث relatedInvoiceIds في مستند الاشتراك عند
///    تغيير subscriptionId أو النوع من/إلى 'subscription'.
///    deleteInvoice يزيل معرف الفاتورة من relatedInvoiceIds.
/// 5. حساب دين العميل واتجاه فاتورة الشراء (purchase):
///    purchase تنقص الدين (newTotalDebt += amountToUpdate
///    حيث amountToUpdate سالب فالناتج ينقص) في addInvoice
///    و updateInvoice (نفس العميل: عكس + تطبيق؛ عملاء
///    مختلفون: عكس + تطبيق) و deleteInvoice. السبب: الشراء
///    = التاجر يشتري من المورد فيدفع له، فالتاجر عليه دين
///    للعميل فيقل دينه ويصبح سالباً (دائن "له" حسب صفحة
///    تفاصيل العميل)، ويوافق صفحة الإنشاء
///    (balanceAfterInvoice = totalDebt - total) ووثائق BLoC
///    ("purchase تقلل الدين"). purchase و sales_return
///    (credit) تشتركان في الإشارة (كلتاهما تنقصان الدين).
///    نفس العميل: purchase — netChange += oldTotalAmount
///    (عكس القديم) و netChange -= invoice.totalAmount
///    (تطبيق الجديد)؛ cash — netChange += oldPaidAmount
///    (عكس القديم) و netChange -= invoice.paidAmount
///    (تطبيق الجديد). أنواع maintenance و rental تُحسب
///    مثل sales (الدين يزيد بالمتبقي) لأن فحص حد الائتمان
///    في BLoC يتضمنها (كانت الشروط تتضمنها لكن حسابات
///    المبالغ لم تتضمنها فتبقى المبالغ 0 ويُتخطى تحديث
///    الدين بسبب الشرط الخارجي `!= 0`).
///    ⚠️ لا تُرجع purchase إلى -= في addInvoice أو إلى
///    الإشارات المعكوسة في update/delete، ولا تُرجعها إلى
///    زيادة الدين (التاجر عليه دين للمورد) مثل
///    sales_return (credit) — الخلط يجعل الموردين مدينين
///    خطأً ويُرسل لهم تذكيرات دين. ولا تحذف
///    maintenance/rental من حسابات دين العميل (أنواع فواتير
///    حقيقية — قوالب افتراضية — يجب أن تزيد الدين مثل
///    sales عند عدم السداد). الخطأ السابق (purchase يزيد
///    الدين) كان يجعل الموردين يظهرون كمدينين ("عليه")
///    ويُرسل لهم تذكيرات دين خطأً.
///    ⚠️ البيانات القديمة (فواتير شراء أُنشئت قبل هذا
///    الإصلاح) قد يكون دين عملائها مضافاً خطأً — راجعها
///    يدوياً إن وُجدت.
/// 6. صفحة التعديل (edit_invoice_page.dart) تمرر حقول مرجع
///    البيع كلها (isSalesReturn/refundMethod/returnedItems/
///    originalInvoiceId) وتهيئ _refundMethod من الفاتورة
///    الحالية. ⚠️ لا تحذف تمرير حقول مرجع البيع من صفحة
///    التعديل.
/// 7. `type` هو المصدر الموثوق لنوع الفاتورة (لا حقل
///    isSalesReturn المقروء من المستند) في updateInvoice و
///    deleteInvoice، لأن تحويل فاتورة من مرجع بيع إلى نوع
///    آخر يترك حقول مرجع البيع عالقة في المستند (toFirestore
///    تكتبها شرطياً و update() لا تمس غير المذكور).
///    updateInvoice يمسحها صراحةً بـ FieldValue.delete() عند
///    تحديث فاتورة ليست مرجع بيع. ⚠️ لا تعتمد على حقل
///    isSalesReturn المقروء من المستند — اعتمد على type
///    دائماً.
/// 8. ربط الفاتورة بالعميل في invoiceIds (addInvoice و
///    deleteInvoice معاً): كان تحديث/حذف invoiceIds مربوطاً
///    بشرط أثر الدين (amountToUpdate/amountToReverse != 0)،
///    فالفاتورة المُسددة بالكامل (remainingAmount == 0) و
///    مرجع البيع النقدي (refundMethod == 'cash' حيث لا يُمس
///    الدين) والفاتورة/الشراء بصفر لم تُربط/يُحذف معرفها في
///    invoiceIds، فبقيت يتيمة عند حذف العميل (deleteCustomer
///    يعتمد على invoiceIds لبناء مراجع الفواتير المرتبطة).
///    الآن تُقرأ بيانات العميل دائماً عند وجود معرف عميل
///    (لا تشترط أثر الدين)، وتحديث الدين فقط هو المشروط
///    بأثر الدين، أما invoiceIds فيُحدَّث/يُحذف دائماً عند
///    وجود عميل. خدمة تذكير الدين تستعلم بـ customerId
///    مباشرة وتفلتر حسب status و remainingAmount فلا تتأثر.
///    deleteCustomer يتجاهل المراجع المعلقة بأمان
///    (يُحدِّث الفواتير الموجودة فقط). ⚠️ لا تُرجع قراءة
///    العميل في addInvoice/deleteInvoice إلى شرط أثر الدين
///    (يعيد مراجع يتيمة في invoiceIds)، ولا تشترط
///    تحديث/حذف invoiceIds بأثر الدين.
/// 9. حقن productRepository في InvoiceRepositoryImpl
///    (injection_container.dart): كان يُنشأ بدون
///    productRepository فكان null دائماً، فلم يُحدَّث
///    المخزون ولا سجلات حركة المنتجات في أي معاملة
///    فواتير (بيع/شراء/مرجع بيع/نقدية/تحديث/حذف) —
///    المعاملات كانت ذرية لكنها تتخطى المخزون صامتاً.
///    الآن يُمرَّر `productRepository: getIt<ProductRepository>()`.
///    ⚠️ لا تحذف هذا الحقن أبداً — بدونه يتوقف المخزون.
/// 10. إحصائيات الفواتير (getInvoiceStats و
///    getInvoiceStatsStream): كانت
///    تستثني maintenance و rental من
///    الإيراد رغم أن منطق الدين
///    يعاملهما مثل sales (الدين
///    += remainingAmount)، وتستثني
///    sales_return رغم أنها تعكس
///    بيعاً (الدين -= totalAmount
///    لنوع credit). فكان الإيراد
///    أقل من حقيقته (maintenance/
///    rental) أو أكثر منه
///    (sales_return) — انحراف لا
///    يطابق دين العملاء. الآن
///    مجموعات الأنواع مطابقة
///    لمنطق الدين: maintenance/
///    rental مع sales/subscription/
///    cash (إيراد)، و sales_return
///    مع purchase (طرح). فاتورة
///    مرجع البيع تُنشأ مدفوعة
///    بالكامل (paidAmount =
///    totalAmount و remainingAmount
///    = 0) فطرحها يصحح الإيراد
///    والمدفوع دون أن يمس المتبقي.
///
/// **قاعدة ذهبية للمبرمجين المستقبليين:**
/// 1. أي عملية تعدل أكثر من مستند = runTransaction واحد،
///    ولا تنقل أي جزء إلى BLoC أو UseCase أو خدمة خارجية.
/// 2. عند إضافة عملية متعددة المستندات جديدة، وثّقها في
///    قسم "ما يجب أن يكون ذرياً" أعلاه مع السبب، واجعل
///    كل القراءات قبل كل الكتابات داخل المعاملة.
/// ============================================================
///
class _InventoryChange {
  ProductEntity product;
  double quantityChange;
  double unitPrice;
  double totalPrice;
  String reason;

  _InventoryChange({
    required this.product,
    required this.quantityChange,
    required this.unitPrice,
    required this.totalPrice,
    required this.reason,
  });
}

class InvoiceRepositoryImpl implements InvoiceRepository {
  InvoiceRepositoryImpl({required this.firestore, this.productRepository});
  final FirebaseFirestore firestore;
  final ProductRepository? productRepository;
  final _emailService = EmailNormalizationService();

  CollectionReference _getInvoicesCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('invoices')
        .collection('invoices');
  }

  /// تحويل آمن لقيمة رقمية من بيانات Firestore
  /// ✅ تحسين (2026-10-12): يُستخدم في حساب
  /// الإحصائيات من البيانات الخام (بدلاً من
  /// بناء InvoiceModel كامل). منطقه مطابق
  /// لـ InvoiceModel._parseDouble.
  static double _parseStatsDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0;
  }

  CollectionReference _getProductsCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('products');
  }

  Future<QuerySnapshot> _handleFirestoreError(
    Future<QuerySnapshot> operation,
    String context,
  ) async {
    try {
      return await operation;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition' || e.code == 'FAILED_PRECONDITION') {
        throw Exception(
          'مطلوب فهرس مركب في Firestore: $context. يرجى نشر الفهارس باستخدام firebase deploy --only firestore:indexes',
        );
      }
      rethrow;
    }
  }

  Stream<QuerySnapshot> _handleFirestoreStreamError(
    Stream<QuerySnapshot> stream,
    String context,
  ) {
    return stream.handleError((error) {
      if (error is FirebaseException &&
          (error.code == 'failed-precondition' ||
              error.code == 'FAILED_PRECONDITION')) {
        throw Exception(
          'مطلوب فهرس مركب في Firestore: $context. يرجى نشر الفهارس باستخدام firebase deploy --only firestore:indexes',
        );
      }
      throw error;
    });
  }

  CollectionReference _getProductLogsCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('inventory')
        .collection('products_logs');
  }

  DocumentReference _getProductDocRef(
    String organizationEmail,
    String productId,
  ) {
    return _getProductsCollection(organizationEmail).doc(productId);
  }

  DocumentReference _getProductLogDocRef(String organizationEmail) {
    return _getProductLogsCollection(organizationEmail).doc();
  }

  CollectionReference _getCashboxCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('cashbox')
        .collection('balance');
  }

  DocumentReference _getCashboxDocRef(String organizationEmail) {
    return _getCashboxCollection(organizationEmail).doc('main');
  }

  CollectionReference _getCustomersCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('customers')
        .collection('customers');
  }

  DocumentReference _getCustomerDocRef(
    String organizationEmail,
    String customerId,
  ) {
    return _getCustomersCollection(organizationEmail).doc(customerId);
  }

  @override
  Future<Either<Failure, List<InvoiceEntity>>> getInvoices(
    String organizationEmail, {
    int? limit,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // ✅ ملاحظة للمبرمجين المستقبليين:
      // نستخدم where + orderBy مع فهرس مناسب لجلب الفواتير غير المؤرشفة فقط.
      // لا نستخدم .get() بدون فلتر لأنه يجلب جميع الفواتير ويسبب بطء كبير.
      // ✅ تمت إضافة فهرس: isArchived + createdAt
      // ⚠️ الحد 500 سجل: للأ institucions الكبيرة، يُنصح باستخدام getInvoicesPaginated
      // مع startAfterDocument بدلاً من تحميل الكل في مرة واحدة.
      var query = _getInvoicesCollection(normalizedEmail)
          .where('isArchived', isEqualTo: false)
          .orderBy('createdAt', descending: true);

      // تطبيق الحد الأقصى للنتائج فقط إذا تم تمريره (null = جميع البيانات)
      if (limit != null) {
        query = query.limit(limit);
      } else {
        query = query.limit(500);
      }

      final snapshot = await _handleFirestoreError(
        query.get(),
        'invoices (isArchived + createdAt)',
      );

      final invoices = snapshot.docs.map(InvoiceModel.fromFirestore).toList();

      return Right(invoices);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<InvoiceEntity>>> getArchivedInvoices(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // 🔧 جلب الفواتير المؤرشفة فقط (isArchived == true)
      // تُستخدم لعرض صفحة الأرشيف. بدون هذه الطريقة، كانت الصفحة
      // تُستدعى بـ getInvoices (الذي يستثني المؤرched) ثم تُFiltered محلياً
      // لـ isArchived == true → النتيجة دائماً فارغة.
      final snapshot = await _handleFirestoreError(
        _getInvoicesCollection(normalizedEmail)
            .where('isArchived', isEqualTo: true)
            .orderBy('updatedAt', descending: true)
            .limit(500)
            .get(),
        'archived invoices (isArchived + updatedAt)',
      );

      final invoices = snapshot.docs.map(InvoiceModel.fromFirestore).toList();

      return Right(invoices);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, InvoicesPage>> getInvoicesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
    String? customerId,
    String? searchQuery,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      var query = _getInvoicesCollection(normalizedEmail)
          .where('isArchived', isEqualTo: false)
          .orderBy('createdAt', descending: true);

      // فلتر حسب العميل إذا تم تمرير معرف العميل
      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customerId', isEqualTo: customerId);
      }

      // إذا كان هناك مستند أخير، نبدأ بعده
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await _handleFirestoreError(
        query.get(),
        'invoices paginated (isArchived + createdAt)',
      );

      var invoices = <InvoiceEntity>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        mapData['id'] = doc.id;
        final invoice = InvoiceModel.fromJson(mapData);
        invoices.add(invoice);
      }

      // تطبيق فلتر البحث في الذاكرة إذا كان موجوداً
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchLower = searchQuery.toLowerCase();
        invoices = invoices.where((invoice) {
          final invoiceNumber = invoice.invoiceNumber.toLowerCase();
          final customerName = invoice.customerName.toLowerCase();
          final customerPhone = invoice.customerPhone.toLowerCase();
          return invoiceNumber.contains(searchLower) ||
              customerName.contains(searchLower) ||
              customerPhone.contains(searchLower);
        }).toList();
      }

      // ✅ تحسين (2026-10-12): نعيد مؤشر الصفحة الأخيرة
      // من نتيجة الاستعلام نفسها (snapshot.docs.last)
      // بدلاً من جلب المستند مجدداً عبر getInvoiceDocument
      // — كان يضيف جولة شبكة زائدة بعد كل تحميل صفحة.
      return Right(
        InvoicesPage(
          invoices: invoices,
          lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  /// الحصول على DocumentSnapshot لفاتورة محددة
  @override
  Future<DocumentSnapshot<Object?>?> getInvoiceDocument(
    String organizationEmail,
    String invoiceId,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      return await _getInvoicesCollection(normalizedEmail).doc(invoiceId).get();
    } on Exception catch (_) {
      // ⚠️ تم التعديل: عدم إخفاء خطأ جلب مستند الفاتورة صامتاً، طباعته للتصحيح
      // مع إرجاع null للحفاظ على توقيع الدالة ودون انهيار التطبيق.
      debugPrint('getInvoiceDocument error occurred');
      return null;
    }
  }

  @override
  Stream<Either<Failure, List<InvoiceEntity>>> getInvoicesStream(
    String organizationEmail, {
    int? limit,
    String? searchQuery,
    String? statusFilter,
    String? typeFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // 1. بناء الـ query الأساسي
      Query query = _getInvoicesCollection(normalizedEmail);

      // 2. إضافة فلتر الحالة إذا كان موجوداً (قبل orderBy)
      if (statusFilter != null && statusFilter != 'all') {
        query = query.where('isPaid', isEqualTo: statusFilter == 'paid');
      }

      // 3. إضافة فلتر النوع إذا كان موجوداً (قبل orderBy)
      if (typeFilter != null && typeFilter != 'all') {
        query = query.where('type', isEqualTo: typeFilter);
      }

      // 3.5 ✅ تطبيق فلترة التاريخ في الخادم بدلاً من الذاكرة
      // السبب: فلترة التاريخ في الذاكرة تجلب جميع الفواتير ثم تفلترها،
      // مما يسبب بطء كبير مع زيادة عدد الفواتير.
      // نستخدم createdAt لأنه مُفهرس وموجود في جميع الفواتير.
      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        final endOfDay = Timestamp.fromDate(
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
        );
        query = query.where('createdAt', isLessThanOrEqualTo: endOfDay);
      }

      // 4. الترتيب
      query = query.orderBy('createdAt', descending: true);

      // 5. الاستماع للتغييرات
      // ✅ تطبيق الحد (Limit) في الاستعلام لتقليل البيانات المنقولة.
      // ⚠️ ملاحظة للمبرمجين المستقبليين: الحد يُطبَّق هنا في
      // الاستعلام (وليس في BLoC بعد الفلترة) لتقليل البيانات
      // المنقولة، لذلك الفلترة والبحث في BLoC (_applyFilters)
      // تعمل على الفواتير المحمّلة ضمن الحد فقط. الصفحات التي
      // تريد كل الفواتير للفلترة الكاملة تمرر limit: null
      // (صفحة القائمة وصفحة التفاصيل)، والصفحات التي تريد
      // حدّاً للأداء تمرر قيمة (لوحة التحكم 20، التقارير
      // 1000). لا تُرجع هذا الحد إلى عدم التطبيق إلا إذا
      // كانت الفلترة الكاملة مطلوبة لكل صفحة تستخدم الستريم.
      if (limit != null) {
        query = query.limit(limit);
      }

      // ✅ تحسين (2026-10-12): للستريم بلا
      // حد (صفحة القائمة وصفحة التفاصيل)
      // نحفظ الفواتير المحللة في ذاكرة
      // خاصة بهذا الستريم ونحدّث المستندات
      // المتغيرة فقط عبر docChanges بدلاً
      // من إعادة تحليل كل الفواتير مع كل
      // لقطة — كان يسبب بطءاً ملحوظاً مع
      // كثرة الفواتير عند كل تحديث. الستريم
      // المحدود (بحد) يبقي التحليل الكامل
      // الأصلي لأن نافذة الحد تتحرك وقد
      // لا يُصدر المستند الخارج تغييراً
      // من نوع removed بشكل موثوق.
      final streamCache = <String, InvoiceEntity>{};

      return query
          .snapshots()
          .map((snapshot) {
            try {
              if (limit == null) {
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
                  if (mapData['id'] == null ||
                      mapData['id'].toString().isEmpty) {
                    mapData['id'] = doc.id;
                  }
                  try {
                    streamCache[doc.id] = InvoiceModel.fromJson(mapData);
                  } on Exception catch (_) {
                    streamCache.remove(doc.id);
                  }
                }

                var invoices = streamCache.values.toList()
                  ..sort((a, b) {
                    final cmp = b.createdAt.compareTo(a.createdAt);
                    return cmp != 0 ? cmp : a.id.compareTo(b.id);
                  });

                // تطبيق فلتر البحث في الذاكرة
                if (searchQuery != null && searchQuery.isNotEmpty) {
                  final search = searchQuery.toLowerCase();
                  invoices = invoices
                      .where(
                        (invoice) =>
                            invoice.customerName.toLowerCase().contains(
                              search,
                            ) ||
                            (invoice.notes?.toLowerCase().contains(search) ??
                                false) ||
                            invoice.id.toLowerCase().contains(search),
                      )
                      .toList();
                }

                // تطبيق فلاتر التاريخ في الذاكرة لـ dateFilter فقط
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

                  invoices = invoices
                      .where(
                        (invoice) => !invoice.invoiceDate.isBefore(filterDate),
                      )
                      .toList();
                }

                return Right<Failure, List<InvoiceEntity>>(invoices);
              }

              // الستريم المحدود: تحليل كامل (السلوك الأصلي)
              final invoices = <InvoiceEntity>[];

              for (final doc in snapshot.docs) {
                try {
                  final data = doc.data();
                  if (data == null) continue;
                  final mapData = data as Map<String, dynamic>;
                  if (mapData['id'] == null ||
                      mapData['id'].toString().isEmpty) {
                    mapData['id'] = doc.id;
                  }
                  final invoice = InvoiceModel.fromJson(mapData);

                  // تطبيق فلتر البحث في الذاكرة (لا يمكن تطبيقه بكفاءة في Firestore مع الفلاتر الأخرى)
                  if (searchQuery != null && searchQuery.isNotEmpty) {
                    final query = searchQuery.toLowerCase();
                    if (!invoice.customerName.toLowerCase().contains(query) &&
                        !(invoice.notes?.toLowerCase().contains(query) ??
                            false) &&
                        !invoice.id.toLowerCase().contains(query)) {
                      continue;
                    }
                  }

                  // تطبيق فلاتر التاريخ في الذاكرة لـ dateFilter فقط
                  // startDate و endDate تتم فلترتهما في الخادم
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

                    if (invoice.invoiceDate.isBefore(filterDate)) {
                      continue;
                    }
                  }

                  // ✅ ملاحظة: فلترة startDate و endDate تتم في الخادم الآن
                  // لا حاجة لفلترتها هنا

                  invoices.add(invoice);
                } on Exception catch (_) {
                  continue;
                }
              }

              return Right<Failure, List<InvoiceEntity>>(invoices);
            } on Exception catch (e) {
              return Left<Failure, List<InvoiceEntity>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, List<InvoiceEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Stream<Either<Failure, InvoiceStatsEntity>> getInvoiceStatsStream(
    String organizationEmail, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final collection = _getInvoicesCollection(normalizedEmail);

      Query query = collection.where('isArchived', isEqualTo: false);

      if (startDate != null || endDate != null) {
        query = query.orderBy('createdAt', descending: true);
      }

      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      return _handleFirestoreStreamError(
            query.snapshots(),
            'invoices stats (isArchived + createdAt)',
          )
          .map((snapshot) {
            try {
              // ✅ تحسين (2026-10-12): حساب الإحصائيات
              // مباشرة من بيانات المستند الخام بدلاً
              // من بناء كائن InvoiceModel كامل (مع
              // تحليل قوائم البنود والمرتجعات) لكل
              // فاتورة — الإحصائيات تحتاج 5 حقول فقط
              // فبناء النموذج كاملاً كان يهدر وقت
              // المعالج خصوصاً مع كثرة فواتير اليوم.
              // ✅ ملاحظة للمبرمجين المستقبليين:
              // منطق الحساب مطابق تماماً للسابق
              // (isPaid = status == 'paid' و isUnpaid =
              // status == 'unpaid' ومجموعات الأنواع
              // مطابقة لمنطق الدين في
              // addInvoice/updateInvoice/deleteInvoice
              // — إصلاح 5 في رأس الملف): maintenance
              // و rental إيراد مثل sales، و sales_return
              // تُطرح مثل purchase. فاتورة مرجع البيع
              // تُنشأ مدفوعة بالكامل فطرحها يصحح
              // الإيراد والمدفوع دون أن يمس المتبقي.
              // لا تُغيّر هذه المجموعات إلا بعد
              // مراجعة منطق الدين.
              int totalInvoices = 0;
              int paidInvoices = 0;
              int unpaidInvoices = 0;
              int overdueInvoices = 0;
              double totalRevenue = 0;
              double totalPaid = 0;
              double totalRemaining = 0;

              for (final doc in snapshot.docs) {
                final data = doc.data();
                if (data == null) continue;
                final mapData = data as Map<String, dynamic>;

                final status = mapData['status'] as String? ?? 'unpaid';
                final type = mapData['type'] as String? ?? 'sales';
                final totalAmount = _parseStatsDouble(mapData['totalAmount']);
                final paidAmount = _parseStatsDouble(mapData['paidAmount']);
                final remainingAmount = _parseStatsDouble(
                  mapData['remainingAmount'],
                );

                totalInvoices++;

                if (status == 'paid') {
                  paidInvoices++;
                } else if (status == 'unpaid' || status == 'partial') {
                  unpaidInvoices++;
                } else if (status == 'cancelled') {
                  // الفواتير الملغاة تُحتسب في totalInvoices فقط،
                  // وليس في paidInvoices أو unpaidInvoices.
                  // هذا توثيق للسلوك الحالي — لا يتم إضافة عداد منفرد
                  // لـ cancelled في InvoiceStatsEntity لتجنب تغيير واجهة الكيان.
                }

                // ⚠️ ملاحظة للمبرمجين المستلمين — عداد الفواتير المدفوعة/غير المدفوعة:
                // الفواتير ذات الحالة 'cancelled' لا تُحتسب في paidInvoices ولا في
                // unpaidInvoices، لكن تُحتسب في totalInvoices. لذلك لا يتحقق الشرط
                // totalInvoices == paidInvoices + unpaidInvoices عند وجود فواتير ملغاة.
                // هذا يُسبب تفاوتًا في الإحصائيات المعروضة. يُنصح بإضافة حالّة cancelled
                // إلى العداد المناسب أو توثيق هذا السلوك في واجهة المستخدم.
                // ⚠️ ملاحظة للمبرمجين المستلمين — عداد الفواتير المتأخرة:
                // تُحسب الفاتورة "متأخرة" إذا كان لديها remainingAmount > 0
                // وحالتها unpaid أو partial، بدون التحقق من تاريخ الاستحقاق الفعلي.
                // هذا يعني أن فاتورة غير مدفوعة منذ سنة تُعتبر "متأخرة" فوراً.
                // لإضافة فحص dueDate، يجب إضافة الحقل إلى InvoiceEntity و InvoiceModel
                // وفهرس Firestore المقابل.
                if (remainingAmount > 0 &&
                    (status == 'unpaid' || status == 'partial')) {
                  overdueInvoices++;
                }

                switch (type) {
                  case 'sales':
                  case 'subscription':
                  case 'cash':
                  case 'maintenance':
                  case 'rental':
                    totalRevenue += totalAmount;
                    totalPaid += paidAmount;
                    totalRemaining += remainingAmount;
                    break;
                  case 'purchase':
                  case 'sales_return':
                    totalRevenue -= totalAmount;
                    totalPaid -= paidAmount;
                    totalRemaining -= remainingAmount;
                    break;
                  default:
                    break;
                }
              }

              return Right<Failure, InvoiceStatsEntity>(
                InvoiceStatsEntity(
                  totalInvoices: totalInvoices,
                  paidInvoices: paidInvoices,
                  unpaidInvoices: unpaidInvoices,
                  overdueInvoices: overdueInvoices,
                  totalRevenue: totalRevenue,
                  totalPaid: totalPaid,
                  totalRemaining: totalRemaining,
                ),
              );
            } on Exception catch (e) {
              return Left<Failure, InvoiceStatsEntity>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, InvoiceStatsEntity>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Future<Either<Failure, InvoiceEntity>> getInvoiceById(
    String id,
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final doc = await _getInvoicesCollection(normalizedEmail).doc(id).get();

      if (!doc.exists) {
        return const Left(ServerFailure(message: 'الفاتورة غير موجودة'));
      }

      return Right(InvoiceModel.fromFirestore(doc));
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> addInvoice(InvoiceEntity invoice) async {
    try {
      final model = InvoiceModel.fromEntity(invoice);

      // إنشاء ID قصير وقابل للقراءة إذا كان فارغاً
      final normalizedEmail = _emailService.normalize(
        invoice.organizationEmail,
      );
      final collection = _getInvoicesCollection(normalizedEmail);
      final invoiceDoc = invoice.id.isEmpty
          ? collection.doc()
          : collection.doc(invoice.id);
      final invoiceId = invoiceDoc.id;

      final data = model.toFirestore();
      data['id'] = invoiceId;

      // ✅ جلب المنتجات قبل الـ transaction لاستخدامها في تحديث المخزون
      // لأن Firestore transactions لا تدعم قراءة Collections مباشرة
      // (قاعدة 2 في رأس الملف). productId يُستخدم للبحث بالمعرف
      // داخل transaction مباشرة، والاسم احتياطي للفواتير القديمة.
      final products = <ProductEntity>[];
      if (productRepository != null) {
        final productsResult = await productRepository!.getProducts(
          organizationEmail: normalizedEmail,
        );
        products.addAll(productsResult.getOrElse(() => []));
      }

      await firestore.runTransaction((transaction) async {
        if (invoice.id.isNotEmpty) {
          final docSnapshot = await transaction.get(invoiceDoc);

          if (docSnapshot.exists) {
            throw Exception('الفاتورة موجودة مسبقاً');
          }
        }

        // ✅ قراءة بيانات العميل قبل أي عملية كتابة لضمان compliance مع Firestore
        // (يجب أن تكون جميع القراءات قبل جميع العمليات الكتابية في المعاملة)
        DocumentReference? customerDocRef;
        DocumentSnapshot? customerSnapshot;
        double amountToUpdate = 0;

        if (invoice.customerId != null && invoice.customerId!.isNotEmpty) {
          if (invoice.isSalesReturn) {
            if (invoice.refundMethod == 'credit') {
              amountToUpdate = -invoice.totalAmount;
            }
          } else if (invoice.type == 'cash' && invoice.isCashAccountReceipt) {
            amountToUpdate = invoice.paidAmount;
          } else if (invoice.type == 'sales' ||
              invoice.type == 'subscription' ||
              invoice.type == 'maintenance' ||
              invoice.type == 'rental') {
            amountToUpdate = invoice.remainingAmount;
          } else if (invoice.type == 'purchase') {
            amountToUpdate = -invoice.totalAmount;
          }

          // ✅ قراءة مستند العميل دائماً عند وجود معرف عميل
          // (لا تشترط amountToUpdate != 0) — إصلاح 8 في
          // رأس الملف: invoiceIds يُحدَّث لكل فاتورة
          // مرتبطة بالعميل حتى لو كان أثرها على الدين
          // صفراً (فاتورة مُسددة بالكامل، أو مرجع بيع
          // نقدي، أو فاتورة/شراء بصفر) وإلا بقيت مرجعاً
          // يتيمة عند حذف العميل. القراءة قبل أي كتابة
          // (قاعدة Firestore) محفوظة.
          customerDocRef = firestore
              .collection(normalizedEmail)
              .doc('customers')
              .collection('customers')
              .doc(invoice.customerId!);

          customerSnapshot = await transaction.get(customerDocRef);
        }

        // ✅ قراءة لقطات حية للمنتجات قبل أي كتابة لضمان العزل
        // ⚠️ ملاحظة للمبرمجين المستقبليين:
        // يجب أن تكون هذه القراءات قبل أول عملية كتابة
        // (transaction.set أدناه) لأن Firestore يفرض
        // ترتيب القراءات قبل الكتابات داخل المعاملة.
        final productIds = _collectTrackedProductIds(invoice, products);
        final productSnapshots = await _readProductSnapshotsInTransaction(
          transaction,
          normalizedEmail,
          productIds,
        );

        transaction.set(invoiceDoc, data);

        // ✅ تحديث المخزون داخل نفس الـ transaction لضمان الذرية
        await _applyInventoryUpdatesForInvoice(
          transaction,
          invoice,
          products,
          productSnapshots,
        );

        // ✅ تطبيق تحديث دين العميل باستخدام القراءة المسبقة
        // (إصلاح 8 في رأس الملف): تحديث الدين فقط هو
        // المشروط بـ amountToUpdate != 0 (لا معنى لتحديث
        // دين بصفر)، أما invoiceIds فيُحدَّث دائماً عند
        // وجود عميل (انظر الملاحظة في قراءة العميل أعلاه).
        if (customerDocRef != null &&
            customerSnapshot != null &&
            customerSnapshot.exists) {
          final customerData = customerSnapshot.data() as Map<String, dynamic>?;
          final currentDebt =
              (customerData?['totalDebt'] as num?)?.toDouble() ?? 0;
          if (!currentDebt.isNaN &&
              !currentDebt.isInfinite &&
              amountToUpdate != 0) {
            var newTotalDebt = currentDebt;

            if (invoice.type == 'sales' ||
                invoice.type == 'subscription' ||
                invoice.type == 'maintenance' ||
                invoice.type == 'rental') {
              newTotalDebt += amountToUpdate;
            } else if (invoice.type == 'purchase') {
              // ✅ purchase تنقص الدين — نفس إشارة
              // sales_return (credit) — إصلاح 5 في
              // رأس الملف. لا تُرجع هذا إلى -=.
              newTotalDebt += amountToUpdate;
            } else if (invoice.type == 'sales_return') {
              newTotalDebt += amountToUpdate;
            } else if (invoice.type == 'cash' && invoice.isCashAccountReceipt) {
              newTotalDebt -= amountToUpdate;
            }

            if (!newTotalDebt.isNaN && !newTotalDebt.isInfinite) {
              transaction.set(customerDocRef, {
                'totalDebt': newTotalDebt,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          }

          // ✅ تحديث قائمة الفواتير في مستند العميل ذرياً
          // (خارج شرط amountToUpdate — انظر الملاحظة أعلاه)
          // ✅ حراسة containsKey (قاعدة ذهبية من
          // customer_repository_impl — تُطبَّق على كل
          // مواضع صيانة invoiceIds في هذا الملف وفي
          // subscription_repository_impl): نُنفّذها فقط
          // إذا كان الحقل موجوداً أصلاً — arrayUnion على
          // عميل قديم بلا حقل invoiceIds يُنشئه بقائمة
          // ناقصة فيُصبح containsKey صحيحاً في
          // deleteCustomer فتبقى فواتيره القديمة تشير
          // لعميل محذوف (مراجع يتيمة). العميل القديم
          // يبقى بلا الحقل ليُستعلم عن فواتيره خارج
          // المعاملة (الفاتورة تُنشأ في كل الأحوال
          // وcustomerId في بياناتها يربطها بالعميل).
          if (customerData?.containsKey('invoiceIds') == true) {
            transaction.set(customerDocRef, {
              'invoiceIds': FieldValue.arrayUnion([invoiceId]),
            }, SetOptions(merge: true));
          }
        }

        // ⚠️ تحديث relatedInvoiceIds في مستند الاشتراك
        // يجب أن يكون ذرياً مع إنشاء الفاتورة: إذا
        // أُنشئت الفاتورة ولم يُحدَّث relatedInvoiceIds
        // فإن حذف الاشتراك لن يحذف هذه الفاتورة
        // تلقائياً. نستخدم FieldValue.arrayUnion
        // لضمان عدم تكرار المعرفات.
        if (invoice.subscriptionId != null &&
            invoice.subscriptionId!.isNotEmpty &&
            invoice.type == 'subscription') {
          final subscriptionDoc = firestore
              .collection(normalizedEmail)
              .doc('subscriptions')
              .collection('subscriptions')
              .doc(invoice.subscriptionId!);

          transaction.set(subscriptionDoc, {
            'relatedInvoiceIds': FieldValue.arrayUnion([invoiceId]),
          }, SetOptions(merge: true));
        }

        // تسجيل حركة الصندوق هنا للفواتير العادية؛ إيصال العميل
        // يسجل حركته في مسار العميل ولا يكررها المستودع.
        if (invoice.paidAmount.abs() > 0) {
          String direction = 'in';
          String description = 'فاتورة #${invoice.invoiceNumber}';

          if (invoice.type == 'purchase') {
            direction = 'out';
            description = 'فاتورة مشتريات #${invoice.invoiceNumber}';
          } else if (invoice.type == 'sales_return') {
            if (invoice.refundMethod == 'cash') {
              direction = 'out';
              description = 'مرجع بيع نقدي #${invoice.invoiceNumber}';
            } else {
              direction = '';
              description = 'مرجع بيع كحساب #${invoice.invoiceNumber}';
            }
          } else if (invoice.type == 'cash') {
            if (invoice.paidAmount < 0) {
              direction = 'out';
              description = 'دفعة نقدية للعميل #${invoice.invoiceNumber}';
            } else {
              direction = 'in';
              description = 'دفعة نقدية من العميل #${invoice.invoiceNumber}';
            }
          } else if (invoice.paidAmount < 0) {
            direction = 'out';
            description = 'تصفير حساب - فاتورة #${invoice.invoiceNumber}';
          }

          if (direction.isNotEmpty) {
            final cashboxRef = firestore
                .collection(normalizedEmail)
                .doc('cashbox')
                .collection('balance')
                .doc('main');

            transaction.set(cashboxRef, {
              'currentBalance': FieldValue.increment(
                direction == 'in'
                    ? invoice.paidAmount.abs()
                    : -invoice.paidAmount.abs(),
              ),
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedBy': invoice.createdBy,
            }, SetOptions(merge: true));
          }
        }

        // ✅ إنشاء سجل النشاط داخل نفس الـ transaction لضمان الذرية
        await _createInvoiceLogInTransaction(transaction, normalizedEmail, {
          'userId': invoice.createdBy,
          'actionType': 'add_invoice',
          'timestamp': FieldValue.serverTimestamp(),
          'details': 'تم إضافة فاتورة جديدة: ${invoice.invoiceNumber}',
          'targetId': invoice.id,
          'targetType': 'invoice',
          'newValues': {
            'invoiceNumber': invoice.invoiceNumber,
            'customerName': invoice.customerName,
            'customerPhone': invoice.customerPhone,
            'totalAmount': invoice.totalAmount,
            'paidAmount': invoice.paidAmount,
            'remainingAmount': invoice.remainingAmount,
            'status': invoice.status,
            'invoiceDate': invoice.invoiceDate.toIso8601String(),
            'type': invoice.type,
          },
          'isSuccess': true,
        });
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> updateInvoice(InvoiceEntity invoice) async {
    try {
      final model = InvoiceModel.fromEntity(invoice);
      final normalizedEmail = _emailService.normalize(
        invoice.organizationEmail,
      );

      // ✅ عملية التحديث ذرية بالكامل داخل الـ transaction:
      // 1. قراءة الفاتورة القديمة لمعرفة تأثيرها الحالي.
      // 2. عكس تأثير الفاتورة القديمة على الصندوق ودين العميل.
      // 3. تطبيق تأثير الفاتورة الجديدة على الصندوق ودين العميل.
      // 4. تحديث بيانات الفاتورة.
      // هذا يضمن إما نجاح الكل أو فشل الكل دون أي بيانات متوسطة.
      final firestoreInstance = FirebaseFirestore.instance;

      // ✅ جلب المنتجات قبل الـ transaction لاستخدامها في
      // تحديث/عكس المخزون (قاعدة 2 في رأس الملف:
      // Firestore لا تدعم قراءة Collections داخل
      // transaction). productId يُستخدم للبحث
      // بالمعرف داخل transaction مباشرة، والاسم
      // احتياطي للفواتير القديمة.
      final products = <ProductEntity>[];
      if (productRepository != null) {
        final productsResult = await productRepository!.getProducts(
          organizationEmail: normalizedEmail,
        );
        products.addAll(productsResult.getOrElse(() => []));
      }

      await firestoreInstance.runTransaction((transaction) async {
        final invoiceDoc = _getInvoicesCollection(
          normalizedEmail,
        ).doc(invoice.id);

        // التحقق من وجود الفاتورة قبل التحديث
        final docSnapshot = await transaction.get(invoiceDoc);

        if (!docSnapshot.exists) {
          throw Exception('الفاتورة غير موجودة');
        }

        final oldData = docSnapshot.data() as Map<String, dynamic>?;
        // ✅ ملاحظة للمبرمجين المستقبليين:
        // oldData تم تحويله إلى Map<String, dynamic>? أعلاه.
        // جميع الوصولات التالية لـ oldData?['...'] مقصودة
        // ومُحوّلة إلى النوع المناسب يدوياً.
        final oldCustomerId = oldData?['customerId'] as String? ?? '';
        final oldType = oldData?['type'] as String? ?? '';
        final oldPaidAmount = (oldData?['paidAmount'] as num?)?.toDouble() ?? 0;
        final oldTotalAmount =
            (oldData?['totalAmount'] as num?)?.toDouble() ?? 0;
        final oldRefundMethod = oldData?['refundMethod'] as String? ?? '';
        final oldIsSalesReturn = oldType == 'sales_return';
        // ✅ قراءة بيانات العملاء قبل أي عملية كتابة لضمان compliance مع Firestore
        // (يجب أن تكون جميع القراءات قبل جميع العمليات الكتابية في المعاملة)
        DocumentSnapshot? oldCustomerSnapshot;
        DocumentSnapshot? newCustomerSnapshot;
        final newCustomerId = invoice.customerId ?? '';
        final sameCustomer =
            oldCustomerId.isNotEmpty && oldCustomerId == newCustomerId;

        if (sameCustomer) {
          if (newCustomerId.isNotEmpty) {
            final customerDoc = firestoreInstance
                .collection(normalizedEmail)
                .doc('customers')
                .collection('customers')
                .doc(newCustomerId);
            newCustomerSnapshot = await transaction.get(customerDoc);
          }
        } else {
          if (oldCustomerId.isNotEmpty) {
            final oldCustomerDoc = firestoreInstance
                .collection(normalizedEmail)
                .doc('customers')
                .collection('customers')
                .doc(oldCustomerId);
            oldCustomerSnapshot = await transaction.get(oldCustomerDoc);
          }
          if (newCustomerId.isNotEmpty) {
            final newCustomerDoc = firestoreInstance
                .collection(normalizedEmail)
                .doc('customers')
                .collection('customers')
                .doc(newCustomerId);
            newCustomerSnapshot = await transaction.get(newCustomerDoc);
          }
        }

        // ✅ إعادة بناء الفاتورة القديمة باستخدام نوع الفاتورة الموثوق.
        final normalizedOldInvoice = InvoiceModel.fromJson({
          ...?oldData,
          'id': invoice.id,
          'type': oldType,
          'isSalesReturn': oldType == 'sales_return',
          if (oldType != 'sales_return') 'returnedItems': null,
        });

        // ✅ قراءة لقطات حية للمنتجات قبل أي كتابة
        // لضمان العزل (قاعدة 1 في رأس الملف):
        // نجمع معرفات المنتجات من القديمة والجديدة
        // ونقرأها مرة واحدة قبل أي كتابة، لأن عكس
        // القديمة وتطبيق الجديدة يقرآن نفس المستندات.
        final productIds = <String>{
          ..._collectTrackedProductIds(normalizedOldInvoice, products),
          ..._collectTrackedProductIds(invoice, products),
        };
        final productSnapshots = await _readProductSnapshotsInTransaction(
          transaction,
          normalizedEmail,
          productIds,
        );

        // ✅ التحقق من التغيير الصافي على المخزون قبل
        // أي كتابة (إصلاح 2 في رأس الملف): التغيير
        // الصافي (عكس القديمة + تطبيق الجديدة) لا
        // يجب أن يجعل كمية أي منتج سالبة قبل بدء
        // الكتابات. إذا فشل التحقق تفشل المعاملة
        // بالكامل ولا يُحدَّث شيء (الفاتورة ولا
        // المخزون) لضمان اتساق البيانات.
        final reverseChanges = _computeInventoryChangeForInvoice(
          invoice: normalizedOldInvoice,
          products: products,
          reverse: true,
        );
        final applyChanges = _computeInventoryChangeForInvoice(
          invoice: invoice,
          products: products,
          reverse: false,
        );
        final netChanges = <String, double>{};
        for (final entry in reverseChanges.entries) {
          netChanges[entry.key] = (netChanges[entry.key] ?? 0) + entry.value;
        }
        for (final entry in applyChanges.entries) {
          netChanges[entry.key] = (netChanges[entry.key] ?? 0) + entry.value;
        }
        for (final entry in netChanges.entries) {
          if (entry.value == 0) continue;
          final productSnapshot = productSnapshots[entry.key];
          if (productSnapshot == null || !productSnapshot.exists) {
            continue;
          }
          final productData = productSnapshot.data() as Map<String, dynamic>?;
          final liveQuantity =
              (productData?['quantity'] as num?)?.toDouble() ?? 0;
          final liveTrackQuantity =
              (productData?['trackQuantity'] as bool?) ?? true;
          if (!liveTrackQuantity) continue;
          if (liveQuantity + entry.value < 0) {
            throw Exception(
              'لا يمكن تحديث الفاتورة: الكمية النهائية لأحد المنتجات ستكون سالبة',
            );
          }
        }

        // ✅ عكس تأثير المخزون القديم داخل نفس الـ
        // transaction لضمان الذرية. ⚠️ الفاتورة
        // النقدية (cash) التي تحتوي على عناصر (مسار
        // "فاتورة بدون عميل" في صفحة الإنشاء)
        // تُخصم من المخزون عند الإنشاء مثل البيع
        // تماماً (_applyInventoryUpdatesForInvoice
        // يعالج cash)، لذلك يجب عكس تأثيرها هنا.
        // إذا استُثنيت cash تُخصم الكمية مرتين
        // (القديمة لا تُعاد والجديدة تُطبق) أو لا
        // تُعاد أبداً — انحراف مزمن في المخزون.
        if (oldType == 'sales_return' ||
            oldType == 'sales' ||
            oldType == 'purchase' ||
            (oldType == 'cash' && !normalizedOldInvoice.isCashAccountReceipt)) {
          await _reverseInventoryImpactInTransaction(
            transaction,
            normalizedOldInvoice,
            products,
            productSnapshots,
            applyChanges: applyChanges,
          );
        }

        // عكس أثر الصندوق القديم قبل تطبيق النسخة الجديدة؛
        // إضافة إيصال الحساب تتم عبر addInvoice في المستودع نفسه.
        if (oldPaidAmount.abs() > 0) {
          String oldDirection = 'in';
          String oldDescription = 'فاتورة #${invoice.invoiceNumber}';

          if (oldType == 'purchase') {
            oldDirection = 'out';
            oldDescription = 'فاتورة مشتريات #${invoice.invoiceNumber}';
          } else if (oldType == 'sales_return') {
            if (oldRefundMethod == 'cash') {
              oldDirection = 'out';
              oldDescription = 'مرجع بيع نقدي #${invoice.invoiceNumber}';
            } else {
              oldDirection = '';
              oldDescription = 'مرجع بيع كحساب #${invoice.invoiceNumber}';
            }
          } else if (oldType == 'cash') {
            if (oldPaidAmount < 0) {
              oldDirection = 'out';
              oldDescription = 'دفعة نقدية للعميل #${invoice.invoiceNumber}';
            } else {
              oldDirection = 'in';
              oldDescription = 'دفعة نقدية من العميل #${invoice.invoiceNumber}';
            }
          } else if (oldPaidAmount < 0) {
            oldDirection = 'out';
            oldDescription = 'تصفير حساب - فاتورة #${invoice.invoiceNumber}';
          }

          if (oldDirection.isNotEmpty) {
            final cashboxRef = firestoreInstance
                .collection(normalizedEmail)
                .doc('cashbox')
                .collection('balance')
                .doc('main');

            transaction.set(cashboxRef, {
              'currentBalance': FieldValue.increment(
                oldDirection == 'in'
                    ? -oldPaidAmount.abs()
                    : oldPaidAmount.abs(),
              ),
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedBy': invoice.updatedBy ?? invoice.createdBy,
            }, SetOptions(merge: true));
          }
        }

        // تطبيق أثر الصندوق الجديد بعد عكس حركة النسخة القديمة.
        if (invoice.paidAmount.abs() > 0) {
          String newDirection = 'in';
          String newDescription = 'فاتورة #${invoice.invoiceNumber}';

          if (invoice.type == 'purchase') {
            newDirection = 'out';
            newDescription = 'فاتورة مشتريات #${invoice.invoiceNumber}';
          } else if (invoice.type == 'sales_return') {
            if (invoice.refundMethod == 'cash') {
              newDirection = 'out';
              newDescription = 'مرجع بيع نقدي #${invoice.invoiceNumber}';
            } else {
              newDirection = '';
              newDescription = 'مرجع بيع كحساب #${invoice.invoiceNumber}';
            }
          } else if (invoice.type == 'cash') {
            if (invoice.paidAmount < 0) {
              newDirection = 'out';
              newDescription = 'دفعة نقدية للعميل #${invoice.invoiceNumber}';
            } else {
              newDirection = 'in';
              newDescription = 'دفعة نقدية من العميل #${invoice.invoiceNumber}';
            }
          } else if (invoice.paidAmount < 0) {
            newDirection = 'out';
            newDescription = 'تصفير حساب - فاتورة #${invoice.invoiceNumber}';
          }

          if (newDirection.isNotEmpty) {
            final newCashboxRef = firestoreInstance
                .collection(normalizedEmail)
                .doc('cashbox')
                .collection('balance')
                .doc('main');

            transaction.set(newCashboxRef, {
              'currentBalance': FieldValue.increment(
                newDirection == 'in'
                    ? invoice.paidAmount.abs()
                    : -invoice.paidAmount.abs(),
              ),
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedBy': invoice.updatedBy ?? invoice.createdBy,
            }, SetOptions(merge: true));
          }
        }

        // ✅ تطبيق تأثير الفاتورة الجديدة على دين العميل
        if (sameCustomer) {
          // ✅ نفس العميل: دمج عكس تأثير القديمة وتطبيق
          // تأثير الجديدة في عملية قراءة/كتابة واحدة
          // لمنع مشكلة عزل اللقطة (snapshot isolation)
          // — قاعدة 4 في رأس الملف: القراءة الثانية
          // لنفس المستند تعيد القيمة الأولية.
          if (newCustomerId.isNotEmpty) {
            double netChange = 0;

            // حساب التغيير القديم (للإزالة)
            // ⚠️ إشارات purchase — إصلاح 5 في رأس
            // الملف: purchase تنقص الدين في addInvoice
            // (نفس إشارة sales_return/credit)، فعكس
            // القديمة يزيد الدين (netChange +=
            // oldTotalAmount). لا تنسخ الإشارة من
            // sales أو cash.
            if (oldIsSalesReturn) {
              if (oldRefundMethod == 'credit') {
                netChange -= -oldTotalAmount;
              }
            } else if (oldType == 'cash' &&
                normalizedOldInvoice.isCashAccountReceipt) {
              netChange += oldPaidAmount; // عكس إيصال الحساب النقدي القديم
            } else if (oldType == 'sales' ||
                oldType == 'subscription' ||
                oldType == 'maintenance' ||
                oldType == 'rental') {
              netChange -= (oldTotalAmount - oldPaidAmount);
            } else if (oldType == 'purchase') {
              // ✅ عكس purchase يزيد الدين (undo). لا تُرجع إلى -=.
              netChange += oldTotalAmount;
            }

            // حساب التغيير الجديد (للإضافة)
            // ⚠️ نفس إشارة purchase (إصلاح 5):
            // تطبيق الجديدة ينقص الدين (netChange
            // -= invoice.totalAmount).
            if (invoice.isSalesReturn) {
              if (invoice.refundMethod == 'credit') {
                netChange += -invoice.totalAmount;
              }
            } else if (invoice.type == 'cash' && invoice.isCashAccountReceipt) {
              netChange -= invoice.paidAmount; // تطبيق إيصال الحساب النقدي
            } else if (invoice.type == 'sales' ||
                invoice.type == 'subscription' ||
                invoice.type == 'maintenance' ||
                invoice.type == 'rental') {
              netChange += invoice.remainingAmount;
            } else if (invoice.type == 'purchase') {
              // ✅ تطبيق purchase الجديدة ينقص الدين. لا تُرجع إلى +=.
              netChange -= invoice.totalAmount;
            }

            if (netChange != 0 &&
                newCustomerSnapshot != null &&
                newCustomerSnapshot.exists) {
              final customerData =
                  newCustomerSnapshot.data() as Map<String, dynamic>?;
              final currentDebt =
                  (customerData?['totalDebt'] as num?)?.toDouble() ?? 0;
              if (!currentDebt.isNaN && !currentDebt.isInfinite) {
                var finalDebt = currentDebt + netChange;

                if (!finalDebt.isNaN && !finalDebt.isInfinite) {
                  transaction.set(newCustomerSnapshot.reference, {
                    'totalDebt': finalDebt,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
              }
            }
          }
        } else {
          // ✅ عملاء مختلفون: عكس القديم وتطبيق الجديد بشكل منفصل
          if (oldCustomerId.isNotEmpty) {
            double oldAmountToReverse = 0;

            if (oldIsSalesReturn) {
              if (oldRefundMethod == 'credit') {
                oldAmountToReverse = -oldTotalAmount;
              }
            } else if (oldType == 'cash' &&
                normalizedOldInvoice.isCashAccountReceipt) {
              oldAmountToReverse = oldPaidAmount;
            } else if (oldType == 'sales' ||
                oldType == 'subscription' ||
                oldType == 'maintenance' ||
                oldType == 'rental') {
              oldAmountToReverse = oldTotalAmount - oldPaidAmount;
            } else if (oldType == 'purchase') {
              oldAmountToReverse = -oldTotalAmount;
            }

            if (oldAmountToReverse != 0 &&
                oldCustomerSnapshot != null &&
                oldCustomerSnapshot.exists) {
              final oldCustomerData =
                  oldCustomerSnapshot.data() as Map<String, dynamic>?;
              final oldCurrentDebt =
                  (oldCustomerData?['totalDebt'] as num?)?.toDouble() ?? 0;
              if (!oldCurrentDebt.isNaN && !oldCurrentDebt.isInfinite) {
                var reversedDebt = oldCurrentDebt;

                if (oldType == 'sales' ||
                    oldType == 'subscription' ||
                    oldType == 'maintenance' ||
                    oldType == 'rental') {
                  reversedDebt -= oldAmountToReverse;
                } else if (oldType == 'purchase') {
                  // ✅ عكس purchase يجب أن يزيد الدين (undo).
                  reversedDebt -= oldAmountToReverse;
                } else if (oldType == 'sales_return') {
                  reversedDebt -= oldAmountToReverse;
                } else if (oldType == 'cash' &&
                    normalizedOldInvoice.isCashAccountReceipt) {
                  reversedDebt += oldAmountToReverse;
                }

                if (!reversedDebt.isNaN && !reversedDebt.isInfinite) {
                  transaction.set(oldCustomerSnapshot.reference, {
                    'totalDebt': reversedDebt,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
              }
            }
          }

          // ✅ تطبيق تأثير الفاتورة الجديدة على دين العميل
          if (newCustomerId.isNotEmpty) {
            double newAmountToUpdate = 0;

            if (invoice.isSalesReturn) {
              if (invoice.refundMethod == 'credit') {
                newAmountToUpdate = -invoice.totalAmount;
              }
            } else if (invoice.type == 'cash' && invoice.isCashAccountReceipt) {
              newAmountToUpdate = invoice.paidAmount;
            } else if (invoice.type == 'sales' ||
                invoice.type == 'subscription' ||
                invoice.type == 'maintenance' ||
                invoice.type == 'rental') {
              newAmountToUpdate = invoice.remainingAmount;
            } else if (invoice.type == 'purchase') {
              newAmountToUpdate = -invoice.totalAmount;
            }

            if (newAmountToUpdate != 0 &&
                newCustomerSnapshot != null &&
                newCustomerSnapshot.exists) {
              final newCustomerData =
                  newCustomerSnapshot.data() as Map<String, dynamic>?;
              final newCurrentDebt =
                  (newCustomerData?['totalDebt'] as num?)?.toDouble() ?? 0;
              if (!newCurrentDebt.isNaN && !newCurrentDebt.isInfinite) {
                var updatedDebt = newCurrentDebt;

                if (invoice.type == 'sales' ||
                    invoice.type == 'subscription' ||
                    invoice.type == 'maintenance' ||
                    invoice.type == 'rental') {
                  updatedDebt += newAmountToUpdate;
                } else if (invoice.type == 'purchase') {
                  // ✅ تطبيق purchase الجديدة يجب أن ينقص الدين.
                  updatedDebt += newAmountToUpdate;
                } else if (invoice.type == 'sales_return') {
                  updatedDebt += newAmountToUpdate;
                } else if (invoice.type == 'cash' &&
                    invoice.isCashAccountReceipt) {
                  updatedDebt -= newAmountToUpdate;
                }

                if (!updatedDebt.isNaN && !updatedDebt.isInfinite) {
                  transaction.set(newCustomerSnapshot.reference, {
                    'totalDebt': updatedDebt,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
              }
            }
          }

          // ✅ نقل معرف الفاتورة بين مستندي العميل
          // عند تغيير العميل: إزالة المعرف من
          // القديم وإضافته للجديد داخل نفس
          // المعاملة (وإلا العميل القديم يبقى
          // يعرض الفاتورة والجديد لا يعرضها).
          // ✅ حراسة containsKey (نفس قاعدة
          // addInvoice الذهبية): arrayRemove/
          // arrayUnion على عميل بلا حقل
          // invoiceIds يُنشئه فارغاً/ناقصاً
          // فيفقد deleteCustomer كشفه بالاستعلام
          // الخارجي.
          if (oldCustomerId.isNotEmpty &&
              oldCustomerSnapshot != null &&
              oldCustomerSnapshot.exists &&
              (oldCustomerSnapshot.data() as Map<String, dynamic>?)
                      ?.containsKey('invoiceIds') ==
                  true) {
            transaction.set(oldCustomerSnapshot.reference, {
              'invoiceIds': FieldValue.arrayRemove([invoice.id]),
            }, SetOptions(merge: true));
          }
          // ✅ حراسة containsKey (نفس قاعدة addInvoice).
          if (newCustomerId.isNotEmpty &&
              newCustomerSnapshot != null &&
              newCustomerSnapshot.exists &&
              (newCustomerSnapshot.data() as Map<String, dynamic>?)
                      ?.containsKey('invoiceIds') ==
                  true) {
            transaction.set(newCustomerSnapshot.reference, {
              'invoiceIds': FieldValue.arrayUnion([invoice.id]),
            }, SetOptions(merge: true));
          }
        }

        // ✅ تحديث بيانات الفاتورة في النهاية
        // ✅ إصلاح 7 في رأس الملف: عند تحويل
        // الفاتورة من مرجع بيع إلى نوع آخر،
        // لا تُدرج toFirestore حقول مرجع البيع
        // (تُكتب شرطياً)، و update() لا تحذف
        // غير المذكور، فتظل عالقة وتُفسد
        // القراءات اللاحقة. نمسحها صراحةً هنا
        // ليبقى المستند متسقاً مع نوعه الحقيقي.
        // FieldValue.delete() مدعومة داخل
        // transaction.update.
        final updateData = model.toFirestore();
        if (!invoice.isSalesReturn) {
          updateData['isSalesReturn'] = false;
          updateData['returnedItems'] = FieldValue.delete();
          updateData['refundMethod'] = FieldValue.delete();
          updateData['originalInvoiceId'] = FieldValue.delete();
        }
        transaction.update(invoiceDoc, updateData);

        // ✅ تحديث relatedInvoiceIds في مستند الاشتراك
        // ذرياً عند التغيير: إذا تغير الاشتراك
        // المرتبط (أو النوع من/إلى 'subscription')
        // يجب إزالة المعرف من القديم وإضافته
        // للجديد داخل نفس المعاملة (وإلا بقيت
        // القائمة قديمة: حذف القديم لن يحذف
        // هذه الفاتورة أو حذف الجديد لن يحذفها).
        final oldSubscriptionId = oldData?['subscriptionId'] as String? ?? '';
        final newSubscriptionId = invoice.subscriptionId ?? '';
        final oldIsSubscription =
            oldType == 'subscription' && oldSubscriptionId.isNotEmpty;
        final newIsSubscription =
            invoice.type == 'subscription' && newSubscriptionId.isNotEmpty;

        if (oldIsSubscription &&
            (oldSubscriptionId != newSubscriptionId || !newIsSubscription)) {
          final oldSubscriptionDoc = firestoreInstance
              .collection(normalizedEmail)
              .doc('subscriptions')
              .collection('subscriptions')
              .doc(oldSubscriptionId);
          transaction.set(oldSubscriptionDoc, {
            'relatedInvoiceIds': FieldValue.arrayRemove([invoice.id]),
          }, SetOptions(merge: true));
        }

        if (newIsSubscription &&
            (oldSubscriptionId != newSubscriptionId || !oldIsSubscription)) {
          final newSubscriptionDoc = firestoreInstance
              .collection(normalizedEmail)
              .doc('subscriptions')
              .collection('subscriptions')
              .doc(newSubscriptionId);
          transaction.set(newSubscriptionDoc, {
            'relatedInvoiceIds': FieldValue.arrayUnion([invoice.id]),
          }, SetOptions(merge: true));
        }

        // ✅ تطبيق تحديثات المخزون الجديدة داخل نفس الـ transaction لضمان الذرية
        await _applyInventoryUpdatesForInvoice(
          transaction,
          invoice,
          products,
          productSnapshots,
          reverseChanges: reverseChanges,
        );

        // ✅ إنشاء سجل النشاط داخل نفس الـ transaction لضمان الذرية
        await _createInvoiceLogInTransaction(transaction, normalizedEmail, {
          'userId': invoice.updatedBy ?? invoice.createdBy,
          'actionType': 'update_invoice',
          'timestamp': FieldValue.serverTimestamp(),
          'details': 'تم تحديث الفاتورة: ${invoice.invoiceNumber}',
          'targetId': invoice.id,
          'targetType': 'invoice',
          'newValues': {
            'invoiceNumber': invoice.invoiceNumber,
            'customerName': invoice.customerName,
            'customerPhone': invoice.customerPhone,
            'totalAmount': invoice.totalAmount,
            'paidAmount': invoice.paidAmount,
            'remainingAmount': invoice.remainingAmount,
            'status': invoice.status,
            'invoiceDate': invoice.invoiceDate.toIso8601String(),
            'type': invoice.type,
          },
          'isSuccess': true,
        });
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> archiveCustomerInvoices({
    required String organizationEmail,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String createdBy,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final invoicesCollection = _getInvoicesCollection(normalizedEmail);

      final snapshot = await invoicesCollection
          .where('customerId', isEqualTo: customerId)
          .where('isArchived', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        return const Right(null);
      }

      final now = DateTime.now();

      // ✅ جلب الفواتير خارج الـ transaction
      // (قاعدة 2 في رأس الملف: لا
      // استعلامات داخل transaction)
      // لأننا نحتاج إلى معرفة عددها
      // لإنشاء سجل النشاط. إذا تم
      // حذف فاتورة بين الجلب والتنفيذ
      // ستفشل المعاملة ولن تُأرشف أي
      // فاتورة، لذا البيانات تظل متسقة.
      // هذه العملية أرشفة فقط — لتصفير
      // الدين أيضاً استخدم
      // clearCustomerAccount.
      await firestore.runTransaction((transaction) async {
        // ✅ أرشفة جميع فواتير العميل
        // داخل نفس الـ transaction
        // لضمان الذرية (إذا فشل أي
        // فاتورة لن تُأرشف أي فاتورة
        // على الإطلاق).
        for (final doc in snapshot.docs) {
          transaction.update(doc.reference, {
            'isArchived': true,
            'updatedAt': Timestamp.fromDate(now),
          });
        }

        // ✅ إنشاء سجل نشاط الأرشفة داخل نفس الـ transaction لضمان الذرية
        await _createInvoiceLogInTransaction(transaction, normalizedEmail, {
          'userId': createdBy,
          'actionType': 'archive_customer_invoices',
          'timestamp': FieldValue.serverTimestamp(),
          'details':
              'تم أرشفة ${snapshot.docs.length} فاتورة للعميل: $customerName',
          'targetId': customerId,
          'targetType': 'customer_invoices',
          'newValues': {
            'customerId': customerId,
            'customerName': customerName,
            'archivedCount': snapshot.docs.length,
          },
          'isSuccess': true,
        });
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ✅ عملية تصفير حساب العميل وتأثيراتها
  // على الصندوق والمخزون يجب أن تكون
  // ذرية بالكامل داخل runTransaction.
  // لا تنفذ أجزاء من هذه العملية
  // خارج الـ Repository لأن ذلك
  // سيؤدي إلى بيانات غير متسقة.
  // ✅ هذه العملية تنشئ سجل نشاط
  // (invoice log) تلقائياً داخل
  // الـ transaction لضمان الذرية.
  @override
  Future<Either<Failure, Map<String, dynamic>>> clearCustomerAccount({
    required String organizationEmail,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String createdBy,
    required double debtAmount,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;
      final invoicesCollection = _getInvoicesCollection(normalizedEmail);

      final snapshot = await invoicesCollection
          .where('customerId', isEqualTo: customerId)
          .where('isArchived', isEqualTo: false)
          .get();

      final now = DateTime.now();
      final invoiceId = invoicesCollection.doc().id;
      final invoiceNumber = InvoiceNumberingService.generateNumberSync(
        section: 'account_clearance',
      );

      final isDebit = debtAmount > 0;
      final isCredit = debtAmount < 0;
      double totalAmount, paidAmount;
      String description;

      if (isDebit) {
        totalAmount = debtAmount.abs();
        paidAmount = debtAmount.abs();
        description = 'تصفير حساب - استلام مبلغ ${debtAmount.abs()} من العميل';
      } else if (isCredit) {
        totalAmount = debtAmount.abs();
        paidAmount = -debtAmount.abs();
        description = 'تصفير حساب - إعطاء مبلغ ${debtAmount.abs()} للعميل';
      } else {
        totalAmount = 0;
        paidAmount = 0;
        description = 'تصفير حساب - حساب متوازن';
      }

      await firestoreInstance.runTransaction((transaction) async {
        // ✅ جلب بيانات العميل داخل نفس الـ
        // transaction لضمان أن
        // balanceBeforeInvoice دقيق (قُلِبت
        // من خارج المعاملة إلى داخلها
        // لجعل العملية ذرية بالكامل —
        // إذا تغير الدين بين الجلب
        // والتنفيذ تكون القيمة دقيقة
        // دائماً). totalDebt = 0 تظل
        // صحيحة لأننا نكتبها داخل
        // المعاملة.
        final customerDoc = _getCustomerDocRef(normalizedEmail, customerId);
        final customerSnapshot = await transaction.get(customerDoc);
        final customerData = customerSnapshot.data() as Map<String, dynamic>?;
        final currentDebt =
            (customerData?['totalDebt'] as num?)?.toDouble() ?? 0;
        final balanceBeforeInvoice = currentDebt;
        final balanceAfterInvoice = 0.0;

        final invoiceData = {
          'id': invoiceId,
          'invoiceNumber': invoiceNumber,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'customerId': customerId,
          'invoiceDate': Timestamp.fromDate(now),
          'totalAmount': totalAmount,
          'paidAmount': paidAmount,
          'remainingAmount': 0,
          'status': 'paid',
          'type': 'cash',
          'items': [],
          'cashTransactionType': 'clearance',
          'cashAmount': totalAmount,
          'notes':
              'فاتورة تصفير حساب - تم تصفير الحساب وأرشفة جميع الفواتير الحالية',
          'organizationEmail': organizationEmail,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'createdBy': createdBy,
          'balanceBeforeInvoice': balanceBeforeInvoice,
          'balanceAfterInvoice': balanceAfterInvoice,
          'isArchived': true,
        };

        // ✅ أرشفة جميع فواتير العميل داخل نفس الـ transaction لضمان الذرية
        // (نفس ضمان الأرشفة في archiveCustomerInvoices: إما أرشفة الكل أو فشل الكل).
        for (final doc in snapshot.docs) {
          transaction.update(doc.reference, {
            'isArchived': true,
            'updatedAt': Timestamp.fromDate(now),
          });
        }

        final invoiceDoc = invoicesCollection.doc(invoiceId);
        transaction.set(invoiceDoc, invoiceData);

        if (customerSnapshot.exists) {
          // ✅ تصفير دين العميل داخل
          // نفس الـ transaction لضمان
          // الذرية (إذا فشل أي جزء
          // لن يتم تصفير الدين).
          transaction.set(customerDoc, {
            'totalDebt': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          // ✅ حراسة containsKey (نفس
          // قاعدة addInvoice الذهبية):
          // لا تُنشئ invoiceIds على
          // عميل قديم بلاها — فاتورة
          // التصفير تُربط بالعميل عبر
          // customerId في بياناتها
          // فيُجدها استعلام التوافق
          // الخارجي في deleteCustomer.
          if ((customerSnapshot.data() as Map<String, dynamic>?)?.containsKey(
                'invoiceIds',
              ) ==
              true) {
            transaction.set(customerDoc, {
              'invoiceIds': FieldValue.arrayUnion([invoiceId]),
            }, SetOptions(merge: true));
          }
        }

        if (paidAmount.abs() > 0) {
          final cashboxRef = _getCashboxDocRef(normalizedEmail);
          final direction = isDebit ? 'in' : 'out';
          // ✅ تحديث الصندوق داخل
          // نفس الـ transaction لضمان
          // الذرية (إذا فشل أي جزء
          // لن يتم تحديث الصندوق).
          transaction.set(cashboxRef, {
            'currentBalance': FieldValue.increment(
              direction == 'in' ? paidAmount.abs() : -paidAmount.abs(),
            ),
            'lastUpdated': FieldValue.serverTimestamp(),
            'updatedBy': createdBy,
          }, SetOptions(merge: true));
        }

        // ✅ إنشاء سجل نشاط التصفير داخل نفس الـ transaction لضمان الذرية
        await _createInvoiceLogInTransaction(transaction, normalizedEmail, {
          'userId': createdBy,
          'actionType': 'clear_customer_account',
          'timestamp': FieldValue.serverTimestamp(),
          'details': 'تم تصفير حساب العميل: $customerName بمبلغ $debtAmount',
          'targetId': customerId,
          'targetType': 'customer_account',
          'newValues': {
            'customerId': customerId,
            'customerName': customerName,
            'debtAmount': debtAmount,
            'archivedCount': snapshot.docs.length,
          },
          'isSuccess': true,
        });
      });

      return Right({
        'invoiceId': invoiceId,
        'invoiceNumber': invoiceNumber,
        'archivedCount': snapshot.docs.length,
      });
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInvoice(
    String id,
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final firestoreInstance = FirebaseFirestore.instance;

      // ✅ جلب المنتجات قبل الـ transaction لاستخدامها
      // في عكس تأثير المخزون (قاعدة 2 في رأس
      // الملف: Firestore لا تدعم قراءة Collections
      // داخل transaction). productId يُستخدم
      // للبحث بالمعرف داخل transaction مباشرة،
      // والاسم احتياطي للفواتير القديمة.
      final products = <ProductEntity>[];
      if (productRepository != null) {
        final productsResult = await productRepository!.getProducts(
          organizationEmail: normalizedEmail,
        );
        products.addAll(productsResult.getOrElse(() => []));
      }

      await firestoreInstance.runTransaction((transaction) async {
        final invoiceDoc = _getInvoicesCollection(normalizedEmail).doc(id);

        // قراءة بيانات الفاتورة قبل الحذف لمعرفة تأثيرها
        final docSnapshot = await transaction.get(invoiceDoc);

        if (!docSnapshot.exists) {
          throw Exception('الفاتورة غير موجودة');
        }

        final invoiceData = docSnapshot.data() as Map<String, dynamic>?;
        // ✅ ملاحظة للمبرمجين المستقبليين:
        // invoiceData تم تحويله إلى Map<String, dynamic>? أعلاه.
        // جميع الوصولات التالية لـ invoiceData?['...'] مقصودة
        // ومُحوّلة إلى النوع المناسب يدوياً.
        final customerId = invoiceData?['customerId'] as String? ?? '';
        final type = invoiceData?['type'] as String? ?? '';
        final paidAmount =
            (invoiceData?['paidAmount'] as num?)?.toDouble() ?? 0;
        final totalAmount =
            (invoiceData?['totalAmount'] as num?)?.toDouble() ?? 0;
        final refundMethod = invoiceData?['refundMethod'] as String? ?? '';
        final isSalesReturn = type == 'sales_return';
        final oldInvoice = InvoiceModel.fromJson({
          ...?invoiceData,
          'id': id,
          'type': type,
          'isSalesReturn': isSalesReturn,
          if (!isSalesReturn) 'returnedItems': null,
        });

        // ✅ قراءة بيانات العميل قبل أي عملية
        // كتابة لضمان compliance مع Firestore
        // (يجب أن تكون جميع القراءات قبل
        // جميع العمليات الكتابية في المعاملة)
        // ✅ إصلاح 8 في رأس الملف: قراءة
        // مستند العميل دائماً عند وجود معرف
        // عميل (لا تشترط amountToReverse != 0)
        // — invoiceIds يجب أن يُحذف معرف
        // الفاتورة منه لكل فاتورة مرتبطة
        // بالعميل حتى لو كان أثرها على الدين
        // صفراً (فاتورة مُسددة بالكامل، أو
        // فاتورة/شراء بصفر) وإلا بقيت مرجعاً
        // يتيمة في قائمة فواتير العميل. تحديث
        // الدين فقط يبقى مشروطاً بـ
        // amountToReverse != 0 (لا معنى لعكس
        // دين بصفر). القراءة قبل أي كتابة
        // (قاعدة Firestore) محفوظة.
        DocumentReference? customerDocRef;
        DocumentSnapshot? customerSnapshot;
        double amountToReverse = 0;

        if (customerId.isNotEmpty) {
          if (isSalesReturn) {
            if (refundMethod == 'credit') {
              amountToReverse = -totalAmount;
            }
          } else if (type == 'cash') {
            amountToReverse = oldInvoice.isCashAccountReceipt
                ? paidAmount
                : -totalAmount;
          } else if (type == 'sales' ||
              type == 'subscription' ||
              type == 'maintenance' ||
              type == 'rental') {
            amountToReverse = totalAmount - paidAmount;
          } else if (type == 'purchase') {
            amountToReverse = -totalAmount;
          }

          customerDocRef = firestoreInstance
              .collection(normalizedEmail)
              .doc('customers')
              .collection('customers')
              .doc(customerId);

          customerSnapshot = await transaction.get(customerDocRef);
        }

        // ✅ قراءة لقطات حية للمنتجات قبل أي
        // كتابة لضمان العزل (قاعدة 1 في رأس
        // الملف): يجب أن تكون هذه القراءات
        // قبل أول عملية كتابة (تحديث الصندوق
        // أدناه) لأن Firestore يفرض ترتيب
        // القراءات قبل الكتابات داخل المعاملة.
        final productIds = _collectTrackedProductIds(oldInvoice, products);
        final productSnapshots = await _readProductSnapshotsInTransaction(
          transaction,
          normalizedEmail,
          productIds,
        );

        // عكس حركة الصندوق عند حذف الفاتورة؛ تشمل إيصالات الحساب.
        // إلغاء حركة الصندوق للفواتير العادية؛ إيصالات الحساب
        // أنشأتها معاملة مسار العميل ولا تُسجل هنا مرة ثانية.
        if (paidAmount.abs() > 0 &&
            (type != 'cash' || !oldInvoice.isCashAccountReceipt)) {
          String direction = 'in';
          String description = 'فاتورة #${invoiceData?['invoiceNumber'] ?? id}';

          if (type == 'purchase') {
            direction = 'out';
            description =
                'فاتورة مشتريات #${invoiceData?['invoiceNumber'] ?? id}';
          } else if (type == 'sales_return') {
            if (refundMethod == 'cash') {
              direction = 'out';
              description =
                  'مرجع بيع نقدي #${invoiceData?['invoiceNumber'] ?? id}';
            } else {
              direction = '';
              description =
                  'مرجع بيع كحساب #${invoiceData?['invoiceNumber'] ?? id}';
            }
          } else if (type == 'cash') {
            if (paidAmount < 0) {
              direction = 'out';
              description =
                  'دفعة نقدية للعميل #${invoiceData?['invoiceNumber'] ?? id}';
            } else {
              direction = 'in';
              description =
                  'دفعة نقدية من العميل #${invoiceData?['invoiceNumber'] ?? id}';
            }
          } else if (paidAmount < 0) {
            direction = 'out';
            description =
                'تصفير حساب - فاتورة #${invoiceData?['invoiceNumber'] ?? id}';
          }

          if (direction.isNotEmpty) {
            final cashboxRef = firestoreInstance
                .collection(normalizedEmail)
                .doc('cashbox')
                .collection('balance')
                .doc('main');

            transaction.set(cashboxRef, {
              'currentBalance': FieldValue.increment(
                direction == 'in' ? -paidAmount.abs() : paidAmount.abs(),
              ),
              'lastUpdated': FieldValue.serverTimestamp(),
              'updatedBy': invoiceData?['createdBy'] ?? 'system',
            }, SetOptions(merge: true));
          }
        }

        // عكس تأثير الفاتورة على دين العميل
        // (داخل نفس الـ transaction لضمان
        // الذرية — إذا فشل أي جزء لن
        // يُعكس أي شيء على دين العميل)
        if (customerDocRef != null &&
            customerSnapshot != null &&
            customerSnapshot.exists &&
            amountToReverse != 0) {
          final customerData = customerSnapshot.data() as Map<String, dynamic>?;
          final currentDebt =
              (customerData?['totalDebt'] as num?)?.toDouble() ?? 0;
          if (!currentDebt.isNaN && !currentDebt.isInfinite) {
            var newTotalDebt = currentDebt;

            if (type == 'sales' ||
                type == 'subscription' ||
                type == 'maintenance' ||
                type == 'rental') {
              newTotalDebt -= amountToReverse;
            } else if (type == 'purchase') {
              // ✅ عكس purchase يزيد الدين (undo) —
              // إصلاح 5 في رأس الملف. لا تُرجع إلى +=.
              newTotalDebt -= amountToReverse;
            } else if (type == 'sales_return') {
              newTotalDebt -= amountToReverse;
            } else if (type == 'cash') {
              newTotalDebt += amountToReverse;
            }

            if (!newTotalDebt.isNaN && !newTotalDebt.isInfinite) {
              transaction.set(customerDocRef, {
                'totalDebt': newTotalDebt,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          }
        }

        // ✅ حذف معرف الفاتورة من قائمة
        // الفواتير في مستند العميل ذرياً
        // ✅ حراسة containsKey (نفس قاعدة
        // addInvoice الذهبية): arrayRemove
        // على عميل بلا حقل invoiceIds
        // يُنشئه فارغاً فيفقد deleteCustomer
        // كشفه بالاستعلام الخارجي.
        if (customerDocRef != null &&
            customerSnapshot != null &&
            customerSnapshot.exists &&
            (customerSnapshot.data() as Map<String, dynamic>?)?.containsKey(
                  'invoiceIds',
                ) ==
                true) {
          transaction.set(customerDocRef, {
            'invoiceIds': FieldValue.arrayRemove([id]),
          }, SetOptions(merge: true));
        }

        // ✅ عكس تأثير المخزون داخل نفس الـ
        // transaction لضمان الذرية. ⚠️
        // الفاتورة النقدية (cash) التي تحتوي
        // على عناصر (مسار "فاتورة بدون عميل"
        // في صفحة الإنشاء) تُخصم من المخزون
        // عند الإنشاء مثل البيع تماماً،
        // لذلك يجب عكس تأثيرها هنا عند
        // الحذف. إذا استُثنيت cash تبقى
        // الكمية مخصومة لفاتورة لم تعد
        // موجودة — انحراف مزمن في المخزون.
        if (type == 'sales_return' ||
            type == 'sales' ||
            type == 'purchase' ||
            (type == 'cash' && !oldInvoice.isCashAccountReceipt)) {
          await _reverseInventoryImpactInTransaction(
            transaction,
            oldInvoice,
            products,
            productSnapshots,
          );
        }

        // ✅ إنشاء سجل النشاط داخل نفس الـ transaction لضمان الذرية
        await _createInvoiceLogInTransaction(transaction, normalizedEmail, {
          'userId': invoiceData?['createdBy'] ?? 'system',
          'actionType': 'delete_invoice',
          'timestamp': FieldValue.serverTimestamp(),
          'details': 'تم حذف الفاتورة',
          'targetId': id,
          'targetType': 'invoice',
          'oldValues': {
            'invoiceNumber': invoiceData?['invoiceNumber'] ?? id,
            'customerName': invoiceData?['customerName'] ?? '',
            'customerPhone': invoiceData?['customerPhone'] ?? '',
            'totalAmount': invoiceData?['totalAmount'] ?? 0,
            'paidAmount': invoiceData?['paidAmount'] ?? 0,
            'remainingAmount': invoiceData?['remainingAmount'] ?? 0,
            'status': invoiceData?['status'] ?? '',
            'type': invoiceData?['type'] ?? '',
          },
          'isSuccess': true,
        });

        // ✅ إزالة معرف الفاتورة من
        // relatedInvoiceIds في مستند
        // الاشتراك ذرياً: إذا كانت الفاتورة
        // مرتبطة باشتراك، يجب إزالة معرفها
        // داخل نفس المعاملة (وإلا بقيت
        // القائمة قديمة وحذف الاشتراك
        // لاحقاً سيحاول حذف فاتورة غير
        // موجودة).
        final subscriptionId = invoiceData?['subscriptionId'] as String? ?? '';
        if (subscriptionId.isNotEmpty) {
          final subscriptionDoc = firestoreInstance
              .collection(normalizedEmail)
              .doc('subscriptions')
              .collection('subscriptions')
              .doc(subscriptionId);
          transaction.set(subscriptionDoc, {
            'relatedInvoiceIds': FieldValue.arrayRemove([id]),
          }, SetOptions(merge: true));
        }

        // حذف الفاتورة في النهاية
        transaction.delete(invoiceDoc);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, InvoiceStatsEntity>> getInvoiceStats(
    String organizationEmail, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      Query query = _getInvoicesCollection(
        normalizedEmail,
      ).where('isArchived', isEqualTo: false);

      if (startDate != null || endDate != null) {
        query = query.orderBy('createdAt', descending: true);
      }

      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await _handleFirestoreError(
        query.get(),
        'invoices stats (isArchived + createdAt)',
      );

      final allInvoices = snapshot.docs
          .map(InvoiceModel.fromFirestore)
          .toList();

      final invoices = allInvoices;

      final totalInvoices = invoices.length;
      final paidInvoices = invoices.where((i) => i.isPaid).length;
      final unpaidInvoices = invoices
          .where((i) => i.status == 'unpaid' || i.status == 'partial')
          .length;
      // الفواتير الملغاة تُحتسب في totalInvoices فقط، وليس في paidInvoices أو unpaidInvoices.
      // هذا توثيق للسلوك الحالي.
      // ⚠️ ملاحظة للمبرمجين المستلمين — عداد الفواتير المتأخرة:
      // تُحسب الفاتورة "متأخرة" إذا كان لديها remainingAmount > 0
      // وحالتها unpaid أو partial، بدون التحقق من تاريخ الاستحقاق الفعلي.
      // لإضافة فحص dueDate، يجب إضافة الحقل إلى InvoiceEntity و InvoiceModel
      // وفهرس Firestore المقابل.
      final overdueInvoices = invoices
          .where(
            (i) =>
                i.remainingAmount > 0 &&
                (i.status == 'unpaid' || i.status == 'partial'),
          )
          .length;

      // ⚠️ ملاحظة للمبرمجين المستلمين — عداد الفواتير المدفوعة/غير المدفوعة:
      // الفواتير ذات الحالة 'cancelled' لا تُحتسب في paidInvoices ولا في
      // unpaidInvoices، لكن تُحتسب في totalInvoices. لذلك لا يتحقق الشرط
      // totalInvoices == paidInvoices + unpaidInvoices عند وجود فواتير ملغاة.
      // هذا يُسبب تفاوتًا في الإحصائيات المعروضة. يُنصح بإضافة حالّة cancelled
      // إلى العداد المناسب أو توثيق هذا السلوك في واجهة المستخدم.

      double totalRevenue = 0;
      double totalPaid = 0;
      double totalRemaining = 0;

      // ✅ مجموعات الأنواع مطابقة لمنطق الدين
      // (إصلاح 5 في رأس الملف): maintenance
      // و rental إيراد مثل sales، و
      // sales_return تُطرح مثل purchase
      // (تعكس بيعاً). فاتورة مرجع البيع
      // تُنشأ مدفوعة بالكامل (paidAmount =
      // totalAmount و remainingAmount = 0)
      // فطرحها يصحح الإيراد والمدفوع دون
      // أن يمس المتبقي.
      for (final invoice in invoices) {
        if (invoice.type == 'sales' ||
            invoice.type == 'subscription' ||
            invoice.type == 'cash' ||
            invoice.type == 'maintenance' ||
            invoice.type == 'rental') {
          totalRevenue += invoice.totalAmount;
          totalPaid += invoice.paidAmount.abs();
          totalRemaining += invoice.calculateRemainingAmount();
        } else if (invoice.type == 'purchase' ||
            invoice.type == 'sales_return') {
          totalRevenue -= invoice.totalAmount;
          totalPaid -= invoice.paidAmount.abs();
          totalRemaining -= invoice.calculateRemainingAmount();
        }
      }

      return Right(
        InvoiceStatsEntity(
          totalInvoices: totalInvoices,
          paidInvoices: paidInvoices,
          unpaidInvoices: unpaidInvoices,
          overdueInvoices: overdueInvoices,
          totalRevenue: totalRevenue,
          totalPaid: totalPaid,
          totalRemaining: totalRemaining,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ===== Invoice Logs Methods =====

  String? _getCurrentOrganizationId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;
    final emailService = EmailNormalizationService();
    return emailService.normalize(user!.email!);
  }

  @override
  Future<Either<Failure, List<InvoiceLogEntity>>> getInvoiceLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('invoices')
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

      if (limit != null) {
        query = query.limit(limit);
      }

      // ترتيب النتائج
      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();
      final logs = <InvoiceLogEntity>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        final log = InvoiceLogModel.fromJson({
          'id': doc.id,
          ...mapData,
        }).toEntity();

        // تطبيق البحث النصي
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          final matchesSearch =
              (log.userName?.toLowerCase().contains(query) ?? false) ||
              (log.userEmail?.toLowerCase().contains(query) ?? false) ||
              (log.actionType.toLowerCase().contains(query)) ||
              (log.details?.toLowerCase().contains(query) ?? false);

          if (matchesSearch) {
            logs.add(log);
          }
        } else {
          logs.add(log);
        }
      }

      return Right(logs);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Stream<Either<Failure, List<InvoiceLogEntity>>> getInvoiceLogsStream({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      Query query = firestore
          .collection(organizationId)
          .doc('invoices')
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

      if (limit != null) {
        query = query.limit(limit);
      }

      // ترتيب النتائج
      query = query.orderBy('timestamp', descending: true);

      return query
          .snapshots()
          .map((snapshot) {
            final logs = <InvoiceLogEntity>[];

            for (final doc in snapshot.docs) {
              final data = doc.data();
              if (data == null) continue;
              final mapData = data as Map<String, dynamic>;
              final log = InvoiceLogModel.fromJson({
                'id': doc.id,
                ...mapData,
              }).toEntity();

              // تطبيق البحث النصي
              if (searchQuery != null && searchQuery.isNotEmpty) {
                final query = searchQuery.toLowerCase();
                final matchesSearch =
                    (log.userName?.toLowerCase().contains(query) ?? false) ||
                    (log.userEmail?.toLowerCase().contains(query) ?? false) ||
                    (log.actionType.toLowerCase().contains(query)) ||
                    (log.details?.toLowerCase().contains(query) ?? false);

                if (matchesSearch) {
                  logs.add(log);
                }
              } else {
                logs.add(log);
              }
            }

            return Right<Failure, List<InvoiceLogEntity>>(logs);
          })
          .handleError((error) {
            return Left<Failure, List<InvoiceLogEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Future<Either<Failure, InvoiceLogEntity>> addInvoiceLog({
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
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

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

      final docRef = await firestore
          .collection(organizationId)
          .doc('invoices')
          .collection('logs')
          .add(logData);

      final snapshot = await docRef.get();
      final snapshotData = snapshot.data();
      if (snapshotData == null) {
        return const Left(
          ServerFailure(message: 'فشل في قراءة سجل النشاط بعد إنشائه'),
        );
      }
      final log = InvoiceLogModel.fromJson({
        'id': docRef.id,
        ...snapshotData,
      }).toEntity();

      return Right(log);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInvoiceLog(String logId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      await firestore
          .collection(organizationId)
          .doc('invoices')
          .collection('logs')
          .doc(logId)
          .delete();

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> clearInvoiceLogs({
    String? userId,
    DateTime? beforeDate,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('invoices')
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
      final batch = firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ===== Invoice Template Methods =====
  // القوالب محلية فقط ولا تُخزن في Firebase

  @override
  Future<Either<Failure, List<InvoiceTemplateEntity>>> getInvoiceTemplates(
    String organizationEmail,
  ) async {
    // إرجاع القوالب المحلية الافتراضية مباشرة
    return Right(_getAllDefaultTemplates());
  }

  @override
  Future<Either<Failure, InvoiceTemplateEntity>> getTemplateByType(
    String organizationEmail,
    String type,
  ) async {
    // إرجاع القالب الافتراضي المحلي حسب النوع
    return Right(_getDefaultTemplate(type));
  }

  @override
  Future<Either<Failure, void>> saveInvoiceTemplate(
    InvoiceTemplateEntity template,
    String organizationEmail,
  ) async {
    // 🔧 ملاحظة للمبرمجين المستقبليين:
    // هذا الحفظ محلي فقط (لا يُكتب في Firebase). القالب يُحفظ في الذاكرة
    // المؤقتة أثناء جلسة التطبيق فقط ويضيع عند إعادة التشغيل.
    // لتفعيل الديمومة، أضف حفظ عبر SharedPreferences أو Hive.
    return const Right(null);
  }

  @override
  Future<Either<Failure, InvoiceTemplateEntity>> getTemplateById(
    String organizationEmail,
    String templateId,
  ) async {
    // 🔧 ملاحظة للمبرمجين المستقبليين:
    // إذا لم يُوجد القالب بالمعرف المطلوب، تُعاد القالب الافتراضي الصامتاً
    // دون إشعار بالخطأ. يمكن تعديل ذلك لإرجاع Failure إذا لزم الأمر.
    final templates = _getAllDefaultTemplates();
    final template = templates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => _getSingleDefaultTemplate(),
    );
    return Right(template);
  }

  @override
  Future<Either<Failure, void>> deleteInvoiceTemplate(
    String templateId,
    String organizationEmail,
  ) async {
    // 🔧 ملاحظة للمبرمجين المستقبليين:
    // الحذف محلي فقط ولا يُنفذ أي عملية في Firebase. القوالب المحلية
    // الثابتة لا يمكن حذفها. هذه العملية ناجحة دائماً (تُعيد Right(null)).
    return const Right(null);
  }

  /// الحصول على القالب الافتراضي الوحيد
  InvoiceTemplateEntity _getSingleDefaultTemplate() {
    return ClassicInvoiceTemplate.create();
  }

  /// الحصول على جميع القوالب الافتراضية
  List<InvoiceTemplateEntity> _getAllDefaultTemplates() {
    return [
      ClassicInvoiceTemplate.create(), // القالب الكلاسيكي
      ModernInvoiceTemplate.create(), // القالب العصري
      ProfessionalInvoiceTemplate.create(), // القالب الاحترافي
      ColorfulInvoiceTemplate.create(), // القالب الملون - جديد
      ElegantInvoiceTemplate.create(), // القالب الأنيق - جديد
      MinimalInvoiceTemplate.create(), // القالب البسيط - جديد
    ];
  }

  /// الحصول على قالب افتراضي حسب النوع (مستخدم في getTemplateByType)
  InvoiceTemplateEntity _getDefaultTemplate(String type) {
    final template = ClassicInvoiceTemplate.create();
    // نستخدم نفس القالب الكلاسيكي مع تغيير النوع فقط
    return template.copyWith(
      id: 'default_$type',
      type: type,
      isDefault: type == 'sales',
    );
  }

  // ============================================================
  // منطق تحديث/عكس المخزون
  // ============================================================

  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// تم نقل منطق تحديث المخزون وعكسه من InvoiceBloc إلى هنا
  /// داخل runTransaction في addInvoice/updateInvoice/deleteInvoice.
  /// السبب: تحديث المخزون مترابط بتاتاً مع الفاتورة،
  /// ويجب إما نجاح الكل أو فشل الكل لضمان اتساق البيانات.
  /// لا تنقل هذا المنطق مرة أخرى إلى BLoC لأن ذلك سيعيد المشكلة.

  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// هذه الدالة تفضل البحث بالمعرف (productId) ثم بالاسم كاحتياطي.
  /// السبب: بعد إضافة حقل productId إلى InvoiceItemEntity،
  /// يمكن جلب المنتج مباشرة داخل transaction بدون الاعتماد على الاسم فقط.
  /// إذا كان productId مفقوداً أو غير صالح، نعود للبحث بالاسم للحفاظ على التوافق مع الفواتير القديمة.
  ProductEntity? _findProduct(
    List<ProductEntity> products, {
    String? productId,
    String? productName,
  }) {
    // 1. البحث بالمعرف أولاً إن وُجد
    if (productId != null && productId.isNotEmpty) {
      final found = products.firstWhereOrNull((p) => p.id == productId);
      if (found != null) return found;
    }

    // 2. الاحتياطي: البحث بالاسم
    if (productName == null || productName.isEmpty) return null;

    final normalizedName = productName.trim().toLowerCase();

    for (final product in products) {
      final name = product.name.trim().toLowerCase();
      if (name == normalizedName) {
        return product;
      }
    }

    for (final product in products) {
      final name = product.name.trim().toLowerCase();
      if (name.contains(normalizedName) || normalizedName.contains(name)) {
        return product;
      }
    }

    return null;
  }

  /// Resolve returned items while avoiding fuzzy name matching for manually
  /// entered returns. An unlinked manual return must never change an unrelated
  /// inventory product just because its name is similar.
  ProductEntity? _findReturnedItemProduct(
    List<ProductEntity> products,
    ReturnedItemEntity returnedItem,
  ) {
    if (returnedItem.itemId.startsWith('manual_return_')) {
      final productId = returnedItem.productId;
      if (productId == null || productId.isEmpty) return null;
      return products.firstWhereOrNull((product) => product.id == productId);
    }

    return _findProduct(
      products,
      productId: returnedItem.productId,
      productName: returnedItem.itemName,
    );
  }

  /// حساب إجمالي تغيير الكمية لكل منتج لفاتورة (بدون كتابة)
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين (إصلاح 2026-10-08):
  /// تُستخدم هذه الدالة للتحقق من التغيير الصافي في
  /// updateInvoice قبل بدء الكتابات. تُجمّع التغييرات
  /// حسب معرف المنتج بنفس منطق _applyInventoryUpdatesForInvoice
  /// و _reverseInventoryImpactInTransaction لكن بدون كتابة.
  /// [reverse] = true لحساب عكس التأثير (حذف/تحديث القديمة)،
  /// و false لتطبيق التأثير (الجديدة).
  Map<String, double> _computeInventoryChangeForInvoice({
    required InvoiceEntity invoice,
    required List<ProductEntity> products,
    required bool reverse,
  }) {
    final changes = <String, double>{};

    void addChange(String productId, double quantityChange) {
      changes[productId] = (changes[productId] ?? 0) + quantityChange;
    }

    // مرجع البيع: يعتمد على العناصر المرتجعة
    if (invoice.isSalesReturn) {
      for (final returnedItem in invoice.returnedItems ?? []) {
        final product = _findReturnedItemProduct(products, returnedItem);
        if (product == null || product.id.isEmpty || !product.trackQuantity) {
          continue;
        }
        // عكس مرجع البيع يخصم الكمية، تطبيقه يعيدها للمخزون
        addChange(
          product.id,
          reverse
              ? -returnedItem.returnedQuantity.toDouble()
              : returnedItem.returnedQuantity.toDouble(),
        );
      }
      return changes;
    }

    // الفواتير العادية (بيع/شراء/نقدية)
    for (final item in invoice.items) {
      // إيصالات الحساب النقدية لا تحتوي مواد مخزنية.
      if (invoice.isCashAccountReceipt) continue;
      final product = _findProduct(
        products,
        productId: item.productId,
        productName: item.productName,
      );
      if (product == null || product.id.isEmpty || !product.trackQuantity) {
        continue;
      }

      double quantityChange;
      if (invoice.type == 'sales' || invoice.type == 'cash') {
        // بيع/نقدية: التطبيق يخصم، والعكس يعيد
        // (النقدية تُخصم مثل البيع عند الإنشاء وتُعاد
        // مثله عند العكس — _reverseNormalInventoryInTransaction
        // يعالج cash بنفس اتجاه sales)
        quantityChange = reverse ? item.quantity : -item.quantity;
      } else if (invoice.type == 'purchase') {
        // شراء: التطبيق يزيد، والعكس يخصم
        quantityChange = reverse ? -item.quantity : item.quantity;
      } else {
        continue;
      }
      addChange(product.id, quantityChange);
    }

    return changes;
  }

  /// جمع معرفات المنتجات المُتتبعة الكمية من فاتورة
  /// (من العناصر والمرتجعات معاً)
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// تُستخدم قائمة المنتجات المُجلوبة مسبقاً فقط
  /// لتحديد معرفات المنتجات (لأن Firestore لا تدعم
  /// استعلامات Collections داخل transaction).
  /// الكمية نفسها تُقرأ لاحقاً من اللقطة الحية داخل
  /// المعاملة عبر _readProductSnapshotsInTransaction.
  Set<String> _collectTrackedProductIds(
    InvoiceEntity invoice,
    List<ProductEntity> products,
  ) {
    final productIds = <String>{};
    if (invoice.isCashAccountReceipt) return productIds;

    for (final item in invoice.items) {
      final product = _findProduct(
        products,
        productId: item.productId,
        productName: item.productName,
      );
      if (product != null && product.id.isNotEmpty && product.trackQuantity) {
        productIds.add(product.id);
      }
    }

    for (final returnedItem in invoice.returnedItems ?? []) {
      final product = _findReturnedItemProduct(products, returnedItem);
      if (product != null && product.id.isNotEmpty && product.trackQuantity) {
        productIds.add(product.id);
      }
    }

    return productIds;
  }

  /// قراءة لقطات حية لمستندات المنتجات داخل المعاملة
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// قراءة المستندات بالمعرف (transaction.get) مسموحة
  /// داخل transaction (على عكس استعلامات Collections).
  /// ⚠️ يجب استدعاء هذه الدالة قبل أي عملية كتابة
  /// في المعاملة لأن Firestore يفرض: جميع القراءات
  /// قبل جميع الكتابات. قراءة اللقطات الحية تضمن
  /// عزل التعديلات المتزامنة: إذا عدّل مستخدم آخر
  /// كمية المنتج، تفشل المعاملة وتُعاد تلقائياً
  /// بالكمية الجديدة.
  Future<Map<String, DocumentSnapshot<Object?>>>
  _readProductSnapshotsInTransaction(
    Transaction transaction,
    String organizationEmail,
    Set<String> productIds,
  ) async {
    final snapshots = <String, DocumentSnapshot<Object?>>{};
    for (final productId in productIds) {
      snapshots[productId] = await transaction.get(
        _getProductDocRef(organizationEmail, productId),
      );
    }
    return snapshots;
  }

  /// تحديث كمية منتج وإنشاء سجل حركة داخل transaction
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// `newQuantity` هي الكمية النهائية المحسوبة من اللقطة
  /// الحية داخل المعاملة بواسطة المستدعي، وتُكتب كما هي.
  /// ⚠️ لا تحسب الكمية هنا من `quantityChange` وحده:
  /// هذا كان خطأ سابقاً كتب `quantityChange` مباشرة
  /// فوق الكمية الحقيقية (بيع 5 من 100 كان يكتب 5،
  /// والبيع لم يكن ينقص المخزون أبداً لأن الناتج
  /// السالب كان يُتجاهل).
  Future<void> _updateProductQuantityInTransaction(
    Transaction transaction,
    String organizationEmail,
    String productId,
    double newQuantity,
    double quantityChange,
    String invoiceId,
    String invoiceType,
    double unitPrice,
    double totalPrice,
    String customerName,
    String customerPhone,
    DateTime date,
    String createdBy,
    String notes, {
    bool reverse = false,
    double? sellingPrice,
    double? costPrice,
    bool? trackQuantity,
    String? productName,
  }) async {
    if (trackQuantity != true) return;

    final finalQuantity = newQuantity;
    if (finalQuantity < 0) return;

    final productDoc = _getProductDocRef(organizationEmail, productId);

    final updateData = <String, dynamic>{
      // ✅ ملاحظة للمبرمجين المستقبليين (إصلاح 2026-10-08):
      // تُكتب الكمية بـ FieldValue.increment(quantityChange)
      // بدلاً من القيمة المطلقة finalQuantity. السبب: في
      // updateInvoice يتم عكس تأثير الفاتورة القديمة ثم
      // تطبيق تأثير الجديدة، وكلاهما يقرأ نفس اللقطة الحية
      // (Firestore تفرض أن جميع القراءات قبل جميع الكتابات).
      // لو كُتبت القيمة المطلقة، لمَسحت خطوة التطبيق أثر
      // خطوة العكس (الكتابة الثانية تغطي الأولى لنفس الحقل)
      // فتصبح الكمية النهائية خاطئة. مع increment تتراكم
      // التغييرات بشكل صحيح:
      // النهائي = اللقطة + عكس القديمة + تطبيق الجديدة.
      // في addInvoice و deleteInvoice (كتابة واحدة فقط)
      // يكون الناتج مطابقاً تماماً للقيمة المطلقة السابقة.
      'quantity': FieldValue.increment(quantityChange),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': createdBy,
    };

    if (sellingPrice != null) {
      updateData['sellingPrice'] = sellingPrice;
    }
    if (costPrice != null) {
      updateData['costPrice'] = costPrice;
    }

    transaction.update(productDoc, updateData);

    final logDocRef = _getProductLogDocRef(organizationEmail);
    final logModel = ProductLogModel(
      id: '',
      productId: productId,
      productName: productName ?? '',
      invoiceId: invoiceId,
      invoiceType: reverse ? '$invoiceType-reversed' : invoiceType,
      quantity: quantityChange,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      customerName: customerName,
      customerPhone: customerPhone,
      date: date,
      organizationEmail: organizationEmail,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      notes: notes,
    );

    transaction.set(logDocRef, logModel.toFirestore());
  }

  /// تطبيق تحديثات المخزون للفواتير (بيع/شراء/نقدية/مرجع بيع)
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// يتم تجميع التغييرات حسب معرف المنتج لتجنب التحديث المزدوج.
  /// إذا كان هناك عدة عناصر لنفس المنتج في الفاتورة،
  /// تتم معالجة جميعها معاً في عملية واحدة لمنع مشكلة
  /// قراءة نفس الكمية الأولية عدة مرات داخل الـ transaction
  /// بسبب عزل اللقطة (snapshot isolation) في Firestore.
  ///
  /// ⚠️ ملاحظة هامة جداً للمبرمجين المستقبليين حول مرجع البيع:
  /// فاتورة مرجع البيع (sales_return) تزيد المخزون لأن
  /// المواد المرتجعة تعود إلى المخزون. كان خطأ سابقاً
  /// تجاهلها هنا (`if (invoice.isSalesReturn) return;`)
  /// مما جعل إنشاء/تحديث مرجع البيع لا يُعيد الكمية إلى
  /// المخزون أبداً، بينما حذفه أو تحديثه كان يخصمها عبر
  /// _reverseSalesReturnInventoryInTransaction — وهذا يسبب
  /// انحرافاً مزمناً في المخزون (المرتجع لا يُضاف، وحذفه
  /// يُنقص). الآن تُعالج هنا بزيادة الكمية، ويُعكس التأثير
  /// عند الحذف/التحديث بنقصانها. لا تُرجع هذه الدالة إلى
  /// التجاهل أبداً.
  Future<void> _applyInventoryUpdatesForInvoice(
    Transaction transaction,
    InvoiceEntity invoice,
    List<ProductEntity> products,
    Map<String, DocumentSnapshot<Object?>> productSnapshots, {
    Map<String, double>? reverseChanges,
  }) async {
    // ✅ فاتورة مرجع البيع: إعادة الكمية المرتجعة إلى المخزون
    // (زيادة المخزون — عكس ما تفعله _reverseSalesReturnInventoryInTransaction)
    if (invoice.isSalesReturn) {
      await _applySalesReturnInventoryInTransaction(
        transaction,
        invoice,
        products,
        productSnapshots,
        reverseChanges: reverseChanges,
      );
      return;
    }
    // ✅ تجميع التغييرات حسب معرف المنتج
    final changesByProduct = <String, _InventoryChange>{};

    for (final item in invoice.items) {
      final product = _findProduct(
        products,
        productId: item.productId,
        productName: item.productName,
      );

      if (product == null || product.id.isEmpty) continue;
      if (!product.trackQuantity) continue;

      double quantityChange;
      String reason;

      if (invoice.type == 'sales' || invoice.type == 'cash') {
        quantityChange = -item.quantity;
        reason =
            'فاتورة ${invoice.type == 'cash' ? 'نقدية' : 'بيع'} رقم ${invoice.invoiceNumber}';
      } else if (invoice.type == 'purchase') {
        quantityChange = item.quantity;
        reason = 'فاتورة شراء رقم ${invoice.invoiceNumber}';
      } else {
        continue;
      }

      final existing = changesByProduct[product.id];
      if (existing != null) {
        existing.quantityChange += quantityChange;
        existing.totalPrice += item.totalPrice;
      } else {
        changesByProduct[product.id] = _InventoryChange(
          product: product,
          quantityChange: quantityChange,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          reason: reason,
        );
      }
    }

    // ✅ تطبيق التغييرات المجمعة من اللقطة الحية داخل المعاملة
    // ⚠️ ملاحظة للمبرمجين المستقبليين:
    // الكمية النهائية تُحسب من اللقطة الحية
    // (productSnapshots) وليس من القائمة المُجلوبة
    // مسبقاً، لضمان عزل التعديلات المتزامنة
    // على نفس المنتج داخل المعاملة.
    for (final change in changesByProduct.values) {
      final productSnapshot = productSnapshots[change.product.id];
      if (productSnapshot == null || !productSnapshot.exists) continue;
      final productData = productSnapshot.data() as Map<String, dynamic>?;
      final liveQuantity = (productData?['quantity'] as num?)?.toDouble() ?? 0;
      final liveTrackQuantity =
          (productData?['trackQuantity'] as bool?) ?? true;
      if (!liveTrackQuantity) continue;

      // ⚠️ في updateInvoice تُضاف قيمة عكس القديمة
      // (reverseChanges) إلى الحساب لأن اللقطة الحية
      // لا تعكس بعد أثر خطوة العكس (Firestore تفرض
      // أن جميع القراءات قبل جميع الكتابات). بدونها
      // تُحسب الكمية من اللقطة وحدها فتكون سالبة
      // ظناً رغم أن الكمية النهائية صحيحة — فيتجاهل
      // الحارس الكتابة صامتاً (continue) فينحرف
      // المخزون. في addInvoice (لا عكس) القيمة null
      // فلا يتغير الحساب.
      final newQuantity =
          liveQuantity +
          (reverseChanges?[change.product.id] ?? 0) +
          change.quantityChange;
      if (newQuantity < 0) continue;

      await _updateProductQuantityInTransaction(
        transaction,
        invoice.organizationEmail,
        change.product.id,
        newQuantity,
        change.quantityChange,
        invoice.id,
        invoice.type,
        change.unitPrice,
        change.totalPrice,
        invoice.customerName,
        invoice.customerPhone,
        invoice.invoiceDate,
        invoice.createdBy,
        change.reason,
        sellingPrice: invoice.type == 'purchase'
            ? (productData?['sellingPrice'] as num?)?.toDouble() ??
                  change.product.sellingPrice
            : null,
        costPrice: invoice.type == 'purchase' ? change.unitPrice : null,
        trackQuantity: liveTrackQuantity,
      );
    }
  }

  /// تطبيق تحديثات المخزون لفاتورة مرجع البيع (إعادة المواد إلى المخزون)
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// مرجع البيع يزيد المخزون لأن المواد المرتجعة تعود
  /// إلى المخزون. يتم تجميع التغييرات حسب معرف المنتج
  /// لتجنب التحديث المزدوج. هذه الدالة هي عكس
  /// _reverseSalesReturnInventoryInTransaction تماماً:
  /// هذه تزيد الكمية (تطبيق مرجع البيع عند الإنشاء/التحديث)،
  /// وتلك تنقصها (عكس مرجع البيع عند الحذف/التحديث).
  /// ⚠️ لا تحذف هذه الدالة ولا تجعلها تُرجع بدون تنفيذ،
  /// وإلا عاد الخطأ القديم (مرجع البيع لا يُعيد الكمية
  /// إلى المخزون أبداً).
  Future<void> _applySalesReturnInventoryInTransaction(
    Transaction transaction,
    InvoiceEntity invoice,
    List<ProductEntity> products,
    Map<String, DocumentSnapshot<Object?>> productSnapshots, {
    Map<String, double>? reverseChanges,
  }) async {
    final returnedItems = invoice.returnedItems ?? [];
    if (returnedItems.isEmpty) return;

    // ✅ تجميع التغييرات حسب معرف المنتج
    final changesByProduct = <String, _InventoryChange>{};

    for (final returnedItem in returnedItems) {
      final product = _findReturnedItemProduct(products, returnedItem);

      if (product == null || product.id.isEmpty) continue;
      if (!product.trackQuantity) continue;

      // ✅ مرجع البيع يزيد المخزون (قيمة موجبة — عكس
      // _reverseSalesReturnInventoryInTransaction التي
      // تنقصها). لا تجعل هذه القيمة سالبة أبداً.
      final quantityChange = returnedItem.returnedQuantity.toDouble();

      final existing = changesByProduct[product.id];
      if (existing != null) {
        existing.quantityChange += quantityChange;
        existing.totalPrice += returnedItem.totalPrice;
      } else {
        changesByProduct[product.id] = _InventoryChange(
          product: product,
          quantityChange: quantityChange,
          unitPrice: returnedItem.unitPrice,
          totalPrice: returnedItem.totalPrice,
          reason: 'مرجع بيع رقم ${invoice.invoiceNumber}',
        );
      }
    }

    // ✅ تطبيق التغييرات المجمعة من اللقطة الحية داخل المعاملة
    // (نفس قاعدة اللقطة الحية في _applyInventoryUpdatesForInvoice:
    // الكمية النهائية من productSnapshots وليس القائمة المُجلوبة
    // مسبقاً لضمان عزل التعديلات المتزامنة على نفس المنتج).
    for (final change in changesByProduct.values) {
      final productSnapshot = productSnapshots[change.product.id];
      if (productSnapshot == null || !productSnapshot.exists) continue;
      final productData = productSnapshot.data() as Map<String, dynamic>?;
      final liveQuantity = (productData?['quantity'] as num?)?.toDouble() ?? 0;
      final liveTrackQuantity =
          (productData?['trackQuantity'] as bool?) ?? true;
      if (!liveTrackQuantity) continue;

      final newQuantity =
          liveQuantity +
          (reverseChanges?[change.product.id] ?? 0) +
          change.quantityChange;
      if (newQuantity < 0) continue;

      await _updateProductQuantityInTransaction(
        transaction,
        invoice.organizationEmail,
        change.product.id,
        newQuantity,
        change.quantityChange,
        invoice.id,
        'sales_return',
        change.unitPrice,
        change.totalPrice,
        invoice.customerName,
        invoice.customerPhone,
        invoice.invoiceDate,
        invoice.createdBy,
        change.reason,
        trackQuantity: liveTrackQuantity,
      );
    }
  }

  /// عكس تأثير المخزون لفواتير مرجع البيع
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// يتم تجميع التغييرات حسب معرف المنتج لتجنب التحديث المزدوج.
  /// إذا كان هناك عدة مرتجع لنفس المنتج،
  /// تتم معالجة جميعها معاً في عملية واحدة لمنع مشكلة
  /// قراءة نفس الكمية الأولية عدة مرات داخل الـ transaction.
  Future<void> _reverseSalesReturnInventoryInTransaction(
    Transaction transaction,
    InvoiceEntity invoice,
    List<ProductEntity> products,
    Map<String, DocumentSnapshot<Object?>> productSnapshots, {
    Map<String, double>? applyChanges,
  }) async {
    final returnedItems = invoice.returnedItems ?? [];
    if (returnedItems.isEmpty) return;

    // ✅ تجميع التغييرات حسب معرف المنتج
    final changesByProduct = <String, _InventoryChange>{};

    for (final returnedItem in returnedItems) {
      final product = _findReturnedItemProduct(products, returnedItem);

      if (product == null || product.id.isEmpty) continue;
      if (!product.trackQuantity) continue;

      final quantityChange = -returnedItem.returnedQuantity.toDouble();

      final existing = changesByProduct[product.id];
      if (existing != null) {
        existing.quantityChange += quantityChange;
        existing.totalPrice += returnedItem.totalPrice;
      } else {
        changesByProduct[product.id] = _InventoryChange(
          product: product,
          quantityChange: quantityChange,
          unitPrice: returnedItem.unitPrice,
          totalPrice: returnedItem.totalPrice,
          reason: 'مرجع بيع رقم ${invoice.invoiceNumber}',
        );
      }
    }

    // ✅ تطبيق التغييرات المجمعة من اللقطة الحية داخل المعاملة
    // (نفس قاعدة اللقطة الحية في _applyInventoryUpdatesForInvoice:
    // الكمية النهائية من productSnapshots وليس القائمة المُجلوبة
    // مسبقاً لضمان عزل التعديلات المتزامنة على نفس المنتج).
    for (final change in changesByProduct.values) {
      final productSnapshot = productSnapshots[change.product.id];
      if (productSnapshot == null || !productSnapshot.exists) continue;
      final productData = productSnapshot.data() as Map<String, dynamic>?;
      final liveQuantity = (productData?['quantity'] as num?)?.toDouble() ?? 0;
      final liveTrackQuantity =
          (productData?['trackQuantity'] as bool?) ?? true;
      if (!liveTrackQuantity) continue;

      final newQuantity =
          liveQuantity +
          change.quantityChange +
          (applyChanges?[change.product.id] ?? 0);
      if (newQuantity < 0) continue;

      await _updateProductQuantityInTransaction(
        transaction,
        invoice.organizationEmail,
        change.product.id,
        newQuantity,
        change.quantityChange,
        invoice.id,
        'sales_return',
        change.unitPrice,
        change.totalPrice,
        invoice.customerName,
        invoice.customerPhone,
        invoice.invoiceDate,
        invoice.createdBy,
        'مرجع بيع رقم ${invoice.invoiceNumber}',
        trackQuantity: liveTrackQuantity,
      );
    }
  }

  /// عكس تأثير المخزون للفواتير العادية (بيع/نقدية/شراء)
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// يتم تجميع التغييرات حسب معرف المنتج لتجنب التحديث المزدوج.
  /// إذا كان هناك عدة عناصر لنفس المنتج في الفاتورة،
  /// تتم معالجة جميعها معاً في عملية واحدة لمنع مشكلة
  /// قراءة نفس الكمية الأولية عدة مرات داخل الـ transaction.
  /// ⚠️ ملاحظة حول الفاتورة النقدية (cash): لها فرع خاص أدناه
  /// تُخصم مبيعات النقد من المخزون مثل البيع، لكن إيصالات الحساب
  /// لا تمثل أصنافاً ولا ينبغي عكس أي كمية مخزنية فيها.
  Future<void> _reverseNormalInventoryInTransaction(
    Transaction transaction,
    InvoiceEntity invoice,
    List<ProductEntity> products,
    Map<String, DocumentSnapshot<Object?>> productSnapshots, {
    Map<String, double>? applyChanges,
  }) async {
    if (invoice.isCashAccountReceipt) return;
    // ✅ تجميع التغييرات حسب معرف المنتج
    final changesByProduct = <String, _InventoryChange>{};

    for (final item in invoice.items) {
      final product = _findProduct(
        products,
        productId: item.productId,
        productName: item.productName,
      );

      if (product == null || product.id.isEmpty) continue;
      if (!product.trackQuantity) continue;

      double quantityChange;
      String reason;

      if (invoice.type == 'sales') {
        quantityChange = item.quantity;
        reason = 'عكس فاتورة بيع رقم ${invoice.invoiceNumber}';
      } else if (invoice.type == 'cash') {
        // ✅ عكس الفاتورة النقدية: إعادة الكمية المباعة نقداً
        // (نفس اتجاه عكس البيع لأن الإنشاء يخصم مثل البيع)
        quantityChange = item.quantity;
        reason = 'عكس فاتورة نقدية رقم ${invoice.invoiceNumber}';
      } else if (invoice.type == 'purchase') {
        quantityChange = -item.quantity;
        reason = 'عكس فاتورة شراء رقم ${invoice.invoiceNumber}';
      } else {
        continue;
      }

      final existing = changesByProduct[product.id];
      if (existing != null) {
        existing.quantityChange += quantityChange;
        existing.totalPrice += item.totalPrice;
      } else {
        changesByProduct[product.id] = _InventoryChange(
          product: product,
          quantityChange: quantityChange,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          reason: reason,
        );
      }
    }

    // ✅ تطبيق التغييرات المجمعة من اللقطة الحية داخل المعاملة
    // (نفس قاعدة اللقطة الحية في _applyInventoryUpdatesForInvoice:
    // الكمية النهائية من productSnapshots وليس القائمة المُجلوبة
    // مسبقاً لضمان عزل التعديلات المتزامنة على نفس المنتج).
    for (final change in changesByProduct.values) {
      final productSnapshot = productSnapshots[change.product.id];
      if (productSnapshot == null || !productSnapshot.exists) continue;
      final productData = productSnapshot.data() as Map<String, dynamic>?;
      final liveQuantity = (productData?['quantity'] as num?)?.toDouble() ?? 0;
      final liveTrackQuantity =
          (productData?['trackQuantity'] as bool?) ?? true;
      if (!liveTrackQuantity) continue;

      final newQuantity =
          liveQuantity +
          change.quantityChange +
          (applyChanges?[change.product.id] ?? 0);
      if (newQuantity < 0) continue;

      await _updateProductQuantityInTransaction(
        transaction,
        invoice.organizationEmail,
        change.product.id,
        newQuantity,
        change.quantityChange,
        invoice.id,
        invoice.type,
        change.unitPrice,
        change.totalPrice,
        invoice.customerName,
        invoice.customerPhone,
        invoice.invoiceDate,
        invoice.createdBy,
        change.reason,
        trackQuantity: liveTrackQuantity,
      );
    }
  }

  /// عكس تأثير الفاتورة على المخزون داخل transaction
  Future<void> _reverseInventoryImpactInTransaction(
    Transaction transaction,
    InvoiceEntity invoice,
    List<ProductEntity> products,
    Map<String, DocumentSnapshot<Object?>> productSnapshots, {
    Map<String, double>? applyChanges,
  }) async {
    if (invoice.isSalesReturn) {
      await _reverseSalesReturnInventoryInTransaction(
        transaction,
        invoice,
        products,
        productSnapshots,
        applyChanges: applyChanges,
      );
    } else {
      await _reverseNormalInventoryInTransaction(
        transaction,
        invoice,
        products,
        productSnapshots,
        applyChanges: applyChanges,
      );
    }
  }

  /// ✅ ملاحظة للمبرمجين المستقبليين:
  /// إنشاء سجل نشاط الفاتورة داخل الـ transaction لضمان الذرية.
  /// هذه الدالة مساعدة تُستخدم عند تنفيذ عمليات الفاتورة داخل transaction
  /// لضمان أن سجل النشاط يُنشأ مع الفاتورة في نفس المعاملة الذرية.
  Future<void> _createInvoiceLogInTransaction(
    Transaction transaction,
    String organizationId,
    Map<String, dynamic> logData,
  ) async {
    final logDocRef = firestore
        .collection(organizationId)
        .doc('invoices')
        .collection('logs')
        .doc();

    transaction.set(logDocRef, logData);
  }

  /// تحديث حساب الصندوق
  ///
  /// ملاحظة للمبرمجين المستقبليين:
  /// هذه الدالة محفوظة كدالة مساعدة مستقبلية.
  /// حالياً تم دمج منطق تحديث الصندوق داخل runTransaction
  /// في addInvoice/updateInvoice/deleteInvoice لجعل العملية ذرية.
  /// إذا أردت استخدامها مستقبلاً، تأكد من دمجها داخل transaction.
  // ignore: unused_element
  Future<void> _updateCashbox({
    required String organizationEmail,
    required double amount,
    required String type,
    required String updatedBy,
    required String source,
    required String referenceId,
    required String description,
  }) async {
    final normalizedEmail = _emailService.normalize(organizationEmail);

    await firestore
        .collection(normalizedEmail)
        .doc('cashbox')
        .collection('balance')
        .doc('main')
        .set({
          'currentBalance': FieldValue.increment(
            type == 'in' ? amount : -amount,
          ),
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        }, SetOptions(merge: true));
  }
}

/// استخراج رسالة خطأ مفهومة للمستخدم من أي استثناء.
/// FirebaseException يحتوي على خاصية message قابلة للقراءة،
/// والاستثناءات المخصصة قد تحتوي على message أيضًا.
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
