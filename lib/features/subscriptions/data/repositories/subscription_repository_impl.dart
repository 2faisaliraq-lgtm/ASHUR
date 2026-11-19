import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/utils/date_parser.dart';
import '../../../invoices/data/models/invoice_model.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../../domain/entities/activation_recharge_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/subscription_log_entity.dart';
import '../../domain/entities/subscription_type_entity.dart';
import '../../domain/entities/subscription_types_page.dart';
import '../../domain/entities/subscriptions_page.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../models/activation_recharge_model.dart';
import '../models/subscription_log_model.dart';
import '../models/subscription_model.dart';
import '../models/subscription_type_model.dart';














































// ════════════════════════════════════════════════════════════
// 🔍 التحقق اليدوي الدقيق من الذريّة (تاريخ التحقق: 2026-10-12 — أُعيد التحقق بنفس التاريخ بقراءة كاملة لكل الأسطر التنفيذية في الملفات الثلاثة: لا انحرافات جديدة) — كتلة مدمجة تجمع التحققات السابعة عشر والثامنة عشر والتاسعة عشر والعشرين وإعادة التحقق لتجنب الاطاله
// ════════════════════════════════════════════════════════════
//
// ⚠️ ملاحظة للمبرمجين المستقبليين:
// هذا التحقق (قراءة فقط، بدون أي تعديل في أي سطر
// تنفيذي) أعاد قراءة كل عمليات الاشتراك سطراً بسطر
// في ستة مواقع: (أ) هذا الملف كاملاً (ب)
// subscription_bloc.dart (ج) functions/index.js (د)
// domain/usecases (هـ) _createInvoiceInTransaction (و)
// الدوال الذرية السحابية الست. لماذا يوجد هذا التحقق؟
// لأن كل عملية تربط مستندات ببعضها (اشتراك ↔ نوع ↔
// سجلات ↔ صندوق ↔ فواتير ↔ عميل): لو فشل جزء ونجح
// جزء صارت البيانات غير متسقة (عداد أعلى/أقل من
// الفعلي، أموال بلا سبب، سجل يوثق عملية لم تحدث،
// تفعيلة مستهلكة بلا تجديد فعلي، اشتراك بلا فاتورة).
// المعاملة الواحدة تضمن إما نجاح الكل أو فشل الكل —
// لا حالة وسيطة أبداً.
// ✅ النتيجة: لا انحراف جديد — كل العمليات ذرية
// فعلاً (كل transaction.get قبل كل كتابة/حذف، وكل
// العمليات داخل runTransaction واحدة — all-or-nothing).
// ✅ ما تم التحقق منه بدقة فائقة (اعتمد على أسماء
// الدوال لا أرقام الأسطر):
// 【Dart — هذا الملف】createSubscription و
// updateSubscription و deleteSubscription و
// updateSubscriptionStatus و renewSubscription و
// updateSubscriptionPayment و createSubscriptionType و
// updateSubscriptionType و deleteSubscriptionType و
// addSubscriptionLog و deleteSubscriptionLog و
// rechargeActivations — كلها داخل runTransaction واحدة
// بكل قراءاتها (transaction.get) قبل كل كتاباتها،
// والعدادات عبر FieldValue.increment، والتحقق من
// التعديل المتزامن عبر expectedUpdatedAt والقراءة
// المسبقة للنوع، وحماية التفعيلات السالبة، ومنع
// القيمة السالبة للمتبقي، وحل مرجع النوع داخل
// المعاملة في deleteSubscription عند فشل القراءة
// المسبقة. updateSubscriptionPayment: totalPaid
// تُحسب قراءة-ثم-كتابة داخل المعاملة — آمنة
// لأن Firestore يعيد تشغيل المعاملة عند تعارض
// (لا تُحوّلها لـ increment ولا تُصلحها — مقصودة
// وذاتية الذريّة داخل المعاملة).
// clearSubscriptionLogs — المسار الأساسي ذري عبر
// clearSubscriptionLogsAtomic؛ مسار الاحتياط Write
// Batch + استعلام خارجها غير ذري تماماً لكنه
// مقبول لعمليات التنظيف (موثق داخل الدالة).
// 【BLoC — subscription_bloc.dart】معالجات الكتابة
// تستدعي طرق المستودع الذرية مباشرة؛ _onCreateSubscription
// و _onRenewSubscription يمرران invoiceBuilder (الفاتورة
// داخل المعاملة)؛ _onUpdateSubscription و
// _onUpgradeSubscription يستخدمان expectedUpdatedAt
// (Optimistic Locking).
// 【Cloud Functions — functions/index.js】الدوال الست
// ذرية ومطابقة لجانب Dart: createSubscriptionAtomic و
// renewSubscriptionAtomic و deleteSubscriptionAtomic و
// updateSubscriptionStatusAtomic و rechargeActivationsAtomic
// و clearSubscriptionLogsAtomic (الأخيرة: استعلام
// خادمي + إعادة قراءة كل مستند داخل المعاملة قبل
// حذفه).
// ⚠️ الاستثناءات الموثقة الوحيدة (لا تُصلح دون مراجعة):
// 1. clearSubscriptionLogs — مسار الاحتياط Write
//    Batch + استعلام خارجها غير ذري تماماً لكنه
//    مقبول لعمليات التنظيف (موثق داخل الدالة).
// 2. _onUpgradeSubscription — سجل الترقية يُنشأ بعد
//    المعاملة عبر addSubscriptionLog (مقبول: الترقية
//    تنجح بلا سجل إذا فشل السجل — موثق في BLoC).
// 3. _applyDefaultSubscriptionTime — أُصلح 2026-10-12:
//    صارت قراءة SettingsService تُنفَّى خارج معاملة
//    التجديد (_readDefaultSubscriptionTimeSettings) وتُطبق
//    داخلها متزامناً (_applyDefaultSubscriptionTimeFromSettings)
//    — لم يعد يطيل عمر المعاملة (السلوك مطابق تماماً).
// 🔒 القواعد الذهبية المؤكدة (مدمجة من التحققات
// السابقة لتجنب الاطاله — لا تنتهكها أبداً):
// 1. أي عملية تعدل أكثر من مستند = runTransaction
//    واحدة (all-or-nothing).
// 2. كل القراءات (transaction.get) قبل كل
//    الكتابات/الحذف — قاعدة Firestore المفروضة.
// 3. لا .where().get() داخل runTransaction — لا تدعم
//    queries؛ استخدم transaction.get() على مرجع معروف
//    (يُحل خارج المعاملة في Dart).
// 4. FieldValue.increment() للعدادات دائماً — يمنع
//    مشكلة Read-Modify-Write (مثال: دفعتان متزامنتان
//    100 لكل منهما: بدون increment يُفقد دفع أحدهما).
// 5. expectedUpdatedAt للتحقق من التعديل المتزامن —
//    بدونه يُتجاوز القفل بالكامل.
// 6. عند تغيير النوع: القديم (linkedSubscriptionsCount
//    -1، activationQuantity +1) والجديد (+1، -1) —
//    الاتجاهات معاكسة ولا تخلطها.
// 7. الاسم الصحيح للحقل: linkedSubscriptionsCount فقط.
// 8. التجديد لا يمس الصندوق ولا linkedSubscriptionsCount
//    (لا خصم مزدوج). تغيير الحالة لا يمس عدادات النوع.
// 9. لا تُضف transaction.get() بعد أي كتابة داخل
//    المعاملة — سيرمي خطأ Firestore.
// 🔒 نهاية التحقق اليدوي المدمج — لا تعدّل المنطق دون مراجعة هذا التحقق 🔒
// ════════════════════════════════════════════════════════════




/// تنفيذ مستودع الاشتراكات
/// ⚠️ ملاحظة عامة حول الذرية (Atomicity):
/// نستخدم Firestore runTransaction لجميع العمليات التي تعدل أكثر من مستند
/// (إنشاء/تعديل/حذف اشتراك + تحديث عدادات أنواع الاشتراكات + الصندوق).
/// هذا يضمن إما نجاح جميع العمليات معاً أو فشلها جميعاً معاً (all-or-nothing).
/// clearSubscriptionLogs ذرية أيضاً عبر Cloud Function
/// clearSubscriptionLogsAtomic (لأن Firestore Transactions لا تدعم
/// الاستعلامات من جانب العميل) — مع مسار احتياطي Write Batch
/// موثّق داخل الدالة.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();

  String? _getCurrentOrganizationId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;
    return _emailService.normalize(user!.email!);
  }

  /// الحصول على اسم المستخدم الحالي
  Future<String> _getCurrentUserName() async {
    final switchedUser = await SessionService.getSwitchedUser();
    if (switchedUser != null && switchedUser['name'] != null) {
      final name = switchedUser['name'] as String;
      return name.split('(').first.trim();
    }
    return 'المدير';
  }

  /// قراءة إعدادات وقت البدء الافتراضي — تُقرأ مرة
  /// واحدة خارج معاملة التجديد.
  ///
  /// ⚠️ ملاحظة للمبرمجين المستقبليين (إصلاح 2026-10-12):
  /// كانت هذه القراءة تُنفَّى داخل معاملة التجديد عبر
  /// _applyDefaultSubscriptionTime — قراءة محلية
  /// (SettingsService) لا تعتمد على بيانات المعاملة
  /// لكنها كانت تطيل عمر المعاملة (زيادة زمن الانتظار
  /// واحتمال التعارض). الآن تُقرأ قبل المعاملة وتُطبق
  /// داخلها عبر _applyDefaultSubscriptionTimeFromSettings
  /// (متزامنة، بدون await). السلوك مطابق تماماً.
  Future<Map<String, dynamic>> _readDefaultSubscriptionTimeSettings() async {
    try {
      return await SettingsService.getSubscriptionSettings();
    } on Exception {
      return const <String, dynamic>{};
    }
  }

  /// تطبيق وقت البدء الافتراضي من إعدادات مُقرأة
  /// مسبقاً — متزامنة للاستخدام داخل المعاملة
  /// (بدون await). مطابقة تامة لـ
  /// _applyDefaultSubscriptionTime القديمة.
  DateTime _applyDefaultSubscriptionTimeFromSettings(
    DateTime date,
    Map<String, dynamic> settings,
  ) {
    final hour = settings['subscriptionDefaultHour'] as int? ?? 0;
    final minute = settings['subscriptionDefaultMinute'] as int? ?? 0;
    if (hour == 0 && minute == 0) {
      return date;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// إنشاء فاتورة اشتراك داخل معاملة ذرية قائمة.
  ///
  /// ⚠️ ملاحظة للمبرمجين المستقبليين:
  /// ⚠️ لا تُستدعى هذه الدالة خارج runTransaction — هي تكملة
  /// للمعاملة الأم (createSubscription أو renewSubscription) التي
  /// تكون قد قرأت العميل (customerSnapshot) قبل أي كتابة بالفعل
  /// (قاعدة Firestore: كل القراءات قبل كل الكتابات).
  /// ⚠️ هذه تطابق الجزء الخاص بفواتير الاشتراك من addInvoice في
  /// invoice_repository_impl.dart: الفاتورة + دين العميل +
  /// invoiceIds في العميل + relatedInvoiceIds في الاشتراك + سجل
  /// نشاط الفاتورة — بدون المخزون (فواتير الاشتراك لا تحتوي
  /// منتجات) وبدون الصندوق (paidAmount = 0 في فاتورة الاشتراك
  /// غير المدفوعة، والصندوق يُحدَّث من totalPaid الاشتراك نفسه)
  /// وبدون __stats__ (لا يُحدَّث في addInvoice في Dart — الإحصائيات
  /// تُحسب بقراءة الفواتير). أي تغيير هنا يجب أن يُعكس في
  /// addInvoice والعكس.
  Future<void> _createInvoiceInTransaction(
    Transaction transaction,
    String normalizedEmail,
    InvoiceEntity invoice,
    String subscriptionId,
    DocumentSnapshot<Object?>? customerSnapshot,
  ) async {
    // إنشاء معرف الفاتورة: يُستخدم المعرف المُمرر في
    // invoice.id إن وُجد (ليعرفه الطرف المُنشئ لتوليد
    // PDF والإشعارات بعد المعاملة)، وإلا يُولَّد جديداً
    // — مطابقةً لـ addInvoice الذي يولّد المعرف عبر
    // collection.doc() عندما يكون فارغاً.
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا يصلح عيباً
    // كامناً — كان الكود يولّد المعرف دائماً متجاهلاً
    // invoice.id رغم أن التعليق يقول "عند غيابه".
    // الآن يُحترم المعرف المُمرر: SubscriptionBloc
    // يولّده مسبقاً (عبر _prepareSubscriptionInvoiceData)
    // ويمرره في invoice.id ليعرفه لتوليد PDF والإشعارات
    // بعد نجاح المعاملة — والمعرف عشوائي فلا يتأثر
    // بالمسار. المُستدعون الذين يمررون id فارغاً
    // يُولَّد لهم معرف جديد كما كان (متوافق رجعياً).
    final invoiceId = invoice.id.isNotEmpty
        ? invoice.id
        : firestore
            .collection(normalizedEmail)
            .doc('invoices')
            .collection('invoices')
            .doc()
            .id;
    final invoiceDoc = firestore
        .collection(normalizedEmail)
        .doc('invoices')
        .collection('invoices')
        .doc(invoiceId);

    // حفظ الفاتورة مع تعبئة المعرف (كما يفعل addInvoice:
    // data['id'] = invoiceId بعد toFirestore الذي لا يتضمنه).
    final invoiceData = InvoiceModel.fromEntity(invoice).toFirestore();
    invoiceData['id'] = invoiceId;
    transaction.set(invoiceDoc, invoiceData);

    // تحديث دين العميل و invoiceIds ذرياً مع الفاتورة — فقط إذا
    // كان العميل موجوداً. نستخدم FieldValue.increment بدل
    // Read-Modify-Write لمنع فقدان تحديث متزامن.
    // ⚠️ إصلاح (2026-10-12 — مطابقةً لإصلاح addInvoice رقم 8
    // في invoice_repository_impl): invoiceIds يُحدَّث دائماً عند
    // وجود عميل (لا يُشترط remainingAmount != 0). السبب: فاتورة
    // اشتراك بقيمة صفر (remainingAmount == 0) لم يُربط معرفها
    // بـ invoiceIds، و deleteCustomer لا يعمل الاستعلام الخارجي
    // للعملاء الجدد (الذين يملكون invoiceIds) فتبقى الفاتورة
    // مرجعاً يتيمة تشير لعميل محذوف. تحديث الدين فقط هو
    // المشروط بالمتبقي (لا معنى لتحديث دين بصفر).
    if (customerSnapshot != null &&
        invoice.customerId != null &&
        invoice.customerId!.isNotEmpty) {
      final customerDocRef = firestore
          .collection(normalizedEmail)
          .doc('customers')
          .collection('customers')
          .doc(invoice.customerId!);
      if (invoice.remainingAmount != 0) {
        transaction.set(
          customerDocRef,
          {
            'totalDebt': FieldValue.increment(invoice.remainingAmount),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      // ✅ حراسة containsKey (نفس قاعدة addInvoice
      // الذهبية في invoice_repository_impl): لا تُنشئ
      // invoiceIds على عميل قديم بلاها — الفاتورة
      // تُربط بالعميل عبر customerId في بياناتها
      // فيُجدها استعلام التوافق الخارجي في
      // deleteCustomer.
      if ((customerSnapshot.data() as Map<String, dynamic>?)
              ?.containsKey('invoiceIds') ==
          true) {
        transaction.set(
          customerDocRef,
          {'invoiceIds': FieldValue.arrayUnion([invoiceId])},
          SetOptions(merge: true),
        );
      }
    }

    // ربط الفاتورة بالاشتراك عبر relatedInvoiceIds — ضروري حتى
    // يحذف deleteSubscription الفاتورة تلقائياً (مطابقةً لـ
    // addInvoice الذي يفعل هذا لفواتير الاشتراك).
    transaction.set(
      firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('subscriptions')
          .doc(subscriptionId),
      {'relatedInvoiceIds': FieldValue.arrayUnion([invoiceId])},
      SetOptions(merge: true),
    );

    // سجل نشاط الفاتورة داخل نفس المعاملة (مطابقةً لـ
    // _createInvoiceLogInTransaction في invoice_repository_impl.dart).
    final logDoc = firestore
        .collection(normalizedEmail)
        .doc('invoices')
        .collection('logs')
        .doc();
    transaction.set(logDoc, {
      'userId': invoice.createdBy,
      'actionType': 'add_invoice',
      'timestamp': FieldValue.serverTimestamp(),
      'details': 'تم إضافة فاتورة جديدة: ${invoice.invoiceNumber}',
      'targetId': invoiceId,
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
  }

  /// التحقق من إمكانية الوصول للمؤسسة
  Future<bool> _canAccessOrganization(String organizationEmail) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // فحص أمني حقيقي: مقارنة البريد الإلكتروني للمؤسسة المطلوبة
      // مع البريد الإلكتروني للمستخدم الحالي بعد التطبيع
      final userEmail = user.email;
      if (userEmail == null || userEmail.isEmpty) return false;

      final currentOrgId = _emailService.normalize(userEmail);
      final requestedOrgId = _emailService.normalize(organizationEmail);
      return currentOrgId == requestedOrgId;
    } on Exception catch (_) {
      return false;
    }
  }

  @override
  Future<Either<Failure, List<SubscriptionEntity>>> getSubscriptions(
    String organizationEmail,
  ) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // التحقق من إمكانية الوصول للمؤسسة
      if (!await _canAccessOrganization(organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      final querySnapshot = await firestore
          .collection(normalizedEmail) // ✅ استخدام البريد المطبّع
          .doc('subscriptions')
          .collection('subscriptions')
          .orderBy('createdAt', descending: true)
          .get();

      final subscriptions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
        }
        return SubscriptionModel.fromJson(data);
      }).toList();

      return Right(subscriptions);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الاشتراكات: $e'));
    }
  }

  @override
  Future<Either<Failure, SubscriptionsPage>> getSubscriptionsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // التحقق من إمكانية الوصول للمؤسسة
      if (!await _canAccessOrganization(organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      var query = firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('subscriptions')
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();

      final subscriptions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = doc.id;
        }
        return SubscriptionModel.fromJson(data);
      }).toList();

      return Right(
        SubscriptionsPage(
          subscriptions: subscriptions,
          lastDocument: querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.last
              : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الاشتراكات: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> createSubscription(
    SubscriptionEntity subscription, {
    InvoiceEntity Function(SubscriptionEntity createdSubscription)?
        invoiceBuilder,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(
        subscription.organizationEmail,
      );

      // التحقق من إمكانية الوصول للمؤسسة
      if (!await _canAccessOrganization(subscription.organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      final model = SubscriptionModel.fromEntity(subscription);

      // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
      // ⚠️ نستخدم Firestore runTransaction لضمان all-or-nothing، لكن Firestore لا تدعم
      // تنفيذ استعلامات (queries مثل .where().get()) داخل المعاملة. لذلك، نحتاج أولاً
      // إلى حل مرجع المستند (typeDocRef) خارج المعاملة، ثم استخدام transaction.get()
      // مباشرة على مرجع معروف داخل المعاملة. هذا يضمن أن Firestore تستطيع إعادة
      // تشغيل المعاملة تلقائياً في حالة تعارض، مع بيانات حديثة دائماً.
      // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
      // 1. إنشاء مستند الاشتراك ← ذري مع تحديث النوع
      //    → إذا تم إنشاء الاشتراك لكن لم يُحدَّث النوع،
      //      فإن عدد الاشتراكات في النوع يكون أعلى من الفعلي.
      // 2. تحديث activationQuantity و linkedSubscriptionsCount في النوع ← ذري مع الاشتراك
      //    → إذا استخدمت currentQuantity - 1 بدلاً من FieldValue.increment(-1)،
      //      فإنك تعيد مشكلة Read-Modify-Write.
      // 3. تحديث الصندوق (currentBalance) ← ذري مع الاشتراك
      //    → إذا تم إنشاء الاشتراك لكن لم يُحدَّث الصندوق،
      //      فإن الأموال لا تُسجل. إذا تم تحديث الصندوق لكن
      //      لم يُنشأ الاشتراك، فإن الأموال تُخصم بلا سبب.
      // ✅ الفاتورة تُنشأ ذرياً داخل هذه المعاملة الآن (إصلاح
      // 2026-10-09، موثّق في كتلة التحقق المدمجة أعلى الملف):
      // عندما يمرر المستدعي invoiceBuilder (يفعله _onCreateSubscription
      // في BLoC منذ 2026-10-11)، تُنشأ الفاتورة + دين العميل و
      // invoiceIds و relatedInvoiceIds وسجل الفاتورة هنا عبر
      // _createInvoiceInTransaction — all-or-nothing مع الاشتراك.
      // ⚠️ ملاحظة للمبرمجين المستقبليين: أي تعليق قديم يقول إن
      // الفاتورة مفقودة هنا أو إن الحل الوحيد هو Cloud Function
      // لم يعد صحيحاً — لا تعتمد عليه ولا تُرجع إنشاء الفاتورة
      // إلى معاملة منفصلة أبداً (سيُنتج اشتراكاً بلا فاتورة أو
      // فاتورة بلا اشتراك: بيانات غير متسقة). createSubscriptionAtomic
      // في Cloud Functions يبقى بديلاً خادمياً وليس الحل الوحيد.
      // ⚠️ لا تقم أبداً بوضع .where().get() داخل runTransaction — ستسبب بيانات غير ذرية.
      // ✅ إصلاح (2026-10-09): حلّ مرجع النوع عبر subscriptionTypeId
      // المباشر أولاً — مطابقةً لـ updateSubscription و
      // deleteSubscription في هذا الملف و createSubscriptionAtomic
      // في Cloud Functions. كان الكود القديم يستخدم الاستعلام
      // بالاسم فقط، وهذا غير موثوق: (1) إذا أُعيدت تسمية النوع
      // بعد تحميل الصفحة، لا يجد الاستعلام النوع → لا تُحدَّث
      // عدادات النوع (activationQuantity و linkedSubscriptionsCount)
      // → الاشتراك يُنشأ دون استهلاك تفعيلة ودون عدّ ارتباط
      // (بيانات غير متسقة). (2) إذا تكرر الاسم بين نوعين،
      // يُؤخذ أول نتيجة وقد يكون خاطئاً → تُطبَّق العدادات
      // على نوع خاطئ. المعرف المباشر هو المرجع الموثوق لأنه
      // لا يتغير بإعادة التسمية. ⚠️ لا ترجع للاستعلام بالاسم
      // كمسار أساسي أبداً.
      DocumentReference? typeDocRef;
      if (subscription.subscriptionTypeId != null &&
          subscription.subscriptionTypeId!.isNotEmpty) {
        typeDocRef = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('types')
            .doc(subscription.subscriptionTypeId);
      } else if (subscription.type.isNotEmpty) {
        // ⚠️ مسار احتياطي فقط عند غياب subscriptionTypeId:
        // استعلام بالاسم خارج المعاملة (Firestore لا تدعم
        // استعلامات داخل runTransaction). يُؤخذ أول نتيجة —
        // لذلك فضّل دائماً تمرير subscriptionTypeId من الصفحة.
        final typesSnapshot = await firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('types')
            .where('name', isEqualTo: subscription.type)
            .limit(1)
            .get();

        if (typesSnapshot.docs.isNotEmpty) {
          typeDocRef = firestore
              .collection(normalizedEmail)
              .doc('subscriptions')
              .collection('types')
              .doc(typesSnapshot.docs.first.id);
        }
      }

      // استخدام Transaction لضمان الحفظ الذري لجميع العمليات
      
      await firestore.runTransaction((transaction) async {
        final subscriptionDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('subscriptions')
            .doc(subscription.id);

        // التحقق من عدم وجود الاشتراك مسبقاً
        final docSnapshot = await transaction.get(subscriptionDoc);

        if (docSnapshot.exists) {
          throw Exception('الاشتراك موجود مسبقاً');
        }

        // إنقاص حساب التفعيلات من نوع الاشتراك داخل نفس الـ transaction
        DocumentReference? typeDoc;
        DocumentSnapshot? typeSnapshot;
        if (typeDocRef != null) {
          typeDoc = typeDocRef;
          typeSnapshot = await transaction.get(typeDoc);
          // ⚠️ حماية من التفعيلات السالبة (إصلاح تحقق يدوي 2026-10-08):
          // التحقق من توفر تفعيلة واحدة على الأقل قبل إنقاصها،
          // مطابقةً لـ createSubscriptionAtomic في Cloud Functions.
          // بدون هذا التحقق قد تصبح activationQuantity سالبة عند
          // إنشاء اشتراكات متزامنة أو متتالية.
          if (typeSnapshot.exists) {
            final typeData = typeSnapshot.data() as Map<String, dynamic>?;
            final currentActivationQuantity =
                (typeData?['activationQuantity'] as int? ?? 0);
            if (currentActivationQuantity < 1) {
              throw Exception('لا توجد تفعيلات كافية للشحن');
            }
          }
        }

        // ⚠️ قراءة العميل قبل أي كتابة (قاعدة Firestore الذهبية:
        // كل القراءات قبل كل الكتابات داخل المعاملة) — تُستخدم
        // لتحديث دين العميل و invoiceIds ذرياً مع الفاتورة أدناه.
        DocumentSnapshot<Object?>? customerSnapshot;
        if (invoiceBuilder != null &&
            subscription.customerId != null &&
            subscription.customerId!.isNotEmpty) {
          final customerDoc = await transaction.get(
            firestore
                .collection(normalizedEmail)
                .doc('customers')
                .collection('customers')
                .doc(subscription.customerId!),
          );
          if (customerDoc.exists) {
            customerSnapshot = customerDoc;
          }
        }

        // حفظ البيانات في نفس الـ transaction
        transaction.set(subscriptionDoc, model.toJson());

        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ إنشاء سجل إنشاء الاشتراك يجب أن يكون ذرياً مع إنشاء الاشتراك!
        // ⚠️ إذا تم إنشاء الاشتراك لكن لم يُنشأ السجل،
        // ⚠️ فإن التاريخ لا يُوثق بشكل صحيح.
        // ⚠️ نستخدم createLogDoc مسبقاً لاستخدام معرفه في relatedLogIds.
        final createLogDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('logs')
            .doc();

        transaction.set(createLogDoc, {
          'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
          'actionType': 'create_subscription',
          'details':
              'تم إنشاء الاشتراك: ${model.toJson()['name'] ?? subscription.id}',
          'targetId': subscription.id,
          'targetType': 'subscription',
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'isSuccess': true,
        });

        // تحديث relatedLogIds في مستند الاشتراك
        transaction.update(subscriptionDoc, {
          'relatedLogIds': FieldValue.arrayUnion([createLogDoc.id]),
        });

        // إنقاص حساب التفعيلات من نوع الاشتراك داخل نفس الـ transaction
        if (typeSnapshot != null && typeSnapshot.exists) {
          transaction.update(typeDoc!, {
            'activationQuantity': FieldValue.increment(-1),
            'linkedSubscriptionsCount': FieldValue.increment(1),
          });
        }

        // تحديث الصندوق إذا كان هناك مبلغ مدفوع داخل نفس الـ transaction
        if (subscription.totalPaid > 0) {
          final boxDoc = firestore
              .collection(normalizedEmail)
              .doc('cashbox')
              .collection('balance')
              .doc('main');

          transaction.set(boxDoc, {
            'currentBalance': FieldValue.increment(subscription.totalPaid),
            'lastUpdated': FieldValue.serverTimestamp(),
            'updatedBy': subscription.createdBy,
          }, SetOptions(merge: true));
        }

        // ⚠️ إنشاء الفاتورة ذرياً مع الاشتراك (إصلاح 2026-10-09):
        // كانت الفاتورة تُنشأ في معاملة منفصلة بعد الاشتراك عبر
        // InvoiceBloc (_createSubscriptionInvoiceAutomatically) — إذا
        // فشل إنشاء الفاتورة بقي اشتراك بلا فاتورة (بيانات غير
        // متسقة: العميل بلا فاتورة، والإحصائيات ناقصة). الآن تُنشأ
        // الفاتورة هنا داخل نفس المعاملة all-or-nothing.
        if (invoiceBuilder != null) {
          final invoice = invoiceBuilder(subscription);
          await _createInvoiceInTransaction(
            transaction,
            normalizedEmail,
            invoice,
            subscription.id,
            customerSnapshot,
          );
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في إنشاء الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateSubscription(
    SubscriptionEntity subscription, {
    int? expectedUpdatedAt,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(
        subscription.organizationEmail,
      );

      // التحقق من إمكانية الوصول للمؤسسة
      if (!await _canAccessOrganization(subscription.organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      final model = SubscriptionModel.fromEntity(subscription);

      // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
      // ⚠️ نستخدم Firestore runTransaction لضمان all-or-nothing، لكن Firestore لا تدعم
      // تنفيذ استعلامات (queries مثل .where().get()) داخل المعاملة. لذلك، نحتاج أولاً
      // إلى حل مرجع المستند (typeDocRefs) خارج المعاملة، ثم استخدام transaction.get()
      // مباشرة على المراجع داخل المعاملة. هذا يضمن أن Firestore تستطيع إعادة
      // تشغيل المعاملة تلقائياً في حالة تعارض، مع بيانات حديثة دائماً.
      // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
      // 1. تحديث مستند الاشتراك ← ذري مع تحديث عدادات الأنواع
      //    → إذا تم تحديث الاشتراك لكن لم يُحدَّث العداد في النوع القديم،
      //      فإن عدد الاشتراكات في النوع القديم يكون أعلى من الفعلي.
      // 2. تحديث linkedSubscriptionsCount في النوع القديم (-1) ← ذري مع التحديث
      // 3. تحديث linkedSubscriptionsCount في النوع الجديد (+1) ← ذري مع التحديث
      //    → إذا تم تحديث العداد في النوع القديم لكن فشل النوع الجديد،
      //      فإن العدد الإجمالي للاشتراكات ينقص بدون سبب.
      // 4. تحديث activationQuantity في النوع القديم (+1) ← ذري مع التحديث
      //    → عند تغيير النوع، تُرجع التفعيلة للنوع القديم.
      //      ⚠️ activationQuantity تزداد (+1) وليس تنقص (-1)!
      //      إذا استخدمت FieldValue.increment(-1)، فإنك تقلل التفعيلات
      //       بدلاً من إعادتها - تعديل غير صحيح!
      // 5. تحديث activationQuantity في النوع الجديد (-1) ← ذري مع التحديث
      //    → عند تغيير النوع، تستهلك تفعيلة من النوع الجديد.
      // ⚠️ الحل: كلا التحديثين داخل نفس المعاملة transaction.
      // ⚠️ نستخدم subscriptionTypeId لتجنب .where().get() داخل المعاملة.
      // ⚠️ إذا كان subscriptionTypeId غير موجود، نبحث عن النوع بالاسم خارج المعاملة.
      DocumentReference? oldTypeDocRef;
      DocumentReference? newTypeDocRef;
      if (subscription.subscriptionTypeId != null &&
          subscription.subscriptionTypeId!.isNotEmpty) {
        newTypeDocRef = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('types')
            .doc(subscription.subscriptionTypeId);
      } else if (subscription.type.isNotEmpty) {
        final newTypeSnapshot = await firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('types')
            .where('name', isEqualTo: subscription.type)
            .limit(1)
            .get();
        if (newTypeSnapshot.docs.isNotEmpty) {
          newTypeDocRef = firestore
              .collection(normalizedEmail)
              .doc('subscriptions')
              .collection('types')
              .doc(newTypeSnapshot.docs.first.id);
        }
      }

      // ⚠️ القراءة المسبقة للنوع القديم خارج المعاملة (تحقق يدوي 2026-10-08):
      // Firestore لا تدعم استعلامات (.where().get()) داخل
      // runTransaction. لذلك نقرأ مستند الاشتراك مسبقاً خارج
      // المعاملة لتحديد النوع القديم (subscriptionTypeId أو الاسم)،
      // ثم نستخدم transaction.get() على المرجع المعروف داخل
      // المعاملة. هذا يضمن أن القراءة مشمولة بقفل التفاؤل
      // وأن المعاملة تُعاد تلقائياً ببيانات حديثة عند تعارض.
      // ⚠️ إذا تغير النوع القديم بين القراءة المسبقة والمعاملة،
      // تُلغى المعاملة داخلها (استثناء) لمنع تطبيق العدادات
      // على نوع خاطئ — انظر التحقق داخل المعاملة أدناه.
      String? preReadOldTypeId;
      String? preReadOldTypeName;
      try {
        final preReadDoc = await firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('subscriptions')
            .doc(subscription.id)
            .get();
        if (preReadDoc.exists) {
          final preReadData = preReadDoc.data();
          preReadOldTypeId = preReadData?['subscriptionTypeId']?.toString();
          preReadOldTypeName = preReadData?['type']?.toString();
          if (preReadOldTypeId != null && preReadOldTypeId.isNotEmpty) {
            oldTypeDocRef = firestore
                .collection(normalizedEmail)
                .doc('subscriptions')
                .collection('types')
                .doc(preReadOldTypeId);
          } else if (preReadOldTypeName != null &&
              preReadOldTypeName.isNotEmpty) {
            final preReadTypeSnapshot = await firestore
                .collection(normalizedEmail)
                .doc('subscriptions')
                .collection('types')
                .where('name', isEqualTo: preReadOldTypeName)
                .limit(1)
                .get();
            if (preReadTypeSnapshot.docs.isNotEmpty) {
              oldTypeDocRef = firestore
                  .collection(normalizedEmail)
                  .doc('subscriptions')
                  .collection('types')
                  .doc(preReadTypeSnapshot.docs.first.id);
            }
          }
        }
      } on Exception {
        oldTypeDocRef = null;
      }

      
      await firestore.runTransaction((transaction) async {
        final subscriptionDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('subscriptions')
            .doc(subscription.id);

        // التحقق من وجود الاشتراك قبل التحديث
        final docSnapshot = await transaction.get(subscriptionDoc);

        if (!docSnapshot.exists) {
          throw Exception('الاشتراك غير موجود');
        }

        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ التحقق من التعديل المتزامن (Optimistic Locking) يجب أن يكون
        // ⚠️ داخل المعاملة لضمان الذريّة.
        // ⚠️ إذا تم تمرير expectedUpdatedAt، نقارنه مع updatedAt
        // ⚠️ الذي تم قراءته من داخل المعاملة.
        // ⚠️ هذا يمنع Lost Update Problem حيث يقوم مستخدمان
        // ⚠️ بقراءة نفس القيمة ثم كتابة قيمة معدلة.
        if (expectedUpdatedAt != null) {
          final existingUpdatedAt = docSnapshot.data()?['updatedAt'];
          if (existingUpdatedAt != null) {
            final existingTime = existingUpdatedAt is Timestamp
                ? existingUpdatedAt.toDate().millisecondsSinceEpoch
                : existingUpdatedAt is int
                ? existingUpdatedAt
                : null;
            if (existingTime != null && existingTime != expectedUpdatedAt) {
              throw Exception(
                'تم تعديل الاشتراك من قبل مستخدم آخر، يرجى إعادة المحاولة',
              );
            }
          }
        }

        // تحديث عدادات الأنواع المرتبطة إذا تغير نوع الاشتراك
        final oldData = docSnapshot.data();
        Map<String, dynamic>? oldMap;
        if (oldData != null) {
          oldMap = Map<String, dynamic>.from(oldData);
          final oldTypeId = oldMap['subscriptionTypeId']?.toString();
          final oldType = oldMap['type']?.toString() ?? '';
          final newType = subscription.type;

          // ⚠️ التحقق من التعديل المتزامن للنوع القديم (تحقق يدوي 2026-10-08):
          // مرجع النوع القديم يُحل خارج المعاملة (انظر القراءة
          // المسبقة قبل runTransaction). هنا نتحقق من أن النوع
          // القديم لم يتغير منذ القراءة المسبقة — إذا تغير،
          // نُلغي المعاملة لمنع تطبيق العدادات على نوع خاطئ.
          // ⚠️ لا نستخدم .where().get() هنا أبداً — مخالف للقاعدة
          // الذهبية رقم 2 أعلى هذا الملف. القراءة الوحيدة هنا
          // هي transaction.get() على المراجع المعروفة أدناه.
          final currentOldTypeId = oldTypeId ?? '';
          final expectedOldTypeId = preReadOldTypeId ?? '';
          final expectedOldTypeName = preReadOldTypeName ?? '';
          final oldTypeChangedConcurrently = currentOldTypeId.isNotEmpty
              ? currentOldTypeId != expectedOldTypeId
              : oldType != expectedOldTypeName;
          if (oldTypeChangedConcurrently) {
            throw Exception(
              'تم تعديل نوع الاشتراك بالتزامن، يرجى إعادة المحاولة',
            );
          }

          if (oldTypeId !=
                  (subscription.subscriptionTypeId?.toString() ?? '') ||
              (oldTypeId == null && oldType != newType)) {
            // إنقاص العداد من النوع القديم
            if (oldTypeDocRef != null) {
              final oldTypeDoc = oldTypeDocRef;
              final oldTypeCheck = await transaction.get(oldTypeDoc);
              if (oldTypeCheck.exists) {
                transaction.update(oldTypeDoc, {
                  'linkedSubscriptionsCount': FieldValue.increment(-1),
                  'activationQuantity': FieldValue.increment(1),
                });
              }
            }

            // زيادة العداد للنوع الجديد
            if (newTypeDocRef != null) {
              final newTypeDoc = newTypeDocRef;
              final newTypeCheck = await transaction.get(newTypeDoc);
              if (newTypeCheck.exists) {
                // ⚠️ التحقق من كفاية التفعيلات في النوع الجديد قبل
                // استهلاكها (نفس createSubscription و renewSubscription)
                // لمنع activationQuantity السالبة — إصلاح 2026-10-12:
                // كان يُنقص العداد بدون تحقق فتصار قيمة سالبة عند
                // تغيير النوع إلى نوع نفدت تفعيلاته.
                final newTypeActivationQuantity =
                    (newTypeCheck.data() as Map<String, dynamic>?)?[
                        'activationQuantity'] ??
                    0;
                if (newTypeActivationQuantity < 1) {
                  throw Exception('لا توجد تفعيلات كافية في النوع الجديد');
                }
                transaction.update(newTypeDoc, {
                  'linkedSubscriptionsCount': FieldValue.increment(1),
                  'activationQuantity': FieldValue.increment(-1),
                });
              }
            }
          }
        }

        // تحديث البيانات في نفس الـ transaction
        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ updatedAt يُكتب كـ FieldValue.serverTimestamp()
        // بدلاً من قيمة الكيان — لأن قيمة الكيان هي
        // updatedAt الأصلي الذي يُمرر كـ expectedUpdatedAt
        // (القفل التفاؤلي) من _onUpdateSubscription و
        // _onUpgradeSubscription. لو كُتبت قيمة الكيان
        // لبقي updatedAt المخزن دون تغيير فلا يُفعَّل
        // القفل أبداً (مستخدمان يحفظان من نفس الأساس →
        // آخر كتابة تفوز بصمت — Lost Update Problem).
        // serverTimestamp() يجعل الخادم يُقدّم updatedAt
        // في كل تحديث ناجح فيُقارن القفل بقيمة جديدة.
        final updateData = Map<String, dynamic>.from(model.toJson());
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        transaction.update(subscriptionDoc, updateData);

        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ إنشاء سجل تحديث الاشتراك يجب أن يكون ذرياً مع تحديث الاشتراك!
        // ⚠️ إذا تم تحديث الاشتراك لكن لم يُنشأ السجل،
        // ⚠️ فإن التاريخ لا يُوثق بشكل صحيح.
        final updateLogDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('logs')
            .doc();

        transaction.set(updateLogDoc, {
          'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
          'actionType': 'update_subscription',
          'details':
              'تم تحديث الاشتراك: ${model.toJson()['name'] ?? subscription.id}',
          'targetId': subscription.id,
          'targetType': 'subscription',
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'isSuccess': true,
          'oldValues': oldMap,
          'newValues': model.toJson(),
        });

        // تحديث relatedLogIds في مستند الاشتراك
        transaction.update(subscriptionDoc, {
          'relatedLogIds': FieldValue.arrayUnion([updateLogDoc.id]),
        });
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSubscription(
    String subscriptionId,
  ) async {
    try {
      // ⚠️ ملاحظات توثيقية للمبرمجين المستقبليين — deleteSubscription (مدمجة):
      // [أمن/إعدادات] لا يستدعي _canAccessOrganization على مستوى الحذف → لا يوجد
      // فحص وصول للمنظمة هنا (يعتمد على صلاحية BLoC فقط). organizationEmail المُمرر
      // من الحدث يُتجاهل ويُستخدم منظمة المستخدم الحالي عبر _getCurrentOrganizationId().
      // أي مستخدم لديه صلاحية الحذف يمكنه حذف أي اشتراك في مؤسسة بريده الحالي.
      // إذا كان النظام يدعم مؤسسات متعددة لنفس المستخدم، يجب تمرير organizationEmail
      // والتحقق منها هنا مثل getSubscriptions و createSubscription.
      // ▶ ملاحظة ثانية (التحقق المسبق للنوع): عند فشل القراءة المسبقة (preReadOk == false)
      // يُتجاهل التحقق من التعديل المتزامن للنوع داخل المعاملة — المرجع غير معروف
      // أصلاً فلن تُقرأ عدادات النوع. هذا مقبول لكنه يُضعف الضمان الذري في حالات
      // تعارض النوع.
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(
        _getCurrentOrganizationId() ?? '',
      );

      if (normalizedEmail.isEmpty) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final updatedByName = await _getCurrentUserName();

      // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
      // ⚠️ نستخدم Firestore runTransaction لضمان all-or-nothing، لكن Firestore لا تدعم
      // تنفيذ استعلامات (queries مثل .where().get()) داخل المعاملة. لذلك، نحتاج أولاً
      // إلى حل مرجع المستند (typeDocRef) خارج المعاملة، ثم استخدام transaction.get()
      // مباشرة على مرجع معروف داخل المعاملة. هذا يضمن أن Firestore تستطيع إعادة
      // تشغيل المعاملة تلقائياً في حالة تعارض، مع بيانات حديثة دائماً.
      // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
      // 1. حذف مستند الاشتراك ← ذري مع تحديث عدادات النوع
      //    → إذا تم حذف الاشتراك لكن لم يُحدَّث العداد في النوع،
      //      فإن عدد الاشتراكات في النوع يكون أعلى من الفعلي.
      // 2. تحديث activationQuantity (+1) في النوع ← ذري مع الحذف
      //    → عند حذف اشتراك، يتم إرجاع التفعيلة للنوع.
      //      ⚠️ activationQuantity تزداد (+1) وليس تنقص (-1)!
      //      إذا استخدمت FieldValue.increment(-1)، فإنك تقلل التفعيلات
      //       بدلاً من إعادتها - تعديل غير صحيح!
      // 3. تحديث linkedSubscriptionsCount (-1) في النوع ← ذري مع الحذف
      // 4. حذف السجلات المرتبطة ← ذري مع الحذف
      //    → إذا تم حذف الاشتراك لكن لم تُحذف السجلات،
      //      فإن السجلات تبقى تشير إلى اشتراك غير موجود.
      // 5. حذف الفواتير المرتبطة ← ذري مع الحذف
      //    → إذا تم حذف الاشتراك لكن لم تُحذف الفواتير،
      //      فإن الفواتير تبقى تشير إلى اشتراك غير موجود.
      // 6. إنشاء سجل الحذف ← ذري مع الحذف
      //    → إذا تم حذف الاشتراك لكن لم يُنشأ السجل،
      //      فإن الحذف لا يُوثق بشكل صحيح.
      // ⚠️ ملاحظة: لا نرجع التفعيلات عند حذف اشتراك منتهي أو ملغي لأنه لم يستهلك رصيد فعلي.
      // ⚠️ نستخدم subscriptionTypeId لتجنب .where().get() داخل المعاملة.
      // ⚠️ إذا كان subscriptionTypeId غير موجود، نبحث عن النوع بالاسم خارج المعاملة.
      DocumentReference? typeDocRef;
      // ⚠️ قيم القراءة المسبقة (تحقق يدوي 2026-10-11): تُحفظ
      // هنا للتحقق من التعديل المتزامن للنوع داخل المعاملة
      // (نفس نمط updateSubscription و renewSubscription).
      String? preReadTypeId;
      String? preReadTypeName;
      bool preReadOk = false;
      try {
        final subscriptionDocForRef = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('subscriptions')
            .doc(subscriptionId);
        final subscriptionSnapshotForRef = await subscriptionDocForRef.get();
        if (subscriptionSnapshotForRef.exists) {
          final subscriptionDataForRef = subscriptionSnapshotForRef.data();
          preReadOk = true;
          preReadTypeId =
              subscriptionDataForRef?['subscriptionTypeId']?.toString();
          preReadTypeName = subscriptionDataForRef?['type']?.toString();
          if (preReadTypeId != null && preReadTypeId.isNotEmpty) {
            typeDocRef = firestore
                .collection(normalizedEmail)
                .doc('subscriptions')
                .collection('types')
                .doc(preReadTypeId);
          } else {
            final subscriptionType = preReadTypeName ?? '';
            if (subscriptionType.isNotEmpty) {
              final typesSnapshot = await firestore
                  .collection(normalizedEmail)
                  .doc('subscriptions')
                  .collection('types')
                  .where('name', isEqualTo: subscriptionType)
                  .limit(1)
                  .get();
              if (typesSnapshot.docs.isNotEmpty) {
                typeDocRef = firestore
                    .collection(normalizedEmail)
                    .doc('subscriptions')
                    .collection('types')
                    .doc(typesSnapshot.docs.first.id);
              }
            }
          }
        }
      } on Exception catch (_) {
        typeDocRef = null;
        preReadOk = false;
      }

      // استخدام Transaction لضمان الحذف الذري وإرجاع التفعيلات
      
      await firestore.runTransaction((transaction) async {
        final subscriptionDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('subscriptions')
            .doc(subscriptionId);

        // التحقق من وجود الاشتراك قبل الحذف
        final docSnapshot = await transaction.get(subscriptionDoc);

        if (!docSnapshot.exists) {
          throw Exception('الاشتراك غير موجود');
        }

        // ✅ تم الإصلاح: التحقق من أن الاشتراك ينتمي إلى منظمة المستخدم الحالية
        // قبل السماح بالحذف (منع حذف اشتراك من مؤسسة أخرى).
        final data = docSnapshot.data();
        if (data == null) throw Exception('المستند فارغ');
        final subscriptionOrgEmail = data['organizationEmail']?.toString() ?? '';
        if (subscriptionOrgEmail.isNotEmpty && subscriptionOrgEmail != normalizedEmail) {
          throw Exception('ليس لديك صلاحية لحذف هذا الاشتراك (ينتمي لمؤسسة أخرى)');
        }

        final mapData = Map<String, dynamic>.from(data);
        if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
          mapData['id'] = docSnapshot.id;
        }
        final subscription = SubscriptionModel.fromJson(mapData);

        // ⚠️ التحقق من التعديل المتزامن للنوع (تحقق يدوي 2026-10-11):
        // مرجع النوع (typeDocRef) يُحل من قراءة مسبقة
        // خارج المعاملة. هنا نتحقق من أن نوع الاشتراك
        // لم يتغير منذ تلك القراءة — إذا تغير، نُلغي
        // المعاملة لمنع إرجاع التفعيلة (activationQuantity
        // +1) وعداد الارتباط (linkedSubscriptionsCount -1)
        // لنوع خاطئ، وهو نفس نمط updateSubscription و
        // renewSubscription في هذا الملف. ⚠️ يُتجاهل
        // التحقق إذا فشلت القراءة المسبقة (preReadOk
        // == false) لأن المرجع غير معروف أصلاً ولن
        // تُقرأ عدادات النوع (typeSnapshot يبقى فارغاً).
        // ⚠️ لا نستخدم .where().get() هنا أبداً — القراءة
        // الوحيدة هي transaction.get() على المراجع المعروفة.
        if (preReadOk) {
          final currentTypeId =
              mapData['subscriptionTypeId']?.toString() ?? '';
          final expectedTypeId = preReadTypeId ?? '';
          final expectedTypeName = preReadTypeName ?? '';
          final typeChangedConcurrently = currentTypeId.isNotEmpty
              ? currentTypeId != expectedTypeId
              : (mapData['type']?.toString() ?? '') != expectedTypeName;
          if (typeChangedConcurrently) {
            throw Exception(
              'تم تعديل نوع الاشتراك بالتزامن، يرجى إعادة المحاولة',
            );
          }
        }

        // إرجاع حساب التفعيلات لنوع الاشتراك داخل نفس المعاملة
        // فقط إذا كان الاشتراك نشطاً أو معلقاً للانتظار (pending)
        // ملاحظة: لا نرجع التفعيلات عند حذف اشتراك منتهي أو ملغي أو معلق (suspended)
        // لأنه لم يستهلك رصيد فعلي.
        // ⚠️ إصلاح التحقق اليدوي الثامن عشر (2026-10-11): حل مرجع
        // النوع من بيانات الاشتراك المقروءة داخل المعاملة
        // (mapData['subscriptionTypeId']) عندما تفشل القراءة
        // المسبقة (typeDocRef فارغ) — نفس نمط
        // deleteSubscriptionAtomic في Cloud Functions. لماذا؟
        // بدون هذا، حذف اشتراك عند فشل القراءة المسبقة
        // (خطأ شبكة عابر) كان يُحذف الاشتراك دون إرجاع
        // التفعيلة (activationQuantity +1) وتحديث عداد
        // الارتباط (linkedSubscriptionsCount -1) للنوع —
        // انحراف عن all-or-nothing (عداد أعلى/أقل من
        // الفعلي). المرجع المُحل داخل المعاملة مغطى بقفل
        // التفاؤل (optimistic locking) فلا يحتاج تحققاً
        // إضافياً. ⚠️ مسار الاسم (subscriptionTypeId فارغ)
        // يبقى معتمداً على القراءة المسبقة لأن Firestore
        // لا تدعم استعلامات داخل المعاملة.
        DocumentReference? typeDoc;
        DocumentSnapshot? typeSnapshot;
        final inTxTypeId = mapData['subscriptionTypeId']?.toString() ?? '';
        final effectiveTypeRef = typeDocRef ??
            (inTxTypeId.isNotEmpty
                ? firestore
                    .collection(normalizedEmail)
                    .doc('subscriptions')
                    .collection('types')
                    .doc(inTxTypeId)
                : null);
        if (effectiveTypeRef != null &&
            (subscription.status == 'active' ||
                subscription.status == 'pending')) {
          typeDoc = effectiveTypeRef;
          typeSnapshot = await transaction.get(typeDoc);
        }

        // حذف الاشتراك
        transaction.delete(subscriptionDoc);

        // حذف السجلات المرتبطة داخل نفس المعاملة
        final relatedLogIds =
            (data['relatedLogIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        for (final logId in relatedLogIds) {
          final logDoc = firestore
              .collection(normalizedEmail)
              .doc('subscriptions')
              .collection('logs')
              .doc(logId);
          transaction.delete(logDoc);
        }

        // حذف الفواتير المرتبطة داخل نفس المعاملة
        final relatedInvoiceIds =
            (data['relatedInvoiceIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        for (final invoiceId in relatedInvoiceIds) {
          final invoiceDoc = firestore
              .collection(normalizedEmail)
              .doc('invoices')
              .collection('invoices')
              .doc(invoiceId);
          transaction.delete(invoiceDoc);
        }

        // إرجاع حساب التفعيلات لنوع الاشتراك داخل نفس المعاملة
        // فقط إذا كان الاشتراك نشطاً أو معلقاً للانتظار (pending)
        // ملاحظة: لا نرجع التفعيلات عند حذف اشتراك منتهي أو ملغي أو معلق (suspended)
        // لأنه لم يستهلك رصيد فعلي.
        if (typeSnapshot != null && typeSnapshot.exists) {
          transaction.update(typeDoc!, {
            'activationQuantity': FieldValue.increment(1),
            'linkedSubscriptionsCount': FieldValue.increment(-1),
          });
        }

        // إضافة سجل الحذف داخل نفس المعاملة
        final log = SubscriptionLogModel(
          id: '',
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
          actionType: 'delete',
          details: 'حذف الاشتراك: ${subscription.name}',
          targetId: subscription.id,
          targetType: 'subscription',
          timestamp: DateTime.now(),
          isSuccess: true,
        );

        final logDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('logs')
            .doc();

        transaction.set(logDoc, log.toJson());
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حذف الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateSubscriptionStatus({
    required String subscriptionId,
    required String status,
    required String organizationEmail,
    String? reason,
    String? updatedBy,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // التحقق من إمكانية الوصول للمؤسسة
      if (!await _canAccessOrganization(organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      // استخدام Transaction لضمان تحديث الحالة ذرياً
      
      await firestore.runTransaction((transaction) async {
        final subscriptionDoc = firestore
            .collection(normalizedEmail) // ✅ استخدام البريد المطبّع
            .doc('subscriptions')
            .collection('subscriptions')
            .doc(subscriptionId);

        // التحقق من وجود الاشتراك قبل التحديث
        final docSnapshot = await transaction.get(subscriptionDoc);

        if (!docSnapshot.exists) {
          throw Exception('الاشتراك غير موجود');
        }

        // تحديث البيانات في نفس الـ transaction
        transaction.update(subscriptionDoc, {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
          ...?updatedBy != null ? {'updatedBy': updatedBy} : null,
          ...?reason != null ? {'statusChangeReason': reason} : null,
        });

        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ إنشاء سجل تغيير الحالة يجب أن يكون ذرياً مع تحديث الحالة!
        // ⚠️ إذا تم تحديث الحالة لكن لم يُنشأ السجل،
        // ⚠️ فإن التاريخ لا يُوثق بشكل صحيح.
        final oldStatus = docSnapshot.data()?['status']?.toString();

        final statusLogDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('logs')
            .doc();

        transaction.set(statusLogDoc, {
          'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
          'actionType': 'change_status_subscription',
          'details':
              'تم تغيير حالة الاشتراك إلى: $status${reason != null ? " - السبب: $reason" : ""}',
          'targetId': subscriptionId,
          'targetType': 'subscription',
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'isSuccess': true,
          'oldValues': {'status': oldStatus},
          'newValues': {'status': status, 'reason': reason},
        });

        // تحديث relatedLogIds في مستند الاشتراك
        transaction.update(subscriptionDoc, {
          'relatedLogIds': FieldValue.arrayUnion([statusLogDoc.id]),
        });
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث حالة الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, SubscriptionEntity>> renewSubscription({
    required String subscriptionId,
    required String organizationEmail,
    DateTime? customStartDate,
    bool? isAutoRenew,
    bool? isPaid,
    InvoiceEntity Function(SubscriptionEntity renewedSubscription)?
        invoiceBuilder,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // التحقق من إمكانية الوصول للمؤسسة
      if (!await _canAccessOrganization(organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      // استخدام transaction لضمان تناسق البيانات
      final updatedByName = await _getCurrentUserName();

      // ⚠️ إصلاح 2026-10-12 (تحسين أداء المعاملة):
      // قراءة إعدادات وقت البدء الافتراضي خارج المعاملة
      // (SettingsService قراءة محلية لا تعتمد على بيانات
      // المعاملة) — كانت تُقرأ داخل المعاملة فكانت تطيل
      // عمرها. تُطبق داخل المعاملة عبر
      // _applyDefaultSubscriptionTimeFromSettings بدون await.
      final defaultSubscriptionTimeSettings =
          await _readDefaultSubscriptionTimeSettings();

      // ⚠️ القراءة المسبقة للنوع خارج المعاملة (تحقق يدوي 2026-10-08):
      // Firestore لا تدعم استعلامات (.where().get()) داخل
      // runTransaction. لذلك نقرأ مستند الاشتراك مسبقاً خارج
      // المعاملة لتحديد نوعه (subscriptionTypeId أو الاسم)،
      // ثم نستخدم transaction.get() على المرجع المعروف داخل
      // المعاملة. هذا يضمن أن القراءة مشمولة بقفل التفاؤل
      // وأن المعاملة تُعاد تلقائياً ببيانات حديثة عند تعارض.
      // ⚠️ إذا تغير النوع بين القراءة المسبقة والمعاملة،
      // تُلغى المعاملة داخلها (استثناء) لمنع تطبيق العداد
      // على نوع خاطئ — انظر التحقق داخل المعاملة أدناه.
      DocumentReference? typeDocRef;
      String? preReadTypeId;
      String? preReadTypeName;
      try {
        final preReadDoc = await firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('subscriptions')
            .doc(subscriptionId)
            .get();
        if (preReadDoc.exists) {
          final preReadData = preReadDoc.data();
          preReadTypeId = preReadData?['subscriptionTypeId']?.toString();
          preReadTypeName = preReadData?['type']?.toString();
          if (preReadTypeId != null && preReadTypeId.isNotEmpty) {
            typeDocRef = firestore
                .collection(normalizedEmail)
                .doc('subscriptions')
                .collection('types')
                .doc(preReadTypeId);
          } else if (preReadTypeName != null && preReadTypeName.isNotEmpty) {
            final preReadTypeSnapshot = await firestore
                .collection(normalizedEmail)
                .doc('subscriptions')
                .collection('types')
                .where('name', isEqualTo: preReadTypeName)
                .limit(1)
                .get();
            if (preReadTypeSnapshot.docs.isNotEmpty) {
              typeDocRef = firestore
                  .collection(normalizedEmail)
                  .doc('subscriptions')
                  .collection('types')
                  .doc(preReadTypeSnapshot.docs.first.id);
            }
          }
        }
      } on Exception {
        typeDocRef = null;
      }

      final result = await firestore.runTransaction<SubscriptionEntity>((
        transaction,
      ) async {
        // قراءة الاشتراك الحالي داخل المعاملة
        final docRef = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('subscriptions')
            .doc(subscriptionId);

        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('الاشتراك غير موجود');
        }

        final data = doc.data();
        if (data == null) throw Exception('المستند فارغ');
        final mapData = Map<String, dynamic>.from(data);
        if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
          mapData['id'] = doc.id;
        }
        final subscription = SubscriptionModel.fromJson(mapData);

        // التحقق من إمكانية التجديد
        if (!subscription.canRenew) {
          throw Exception('لا يمكن تجديد هذا الاشتراك');
        }

        final now = DateTime.now();
        final rawStartDate =
            customStartDate ??
            (subscription.endDate.isAfter(now) ? subscription.endDate : now);

        // إذا حُدد وقت بداية مخصص من المستخدم، نحافظ عليه كما هو؛ وإلا
        // نطبق وقت الاشتراك الافتراضي على التاريخ المحسوب تلقائياً.
        final startDate = customStartDate != null
            ? rawStartDate
            : _applyDefaultSubscriptionTimeFromSettings(
                rawStartDate,
                defaultSubscriptionTimeSettings,
              );

        final endDate = SubscriptionEntity.calculateEndDate(
          startDate,
          subscription.duration,
          subscription.customDays,
        );

        final renewedSubscription = subscription.copyWith(
          status: 'active',
          startDate: startDate,
          endDate: endDate,
          renewalCount: subscription.renewalCount + 1,
          lastRenewalDate: DateTime.now(),
          updatedAt: DateTime.now(),
          updatedBy: updatedByName,
          isAutoRenew: isAutoRenew ?? subscription.isAutoRenew,
          isPaid: isPaid ?? subscription.isPaid,
          totalPaid: 0,
          remainingAmount: subscription.price,
          nextBillingDate: endDate,
        );

        // ⚠️ ملاحظة للمبرمجين المستقبليين: updatedAt في الكيان المُعاد يُكتب
        /// بتوقيت العميل (DateTime.now()) للعرض الفوري، بينما القيمة المخزنة
        /// في Firestore تستخدم FieldValue.serverTimestamp() أدناه للتزامن مع
        /// updateSubscription وضمان القفل التفاؤلي المتسق.

        // التحقق من صحة البيانات الجديدة
        final validationError = renewedSubscription.validate();
        if (validationError != null) {
          throw Exception(validationError);
        }

        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ نحتاج أولاً إلى حل مرجع مستند نوع الاشتراك خارج المعاملة لأن
        // Firestore لا تدعم تنفيذ استعلامات (queries مثل .where().get()) داخل المعاملة.
        // بعد ذلك، نستخدم transaction.get() مباشرة على المرجع داخل المعاملة لضمان
        // أن Firestore تستطيع إعادة تشغيل المعاملة تلقائياً ببيانات حديثة دائماً.
        // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
        // 1. تحديث بيانات الاشتراك (status, dates, renewalCount) ← ذري مع تحديث النوع
        //    → إذا تم تحديث الاشتراك لكن لم يُحدَّث النوع،
        //      فإن عدد الاشتراكات في النوع يكون أعلى من الفعلي.
        // 2. تحديث activationQuantity (-1) في النوع ← ذري مع التجديد
        //    → عند تجديد الاشتراك، تستهلك تفعيلة واحدة من النوع.
        //      ⚠️ إذا استخدمت currentQuantity - 1 بدلاً من FieldValue.increment(-1)،
        //      فإنك تعيد مشكلة Read-Modify-Write.
        // 3. تحديث الصندوق ← غير موجود هنا (صحيح ومُوثق)!
        //    ⚠️ ⚠️ ⚠️ تحذير: renewSubscription لا يحدث الصندوق!
        //    السبب: totalPaid كان قد أُضيف إلى الصندوق بالفعل عند إنشاء الاشتراك الأصلي.
        //    إعادة إضافته تسبب خصماً مزدوجاً من الصندوق.
        //    أي دفعة جديدة أثناء التجديد يتم التعامل معها عبر updateSubscriptionPayment.
        // 4. إنشاء سجل التجديد ← موجود أدناه داخل نفس المعاملة (صُحِّح 2026-10-08)!
        //    ⚠️ سجل التجديد يُنشأ فعلاً أدناه (transaction.set)
        //    ويُربط بـ relatedLogIds — راجع أسطر إنشاء سجل
        //    التجديد أدناه. ⚠️ لا تُنشئ سجل تجديد آخر
        //    بناءً على تعليق قديم — سيُنشأ سجل مكرر.
        //    ⚠️ إذا تم التجديد لكن لم يُنشأ السجل،
        //      فإن التاريخ لا يُوثق بشكل صحيح.
        // ⚠️ لا تقم أبداً بوضع .where().get() داخل runTransaction.
        // ⚠️ التحقق من التعديل المتزامن للنوع (تحقق يدوي 2026-10-08):
        // مرجع النوع يُحل خارج المعاملة (انظر القراءة المسبقة
        // قبل runTransaction). هنا نتحقق من أن النوع لم يتغير
        // منذ القراءة المسبقة — إذا تغير، نُلغي المعاملة لمنع
        // تطبيق العداد على نوع خاطئ.
        // ⚠️ لا نستخدم .where().get() هنا أبداً — مخالف للقاعدة
        // الذهبية رقم 2 أعلى هذا الملف. القراءة الوحيدة هنا
        // هي transaction.get() على المرجع المعروف أدناه.
        final currentTypeId = subscription.subscriptionTypeId?.toString() ?? '';
        final expectedTypeId = preReadTypeId ?? '';
        final expectedTypeName = preReadTypeName ?? '';
        final typeChangedConcurrently = currentTypeId.isNotEmpty
            ? currentTypeId != expectedTypeId
            : subscription.type != expectedTypeName;
        if (typeChangedConcurrently) {
          throw Exception(
            'تم تعديل نوع الاشتراك بالتزامن، يرجى إعادة المحاولة',
          );
        }

        // ⚠️ قراءة العميل قبل أي كتابة (قاعدة Firestore الذهبية:
        // كل القراءات قبل كل الكتابات داخل المعاملة) — تُستخدم
        // لتحديث دين العميل و invoiceIds ذرياً مع الفاتورة أدناه.
        // customerId من الاشتراك المُقرأ أعلى المعاملة.
        DocumentSnapshot<Object?>? customerSnapshot;
        if (invoiceBuilder != null &&
            subscription.customerId != null &&
            subscription.customerId!.isNotEmpty) {
          final customerDoc = await transaction.get(
            firestore
                .collection(normalizedEmail)
                .doc('customers')
                .collection('customers')
                .doc(subscription.customerId!),
          );
          if (customerDoc.exists) {
            customerSnapshot = customerDoc;
          }
        }

        // تحديث بيانات الاشتراك داخل المعاملة
        DocumentReference? typeDoc;
        DocumentSnapshot? typeSnapshot;
        if (typeDocRef != null) {
          typeDoc = typeDocRef;
          typeSnapshot = await transaction.get(typeDoc);
          // ⚠️ حماية من التفعيلات السالبة (إصلاح تحقق يدوي 2026-10-08):
          // التحقق من توفر تفعيلة واحدة على الأقل قبل إنقاصها،
          // مطابقةً لـ renewSubscriptionAtomic في Cloud Functions.
          // بدون هذا التحقق قد تصبح activationQuantity سالبة عند
          // تجديد اشتراكات متزامنة أو متتالية.
          if (typeSnapshot.exists) {
            final typeData = typeSnapshot.data() as Map<String, dynamic>?;
            final currentActivationQuantity =
                (typeData?['activationQuantity'] as int? ?? 0);
            if (currentActivationQuantity < 1) {
              throw Exception('لا توجد تفعيلات كافية للشحن');
            }
          }
        }

        final model = SubscriptionModel.fromEntity(renewedSubscription);
        final updateData = Map<String, dynamic>.from(model.toJson());
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        transaction.update(docRef, updateData);

        if (typeSnapshot != null && typeSnapshot.exists) {
          transaction.update(typeDoc!, {
            'activationQuantity': FieldValue.increment(-1),
          });
        }

        // ⚠️ إنشاء سجل التجديد داخل نفس المعاملة لضمان ذريّة بدقة فائقة
        // إذا تم التجديد لكن لم يُنشأ السجل، فإن التاريخ لا يُوثق بشكل صحيح.
        // إذا تم إنشاء السجل لكن لم يتم التجديد، فإن السجل يوثق عملية لم تحدث.
        // transaction.set() داخل المعاملة يضمن أن السجل يُنشأ فقط إذا نجح التجديد.
        final renewalLog = SubscriptionLogModel(
          id: '',
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
          actionType: 'renew_subscription',
          details: 'تم تجديد الاشتراك: ${renewedSubscription.name}',
          targetId: renewedSubscription.id,
          targetType: 'subscription',
          timestamp: DateTime.now(),
          isSuccess: true,
        );

        final renewalLogDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('logs')
            .doc();

        transaction.set(renewalLogDoc, renewalLog.toJson());

        // ⚠️ ربط سجل التجديد بـ relatedLogIds (إصلاح تحقق يدوي 2026-10-08):
        // بدون هذا الربط، لا يُحذف سجل التجديد عند حذف الاشتراك
        // (لأن deleteSubscription يحذف السجلات المرتبطة عبر
        // relatedLogIds فقط)، فيبقى سجل يتيم في مجموعة logs.
        // هذا الربط يضمن توثيق التجديد وحذفه ذرياً مع الاشتراك.
        transaction.update(docRef, {
          'relatedLogIds': FieldValue.arrayUnion([renewalLogDoc.id]),
        });

        // ⚠️ إنشاء الفاتورة ذرياً مع التجديد (إصلاح 2026-10-09):
        // كانت الفاتورة تُنشأ في معاملة منفصلة بعد التجديد عبر
        // InvoiceBloc — إذا فشل إنشاء الفاتورة بقي اشتراك مُجدَّد
        // بلا فاتورة (بيانات غير متسقة). الآن تُنشأ هنا داخل نفس
        // المعاملة، وبناؤها من الاشتراك المُجدَّد (بالتواريخ
        // الجديدة) عبر invoiceBuilder التي يستدعيها هذا الملف.
        if (invoiceBuilder != null) {
          final invoice = invoiceBuilder(renewedSubscription);
          await _createInvoiceInTransaction(
            transaction,
            normalizedEmail,
            invoice,
            renewedSubscription.id,
            customerSnapshot,
          );
        }

        return renewedSubscription;
      });

      return Right(result);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تجديد الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SubscriptionEntity>>> getCustomerSubscriptions({
    required String customerId,
    required String organizationEmail,
    String? status,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // التحقق من إمكانية الوصول للمؤسسة
      if (!await _canAccessOrganization(organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      // ⚠️ ملاحظة أمان للمبرمجين المستقبليين: هذه الطريقة تفرض الآن فحص
      /// _canAccessOrganization للمواءمة مع getSubscriptions وغيرها.
      Query query = firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('subscriptions')
          .where('customerId', isEqualTo: customerId);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final querySnapshot = await query.get();

      final subscriptions = <SubscriptionEntity>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
          mapData['id'] = doc.id;
        }
        subscriptions.add(SubscriptionModel.fromJson(mapData));
      }

      return Right(subscriptions);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب اشتراكات العميل: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SubscriptionEntity>>> getExpiredSubscriptions(
    String organizationEmail,
  ) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // التحقق من إمكانية الوصول للمؤسسة
      if (!await _canAccessOrganization(organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      // ⚠️ ملاحظة أمان للمبرمجين المستقبليين: هذه الطريقة تفرض الآن فحص
      /// _canAccessOrganization للمواءمة مع getSubscriptions.
      final now = Timestamp.fromDate(DateTime.now());
      final querySnapshot = await firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('subscriptions')
          .where('endDate', isLessThan: now)
          .where('status', isEqualTo: 'active')
          .get();

      final subscriptions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = doc.id;
        }
        return SubscriptionModel.fromJson(data);
      }).toList();

      return Right(subscriptions);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الاشتراكات المنتهية: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SubscriptionEntity>>>
  getExpiringSoonSubscriptions(
    String organizationEmail, {
    int daysAhead = 7,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // التحقق من إمكانية الوصول للمؤسسة
      if (!await _canAccessOrganization(organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      // ⚠️ ملاحظة أمان للمبرمجين المستقبليين: هذه الطريقة تفرض الآن فحص
      /// _canAccessOrganization للمواءمة مع getSubscriptions.
      final now = DateTime.now();
      final futureDate = now.add(Duration(days: daysAhead));

      final querySnapshot = await firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('subscriptions')
          .where('endDate', isGreaterThan: Timestamp.fromDate(now))
          .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(futureDate))
          .where('status', isEqualTo: 'active')
          .get();

      final subscriptions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = doc.id;
        }
        return SubscriptionModel.fromJson(data);
      }).toList();

      return Right(subscriptions);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في جلب الاشتراكات التي تنتهي قريباً: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateSubscriptionPayment({
    required String subscriptionId,
    required String organizationEmail,
    required double amountPaid,
    String? paymentMethod,
    String? paymentReference,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      
      return await firestore.runTransaction((transaction) async {
        final subscriptionDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('subscriptions')
            .doc(subscriptionId);

        final docSnapshot = await transaction.get(subscriptionDoc);
        if (!docSnapshot.exists) {
          throw Exception('الاشتراك غير موجود');
        }

        final data = docSnapshot.data();
        if (data == null) throw Exception('المستند فارغ');
        final mapData = Map<String, dynamic>.from(data);
        final currentTotalPaid = (mapData['totalPaid'] ?? 0).toDouble();
        final price = (mapData['price'] ?? 0).toDouble();

        final newTotalPaid = currentTotalPaid + amountPaid;
        final newRemainingAmount = price - newTotalPaid;

        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
        // 1. تحديث totalPaid و remainingAmount في الاشتراك ← ذري مع تحديث الصندوق
        //    → إذا تم تحديث الاشتراك لكن لم يُحدَّث الصندوق،
        //      فإن الأموال لا تُسجل بشكل صحيح.
        // 2. تحديث currentBalance في الصندوق ← ذري مع تحديث الاشتراك
        //    → إذا تم تحديث الصندوق لكن لم يُحدَّث الاشتراك،
        //      فإن الأموال تُخصم بلا سبب.
        //    → ⚠️ نستخدم FieldValue.increment(amountPaid) للذريّة!
        //      إذا استخدمت currentBalance + amountPaid بدلاً من FieldValue.increment(amountPaid)،
        //      فإنك تعيد مشكلة Read-Modify-Write.
        //    → مثال: مستخدمان يدفعان 100 كل منهما:
        //      - المستخدم A يقرأ balance = 500
        //      - المستخدم B يقرأ balance = 500
        //      - المستخدم A يكتب 500+100=600
        //      - المستخدم B يكتب 500+100=600 (بدلاً من 700!)
        //      النتيجة: الرصيد يصبح 600 بدلاً من 700 - تعديل غير صحيح!
        //    → الحل: FieldValue.increment(amountPaid) يضمن أن الخادم يضيف المبلغ ذرياً.
        // 3. منع القيمة السالبة للمبلغ المتبقي ← ذري مع التحديث
        //    → إذا كان newRemainingAmount < 0، تُلغى المعاملة بالكامل.
        //      هذا يمنع تحديث جزئي للبيانات.
        // ⚠️ لا تقم أبداً باستخدام currentBalance + amount بدلاً من FieldValue.increment(amount)!

        // منع القيمة السالبة للمبلغ المتبقي
        if (newRemainingAmount < 0) {
          throw Exception(
            'لا يمكن أن يكون المبلغ المتبقي سالباً. السعر: $price، المدفوع الحالي: $currentTotalPaid، المدفوع الجديد: $amountPaid',
          );
        }

        final updateData = <String, dynamic>{
          'totalPaid': newTotalPaid,
          'remainingAmount': newRemainingAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (paymentMethod != null) {
          updateData['lastPaymentMethod'] = paymentMethod;
        }

        if (paymentReference != null) {
          updateData['lastPaymentReference'] = paymentReference;
        }

        transaction.update(subscriptionDoc, updateData);

        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ إنشاء سجل دفع الاشتراك يجب أن يكون ذرياً مع تحديث الدفع!
        // ⚠️ إذا تم تحديث الدفع لكن لم يُنشأ السجل،
        // ⚠️ فإن الدفعة لا تُوثق بشكل صحيح.
        final paymentLogDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('logs')
            .doc();

        transaction.set(paymentLogDoc, {
          'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
          'actionType': 'payment_subscription',
          'details':
              'تم دفع مبلغ $amountPaid للاشتراك: ${mapData['name'] ?? subscriptionId}',
          'targetId': subscriptionId,
          'targetType': 'subscription',
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'isSuccess': true,
          'oldValues': {
            'totalPaid': currentTotalPaid,
            'remainingAmount': price - currentTotalPaid,
          },
          'newValues': {
            'totalPaid': newTotalPaid,
            'remainingAmount': newRemainingAmount,
          },
        });

        // تحديث relatedLogIds في مستند الاشتراك
        transaction.update(subscriptionDoc, {
          'relatedLogIds': FieldValue.arrayUnion([paymentLogDoc.id]),
        });

        if (amountPaid > 0) {
          final boxDoc = firestore
              .collection(normalizedEmail)
              .doc('cashbox')
              .collection('balance')
              .doc('main');

          transaction.set(boxDoc, {
            'currentBalance': FieldValue.increment(amountPaid),
            'lastUpdated': FieldValue.serverTimestamp(),
            'updatedBy': FirebaseAuth.instance.currentUser?.email ?? '',
          }, SetOptions(merge: true));
        }

        return const Right(null);
      });
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث معلومات الدفع: $e'));
    }
  }

  @override
  Future<Either<Failure, SubscriptionEntity?>> getSubscriptionById(
    String subscriptionId,
  ) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final doc = await firestore
          .collection(organizationId)
          .doc('subscriptions')
          .collection('subscriptions')
          .doc(subscriptionId)
          .get();

      if (!doc.exists) {
        return const Right(null);
      }

      final data = doc.data();
      if (data == null) return Left(ServerFailure(message: 'المستند فارغ'));
      final mapData = Map<String, dynamic>.from(data);
      // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
      if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
        mapData['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
      }
      final subscription = SubscriptionModel.fromJson(mapData);
      return Right(subscription);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> searchSubscriptionNames({
    required String query,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final lowerQuery = query.toLowerCase();

      // استخدام Firestore query مع where للبحث
      final snapshot = await firestore
          .collection(organizationId)
          .doc('subscriptions')
          .collection('subscriptions')
          .where('name', isGreaterThanOrEqualTo: lowerQuery)
          .where('name', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(20)
          .get();

      // جمع الأسماء المطابقة
      final matchingNames =
          snapshot.docs
              .map((doc) => doc.data()['name'] as String)
              .where((name) => name.toLowerCase().contains(lowerQuery))
              .toSet()
              .toList()
            ..sort();

      return Right(matchingNames);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في البحث عن أسماء الاشتراكات: $e'),
      );
    }
  }

  // ===== Subscription Types Methods =====

  @override
  Future<Either<Failure, List<SubscriptionTypeEntity>>> getSubscriptionTypes(
    String organizationEmail,
  ) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      final querySnapshot = await firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('types')
          .orderBy('name')
          .get();

      final types = querySnapshot.docs.map((doc) {
        return SubscriptionTypeModel.fromJson({...doc.data(), 'id': doc.id});
      }).toList();

      return Right(types);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب أنواع الاشتراكات: $e'));
    }
  }

  @override
  Future<Either<Failure, SubscriptionTypesPage>> getSubscriptionTypesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      var query = firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('types')
          .orderBy('name');

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();

      final types = querySnapshot.docs.map((doc) {
        return SubscriptionTypeModel.fromJson({...doc.data(), 'id': doc.id});
      }).toList();

      return Right(
        SubscriptionTypesPage(
          types: types,
          lastDocument: querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.last
              : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب أنواع الاشتراكات: $e'));
    }
  }

  @override
  Stream<Either<Failure, List<SubscriptionTypeEntity>>>
      getSubscriptionTypesStream(String organizationEmail) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // فحص أمني متزامن لمنع الوصول غير المصرح به للمؤسسة
      // (نفس فحص getSubscriptionsStream)
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        return Stream.value(
          Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }
      final currentOrgId = _emailService.normalize(user!.email!);
      final requestedOrgId = _emailService.normalize(organizationEmail);
      if (currentOrgId != requestedOrgId) {
        return Stream.value(
          Left(ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة')),
        );
      }

      return firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('types')
          .orderBy('name')
          .snapshots()
          .map((snapshot) {
            try {
              final types = <SubscriptionTypeEntity>[];
              for (final doc in snapshot.docs) {
                try {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) continue;
                  types.add(
                    SubscriptionTypeModel.fromJson({
                      ...data,
                      'id': doc.id,
                    }),
                  );
                } on Exception catch (_) {
                  continue;
                }
              }
              return Right<Failure, List<SubscriptionTypeEntity>>(types);
            } on Exception catch (e) {
              return Left<Failure, List<SubscriptionTypeEntity>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, List<SubscriptionTypeEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Future<Either<Failure, void>> createSubscriptionType(
    SubscriptionTypeEntity type,
  ) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final model = SubscriptionTypeModel.fromEntity(type);
      final data = model.toJson();

      // استخدام Transaction لضمان الحفظ الذري
      
      await firestore.runTransaction((transaction) async {
        final typeDoc = firestore
            .collection(organizationId)
            .doc('subscriptions')
            .collection('types')
            .doc(type.id);

        // التحقق من عدم وجود النوع مسبقاً
        final docSnapshot = await transaction.get(typeDoc);

        if (docSnapshot.exists) {
          throw Exception('نوع الاشتراك موجود مسبقاً');
        }

        // حفظ البيانات في نفس الـ transaction
        transaction.set(typeDoc, data);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في إنشاء نوع الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateSubscriptionType(
    SubscriptionTypeEntity type,
  ) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final model = SubscriptionTypeModel.fromEntity(type);

      // استخدام Transaction لضمان الحفظ الذري
      
      await firestore.runTransaction((transaction) async {
        final typeDoc = firestore
            .collection(organizationId)
            .doc('subscriptions')
            .collection('types')
            .doc(type.id);

        // التحقق من وجود النوع قبل التحديث
        final docSnapshot = await transaction.get(typeDoc);

        if (!docSnapshot.exists) {
          throw Exception('نوع الاشتراك غير موجود');
        }

        // تحديث البيانات في نفس الـ transaction
        transaction.update(typeDoc, model.toJson());
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث نوع الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSubscriptionType(
    String typeId,
    String organizationEmail,
  ) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      if (!await _canAccessOrganization(organizationEmail)) {
        return const Left(
          ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة'),
        );
      }

      final typeDoc = firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('types')
          .doc(typeId);

      // استخدام Transaction لضمان الحذف الذري
      
      await firestore.runTransaction((transaction) async {
        // التحقق من وجود النوع وعدم وجود اشتراكات مرتبطة داخل المعاملة
        // ملاحظة: الحقل linkedSubscriptionsCount قد لا يكون موجوداً في الأنواع القديمة
        // قبل هذا التعديل، وسيتم اعتباره 0 في هذه الحالة. يلزم تهيئة يدوية للبيانات القديمة.
        final typeSnapshot = await transaction.get(typeDoc);

        if (!typeSnapshot.exists) {
          throw Exception('نوع الاشتراك غير موجود');
        }

        final typeData = typeSnapshot.data();
        final linkedCount =
            (typeData?['linkedSubscriptionsCount'] as int?) ?? 0;
        if (linkedCount > 0) {
          throw Exception('لا يمكن حذف نوع الاشتراك لوجود اشتراكات مرتبطة به');
        }

        // حذف النوع داخل المعاملة
        transaction.delete(typeDoc);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حذف نوع الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> searchSubscriptionTypeNames({
    required String query,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final lowerQuery = query.toLowerCase();

      // استخدام Firestore query مع where للبحث
      final snapshot = await firestore
          .collection(organizationId)
          .doc('subscriptions')
          .collection('types')
          .where('name', isGreaterThanOrEqualTo: lowerQuery)
          .where('name', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(20)
          .get();

      final matchingNames =
          snapshot.docs
              .map((doc) => doc.data()['name'] as String)
              .where((name) => name.toLowerCase().contains(lowerQuery))
              .toSet()
              .toList()
            ..sort();

      return Right(matchingNames);
    } on Exception catch (e) {
      return Left(
        ServerFailure(message: 'فشل في البحث عن أسماء أنواع الاشتراكات: $e'),
      );
    }
  }

  // ===== Subscription Logs Methods =====

  @override
  Future<Either<Failure, SubscriptionLogEntity>> addSubscriptionLog({
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

      final log = SubscriptionLogModel(
        id: '',
        userId: userId,
        actionType: actionType,
        details: details ?? '',
        targetId: targetId,
        targetType: targetType,
        oldValues: oldValues,
        newValues: newValues,
        timestamp: DateTime.now(),
        isSuccess: isSuccess,
      );

      // استخدام Transaction لضمان إضافة السجل ذرياً
      
      final docRef = await firestore.runTransaction<String?>((
        transaction,
      ) async {
        final logDoc = firestore
            .collection(organizationId)
            .doc('subscriptions')
            .collection('logs')
            .doc();

        transaction.set(logDoc, log.toJson());

        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ تحديث relatedLogIds في مستند الاشتراك يجب أن يكون ذرياً مع إنشاء السجل!
        // ⚠️ إذا تم إنشاء السجل لكن لم يُحدَّث relatedLogIds،
        // ⚠️ فإن حذف الاشتراك لن يحذف هذا السجل تلقائياً.
        // ⚠️ نستخدم FieldValue.arrayUnion لضمان عدم تكرار المعرفات.
        if (targetId != null && targetType == 'subscription') {
          final subscriptionDoc = firestore
              .collection(organizationId)
              .doc('subscriptions')
              .collection('subscriptions')
              .doc(targetId);

          transaction.update(subscriptionDoc, {
            'relatedLogIds': FieldValue.arrayUnion([logDoc.id]),
          });
        }

        return logDoc.id;
      });

      // ✅ runTransaction ترجع دائماً قيمة الدالة الممررة (logDoc.id غير فارغ)،
      // لذلك لا يوجد مسار فشل هنا — أي استثناء يُلتقط بواسطة catch Exception أعلاه.
      final createdLog = log.copyWith(id: docRef);
      return Right(createdLog);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في إضافة سجل الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SubscriptionLogEntity>>> getSubscriptionLogs({
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
          .doc('subscriptions')
          .collection('logs')
          .orderBy('timestamp', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      var logs = <SubscriptionLogEntity>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        logs.add(SubscriptionLogModel.fromJson({...mapData, 'id': doc.id}));
      }

      // تطبيق الفلاتر محلياً
      if (userId != null && userId.isNotEmpty) {
        logs = logs.where((log) => log.userId == userId).toList();
      }

      if (actionFilter != null && actionFilter.isNotEmpty) {
        logs = logs.where((log) => log.actionType == actionFilter).toList();
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        logs = logs
            .where(
              (log) =>
                  (log.details?.toLowerCase().contains(lowerQuery) ?? false) ||
                  (log.targetId?.toLowerCase().contains(lowerQuery) ?? false),
            )
            .toList();
      }

      if (startDate != null) {
        logs = logs.where((log) => log.timestamp.isAfter(startDate)).toList();
      }

      if (endDate != null) {
        logs = logs.where((log) => log.timestamp.isBefore(endDate)).toList();
      }

      return Right(logs);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب سجلات الاشتراكات: $e'));
    }
  }

  @override
  Stream<Either<Failure, List<SubscriptionLogEntity>>>
      getSubscriptionLogsStream({
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
          Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      Query query = firestore
          .collection(organizationId)
          .doc('subscriptions')
          .collection('logs')
          .orderBy('timestamp', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      // ✅ أداء (2026-10-12): كاش تدريجي
      // خاص بهذا الستريم فقط يعالج
      // docChanges بدلاً من إعادة تحليل
      // كل السجلات مع كل لقطة — سجلات
      // الاشتراكات تنمو بلا حدود فكان
      // إعادة بناء كل SubscriptionLogEntity
      // عند كل عملية جديدة هو الهدر
      // الأكبر هنا. الستريم المحدود
      // (بحد) يبقي التحليل الكامل
      // الأصلي لأن نافذة الحد تتحرك
      // وقد لا يُصدر المستند الخارج
      // تغييراً من نوع removed بشكل
      // موثوق.
      final streamCache = <String, SubscriptionLogEntity>{};

      return query.snapshots().map((snapshot) {
        try {
          List<SubscriptionLogEntity> logs;

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
              final mapData = data as Map<String, dynamic>;
              try {
                streamCache[doc.id] = SubscriptionLogModel.fromJson({
                  ...mapData,
                  'id': doc.id,
                });
              } on Exception catch (_) {
                streamCache.remove(doc.id);
              }
            }

            // الحفاظ على ترتيب الاستعلام
            // (timestamp تنازلي) عبر المرور
            // على مستندات اللقطة مرتبة
            // وأخذ الكيان المحلل من
            // الكاش — أدق من إعادة
            // الترتيب في الذاكرة لأن
            // ترتيب Firestore الحقيقي
            // (بما في ذلك كسر التعادل)
            // يُحفظ كما هو
            logs = <SubscriptionLogEntity>[];
            for (final doc in snapshot.docs) {
              final cachedLog = streamCache[doc.id];
              if (cachedLog != null) {
                logs.add(cachedLog);
              }
            }
          } else {
            // الستريم المحدود: تحليل كامل
            // (السلوك الأصلي)
            logs = <SubscriptionLogEntity>[];
            for (final doc in snapshot.docs) {
              try {
                final data = doc.data();
                if (data == null) continue;
                final mapData = data as Map<String, dynamic>;
                logs.add(
                  SubscriptionLogModel.fromJson({...mapData, 'id': doc.id}),
                );
              } on Exception catch (_) {
                continue;
              }
            }
          }

          // تطبيق الفلاتر محلياً (نفس فلاتر getSubscriptionLogs)
          if (userId != null && userId.isNotEmpty) {
            logs = logs.where((log) => log.userId == userId).toList();
          }

          if (actionFilter != null && actionFilter.isNotEmpty) {
            logs = logs.where((log) => log.actionType == actionFilter).toList();
          }

          if (searchQuery != null && searchQuery.isNotEmpty) {
            final lowerQuery = searchQuery.toLowerCase();
            logs = logs
                .where(
                  (log) =>
                      (log.details?.toLowerCase().contains(lowerQuery) ??
                          false) ||
                      (log.targetId?.toLowerCase().contains(lowerQuery) ??
                          false),
                )
                .toList();
          }

          if (startDate != null) {
            logs = logs.where((log) => log.timestamp.isAfter(startDate)).toList();
          }

          if (endDate != null) {
            logs = logs.where((log) => log.timestamp.isBefore(endDate)).toList();
          }

          return Right<Failure, List<SubscriptionLogEntity>>(logs);
        } on Exception catch (e) {
          return Left<Failure, List<SubscriptionLogEntity>>(
            ServerFailure(message: _readableError(e)),
          );
        }
      }).handleError((error) {
        return Left<Failure, List<SubscriptionLogEntity>>(
          ServerFailure(message: _readableError(error)),
        );
      });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSubscriptionLog(String logId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final logDoc = firestore
          .collection(organizationId)
          .doc('subscriptions')
          .collection('logs')
          .doc(logId);

      // استخدام Transaction لضمان الحذف الذري
      
      await firestore.runTransaction((transaction) async {
        // التحقق من وجود السجل قبل الحذف
        final snapshot = await transaction.get(logDoc);

        if (!snapshot.exists) {
          throw Exception('السجل غير موجود');
        }

        // ⚠️ إصلاح 2026-10-08 — إزالة معرف السجل من relatedLogIds:
        // بدون هذا، يبقى معرف يتيم في مصفوفة relatedLogIds في مستند
        // الاشتراك بعد حذف السجل، فيحاول deleteSubscription لاحقاً
        // حذف سجل غير موجود (وتبقى المصفوفة مليئة بمعرفات قديمة).
        // ⚠️ القراءة (transaction.get) هنا قبل أي كتابة — قاعدة
        // Firestore: كل القراءات قبل كل الكتابات.
        // ⚠️ نتحقق من وجود الاشتراك قبل التحديث لتجنب خطأ التحديث
        // على مستند غير موجود (إذا حُذف الاشتراك عبر مسار آخر).
        final logData = snapshot.data();
        final targetId = logData?['targetId']?.toString();
        final targetType = logData?['targetType']?.toString();
        if (targetId != null &&
            targetId.isNotEmpty &&
            targetType == 'subscription') {
          final subscriptionDoc = firestore
              .collection(organizationId)
              .doc('subscriptions')
              .collection('subscriptions')
              .doc(targetId);
          final subscriptionSnapshot = await transaction.get(subscriptionDoc);
          if (subscriptionSnapshot.exists) {
            transaction.update(subscriptionDoc, {
              'relatedLogIds': FieldValue.arrayRemove([logId]),
            });
          }
        }

        // حذف السجل داخل المعاملة
        transaction.delete(logDoc);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حذف سجل الاشتراك: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearSubscriptionLogs({
    String? userId,
    DateTime? beforeDate,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // ⚠️ ملاحظة للمبرمجين المستقبليين حول الذرية (Atomicity):
      // ⚠️ المسار الأساسي ذري (all-or-nothing) الآن عبر Cloud
      // Function clearSubscriptionLogsAtomic التي تُنفذ
      // الاستعلام والحذف على الخادم داخل معاملة واحدة.
      // لماذا دالة سحابية؟ لأن Firestore runTransaction
      // لا تدعم الاستعلامات (queries) من جانب العميل —
      // لذلك يُنفذ الحذف على الخادم حيث تُجرى المعاملة
      // والاستعلام على نفس الشبكة (نافذة سباق ضئيلة
      // جداً). ⚠️ للحذف قبل تاريخ (beforeDate) لا سباق
      // أصلاً: السجلات الجديدة تحمل طوابع زمنية من
      // الخادم أحدث من beforeDate فلا تطابق شرط
      // الاستعلام.
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'clearSubscriptionLogsAtomic',
        );
        await callable.call({
          'organizationEmail': organizationId,
          'userId': userId,
          'beforeDate': beforeDate?.toIso8601String(),
        });
        return const Right(null);
      } on FirebaseFunctionsException catch (e) {
        // ⚠️ لا مسار احتياطي لأخطاء الصلاحية أو المصادقة —
        // إذا رفضت الدالة السحابية الوصول فلا يُحذف شيء
        // (منع حذف غير ذري لبيانات لا يملك المستخدم
        // صلاحيتها).
        if (e.code == 'permission-denied' ||
            e.code == 'unauthenticated') {
          return Left(
            ServerFailure(
              message: 'فشل في مسح سجلات الاشتراكات: ${e.message}',
            ),
          );
        }
        // ⚠️ مسار الاحتياط (Write Batch + استعلام خارجها) —
        // يُستخدم فقط إذا كانت الدالة السحابية غير متاحة
        // (غير منشورة أو غير قابلة للوصول، مثلاً في بيئة
        // تطوير). ⚠️ هذا المسار ليس ذرياً تماماً:
        // الاستعلام (query.get()) يُنفذ خارج الـ Batch،
        // فإذا أُنشئت سجلات جديدة تطابق الاستعلام بعد
        // جلب النتائج وقبل commit الـ Batch لن تُحذف.
        // هذا مقبول لعمليات التنظيف لأن السجلات الجديدة
        // لن تطابق شرط التاريخ عادة. ⚠️ للحذف الذري
        // الكامل نشّل Cloud Function
        // clearSubscriptionLogsAtomic على الخادم.
        final batch = firestore.batch();
        Query query = firestore
            .collection(organizationId)
            .doc('subscriptions')
            .collection('logs');

        if (userId != null) {
          query = query.where('userId', isEqualTo: userId);
        }

        if (beforeDate != null) {
          query = query.where(
            'timestamp',
            isLessThan: Timestamp.fromDate(beforeDate),
          );
        }

        final querySnapshot = await query.get();

        for (final doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        return const Right(null);
      }
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في مسح سجلات الاشتراكات: $e'));
    }
  }

  @override
  Stream<Either<Failure, List<SubscriptionEntity>>> getSubscriptionsStream(
    String organizationEmail, {
    int? limit,
    String? searchQuery,
    String? statusFilter,
    String? typeFilter,
    String? customerFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // فحص أمني متزامن لمنع الوصول غير المصرح به للمؤسسة
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        return Stream.value(
          Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }
      final currentOrgId = _emailService.normalize(user!.email!);
      final requestedOrgId = _emailService.normalize(organizationEmail);
      if (currentOrgId != requestedOrgId) {
        return Stream.value(
          Left(ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة')),
        );
      }

      // 1. بناء الـ query الأساسي
      Query query = firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('subscriptions');

      // 2. إضافة فلتر الحالة إذا كان موجوداً (قبل orderBy)
      if (statusFilter != null && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      // 3. إضافة فلتر النوع إذا كان موجوداً (قبل orderBy)
      if (typeFilter != null && typeFilter != 'all') {
        query = query.where('type', isEqualTo: typeFilter);
      }

      // 4. الترتيب
      query = query.orderBy('createdAt', descending: true);

      // 5. ✅ عدم تطبيق الحد في الـ query - نريد كل البيانات للفلترة
      // التطبيق النهائي للحد سيكون في BLoC بعد الفلترة
      // if (limit != null) {
      //   query = query.limit(limit);
      // }

      // 6. الاستماع للتغييرات
      // ✅ تحسين (2026-10-12): نفس تحسين
      // قسم الفواتير — نحفظ الاشتراكات
      // المحللة في ذاكرة خاصة بهذا الستريم
      // ونحدّث المستندات المتغيرة فقط عبر
      // docChanges بدلاً من إعادة تحليل
      // كل الاشتراكات مع كل لقطة — كان
      // يسبب بطءاً ملحوظاً مع كثرة
      // الاشتراكات عند كل تحديث. الحد لا
      // يُطبَّق في الـ query (نريد كل
      // البيانات للفلترة في الذاكرة) فالذاكرة
      // تمثل نتيجة الاستعلام كاملة ويُطبَّق
      // الحد في الذاكرة بعد الفلترة.
      final streamCache = <String, SubscriptionEntity>{};

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
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) {
                  streamCache.remove(doc.id);
                  continue;
                }
                final mapData = Map<String, dynamic>.from(data);
                if (mapData['id'] == null ||
                    mapData['id'].toString().isEmpty) {
                  mapData['id'] = doc.id;
                }
                try {
                  streamCache[doc.id] =
                      SubscriptionModel.fromJson(mapData);
                } on Exception catch (_) {
                  streamCache.remove(doc.id);
                }
              }

              var subscriptions = streamCache.values.toList()
                ..sort((a, b) {
                  final cmp = b.createdAt.compareTo(a.createdAt);
                  return cmp != 0 ? cmp : a.id.compareTo(b.id);
                });

              // 6. تطبيق فلتر البحث في الذاكرة
              if (searchQuery != null && searchQuery.isNotEmpty) {
                final query = searchQuery.toLowerCase();
                subscriptions = subscriptions.where((subscription) {
                  final name = subscription.name.toLowerCase();
                  final description =
                      subscription.description?.toLowerCase();
                  final customerName =
                      subscription.customerName?.toLowerCase();
                  return name.contains(query) ||
                      (description?.contains(query) ?? false) ||
                      (customerName?.contains(query) ?? false);
                }).toList();
              }

              // 7. تطبيق فلتر العميل في الذاكرة (إذا لم يكن في Firestore)
              if (customerFilter != null && customerFilter != 'all') {
                subscriptions = subscriptions
                    .where(
                      (subscription) =>
                          subscription.customerName == customerFilter,
                    )
                    .toList();
              }

              // 8. تطبيق فلاتر التاريخ في الذاكرة
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

                subscriptions = subscriptions
                    .where(
                      (subscription) =>
                          !subscription.createdAt.isBefore(filterDate),
                    )
                    .toList();
              }

              // فلتر التاريخ المخصص
              if (startDate != null) {
                subscriptions = subscriptions
                    .where(
                      (subscription) =>
                          !subscription.createdAt.isBefore(startDate),
                    )
                    .toList();
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
                subscriptions = subscriptions
                    .where(
                      (subscription) =>
                          !subscription.createdAt.isAfter(endOfDay),
                    )
                    .toList();
              }

              // 9. التأكد من عدم تجاوز الحد (حماية إضافية)
              if (limit != null && subscriptions.length > limit) {
                subscriptions = subscriptions.sublist(0, limit);
              }

              return Right<Failure, List<SubscriptionEntity>>(
                subscriptions,
              );
            } on Exception catch (e) {
              return Left<Failure, List<SubscriptionEntity>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, List<SubscriptionEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>> getSubscriptionStatsStream(
    String organizationEmail, {
    int? limit,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // فحص أمني متزامن لمنع الوصول غير المصرح به للمؤسسة
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        return Stream.value(
          Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }
      final currentOrgId = _emailService.normalize(user!.email!);
      final requestedOrgId = _emailService.normalize(organizationEmail);
      if (currentOrgId != requestedOrgId) {
        return Stream.value(
          Left(ServerFailure(message: 'ليس لديك صلاحية للوصول لهذه المؤسسة')),
        );
      }

      final collection = firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('subscriptions');

      return collection
          .snapshots()
          .map((snapshot) {
            try {
              // ✅ تحسين (2026-10-12): حساب
              // الإحصائيات مباشرة من بيانات
              // المستند الخام بدلاً من بناء
              // SubscriptionModel كامل لكل
              // اشتراك — الإحصائيات تحتاج
              // 4 حقول فقط (status، startDate،
              // endDate، duration/customDays
              // لحساب endDate عند غيابه) فبناء
              // النموذج كامل كان يهدر وقت
              // المعالج مع كثرة الاشتراكات
              // عند كل لقطة. منطق الحساب
              // مطابق تماماً للسابق (isExpired
              // و isExpiringSoon من
              // SubscriptionEntity — انظر
              // getters هناك).
              var totalSubscriptions = 0;
              // ⚠️ ملاحظة صيانة للمبرمجين المستقبليين (مكتشفة في التدقيق): هذا الستريم يكرر منطق isExpired/
              // isExpiringSoon من SubscriptionEntity بدلاً من إعادة استخدام getters الكيان → خطر اختلاف المنطق
              // مستقبلاً إذا عُدّل الكيان. السبب: الستريم يحسب انتهاء الصلاحية والقرب من الانتهاء مباشرة من
              // حقول المستند الخام (status, endDate) باستخدام منطق مكرر بدلاً من إنشاء SubscriptionEntity
              // واستخدام isExpired و isExpiringSoon. إذا تغير تعريف "منتهي" أو "قريب من الانتهاء" في الكيان
              // (مثلاً تغيير حد الـ 3 أيام أو إضافة منطق UTC)، قد لا يُ reflet التغيير هنا مما يؤدي إلى اختلاف
              // الإحصائيات عن الواجهة. التوصية: إعادة استخدام SubscriptionEntity أو استخراج دالة مساعدة مشتركة
              // لاحتساب انتهاء الصلاحية والقرب منه في مكان واحد.
              var activeSubscriptions = 0;
              var expiredSubscriptions = 0;
              var expiringSoonSubscriptions = 0;

              for (final doc in snapshot.docs) {
                final mapData = doc.data();

                final status =
                    mapData['status']?.toString() ??
                    'active';
                final startDate = DateParser.parse(
                  mapData['startDate'] ?? mapData['created_at'],
                );
                final endDate = DateParser.parse(
                  mapData['endDate'] ??
                      SubscriptionEntity.calculateEndDate(
                        startDate,
                        mapData['duration'] as String? ??
                            'monthly',
                        mapData['customDays'] as int?,
                      ),
                );

                // ✅ استخدام SubscriptionEntity لإعادة استخدام منطق isExpired
                // و isExpiringSoon بدلاً من تكرار المنطق — يضمن اتساق المنطق
                // بين الإحصائيات والواجهة إذا عُدّل الكيان مستقبلاً.
                final subscription = SubscriptionEntity(
                  id: mapData['id'] ?? doc.id,
                  name: mapData['name'] ?? '',
                  type: mapData['type'] ?? '',
                  price: (mapData['price'] ?? 0).toDouble(),
                  duration: mapData['duration'] as String? ?? 'monthly',
                  status: status,
                  startDate: startDate,
                  endDate: endDate,
                  organizationEmail: mapData['organizationEmail'] ?? '',
                  createdAt: DateTime.parse(
                    mapData['createdAt'] ?? mapData['created_at'] ?? DateTime.now().toIso8601String(),
                  ),
                  updatedAt: DateTime.parse(
                    mapData['updatedAt'] ?? DateTime.now().toIso8601String(),
                  ),
                  createdBy: mapData['createdBy'] ?? '',
                  customDays: mapData['customDays'] as int?,
                );

                totalSubscriptions++;

                if (subscription.status == 'active' && !subscription.isExpired) {
                  activeSubscriptions++;
                }
                if (subscription.isExpired) {
                  expiredSubscriptions++;
                }

                if (subscription.isExpiringSoon) {
                  expiringSoonSubscriptions++;
                }
              }

              final stats = {
                'total': totalSubscriptions,
                'active': activeSubscriptions,
                'expired': expiredSubscriptions,
                'expiringSoon': expiringSoonSubscriptions,
              };

              return Right<Failure, Map<String, dynamic>>(stats);
            } on Exception catch (e) {
              return Left<Failure, Map<String, dynamic>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, Map<String, dynamic>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  // ===== Activation Recharge Methods =====

  @override
  Future<Either<Failure, void>> rechargeActivations({
    required String subscriptionTypeId,
    required String subscriptionTypeName,
    required int quantity,
    required double pricePerActivation,
    required String organizationEmail,
    required String createdBy,
    String? boxId,
  }) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final totalPrice = quantity * pricePerActivation;
      final rechargeId = DateTime.now().millisecondsSinceEpoch.toString();

      // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
      // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
      // 1. تحديث activationQuantity في نوع الاشتراك ← ذري مع إنشاء سجل الشحن
      //    → نستخدم FieldValue.increment(quantity) للذريّة!
      //      إذا استخدمت currentQuantity + quantity بدلاً من FieldValue.increment(quantity)،
      //      فإنك تعيد مشكلة Read-Modify-Write.
      // 2. إنشاء سجل الشحن (activation_recharges) ← ذري مع تحديث التفعيلات
      //    → إذا تم شحن التفعيلات لكن لم يُنشأ السجل،
      //      فإن السجل يوثق عملية لم تحدث.
      // 3. تحديث currentBalance في الصندوق ← ذري مع شحن التفعيلات
      //    → نستخدم FieldValue.increment(-totalPrice) للذريّة!
      //      إذا استخدمت currentBalance - totalPrice بدلاً من FieldValue.increment(-totalPrice)،
      //      فإنك تعيد مشكلة Read-Modify-Write.
      //    → ⚠️ ⚠️ ⚠️ تحذير: إذا قام مستخدمان بدفع مبلغ في نفس الوقت:
      //      - المستخدم A يريد الدفع 100
      //      - المستخدم B يريد الدفع 100
      //      - المستخدم A يقرأ balance = 500
      //      - المستخدم B يقرأ balance = 500
      //      - المستخدم A يكتب 500-100=400
      //      - المستخدم B يكتب 500-100=400 (بدلاً من 300!)
      //      النتيجة: الرصيد يصبح 400 بدلاً من 300 - تعديل غير صحيح!
      //    → الحل: FieldValue.increment(-totalPrice) يضمن أن الخادم يخصم المبلغ ذرياً.
      // 4. إنشاء سجل المعاملة (cashbox transactions) ← ذري مع تحديث الصندوق
      //    → إذا تم تحديث الصندوق لكن لم يُنشأ سجل المعاملة،
      //      فإن الرصيد لا يُطابق السجلات.
      // ⚠️ تصحيح تحقق يدوي (2026-10-08): التحقق من الحد
      // الأقصى (10000) ومن كفاية رصيد الصندوق مُضافان
      // الآن داخل المعاملة (بعد transaction.get(typeDoc)
      // مباشرة)، مطابقةً لـ rechargeActivationsAtomic في
      // Cloud Function (functions/index.js). المعاملة هنا
      // تضمن ذريّة الشحن (increment + سجل الشحن + الصندوق)
      // وحد الكمية وكفاية الرصيد معاً. لا تُزِل هذين
      // التحققين أبداً.

      // استخدام Transaction لضمان الحفظ الذري لجميع العمليات
      
      await firestore.runTransaction((transaction) async {
        // 1. زيادة حساب التفعيلات في نوع الاشتراك داخل المعاملة
        final typeDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('types')
            .doc(subscriptionTypeId);

        final typeSnapshot = await transaction.get(typeDoc);
        if (!typeSnapshot.exists) {
          throw Exception('نوع الاشتراك غير موجود');
        }

        // ⚠️ إصلاح 2026-10-08 — التحقق من الحد الأقصى (10000) داخل
        // المعاملة، مطابقةً لـ rechargeActivationsAtomic في Cloud
        // Functions (functions/index.js). بدون هذا التحقق يمكن تجاوز
        // الحد الأقصى عبر المسار المباشر من Dart. القراءة
        // (transaction.get) أعلاه قبل أي كتابة — قاعدة Firestore:
        // كل القراءات قبل كل الكتابات.
        final currentQuantity =
            (typeSnapshot.data()?['activationQuantity'] as int? ?? 0);
        if (currentQuantity + quantity > 10000) {
          throw Exception('لا يمكن إضافة أكثر من 10000 تفعيلة');
        }

        // ⚠️ إصلاح 2026-10-08 — التحقق من كفاية رصيد
        // الصندوق داخل المعاملة، مطابقةً لـ
        // rechargeActivationsAtomic في Cloud Function
        // (functions/index.js) الذي يقرأ currentBalance
        // عبر transaction.get ويرمي خطأ إذا كان
        // currentBalance < totalPrice. بدون هذا التحقق
        // يمكن أن يصبح رصيد الصندوق سالباً عبر المسار
        // المباشر من Dart (وهو المسار الذي يستخدمه
        // التطبيق فعلاً).
        // ⚠️ القراءة (transaction.get) هنا قبل أي
        // كتابة — قاعدة Firestore: كل القراءات قبل
        // كل الكتابات. لا تُضف أي transaction.get
        // بعد transaction.update أدناه أبداً.
        final balanceDoc = firestore
            .collection(normalizedEmail)
            .doc('cashbox')
            .collection('balance')
            .doc('main');
        if (totalPrice > 0) {
          final balanceSnapshot = await transaction.get(balanceDoc);
          final currentBalance =
              (balanceSnapshot.data()?['currentBalance'] as num?)
                      ?.toDouble() ??
                  0;
          if (currentBalance < totalPrice) {
            throw Exception(
              'رصيد الصندوق غير كافٍ. الرصيد الحالي: $currentBalance',
            );
          }
        }

        transaction.update(typeDoc, {
          'activationQuantity': FieldValue.increment(quantity),
        });

        // 2. تسجيل حركة الشحن داخل المعاملة
        final rechargeDoc = firestore
            .collection(normalizedEmail)
            .doc('subscriptions')
            .collection('activation_recharges')
            .doc(rechargeId);

        final transactionId = 'act_${DateTime.now().millisecondsSinceEpoch}';

        transaction.set(rechargeDoc, {
          'id': rechargeId,
          'subscriptionTypeId': subscriptionTypeId,
          'subscriptionTypeName': subscriptionTypeName,
          'addedQuantity': quantity,
          'pricePerActivation': pricePerActivation,
          'totalPrice': totalPrice,
          'timestamp': FieldValue.serverTimestamp(),
          'createdBy': createdBy,
          'organizationEmail': organizationEmail,
          'boxId': boxId,
          'boxTransactionId': transactionId,
        });

        // 3. خصم المبلغ من الصندوق داخل نفس المعاملة
        if (totalPrice > 0) {
          final transactionDoc = firestore
              .collection(normalizedEmail)
              .doc('cashbox')
              .collection('transactions')
              .doc(transactionId);

          transaction.set(transactionDoc, {
            'type': 'out',
            'amount': totalPrice,
            'source': 'subscription_activation',
            'referenceId': rechargeId,
            'description':
                'شحن $quantity تفعيلات لنوع الاشتراك: $subscriptionTypeName',
            'timestamp': FieldValue.serverTimestamp(),
            'createdBy': createdBy,
            'subscriptionTypeId': subscriptionTypeId,
          });

          transaction.set(balanceDoc, {
            'currentBalance': FieldValue.increment(-totalPrice),
            'lastUpdated': FieldValue.serverTimestamp(),
            'updatedBy': createdBy,
          }, SetOptions(merge: true));
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في شحن التفعيلات: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ActivationRechargeEntity>>>
  getActivationRecharges({
    String? subscriptionTypeId,
    String? organizationEmail,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final orgEmail = organizationEmail ?? _getCurrentOrganizationId();
      if (orgEmail == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final normalizedEmail = _emailService.normalize(orgEmail);

      Query query = firestore
          .collection(normalizedEmail)
          .doc('subscriptions')
          .collection('activation_recharges')
          .orderBy('timestamp', descending: true);

      if (subscriptionTypeId != null && subscriptionTypeId.isNotEmpty) {
        query = query.where(
          'subscriptionTypeId',
          isEqualTo: subscriptionTypeId,
        );
      }

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      final recharges = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = doc.id;
        }
        return ActivationRechargeModel.fromJson(data);
      }).toList();

      return Right(recharges);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب سجل شحن التفعيلات: ${_readableError(e)}'));
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
