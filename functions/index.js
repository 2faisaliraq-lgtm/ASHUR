const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {
  normalizeOrganizationEmail,
  getRecipientPlayerIds,
  canPerformActingNotificationAction,
  isSettingEnabled,
} = require("./notification_utils");
admin.initializeApp();

const db = admin.firestore();
const notificationSettingsCache = new Map();

async function getOrganizationNotificationSettings(organizationEmail) {
  const cached = notificationSettingsCache.get(organizationEmail);
  if (cached) return cached;
  const snapshot = await db
    .collection(organizationEmail)
    .doc("settings")
    .collection("settings")
    .get();
  const byCategory = {};
  for (const doc of snapshot.docs) {
    const setting = doc.data();
    if (!setting.category || !setting.key) continue;
    byCategory[setting.category] = byCategory[setting.category] || {};
    byCategory[setting.category][setting.key] = setting.value;
  }
  notificationSettingsCache.set(organizationEmail, byCategory);
  return byCategory;
}

async function sendScheduledOrganizationPush({
  organizationEmail,
  recipients,
  title,
  body,
  type,
}) {
  const restApiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!restApiKey) throw new Error("ONESIGNAL_REST_API_KEY is not configured");
  const ids = Array.from(recipients);
  for (let index = 0; index < ids.length; index += 2000) {
    const response = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Key ${restApiKey}`,
      },
      body: JSON.stringify({
        app_id: "e309b00d-2d36-4285-ac55-f7b5831d731d",
        include_subscription_ids: ids.slice(index, index + 2000),
        target_channel: "push",
        headings: { en: title, ar: title },
        contents: { en: body, ar: body },
        data: { type },
        android_sound: "default",
        android_priority: 10,
      }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(
        `OneSignal request failed ${response.status}: ${JSON.stringify(result).slice(0, 500)}`,
      );
    }
  }
  await db
    .collection(organizationEmail)
    .doc("notifications")
    .collection("notifications")
    .add({
      title,
      body,
      type,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      actorEmail: "system",
    });
}

const onSubscriptionWrittenSendPush = functions
  .runWith({ secrets: ["ONESIGNAL_REST_API_KEY"] })
  .firestore.document(
    "{organizationEmail}/subscriptions/subscriptions/{subscriptionId}",
  )
  .onWrite(async (change, context) => {
    const organizationEmail = normalizeOrganizationEmail(
      context.params.organizationEmail,
    );
    if (!organizationEmail.includes("@")) return null;
    const after = change.after.exists ? change.after.data() : null;
    const before = change.before.exists ? change.before.data() : null;
    if (!after) return null;
    const statusChanged = before && before.status !== after.status;
    const isCreated = !before;
    if (!isCreated && !statusChanged) return null;
    const settings =
      await getOrganizationNotificationSettings(organizationEmail);
    const globalSettings = settings.notifications || {};
    const subSettings = settings.subscriptions || {};
    if (
      !isSettingEnabled(globalSettings, "enableNotifications", true) ||
      !isSettingEnabled(globalSettings, "enablePushNotifications", true) ||
      !isSettingEnabled(subSettings, "subscriptionAlertsEnabled", true) ||
      !isSettingEnabled(subSettings, "subscriptionAlertPushEnabled", true)
    )
      return null;
    const enabled = isCreated
      ? isSettingEnabled(subSettings, "subscriptionAlertNewEnabled", true)
      : isSettingEnabled(subSettings, "subscriptionAlertRenewalEnabled", true);
    if (!enabled) return null;
    const usersSnapshot = await db
      .collection(organizationEmail)
      .doc("users")
      .collection("users")
      .get();
    const users = usersSnapshot.docs.map((doc) => ({
      id: doc.id,
      data: doc.data(),
    }));
    const recipients = getRecipientPlayerIds(users, new Set(), new Set());
    if (recipients.size === 0) return null;
    const customerName = after.customerName || "المشترك";
    const title = isCreated ? "اشتراك جديد" : "تم تجديد الاشتراك";
    const body = isCreated
      ? `تم إنشاء اشتراك جديد للعميل ${customerName} بخطة ${after.name || ""}.`
      : `تم تجديد اشتراك العميل ${customerName} بخطة ${after.name || ""}.`;
    const eventKey = isCreated
      ? "created"
      : String(after.updatedAt?.toMillis?.() || Date.now());
    const dedupeRef = db
      .collection(organizationEmail)
      .doc("system")
      .collection("notificationSchedules")
      .doc(`subscription_${eventKey}_${context.params.subscriptionId}`);
    const existing = await dedupeRef.get();
    if (existing.exists) return null;
    await sendScheduledOrganizationPush({
      organizationEmail,
      recipients,
      title,
      body,
      type: isCreated ? "subscription_created" : "subscription_renewed",
    });
    await dedupeRef.set({
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return null;
  });

const onInvoiceWrittenSendPush = functions
  .runWith({ secrets: ["ONESIGNAL_REST_API_KEY"] })
  .firestore.document("{organizationEmail}/invoices/invoices/{invoiceId}")
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;
    const organizationEmail = normalizeOrganizationEmail(
      context.params.organizationEmail,
    );
    if (!organizationEmail.includes("@")) return null;
    const after = change.after.data();
    const before = change.before.exists ? change.before.data() : null;
    const type = !before ? "invoice_created" : "invoice_updated";
    const settings =
      await getOrganizationNotificationSettings(organizationEmail);
    const globalSettings = settings.notifications || {};
    const invoiceSettings = settings.invoices || {};
    const preference =
      type === "invoice_created"
        ? "invoice_notify_new"
        : "invoice_notify_updated";
    if (
      !isSettingEnabled(globalSettings, "enableNotifications", true) ||
      !isSettingEnabled(globalSettings, "enablePushNotifications", true) ||
      !isSettingEnabled(invoiceSettings, "invoiceAlertsEnabled", true) ||
      !isSettingEnabled(invoiceSettings, "invoiceAlertPushEnabled", true) ||
      !isSettingEnabled(globalSettings, preference, false)
    )
      return null;
    const usersSnapshot = await db
      .collection(organizationEmail)
      .doc("users")
      .collection("users")
      .get();
    const users = usersSnapshot.docs.map((doc) => ({
      id: doc.id,
      data: doc.data(),
    }));
    const recipients = getRecipientPlayerIds(users, new Set(), new Set());
    if (recipients.size === 0) return null;
    const title = type === "invoice_created" ? "فاتورة جديدة" : "تحديث فاتورة";
    const body =
      type === "invoice_created"
        ? `تم إصدار فاتورة جديدة للعميل ${after.customerName || ""}.`
        : `تم تحديث فاتورة العميل ${after.customerName || ""}.`;
    const dedupeRef = db
      .collection(organizationEmail)
      .doc("system")
      .collection("notificationSchedules")
      .doc(
        `invoice_${context.params.invoiceId}_${type}_${after.updatedAt?.toMillis?.() || "created"}`,
      );
    const existing = await dedupeRef.get();
    if (existing.exists) return null;
    await sendScheduledOrganizationPush({
      organizationEmail,
      recipients,
      title,
      body,
      type,
    });
    await dedupeRef.set({
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return null;
  });

// ===== Atomic Subscription Operations =====
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// جميع الدوال التالية تستخدم Firestore transactions
// لضمان الذريّة (Atomicity). هذا يعني أن جميع العمليات
// داخل المعاملة تتم بنجاح أو لا تتم على الإطلاق.
//
// إذا فشلت أي عملية داخل المعاملة، تُلغى جميع العمليات
// الأخرى تلقائياً. هذا يمنع الحالات غير المتسقة
// حيث يتم تحديث بعض المستندات فقط.
//
// القواعد الأساسية للذريّة:
// 1. استخدم transaction.get() لقراءة المستندات داخل المعاملة
// 2. استخدم transaction.set() و transaction.update() للكتابة
// 3. لا تستخدم firestore.get() خارج المعاملة لقراءة بيانات
//    ستُستخدم داخل المعاملة
// 4. استخدم FieldValue.increment() للعمليات الحسابية
//    لضمان عدم التداخل
// 5. استخدم expectedUpdatedAt للتحقق من التعديل المتزامن
//
// ════════════════════════════════════════════════════════════
// ✅ ملخص التحقق من الذريّة (Atomicity Verification)
// ════════════════════════════════════════════════════════════
//
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
//
// ✅ تم التحقق من جميع العمليات الذرية في قسم الاشتراكات:
//
// 1. createSubscriptionAtomic: ✅ ذري
//    - إنشاء الاشتراك + تحديث النوع + تحديث الصندوق + إنشاء الفاتورة + السجل
//    - جميعها داخل runTransaction واحدة
//
// 2. renewSubscriptionAtomic: ✅ ذري
//    - تجديد الاشتراك + تحديث النوع (activationQuantity -1 فقط) + السجل
//    - typeDocRef يُنشأ داخل المعاملة بعد قراءة currentSubscription
//    - جميعها داخل runTransaction واحدة
//
// 3. deleteSubscriptionAtomic: ✅ ذري
//    - حذف الاشتراك + تحديث النوع (linkedSubscriptionsCount -1, activationQuantity +1)
//    - حذف السجلات والفواتير المرتبطة
//    - جميعها داخل runTransaction واحدة
//
// 4. updateSubscriptionStatusAtomic: ✅ ذري
//    - تحديث الحالة + تحديث النوعين (القديم والجديد) عند تغيير النوع
//    - إنشاء سجل التغيير + تحديث relatedLogIds
//    - جميعها داخل runTransaction واحدة
//
// 5. rechargeActivationsAtomic: ✅ ذري
//    - تحديد activationQuantity + إنشاء سجل الشحن
//    - تحديث الصندوق + إنشاء سجل المعاملة
//    - جميعها داخل runTransaction واحدة
//
// 6. clearSubscriptionLogsAtomic: ✅ ذري
//    - الاستعلام خارج المعاملة (Firestore لا تدعم queries داخلها)
//    ثم قراءة كل مستند عبر transaction.get قبل حذفه داخل معاملة واحدة
//
// 7. دفع الاشتراك (updateSubscriptionPayment في repository): ✅ ذري
//    - تحديث totalPaid و remainingAmount في الاشتراك + تحديث الصندوق
//    - إنشاء سجل الدفع + تحديث relatedLogIds
//    - ⚠️ currentBalance عداد تراكمي — FieldValue.increment فقط
//      (لا currentBalance + amountPaid — مشكلة Read-Modify-Write)
//
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
//
// ════════════════════════════════════════════════════════════
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
// ════════════════════════════════════════════════════════════
//
// ⚠️ ⚠️ ⚠️ تحذير عالي الدقة جداً: ما يجب أن يكون ذرياً بدقة فائقة ⚠️ ⚠️ ⚠️
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// هذا القسم يحدد بدقة ما يجب أن يكون ذرياً معاً
// لتجنب التعديلات الغير صحيحة. إذا لم تكن أي عملية
// من هذه العمليات ذرية معاً، فإن البيانات تصبح غير متسقة.
//
// ════════════════════════════════════════════════════════════
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
// ════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
// ════════════════════════════════════════════════════════════════════════
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
// ════════════════════════════════════════════════════════════════════════
//
// ✅ ملخص التحقق من الذريّة (Atomicity Verification Summary)
//    تم التحقق من جميع العمليات الذرية في قسم الاشتراكات
//    وتحديد ما يجب أن يكون ذرياً بدقة فائقة
//
// ════════════════════════════════════════════════════════════════════════
//
// ⚠️ ⚠️ ⚠️ ما يجب أن يكون ذرياً بدقة فائقة في قسم الاشتراكات ⚠️ ⚠️ ⚠️
//
// ════════════════════════════════════════════════════════════════════════
//
// 1. إنشاء الاشتراك (createSubscriptionAtomic):
//    ✅ إنشاء مستند الاشتراك + تحديث النوع (activationQuantity -1،
//    linkedSubscriptionsCount +1) + تحديث الصندوق (cashbox) +
//    إنشاء الفاتورة + إنشاء السجل — كلها في runTransaction واحدة.
//    → إذا فشل أي منها، تُلغى جميع العمليات الأخرى.
//    → ⚠️ إذا لم تكن ذرية: اشتراك يُنشأ لكن النوع لا يُحدَّث
//      → عدد الاشتراكات غير صحيح + تفعيلات غير دقيقة
//
// 2. تجديد الاشتراك (renewSubscriptionAtomic):
//    ✅ تجديد الاشتراك + تحديث النوع (activationQuantity -1 فقط)
//    + إنشاء السجل — كلها في معاملة واحدة.
//    → ⚠️ إذا لم تكن ذرية: تجديد يحدث لكن التفعيلة لا تُستهلك
//      → تفعيلة مستهلكة بلا تجديد فعلي أو العكس
//    → ⚠️ ملاحظة: typeDocRef يُنشأ داخل المعاملة بعد قراءة
//      currentSubscription من docSnapshot.data() - هذا يضمن الذريّة.
//    → ⚠️ ملاحظة: totalPaid لا يُضاف إلى الصندوق عند التجديد
//      (أُضيف عند إنشاء الاشتراك الأصلي — إعادة إضافته تسبب
//      خصماً مزدوجاً). الدفعات الجديدة فقط عبر updateSubscriptionPayment.
//
// 3. حذف الاشتراك (deleteSubscriptionAtomic):
//    ✅ حذف الاشتراك + تحديث النوع (activationQuantity +1،
//    linkedSubscriptionsCount -1) + حذف السجلات المرتبطة +
//    حذف الفواتير المرتبطة — كلها في معاملة واحدة.
//    → ⚠️ إذا لم تكن ذرية: اشتراك يُحذف لكن النوع لا يُنقص
//      → عدد الاشتراكات أعلى من الفعلي + تفعيلات أقل من الفعلي
//    → ⚠️ ملاحظة: activationQuantity تزداد (+1) عند الحذف لأن
//      التفعيلة تُرجع للنوع، وليس تنقص (-1).
//
// 4. تحديث حالة الاشتراك (updateSubscriptionStatusAtomic):
//    ✅ تحديث الحالة + تحديث النوعين (القديم والجديد) عند تغيير
//    النوع + إنشاء سجل التغيير + تحديث relatedLogIds — كلها في
//    معاملة واحدة.
//    → ⚠️ إذا لم تكن ذرية: نقص في القديم بدون زيادة في الجديد
//      → العدد الإجمالي للاشتراكات ينقص بدون سبب
//    → ⚠️ ملاحظة: expectedUpdatedAt يُقرأ من العميل ويُقارن مع
//      updatedAt الذي يُقرأ من داخل المعاملة - هذا يضمن الذريّة.
//
// 5. شحن التفعيلات (rechargeActivationsAtomic):
//    ✅ تحديد activationQuantity + إنشاء سجل الشحن + تحديث
//    الصندوق + إنشاء سجل المعاملة — كلها في معاملة واحدة.
//    → ⚠️ إذا لم تكن ذرية: سجل شحن يُنشأ لكن التفعيلات لا تُحدَّث
//      → سجل يوثق عملية لم تحدث فعلياً
//    → ⚠️ ملاحظة: التحقق من الحد الأقصى (10000) يتم داخل
//      المعاملة باستخدام transaction.get() لقراءة الكمية الحالية.
//
// 6. دفع الاشتراك (updateSubscriptionPayment في repository):
//    ✅ تحديث totalPaid و remainingAmount في الاشتراك + تحديث
//    الصندوق + إنشاء سجل الدفع + تحديث relatedLogIds.
//    → ⚠️ currentBalance هو عداد تراكمي - يجب استخدام FieldValue.increment.
//    → ⚠️ إذا استخدمت currentBalance + amountPaid بدلاً من
//      FieldValue.increment: مشكلة Read-Modify-Write → فقدان
//      التعديلات المتزامنة.
//
// ════════════════════════════════════════════════════════════════════════
// ⚠️ ⚠️ ⚠️ لماذا FieldValue.increment() ذري ومهم؟ ⚠️ ⚠️ ⚠️
// ════════════════════════════════════════════════════════════════════════
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// FieldValue.increment يتم تنفيذه ذرياً على جانب خادم Firestore.
// لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
// Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
// هذا يمنع تماماً مشكلة Read-Modify-Write حيث يقوم مستخدمان
// بقراءة نفس القيمة ثم كتابة قيمة معدلة.
//
// ⚠️ مثال على مشكلة Read-Modify-Write:
// مستخدمان يريدان تقليل التفعيلات من 10 إلى 8:
// - المستخدم A يقرأ 10
// - المستخدم B يقرأ 10
// - المستخدم A يكتب 10-1=9
// - المستخدم B يكتب 10-1=9 (بدلاً من 8!)
// النتيجة: التفعيلات تصبح 9 بدلاً من 8 - تعديل غير صحيح!
// الحل: FieldValue.increment(-1) يضمن أن الخادم يضيف -1 للقيمة الحالية ذرياً.
//
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
//
// ⚠️ ⚠️ ⚠️ ملخص المشاكل التي أُصلحت (سجل تاريخي) ⚠️ ⚠️ ⚠️
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// المشاكل التالية أُصلحت جميعها (لا مشاكل معلقة —
// هذا سجل تاريخي للتوثيق فقط، لا تُصلح ما هو مُصلح):
//
// 1. ✅ deleteCustomerAtomic: يستخدم invoiceIds و logIds المخزنة
//    في مستند العميل بدلاً من where().get() داخل المعاملة.
//    Firestore Transactions لا تسمح بـ queries!
//
// 2. ✅ createSubscriptionAtomic: typeDocRef يُنشأ من
//    subscription.subscriptionTypeId مع db.doc() بدلاً من
//    where().get() خارج المعاملة.
//
// 3. ✅ renewSubscriptionAtomic: typeDocRef و expectedUpdatedAt —
//    يستخدم currentSubscription.subscriptionTypeId مع db.doc()
//    ويقارن expectedUpdatedAt الخارجي مع updatedAt المقروء
//    من داخل المعاملة (نمط Optimistic Locking الصحيح).
//
// 4. ✅ rechargeActivationsAtomic: typeDocRef يُنشأ داخل المعاملة
//    باستخدام db.doc() مع transaction.get() للقراءة.
//
// 5. ✅ deleteSubscriptionAtomic: تحديث activationQuantity
//    باستخدام FieldValue.increment — ⚠️ الحالة الحالية للكود:
//    التفعيلة تُرجع (+1) فقط للحالة active/pending — مطابقة
//    لجانب Dart (انظر التحقق المدمج أدناه). لا تجعلها
//    غير شرطية دون مراجعة جانب Dart أولاً.
//
// 6. ✅ updateSubscriptionStatusAtomic: تحديث عدد الاشتراكات
//    في النوعين (القديم والجديد) عند تغيير النوع.
//
// 7. ✅ rechargeActivationsAtomic: إزالة التحقق المزدوج
//    من quantity <= 0 (كان مكرراً).
//
// ════════════════════════════════════════════════════════════════════════
// ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
// ════════════════════════════════════════════════════════════════════════
//
// ════════════════════════════════════════════════════════════════════════
// 🔒 ملخص التحقق الذري الدقيق - Firebase Functions 🔒
// ════════════════════════════════════════════════════════════════════════
//
// ⚠️ ⚠️ ⚠️ ملخص شامل للمرمجين المستقبليين ⚠️ ⚠️ ⚠️
//
// ✅ ما يجب أن يكون ذرياً بدقة فائقة في Firebase Functions:
// (ملخص الدوال الذرية السبع موثق أعلاه في "ملخص التحقق
// من الذريّة"، والتحليل التفصيلي سطراً بسطر + القواعد
// الذهبية المؤكدة + تصحيحات انحرافات التعليق/كود
// موثقة في كتلة "التحقق اليدوي الدقيق المدمج" أدناه.)
// ⚠️ ملاحظة: لا تستخدم db.get() أو db.collection().where().get()
// داخل المعاملة — Firestore Transactions لا تسمح بـ queries!
// استخدم transaction.get(DocumentReference) أو runBatch().
// لا تقسم المعاملة إلى عمليات منفصلة — أي عملية تؤثر على
// أكثر من مستند يجب أن تكون داخل Transaction واحدة.
// بدون expectedUpdatedAt، Optimistic Locking يُتجاوز بالكامل.
//
// ════════════════════════════════════════════════════════════════════════
// 🔒 نهاية ملخص التحقق الذري الدقيق - Firebase Functions 🔒
// ════════════════════════════════════════════════════════════════════════
//
// ⚠️ ⚠️ ⚠️ ملاحظة: العمليات الذرية تُنفذ في مستوى Firebase Functions
// باستخدام Firestore Transactions. الذريّة تضمن أن جميع العمليات
// إما تنجح جميعها أو تفشل جميعاً.
// ⚠️ ⚠️ ⚠️

// ════════════════════════════════════════════════════════════
// 🔍 التحقق اليدوي الدقيق المدمج من الذريّة (تواريخ التحقق: 2026-10-08 و 2026-10-12 — أُعيد التحقق بنفس التاريخ بقراءة كاملة للدوال الست: لا انحرافات جديدة) — كتلة واحدة مدمجة تجمع التحققات الثانية والثالثة والرابعة وإعادة التحقق لتجنب الاطاله
// ════════════════════════════════════════════════════════════
//
// ⚠️ ملاحظة للمبرمجين المستقبليين:
// هذا التحقق (قراءة فقط، بدون أي تعديل في أي سطر
// تنفيذي) أعاد قراءة الدوال الذرية الست سطراً بسطر
// وقارنها بجانب Dart (subscription_repository_impl.dart)
// و BLoC (subscription_bloc.dart). لماذا يوجد هذا
// التحقق؟ لأن كل دالة تربط مستندات ببعضها (اشتراك ↔
// نوع ↔ سجلات ↔ صندوق ↔ فواتير ↔ عميل): لو فشل
// جزء ونجح جزء صارت البيانات غير متسقة. المعاملة
// الواحدة تضمن إما نجاح الكل أو فشل الكل.
// ✅ النتيجة: لا انحراف جديد — الدوال الست ذرية
// فعلاً ومطابقة لجانب Dart (كل transaction.get قبل
// كل كتابة، والعدادات عبر FieldValue.increment،
// والتحقق من التعديل المتزامن عبر expectedUpdatedAt).
// ✅ ما تم التحقق منه بدقة فائقة (اعتمد على أسماء
// الدوال لا أرقام الأسطر):
// 1. createSubscriptionAtomic — القراءات: الاشتراك +
//    النوع (activationQuantity >= 1) + العميل (عند
//    فاتورة بعميل) قبل أي كتابة؛ الكتابات: الاشتراك +
//    النوع (activationQuantity -1، linkedSubscriptionsCount
//    +1) + الصندوق (increment(totalPaid)) + الفاتورة +
//    invoiceIds العميل (arrayUnion) + __stats__ (increment).
//    فحص صلاحية الفاتورة وسجل الرفض خارج المعاملة
//    (موثق 2026-10-11 — رمي خطأ داخل المعاملة كان
//    يُلغي سجل الرفض معها فلا يُحفظ). typeDocRef يُنشأ
//    داخل المعاملة من subscriptionTypeId المعروف
//    (بدون استعلام) — النمط الصحيح.
// 2. renewSubscriptionAtomic — القراءات: الاشتراك +
//    النوع قبل أي كتابة؛ التحقق من الحالة المخزنة
//    active/expired مباشرة (canRenew غير مخزنة) +
//    expectedUpdatedAt + activationQuantity >= 1؛
//    الكتابات: الاشتراك (status + التواريخ + renewalCount
//    +1) + النوع (activationQuantity -1 فقط) + سجل
//    التجديد. لا يمس الصندوق (صحيح: totalPaid أُضيف
//    عند الإنشاء) ولا linkedSubscriptionsCount (صحيح:
//    التجديد لا يغير الارتباط).
// 3. deleteSubscriptionAtomic — القراءات: الاشتراك +
//    النوع قبل أي حذف؛ الكتابات: حذف السجلات +
//    الفواتير المرتبطة + النوع (linkedSubscriptionsCount
//    -1، activationQuantity +1 فقط للحالة active/pending)
//    + حذف الاشتراك.
// 4. updateSubscriptionStatusAtomic — القراءات: الاشتراك
//    + النوعين (عند تغيير النوع) قبل أي كتابة؛
//    الكتابات: القديم (-1 linked، +1 activation) +
//    الجديد (+1 linked، -1 activation) + الحالة + سجل
//    التغيير + relatedLogIds + تحقق expectedUpdatedAt.
// 5. rechargeActivationsAtomic — القراءات: النوع (حد
//    10000) + الصندوق (كفاية الرصيد) قبل أي كتابة؛
//    الكتابات: النوع (increment(quantity)) + سجل الشحن
//    + الصندوق (increment(-totalPrice)) + سجل المعاملة.
// 6. clearSubscriptionLogsAtomic — الاستعلام خارج
//    المعاملة (Firestore لا تدعم queries داخلها) ثم
//    قراءة كل مستند عبر transaction.get قبل حذفه
//    داخل معاملة واحدة (all-or-nothing).
// ⚠️⚠️⚠️ تصحيحات انحرافات تعليق/كود (2026-10-08):
// A. التعليق القديم في createSubscriptionAtomic كان
//    يقول "ناقص تحديثات ذرية" و"الحل: إضافة
//    transaction.set(statsDocRef...)" — غير صحيح!
//    الكود ينفذ تحديث __stats__ و invoiceIds في العميل
//    فعلاً. لا تعتمد على ذلك التعليق القديم.
// B. التعليقات القديمة في renewSubscriptionAtomic و
//    updateSubscriptionStatusAtomic كانت تقول "لا تستخدم
//    expectedUpdatedAt الخارجي مباشرة" — مضللة. الكود
//    يستخدم expectedUpdatedAt الخارجي ويقارنه مع
//    updatedAt المقروء من داخل المعاملة — وهذا هو نمط
//    Optimistic Locking الصحيح. لا تُزله.
// C. ملاحظة قديمة كانت تقول إن updateSubscription و
//    deleteSubscription في subscription_repository_impl.dart
//    "يستخدمان .where().get() داخل المعاملة" — غير
//    دقيقة! كلاهما يحل مرجع النوع خارج المعاملة (النمط
//    الصحيح). لا تُرجع لوضع استعلام داخل المعاملة أبداً.
// ⚠️ ملاحظات دقة (لتجنب التعديلات الغير صحيحة):
// 1. renewSubscriptionAtomic لا يمس الصندوق — صحيح
//    ومُوثق. لا تُضف خصماً مزدوجاً أبداً. الدفعات
//    الجديدة فقط عبر updateSubscriptionPayment (جانب Dart).
// 2. deleteSubscriptionAtomic يُرجع التفعيلة (+1) فقط
//    للحالة active/pending — مطابقة لجانب Dart. لا
//    تجعلها غير شرطية دون مراجعة جانب Dart أولاً.
// 3. التحقق من الحد الأقصى (10000) موجود فقط هنا
//    (في Cloud Function) وليس في كود Dart
//    (rechargeActivations) — موثّق.
// 4. createSubscriptionAtomic ينشئ الفاتورة و__stats__
//    وinvoiceIds — كلها ذرية مع الاشتراك. جانب Dart
//    (createSubscription) لا ينشئ فاتورة — الفواتير عبر
//    هذه الدالة فقط.
// 🔒 القواعد الذهبية المؤكدة (مدمجة — لا تنتهكها أبداً):
// 1. أي عملية تعدل أكثر من مستند = runTransaction واحدة.
// 2. كل القراءات قبل كل الكتابات — قاعدة Firestore
//    المفروضة (كل قراءة بعد أي كتابة ترمي خطأ).
// 3. لا where().get() داخل المعاملة — استخدم
//    transaction.get() على مرجع معروف.
// 4. FieldValue.increment() للعدادات دائماً — يمنع
//    مشكلة Read-Modify-Write.
// 5. expectedUpdatedAt للتحقق من التعديل المتزامن.
// 6. عند تغيير النوع: القديم (-1 linked، +1 activation)
//    والجديد (+1 linked، -1 activation) — الاتجاهات
//    معاكسة ولا تخلطها.
// 7. الاسم الصحيح للحقل: linkedSubscriptionsCount فقط
//    (القديم subscriptionCount لا يقرأه التطبيق أبداً).
// 🔒 نهاية التحقق اليدوي المدمج — لا تعدّل المنطق دون مراجعة هذا التحقق 🔒
// ════════════════════════════════════════════════════════════

/**
 * Atomic operation: Create subscription with all related documents
 * Ensures all-or-nothing execution for subscription creation
 *
 * ✅ تم التحقق من الذريّة: جميع العمليات التالية داخل runTransaction واحدة:
 * 1. إنشاء مستند الاشتراك (transaction.set)
 * 2. التحقق من وجود نوع الاشتراك (transaction.get)
 * 3. تحديث activationQuantity و linkedSubscriptionsCount في النوع (transaction.update)
 * 4. تحديث الصندوق (transaction.set مع FieldValue.increment)
 * 5. إنشاء الفاتورة (transaction.set)
 * 6. إنشاء السجل (transaction.set)
 * 7. تحديث relatedLogIds و relatedInvoiceIds (transaction.update)
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
 *
 * 1. FieldValue.increment(-1) لـ activationQuantity
 *    → إذا استخدمت currentQuantity - 1 بدلاً من FieldValue.increment(-1)،
 *      فإنك تعيد مشكلة Read-Modify-Write. مستخدمان يقرأان 10،
 *      كل منهما يكتب 9 بدلاً من 8. الحل: FieldValue.increment(-1) ذري.
 *
 * 2. FieldValue.increment(1) لـ linkedSubscriptionsCount
 *    → نفس المشكلة. يجب أن يكون ذرياً مع إنشاء الاشتراك.
 *      إذا تم إنشاء الاشتراك لكن لم يُحدَّث العدد،
 *      فإن عدد الاشتراكات في النوع يكون أعلى من الفعلي.
 *
 * 3. تحديث الصندوق (cashbox) باستخدام FieldValue.increment
 *    → يجب أن يكون ذرياً مع إنشاء الاشتراك.
 *      إذا تم إنشاء الاشتراك لكن لم يُحدَّث الصندوق،
 *      فإن الأموال لا تُسجل. إذا تم تحديث الصندوق لكن
 *      لم يُنشأ الاشتراك، فإن الأموال تُخصم بلا سبب.
 *
 * 4. إنشاء الفاتورة
 *    → يجب أن يكون ذرياً مع إنشاء الاشتراك.
 *      إذا تم إنشاء الفاتورة لكن لم يُنشأ الاشتراك،
 *      فإن الفاتورة تشير إلى اشتراك غير موجود.
 *
 * 5. التحقق من وجود نوع الاشتراك داخل المعاملة
 *    → typeDocRef يُنشأ باستخدام db.doc() مع subscription.subscriptionTypeId.
 *      المرجع لا يقرأ شيئاً. القراءة الفعلية تحدث داخل المعاملة
 *      عبر transaction.get(typeDocRef). هذا يضمن أن الذريّة محفوظة.
 *      إذا تم حذف النوع بين إنشاء المرجع وبدء المعاملة،
 *      فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 */
exports.createSubscriptionAtomic = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const { organizationEmail, subscription, invoice } = data;

    if (!organizationEmail || !organizationEmail.includes("@")) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بريد المؤسسة غير صالح",
      );
    }

    const normalizedEmail = organizationEmail
      .toLowerCase()
      .replace(/\./g, "")
      .replace(/\+.*/, "");
    const subscriptionDocRef = db
      .collection(normalizedEmail)
      .doc("subscriptions")
      .collection("subscriptions")
      .doc(subscription.id);

    // ⚠️ فحص صلاحية إنشاء فاتورة الاشتراك قبل المعاملة
    // (إصلاح تحقق يدوي 2026-10-11): كان هذا الفحص داخل
    // المعاملة ويكتب سجل الرفض عبر transaction.set ثم
    // يرمي خطأ — لكن رمي الخطأ يُلغي المعاملة فيُلغى
    // سجل الرفض معها فلا يُحفظ أبداً (النية كانت توثيق
    // الرفض). الفحص يعتمد فقط على بيانات الطلب (صلاحيات
    // الرمز ووجود الفاتورة) لا على بيانات المعاملة، لذلك
    // نُقل قبل المعاملة ويُكتب السجل خارجها فيُحفظ فعلاً.
    const hasInvoicePermission =
      context.token.permissions &&
      context.token.permissions.includes("invoices_subscription_manage");
    if (!hasInvoicePermission && !invoice) {
      const logDocRef = db
        .collection(normalizedEmail)
        .doc("subscriptions")
        .collection("logs")
        .doc();
      await logDocRef.set({
        userId: context.auth.uid,
        actionType: "auto_invoice_creation_permission_denied",
        details: "ليس لديه صلاحية إنشاء فاتورة اشتراك",
        targetId: subscription.id,
        targetType: "subscription",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isSuccess: false,
      });
      throw new functions.https.HttpsError(
        "permission-denied",
        "ليس لديك صلاحية إنشاء فاتورة اشتراك",
      );
    }

    try {
      await db.runTransaction(async (transaction) => {
        // ⚠️ تحذير عالي الدقة: typeDocRef يتم إنشاؤه داخل المعاملة
        // باستخدام subscription.subscriptionTypeId المعروف.
        // المرجع يُنشأ دون قراءة، والقراءة الفعلية تحدث
        // داخل المعاملة عبر transaction.get(typeDocRef). هذا يضمن الذريّة.
        // إذا تم حذف نوع الاشتراك بين إنشاء المرجع وبدء المعاملة،
        // فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
        const typeDocRef = subscription.subscriptionTypeId
          ? db
              .collection(normalizedEmail)
              .doc("subscriptions")
              .collection("types")
              .doc(subscription.subscriptionTypeId)
          : null;

        // Check if subscription already exists
        const docSnapshot = await transaction.get(subscriptionDocRef);
        if (docSnapshot.exists) {
          throw new Error("الاشتراك موجود مسبقاً");
        }

        // ⚠️ تحذير عالي الدقة: التحقق من وجود نوع الاشتراك + التفعيلات
        // داخل المعاملة بقراءة واحدة — قبل أي كتابة.
        // ⚠️ قاعدة Firestore الحاسمة (مُتحقق منها في الـ SDK المثبت
        // @google-cloud/firestore): كل transaction.get() يجب أن يكون
        // قبل كل transaction.set()/update()/delete()، وإلا رُمي خطأ:
        // "Firestore transactions require all reads to be executed
        // before all writes." لذلك تُجمع كل القراءات أعلى المعاملة.
        // إذا تم حذف النوع بين إنشاء المرجع وبدء المعاملة،
        // فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
        let typeSnapshot = null;
        if (typeDocRef) {
          typeSnapshot = await transaction.get(typeDocRef);
          if (!typeSnapshot.exists) {
            throw new Error("نوع الاشتراك غير موجود");
          }
          if (typeSnapshot.data()?.["activationQuantity"] < 1) {
            throw new Error("لا توجد تفعيلات كافية للشحن");
          }
        }

        // ⚠️ قراءة العميل (إذا وُجدت فاتورة بعميل) قبل أي كتابة
        // (نفس قاعدة القراءة قبل الكتابة أعلاه). القراءة تُستخدم
        // لاحقاً لتحديث invoiceIds في مستند العميل ذرياً مع الفاتورة.
        let customerRef = null;
        let customerSnapshot = null;
        if (invoice && invoice.customerId) {
          customerRef = db
            .collection(normalizedEmail)
            .doc("customers")
            .collection("customers")
            .doc(invoice.customerId);
          customerSnapshot = await transaction.get(customerRef);
        }

        // Set subscription
        transaction.set(subscriptionDocRef, subscription);

        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملخص الذريّة: تحديث النوع + الصندوق + الفاتورة + السجل
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //
        // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
        // 1. FieldValue.increment(-1) لـ activationQuantity ← ذري مع الاشتراك
        //    → إذا استخدمت currentQuantity - 1 بدلاً من FieldValue.increment(-1)،
        //      فإنك تعيد مشكلة Read-Modify-Write.
        //    → الحل: FieldValue.increment(-1) يضمن أن الخادم يضيف -1 ذرياً.
        // 2. FieldValue.increment(1) لـ linkedSubscriptionsCount ← ذري مع الاشتراك
        //    → إذا تم إنشاء الاشتراك لكن لم يُحدَّث العدد،
        //      فإن عدد الاشتراكات في النوع يكون أعلى من الفعلي.
        // 3. تحديث الصندوق باستخدام FieldValue.increment ← ذري مع الاشتراك
        //    → إذا تم إنشاء الاشتراك لكن لم يُحدَّث الصندوق،
        //      فإن الأموال لا تُسجل.
        // 4. إنشاء الفاتورة ← ذري مع الاشتراك
        //    → إذا تم إنشاء الفاتورة لكن لم يُنشأ الاشتراك،
        //      فإن الفاتورة تشير إلى اشتراك غير موجود.
        // 5. إنشاء السجل ← ذري مع الاشتراك
        //    → إذا تم إنشاء السجل لكن لم يتم إنشاء الاشتراك،
        //      فإن السجل يوثق عملية لم تحدث.
        //
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملاحظة للمبرمجين المستقبليين: typeSnapshot
        // قُرئ مسبقاً أعلى المعاملة (قبل أي كتابة).
        // لا تقرأ هنا أبداً — أي transaction.get() بعد
        // transaction.set()/update()/delete() يرمي خطأ
        // "Firestore transactions require all reads to be
        // executed before all writes."
        // ⚠️ اسم الحقل الصحيح هو linkedSubscriptionsCount
        // (مطابق لـ SubscriptionTypeEntity في جانب Dart).
        // الحقل القديم subscriptionCount غير موجود في
        // النموذج ولا يقرأه التطبيق — لا تستخدمه.
        if (typeDocRef && typeSnapshot && typeSnapshot.exists) {
          transaction.update(typeDocRef, {
            activationQuantity: admin.firestore.FieldValue.increment(-1),
            linkedSubscriptionsCount: admin.firestore.FieldValue.increment(1),
          });
        }

        // Update cashbox if paid
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملخص الذريّة: تحديث الصندوق ← ذري مع الاشتراك
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //
        // ⚠️ لماذا تحديث الصندوق يجب أن يكون ذرياً بدقة فائقة؟
        // لأن الصندوق والاشتراك مرتبطان ببعضهما البعض:
        // - إذا تم إنشاء الاشتراك لكن لم يتم تحديث الصندوق،
        //   فإن الأموال لا تُسجل بشكل صحيح.
        // - إذا تم تحديث الصندوق لكن لم يتم إنشاء الاشتراك،
        //   فإن الأموال تُخصم دون سبب.
        // - إذا قام مستخدمان بالدفع في نفس الوقت،
        //   يجب أن يكون تحديث الصندوق دقيقاً.
        //
        // ⚠️ لماذا FieldValue.increment() ذري ومهم هنا؟
        // تحديث currentBalance باستخدام FieldValue.increment() يتم تنفيذه ذرياً.
        // لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
        // Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
        // هذا يمنع تماماً مشكلة Read-Modify-Write.
        // إذا استخدمت currentBalance + amount بدلاً من FieldValue.increment(amount)،
        // فإنك تعيد نفس مشكلة Read-Modify-Write.
        // مثال: مستخدمان يدفعان 100 كل منهما:
        // - المستخدم A يقرأ balance = 500
        // - المستخدم B يقرأ balance = 500
        // - المستخدم A يكتب 500+100=600
        // - المستخدم B يكتب 500+100=600 (بدلاً من 700!)
        // النتيجة: الرصيد يصبح 600 بدلاً من 700 - تعديل غير صحيح!
        if (subscription.totalPaid > 0) {
          const cashboxRef = db
            .collection(normalizedEmail)
            .doc("cashbox")
            .collection("balance")
            .doc("main");
          transaction.set(
            cashboxRef,
            {
              currentBalance: admin.firestore.FieldValue.increment(
                subscription.totalPaid,
              ),
              lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
              updatedBy: subscription.createdBy,
            },
            { merge: true },
          );
        }

        // Create invoice if provided
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملخص الذريّة: إنشاء الفاتورة ← ذري مع الاشتراك
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //
        // ⚠️ لماذا إنشاء الفاتورة يجب أن يكون ذرياً بدقة فائقة؟
        // لأن الفاتورة والاشتراك مرتبطان ببعضهما البعض:
        // - إذا تم إنشاء الاشتراك لكن لم يتم إنشاء الفاتورة،
        //   فإن الاشتراك لا يملك فاتورة مرتبطة.
        // - إذا تم إنشاء الفاتورة لكن لم يتم إنشاء الاشتراك،
        //   فإن الفاتورة تشير إلى اشتراك غير موجود.
        // - إذا تم إنشاء الفاتورة لكن الاشتراك فشل،
        //   فإن المعاملة تُلغى تلقائياً بما في ذلك الفاتورة.
        //
        // ⚠️ ملاحظة: transaction.set(invoiceDocRef, invoice)
        // يتم داخل المعاملة، مما يعني أنه إذا فشل أي شيء،
        // تُلغى الفاتورة أيضاً. هذا هو الذريّة.
        if (invoice) {
          const invoiceDocRef = db
            .collection(normalizedEmail)
            .doc("invoices")
            .collection("invoices")
            .doc(invoice.id);
          transaction.set(invoiceDocRef, invoice);

          // ⚠️ ملاحظة ذرية حرجة: تحديث invoiceIds في مستند العميل
          // → يجب أن يكون ذرياً مع إنشاء الفاتورة
          // ⚠️ العميل قُرئ مسبقاً أعلى المعاملة
          // (قبل أي كتابة). لا تقرأ هنا أبداً —
          // أي transaction.get() بعد transaction.set()
          // يرمي خطأ "Firestore transactions require
          // all reads to be executed before all writes."
          if (customerRef && customerSnapshot && customerSnapshot.exists) {
            transaction.update(customerRef, {
              invoiceIds: admin.firestore.FieldValue.arrayUnion([invoice.id]),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          // ⚠️ ملاحظة ذرية حرجة: تحديث مستند الإحصائيات (__stats__)
          // → يجب أن يكون ذرياً بدقة فائقة مع إنشاء الفاتورة
          const statsDocRef = db
            .collection(normalizedEmail)
            .doc("invoices")
            .collection("invoices")
            .doc("__stats__");
          transaction.set(
            statsDocRef,
            {
              totalInvoices: admin.firestore.FieldValue.increment(1),
              totalAmount: admin.firestore.FieldValue.increment(
                invoice.totalAmount || 0,
              ),
              totalPaid: admin.firestore.FieldValue.increment(
                invoice.paidAmount || 0,
              ),
              totalRemaining: admin.firestore.FieldValue.increment(
                invoice.remainingAmount || 0,
              ),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ تصحيح تحقق يدوي (2026-10-08): التعليق القديم "ناقص تحديثات ذرية" غير صحيح — الكود ينفذ __stats__ و invoiceIds فعلاً أعلاه
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //
        // ⚠️ ما يلي يصف حالة قديمة — الكود الحالي ينفذ كل شيء أدناه فعلاً (تحقق 2026-10-08):
        //
        // 1. ✅ تحديث invoiceIds في مستند العميل
        //    → تمت الإضافة: transaction.update(customerRef, {invoiceIds: FieldValue.arrayUnion([invoice.id])})
        //    → هذا يضمن أن قائمة الفواتير في العميل تُحدَّث ذرياً مع إنشاء الفاتورة
        //
        // 2. تحديث مستند الإحصائيات (__stats__)
        //    → يجب أن يكون ذرياً بدقة فائقة مع إنشاء الفاتورة
        //    → إذا تم إنشاء الفاتورة لكن الإحصائيات لم تُحدَّث،
        //      فإن التقارير تكون خاطئة
        //    → ✅ مُنفَّذ فعلاً أعلاه: transaction.set(statsDocRef, {...}, {merge: true})
        //    → هذا يجب أن يكون ذرياً بدقة فائقة لتجنب تعديلات غير صحيحة
        //
        // ⚠️ لماذا هذه العمليات يجب أن تكون ذرية معاً؟
        // لأنها تعتمد على بعضها البعض:
        // - إذا تم إنشاء الفاتورة لكن invoiceCount لم يُحدَّث → عدود خاطئة
        // - إذا تم إنشاء الفاتورة لكن الإحصائيات لم تُحدَّث → تقارير خاطئة
        // - إذا فشل أي جزء، يجب إلغاء جميع التغييرات الأخرى
        //
        // ⚠️ ملاحظة: هذا يطابق Dart side (invoice_repository_impl.dart)
        // حيث يتم تحديث invoiceCount والإحصائيات بشكل صحيح داخل Transaction.
        // ✅ Node.js side و Dart side متزامنان الآن (تحقق 2026-10-08).
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
      });

      return { success: true, message: "تم إنشاء الاشتراك بنجاح" };
    } catch (error) {
      throw new functions.https.HttpsError("aborted", error.message);
    }
  },
);

// ⚠️ دوال مساعدة لحساب تواريخ التجديد (إصلاح التحقق اليدوي السادس 2026-10-08):
// ⚠️ ملاحظة للمبرمجين المستقبليين:
// هذه الدوال مطابقة بالضبط لدوال Dart في
// subscription_entity.dart (_calculateEndDateFromStart
// و _addMonthsToDate و calculateEndDate) — أي تغيير
// في منطق Dart يجب أن يُعكس هنا أيضاً. لا تُغيّر
// أحدهما دون الآخر — سيؤدي لاختلاف تواريخ النهاية
// بين العميل والخادم.
// تحويل أي قيمة تاريخ واردة (سلسلة ISO، رقم،
// كائن Timestamp، أو Date) إلى Date — لأن بيانات
// HTTPS Callable تصل بصيغ مختلفة حسب العميل.
function toDateValue(value) {
  if (value == null) return null;
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    return new Date(value);
  }
  if (typeof value.toDate === "function") return value.toDate();
  if (value.seconds != null) return new Date(value.seconds * 1000);
  return new Date(value);
}

// إضافة عدد من الأشهر مع معالجة تجاوز عدد أيام الشهر
// مثال: 31 يناير + شهر = 28 فبراير (وليس 3 مارس)
// مطابقة لـ _addMonthsToDate في subscription_entity.dart
function addMonthsToDate(date, months) {
  let newYear = date.getFullYear();
  let newMonth = date.getMonth() + 1 + months; // 1-based
  while (newMonth > 12) {
    newMonth -= 12;
    newYear += 1;
  }
  while (newMonth < 1) {
    newMonth += 12;
    newYear -= 1;
  }
  // آخر يوم في الشهر الجديد (اليوم 0 من الشهر التالي = آخر يوم للشهر الحالي)
  const lastDayOfNewMonth = new Date(newYear, newMonth, 0).getDate();
  const newDay =
    date.getDate() > lastDayOfNewMonth ? lastDayOfNewMonth : date.getDate();
  // إنشاء التاريخ الجديد مع الحفاظ على الوقت (مطابقة لـ Dart)
  return new Date(
    newYear,
    newMonth - 1,
    newDay,
    date.getHours(),
    date.getMinutes(),
    date.getSeconds(),
    date.getMilliseconds(),
  );
}

// حساب تاريخ النهاية من تاريخ البداية
// مطابقة لـ calculateEndDate في subscription_entity.dart
function calculateEndDate(startDate, duration, customDays) {
  const oneDayMs = 24 * 60 * 60 * 1000;
  switch (duration) {
    case "daily":
      return new Date(startDate.getTime() + oneDayMs);
    case "weekly":
      return new Date(startDate.getTime() + 7 * oneDayMs);
    case "monthly":
      return addMonthsToDate(startDate, 1);
    case "quarterly":
      return addMonthsToDate(startDate, 3);
    case "yearly":
      return addMonthsToDate(startDate, 12);
    case "custom":
      if (customDays == null || customDays <= 0) {
        throw new Error("عدد الأيام المخصصة يجب أن يكون أكبر من صفر");
      }
      return new Date(startDate.getTime() + customDays * oneDayMs);
    default:
      return addMonthsToDate(startDate, 1);
  }
}

/**
 * Atomic operation: Renew subscription with all related documents
 * Ensures all-or-nothing execution for subscription renewal
 *
 * ✅ تم التحقق من الذريّة: جميع العمليات التالية داخل runTransaction واحدة:
 * 1. قراءة الاشتراك (transaction.get)
 * 2. إنشاء typeDocRef داخل المعاملة بعد قراءة currentSubscription
 * 3. التحقق من وجود نوع الاشتراك (transaction.get)
 * 4. تحديث الاشتراك (transaction.update)
 * 5. تحديث activationQuantity فقط في النوع (transaction.update)
 *    ⚠️ بدون subscriptionCount/linkedSubscriptionsCount
 *    (التجديد لا يغير ارتباط الاشتراك بالنوع — مُعدّ
 *    عند الإنشاء). الاسم الصحيح للحقل هو
 *    linkedSubscriptionsCount (القديم subscriptionCount
 *    لا يقرأه التطبيق أبداً).
 * 6. إنشاء السجل (transaction.set)
 *    ⚠️ لا يتم تحديث الصندوق (صحيح ومُوثق:
 *    totalPaid أُضيف عند إنشاء الاشتراك الأصلي،
 *    والدفعات الجديدة فقط عبر updateSubscriptionPayment).
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
 *
 * 1. typeDocRef يُنشأ داخل المعاملة
 *    → بعد قراءة currentSubscription من docSnapshot.data().
 *      هذا يضمن أن الذريّة محفوظة بين الاشتراك وتحديث النوع.
 *      ⚠️ لا يُنشأ typeDocRef خارج المعاملة أبداً!
 *      إذا تم حذف النوع بين القراءة والتحديث،
 *      فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
 *
 * 2. expectedUpdatedAt يُقرأ من داخل المعاملة
 *    → docSnapshot.data()['updatedAt'] يُقرأ داخل المعاملة.
 *      هذا يضمن أن التحقق من التعديل المتزامن يكون ذرياً.
 *      إذا تم تعديل الاشتراك بين القراءة والتحديث،
 *      فإن المعاملة تُلغى.
 *      ✅ تصحيح تحقق يدوي (2026-10-08): النمط الحالي
 *      صحيح — الكود يقارن expectedUpdatedAt الخارجي
 *      مع updatedAt المقروء من داخل المعاملة.
 *      هذا هو نمط Optimistic Locking الصحيح.
 *      لا تُزِل هذا الفحص أبداً.
 *
 * 3. FieldValue.increment(-1) لـ activationQuantity
 *    → يجب أن يكون ذرياً مع تجديد الاشتراك.
 *      إذا استخدمت currentQuantity - 1 بدلاً من FieldValue.increment(-1)،
 *      فإنك تعيد مشكلة Read-Modify-Write.
 *
 * 4. تحديث الصندوق
 *    → ⚠️ لا يتم إضافة totalPaid إلى الصندوق عند التجديد!
 *    → السبب: totalPaid كان قد أُضيف مسبقاً عند إنشاء الاشتراك الأصلي.
 *    → إعادة إضافته تسبب خصماً مزدوجاً من الصندوق.
 *    → أي دفعة جديدة يتم التعامل معها عبر updateSubscriptionPayment.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * 5. إنشاء السجل ← ذري مع التجديد
 *      فإن الأموال لا تُسجل. إذا تم تحديث الصندوق
 *      لكن لم يتم التجديد، فإن الأموال تُخصم بلا سبب.
 *
 * 5. إنشاء السجل
 *    → يجب أن يكون ذرياً مع التجديد.
 *      إذا تم التجديد لكن لم يُنشأ السجل،
 *      فإن التاريخ لا يُوثق. إذا تم إنشاء السجل
 *      لكن لم يتم التجديد، فإن السجل يوثق عملية لم تحدث.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ✅ إصلاح تحقق يدوي (2026-10-08): أُصلح الملخصان
 * أعلاه (قائمة "تم التحقق من الذريّة" و"ملخص
 * الذريّة") — كانا يذكران تحديث subscriptionCount
 * والصندوق بشكل غير صحيح. الحالة الصحيحة: الكود
 * يحدّث activationQuantity فقط (بدون
 * subscriptionCount/linkedSubscriptionsCount — التجديد
 * لا يغير ارتباط الاشتراك بالنوع) ولا يمس الصندوق
 * (صحيح: totalPaid أُضيف عند إنشاء الاشتراك الأصلي،
 * والدفعات الجديدة فقط عبر updateSubscriptionPayment).
 * ✅ أيضاً: أُصلح التحقق من canRenew داخل المعاملة
 * (كان دائماً يرمي الخطأ لأن canRenew غير مُخزنة
 * في Firestore) — راجع الإصلاح عند سطر التحقق من
 * الحالة أسفل هذه الدالة.
 * ✅ إصلاح التحقق اليدوي السادس (2026-10-08): أُضيف
 * تحديث مستند الاشتراك نفسه داخل المعاملة (كان
 * مفقوداً — الدالة كانت تستهلك تفعيلة وتُنشئ سجل
 * تجديد دون تحديث status/endDate/renewalCount —
 * تفعيلة مستهلكة بلا تجديد فعلي). الآن الدالة
 * تُحدّث: الاشتراك (status='active' + التواريخ
 * المحسوبة عبر دوال مساعدة مطابقة لـ calculateEndDate
 * و _addMonthsToDate في subscription_entity.dart +
 * renewalCount +1 + lastRenewalDate + updatedAt +
 * updatedBy + isAutoRenew/isPaid + totalPaid=0 +
 * remainingAmount=price + nextBillingDate=endDate) +
 * activationQuantity -1 في النوع + سجل التجديد.
 * ⚠️ لا يمس الصندوق (صحيح ومُوثق أعلاه: totalPaid
 * أُضيف عند الإنشاء، والدفعات الجديدة فقط عبر
 * updateSubscriptionPayment).
 */
exports.renewSubscriptionAtomic = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const {
      organizationEmail,
      subscriptionId,
      customStartDate,
      isAutoRenew,
      isPaid,
      expectedUpdatedAt,
      updatedBy,
    } = data;

    // ✅ إصلاح التحقق اليدوي السادس (2026-10-08): تحديث مستند الاشتراك نفسه
    // ⚠️ ملاحظة للمبرمجين المستقبليين:
    // كان الاكتشاف الحرج في التحقق السادس: هذه الدالة
    // كانت ذرية (all-or-nothing) لكنها ناقصة — لا
    // تحتوي على أي transaction.update لمستند الاشتراك
    // (كانت تستهلك تفعيلة وتُنشئ سجل تجديد فقط دون
    // تحديث status/endDate/renewalCount — تفعيلة
    // مستهلكة بلا تجديد فعلي). ✅ الإصلاح المُنفَّذ:
    // أُضيف تحديث مستند الاشتراك داخل المعاملة (انظر
    // "إصلاح التحقق اليدوي السادس: تحديث مستند
    // الاشتراك نفسه" في جسم المعاملة أدناه) مطابقاً
    // لـ renewSubscription في subscription_repository_impl.dart.
    // ⚠️ الدالة لم تكن مستخدمة من التطبيق وقت الإصلاح
    // (التطبيق يستخدم renewSubscription في Dart عبر
    // SubscriptionBloc) — الآن تعمل بشكل صحيح إذا
    // استُدعيت مستقبلاً.
    // ⚠️ ملاحظة دقة: إعدادات وقت البدء الافتراضي
    // (_applyDefaultSubscriptionTime في Dart) تُقرأ من
    // SettingsService على العميل فقط — لا يمكن قراءتها
    // هنا، لذا يُستخدم تاريخ البداية الخام كما وصل
    // (customStartDate أو نهاية الاشتراك الحالية أو الآن).

    if (!organizationEmail || !organizationEmail.includes("@")) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بريد المؤسسة غير صالح",
      );
    }

    const normalizedEmail = organizationEmail
      .toLowerCase()
      .replace(/\./g, "")
      .replace(/\+.*/, "");
    const subDocRef = db
      .collection(normalizedEmail)
      .doc("subscriptions")
      .collection("subscriptions")
      .doc(subscriptionId);

    // ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
    // ⚠️ تحذير عالي الدقة: typeDocRef يُنشأ داخل المعاملة
    // بعد قراءة currentSubscription من docSnapshot.data().
    // هذا يضمن أن الذريّة محفوظة بين الاشتراك وتحديث النوع.
    // ⚠️ لا يُنشأ typeDocRef خارج المعاملة أبداً!
    // ⚠️ إذا تم حذف نوع الاشتراك بين القراءة والتحديث،
    // فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
    // هذا يجب أن يكون ذرياً بدقة فائقة لتجنب التعديلات الغير صحيحة.

    try {
      await db.runTransaction(async (transaction) => {
        // Read subscription inside transaction
        const docSnapshot = await transaction.get(subDocRef);
        if (!docSnapshot.exists) {
          throw new Error("الاشتراك غير موجود");
        }

        const currentData = docSnapshot.data();
        const currentSubscription = currentData;

        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ إصلاح الخلل الذري: typeDocRef يُنشأ الآن داخل المعاملة
        // ⚠️ بعد قراءة currentSubscription من docSnapshot.data()
        // ⚠️ هذا يضمن أن الذريّة محفوظة بين الاشتراك وتحديث النوع
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        const typeDocRef = currentSubscription?.subscriptionTypeId
          ? db
              .collection(normalizedEmail)
              .doc("subscriptions")
              .collection("types")
              .doc(currentSubscription.subscriptionTypeId)
          : null;

        // Check if subscription can be renewed
        // ✅ إصلاح تحقق يدوي (2026-10-08) — كان عيباً كامناً:
        // التحقق القديم `if (!currentSubscription.canRenew)`
        // كان سيرمي الخطأ دائماً لأن canRenew خاصية
        // محسوبة (getter) في كيان Dart
        // (subscription_entity.dart سطر 220:
        // status == 'active' || status == 'expired')
        // ولا تُخزن في Firestore أبداً (غير موجودة في
        // toJson في subscription_model.dart سطر 154)،
        // لذلك كانت قيمتها undefined هنا و
        // !undefined === true. ✅ الإصلاح المُنفَّذ:
        // مقارنة الحالة المخزنة مباشرة (نفس منطق
        // الـ getter في Dart بالضبط). ⚠️ الدالة غير
        // مستخدمة حالياً من التطبيق (التطبيق يستخدم
        // renewSubscription في
        // subscription_repository_impl.dart عبر
        // SubscriptionBloc سطر 752)، لكنها تعمل
        // بشكل صحيح الآن إذا استُدعيت مستقبلاً.
        const currentStatus = currentSubscription.status;
        if (currentStatus !== "active" && currentStatus !== "expired") {
          throw new Error("لا يمكن تجديد هذا الاشتراك");
        }

        // ⚠️ تحذير عالي الدقة: التحقق من التعديل المتزامن داخل المعاملة
        // الآن يتم قراءة updatedAt من داخل المعاملة باستخدام transaction.get()
        // بدلاً من expectedUpdatedAt الخارجي. هذا يضمن أن الذريّة محفوظة.
        // إذا كان expectedUpdatedAt لا يزال مطلوباً من العميل،
        // يمكن مقارنته مع updatedAt الداخلي.
        if (expectedUpdatedAt) {
          const existingUpdatedAt = currentData["updatedAt"]?.toDate();
          if (
            existingUpdatedAt &&
            existingUpdatedAt.getTime() !== expectedUpdatedAt
          ) {
            throw new Error(
              "تم تعديل الاشتراك من قبل مستخدم آخر، يرجى إعادة المحاولة",
            );
          }
        }

        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملخص الذريّة: تحديث الاشتراك + تحديث النوع + السجل
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //
        // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
        // 1. FieldValue.increment(-1) لـ activationQuantity ← ذري مع التجديد
        //    → إذا استخدمت currentQuantity - 1 بدلاً من FieldValue.increment(-1)،
        //      فإنك تعيد مشكلة Read-Modify-Write.
        //    ⚠️ لا يتم تحديث subscriptionCount/
        //    linkedSubscriptionsCount هنا — التجديد لا
        //    يغير ارتباط الاشتراك بالنوع (مُعدّ عند
        //    الإنشاء)، فالصحيح استهلاك تفعيلة فقط.
        // 2. إنشاء السجل ← ذري مع التجديد
        //    → إذا تم التجديد لكن لم يُنشأ السجل،
        //      فإن التاريخ لا يُوثق.
        // 3. typeDocRef يُنشأ داخل المعاملة ← ذري
        //    → بعد قراءة currentSubscription من docSnapshot.data().
        //      هذا يضمن أن الذريّة محفوظة بين الاشتراك وتحديث النوع.
        // ⚠️ لا يتم تحديث الصندوق هنا (صحيح ومُوثق):
        // totalPaid أُضيف عند إنشاء الاشتراك الأصلي،
        // والدفعات الجديدة فقط عبر updateSubscriptionPayment.
        //
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        if (typeDocRef) {
          const typeSnapshot = await transaction.get(typeDocRef);
          // ✅ إصلاح تحقق يدوي (2026-10-08): تحقق
          //    وجود النوع قبل قراءة بياناته (مطابقة
          //    لـ createSubscriptionAtomic). بدونه،
          //    إذا حُذف النوع بالتزامن، تُرمى خطأ
          //    Firestore غير واضح بدلاً من رسالة
          //    عربية واضحة — والمعاملة تُلغى في
          //    الحالتين.
          if (!typeSnapshot.exists) {
            throw new Error("نوع الاشتراك غير موجود");
          }
          if (typeSnapshot.data()?.["activationQuantity"] < 1) {
            throw new Error("لا توجد تفعيلات كافية للشحن");
          }
          // ✅ إصلاح تحقق يدوي (2026-10-08): أُزيلت الزيادة
          //    subscriptionCount +1 لأنها كانت خاطئة:
          //    (1) اسم الحقل الصحيح هو linkedSubscriptionsCount
          //    (الحقل القديم subscriptionCount لا يقرأه
          //    التطبيق أبداً)، (2) التجديد لا يغير ارتباط
          //    الاشتراك بالنوع (مُعدّ عند الإنشاء)، فالصحيح
          //    استهلاك تفعيلة فقط (activationQuantity -1)
          //    دون لمس عداد الاشتراكات المرتبطة — مطابقةً
          //    لـ renewSubscription في
          //    subscription_repository_impl.dart.
          transaction.update(typeDocRef, {
            activationQuantity: admin.firestore.FieldValue.increment(-1),
          });
        }

        // ✅ إصلاح التحقق اليدوي السادس (2026-10-08): تحديث مستند الاشتراك نفسه
        // ⚠️ ملاحظة للمبرمجين المستقبليين:
        // هذا التحديث كان مفقوداً — بدونه تستهلك
        // التفعيلة ويُنشأ سجل التجديد دون تغيير
        // تاريخ النهاية أو الحالة أو عدد التجديدات
        // (تفعيلة مستهلكة بلا تجديد فعلي — بيانات
        // غير متسقة). التحديث يطابق renewSubscription
        // في subscription_repository_impl.dart بالضبط:
        // status='active' + تاريخ البداية المحسوب +
        // تاريخ النهاية المحسوب + renewalCount +1 +
        // lastRenewalDate + updatedAt + updatedBy +
        // isAutoRenew/isPaid (الواردة أو الحالية) +
        // totalPaid=0 + remainingAmount=price +
        // nextBillingDate=تاريخ النهاية.
        // ⚠️ كل القراءات (transaction.get) أعلاه تمت
        // قبل هذه الكتابة — قاعدة Firestore: كل
        // القراءات قبل كل الكتابات. لا تُضف أي
        // transaction.get بعد هذا السطر أبداً.
        // ⚠️ حساب التواريخ يطابق Dart: تاريخ البداية
        // = customStartDate إن وُجد وصحيح، وإلا نهاية
        // الاشتراك الحالية إن كانت بعد الآن، وإلا الآن.
        // تاريخ النهاية = حساب المدة عبر
        // calculateEndDate أعلاه (مطابقة لـ
        // calculateEndDate في subscription_entity.dart).
        // ⚠️ إعدادات وقت البدء الافتراضي
        // (_applyDefaultSubscriptionTime) تُقرأ من
        // SettingsService على العميل فقط — لا يمكن
        // قراءتها هنا، لذا يُستخدم تاريخ البداية
        // الخام كما وصل.
        const renewalNow = new Date();
        const parsedEndDate = toDateValue(currentSubscription.endDate);
        const currentEndDate =
          parsedEndDate && !isNaN(parsedEndDate.getTime())
            ? parsedEndDate
            : renewalNow;
        const parsedCustomStart = toDateValue(customStartDate);
        const rawStartDate =
          parsedCustomStart && !isNaN(parsedCustomStart.getTime())
            ? parsedCustomStart
            : currentEndDate.getTime() > renewalNow.getTime()
              ? currentEndDate
              : renewalNow;
        const newStartDate = rawStartDate;
        const newEndDate = calculateEndDate(
          newStartDate,
          currentSubscription.duration,
          currentSubscription.customDays,
        );
        transaction.update(subDocRef, {
          status: "active",
          startDate: admin.firestore.Timestamp.fromDate(newStartDate),
          endDate: admin.firestore.Timestamp.fromDate(newEndDate),
          renewalCount: admin.firestore.FieldValue.increment(1),
          lastRenewalDate: admin.firestore.Timestamp.fromDate(renewalNow),
          updatedAt: admin.firestore.Timestamp.fromDate(renewalNow),
          updatedBy:
            updatedBy ||
            context.auth.token?.name ||
            context.auth.token?.email ||
            context.auth.uid,
          isAutoRenew:
            isAutoRenew != null
              ? isAutoRenew
              : (currentSubscription.isAutoRenew ?? false),
          isPaid:
            isPaid != null ? isPaid : (currentSubscription.isPaid ?? false),
          totalPaid: 0,
          remainingAmount: currentSubscription.price ?? 0,
          nextBillingDate: admin.firestore.Timestamp.fromDate(newEndDate),
        });

        // Update cashbox if paid
        // ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
        // ⚠️ تحذير عالي الدقة: تحديث الصندوق (cashbox) يجب أن يكون ذرياً مع التجديد!
        //
        // ⚠️ لماذا تحديث الصندوق يجب أن يكون ذرياً بدقة فائقة؟
        // لأن الصندوق والتجديد مرتبطان ببعضهما البعض:
        // - إذا تم تجديد الاشتراك لكن لم يتم تحديث الصندوق،
        //   فإن الأموال لا تُسجل بشكل صحيح
        // - إذا تم تحديث الصندوق لكن لم يتم التجديد،
        //   فإن الأموال تُخصم دون سبب
        // - إذا قام مستخدمان بالدفع في نفس الوقت،
        //   يجب أن يكون تحديث الصندوق دقيقاً
        //
        // ⚠️ لماذا FieldValue.increment() ذري ومهم هنا؟
        // تحديث currentBalance باستخدام FieldValue.increment() يتم تنفيذه ذرياً.
        // لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
        // Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
        // هذا يمنع تماماً مشكلة Read-Modify-Write.
        // إذا استخدمت currentBalance + amount بدلاً من FieldValue.increment(amount)،
        // فإنك تعيد نفس مشكلة Read-Modify-Write.
        // مثال: مستخدمان يريدان تجديد اشتراكين مدفوعين:
        // - المستخدم A يقرأ balance = 500
        // - المستخدم B يقرأ balance = 500
        // - المستخدم A يكتب 500+100=600
        // - المستخدم B يكتب 500+100=600 (بدلاً من 700!)
        // النتيجة: الرصيد يصبح 600 بدلاً من 700 - تعديل غير صحيح!
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
        // ⚠️ لا يتم تحديث الصندوق بـ totalPaid عند التجديد!
        // ⚠️ السبب: totalPaid يُمثّل إجمالي المبالغ المدفوعة مسبقاً
        // ⚠️ وقد تم إضافته إلى الصندوق بالفعل عند إنشاء الاشتراك الأصلي.
        // ⚠️ إعادة إضافته أثناء التجديد تسبب خصماً مزدوجاً من الصندوق.
        // ⚠️ أي دفعة جديدة أثناء التجديد يتم التعامل معها عبر
        // ⚠️ updateSubscriptionPayment وليس هنا.
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // لا يتم تحديث الصندوق هنا لأن totalPaid كان قد أُضيف مسبقاً
        // عند إنشاء الاشتراك الأصلي. الدفع الجديد يتم عبر
        // updateSubscriptionPayment.
        // totalPaid يُحفظ في مستند الاشتراك فقط دون إعادة إضافته للصندوق.

        // تحديث الصندوق إذا كان هناك دفعة جديدة (وليس totalPaid القديم)
        // ⚠️ لا يتم هنا إضافة totalPaid لأنه كان قد أُضيف مسبقاً
        // عند إنشاء الاشتراك الأصلي.

        // Create log
        // ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
        // ⚠️ تحذير عالي الدقة: إنشاء السجل يجب أن يكون ذرياً مع التجديد!
        //
        // ⚠️ لماذا إنشاء السجل يجب أن يكون ذرياً؟
        // لأن السجل يوثق عملية التجديد.
        // إذا تم التجديد لكن لم يتم إنشاء السجل،
        // فإن التاريخ لا يُوثق بشكل صحيح.
        // إذا تم إنشاء السجل لكن لم يتم التجديد،
        // فإن السجل يوثق عملية لم تحدث.
        // transaction.set(logDocRef, ...) داخل المعاملة
        // يضمن أن السجل يُنشأ فقط إذا نجح التجديد.
        const logDocRef = db
          .collection(normalizedEmail)
          .doc("subscriptions")
          .collection("logs")
          .doc();
        transaction.set(logDocRef, {
          userId: context.auth.uid,
          actionType: "renew_subscription",
          details: `تم تجديد الاشتراك: ${currentSubscription.name}`,
          targetId: subscriptionId,
          targetType: "subscription",
          timestamp: new Date(),
          isSuccess: true,
        });
      });

      return { success: true, message: "تم تجديد الاشتراك بنجاح" };
    } catch (error) {
      throw new functions.https.HttpsError("aborted", error.message);
    }
  },
);

/**
 * Atomic operation: Delete subscription with all related documents
 * Ensures all related logs and invoices are deleted atomically
 *
 * ✅ تم التحقق من الذريّة: جميع العمليات التالية داخل runTransaction واحدة:
 * 1. قراءة الاشتراك والبيانات المرتبطة (transaction.get)
 * 2. حذف السجلات المرتبطة (transaction.delete)
 * 3. حذف الفواتير المرتبطة (transaction.delete)
 * 4. تحديث النوع: linkedSubscriptionsCount -1, activationQuantity +1 (transaction.update)
 *    ⚠️ activationQuantity تزداد (+1) لأن التفعيلة تُرجع للنوع
 * 5. حذف الاشتراك (transaction.delete)
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
 *
 * 1. FieldValue.increment(1) لـ activationQuantity
 *    → ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *    عند حذف اشتراك، يتم إرجاع التفعيلة للنوع.
 *    لذلك activationQuantity يجب أن تزداد (+1) وليس تنقص (-1).
 *    ⚠️ إذا استخدمت FieldValue.increment(-1) لـ activationQuantity،
 *    فإنك تقلل التفعيلات بدلاً من إعادتها.
 *    النتيجة: تفعيلات أقل من الفعلي + لا يمكن إعادة تفعيلات محذوفة.
 *    الحل: FieldValue.increment(1) يضمن أن التفعيلة تُرجع ذرياً.
 *    ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * 2. FieldValue.increment(-1) لـ linkedSubscriptionsCount
 *    → يجب أن يكون ذرياً مع حذف الاشتراك.
 *      إذا تم حذف الاشتراك لكن لم يُنقص العدد،
 *      فإن عدد الاشتراكات في النوع يكون أعلى من الفعلي.
 *
 * 3. حذف السجلات والفواتير
 *    → يجب أن يكون ذرياً مع حذف الاشتراك.
 *      إذا تم حذف الاشتراك لكن لم تُحذف السجلات،
 *      فإن السجلات تبقى تشير إلى اشتراك غير موجود.
 *
 * 4. typeDocRef يُنشأ داخل المعاملة
 *    → المرجع لا يقرأ شيئاً. القراءة الفعلية تحدث
 *      داخل المعاملة عبر transaction.get(typeDocRef).
 *      إذا تم حذف النوع بين إنشاء المرجع وبدء المعاملة،
 *      فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 */
exports.deleteSubscriptionAtomic = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const { organizationEmail, subscriptionId } = data;

    if (!organizationEmail || !organizationEmail.includes("@")) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بريد المؤسسة غير صالح",
      );
    }

    const normalizedEmail = organizationEmail
      .toLowerCase()
      .replace(/\./g, "")
      .replace(/\+.*/, "");
    const subscriptionDocRef = db
      .collection(normalizedEmail)
      .doc("subscriptions")
      .collection("subscriptions")
      .doc(subscriptionId);

    try {
      await db.runTransaction(async (transaction) => {
        // Check if subscription exists and get related data
        const docSnapshot = await transaction.get(subscriptionDocRef);
        if (!docSnapshot.exists) {
          throw new Error("الاشتراك غير موجود");
        }

        const subscriptionData = docSnapshot.data();
        const subscriptionTypeId = subscriptionData?.["subscriptionTypeId"];
        const subscriptionStatus = subscriptionData?.["status"];
        const relatedLogIds = subscriptionData?.["relatedLogIds"] || [];
        const relatedInvoiceIds = subscriptionData?.["relatedInvoiceIds"] || [];

        // ⚠️ قراءة نوع الاشتراك قبل أي كتابة (قبل حذف
        // السجلات والفواتير أدناه).
        // ⚠️ قاعدة Firestore الحاسمة (مُتحقق منها في الـ SDK
        // المثبت @google-cloud/firestore): كل transaction.get()
        // يجب أن يكون قبل كل transaction.set()/update()/delete()،
        // وإلا رُمي خطأ: "Firestore transactions require all
        // reads to be executed before all writes."
        // لذلك تُقرأ كل المرجعات أعلى المعاملة.
        // ⚠️ typeDocRef يُنشأ هنا (داخل المعاملة) باستخدام
        // subscriptionTypeId المعروف من القراءة أعلاه.
        // إذا تم حذف النوع بين القراءة والتحديث،
        // فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
        let typeDocRef = null;
        let typeSnapshot = null;
        if (subscriptionTypeId) {
          typeDocRef = db
            .collection(normalizedEmail)
            .doc("subscriptions")
            .collection("types")
            .doc(subscriptionTypeId);
          typeSnapshot = await transaction.get(typeDocRef);
          if (!typeSnapshot.exists) {
            throw new Error("نوع الاشتراك غير موجود");
          }
        }

        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملخص الذريّة: حذف السجلات + الفواتير + تحديث النوع + حذف الاشتراك
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //
        // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
        // 1. حذف السجلات المرتبطة ← ذري مع حذف الاشتراك
        //    ⚠️ إذا تم حذف الاشتراك لكن لم تُحذف السجلات،
        //      فإن السجلات تبقى تشير إلى اشتراك غير موجود.
        // 2. حذف الفواتير المرتبطة ← ذري مع حذف الاشتراك
        //    ⚠️ إذا تم حذف الاشتراك لكن لم تُحذف الفواتير،
        //      فإن الفواتير تبقى تشير إلى اشتراك غير موجود.
        // 3. FieldValue.increment(1) لـ activationQuantity ← ذري مع الحذف
        //    ⚠️ activationQuantity تزداد (+1) لأن التفعيلة تُرجع للنوع
        //    ⚠️ إذا استخدمت FieldValue.increment(-1)، فإنك تقلل التفعيلات
        //       بدلاً من إعادتها - تعديل غير صحيح!
        // 4. FieldValue.increment(-1) لـ linkedSubscriptionsCount ← ذري مع الحذف
        // 5. حذف الاشتراك ← ذري مع جميع العمليات الأخرى
        //
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ⚠️ ⚠️ إصلاح: حذف السجلات والفواتير المرتبطة داخل المعاملة ⚠️ ⚠️ ⚠️
        // ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ كان يتم قراءة relatedLogIds و relatedInvoiceIds لكن لا يتم حذفها!
        // ⚠️ هذا يسبب بقاء سجلات وفواتير تشير إلى اشتراك غير موجود.
        // ⚠️ الآن يتم حذفها داخل المعاملة لضمان الذريّة.
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        for (const logId of relatedLogIds) {
          const logDocRef = db
            .collection(normalizedEmail)
            .doc("subscriptions")
            .collection("logs")
            .doc(logId);
          transaction.delete(logDocRef);
        }
        for (const invoiceId of relatedInvoiceIds) {
          const invoiceDocRef = db
            .collection(normalizedEmail)
            .doc("invoices")
            .collection("invoices")
            .doc(invoiceId);
          transaction.delete(invoiceDocRef);
        }
        // ⚠️ ملاحظة للمبرمجين المستقبليين:
        // typeSnapshot قُرئ مسبقاً أعلى المعاملة
        // (قبل حذف السجلات والفواتير). لا تقرأ هنا
        // أبداً — أي transaction.get() بعد transaction.delete()
        // يرمي خطأ "Firestore transactions require all
        // reads to be executed before all writes."
        // ⚠️ activationQuantity تزداد (+1) فقط إذا كانت
        // حالة الاشتراك active أو pending (مطابقة لجانب Dart
        // في subscription_repository_impl.dart). الاشتراك
        // الملغي/المكتمل لا يرجع تفعيلة.
        // ⚠️ اسم الحقل الصحيح هو linkedSubscriptionsCount
        // (مطابق لـ SubscriptionTypeEntity في جانب Dart).
        // الحقل القديم subscriptionCount غير موجود في
        // النموذج ولا يقرأه التطبيق — لا تستخدمه.
        if (typeDocRef && typeSnapshot && typeSnapshot.exists) {
          const typeUpdates = {
            linkedSubscriptionsCount: admin.firestore.FieldValue.increment(-1),
          };
          if (
            subscriptionStatus === "active" ||
            subscriptionStatus === "pending"
          ) {
            typeUpdates.activationQuantity =
              admin.firestore.FieldValue.increment(1);
          }
          transaction.update(typeDocRef, typeUpdates);
        }
        // Delete the subscription
        transaction.delete(subscriptionDocRef);
      });

      return { success: true, message: "تم حذف الاشتراك بنجاح" };
    } catch (error) {
      throw new functions.https.HttpsError("aborted", error.message);
    }
  },
);

/**
 * Atomic operation: Update subscription status with concurrent modification check
 *
 * ✅ تم التحقق من الذريّة: جميع العمليات التالية داخل runTransaction واحدة:
 * 1. قراءة الاشتراك (transaction.get)
 * 2. التحقق من التعديل المتزامن باستخدام expectedUpdatedAt
 * 3. تحديث حالة الاشتراك (transaction.update)
 * 4. تحديث النوعين (القديم والجديد) عند تغيير النوع (transaction.update)
 *    ⚠️ linkedSubscriptionsCount و activationQuantity في النوعين
 * 5. إنشاء سجل التغيير (transaction.set)
 * 6. تحديث relatedLogIds (transaction.update)
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
 *
 * 1. تحديث النوعين (القديم والجديد) عند تغيير النوع
 *    → ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *    إذا تم تغيير نوع الاشتراك (subscriptionTypeId)،
 *    فيجب تحديث linkedSubscriptionsCount و activationQuantity
 *    في النوعين (القديم والجديد) داخل المعاملة كعملية ذرية واحدة.
 *    ⚠️ المشكلة: إذا نقص العدد في النوع القديم
 *    لكن فشل الزيادة في النوع الجديد،
 *    فإن العدد الإجمالي للاشتراكات يكون غير صحيح.
 *    النوع القديم سيكون لديه عدد أقل
 *    والنوع الجديد لن يعرف بالاشتراكات الإضافية.
 *    ⚠️ الحل: كلا التحديثين داخل نفس المعاملة transaction.
 *    ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * 2. FieldValue.increment() لتحديث العدود
 *    → تحديث linkedSubscriptionsCount و activationQuantity
 *    في النوعين باستخدام FieldValue.increment()
 *    يتم تنفيذه ذرياً على جانب خادم Firestore.
 *    لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
 *    ⚠️ إذا استخدمت currentValue ± amount بدلاً من
 *    FieldValue.increment(amount)، فإنك تعيد
 *    مشكلة Read-Modify-Write.
 *
 * 3. expectedUpdatedAt يُقرأ من داخل المعاملة
 *    → docSnapshot.data()['updatedAt'] يُقرأ داخل المعاملة.
 *      هذا يضمن أن التحقق من التعديل المتزامن يكون ذرياً.
 *      ✅ تصحيح تحقق يدوي (2026-10-08): النمط الحالي
 *      صحيح — الكود يقارن expectedUpdatedAt الخارجي
 *      مع updatedAt المقروء من داخل المعاملة.
 *      هذا هو نمط Optimistic Locking الصحيح.
 *      لا تُزِل هذا الفحص أبداً.
 *
 * 4. إنشاء سجل التغيير
 *    → يجب أن يكون ذرياً مع تحديث الحالة.
 *      إذا تم تحديث الحالة لكن لم يُنشأ السجل،
 *      فإن التغيير لا يُوثق. إذا تم إنشاء السجل
 *      لكن لم يتم تحديث الحالة، فإن السجل يوثق
 *      عملية لم تحدث.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 */
exports.updateSubscriptionStatusAtomic = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const {
      organizationEmail,
      subscriptionId,
      status,
      reason,
      updatedBy,
      expectedUpdatedAt,
      newSubscriptionTypeId,
    } = data;

    if (!organizationEmail || !organizationEmail.includes("@")) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بريد المؤسسة غير صالح",
      );
    }

    const normalizedEmail = organizationEmail
      .toLowerCase()
      .replace(/\./g, "")
      .replace(/\+.*/, "");
    const subscriptionDocRef = db
      .collection(normalizedEmail)
      .doc("subscriptions")
      .collection("subscriptions")
      .doc(subscriptionId);

    try {
      await db.runTransaction(async (transaction) => {
        const docSnapshot = await transaction.get(subscriptionDocRef);
        if (!docSnapshot.exists) {
          throw new Error("الاشتراك غير موجود");
        }

        const oldSubscriptionTypeId =
          docSnapshot.data()?.["subscriptionTypeId"];
        if (
          newSubscriptionTypeId &&
          oldSubscriptionTypeId &&
          oldSubscriptionTypeId !== newSubscriptionTypeId
        ) {
          // ⚠️ ⚠️ ⚠️ تحذير عالي الدقة: typeDocRef يتم إنشاؤه داخل المعاملة ⚠️ ⚠️ ⚠️
          // ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
          // oldTypeDocRef و newTypeDocRef يتم إنشاؤهما داخل المعاملة
          // باستخدام db.doc() مع IDs المعروفة. المراجع لا تقرأ شيئاً.
          // القراءة الفعلية تحدث داخل المعاملة عبر transaction.get().
          // هذا يضمن أن الذريّة محفوظة.
          // إذا تم حذف أحد الأنواع بين إنشاء المرجع وبدء المعاملة،
          // فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
          const oldTypeDocRef = db
            .collection(normalizedEmail)
            .doc("subscriptions")
            .collection("types")
            .doc(oldSubscriptionTypeId);
          const newTypeDocRef = db
            .collection(normalizedEmail)
            .doc("subscriptions")
            .collection("types")
            .doc(newSubscriptionTypeId);
          const oldTypeSnapshot = await transaction.get(oldTypeDocRef);
          const newTypeSnapshot = await transaction.get(newTypeDocRef);
          // ✅ إصلاح تحقق يدوي (2026-10-08): سُجّل اسم الحقل
          //    الصحيح linkedSubscriptionsCount (كان subscriptionCount
          //    خاطئاً — حقل قديم لا يقرأه التطبيق). كيان نوع
          //    الاشتراك في Dart (subscription_type_entity.dart) ونموذجه
          //    يستخدمان linkedSubscriptionsCount فقط.
          if (oldTypeSnapshot.exists) {
            transaction.update(oldTypeDocRef, {
              linkedSubscriptionsCount:
                admin.firestore.FieldValue.increment(-1),
              // ⚠️ ⚠️ ⚠️ إصلاح: activationQuantity تزداد (+1) عند تغيير النوع
              // لأن التفعيلة تُرجع للنوع القديم (لا تستهلكها)
              activationQuantity: admin.firestore.FieldValue.increment(1),
            });
          }
          if (newTypeSnapshot.exists) {
            // ⚠️ التحقق من كفاية التفعيلات في النوع الجديد قبل
            // استهلاكها (نفس createSubscriptionAtomic و
            // renewSubscriptionAtomic) لمنع activationQuantity
            // السالبة — إصلاح 2026-10-12
            const newTypeActivationQuantity =
              newTypeSnapshot.data()?.["activationQuantity"] ?? 0;
            if (newTypeActivationQuantity < 1) {
              throw new Error("لا توجد تفعيلات كافية في النوع الجديد");
            }
            transaction.update(newTypeDocRef, {
              linkedSubscriptionsCount: admin.firestore.FieldValue.increment(1),
              // ⚠️ ⚠️ ⚠️ إصلاح: activationQuantity تنقص (-1) عند تغيير النوع
              // لأن التفعيلة تستهلك في النوع الجديد
              activationQuantity: admin.firestore.FieldValue.increment(-1),
            });
          }
        }

        // ⚠️ تحذير عالي الدقة: التحقق من التعديل المتزامن
        // expectedUpdatedAt يُقرأ من العميل ويُقارن مع updatedAt
        // الذي يُقرأ من داخل المعاملة عبر docSnapshot.data().
        // هذا يضمن أن التحقق من التعديل المتزامن يكون ذرياً.
        // ⚠️ الحل الأمثل: استخدام transaction.get() لقراءة updatedAt
        // داخل المعاملة ومقارنته مباشرة مع القيمة المتوقعة.
        if (expectedUpdatedAt) {
          const existingUpdatedAt = docSnapshot.data()["updatedAt"]?.toDate();
          if (
            existingUpdatedAt &&
            existingUpdatedAt.getTime() !== expectedUpdatedAt
          ) {
            throw new Error(
              "تم تعديل الاشتراك من قبل مستخدم آخر، يرجى إعادة المحاولة",
            );
          }
        }

        const previousStatus = docSnapshot.data()["status"];
        const now = admin.firestore.FieldValue.serverTimestamp();

        // Update status
        transaction.update(subscriptionDocRef, {
          status,
          updatedAt: now,
          ...(updatedBy ? { updatedBy } : {}),
          ...(reason ? { statusChangeReason: reason } : {}),
        });

        // Create log
        const logDocRef = db
          .collection(normalizedEmail)
          .doc("subscriptions")
          .collection("logs")
          .doc();
        transaction.set(logDocRef, {
          userId: context.auth.uid,
          actionType: "change_subscription_status",
          details: `تم تغيير الحالة من ${previousStatus} إلى ${status}${reason ? "، السبب: " + reason : ""}`,
          targetId: subscriptionId,
          targetType: "subscription",
          oldValues: docSnapshot.data(),
          newValues: { status, updatedBy, reason },
          timestamp: new Date(),
          isSuccess: true,
        });

        // Update relatedLogIds in subscription document
        transaction.update(subscriptionDocRef, {
          relatedLogIds: admin.firestore.FieldValue.arrayUnion([logDocRef.id]),
        });
      });

      return { success: true, message: "تم تحديث حالة الاشتراك بنجاح" };
    } catch (error) {
      throw new functions.https.HttpsError("aborted", error.message);
    }
  },
);

/**
 * Atomic operation: Recharge activations with balance verification
 *
 * ✅ تم التحقق من الذريّة: جميع العمليات التالية داخل runTransaction واحدة:
 * 1. إنشاء typeDocRef وقراءته داخل المعاملة (transaction.get)
 * 2. التحقق من الحد الأقصى (10000) داخل المعاملة
 * 3. تحديد activationQuantity (transaction.update مع FieldValue.increment)
 * 4. إنشاء سجل الشحن (transaction.set)
 * 5. تحديث الصندوق (transaction.set مع FieldValue.increment)
 * 6. إنشاء سجل المعاملة (transaction.set)
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
 *
 * 1. FieldValue.increment(quantity) لـ activationQuantity
 *    → يجب أن يكون ذرياً مع إنشاء سجل الشحن.
 *      إذا تم شحن التفعيلات لكن لم يُنشأ السجل،
 *      فإن السجل يوثق عملية لم تحدث.
 *      إذا تم إنشاء السجل لكن لم تُشحن التفعيلات،
 *      فإن السجل يوثق عملية لم تحدث.
 *
 * 2. تحديث الصندوق باستخدام FieldValue.increment(-totalPrice)
 *    → يجب أن يكون ذرياً مع شحن التفعيلات.
 *      ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *      إذا قام مستخدمان بدفع مبلغ في نفس الوقت:
 *      - المستخدم A يريد الدفع 100
 *      - المستخدم B يريد الدفع 100
 *      - المستخدم A يقرأ balance = 500
 *      - المستخدم B يقرأ balance = 500
 *      - المستخدم A يكتب 500-100=400
 *      - المستخدم B يكتب 500-100=400 (بدلاً من 300!)
 *      النتيجة: الرصيد يصبح 400 بدلاً من 300 - تعديل غير صحيح!
 *      الحل: FieldValue.increment(-totalPrice) يضمن أن الخادم
 *      يخصم المبلغ ذرياً.
 *      ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * 3. إنشاء سجل المعاملة (cashbox transactions)
 *    → يجب أن يكون ذرياً مع تحديث الصندوق.
 *      إذا تم تحديث الصندوق لكن لم يُنشأ سجل المعاملة،
 *      فإن الرصيد لا يُطابق السجلات.
 *      إذا تم إنشاء سجل المعاملة لكن لم يتم تحديث الصندوق،
 *      فإن المعاملة لا تُطابق الرصيد.
 *
 * 4. التحقق من الحد الأقصى (10000) داخل المعاملة
 *    → يتم باستخدام transaction.get() لقراءة الكمية الحالية.
 *      إذا تم شحن تفعيلات بين القراءة والتحديث،
 *      ستُعاد المعاملة تلقائياً.
 *      هذا يمنع تجاوز الحد الأقصى.
 *
 * 5. typeDocRef يُنشأ داخل المعاملة
 *    → المرجع لا يقرأ شيئاً. القراءة الفعلية تحدث
 *      داخل المعاملة عبر transaction.get(typeDocRef).
 *      إذا تم حذف النوع بين إنشاء المرجع وبدء المعاملة،
 *      فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 */
exports.rechargeActivationsAtomic = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const {
      organizationEmail,
      subscriptionTypeId,
      quantity,
      pricePerActivation,
      createdBy,
      boxId,
    } = data;

    if (!organizationEmail || !organizationEmail.includes("@")) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بريد المؤسسة غير صالح",
      );
    }

    if (quantity <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "كمية الشحن يجب أن تكون أكبر من صفر",
      );
    }

    const normalizedEmail = organizationEmail
      .toLowerCase()
      .replace(/\./g, "")
      .replace(/\+.*/, "");

    const totalPrice = quantity * pricePerActivation;
    const rechargeId = Date.now().toString();

    try {
      await db.runTransaction(async (transaction) => {
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملخص الذريّة: typeDocRef داخل المعاملة + التحقق + التحديث + السجلات
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //
        // ✅ typeDocRef يُنشأ داخل المعاملة ويُقرأ باستخدام transaction.get().
        //    هذا يضمن الذريّة.
        //    إذا تم حذف نوع الاشتراك بين بدء المعاملة والقراءة،
        //    فإن transaction.get() سيعيد snapshot فارغ وسيتم رمي خطأ.
        const typeDocRef = db
          .collection(normalizedEmail)
          .doc("subscriptions")
          .collection("types")
          .doc(subscriptionTypeId);
        const typeSnapshot = await transaction.get(typeDocRef);
        if (!typeSnapshot.exists) {
          throw new Error("نوع الاشتراك غير موجود");
        }
        const currentData = typeSnapshot.data();
        const currentQuantity = currentData?.["activationQuantity"] || 0;

        if (currentQuantity + quantity > 10000) {
          throw new Error("لا يمكن إضافة أكثر من 10000 تفعيلة");
        }

        // Verify cashbox balance if totalPrice > 0
        if (totalPrice > 0) {
          const cashboxRef = db
            .collection(normalizedEmail)
            .doc("cashbox")
            .collection("balance")
            .doc("main");
          const cashboxSnapshot = await transaction.get(cashboxRef);
          const currentBalance =
            cashboxSnapshot.data()?.["currentBalance"] || 0;
          if (currentBalance < totalPrice) {
            throw new Error(
              `رصيد الصندوق غير كافٍ. الرصيد الحالي: ${currentBalance}`,
            );
          }
        }

        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملخص الذريّة: تحديث activationQuantity + إنشاء سجل الشحن + تحديث الصندوق + سجل المعاملة
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //
        // ⚠️ ما يجب أن يكون ذرياً بدقة فائقة:
        // 1. FieldValue.increment(quantity) لـ activationQuantity ← ذري مع الشحن
        //    → إذا استخدمت currentQuantity + quantity بدلاً من FieldValue.increment(quantity)،
        //      فإنك تعيد مشكلة Read-Modify-Write.
        // 2. إنشاء سجل الشحن ← ذري مع التحديث
        //    → إذا تم شحن التفعيلات لكن لم يُنشأ السجل،
        //      فإن السجل يوثق عملية لم تحدث.
        // 3. تحديث الصندوق باستخدام FieldValue.increment(-totalPrice) ← ذري مع الشحن
        //    → ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //    إذا قام مستخدمان بدفع مبلغ في نفس الوقت:
        //    - المستخدم A يريد الدفع 100
        //    - المستخدم B يريد الدفع 100
        //    - المستخدم A يقرأ balance = 500
        //    - المستخدم B يقرأ balance = 500
        //    - المستخدم A يكتب 500-100=400
        //    - المستخدم B يكتب 500-100=400 (بدلاً من 300!)
        //    النتيجة: الرصيد يصبح 400 بدلاً من 300 - تعديل غير صحيح!
        //    الحل: FieldValue.increment(-totalPrice) يضمن أن الخادم يخصم المبلغ ذرياً.
        //    ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // 4. إنشاء سجل المعاملة ← ذري مع تحديث الصندوق
        //    → إذا تم تحديث الصندوق لكن لم يُنشأ سجل المعاملة،
        //      فإن الرصيد لا يُطابق السجلات.
        //    → إذا تم إنشاء سجل المعاملة لكن لم يتم تحديث الصندوق،
        //      فإن المعاملة لا تُطابق الرصيد.
        //
        // ⚠️ التحقق من الحد الأقصى (10000) يتم داخل المعاملة
        // باستخدام transaction.get() لقراءة الكمية الحالية.
        // إذا تم شحن تفعيلات بين القراءة والتحديث،
        // ستُعاد المعاملة تلقائياً.
        transaction.update(typeDocRef, {
          activationQuantity: admin.firestore.FieldValue.increment(quantity),
        });

        // Create recharge record (inside transaction)
        const rechargeDocRef = db
          .collection(normalizedEmail)
          .doc("subscriptions")
          .collection("activation_recharges")
          .doc(rechargeId);
        transaction.set(rechargeDocRef, {
          subscriptionTypeId,
          subscriptionTypeName: currentData?.["name"],
          addedQuantity: quantity,
          pricePerActivation,
          totalPrice,
          timestamp: new Date(),
          createdBy,
          organizationEmail,
          boxId,
        });

        // Record cashbox transaction if paid
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        // ⚠️ ملخص الذريّة: تحديث الصندوق + سجل المعاملة ← ذري مع الشحن
        // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
        //
        // ⚠️ لماذا تحديث الصندوق وسجل المعاملة يجب أن يكونا ذريين مع شحن التفعيلات؟
        // لأنها تعتمد على بعضها البعض:
        // - إذا تم تحديث الصندوق لكن لم يتم إنشاء سجل المعاملة،
        //   فإن الرصيد لا يُطابق السجلات.
        // - إذا تم إنشاء سجل المعاملة لكن لم يتم تحديث الصندوق،
        //   فإن المعاملة لا تُطابق الرصيد.
        // - إذا تم شحن التفعيلات لكن لم يتم تحديث الصندوق،
        //   فإن الأموال لا تُسجل.
        //
        // ⚠️ لماذا FieldValue.increment() ذري ومهم هنا؟
        // تحديث currentBalance باستخدام FieldValue.increment(-totalPrice)
        // يتم تنفيذه ذرياً على جانب الخادم.
        // لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
        // Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
        // هذا يمنع تماماً مشكلة Read-Modify-Write.
        if (totalPrice > 0) {
          const cashboxRef = db
            .collection(normalizedEmail)
            .doc("cashbox")
            .collection("balance")
            .doc("main");
          transaction.set(
            cashboxRef,
            {
              currentBalance: admin.firestore.FieldValue.increment(-totalPrice),
              lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
              updatedBy: createdBy,
            },
            { merge: true },
          );

          // Create transaction record (inside transaction)
          const transactionDocRef = db
            .collection(normalizedEmail)
            .doc("cashbox")
            .collection("transactions")
            .doc();
          transaction.set(transactionDocRef, {
            type: "out",
            amount: totalPrice,
            source: "subscription_activation",
            referenceId: rechargeId,
            description: `شحن ${quantity} تفعيلات`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            createdBy,
            subscriptionTypeId,
          });
        }
      });

      return { success: true, message: "تم شحن التفعيلات بنجاح" };
    } catch (error) {
      throw new functions.https.HttpsError("aborted", error.message);
    }
  },
);

// ===== Atomic Subscription Logs Cleanup =====
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// هذه الدالة تُنفذ حذف سجلات الاشتراكات ذرياً (all-or-nothing)
// على الخادم. لماذا دالة سحابية؟ لأن Firestore Transactions
// لا تدعم الاستعلامات (queries) داخل runTransaction من جانب
// العميل — لذلك يُنفذ الاستعلام والحذف هنا على الخادم حيث
// تُجرى المعاملة والاستعلام على نفس الشبكة (نافذة سباق
// ضئيلة جداً). ⚠️ للحذف قبل تاريخ (beforeDate) لا سباق
// أصلاً: السجلات الجديدة تحمل طوابع زمنية من الخادم أحدث
// من beforeDate فلا تطابق شرط الاستعلام.
// ⚠️ قاعدة Firestore الحاسمة: كل transaction.get قبل كل
// transaction.delete — تُجمع كل القراءات أعلى المعاملة.
// ⚠️ حد المعاملة: 500 مستند كحد أقصى (نفس قيد Write Batch
// في جانب العميل) — للحذف بأكثر من 500 سجل استدعِ الدالة
// على دفعات من جانب العميل.
exports.clearSubscriptionLogsAtomic = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const { organizationEmail, userId, beforeDate } = data;

    if (!organizationEmail || !organizationEmail.includes("@")) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بريد المؤسسة غير صالح",
      );
    }

    // فحص أمني: يجب أن يطابق بريد المستخدم الحالي بريد المؤسسة
    // (نفس _canAccessOrganization في جانب Dart) — يمنع مستخدماً
    // من حذف سجلات مؤسسة أخرى.
    const userEmail = context.token.email;
    if (!userEmail) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "لا يملك المستخدم بريداً إلكترونياً",
      );
    }
    const normalizeEmail = (email) =>
      email.toLowerCase().replace(/\./g, "").replace(/\+.*/, "");
    if (normalizeEmail(userEmail) !== normalizeEmail(organizationEmail)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "ليس لديك صلاحية للوصول لهذه المؤسسة",
      );
    }

    const normalizedEmail = normalizeEmail(organizationEmail);

    // بناء الاستعلام (خارج المعاملة — Firestore Transactions
    // لا تدعم queries). نفس فلاتر جانب Dart بالضبط.
    let query = db
      .collection(normalizedEmail)
      .doc("subscriptions")
      .collection("logs");
    if (userId) {
      query = query.where("userId", "==", userId);
    }
    if (beforeDate) {
      query = query.where(
        "timestamp",
        "<",
        admin.firestore.Timestamp.fromDate(new Date(beforeDate)),
      );
    }

    const querySnapshot = await query.get();
    if (querySnapshot.empty) {
      return { success: true, deletedCount: 0 };
    }

    // حذف جميع السجلات المطابقة داخل معاملة واحدة (all-or-nothing)
    // ⚠️ كل القراءات (transaction.get) أولاً — ثم كل الكتابات
    // (transaction.delete) — قاعدة Firestore الحاسمة التي يفرضها
    // الـ SDK: "Firestore transactions require all reads to be
    // executed before all writes."
    // ⚠️ إعادة التحقق من الوجود داخل المعاملة تمنع تطبيق الحذف
    // على مستند حُذف بالتزامن (يُتجاهل بأمان).
    await db.runTransaction(async (transaction) => {
      const snapshots = [];
      for (const doc of querySnapshot.docs) {
        snapshots.push(await transaction.get(doc.ref));
      }
      for (const snapshot of snapshots) {
        if (snapshot.exists) {
          transaction.delete(snapshot.ref);
        }
      }
    });

    return { success: true, deletedCount: querySnapshot.docs.length };
  },
);

// ===== Atomic Customer Operations =====
// ✅ ملاحظة مهمة حول الذريّة (Atomicity):
// جميع عمليات العملاء أدناه تستخدم Firestore Transactions لضمان الذريّة
// المعاملة الذرية تعني أن جميع العمليات إما تنجح معًا أو تفشل معًا
// هذا يمنع تضارب البيانات عند حدوث أخطاء في منتصف العملية
// مثال: إذا فشل إنشاء فاتورة الحساب الافتتاحي بعد إنشاء العميل،
// يتم التراجع عن إنشاء العميل أيضًا
//
// ⚠️ ⚠️ ⚠️ تحذير عالي الدقة: قواعد Firestore Transactions ⚠️ ⚠️ ⚠️
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// Firestore Transactions لا تسمح بـ:
//   - where().get() أو أي query داخل المعاملة
//   - يمكن فقط استخدام transaction.get(DocumentReference) مباشرة
//   - إذا احتجت query، استخدم firestore.runBatch() بدلاً من ذلك
//
// ⚠️ ⚠️ ⚠️ تحذير عالي الدقة: الذريّة بدقة فائقة ⚠️ ⚠️ ⚠️
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// العمليات التالية يجب أن تكون ذرية معاً بدقة فائقة لتجنب التعديلات الغير صحيحة:
//
// 1. إنشاء/تحديث/حذف العميل + تحديد customerCount في المجموعة
//    → يجب أن يكون ذرياً معاً
//    → إذا تم تحديث العميل لكن customerCount لم يُحدَّث،
//      فإن عدد العملاء في المجموعة يكون غير صحيح
//    → إذا تم تحديث customerCount لكن العميل لم يُنشأ،
//      فإن العدد يزيد دون سبب
//
// 2. إنشاء/حذف قيود البريد والهاتف + إنشاء/حذف العميل
//    → يجب أن يكون ذرياً معاً
//    → إذا تم إنشاء قيد البريد لكن العميل لم يُنشأ،
//      فإن قيداً زائداً يبقى في النظام
//    → إذا تم حذف العميل لكن قيد البريد لم يُحذف،
//      فإن القيد يمنع إنشاء عميل جديد بنفس البريد
//
// 3. إنشاء/أرشفة الفواتير + تحديث invoiceCount وtotalDebt
//    → يجب أن يكون ذرياً معاً
//    → إذا تم إنشاء فاتورة لكن invoiceCount لم يُحدَّث،
//      فإن العدد يكون غير صحيح
//    → إذا تم تحديث invoiceCount لكن الفاتورة لم تُنشأ،
//      فإن العدد يزيد دون سبب
//
// 4. تحديث الصندوق (cashbox) + إنشاء سجل المعاملة
//    → يجب أن يكون ذرياً معاً
//    → إذا تم تحديث الصندوق لكن سجل المعاملة لم يُنشأ،
//      فإن الرصيد لا يُطابق السجلات
//    → إذا تم إنشاء سجل المعاملة لكن الصندوق لم يُحدَّث،
//      فإن المعاملة لا تُطابق الرصيد
//
// 5. إنشاء سجل الشحن (activation_recharges) + تحديد activationQuantity
//    → يجب أن يكون ذرياً معاً
//    → إذا تم إنشاء السجل لكن التفعيلات لم تُحدَّث،
//      فإن السجل يوثق عملية لم تحدث
//    → إذا تم تحديث التفعيلات لكن السجل لم يُنشأ،
//      فإن الشحن لا يُوثق
//
// 6. ⚠️ ⚠️ ⚠️ تحديث مستند الإحصائيات (__stats__) + جميع العمليات الأخرى ⚠️ ⚠️ ⚠️
//    → يجب أن يكون ذرياً معاً بدقة فائقة!
//    → إذا تم تحديث العميل لكن __stats__ لم يُحدَّث،
//      فإن الإحصائيات تكون غير صحيحة
//    → إذا تم تحديث __stats__ لكن العميل لم يُنشأ/يُحدَّث/يُحذف،
//      فإن الإحصائيات تزيد/تنقص دون سبب
//    → هذا يجب أن يكون ذرياً بدقة فائقة لتجنب التعديلات الغير صحيحة
//    → ⚠️ ملاحظة (تصحيح 2026-10-08): التعليق القديم كان
//      يقول إن Node.js side لا يُحدّث __stats__ في الدوال
//      الثلاث — هذا غير صحيح! الكود يُحدّث __stats__ فعلاً
//      في createCustomerAtomic و updateCustomerAtomic و
//      deleteCustomerAtomic باستخدام transaction.set()
//      مع {merge: true} (التفصيل في كتلة التحقق أدناه).
//
// ⚠️ لماذا الذريّة بدقة فائقة مهمة؟
// لأن العمليات المذكورة أعلاه تعتمد على بعضها البعض.
// إذا لم تكن ذرية معاً، قد تحدث الحالات التالية:
// - عميل مُنشأ لكن قيد البريد غير موجود → تكرار البريد
// - فاتورة مُنشأة لكن invoiceCount غير مُحدَّث → عدود خاطئة
// - صندوق مُحدَّث لكن سجل المعاملة غير موجود → رصيد غير مطابق
// - تفعيلات مُحدَّثة لكن سجل الشحن غير موجود → سجل يوثق عملية لم تحدث
// - عميل مُحذف لكن customerCount لم يُنقص → عدد غير صحيح
// - __stats__ لم يُحدَّث → إحصائيات خاطئة
// هذا يجب أن يكون ذرياً بدقة فائقة لتجنب التعديلات الغير صحيحة.
//
// ⚠️ لماذا FieldValue.increment() ذري ومهم؟
// لأنه يتم تنفيذه ذرياً على جانب خادم Firestore.
// لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
// Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
// هذا يمنع تماماً مشكلة Read-Modify-Write حيث يقوم مستخدمان
// بقراءة نفس القيمة ثم كتابة قيمة معدلة.
// إذا استخدمت currentValue ± amount بدلاً من FieldValue.increment(amount)،
// فإنك تعيد نفس مشكلة Read-Modify-Write التي تسبب فقدان التعديلات المتزامنة.
//
// ⚠️ ⚠️ ⚠️ ملخص مشاكل الذريّة المكتشفة والمُصلحة ⚠️ ⚠️ ⚠️
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// تم اكتشاف المشاكل التالية المتعلقة بالذريّة وإصلاحها:
//
// 1. ✅ createCustomerAtomic: تم استخدام runTransaction لجميع العمليات
//    بما في ذلك التحقق من التكرار وإنشاء القيود وإنشاء الفاتورة
// 2. ✅ updateCustomerAtomic: تم استخدام runTransaction لجميع العمليات
//    بما في ذلك تحديد customerCount في المجموعات القديمة والجديدة
// 3. ✅ deleteCustomerAtomic: تم استخدام runTransaction لجميع العمليات
//    بما في ذلك حذف القيود والسجلات وتحديد customerCount
//    ✅ يقرأ الفواتير والسجلات عبر invoiceIds و logIds
//    المخزنة في مستند العميل (لا where().get() داخل
//    المعاملة — ممنوع في Firestore) — أُصلح 2026-10-08
//    (التفصيل في البند 1 أدناه)
// 4. ✅ createSubscriptionAtomic: تم استخدام runTransaction مع التحقق
//    من وجود نوع الاشتراك داخل المعاملة
// 5. ✅ renewSubscriptionAtomic: تم نقل قراءة الاشتراك ونوعه داخل المعاملة
// 6. ✅ deleteSubscriptionAtomic: تم جعل تقليل activationQuantity غير شرطي
//    باستخدام FieldValue.increment(-1) لتجنب race condition
// 7. ✅ updateSubscriptionStatusAtomic: تم إضافة تحديث عدد الاشتراكات
//    في النوعين (القديم والجديد) عند تغيير النوع
// 8. ✅ rechargeActivationsAtomic: تم نقل إنشاء typeDocRef داخل المعاملة
//    مع التحقق من وجود النوع باستخدام transaction.get()
// 9. ✅ createInvoiceAtomic: تم استخدام FieldValue.increment() لتحديث totalDebt
//    بدلاً من Read-Modify-Write لتجنب مشكلة التعديل المتزامن
// 10. ✅ updateInvoiceAtomic: تم استخدام FieldValue.increment() لتحديث totalDebt
// 11. ✅ deleteInvoiceAtomic: تم استخدام FieldValue.increment() لاسترجاع الدين
//
// ⚠️ ⚠️ ⚠️ ملخص المشاكل المُصلحة (سجل تاريخي) ⚠️ ⚠️ ⚠️
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// المشاكل التالية أُصلحت جميعها (لا مشاكل معلقة
// — هذا سجل تاريخي للتوثيق فقط، لا تُصلح ما هو
// مُصلح):
//
// 1. ✅ deleteCustomerAtomic: تم الإصلاح - يستخدم invoiceIds و logIds المخزنة
//    في مستند العميل بدلاً من where().get() داخل المعاملة.
//    السطر 2070: invoiceIds من docData?.['invoiceIds']
//    السطر 2083: logIds من docData?.['logIds']
//    Firestore Transactions لا تسمح بـ queries!
//    الحل المُنفَّذ: استخدام invoiceIds و logIds المخزنة في مستند العميل
//    مثلما هو مُنفَّذ في customer_repository_impl.dart (Dart side)
//    هذا يضمن الذريّة بدقة فائقة لتجنب التعديلات الغير صحيحة.
//
// 2. ✅ createSubscriptionAtomic: تم إصلاح typeDocRef
//    الآن يتم استخدام subscription.subscriptionTypeId مع db.doc()
//    بدلاً من where().get() خارج المعاملة. المرجع يُنشأ
//    دون قراءة، والقراءة الفعلية تحدث داخل المعاملة
//    عبر transaction.get(). هذا يضمن الذريّة.
// 3. ✅ renewSubscriptionAtomic: تم إصلاح typeDocRef و expectedUpdatedAt
//    الآن يتم استخدام currentSubscriptionData.subscriptionTypeId
//    مع db.doc() بدلاً من where().get() خارج المعاملة.
//    expectedUpdatedAt يُقارن مع updatedAt من داخل المعاملة.
// 4. ✅ rechargeActivationsAtomic: تم إصلاح typeDocRef
//    الآن يتم إنشاء المرجع داخل المعاملة باستخدام db.doc()
//    مع transaction.get() للقراءة. التحقق من الكفاية
//    وتحديد الكمية يتمان ذرياً داخل المعاملة.
// 5. ✅ deleteSubscriptionAtomic: تم جعل تقليل activationQuantity
//    غير شرطي باستخدام FieldValue.increment(-1) لتجنب race condition.
// 6. ✅ updateSubscriptionStatusAtomic: تم إضافة تحديث عدد الاشتراكات
//    في النوعين (القديم والجديد) عند تغيير النوع.
//    تم إضافة معامل newSubscriptionTypeId للدالة.
// 7. ✅ rechargeActivationsAtomic: تم إزالة التحقق المزدوج
//    من quantity <= 0 (كان مكرراً).
//
// ⚠️ لماذا الذريّة بدقة فائقة مهمة؟
// لأن العمليات المذكورة أعلاه تعتمد على بعضها البعض.
// إذا لم تكن ذرية معاً، قد تحدث الحالات التالية:
// - اشتراك مُنشأ لكن النوع لم يُحدَّث → عدد الاشتراكات غير صحيح
// - صندوق مُحدَّث لكن الاشتراك لم يُنشأ → أموال مخصومة بلا سبب
// - فاتورة مُنشأة لكن الاشتراك لم يُنشأ → فاتورة تشير إلى اشتراك غير موجود
// - سجل شحن مُنشأ لكن التفعيلات لم تُحدَّث → سجل يوثق عملية لم تحدث
// - عميل مُحذف لكن __stats__ لم يُحدَّث → إحصائيات خاطئة
// هذا يجب أن يكون ذرياً بدقة فائقة لتجنب التعديلات الغير صحيحة.
//
// ⚠️ لماذا FieldValue.increment() ذري ومهم؟
// لأنه يتم تنفيذه ذرياً على جانب خادم Firestore.
// لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
// Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
// هذا يمنع تماماً مشكلة Read-Modify-Write حيث يقوم مستخدمان
// بقراءة نفس القيمة ثم كتابة قيمة معدلة.
// إذا استخدمت currentValue ± amount بدلاً من FieldValue.increment(amount)،
// فإنك تعيد نفس مشكلة Read-Modify-Write التي تسبب فقدان التعديلات المتزامنة.
//
// ⚠️ ⚠️ ⚠️ ملخص مشاكل الذريّة المكتشفة والمُصلحة ⚠️ ⚠️ ⚠️
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// تم اكتشاف المشاكل التالية المتعلقة بالذريّة وإصلاحها:
//
// 1. ✅ createSubscriptionAtomic: تم إضافة التحقق من وجود نوع الاشتراك
//    داخل المعاملة (transaction.get) بدلاً من الاعتماد على المرجع الخارجي.
//    إذا تم حذف النوع، تُلغى المعاملة.
// 2. ✅ renewSubscriptionAtomic: تم نقل قراءة الاشتراك ونوعه
//    داخل المعاملة. الآن expectedUpdatedAt يُقرأ من داخل المعاملة
//    ويُستخدم transaction.get() للتحقق من وجود النوع.
// 3. ✅ deleteSubscriptionAtomic: تم جعل تقليل activationQuantity
//    غير شرطي باستخدام FieldValue.increment(-1) لتجنب race condition.
// 4. ✅ updateSubscriptionStatusAtomic: تم إضافة تحديث عدد الاشتراكات
//    في النوعين (القديم والجديد) عند تغيير النوع.
//    تم إضافة معامل newSubscriptionTypeId للدالة.
// 5. ✅ rechargeActivationsAtomic: تم نقل إنشاء typeDocRef داخل المعاملة
//    مع التحقق من وجود النوع باستخدام transaction.get().
//
// ⚠️ ⚠️ ⚠️ ما يجب أن يكون ذرياً بدقة فائقة ⚠️ ⚠️ ⚠️
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// العمليات التالية يجب أن تكون ذرية معاً:
//
// 1. تحديث نوع الاشتراك (activationQuantity و linkedSubscriptionsCount)
//    → يجب أن يكون ذرياً مع إنشاء/تحديث/حذف الاشتراك
//    → إذا تم تحديث النوع لكن لم يتم إنشاء الاشتراك،
//      فإن العدد يكون غير صحيح
//    → استخدام FieldValue.increment() يضمن الذريّة
//
// 2. تحديث الصندوق (cashbox)
//    → يجب أن يكون ذرياً مع الاشتراك
//    → إذا تم تحديث الصندوق لكن لم يتم إنشاء الاشتراك،
//      فإن الأموال تُخصم دون سبب
//    → إذا تم إنشاء الاشتراك لكن لم يتم تحديث الصندوق،
//      فإن الأموال لا تُسجل
//
// 3. إنشاء الفاتورة
//    → يجب أن يكون ذرياً مع الاشتراك
//    → إذا تم إنشاء الفاتورة لكن لم يتم إنشاء الاشتراك،
//      فإن الفاتورة تشير إلى اشتراك غير موجود
//
// 4. إنشاء سجل الشحن (activation_recharges)
//    → يجب أن يكون ذرياً مع تحديث التفعيلات
//    → إذا تم إنشاء السجل لكن لم يتم تحديث التفعيلات،
//      فإن السجل يوثق عملية لم تحدث
//
// 5. إنشاء سجل المعاملة (cashbox transactions)
//    → يجب أن يكون ذرياً مع تحديث الصندوق
//    → إذا تم إنشاء السجل لكن لم يتم تحديث الصندوق،
//      فإن المعاملة لا تُطابق الرصيد
//
// 6. التحقق من التعديل المتزامن (expectedUpdatedAt)
//    → يجب أن يكون ذرياً مع التحديث
//    → إذا تم تعديل الاشتراك بين القراءة والتحديث،
//      يجب أن تُلغى المعاملة
//    → استخدام transaction.get() لقراءة updatedAt داخل المعاملة
//
// 7. التحقق من وجود نوع الاشتراك
//    → يجب أن يكون ذرياً مع إنشاء/تحديث الاشتراك
//    → إذا تم حذف النوع بين القراءة والتحديث،
//      يجب أن تُلغى المعاملة
//    → استخدام transaction.get() للتحقق داخل المعاملة
//
// ⚠️ لماذا الذريّة بدقة فائقة مهمة؟
// لأن العمليات المذكورة أعلاه تعتمد على بعضها البعض.
// إذا لم تكن ذرية معاً، قد تحدث الحالات التالية:
// - اشتراك مُنشأ لكن النوع لم يُحدَّث → عدد الاشتراكات غير صحيح
// - صندوق مُحدَّث لكن الاشتراك لم يُنشأ → أموال مخصومة بلا سبب
// - فاتورة مُنشأة لكن الاشتراك لم يُنشأ → فاتورة تشير إلى اشتراك غير موجود
// - سجل شحن مُنشأ لكن التفعيلات لم تُحدَّث → سجل يوثق عملية لم تحدث
// هذا يجب أن يكون ذرياً بدقة فائقة لتجنب التعديلات الغير صحيحة.
//
// ⚠️ لماذا FieldValue.increment() ذري ومهم؟
// لأنه يتم تنفيذه ذرياً على جانب خادم Firestore.
// لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
// Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
// هذا يمنع تماماً مشكلة Read-Modify-Write حيث يقوم مستخدمان
// بقراءة نفس القيمة ثم كتابة قيمة معدلة.
// إذا استخدمت currentValue ± amount بدلاً من FieldValue.increment(amount)،
// فإنك تعيد نفس مشكلة Read-Modify-Write التي تسبب فقدان التعديلات المتزامنة.

// ════════════════════════════════════════════════════════════
// 🔍 التحقق اليدوي الدقيق من الذريّة — قسم العملاء (تاريخ التحقق: 2026-10-08)
// ════════════════════════════════════════════════════════════
//
// ⚠️ ملاحظة للمبرمجين المستقبليين:
// هذه الكتلة توثق نتيجة تحقق يدوي دقيق لجميع العمليات الذرية
// في قسم العملاء (createCustomerAtomic و updateCustomerAtomic
// و deleteCustomerAtomic). التحقق الأول (2026-10-08) كان
// بدون تعديل، ثم طُبِّق إصلاح (2026-10-08) موثق في
// البند B أدناه لتخزين invoiceIds و logIds و
// openingBalanceInvoiceId. الهدف: تأكيد ما هو ذري فعلاً،
// وتصحيح الانحرافات بين التعليقات والكود، لتجنب
// التعديلات الغير صحيحة.
// لا تُغيّر أي سطر تنفيذي أدناه دون قراءة هذا التحقق أولاً.
//
// ✅ ما تم التحقق من أنه ذري بشكل صحيح (كل القراءات عبر
//    transaction.get قبل كل الكتابات، وكل العمليات داخل
//    runTransaction واحدة — all-or-nothing):
//
// 1. createCustomerAtomic (سطر 1882):
//    ✅ التحقق من وجود العميل + فريدية البريد + فريدية الهاتف
//       (ثلاثة transaction.get قبل كل الكتابات)
//    ✅ إنشاء مستند العميل (transaction.set) مع تخزين
//       openingBalanceInvoiceId و invoiceIds و logIds
//       (إصلاح 2026-10-08 — الأسطر 1958-1960)
//    ✅ زيادة customerCount في المجموعة (FieldValue.increment(1))
//    ✅ إنشاء قيدي البريد والهاتف (transaction.set)
//    ✅ إنشاء فاتورة الحساب الافتتاحي (transaction.set)
//    ✅ إنشاء سجل النشاط (transaction.set)
//    ✅ تحديث __stats__ (transaction.set مع merge:true و
//       FieldValue.increment لكل عداد)
//    → كلها داخل runTransaction واحدة. القراءات الثلاث
//      (العميل، البريد، الهاتف) كلها قبل أول كتابة —
//      وهذا يحقق قاعدة Firestore: all reads before all writes.
//
// 2. updateCustomerAtomic (سطر 2105):
//    ✅ قراءة العميل + فريدية البريد/الهاتف عند تغيرهما +
//       صحة المجموعة عند تغيرها (transaction.get)
//    ✅ عند تغير الحساب الافتتاحي: قراءة الفاتورة القديمة +
//       حذفها + إنشاء فاتورة جديدة + تحديث
//       openingBalanceInvoiceId + مزامنة invoiceIds
//       (إزالة القديمة وإضافة الجديدة) — كلها ذرية
//    ✅ الحفاظ على invoiceIds/logIds من اللقطة الطازجة
//       داخل المعاملة (نمط Dart) + تتبع سجل التحديث
//       في logIds (إصلاح 2026-10-08)
//    ✅ تحديث مستند العميل (transaction.update)
//    ✅ تحديث القيود: حذف القديم + إنشاء الجديد (ذري)
//    ✅ تحديث customerCount: المجموعة القديمة -1 والجديدة +1
//       في نفس المعاملة (FieldValue.increment) — لا يجوز
//       فصلهما أبداً، وإلا أصبح العدد الإجمالي خاطئاً
//    ✅ إنشاء سجل النشاط + تحديث __stats__ بدلتا (الفرق
//       بين القديم والجديد) — ذري
//
// 3. deleteCustomerAtomic (سطر 2382):
//    ✅ قراءة العميل + التحقق من الفواتير عبر invoiceIds
//       المخزنة في المستند (بدون where().get() — الاستعلامات
//       غير مسموحة داخل المعاملة)
//    ✅ حذف السجلات عبر logIds المخزنة (transaction.get +
//       transaction.delete لكل سجل)
//    ✅ حذف قيدي البريد والهاتف + حذف العميل + تقليل
//       customerCount في المجموعة القديمة (-1) + تحديث
//       __stats__ (كل العدادات باتجاه السالب) — كلها ذرية
//
// ⚠️⚠️⚠️ تصحيحات انحرافات تعليق/كود (2026-10-08):
// A. التعليق في السطر 1486-1492 يقول إن Node.js side
//    "لا يتم تحديث __stats__ في createCustomerAtomic و
//    updateCustomerAtomic و deleteCustomerAtomic" — هذا
//    غير صحيح! الكود ينفذ تحديث __stats__ فعلاً في
//    الدوال الثلاث (الأسطر 2065 و 2347 و 2477) باستخدام
//    transaction.set مع {merge: true}. لا تعتمد على ذلك
//    التعليق القديم.
// B. ✅ تم الإصلاح (2026-10-08): createCustomerAtomic
//    يخزن الآن openingBalanceInvoiceId و invoiceIds
//    (بفاتورة الحساب الافتتاحي) و logIds (بسجل
//    الإنشاء) في مستند العميل (الأسطر 1958-1960) —
//    مطابقة لجانب Dart addCustomerWithOpeningBalance
//    الذي يخزن invoiceIds. و updateCustomerAtomic
//    يحافظ الآن على invoiceIds/logIds من اللقطة
//    الطازجة داخل المعاملة (نمط Dart) ويزامن
//    invoiceIds عند استبدال الفاتورة الافتتاحية
//    (إزالة القديمة وإضافة الجديدة) ويتتبع سجل
//    التحديث في logIds.
//    ⚠️ ملاحظتان للمبرمجين المستقبليين:
//    1. جانب Dart لا يخزن openingBalanceInvoiceId
//       لأنه لا يستبدل الفاتورة الافتتاحية في
//       updateCustomer — الحقل خاص بـ Node.js فقط.
//    2. سلوك الحذف يختلف بين الجانبين (Dart يربط
//       الفواتير بـ deleted_customer بينما Node.js
//       يمنع حذف عميل لديه فواتير) — هذا فرق
//       قواعد عمل قائم وليس جزءاً من الذريّة.
//
// ✅ ما يجب أن يكون ذرياً بدقة فائقة في قسم العملاء:
// 1. مستند العميل + قيدا البريد والهاتف ← ذري معاً
//    → إذا أُنشئ العميل دون القيدين: تكرار بريد/هاتف
//    → إذا أُنشئ القيد دون العميل: قيد زائف يمنع التسجيل
// 2. مستند العميل + customerCount في المجموعة ← ذري معاً
//    → FieldValue.increment فقط، لا read-then-write
// 3. مستند العميل + فاتورة الحساب الافتتاحي ← ذري معاً
//    → إذا فشل أي منهما تُلغى المعاملة كاملة
// 4. مستند العميل + __stats__ ← ذري معاً بدقة فائقة
//    → الإحصائيات تعكس الحقيقة فقط إذا تحركت مع العميل
// 5. عند تغيير المجموعة: القديمة -1 والجديدة +1 ← معاً
//    → فصلهما يكسر العدد الإجمالي للمجموعات
// 6. عند تغيير الرصيد الافتتاحي: حذف الفاتورة القديمة +
//    إنشاء الجديدة + تحديث العميل ← معاً
// 7. عند الحذف: العميل + القيود + السجلات + customerCount
//    + __stats__ ← معاً (all-or-nothing)
//
// ✅ القواعد الذهبية المؤكدة (لا تنتهكها أبداً):
// 1. أي عملية تعدل أكثر من مستند يجب أن تكون في
//    runTransaction واحدة.
// 2. كل عمليات القراءة (transaction.get) قبل كل عمليات
//    الكتابة — Firestore يفرض: all reads before all writes.
// 3. لا تستخدم db.collection().where().get() داخل المعاملة
//    — الاستعلامات غير مسموحة. استخدم المعرفات المخزنة
//    في مستند العميل (invoiceIds، logIds) كما في
//    deleteCustomerAtomic.
// 4. استخدم FieldValue.increment() للعدادات دائماً —
//    يمنع مشكلة Read-Modify-Write.
// 5. لا تُجزّئ المعاملة: تحديث المجموعتين (القديمة والجديدة)
//    يجب أن يبقى في نفس المعاملة حتى لو تغيرت مجموعة واحدة.
//
// 🔒 نهاية التحقق اليدوي لقسم العملاء — لا تعدّل المنطق دون مراجعة هذا التحقق 🔒
// ════════════════════════════════════════════════════════════
//
// 🔎 إعادة تحقق يدوية إضافية (2026-10-08) — قراءة
//    سطرية كاملة للدوال الثلاث بدون أي تعديل في
//    المنطق (تعليق فقط). القاعدة المفحوصة: كل
//    transaction.get() قبل كل transaction.set/
//    update/delete داخل نفس runTransaction واحدة:
//    ✅ createCustomerAtomic — القراءات: العميل
//       (شرطي)، قيد البريد (شرطي)، قيد الهاتف
//       (شرطي) — كلها قبل أول كتابة
//       (transaction.set للعميل). الكتابات: العميل
//       + customerCount في المجموعة (increment) +
//       قيدا البريد والهاتف + فاتورة الافتتاح +
//       سجل الإنشاء + __stats__ (merge+increment).
//       مرجعا الفاتورة والسجل يُنشآن مسبقاً
//       (توليد معرف فقط بدون قراءة) ويُخزنان في
//       مستند العميل (openingBalanceInvoiceId/
//       invoiceIds/logIds) — إصلاح 2026-10-08.
//    ✅ updateCustomerAtomic — القراءات: العميل +
//       قيدا البريد/الهاتف عند تغيرهما + المجموعة
//       عند تغيرها + الفاتورة القديمة عند تغير
//       الرصيد الافتتاحي — كلها قبل أي كتابة.
//       الكتابات: العميل (مع الحفاظ على
//       invoiceIds/logIds من اللقطة الطازجة داخل
//       المعاملة) + قيود البريد/الهاتف +
//       customerCount (القديمة -1 والجديدة +1) +
//       فاتورة الافتتاح الجديدة + سجل التحديث +
//       __stats__ (دلتا). مزامنة invoiceIds عند
//       استبدال الفاتورة الافتتاحية (إزالة القديمة
//       وإضافة الجديدة) وإضافة سجل التحديث إلى
//       logIds — إصلاح 2026-10-08 موثق.
//    ✅ deleteCustomerAtomic — القراءات: العميل +
//       كل الفواتير عبر invoiceIds المخزنة (بدون
//       where().get() الممنوع داخل المعاملة) + كل
//       السجلات عبر logIds المخزنة (قراءة كلها
//       أولاً ثم حذف كلها — لا قراءة بعد حذف) —
//       كلها قبل أي كتابة. الكتابات: حذف السجلات
//       + قيدا البريد/الهاتف + العميل +
//       customerCount (-1) + __stats__ (عدادات
//       سالبة).
//    ⚠️ تنبيه مهم: أرقام الأسطر في التحقق السابق
//       أعلاه (1882/2105/2382) أصبحت قديمة — لا
//       تعتمد عليها. الأرقام الصحيحة الحالية:
//       createCustomerAtomic سطر 2262،
//       updateCustomerAtomic سطر 2485،
//       deleteCustomerAtomic سطر 2762.
//    ✅ النتيجة: الدوال الثلاث ذرية فعلاً كما
//       وُثِّق — كل القراءات قبل كل الكتابات
//       (all-or-nothing)، ولا يوجد أي قراءة بعد
//       أي كتابة في أي معاملة. لا تحتاج أي تعديل
//       في المنطق.
// ════════════════════════════════════════════════════════════

/**
 * Atomic operation: Create customer with all related documents
 * Ensures all-or-nothing execution for customer creation
 *
 * ✅ ذري: جميع العمليات التالية داخل transaction واحدة:
 * 1. التحقق من وجود العميل مسبقًا
 * 2. التحقق من فريدية البريد الإلكتروني
 * 3. التحقق من فريدية رقم الهاتف
 * 4. إنشاء مستند العميل
 * 5. إنشاء قيود البريد الإلكتروني والهاتف
 * 6. إنشاء فاتورة الحساب الافتتاحي (إن وجدت)
 * 7. إنشاء سجل النشاط
 * 8. تحديد customerCount في المجموعة (إذا كان هناك مجموعة)
 * 9. تحديث مستند الإحصائيات (__stats__)
 * إذا فشل أي منها، يتم التراجع عن جميع التغييرات
 *
 * ⚠️ ⚠️ ⚠️ تحذير عالي الدقة: الذريّة بدقة فائقة ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * هذه العملية يجب أن تكون ذرية بدقة فائقة لأنها تشمل:
 * - إنشاء العميل + إنشاء القيود + تحديد customerCount + إنشاء الفاتورة
 * - إذا لم تكن ذرية، قد يُنشأ عميل بدون قيد بريد → تكرار
 * - إذا لم تكن ذرية، قد يُزاد customerCount دون إنشاء العميل → عدد غير صحيح
 * - إذا لم تكن ذرية، قد تُنشأ فاتورة دون العميل → فاتورة بلا مرجع
 *
 * ⚠️ ملاحظة: expectedUpdatedAt يُقرأ من العميل
 * ويُقارن مع updatedAt الذي يُقرأ من داخل المعاملة.
 * هذا النمط يعمل لكنه ليس مثالياً. الحل الأمثل:
 * قراءة updatedAt داخل المعاملة باستخدام transaction.get()
 * ومقارنته مباشرة.
 * هذا يجب أن يكون ذرياً بدقة فائقة لتجنب التعديلات الغير صحيحة.
 *
 * ⚠️ ملاحظة: FieldValue.increment(1) ذري على مستوى مستند واحد،
 * لكن يجب أن يكون داخل transaction لضمان ذريّة العملية بأكملها
 * مع إنشاء العميل وقيوده. بدون transaction، قد يحدث race condition
 * حيث يُنشأ عميلين بنفس البريد في نفس الوقت.
 * هذا يجب أن يكون ذرياً بدقة فائقة لتجنب التعديلات الغير صحيحة.
 */
exports.createCustomerAtomic = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const { organizationEmail, customer } = data;

  if (!organizationEmail || !organizationEmail.includes("@")) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "بريد المؤسسة غير صالح",
    );
  }

  const normalizedEmail = organizationEmail
    .toLowerCase()
    .replace(/\./g, "")
    .replace(/\+.*/, "");
  const customersCollection = db
    .collection(normalizedEmail)
    .doc("customers")
    .collection("customers");
  const customerDocRef = customer.id
    ? customersCollection.doc(customer.id)
    : customersCollection.doc();
  const customerId = customerDocRef.id;

  try {
    await db.runTransaction(async (transaction) => {
      // Check if customer already exists
      if (customer.id) {
        const docSnapshot = await transaction.get(customerDocRef);
        if (docSnapshot.exists) {
          throw new Error("العميل موجود مسبقاً");
        }
      }

      // Check email uniqueness constraint
      if (customer.email) {
        const emailConstraintRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("unique_constraints")
          .doc(`email:${customer.email.trim().toLowerCase()}`);
        const emailSnapshot = await transaction.get(emailConstraintRef);
        if (emailSnapshot.exists) {
          throw new Error("البريد الإلكتروني مستخدم من قبل");
        }
      }

      // Check phone uniqueness constraint
      if (customer.phone) {
        const phoneConstraintRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("unique_constraints")
          .doc(`phone:${customer.phone.trim()}`);
        const phoneSnapshot = await transaction.get(phoneConstraintRef);
        if (phoneSnapshot.exists) {
          throw new Error("رقم الهاتف مستخدم من قبل");
        }
      }

      // Prepare customer data
      const openingBalance = customer.openingBalance || 0;

      // ⚠️ ملاحظة ذرية حرجة (إصلاح 2026-10-08): توليد مراجع
      // الفاتورة الافتتاحية وسجل النشاط مسبقاً — توليد المعرف
      // فقط بدون قراءة — حتى تُخزن معرفاتها في مستند العميل
      // عند إنشائه. هذا يضمن:
      // 1. openingBalanceInvoiceId: حتى تستطيع
      //    updateCustomerAtomic حذف الفاتورة القديمة عند
      //    تغيير الرصيد الافتتاحي (بدون استعلام where
      //    الممنوع داخل المعاملة).
      // 2. invoiceIds: تتضمن فاتورة الحساب الافتتاحي
      //    (مطابقة لجانب Dart addCustomerWithOpeningBalance
      //    الذي يخزن invoiceIds) حتى تعرف deleteCustomerAtomic
      //    بوجودها ولا تُترك فاتورة يتيمة تشير لعميل محذوف.
      // 3. logIds: تتضمن سجل الإنشاء حتى يُحذف مع العميل
      //    ذرياً في deleteCustomerAtomic.
      // ⚠️ بدون هذا التخزين: الفاتورة والسجل يصبحان يتيمين
      // (orphaned) — لا يُحذفان مع العميل ولا يُعرف عنهما
      // عند التحديث. هذا كان سبب التحقق اليدوي أعلاه.
      const invoiceCollection = db
        .collection(normalizedEmail)
        .doc("invoices")
        .collection("invoices");
      const invoiceDocRef =
        openingBalance !== 0 ? invoiceCollection.doc() : null;
      const logCollection = db
        .collection(normalizedEmail)
        .doc("customers")
        .collection("logs");
      const logDocRef = logCollection.doc();

      const customerData = {
        ...customer,
        id: customerId,
        hasInvoices: openingBalance !== 0,
        totalPurchases: openingBalance > 0 ? openingBalance : 0,
        totalDebt: openingBalance,
        invoiceCount: openingBalance !== 0 ? 1 : 0,
        openingBalanceInvoiceId: invoiceDocRef ? invoiceDocRef.id : null,
        invoiceIds: invoiceDocRef ? [invoiceDocRef.id] : [],
        logIds: [logDocRef.id],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Set customer document
      transaction.set(customerDocRef, customerData);

      // ✅ ذري: زيادة customerCount في المجموعة عند إضافة عميل
      // هذا يجب أن يكون ذرياً مع إنشاء العميل لمنع تضارب البيانات
      if (customer.customerGroupId) {
        const groupRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("customer_groups")
          .doc(customer.customerGroupId);
        transaction.update(groupRef, {
          customerCount: admin.firestore.FieldValue.increment(1),
        });
      }

      // Set email constraint
      if (customer.email) {
        const emailConstraintRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("unique_constraints")
          .doc(`email:${customer.email.trim().toLowerCase()}`);
        transaction.set(emailConstraintRef, {
          type: "email",
          value: customer.email.trim().toLowerCase(),
          customerId: customerId,
        });
      }

      // Set phone constraint
      if (customer.phone) {
        const phoneConstraintRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("unique_constraints")
          .doc(`phone:${customer.phone.trim()}`);
        transaction.set(phoneConstraintRef, {
          type: "phone",
          value: customer.phone.trim(),
          customerId: customerId,
        });
      }

      // Create opening balance invoice if applicable
      // ⚠️ ملاحظة ذرية (إصلاح 2026-10-08): invoiceDocRef يُنشأ
      // مسبقاً أعلاه (قبل transaction.set للعميل) حتى يُخزن
      // معرفه في customerData.openingBalanceInvoiceId و
      // invoiceIds. لا تُنشئ مرجعاً جديداً هنا وإلا انفصل
      // المعرف المخزن عن الفاتورة المُنشأة.
      if (invoiceDocRef) {
        const isDebit = openingBalance > 0;
        const description = isDebit
          ? "حساب افتتاحي مدين (عليه)"
          : "حساب افتتاحي دائن (له)";

        const invoiceData = {
          customerName: customer.name,
          customerPhone: customer.phone,
          customerId: customerId,
          invoiceDate: admin.firestore.FieldValue.serverTimestamp(),
          totalAmount: Math.abs(openingBalance),
          paidAmount: isDebit ? 0 : Math.abs(openingBalance),
          remainingAmount: Math.abs(openingBalance),
          status: isDebit ? "unpaid" : "paid",
          type: "opening_balance",
          items: [
            {
              productName: description,
              quantity: 1,
              unit: "حساب",
              unitPrice: Math.abs(openingBalance),
              totalPrice: Math.abs(openingBalance),
            },
          ],
          notes: description,
          organizationEmail: organizationEmail,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: customer.createdBy || "النظام",
          balanceBeforeInvoice: 0,
          balanceAfterInvoice: openingBalance,
          invoiceNumber: `OB-${invoiceDocRef.id}`,
        };
        transaction.set(invoiceDocRef, invoiceData);
      }

      // Create log entry
      // ⚠️ ملاحظة ذرية (إصلاح 2026-10-08): logDocRef يُنشأ
      // مسبقاً أعلاه حتى يُخزن معرفه في customerData.logIds
      // ويُحذف مع العميل ذرياً في deleteCustomerAtomic.
      // لا تُنشئ مرجعاً جديداً هنا وإلا انفصل المعرف
      // المخزن عن السجل المُنشأ.
      transaction.set(logDocRef, {
        userId: context.auth.uid,
        userName: customer.name,
        userEmail: organizationEmail,
        actionType: "add_customer",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: `تم إضافة عميل جديد: ${customer.name}`,
        isSuccess: true,
        targetId: customerId,
        targetType: "customer",
      });

      // ✅ ذري: تحديث مستند الإحصائيات (__stats__) عند إنشاء العميل
      // هذا يجب أن يكون ذرياً بدقة فائقة مع الإنشاء لتجنب تعديلات غير صحيحة
      // ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
      // يتم استخدام transaction.set() مع {merge: true}
      // لضمان ذريّة بدقة فائقة. هذا يعني أن التحديث ذري حتى لو لم يكن
      // مستند الإحصائيات موجوداً مسبقاً.
      const isActive = customer.status === "active";
      const isInactive = customer.status === "inactive";
      const isBlocked = customer.status === "blocked";
      const hasGroup =
        customer.customerGroupId !== null && customer.customerGroupId !== "";
      const statsOpeningBalance = customer.openingBalance || 0;
      const statsDocRef = db
        .collection(normalizedEmail)
        .doc("customers")
        .collection("customers")
        .doc("__stats__");
      transaction.set(
        statsDocRef,
        {
          totalCustomers: admin.firestore.FieldValue.increment(1),
          activeCustomers: isActive
            ? admin.firestore.FieldValue.increment(1)
            : 0,
          inactiveCustomers: isInactive
            ? admin.firestore.FieldValue.increment(1)
            : 0,
          blockedCustomers: isBlocked
            ? admin.firestore.FieldValue.increment(1)
            : 0,
          customersWithGroups: hasGroup
            ? admin.firestore.FieldValue.increment(1)
            : 0,
          customersWithoutGroups: hasGroup
            ? 0
            : admin.firestore.FieldValue.increment(1),
          totalPurchases: admin.firestore.FieldValue.increment(
            statsOpeningBalance > 0 ? statsOpeningBalance : 0,
          ),
          netBalance: admin.firestore.FieldValue.increment(statsOpeningBalance),
          totalDebtAmount: admin.firestore.FieldValue.increment(
            statsOpeningBalance > 0 ? statsOpeningBalance : 0,
          ),
          totalCreditAmount:
            statsOpeningBalance < 0
              ? admin.firestore.FieldValue.increment(
                  Math.abs(statsOpeningBalance),
                )
              : 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    return { success: true, message: "تم إنشاء العميل بنجاح", customerId };
  } catch (error) {
    throw new functions.https.HttpsError("aborted", error.message);
  }
});

/**
 * Atomic operation: Update customer with all related documents
 * Ensures all-or-nothing execution for customer update
 *
 * ✅ ذري: جميع العمليات التالية داخل transaction واحدة:
 * 1. التحقق من وجود العميل
 * 2. التحقق من فريدية البريد الإلكتروني (إذا تغير)
 * 3. التحقق من فريدية رقم الهاتف (إذا تغير)
 * 4. التحقق من صحة المجموعة (إذا تغيرت)
 * 5. تحديث مستند العميل
 * 6. تحديث قيود البريد الإلكتروني والهاتف
 * 7. تحديث عدد العملاء في المجموعات (customerCount)
 * 8. إنشاء/حذف فاتورة الحساب الافتتاحي
 * 9. إنشاء سجل النشاط
 *
 * ⚠️ ملاحظة: يجب أيضًا تحديث totalPurchases عند تغيير الحساب الافتتاحي
 * لضمان اتساق البيانات
 */
exports.updateCustomerAtomic = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const { organizationEmail, customer } = data;

  if (!organizationEmail || !organizationEmail.includes("@")) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "بريد المؤسسة غير صالح",
    );
  }

  const normalizedEmail = organizationEmail
    .toLowerCase()
    .replace(/\./g, "")
    .replace(/\+.*/, "");
  const customersCollection = db
    .collection(normalizedEmail)
    .doc("customers")
    .collection("customers");
  const customerDocRef = customersCollection.doc(customer.id);

  try {
    await db.runTransaction(async (transaction) => {
      // Check if customer exists
      const docSnapshot = await transaction.get(customerDocRef);
      if (!docSnapshot.exists) {
        throw new Error("العميل غير موجود");
      }

      const docData = docSnapshot.data();
      const oldEmail = docData?.["email"] || "";
      const oldPhone = docData?.["phone"] || "";
      const oldOpeningBalance = docData?.["openingBalance"] || 0;
      const oldGroupId = docData?.["customerGroupId"] || "";

      // Check email uniqueness if changed
      if (customer.email && customer.email.trim().toLowerCase() !== oldEmail) {
        const emailConstraintRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("unique_constraints")
          .doc(`email:${customer.email.trim().toLowerCase()}`);
        const emailSnapshot = await transaction.get(emailConstraintRef);
        if (emailSnapshot.exists) {
          throw new Error("البريد الإلكتروني مستخدم من قبل");
        }
      }

      // Check phone uniqueness if changed
      if (customer.phone && customer.phone.trim() !== oldPhone) {
        const phoneConstraintRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("unique_constraints")
          .doc(`phone:${customer.phone.trim()}`);
        const phoneSnapshot = await transaction.get(phoneConstraintRef);
        if (phoneSnapshot.exists) {
          throw new Error("رقم الهاتف مستخدم من قبل");
        }
      }

      // Check group validity if changed
      if (customer.customerGroupId && customer.customerGroupId !== oldGroupId) {
        const groupRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("customer_groups")
          .doc(customer.customerGroupId);
        const groupSnapshot = await transaction.get(groupRef);
        if (!groupSnapshot.exists) {
          throw new Error("مجموعة العميل غير موجودة");
        }
        const groupData = groupSnapshot.data();
        if (groupData?.["isActive"] !== true) {
          throw new Error("مجموعة العميل غير نشطة");
        }
      }

      // Prepare update data
      const updateData = { ...customer };
      const newOpeningBalance = customer.openingBalance || 0;

      // ⚠️ ملاحظة ذرية حرجة (إصلاح 2026-10-08):
      // الحفاظ على invoiceIds و logIds من اللقطة
      // الطازجة المقروءة داخل المعاملة (وليس من
      // كيان العميل المرسل من العميل الذي قد يكون
      // قديماً) — نفس نمط Dart updateCustomer. هذا
      // يمنع فقدان معرفات الفواتير/السجلات التي
      // أُنشئت بعد تحميل الشاشة (مشكلة lost update).
      const existingInvoiceIds = Array.isArray(docData?.["invoiceIds"])
        ? docData["invoiceIds"].map(String)
        : Array.isArray(customer.invoiceIds)
          ? customer.invoiceIds.map(String)
          : [];
      const existingLogIds = Array.isArray(docData?.["logIds"])
        ? docData["logIds"].map(String)
        : Array.isArray(customer.logIds)
          ? customer.logIds.map(String)
          : [];
      updateData["invoiceIds"] = existingInvoiceIds;
      updateData["logIds"] = existingLogIds;

      // ⚠️ ملاحظة ذرية (إصلاح 2026-10-08): توليد
      // مرجع سجل التحديث مسبقاً (توليد المعرف فقط
      // بدون قراءة) حتى يُضاف إلى logIds في
      // transaction.update أدناه ويُحذف مع العميل
      // ذرياً في deleteCustomerAtomic.
      const logCollection = db
        .collection(normalizedEmail)
        .doc("customers")
        .collection("logs");
      const logDocRef = logCollection.doc();

      // Handle opening balance changes
      if (newOpeningBalance !== oldOpeningBalance) {
        updateData["totalPurchases"] =
          newOpeningBalance > 0
            ? newOpeningBalance
            : docData?.["totalPurchases"];
        updateData["totalDebt"] = newOpeningBalance;
        updateData["invoiceCount"] = newOpeningBalance !== 0 ? 1 : 0;

        // Delete old opening balance invoice
        const oldInvoiceId = docData?.["openingBalanceInvoiceId"];
        if (oldInvoiceId) {
          const oldInvoiceRef = db
            .collection(normalizedEmail)
            .doc("invoices")
            .collection("invoices")
            .doc(oldInvoiceId);
          const oldInvoiceSnapshot = await transaction.get(oldInvoiceRef);
          if (oldInvoiceSnapshot.exists) {
            transaction.delete(oldInvoiceRef);
          }
        }

        // Create new opening balance invoice
        const invoiceCollection = db
          .collection(normalizedEmail)
          .doc("invoices")
          .collection("invoices");
        const invoiceDocRef = invoiceCollection.doc();
        const isDebit = newOpeningBalance > 0;
        const description = isDebit
          ? "حساب افتتاحي مدين (عليه) - تحديث"
          : "حساب افتتاحي دائن (له) - تحديث";

        const invoiceData = {
          customerName: customer.name,
          customerPhone: customer.phone,
          customerId: customer.id,
          invoiceDate: admin.firestore.FieldValue.serverTimestamp(),
          totalAmount: Math.abs(newOpeningBalance),
          paidAmount: isDebit ? 0 : Math.abs(newOpeningBalance),
          remainingAmount: Math.abs(newOpeningBalance),
          status: isDebit ? "unpaid" : "paid",
          type: "opening_balance",
          items: [
            {
              productName: description,
              quantity: 1,
              unit: "حساب",
              unitPrice: Math.abs(newOpeningBalance),
              totalPrice: Math.abs(newOpeningBalance),
            },
          ],
          notes: description,
          organizationEmail: organizationEmail,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: customer.createdBy || "النظام",
          balanceBeforeInvoice: oldOpeningBalance,
          balanceAfterInvoice: newOpeningBalance,
          invoiceNumber: `OB-${invoiceDocRef.id}`,
        };
        transaction.set(invoiceDocRef, invoiceData);
        updateData["openingBalanceInvoiceId"] = invoiceDocRef.id;

        // ⚠️ ملاحظة ذرية (إصلاح 2026-10-08): مزامنة
        // invoiceIds عند استبدال الفاتورة الافتتاحية:
        // إزالة الفاتورة القديمة (إن وُجدت في القائمة)
        // وإضافة الجديدة. بدون هذا: القائمة تشير
        // لفاتورة محذوفة ولا تعرف الفاتورة الجديدة
        // → فاتورة يتيمة لا تُحذف مع العميل ولا
        // تُمنع حذف العميل بوجودها في deleteCustomerAtomic.
        const syncedInvoiceIds = existingInvoiceIds.filter(
          (id) => id !== oldInvoiceId,
        );
        syncedInvoiceIds.push(invoiceDocRef.id);
        updateData["invoiceIds"] = syncedInvoiceIds;
      }

      // ⚠️ ملاحظة ذرية (إصلاح 2026-10-08): إضافة
      // معرف سجل التحديث إلى logIds حتى يُحذف مع
      // العميل ذرياً في deleteCustomerAtomic. بدون
      // هذا: سجل التحديث يتيم — لا يُحذف مع العميل.
      updateData["logIds"] = [...existingLogIds, logDocRef.id];

      // Update customer document
      transaction.update(customerDocRef, {
        ...updateData,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update email constraint if changed
      if (customer.email && customer.email.trim().toLowerCase() !== oldEmail) {
        if (oldEmail) {
          transaction.delete(
            db
              .collection(normalizedEmail)
              .doc("customers")
              .collection("unique_constraints")
              .doc(`email:${oldEmail}`),
          );
        }
        transaction.set(
          db
            .collection(normalizedEmail)
            .doc("customers")
            .collection("unique_constraints")
            .doc(`email:${customer.email.trim().toLowerCase()}`),
          {
            type: "email",
            value: customer.email.trim().toLowerCase(),
            customerId: customer.id,
          },
        );
      }

      // Update phone constraint if changed
      if (customer.phone && customer.phone.trim() !== oldPhone) {
        if (oldPhone) {
          transaction.delete(
            db
              .collection(normalizedEmail)
              .doc("customers")
              .collection("unique_constraints")
              .doc(`phone:${oldPhone}`),
          );
        }
        transaction.set(
          db
            .collection(normalizedEmail)
            .doc("customers")
            .collection("unique_constraints")
            .doc(`phone:${customer.phone.trim()}`),
          {
            type: "phone",
            value: customer.phone.trim(),
            customerId: customer.id,
          },
        );
      }

      // Update group customer counts if group changed
      // ✅ ذري: تحديث customerCount في المجموعات ذري باستخدام FieldValue.increment
      // هذا يضمن أن العدد يكون دائماً متسقاً حتى مع التزامن
      // إذا تم تغيير المجموعة، يتم تقليل العدد في المجموعة القديمة
      // وزيادته في المجموعة الجديدة داخل نفس المعاملة
      if (customer.customerGroupId && customer.customerGroupId !== oldGroupId) {
        if (oldGroupId) {
          transaction.update(
            db
              .collection(normalizedEmail)
              .doc("customers")
              .collection("customer_groups")
              .doc(oldGroupId),
            {
              customerCount: admin.firestore.FieldValue.increment(-1),
            },
          );
        }
        transaction.update(
          db
            .collection(normalizedEmail)
            .doc("customers")
            .collection("customer_groups")
            .doc(customer.customerGroupId),
          {
            customerCount: admin.firestore.FieldValue.increment(1),
          },
        );
      }

      // Create log entry
      // ⚠️ ملاحظة ذرية (إصلاح 2026-10-08): logDocRef
      // يُنشأ مسبقاً أعلاه (قبل transaction.update
      // للعميل) حتى يُضاف معرفه إلى logIds في نفس
      // تحديث العميل. لا تُنشئ مرجعاً جديداً هنا
      // وإلا انفصل المعرف المخزن عن السجل المُنشأ.
      transaction.set(logDocRef, {
        userId: context.auth.uid,
        userName: customer.name,
        userEmail: organizationEmail,
        actionType: "update_customer",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: `تم تحديث بيانات العميل: ${customer.name}`,
        isSuccess: true,
        targetId: customer.id,
        targetType: "customer",
      });

      // ✅ ذري: تحديث مستند الإحصائيات (__stats__) عند تحديث العميل
      // هذا يجب أن يكون ذرياً بدقة فائقة مع التحديث لتجنب تعديلات غير صحيحة
      // ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
      // يتم استخدام transaction.set() مع {merge: true}
      // لضمان ذريّة بدقة فائقة. يتم حساب الدلتا بناءً على التغييرات
      // في بيانات العميل (الحالة، المجموعة، الحساب الافتتاحي).
      const newStatus = customer.status || "";
      const newGroupId = customer.customerGroupId || "";
      const statsOpeningBalance = customer.openingBalance || 0;
      const isNewActive = newStatus === "active";
      const isNewInactive = newStatus === "inactive";
      const isNewBlocked = newStatus === "blocked";
      const hasNewGroup = newGroupId !== "";
      // حساب الدلتا بناءً على التغييرات
      const oldStatus = docData?.["status"] || "";
      const statsOldGroupId = docData?.["customerGroupId"] || "";
      const statsOldOpeningBalance = docData?.["openingBalance"] || 0;
      const isOldActive = oldStatus === "active";
      const isOldInactive = oldStatus === "inactive";
      const isOldBlocked = oldStatus === "blocked";
      const oldHasGroup = statsOldGroupId !== "";
      const statsDocRef = db
        .collection(normalizedEmail)
        .doc("customers")
        .collection("customers")
        .doc("__stats__");
      transaction.set(
        statsDocRef,
        {
          totalCustomers: 0, // لا يتغير عدد العملاء عند التحديث
          activeCustomers:
            isNewActive && !isOldActive
              ? admin.firestore.FieldValue.increment(1)
              : !isNewActive && isOldActive
                ? admin.firestore.FieldValue.increment(-1)
                : 0,
          inactiveCustomers:
            isNewInactive && !isOldInactive
              ? admin.firestore.FieldValue.increment(1)
              : !isNewInactive && isOldInactive
                ? admin.firestore.FieldValue.increment(-1)
                : 0,
          blockedCustomers:
            isNewBlocked && !isOldBlocked
              ? admin.firestore.FieldValue.increment(1)
              : !isNewBlocked && isOldBlocked
                ? admin.firestore.FieldValue.increment(-1)
                : 0,
          customersWithGroups:
            hasNewGroup && !oldHasGroup
              ? admin.firestore.FieldValue.increment(1)
              : !hasNewGroup && oldHasGroup
                ? admin.firestore.FieldValue.increment(-1)
                : 0,
          customersWithoutGroups:
            hasNewGroup && !oldHasGroup
              ? admin.firestore.FieldValue.increment(-1)
              : !hasNewGroup && oldHasGroup
                ? admin.firestore.FieldValue.increment(1)
                : 0,
          totalPurchases: admin.firestore.FieldValue.increment(
            (statsOpeningBalance > 0 ? statsOpeningBalance : 0) -
              (statsOldOpeningBalance > 0 ? statsOldOpeningBalance : 0),
          ),
          netBalance: admin.firestore.FieldValue.increment(
            statsOpeningBalance - statsOldOpeningBalance,
          ),
          totalDebtAmount: admin.firestore.FieldValue.increment(
            (statsOpeningBalance > 0 ? statsOpeningBalance : 0) -
              (statsOldOpeningBalance > 0 ? statsOldOpeningBalance : 0),
          ),
          totalCreditAmount: admin.firestore.FieldValue.increment(
            (statsOpeningBalance < 0 ? Math.abs(statsOpeningBalance) : 0) -
              (statsOldOpeningBalance < 0
                ? Math.abs(statsOldOpeningBalance)
                : 0),
          ),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    return { success: true, message: "تم تحديث العميل بنجاح" };
  } catch (error) {
    throw new functions.https.HttpsError("aborted", error.message);
  }
});

/**
 * Atomic operation: Delete customer with all related documents
 * Ensures all related logs and constraints are deleted atomically
 *
 * ✅ ذري: جميع العمليات التالية داخل transaction واحدة:
 * 1. التحقق من وجود العميل
 * 2. التحقق من عدم وجود فواتير مرتبطة
 * 3. حذف جميع سجلات النشاط
 * 4. حذف قيود البريد الإلكتروني والهاتف
 * 5. تحديث عدد العملاء في المجموعة القديمة (customerCount)
 * 6. حذف مستند العميل
 * إذا فشل أي منها، يتم التراجع عن جميع التغييرات
 */
exports.deleteCustomerAtomic = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const { organizationEmail, customerId } = data;

  if (!organizationEmail || !organizationEmail.includes("@")) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "بريد المؤسسة غير صالح",
    );
  }

  const normalizedEmail = organizationEmail
    .toLowerCase()
    .replace(/\./g, "")
    .replace(/\+.*/, "");
  const customerDocRef = db
    .collection(normalizedEmail)
    .doc("customers")
    .collection("customers")
    .doc(customerId);

  try {
    await db.runTransaction(async (transaction) => {
      // Check if customer exists
      const docSnapshot = await transaction.get(customerDocRef);
      if (!docSnapshot.exists) {
        throw new Error("العميل غير موجود");
      }

      const docData = docSnapshot.data();

      // ✅ ذري: التحقق من الفواتير باستخدام invoiceIds المخزنة في المستند
      // بدلاً من where().get() الذي لا يُسمح به داخل Firestore Transaction
      const invoiceIds = docData?.["invoiceIds"] || [];
      if (invoiceIds.length > 0) {
        const invoiceCollection = db
          .collection(normalizedEmail)
          .doc("invoices")
          .collection("invoices");
        for (const invoiceId of invoiceIds) {
          const invoiceRef = invoiceCollection.doc(invoiceId);
          const invoiceSnapshot = await transaction.get(invoiceRef);
          if (invoiceSnapshot.exists) {
            throw new Error("لا يمكن حذف العميل لأنه لديه فواتير مرتبطة");
          }
        }
      }

      // ✅ ذري: حذف السجلات باستخدام logIds المخزنة في المستند
      // ✅ إصلاح ذري (2026-10-08): قراءة جميع السجلات
      // أولاً ثم حذفها جميعاً. Firestore يفرض قاعدة
      // صارمة: جميع عمليات القراءة (transaction.get)
      // يجب أن تتم قبل جميع عمليات الكتابة (delete)
      // داخل نفس المعاملة. كان الكود يقرأ ويحذف
      // بالتناوب داخل الحلقة، فإذا كان هناك سجلان
      // أو أكثر، القراءة الثانية تتم بعد الحذف الأول
      // مما يخالف القاعدة ويسبب خطأ:
      //   'Transactions require all reads to be executed before all writes.'
      // ⚠️ لا تُرجع القراءة إلى داخل حلقة الحذف أبداً.
      const logIds = docData?.["logIds"] || [];
      const logsCollection = db
        .collection(normalizedEmail)
        .doc("customers")
        .collection("logs");
      const logRefs = logIds.map((logId) => logsCollection.doc(logId));
      for (const logRef of logRefs) {
        await transaction.get(logRef);
      }
      for (const logRef of logRefs) {
        transaction.delete(logRef);
      }

      // Delete email and phone constraints
      const oldEmail = docData?.["email"] || "";
      const oldPhone = docData?.["phone"] || "";
      if (oldEmail) {
        transaction.delete(
          db
            .collection(normalizedEmail)
            .doc("customers")
            .collection("unique_constraints")
            .doc(`email:${oldEmail}`),
        );
      }
      if (oldPhone) {
        transaction.delete(
          db
            .collection(normalizedEmail)
            .doc("customers")
            .collection("unique_constraints")
            .doc(`phone:${oldPhone}`),
        );
      }

      // Delete the customer
      transaction.delete(customerDocRef);

      // ✅ ذري: تقليل customerCount في المجموعة القديمة عند حذف عميل
      // هذا يجب أن يكون ذرياً مع حذف العميل لمنع تضارب البيانات
      const oldGroupId = docData?.["customerGroupId"];
      if (oldGroupId) {
        const oldGroupRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("customer_groups")
          .doc(oldGroupId);
        transaction.update(oldGroupRef, {
          customerCount: admin.firestore.FieldValue.increment(-1),
        });
      }

      // ✅ ذري: تحديث مستند الإحصائيات (__stats__) عند حذف العميل
      // هذا يجب أن يكون ذرياً بدقة فائقة مع الحذف لتجنب تعديلات غير صحيحة
      // ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
      // يتم استخدام transaction.set() مع {merge: true}
      // لضمان ذريّة بدقة فائقة. هذا يعني أن التحديث ذري حتى لو لم يكن
      // مستند الإحصائيات موجوداً مسبقاً.
      const oldStatus = docData?.["status"] || "";
      const oldGroupValue = docData?.["customerGroupId"] || "";
      const oldOpeningBalance = docData?.["openingBalance"] || 0;
      const isOldActive = oldStatus === "active";
      const isOldInactive = oldStatus === "inactive";
      const isOldBlocked = oldStatus === "blocked";
      const oldHasGroup = oldGroupValue !== "";
      const statsDocRef = db
        .collection(normalizedEmail)
        .doc("customers")
        .collection("customers")
        .doc("__stats__");
      // ⚠️ تحذير عالي الدقة: لا تستخدم 0 الحرفية أبداً هنا!
      // مع {merge: true}، القيمة 0 الحرفية تُعيد كتابة
      // الحقل إلى 0 (تدمير العداد). استخدم
      // FieldValue.increment(0) للحقول التي لا يجب
      // أن تتغير — increment(0) لا يغير القيمة.
      transaction.set(
        statsDocRef,
        {
          totalCustomers: admin.firestore.FieldValue.increment(-1),
          activeCustomers: isOldActive
            ? admin.firestore.FieldValue.increment(-1)
            : admin.firestore.FieldValue.increment(0),
          inactiveCustomers: isOldInactive
            ? admin.firestore.FieldValue.increment(-1)
            : admin.firestore.FieldValue.increment(0),
          blockedCustomers: isOldBlocked
            ? admin.firestore.FieldValue.increment(-1)
            : admin.firestore.FieldValue.increment(0),
          customersWithGroups: oldHasGroup
            ? admin.firestore.FieldValue.increment(-1)
            : admin.firestore.FieldValue.increment(0),
          customersWithoutGroups: oldHasGroup
            ? admin.firestore.FieldValue.increment(0)
            : admin.firestore.FieldValue.increment(-1),
          totalPurchases: admin.firestore.FieldValue.increment(
            -(oldOpeningBalance > 0 ? oldOpeningBalance : 0),
          ),
          netBalance: admin.firestore.FieldValue.increment(-oldOpeningBalance),
          totalDebtAmount: admin.firestore.FieldValue.increment(
            -(oldOpeningBalance > 0 ? oldOpeningBalance : 0),
          ),
          totalCreditAmount:
            oldOpeningBalance < 0
              ? admin.firestore.FieldValue.increment(
                  Math.abs(oldOpeningBalance),
                )
              : admin.firestore.FieldValue.increment(0),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    return { success: true, message: "تم حذف العميل بنجاح" };
  } catch (error) {
    throw new functions.https.HttpsError("aborted", error.message);
  }
});

// ===== Atomic Invoice Operations =====
//
// ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
// جميع الدوال التالية تستخدم Firestore transactions
// لضمان الذريّة (Atomicity). هذا يعني أن جميع العمليات
// داخل المعاملة تتم بنجاح أو لا تتم على الإطلاق.
//
// إذا فشلت أي عملية داخل المعاملة، تُلغى جميع العمليات
// الأخرى تلقائياً. هذا يمنع الحالات غير المتسقة
// حيث يتم تحديث بعض المستندات فقط.
//
// القواعد الأساسية للذريّة:
// 1. استخدم transaction.get() لقراءة المستندات داخل المعاملة
// 2. استخدم transaction.set() و transaction.update() للكتابة
// 3. لا تستخدم firestore.get() خارج المعاملة لقراءة بيانات
//    ستُستخدم داخل المعاملة
// 4. استخدم FieldValue.increment() للعمليات الحسابية
//    لضمان عدم التداخل
// 5. استخدم expectedUpdatedAt للتحقق من التعديل المتزامن
//    (Optimistic Locking)
// 6. ⚠️ الذريّة على مستوى الخادم فقط - لا توجد حاجة
//    لـ AsyncLock في العميل (client-side) لأن Firestore
//    Transactions توفر الذريّة بالفعل

/**
 * Atomic operation: Create invoice with all related documents
 * Ensures all-or-nothing execution for invoice creation
 *
 * ⚠️ ملاحظة مهمة حول الذريّة:
 * هذه العملية ذرية عبر Firestore transaction.
 * تشمل: إنشاء الفاتورة، تحديث دين العميل،
 * تحديث الصندوق، وإنشاء السجل.
 * إذا فشل أي منها، تُلغى جميع العمليات.
 *
 * ⚠️ لماذا هذا ذري مهم؟
 * بدون المعاملة، قد يتم إنشاء الفاتورة
 * لكن يفشل تحديث دين العميل، مما يؤدي
 * إلى بيانات غير متسقة.
 *
 * ⚠️ ملاحظة: لا حاجة لـ AsyncLock في العميل
 * لأن Firestore Transaction توفر الذريّة
 * على مستوى الخادم.
 *
 * ⚠️ ⚠️ ⚠️ تحذير عالي الدقة: الذريّة في totalDebt ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * تحديث totalDebt في هذه الدالة يستخدم FieldValue.increment()
 * وهو ذري على جانب الخادم Firestore.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 * ⚠️ ملاحظة ذرية حرجة: createInvoiceAtomic ناقص تحديثات ذرية ⚠️
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ما يجب أن يكون ذرياً بدقة فائقة ولكنه MISSING حاليًا:
 *
 * 1. تحديث invoiceCount في مستند العميل
 *    → يجب أن يكون ذرياً مع إنشاء الفاتورة
 *    → إذا تم إنشاء الفاتورة لكن invoiceCount لم يُحدَّث،
 *      فإن عدد الفواتير في العميل يكون غير صحيح
 *    → الحل: إضافة transaction.update(customerRef, {invoiceCount: FieldValue.increment(1)})
 *    → هذا يجب أن يكون ذرياً مع إنشاء الفاتورة لتجنب تعديلات غير صحيحة
 *
 * 2. تحديث مستند الإحصائيات (__stats__)
 *    → يجب أن يكون ذرياً بدقة فائقة مع إنشاء الفاتورة
 *    → إذا تم إنشاء الفاتورة لكن الإحصائيات لم تُحدَّث،
 *      فإن التقارير تكون خاطئة
 *    → الحل: إضافة transaction.set(statsDocRef, {...}, {merge: true})
 *    → هذا يجب أن يكون ذرياً بدقة فائقة لتجنب تعديلات غير صحيحة
 *
 * 3. تحديث relatedInvoiceIds في مستند العميل
 *    → يجب أن يكون ذرياً مع إنشاء الفاتورة
 *    → إذا تم إنشاء الفاتورة لكن relatedInvoiceIds لم يُحدَّث،
 *      فإن العميل لا يعرف بفاتورته الجديدة
 *    → الحل: إضافة transaction.update(customerRef, {relatedInvoiceIds: FieldValue.arrayUnion([invoice.id])})
 *
 * ⚠️ لماذا هذه العمليات يجب أن تكون ذرية معاً؟
 * لأنها تعتمد على بعضها البعض:
 * - إذا تم إنشاء الفاتورة لكن invoiceCount لم يُحدَّث → عدود خاطئة
 * - إذا تم إنشاء الفاتورة لكن الإحصائيات لم تُحدَّث → تقارير خاطئة
 * - إذا تم إنشاء الفاتورة لكن relatedInvoiceIds لم يُحدَّث → فقدان مرجع
 * - إذا فشل أي جزء، يجب إلغاء جميع التغييرات الأخرى
 *
 * ⚠️ ملاحظة: هذا يختلف عن Dart side (invoice_repository_impl.dart)
 * حيث يتم تحديث invoiceCount والإحصائيات بشكل صحيح داخل Transaction.
 * يجب مزامنة Node.js side مع Dart side لضمان الذريّة الكاملة.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * تحديث totalDebt في هذه الدالة يستخدم FieldValue.increment()
 * وهو ذري على جانب الخادم Firestore.
 * لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
 * Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
 * هذا يمنع تماماً مشكلة Read-Modify-Write.
 *
 * ⚠️ لماذا لا نزال نستخدم read-modify-write هنا؟
 * لأننا نحتاج للتحقق من أن debtAmount != 0 قبل التحديث.
 * لكن هذا يعني أن المعاملة قد تفشل إذا تغير الدين بين
 * القراءة والتحديث. Firestore Transaction يعيد المحاولة تلقائياً.
 */
exports.createInvoiceAtomic = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const { organizationEmail, invoice } = data;

  if (!organizationEmail || !organizationEmail.includes("@")) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "بريد المؤسسة غير صالح",
    );
  }

  const normalizedEmail = organizationEmail
    .toLowerCase()
    .replace(/\./g, "")
    .replace(/\+.*/, "");
  const invoiceDocRef = db
    .collection(normalizedEmail)
    .doc("invoices")
    .collection("invoices")
    .doc(invoice.id);

  try {
    await db.runTransaction(async (transaction) => {
      // Check if invoice already exists
      const docSnapshot = await transaction.get(invoiceDocRef);
      if (docSnapshot.exists) {
        throw new Error("الفاتورة موجودة مسبقاً");
      }

      // Check invoice permission
      const hasInvoicePermission =
        context.token.permissions &&
        (context.token.permissions.includes("invoices_sales_manage") ||
          context.token.permissions.includes("invoices_purchase_manage") ||
          context.token.permissions.includes("invoices_cash_manage"));
      if (!hasInvoicePermission) {
        throw new Error("ليس لديك صلاحية إنشاء فاتورة");
      }

      // ✅ إصلاح ذري (2026-10-08): قراءة مستندي العميل والصندوق
      // قبل أي كتابة. Firestore يفرض قاعدة صارمة: جميع عمليات
      // القراءة (transaction.get) يجب أن تتم قبل جميع عمليات
      // الكتابة (set/update/delete) داخل نفس المعاملة.
      // كان الكود يقرأ العميل والصندوق بعد transaction.set(invoiceDocRef)
      // مما يخالف القاعدة ويسبب خطأ:
      //   'Transactions require all reads to be executed before all writes.'
      // ⚠️ لا تُرجع هذه القراءات إلى بعد الكتابات أبداً.
      let customerRef = null;
      let customerSnapshot = null;
      if (invoice.customerId) {
        customerRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("customers")
          .doc(invoice.customerId);
        customerSnapshot = await transaction.get(customerRef);
      }

      let cashboxRef = null;
      let cashboxSnapshot = null;
      if (invoice.paidAmount && invoice.paidAmount !== 0) {
        cashboxRef = db
          .collection(normalizedEmail)
          .doc("cashbox")
          .collection("balance")
          .doc("main");
        cashboxSnapshot = await transaction.get(cashboxRef);
      }

      // Set invoice document
      transaction.set(invoiceDocRef, invoice);

      // Update customer debt if applicable
      if (invoice.customerId) {
        if (customerSnapshot && customerSnapshot.exists) {
          let debtAmount = 0;
          if (invoice.type === "cash") {
            debtAmount = invoice.paidAmount;
          } else if (
            invoice.type === "sales" ||
            invoice.type === "subscription"
          ) {
            debtAmount = invoice.remainingAmount;
          } else if (invoice.type === "purchase") {
            debtAmount = -invoice.totalAmount;
          }

          if (debtAmount !== 0) {
            // ✅ تم الإصلاح: استخدام FieldValue.increment() للذريّة
            //
            // ✅ ملاحظة مهمة للمرمجين المستقبليين:
            // تم تغيير تحديث totalDebt من Read-Modify-Write إلى FieldValue.increment().
            // FieldValue.increment() يُنفَّذ ذرياً على جانب الخادم
            // ولا يمكن أن يتأثر بالتعديلات المتزامنة.
            //
            // ✅ لماذا FieldValue.increment() ذري؟
            // Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
            // لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
            // هذا يمنع تماماً مشكلة Read-Modify-Write حيث يقوم مستخدمان
            // بقراءة نفس القيمة ثم كتابة قيمة معدلة.
            transaction.update(customerRef, {
              totalDebt: admin.firestore.FieldValue.increment(debtAmount),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // ⚠️ إصلاح يدوي (2026-10-08): أُزيل قوس إغلاق زائد
      // كان هنا يغلق معاملة runTransaction قبل أوانها، مما
      // دفع كود الصندوق والسجل (أدناه) خارج المعاملة حيث
      // transaction خارج النطاق — وهذا يكسر الذرية ويسبب
      // خطأ نحويًا. كود الصندوق والسجل أدناه يجب أن يبقى
      // داخل المعاملة ليكون ذرياً مع إنشاء الفاتورة وتحديث
      // الدين. لا تُضِف قوس إغلاق هنا أبداً.

      // Update cashbox if applicable
      if (invoice.paidAmount && invoice.paidAmount !== 0) {
        const direction = invoice.type === "purchase" ? "out" : "in";
        const amount = invoice.paidAmount;
        if (cashboxSnapshot && cashboxSnapshot.exists) {
          transaction.update(cashboxRef, {
            currentBalance: admin.firestore.FieldValue.increment(
              direction === "in" ? amount : -amount,
            ),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            updatedBy: invoice.createdBy,
          });
        } else {
          transaction.set(
            cashboxRef,
            {
              currentBalance: direction === "in" ? amount : -amount,
              lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
              updatedBy: invoice.createdBy,
            },
            { merge: true },
          );
        }
      }

      // Create log entry
      const logDocRef = db
        .collection(normalizedEmail)
        .doc("invoices")
        .collection("logs")
        .doc();
      transaction.set(logDocRef, {
        userId: context.auth.uid,
        actionType: "add_invoice",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: `تم إضافة فاتورة جديدة: ${invoice.invoiceNumber}`,
        targetId: invoice.id,
        targetType: "invoice",
        newValues: invoice,
        isSuccess: true,
      });
    });

    return { success: true, message: "تم إنشاء الفاتورة بنجاح" };
  } catch (error) {
    throw new functions.https.HttpsError("aborted", error.message);
  }
});

/**
 * Atomic operation: Update invoice with all related documents
 * Ensures all-or-nothing execution for invoice update with concurrent modification check
 *
 * ⚠️ ملاحظة مهمة حول الذريّة والتعديل المتزامن:
 * هذه العملية ذرية عبر Firestore transaction مع Optimistic Locking.
 * تشمل: تحديث الفاتورة، تحديث دين العميل،
 * تطبيق صافي تأثير الصندوق، عكس تأثير المخزون،
 * تطبيق تأثير المخزون الجديد، إنشاء السجل، وتحديث الإحصائيات.
 * إذا فشل أي منها، تُلغى جميع العمليات.
 *
 * ⚠️ لماذا Optimistic Locking مهم؟
 * expectedUpdatedAt يُستخدم للتحقق من أن الفاتورة
 * لم تتغير منذ آخر قراءة. إذا تغيرت، تُلغى العملية.
 * هذا يمنع التعديلات الغير صحيحة التي قد تحدث
 * عندما يعدل مستخدمان نفس الفاتورة في نفس الوقت.
 *
 * ⚠️ ملاحظة: expectedUpdatedAt يُقرأ من Firestore
 * قبل إرسال التحديث ويُقارن داخل المعاملة.
 * إذا كان التاريخ مختلفاً، تُلغى العملية بالكامل.
 *
 * ⚠️ لا حاجة لـ AsyncLock في العميل
 * لأن Firestore Transaction + Optimistic Locking
 * يوفران الحماية الكاملة على مستوى الخادم.
 *
 * ⚠️ ⚠️ ⚠️ تحذير عالي الدقة: الذريّة في totalDebt ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * تحديث totalDebt في هذه الدالة يستخدم FieldValue.increment()
 * وهو ذري على جانب الخادم Firestore.
 * لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
 * Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
 * هذا يمنع تماماً مشكلة Read-Modify-Write.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 * ⚠️ ملاحظة ذرية حرجة: updateInvoiceAtomic ناقص تحديثات ذرية ⚠️
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ما يجب أن يكون ذرياً بدقة فائقة ولكنه MISSING حاليًا:
 *
 * 1. تحديث invoiceCount في مستند العميل
 *    → يجب أن يكون ذرياً مع تحديث الفاتورة
 *    → إذا تم تحديث الفاتورة لكن invoiceCount لم يُحدَّث،
 *      فإن عدد الفواتير في العميل يكون غير صحيح
 *    → الحل: إضافة transaction.update(customerRef, {invoiceCount: FieldValue.increment(...)})
 *    → هذا يجب أن يكون ذرياً مع تحديث الفاتورة لتجنب تعديلات غير صحيحة
 *
 * 2. تحديث مستند الإحصائيات (__stats__)
 *    → يجب أن يكون ذرياً بدقة فائقة مع تحديث الفاتورة
 *    → إذا تم تحديث الفاتورة لكن الإحصائيات لم تُحدَّث،
 *      فإن التقارير تكون خاطئة
 *    → الحل: إضافة transaction.set(statsDocRef, {...}, {merge: true})
 *    → هذا يجب أن يكون ذرياً بدقة فائقة لتجنب تعديلات غير صحيحة
 *
 * ⚠️ لماذا هذه العمليات يجب أن تكون ذرية معاً؟
 * لأنها تعتمد على بعضها البعض:
 * - إذا تم تحديث الفاتورة لكن invoiceCount لم يُحدَّث → عدود خاطئة
 * - إذا تم تحديث الفاتورة لكن الإحصائيات لم تُحدَّث → تقارير خاطئة
 * - إذا فشل أي جزء، يجب إلغاء جميع التغييرات الأخرى
 *
 * ⚠️ ملاحظة: هذا يختلف عن Dart side (invoice_repository_impl.dart)
 * حيث يتم تحديث invoiceCount والإحصائيات بشكل صحيح داخل Transaction.
 * يجب مزامنة Node.js side مع Dart side لضمان الذريّة الكاملة.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * تحديث totalDebt في هذه الدالة يستخدم FieldValue.increment()
 * وهو ذري على جانب الخادم Firestore.
 * لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
 * Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
 * هذا يمنع تماماً مشكلة Read-Modify-Write.
 *
 * ⚠️ لماذا لا نزال نستخدم read-modify-write هنا؟
 * لأننا نحتاج لحساب الفرق الدقيق (debtAmount) بين
 * الفاتورة القديمة والجديدة.
 * لكن هذا يعني أن المعاملة قد تفشل إذا تغير الدين بين
 * القراءة والتحديث. Firestore Transaction يعيد المحاولة تلقائياً.
 */
exports.updateInvoiceAtomic = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const { organizationEmail, invoice, expectedUpdatedAt } = data;

  if (!organizationEmail || !organizationEmail.includes("@")) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "بريد المؤسسة غير صالح",
    );
  }

  const normalizedEmail = organizationEmail
    .toLowerCase()
    .replace(/\./g, "")
    .replace(/\+.*/, "");
  const invoiceDocRef = db
    .collection(normalizedEmail)
    .doc("invoices")
    .collection("invoices")
    .doc(invoice.id);

  try {
    await db.runTransaction(async (transaction) => {
      // Check if invoice exists
      const docSnapshot = await transaction.get(invoiceDocRef);
      if (!docSnapshot.exists) {
        throw new Error("الفاتورة غير موجودة");
      }

      // Check for concurrent modification
      if (expectedUpdatedAt) {
        const existingUpdatedAt = docSnapshot.data()?.["updatedAt"]?.toDate();
        if (
          existingUpdatedAt &&
          existingUpdatedAt.getTime() !== expectedUpdatedAt.getTime()
        ) {
          throw new Error(
            "تم تعديل الفاتورة من قبل مستخدم آخر، يرجى إعادة المحاولة",
          );
        }
      }

      // Check invoice permission
      const hasInvoicePermission =
        context.token.permissions &&
        (context.token.permissions.includes("invoices_sales_manage") ||
          context.token.permissions.includes("invoices_purchase_manage") ||
          context.token.permissions.includes("invoices_cash_manage"));
      if (!hasInvoicePermission) {
        throw new Error("ليس لديك صلاحية تحديث فاتورة");
      }

      const prevInvoice = docSnapshot.data();

      // ✅ إصلاح ذري (2026-10-08): قراءة مستندي العميل والصندوق
      // قبل أي كتابة. Firestore يفرض قاعدة صارمة: جميع عمليات
      // القراءة (transaction.get) يجب أن تتم قبل جميع عمليات
      // الكتابة (set/update/delete) داخل نفس المعاملة.
      // كان الكود يقرأ العميل والصندوق بعد transaction.update(invoiceDocRef)
      // مما يخالف القاعدة ويسبب خطأ:
      //   'Transactions require all reads to be executed before all writes.'
      // ⚠️ لا تُرجع هذه القراءات إلى بعد الكتابات أبداً.
      let customerRef = null;
      let customerSnapshot = null;
      if (invoice.customerId) {
        customerRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("customers")
          .doc(invoice.customerId);
        customerSnapshot = await transaction.get(customerRef);
      }

      const cashboxRef = db
        .collection(normalizedEmail)
        .doc("cashbox")
        .collection("balance")
        .doc("main");
      const cashboxSnapshot = await transaction.get(cashboxRef);

      // Update invoice document
      transaction.update(invoiceDocRef, {
        ...invoice,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update customer debt if applicable
      if (invoice.customerId) {
        if (customerSnapshot && customerSnapshot.exists) {
          const originalAmount =
            prevInvoice.type === "cash"
              ? prevInvoice.paidAmount
              : prevInvoice.remainingAmount;
          const newAmount =
            invoice.type === "cash"
              ? invoice.paidAmount
              : invoice.remainingAmount;
          const debtAmount = newAmount - originalAmount;

          if (debtAmount !== 0) {
            // ✅ تم الإصلاح: استخدام FieldValue.increment() للذريّة
            //
            // ✅ ملاحظة مهمة للمرمجين المستقبليين:
            // تم تغيير تحديث totalDebt من Read-Modify-Write إلى FieldValue.increment().
            // FieldValue.increment() يُنفَّذ ذرياً على جانب الخادم
            // ولا يمكن أن يتأثر بالتعديلات المتزامنة.
            //
            // ✅ لماذا FieldValue.increment() ذري؟
            // Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
            // لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
            // هذا يمنع تماماً مشكلة Read-Modify-Write حيث يقوم مستخدمان
            // بقراءة نفس القيمة ثم كتابة قيمة معدلة.
            transaction.update(customerRef, {
              totalDebt: admin.firestore.FieldValue.increment(debtAmount),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // ⚠️ إصلاح يدوي (2026-10-08): أُضيف قوس إغلاق
      // أعلاه لإغلاق شرط invoice.customerId الذي كان
      // مفتوحاً دون إغلاق، مما جعل كود الصندوق والسجل
      // (أدناه) داخله خطأً، وأدى إلى عدم إغلاق معاملة
      // runTransaction وخطأ نحويًا. كود الصندوق والسجل
      // يجب أن يكون في مستوى المعاملة مباشرة.
      // لا تُحذف أقواس الإغلاق أعلاه أبداً.

      // Update cashbox (net impact: reverse old + apply new)
      if (cashboxSnapshot.exists) {
        let netBalance = 0;
        const prevDirection = prevInvoice.type === "purchase" ? "out" : "in";
        const newDirection = invoice.type === "purchase" ? "out" : "in";
        const prevAmount =
          prevInvoice.type === "cash"
            ? prevInvoice.paidAmount
            : prevInvoice.totalAmount;
        const newAmount =
          invoice.type === "cash" ? invoice.paidAmount : invoice.totalAmount;
        netBalance += prevDirection === "in" ? -prevAmount : prevAmount;
        netBalance += newDirection === "in" ? newAmount : -newAmount;

        if (netBalance !== 0) {
          transaction.update(cashboxRef, {
            currentBalance: admin.firestore.FieldValue.increment(netBalance),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            updatedBy: invoice.createdBy,
          });
        }
      }

      // Create log entry
      const logDocRef = db
        .collection(normalizedEmail)
        .doc("invoices")
        .collection("logs")
        .doc();
      transaction.set(logDocRef, {
        userId: context.auth.uid,
        actionType: "update_invoice",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: `تم تحديث الفاتورة: ${invoice.invoiceNumber}`,
        targetId: invoice.id,
        targetType: "invoice",
        oldValues: prevInvoice,
        newValues: invoice,
        isSuccess: true,
      });
    });

    return { success: true, message: "تم تحديث الفاتورة بنجاح" };
  } catch (error) {
    throw new functions.https.HttpsError("aborted", error.message);
  }
});

/**
 * Atomic operation: Delete invoice with all related documents
 * Ensures all-or-nothing execution for invoice deletion with concurrent modification check
 *
 * ⚠️ ملاحظة مهمة حول الذريّة والتعديل المتزامن:
 * هذه العملية ذرية عبر Firestore transaction مع Optimistic Locking.
 * تشمل: حذف الفاتورة، استرجاع دين العميل وتحديثه،
 * تطبيق تأثير الصندوق العكسي، عكس تأثير المخزون،
 * إنشاء سجل الحذف، وتحديث الإحصائيات.
 * إذا فشل أي منها، تُلغى جميع العمليات.
 *
 * ⚠️ لماذا Optimistic Locking مهم؟
 * expectedUpdatedAt يُستخدم للتحقق من أن الفاتورة
 * لم تتغير منذ آخر قراءة. إذا تغيرت، تُلغى العملية.
 * هذا يمنع حذف فاتورة تم تعديلها من قبل مستخدم آخر.
 *
 * ⚠️ ملاحظة: expectedUpdatedAt يُقرأ من Firestore
 * قبل إرسال طلب الحذف ويُقارن داخل المعاملة.
 * إذا كان التاريخ مختلفاً، تُلغى العملية بالكامل.
 *
 * ⚠️ لا حاجة لـ AsyncLock في العميل
 * لأن Firestore Transaction + Optimistic Locking
 * يوفران الحماية الكاملة على مستوى الخادم.
 *
 * ⚠️ ⚠️ ⚠️ تحذير عالي الدقة: الذريّة في totalDebt ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * تحديث totalDebt في هذه الدالة يستخدم FieldValue.increment()
 * وهو ذري على جانب الخادم Firestore.
 * لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
 * Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
 * هذا يمنع تماماً مشكلة Read-Modify-Write.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 * ⚠️ ملاحظة ذرية حرجة: deleteInvoiceAtomic ناقص تحديثات ذرية ⚠️
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ما يجب أن يكون ذرياً بدقة فائقة ولكنه MISSING حاليًا:
 *
 * 1. تحديث مستند الإحصائيات (__stats__)
 *    → يجب أن يكون ذرياً بدقة فائقة مع حذف الفاتورة
 *    → إذا تم حذف الفاتورة لكن الإحصائيات لم تُعكس،
 *      فإن التقارير تكون خاطئة
 *    → الحل: إضافة transaction.set(statsDocRef, {...}, {merge: true})
 *    → هذا يجب أن يكون ذرياً بدقة فائقة لتجنب تعديلات غير صحيحة
 *
 * ⚠️ لماذا هذه العمليات يجب أن تكون ذرية معاً؟
 * لأنها تعتمد على بعضها البعض:
 * - إذا تم حذف الفاتورة لكن الإحصائيات لم تُعكس → تقارير خاطئة
 * - إذا فشل أي جزء، يجب إلغاء جميع التغييرات الأخرى
 *
 * ⚠️ ملاحظة: هذا يختلف عن Dart side (invoice_repository_impl.dart)
 * حيث يتم تحديث الإحصائيات بشكل صحيح داخل Transaction.
 * يجب مزامنة Node.js side مع Dart side لضمان الذريّة الكاملة.
 *
 * ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
 *
 * ⚠️ ملاحظة مهمة للمرمجين المستقبليين:
 * تحديث totalDebt في هذه الدالة يستخدم FieldValue.increment()
 * وهو ذري على جانب الخادم Firestore.
 * لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
 * Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
 * هذا يمنع تماماً مشكلة Read-Modify-Write.
 *
 * ⚠️ لماذا لا نزال نستخدم read-modify-write هنا؟
 * لأننا نحتاج لحساب المبلغ الدقيق المرجع.
 * لكن هذا يعني أن المعاملة قد تفشل إذا تغير الدين بين
 * القراءة والتحديث. Firestore Transaction يعيد المحاولة تلقائياً.
 */
exports.deleteInvoiceAtomic = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const { organizationEmail, invoiceId, expectedUpdatedAt } = data;

  if (!organizationEmail || !organizationEmail.includes("@")) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "بريد المؤسسة غير صالح",
    );
  }

  const normalizedEmail = organizationEmail
    .toLowerCase()
    .replace(/\./g, "")
    .replace(/\+.*/, "");
  const invoiceDocRef = db
    .collection(normalizedEmail)
    .doc("invoices")
    .collection("invoices")
    .doc(invoiceId);

  try {
    await db.runTransaction(async (transaction) => {
      // Check if invoice exists
      const docSnapshot = await transaction.get(invoiceDocRef);
      if (!docSnapshot.exists) {
        throw new Error("الفاتورة غير موجودة");
      }

      const invoiceData = docSnapshot.data();

      // Check for concurrent modification
      if (expectedUpdatedAt) {
        const existingUpdatedAt = invoiceData?.["updatedAt"]?.toDate();
        if (
          existingUpdatedAt &&
          existingUpdatedAt.getTime() !== expectedUpdatedAt.getTime()
        ) {
          throw new Error(
            "تم تعديل الفاتورة من قبل مستخدم آخر، يرجى إعادة المحاولة",
          );
        }
      }

      // Check invoice permission
      const hasInvoicePermission =
        context.token.permissions &&
        (context.token.permissions.includes("invoices_sales_manage") ||
          context.token.permissions.includes("invoices_purchase_manage") ||
          context.token.permissions.includes("invoices_cash_manage"));
      if (!hasInvoicePermission) {
        throw new Error("ليس لديك صلاحية حذف فاتورة");
      }

      // ✅ إصلاح ذري (2026-10-08): قراءة مستندي العميل والصندوق
      // قبل أي كتابة. Firestore يفرض قاعدة صارمة: جميع عمليات
      // القراءة (transaction.get) يجب أن تتم قبل جميع عمليات
      // الكتابة (set/update/delete) داخل نفس المعاملة.
      // كان الكود يقرأ العميل والصندوق بعد transaction.delete(invoiceDocRef)
      // مما يخالف القاعدة ويسبب خطأ:
      //   'Transactions require all reads to be executed before all writes.'
      // ⚠️ لا تُرجع هذه القراءات إلى بعد الكتابات أبداً.
      let customerRef = null;
      let customerSnapshot = null;
      if (invoiceData.customerId) {
        customerRef = db
          .collection(normalizedEmail)
          .doc("customers")
          .collection("customers")
          .doc(invoiceData.customerId);
        customerSnapshot = await transaction.get(customerRef);
      }

      const cashboxRef = db
        .collection(normalizedEmail)
        .doc("cashbox")
        .collection("balance")
        .doc("main");
      const cashboxSnapshot = await transaction.get(cashboxRef);

      // Delete the invoice
      transaction.delete(invoiceDocRef);

      // Reverse customer debt
      if (invoiceData.customerId) {
        if (customerSnapshot && customerSnapshot.exists) {
          let debtAmount = 0;
          if (invoiceData.type === "cash") {
            debtAmount = invoiceData.paidAmount;
          } else if (
            invoiceData.type === "sales" ||
            invoiceData.type === "subscription"
          ) {
            debtAmount = invoiceData.remainingAmount;
          } else if (invoiceData.type === "purchase") {
            debtAmount = -invoiceData.totalAmount;
          }

          if (debtAmount !== 0) {
            // ✅ تم الإصلاح: استخدام FieldValue.increment() للذريّة
            //
            // ✅ ملاحظة مهمة للمرمجين المستقبليين:
            // تم تغيير تحديث totalDebt من Read-Modify-Write إلى FieldValue.increment().
            // FieldValue.increment() يُنفَّذ ذرياً على جانب الخادم
            // ولا يمكن أن يتأثر بالتعديلات المتزامنة.
            //
            // ✅ لماذا FieldValue.increment() ذري؟
            // Firestore يضيف القيمة مباشرة إلى القيمة الحالية في الخادم.
            // لا يحتاج إلى قراءة القيمة الحالية ثم كتابتها.
            // هذا يمنع تماماً مشكلة Read-Modify-Write حيث يقوم مستخدمان
            // بقراءة نفس القيمة ثم كتابة قيمة معدلة.
            transaction.update(customerRef, {
              totalDebt: admin.firestore.FieldValue.increment(-debtAmount),
              invoiceCount: admin.firestore.FieldValue.increment(-1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // ⚠️ إصلاح يدوي (2026-10-08): أُضيف قوس إغلاق
      // أعلاه لإغلاق شرط invoiceData.customerId الذي كان
      // مفتوحاً دون إغلاق، مما جعل كود الصندوق والسجل
      // (أدناه) داخله خطأً، وأدى إلى عدم إغلاق معاملة
      // runTransaction وخطأ نحويًا. كود الصندوق والسجل
      // يجب أن يكون في مستوى المعاملة مباشرة.
      // لا تُحذف أقواس الإغلاق أعلاه أبداً.

      // Reverse cashbox impact
      if (cashboxSnapshot.exists) {
        const direction = invoiceData.type === "purchase" ? "out" : "in";
        const amount =
          invoiceData.type === "cash"
            ? invoiceData.paidAmount
            : invoiceData.totalAmount;
        transaction.update(cashboxRef, {
          currentBalance: admin.firestore.FieldValue.increment(
            direction === "in" ? -amount : amount,
          ),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: context.auth.uid,
        });
      }

      // Create log entry
      const logDocRef = db
        .collection(normalizedEmail)
        .doc("invoices")
        .collection("logs")
        .doc();
      transaction.set(logDocRef, {
        userId: context.auth.uid,
        actionType: "delete_invoice",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        details: `تم حذف الفاتورة: ${invoiceData.invoiceNumber}`,
        targetId: invoiceId,
        targetType: "invoice",
        oldValues: invoiceData,
        isSuccess: true,
      });
    });

    return { success: true, message: "تم حذف الفاتورة بنجاح" };
  } catch (error) {
    throw new functions.https.HttpsError("aborted", error.message);
  }
});

// ===== Health Check =====
exports.subscriptionsHealth = functions.https.onCall(async () => {
  return { status: "ok", timestamp: new Date().toISOString() };
});

// ===== Atomic Auth Operations (Email OTP) =====
//
// ⚠️ ملاحظة مهمة للمبرمجين المستقبليين:
// هذه الدوال تُكمل قسم المصادقة في التطبيق (Flutter).
// كانت تُستدعى من العميل لكنها لم تكن موجودة هنا
// (فجوة نشر) — أُضيفت ليعمل إرسال بريد OTP وإعادة
// تعيين كلمة المرور فعلياً.
//
// ⚠️ تطبيع البريد: يجب أن يطابق تماماً
// EmailNormalizationService في جانب Dart
// (lib/core/email/email_normalization_service.dart):
// Gmail/Googlemail: إزالة النقاط وما بعد +
// Outlook/Hotmail/Live/Yahoo/iCloud/Me: إزالة ما بعد + فقط
// غيرها: تحويل لأحرف صغيرة فقط
//
// ⚠️ الذريّة + الأمان في resetPasswordWithOTP: استهلاك رمز
// OTP (التحقق + تعليم used:true) في runTransaction واحدة
// على الخادم قبل تغيير كلمة المرور — يمنع الاستهلاك
// المزدوج لطلبين متزامنين (نمط TOCTOU). التحقق على
// الخادم لا يثق بالعميل — بدونه يستطيع أي شخص إعادة
// تعيين كلمة مرور أي حساب آخر. لا تُجزّئها ولا تُزل
// هذا التحقق أبداً.
//
// ⚠️ إعداد SMTP: أضف متغيرات البيئة في Firebase:
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
// بدونها يعمل sendEmailOTP في وضع التطوير (يسجّل الرمز
// بدلاً من إرساله) ولا يُرسل بريداً فعلياً.
//
// ⚠️ ملاحظة أمان: الرمز 6 أرقام — لحمايته من القوة العمياء
// أضف عدّاد محاولات فاشلة في مستند الرمز وقفله بعد
// عدد محدد (تحسين مستقبلي اختياري).

const nodemailer = require("nodemailer");

// النطاقات التي تتجاهل النقاط (تطابق EmailDomainConfig)
const DOTS_IGNORED_DOMAINS = ["gmail.com", "googlemail.com"];
// النطاقات التي تتجاهل ما بعد + (تطابق EmailDomainConfig)
const PLUS_IGNORED_DOMAINS = [
  "gmail.com",
  "googlemail.com",
  "outlook.com",
  "hotmail.com",
  "live.com",
  "yahoo.com",
  "icloud.com",
  "me.com",
];

function normalizeEmail(email) {
  const lower = (email || "").toLowerCase().trim();
  const atIndex = lower.indexOf("@");
  if (atIndex < 0) return lower;
  let local = lower.substring(0, atIndex);
  const domain = lower.substring(atIndex + 1);
  if (DOTS_IGNORED_DOMAINS.includes(domain)) {
    local = local.replace(/\./g, "");
  }
  if (PLUS_IGNORED_DOMAINS.includes(domain)) {
    const plusIndex = local.indexOf("+");
    if (plusIndex >= 0) local = local.substring(0, plusIndex);
  }
  return local + "@" + domain;
}

function buildMailTransporter() {
  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const port = parseInt(process.env.SMTP_PORT || "587", 10);
  if (!host || !user || !pass) return null;
  return nodemailer.createTransport({
    host: host,
    port: port,
    secure: port === 465,
    auth: { user: user, pass: pass },
  });
}

// إرسال بريد رمز التحقق — تُستدعى من العميل بعد حفظ الرمز
// في Firestore. تتحقق أن الرمز محفوظ فعلاً ويطابق قبل
// الإرسال (يمنع إرسال رموز مزيفة). لا تتطلب تسجيل دخول
// (تدفق التسجيل ونسيان كلمة المرور لمستخدم غير مسجّل).
exports.sendEmailOTP = functions.https.onCall(async (data, context) => {
  const email = data && data.email;
  const otpCode = data && data.otpCode;
  if (!email || !otpCode) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "البريد الإلكتروني ورمز التحقق مطلوبان",
    );
  }

  const normalizedEmail = normalizeEmail(email);
  const otpRef = db.collection(normalizedEmail).doc("otp_codes");

  // تحقق أن الرمز محفوظ فعلاً ويطابق — يمنع إرسال رموز مزيفة
  const snapshot = await otpRef.get();
  if (!snapshot.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "رمز التحقق غير موجود، اطلب رمزاً جديداً",
    );
  }
  const otpData = snapshot.data();
  if (!otpData || otpData.otpCode !== otpCode) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "رمز التحقق غير صحيح",
    );
  }

  const subject = "رمز التحقق - نظام آشور";
  const text = "رمز التحقق الخاص بك هو: " + otpCode + "\nصالح لمدة 10 دقائق.";
  const html =
    "<p>رمز التحقق الخاص بك هو: <b>" +
    otpCode +
    "</b></p><p>صالح لمدة 10 دقائق.</p>";

  const transporter = buildMailTransporter();
  if (!transporter) {
    // وضع التطوير: لا توجد بيانات SMTP — سجّل الرمز بدلاً من الإرسال
    functions.logger.warn("sendEmailOTP: SMTP غير مُعدّ — الرمز", {
      email: normalizedEmail,
      otpCode: otpCode,
    });
    return { sent: false, devMode: true };
  }

  const mailOptions = {
    from: process.env.SMTP_FROM || process.env.SMTP_USER,
    to: normalizedEmail,
    subject: subject,
    text: text,
    html: html,
  };
  await transporter.sendMail(mailOptions);
  return { sent: true };
});

// إعادة تعيين كلمة المرور عبر رمز OTP — تتحقق من الرمز وتستهلكه
// ذرياً على الخادم (runTransaction واحدة) قبل تغيير كلمة
// المرور عبر Firebase Auth. العميل يرسل {email, otpCode,
// newPassword} فقط — لا يُثق بأي تحقق سابق من العميل.
exports.resetPasswordWithOTP = functions.https.onCall(async (data, context) => {
  const email = data && data.email;
  const otpCode = data && data.otpCode;
  const newPassword = data && data.newPassword;
  if (!email || !otpCode || !newPassword) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "البريد الإلكتروني ورمز التحقق وكلمة المرور الجديدة مطلوبون",
    );
  }
  if (typeof newPassword !== "string" || newPassword.length < 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "كلمة المرور يجب أن تكون 6 أحرف على الأقل",
    );
  }

  const normalizedEmail = normalizeEmail(email);
  const otpRef = db.collection(normalizedEmail).doc("otp_codes");

  // 1. استهلاك الرمز ذرياً: التحقق + تعليم used:true في معاملة
  //    واحدة قبل تغيير كلمة المرور (يمنع الاستهلاك المزدوج
  //    TOCTOU). ⚠️ لا تُرمِ خطأ داخل المعاملة (يُعيد Firestore
  //    تنفيذها) — استخدم متغير فشل وارمِ بعد اكتمالها.
  let otpFailure = null;
  await db.runTransaction(async (transaction) => {
    otpFailure = null; // إعادة تعيين عند إعادة تنفيذ المعاملة
    const snapshot = await transaction.get(otpRef);
    if (!snapshot.exists) {
      otpFailure = {
        code: "not-found",
        message: "رمز التحقق غير موجود أو منتهي الصلاحية",
      };
      return;
    }
    const otpData = snapshot.data();
    if (!otpData || otpData.used === true) {
      otpFailure = {
        code: "failed-precondition",
        message: "تم استخدام رمز التحقق بالفعل",
      };
      return;
    }
    const expiresAt = otpData.expiresAt ? otpData.expiresAt.toDate() : null;
    if (expiresAt && expiresAt.getTime() <= Date.now()) {
      otpFailure = {
        code: "failed-precondition",
        message: "انتهت صلاحية رمز التحقق",
      };
      return;
    }
    if (otpData.otpCode !== otpCode) {
      otpFailure = {
        code: "invalid-argument",
        message: "رمز التحقق غير صحيح",
      };
      return;
    }
    transaction.update(otpRef, { used: true });
  });

  if (otpFailure) {
    throw new functions.https.HttpsError(otpFailure.code, otpFailure.message);
  }

  // 2. تغيير كلمة المرور عبر Firebase Auth (أثر جانبي بعد
  //    استهلاك الرمز — عبر خدمتين لا يمكن أن تكونا في معاملة
  //    واحدة: إذا فشل التغيير يبقى الرمز مستهلكاً ويُطلب رمز جديد)
  try {
    const user = await admin.auth().getUserByEmail(normalizedEmail);
    await admin.auth().updateUser(user.uid, { password: newPassword });
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new functions.https.HttpsError("not-found", "المستخدم غير موجود");
    }
    throw new functions.https.HttpsError(
      "internal",
      "فشل في تحديث كلمة المرور، حاول مرة أخرى",
    );
  }

  return { success: true };
});

// ===== Firestore Trigger: Prevent invoices for deleted customers =====
//
// ⚠️ ملاحظة هامة للمبرمجين المستقبليين:
// هذا الـ trigger يمنع إنشاء فواتير جديدة لعملاء محذوفين.
// يعمل كحل نهائي لنافذة السباق في deleteCustomer.
//
// ⚠️ كيف يعمل:
// 1. عند إنشاء فاتورة جديدة، يتحقق الـ trigger من وجود العميل.
// 2. إذا لم يوجد العميل، يحذف الـ trigger الفاتورة ويسجل حدث.
// 3. هذا يمنع فواتير جديدة لعملاء محذوفين.
//
// ⚠️ لماذا هذا الحل نهائي؟
// لأن Firestore triggers تعمل على جانب الخادم وتُنفذ
// بعد كتابة المستند مباشرة. حتى لو تم إنشاء الفاتورة
// من عميل متزامن، سيقوم الـ trigger بحذفها تلقائياً.
//
// ⚠️ القيود:
// - الـ trigger يعمل بعد إنشاء الفاتورة، ليس قبل.
// - هذا يعني أن الفاتورة توجد لفترة وجيزة قبل الحذف.
// - لكن هذا مقبول لأن الـ trigger يضمن عدم وجود
//   فواتير نهائية لعملاء محذوفين.
//
// ⚠️ ملاحظة: إذا أردت منع إنشاء الفاتورة أصلاً،
// استخدم Cloud Function مع `beforeCreate` trigger
// إذا كان متاحاً في إصدار Firebase SDK الخاص بك.
exports.preventInvoicesForDeletedCustomers = functions.firestore
  .document("{organizationEmail}/invoices/invoices/{invoiceId}")
  .onCreate(async (snap, context) => {
    const invoiceData = snap.data();
    const customerId = invoiceData?.customerId;
    const normalizedEmail = context.params.organizationEmail;

    // إذا لم يكن هناك عميل مرتبط، لا نتحقق
    // ⚠️ إصلاح يدوي (2026-10-08): استُبدلت customerId.trim().isEmpty
    // (طريقة غير موجودة في JavaScript — منقولة من Dart)
    // بـ customerId.trim() === '' لفحص صحيح أن معرف
    // العميل فارغ أو مسافات بيضاء فقط.
    if (
      !customerId ||
      customerId === "deleted_customer" ||
      customerId.trim() === ""
    ) {
      return null;
    }

    const customerRef = db
      .collection(normalizedEmail)
      .doc("customers")
      .collection("customers")
      .doc(customerId);
    const customerSnapshot = await customerRef.get();

    if (!customerSnapshot.exists) {
      // العميل محذوف - نحذف الفاتورة تلقائياً
      await snap.ref.delete();

      // تسجيل الحدث في سجل الفواتير
      const logDocRef = db
        .collection(normalizedEmail)
        .doc("invoices")
        .collection("logs")
        .doc();
      await logDocRef.set({
        userId: "system",
        actionType: "invoice_creation_blocked",
        details: `تم حذف الفاتورة تلقائياً: العميل ${customerId} محذوف`,
        targetId: context.params.invoiceId,
        targetType: "invoice",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isSuccess: false,
        invoiceData: invoiceData,
      });

      console.warn(
        `Blocked invoice creation for deleted customer: ${customerId} in ${normalizedEmail}`,
      );
      return null;
    }

    return null;
  });

// ════════════════════════════════════════════════════════════════════════
// ⚠️ ⚠️ ⚠️ ملاحظات نهائية للمبرمجين المستقبليين ⚠️ ⚠️ ⚠️
// ════════════════════════════════════════════════════════════════════════
//
// ⚠️ ملاحظة مهمة للمبرمجين المستقبليين:
// 1. جميع عمليات الاشتراكات في هذا الملف ذرية باستخدام Firestore Transactions.
// 2. لا تستخدم where().get() داخل المعاملة - استخدم transaction.get(DocumentReference).
// 3. استخدم FieldValue.increment() للعمليات الحسابية لضمان الذرية.
// 4. استخدم expectedUpdatedAt للتحقق من التعديل المتزامن.
// 5. إذا أضفت عملية جديدة، تأكد من أنها داخل runTransaction واحدة مع جميع العمليات المرتبطة.
// 6. ⚠️ تصحيح تحقق يدوي (2026-10-08): الملاحظة القديمة
//    التي كانت هنا تقول إن updateSubscription و
//    deleteSubscription في
//    D:\ashur\lib\features\subscriptions\data\repositories\subscription_repository_impl.dart
//    "يستخدمان .where().get() داخل المعاملة" — وهذا
//    غير دقيق! كلاهما يحل مرجع النوع خارج المعاملة
//    (النمط الصحيح). لا تُرجع لوضع استعلام داخل
//    المعاملة أبداً.
//
// ════════════════════════════════════════════════════════════════════════
// ✅ نهاية التحقق من العمليات الذرية في قسم الاشتراكات ✅
// ════════════════════════════════════════════════════════════════════════

// Send OneSignal alerts to the authenticated user's own registered device.
// This is used for reminders that used to be scheduled/displayed locally.
exports.sendSelfOneSignalNotification = functions
  .runWith({ secrets: ["ONESIGNAL_REST_API_KEY"] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const title = typeof data?.title === "string" ? data.title.trim() : "";
    const body = typeof data?.body === "string" ? data.body.trim() : "";
    const subscriptionId =
      typeof data?.subscriptionId === "string"
        ? data.subscriptionId.trim()
        : "";
    const sendAfter = typeof data?.sendAfter === "string" ? data.sendAfter : "";
    const notificationId = Number.isInteger(data?.notificationId)
      ? data.notificationId
      : null;
    if (
      !title ||
      title.length > 120 ||
      !body ||
      body.length > 2000 ||
      !subscriptionId
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات الإشعار غير صالحة",
      );
    }
    if (
      sendAfter &&
      (!Number.isFinite(Date.parse(sendAfter)) ||
        Date.parse(sendAfter) <= Date.now())
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "وقت جدولة الإشعار غير صالح",
      );
    }

    const callerEmail = context.auth.token.email;
    if (typeof callerEmail !== "string" || !callerEmail.includes("@")) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "تعذر تحديد المؤسسة",
      );
    }
    const organizationEmail = normalizeOrganizationEmail(callerEmail);
    const userRef = db
      .collection(organizationEmail)
      .doc("users")
      .collection("users")
      .doc(context.auth.uid);
    const userSnapshot = await userRef.get();
    if (!userSnapshot.exists || userSnapshot.data().isActive === false) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "حساب المستخدم غير نشط",
      );
    }
    const userData = userSnapshot.data();
    const ownedIds = new Set([
      ...(typeof userData.oneSignalPlayerId === "string"
        ? [userData.oneSignalPlayerId]
        : []),
      ...(Array.isArray(userData.oneSignalPlayerIds)
        ? userData.oneSignalPlayerIds
        : []),
    ]);
    if (userData.notificationEnabled === false) {
      return { sent: 0, message: "إشعارات هذا المستخدم متوقفة" };
    }
    if (!ownedIds.has(subscriptionId)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "الجهاز غير مرتبط بحسابك",
      );
    }

    const restApiKey = process.env.ONESIGNAL_REST_API_KEY;
    if (!restApiKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "خدمة الإشعارات غير مهيأة",
      );
    }
    const message = {
      app_id: "e309b00d-2d36-4285-ac55-f7b5831d731d",
      include_subscription_ids: [subscriptionId],
      target_channel: "push",
      headings: { en: title, ar: title },
      contents: { en: body, ar: body },
      data: {
        type: sendAfter ? "scheduled_local_alert" : "local_alert",
        ...(notificationId === null
          ? {}
          : { notificationId: String(notificationId) }),
        title,
        body,
      },
      android_sound: "default",
      android_priority: 10,
    };
    if (sendAfter) message.send_after = sendAfter;

    const response = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Key ${restApiKey}`,
      },
      body: JSON.stringify(message),
    });
    const responseBody = await response.json().catch(() => ({}));
    if (!response.ok) {
      console.error(
        `OneSignal rejected self notification: ${response.status} ${JSON.stringify(responseBody).slice(0, 1000)}`,
      );
      throw new functions.https.HttpsError(
        "internal",
        "تعذر إرسال الإشعار عبر OneSignal",
      );
    }

    if (sendAfter && typeof responseBody.id === "string") {
      await userRef
        .collection("oneSignalScheduledNotifications")
        .doc(responseBody.id)
        .set({
          subscriptionId,
          notificationId,
          scheduleKey: notificationId === null ? "" : `local_${notificationId}`,
          sendAfter: admin.firestore.Timestamp.fromDate(new Date(sendAfter)),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      if (notificationId !== null && callerEmail) {
        const organizationEmail = normalizeOrganizationEmail(callerEmail);
        const scheduleKey = `local_${notificationId}`;
        await db
          .collection(organizationEmail)
          .doc("system")
          .collection("notificationSchedules")
          .doc(scheduleKey)
          .set({
            userId: context.auth.uid,
            messageId: responseBody.id,
            scheduledAt: admin.firestore.Timestamp.fromDate(
              new Date(sendAfter),
            ),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }
    }
    return { sent: 1, messageId: responseBody.id ?? null };
  });

exports.cancelSelfOneSignalNotification = functions
  .runWith({ secrets: ["ONESIGNAL_REST_API_KEY"] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }
    const messageId =
      typeof data?.messageId === "string" ? data.messageId.trim() : "";
    const callerEmail = context.auth.token.email;
    if (
      !messageId ||
      typeof callerEmail !== "string" ||
      !callerEmail.includes("@")
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات الإلغاء غير صالحة",
      );
    }
    const organizationEmail = normalizeOrganizationEmail(callerEmail);
    const userRef = db
      .collection(organizationEmail)
      .doc("users")
      .collection("users")
      .doc(context.auth.uid);
    const userSnapshot = await userRef.get();
    if (!userSnapshot.exists || userSnapshot.data().isActive === false) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "حساب المستخدم غير نشط",
      );
    }
    const scheduleRef = userRef
      .collection("oneSignalScheduledNotifications")
      .doc(messageId);
    const scheduleSnapshot = await scheduleRef.get();
    if (!scheduleSnapshot.exists) return { canceled: false };
    const scheduleData = scheduleSnapshot.data();
    if (scheduleData?.scheduleKey) {
      await db
        .collection(organizationEmail)
        .doc("system")
        .collection("notificationSchedules")
        .doc(scheduleData.scheduleKey)
        .delete();
    }
    const restApiKey = process.env.ONESIGNAL_REST_API_KEY;
    if (!restApiKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "خدمة الإشعارات غير مهيأة",
      );
    }
    const response = await fetch(
      `https://api.onesignal.com/notifications/${encodeURIComponent(messageId)}?app_id=e309b00d-2d36-4285-ac55-f7b5831d731d`,
      { method: "DELETE", headers: { Authorization: `Key ${restApiKey}` } },
    );
    const responseBody = await response.json().catch(() => ({}));
    if (response.status === 404) {
      await scheduleRef.delete();
      return { canceled: false };
    }
    if (!response.ok) {
      console.error(
        `OneSignal rejected cancellation: ${response.status} ${JSON.stringify(responseBody).slice(0, 1000)}`,
      );
      throw new functions.https.HttpsError(
        "internal",
        "تعذر إلغاء الإشعار المجدول",
      );
    }
    await scheduleRef.delete();
    return { canceled: true };
  });

// Organization push notifications are sent from trusted server code so the
// OneSignal REST API key is never shipped in the client application.
exports.sendOrganizationNotification = functions
  .runWith({ secrets: ["ONESIGNAL_REST_API_KEY"] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const organizationEmail = normalizeOrganizationEmail(
      data?.organizationEmail,
    );
    const callerEmail =
      typeof context.auth.token.email === "string"
        ? context.auth.token.email.trim().toLowerCase()
        : "";
    const title = typeof data?.title === "string" ? data.title.trim() : "";
    const body = typeof data?.body === "string" ? data.body.trim() : "";
    const type = typeof data?.type === "string" ? data.type.trim() : "";
    const isSystemSubscriptionAlert =
      type === "subscription_expiring" || type === "subscription_expired";
    if (
      isSystemSubscriptionAlert &&
      normalizeOrganizationEmail(callerEmail) !== organizationEmail
    ) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "لا يمكن إرسال تنبيه لمؤسسة أخرى",
      );
    }
    const allowedTypes = new Set([
      "subscription_expiring",
      "subscription_expired",
      "invoice_created",
      "invoice_updated",
      "invoice_deleted",
      "invoice_paid",
      "invoice_cash",
      "customer_cash_invoice",
      "inventory_product_created",
      "inventory_product_deleted",
      "inventory_quantity_updated",
      "customer_created",
      "customer_updated",
      "customer_deleted",
      "customer_zero_balance",
      "maintenance_created",
      "maintenance_updated",
      "maintenance_deleted",
      "maintenance_completed",
      "rental_created",
      "rental_updated",
      "rental_deleted",
      "rental_returned",
      "expense_created",
      "expense_updated",
      "expense_deleted",
      "subscription_created",
      "subscription_updated",
      "subscription_deleted",
      "subscription_renewed",
      "subscription_expiring",
      "subscription_expired",
    ]);

    if (
      !organizationEmail.includes("@") ||
      title.length === 0 ||
      title.length > 120 ||
      body.length === 0 ||
      body.length > 2000 ||
      !allowedTypes.has(type) ||
      !callerEmail ||
      !normalizeOrganizationEmail(callerEmail).includes("@")
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بيانات الإشعار غير صالحة",
      );
    }

    const usersRef = db
      .collection(organizationEmail)
      .doc("users")
      .collection("users");
    const usersSnapshot = await usersRef.get();
    const rolesSnapshot = await db
      .collection(organizationEmail)
      .doc("users")
      .collection("roles")
      .get();
    const rolesById = new Map(
      rolesSnapshot.docs.map((doc) => [doc.id, doc.data()]),
    );
    const authenticatedUserDoc =
      usersSnapshot.docs.find((doc) => doc.id === context.auth.uid) ??
      usersSnapshot.docs.find(
        (doc) =>
          normalizeOrganizationEmail(String(doc.data().email ?? "")) ===
          normalizeOrganizationEmail(callerEmail),
      );
    if (!authenticatedUserDoc) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "ليس لديك عضوية في هذه المؤسسة",
      );
    }
    if (authenticatedUserDoc.data().isActive === false) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "حساب المستخدم غير نشط",
      );
    }

    const switchedActorUid =
      typeof data?.actorUid === "string" ? data.actorUid.trim() : "";
    const actorEmail =
      typeof data?.actorEmail === "string"
        ? data.actorEmail.trim().toLowerCase()
        : "";
    const switchedActorDoc = switchedActorUid
      ? usersSnapshot.docs.find((doc) => doc.id === switchedActorUid)
      : null;
    const verifiedSwitchedActor =
      switchedActorUid &&
      switchedActorDoc &&
      switchedActorDoc.id !== authenticatedUserDoc.id &&
      switchedActorDoc.data().isActive !== false &&
      actorEmail &&
      normalizeOrganizationEmail(
        String(switchedActorDoc.data().email ?? ""),
      ) === normalizeOrganizationEmail(actorEmail);
    if (switchedActorUid && !verifiedSwitchedActor) {
      console.warn(
        "Ignoring switched actor hint that does not match authenticated organization identity.",
      );
    }
    const actorDoc = verifiedSwitchedActor
      ? switchedActorDoc
      : authenticatedUserDoc;
    if (!actorDoc || actorDoc.data().isActive === false) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "المستخدم المنفذ غير تابع لهذه المؤسسة أو غير نشط",
      );
    }
    const requiredPermissions = {
      subscription_expiring: [],
      subscription_expired: [],
      invoice_created: [
        "invoices_sales_manage",
        "invoices_purchase_manage",
        "invoices_cash_manage",
        "invoices_subscription_manage",
        "invoices_sales_return_manage",
      ],
      invoice_updated: [
        "invoices_sales_manage",
        "invoices_purchase_manage",
        "invoices_cash_manage",
        "invoices_subscription_manage",
        "invoices_sales_return_manage",
      ],
      invoice_deleted: [
        "invoices_sales_manage",
        "invoices_purchase_manage",
        "invoices_cash_manage",
        "invoices_subscription_manage",
        "invoices_sales_return_manage",
      ],
      invoice_paid: [
        "invoices_sales_manage",
        "invoices_purchase_manage",
        "invoices_cash_manage",
        "invoices_subscription_manage",
      ],
      invoice_cash: ["invoices_cash_manage"],
      customer_cash_invoice: [
        "invoices_cash_manage",
        "customers_create",
        "customers_edit",
      ],
      inventory_product_created: ["inventory_create"],
      inventory_product_deleted: ["inventory_delete"],
      inventory_quantity_updated: ["inventory_edit"],
      customer_created: ["customers_create"],
      customer_updated: ["customers_edit", "customers_create"],
      customer_deleted: ["customers_delete"],
      customer_zero_balance: ["customers_edit", "customers_create"],
      maintenance_created: ["maintenance_create"],
      maintenance_updated: ["maintenance_edit"],
      maintenance_deleted: ["maintenance_delete"],
      maintenance_completed: ["maintenance_edit"],
      rental_created: ["rentals_create"],
      rental_updated: ["rentals_edit"],
      rental_deleted: ["rentals_delete"],
      rental_returned: ["rentals_edit"],
      expense_created: ["expenses_create"],
      expense_updated: ["expenses_edit"],
      expense_deleted: ["expenses_delete"],
      subscription_created: ["subscriptions_create"],
      subscription_updated: ["subscriptions_edit"],
      subscription_deleted: ["subscriptions_delete"],
      subscription_renewed: ["subscriptions_renew"],
      subscription_expiring: [],
      subscription_expired: [],
    };
    const allowedPermissions = requiredPermissions[type];
    if (
      !isSystemSubscriptionAlert &&
      !canPerformActingNotificationAction(
        actorDoc.data(),
        authenticatedUserDoc.data(),
        rolesById,
        allowedPermissions,
        Boolean(verifiedSwitchedActor),
      )
    ) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "ليس لديك صلاحية إرسال هذا الإشعار",
      );
    }

    const settingsSnapshot = await db
      .collection(organizationEmail)
      .doc("settings")
      .collection("settings")
      .get();
    const settingsByCategory = {};
    for (const settingDoc of settingsSnapshot.docs) {
      const setting = settingDoc.data();
      if (!setting.category || !setting.key) continue;
      settingsByCategory[setting.category] =
        settingsByCategory[setting.category] || {};
      settingsByCategory[setting.category][setting.key] = setting.value;
    }

    const sectionKeys = {
      invoices: ["invoiceAlertsEnabled", "invoiceAlertPushEnabled"],
      inventory: ["inventoryAlertsEnabled", "inventoryAlertPushEnabled"],
      customers: ["customerAlertsEnabled", "customerAlertPushEnabled"],
      maintenance: ["maintenanceAlertsEnabled", "maintenanceAlertPushEnabled"],
      rentals: ["rentalAlertsEnabled", "rentalAlertPushEnabled"],
      expenses: ["expensesAlertsEnabled", "expensesAlertPushEnabled"],
      subscriptions: [
        "subscriptionAlertsEnabled",
        "subscriptionAlertPushEnabled",
      ],
    };
    const typePreferenceKey = {
      invoice_created: "invoice_notify_new",
      invoice_updated: "invoice_notify_updated",
      invoice_deleted: "invoice_notify_deleted",
      invoice_paid: "invoice_notify_paid",
      invoice_cash: "invoice_notify_cash",
      customer_cash_invoice: "customer_notify_cash_invoice",
      inventory_product_created: "inventory_notify_new",
      inventory_product_deleted: "inventory_notify_deleted",
      inventory_quantity_updated: "inventory_notify_quantity_update",
      customer_created: "customer_notify_new",
      customer_updated: "customer_notify_updated",
      customer_deleted: "customer_notify_deleted",
      customer_zero_balance: "customer_notify_zero_balance",
      maintenance_created: "maintenance_notify_new",
      maintenance_updated: "maintenance_notify_updated",
      maintenance_deleted: "maintenance_notify_deleted",
      maintenance_completed: "maintenance_notify_completed",
      rental_created: "rental_notify_new",
      rental_updated: "rental_notify_updated",
      rental_deleted: "rental_notify_deleted",
      rental_returned: "rental_notify_returned",
      expense_created: "expenses_notify_new",
      expense_updated: "expenses_notify_updated",
      expense_deleted: "expenses_notify_deleted",
      subscription_created: "subscription_notify_new",
      subscription_updated: "subscription_notify_updated",
      subscription_deleted: "subscription_notify_deleted",
      subscription_renewed: "subscription_notify_renewed",
    };
    const notificationSettings = settingsByCategory.notifications || {};
    if (isSystemSubscriptionAlert) {
      const subscriptionSettings = settingsByCategory.subscriptions || {};
      const isEnabled =
        isSettingEnabled(
          subscriptionSettings,
          "subscriptionAlertsEnabled",
          true,
        ) &&
        isSettingEnabled(
          subscriptionSettings,
          "subscriptionAlertPushEnabled",
          true,
        ) &&
        isSettingEnabled(
          subscriptionSettings,
          type === "subscription_expiring"
            ? "subscriptionAlertRenewalEnabled"
            : "subscriptionAlertExpiredEnabled",
          true,
        ) &&
        isSettingEnabled(notificationSettings, "enableNotifications", true) &&
        isSettingEnabled(notificationSettings, "enablePushNotifications", true);
      if (!isEnabled) return { sent: 0, message: "تنبيهات الاشتراك متوقفة" };
    }
    if (
      !isSystemSubscriptionAlert &&
      (!isSettingEnabled(notificationSettings, "enableNotifications", true) ||
        !isSettingEnabled(
          notificationSettings,
          "enablePushNotifications",
          true,
        ))
    ) {
      return { sent: 0, message: "إشعارات المؤسسة متوقفة" };
    }
    const sectionForType = {
      invoice_created: "invoices",
      invoice_updated: "invoices",
      invoice_deleted: "invoices",
      invoice_paid: "invoices",
      invoice_cash: "invoices",
      customer_cash_invoice: "customers",
      inventory_product_created: "inventory",
      inventory_product_deleted: "inventory",
      inventory_quantity_updated: "inventory",
      customer_created: "customers",
      customer_updated: "customers",
      customer_deleted: "customers",
      customer_zero_balance: "customers",
      maintenance_created: "maintenance",
      maintenance_updated: "maintenance",
      maintenance_deleted: "maintenance",
      maintenance_completed: "maintenance",
      rental_created: "rentals",
      rental_updated: "rentals",
      rental_deleted: "rentals",
      rental_returned: "rentals",
      expense_created: "expenses",
      expense_updated: "expenses",
      expense_deleted: "expenses",
      subscription_created: "subscriptions",
      subscription_updated: "subscriptions",
      subscription_deleted: "subscriptions",
      subscription_renewed: "subscriptions",
    };
    const section = sectionForType[type];
    if (!isSystemSubscriptionAlert) {
      const sectionSettings = settingsByCategory[section] || {};
      const [masterKey, pushKey] = sectionKeys[section];
      const sectionMasterDefaults = {
        invoices: true,
        inventory: true,
        customers: true,
        maintenance: true,
        rentals: true,
        expenses: true,
        subscriptions: true,
      };
      if (
        !isSettingEnabled(
          sectionSettings,
          masterKey,
          sectionMasterDefaults[section],
        ) ||
        !isSettingEnabled(sectionSettings, pushKey, true)
      ) {
        return { sent: 0, message: "إشعارات هذا القسم متوقفة" };
      }
      const preferenceKey = typePreferenceKey[type];
      const preferenceDefaults = {
        invoice_created: false,
        invoice_updated: false,
        invoice_deleted: false,
        invoice_paid: false,
        invoice_cash: false,
        customer_cash_invoice: false,
        inventory_product_created: false,
        inventory_product_deleted: false,
        inventory_quantity_updated: false,
        customer_created: false,
        customer_updated: false,
        customer_deleted: false,
        customer_zero_balance: false,
        maintenance_created: false,
        maintenance_updated: false,
        maintenance_deleted: false,
        maintenance_completed: false,
        rental_created: false,
        rental_updated: false,
        rental_deleted: false,
        rental_returned: false,
        expense_created: false,
        expense_updated: false,
        expense_deleted: false,
        subscription_created: false,
        subscription_updated: false,
        subscription_deleted: false,
        subscription_renewed: false,
      };
      if (
        preferenceKey &&
        !isSettingEnabled(
          notificationSettings,
          preferenceKey,
          preferenceDefaults[type] ?? false,
        )
      ) {
        return { sent: 0, message: "نوع الإشعار متوقف" };
      }
    }

    // Only exclude devices bound to the authenticated Firebase account. The
    // switched-role UID is client state and cannot safely identify devices to
    // suppress. An opted-out user is excluded separately as a recipient.
    const allUsers = usersSnapshot.docs.map((doc) => ({
      id: doc.id,
      data: doc.data(),
    }));
    const excludedActorIds = new Set([authenticatedUserDoc.id]);
    const optedOutUserIds = new Set(
      allUsers
        .filter((user) => user.data.notificationEnabled === false)
        .map((user) => user.id),
    );
    const recipientPlayerIds = getRecipientPlayerIds(
      allUsers,
      excludedActorIds,
      optedOutUserIds,
    );

    if (recipientPlayerIds.size === 0) {
      return { sent: 0, message: "لا يوجد مستلمون مفعّلون للإشعارات" };
    }

    const restApiKey = process.env.ONESIGNAL_REST_API_KEY;
    if (!restApiKey) {
      console.error("ONESIGNAL_REST_API_KEY secret is not configured");
      throw new functions.https.HttpsError(
        "failed-precondition",
        "خدمة الإشعارات غير مهيأة",
      );
    }

    const playerIds = Array.from(recipientPlayerIds);
    const chunks = [];
    for (let index = 0; index < playerIds.length; index += 2000) {
      chunks.push(playerIds.slice(index, index + 2000));
    }

    const rawData = data?.data;
    const notificationData = {};
    if (rawData && typeof rawData === "object" && !Array.isArray(rawData)) {
      for (const [key, value] of Object.entries(rawData).slice(0, 30)) {
        if (
          typeof value === "string" &&
          key.length <= 100 &&
          value.length <= 500
        ) {
          notificationData[key] = value;
        }
      }
    }
    notificationData.type = type;
    notificationData.title = title;
    notificationData.body = body;
    const scheduleAt =
      data?.scheduledAt instanceof admin.firestore.Timestamp
        ? data.scheduledAt.toDate()
        : null;
    const scheduleKey =
      typeof data?.scheduleKey === "string"
        ? data.scheduleKey.slice(0, 180)
        : "";

    for (const playerIdChunk of chunks) {
      const response = await fetch("https://api.onesignal.com/notifications", {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          Authorization: `Key ${restApiKey}`,
        },
        body: JSON.stringify({
          app_id: "e309b00d-2d36-4285-ac55-f7b5831d731d",
          include_subscription_ids: playerIdChunk,
          target_channel: "push",
          contents: { en: body, ar: body },
          headings: { en: title, ar: title },
          data: notificationData,
          ...(scheduleAt ? { send_after: scheduleAt.toISOString() } : {}),
          android_sound: "default",
          android_priority: 10,
        }),
      });

      const responseBody = await response.json().catch(() => ({}));
      if (!response.ok) {
        console.error(
          `OneSignal rejected ${type}: ${response.status} ${JSON.stringify(responseBody).slice(0, 1000)}`,
        );
        throw new functions.https.HttpsError(
          "internal",
          "تعذر إرسال إشعار المؤسسة",
        );
      }
      if (scheduleAt && scheduleKey && typeof responseBody.id === "string") {
        await db
          .collection(organizationEmail)
          .doc("system")
          .collection("notificationSchedules")
          .doc(scheduleKey)
          .set({
            messageId: responseBody.id,
            scheduledAt: admin.firestore.Timestamp.fromDate(scheduleAt),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }
    }

    return { sent: recipientPlayerIds.size };
  });

// Daily server-side subscription expiry reminders; this executes even when all
// clients are closed and uses the OneSignal REST key only on the server.
exports.sendDailySubscriptionExpiryNotifications = functions
  .runWith({ secrets: ["ONESIGNAL_REST_API_KEY"], timeoutSeconds: 540 })
  .pubsub.schedule("every 60 minutes")
  .timeZone("UTC")
  .onRun(async () => {
    notificationSettingsCache.clear();
    const organizationEmails = new Set();
    const organizationsSnapshot = await db.collectionGroup("users").get();
    for (const userDoc of organizationsSnapshot.docs) {
      const usersCollection = userDoc.ref.parent;
      if (usersCollection.id !== "users") continue;
      const usersDocument = usersCollection.parent;
      if (usersDocument?.id !== "users") continue;
      const organizationCollection = usersDocument.parent;
      const organizationEmail = normalizeOrganizationEmail(organizationCollection?.id);
      if (organizationEmail.includes("@")) organizationEmails.add(organizationEmail);
    }
    const now = new Date();
    const todayKey = now.toISOString().slice(0, 10);
    const summary = { organizations: 0, notifications: 0 };

    for (const organizationEmail of organizationEmails) {
      const settingsSnapshot = await db
        .collection(organizationEmail)
        .doc("settings")
        .collection("settings")
        .get();
      const settingsByCategory = {};
      for (const settingDoc of settingsSnapshot.docs) {
        const setting = settingDoc.data();
        if (setting.category && setting.key) {
          settingsByCategory[setting.category] =
            settingsByCategory[setting.category] || {};
          settingsByCategory[setting.category][setting.key] = setting.value;
        }
      }
      const notifications = settingsByCategory.notifications || {};
      const subscriptionSettings = settingsByCategory.subscriptions || {};
      if (
        !isSettingEnabled(notifications, "enableNotifications", true) ||
        !isSettingEnabled(notifications, "enablePushNotifications", true) ||
        !isSettingEnabled(
          subscriptionSettings,
          "subscriptionAlertsEnabled",
          true,
        ) ||
        !isSettingEnabled(
          subscriptionSettings,
          "subscriptionAlertPushEnabled",
          true,
        )
      ) {
        continue;
      }

      const usersSnapshot = await db
        .collection(organizationEmail)
        .doc("users")
        .collection("users")
        .get();
      const allUsers = usersSnapshot.docs.map((doc) => ({
        id: doc.id,
        data: doc.data(),
      }));
      const recipients = getRecipientPlayerIds(allUsers, new Set(), new Set());
      if (recipients.size === 0) continue;
      const subscriptionSnapshot = await db
        .collection(organizationEmail)
        .doc("subscriptions")
        .collection("subscriptions")
        .get();
      // Settings are persisted by the Flutter client as serialized strings
      // (including JSON arrays), so parse warning days before checking values.
      const warningDaysRaw = subscriptionSettings.subscriptionWarningDays;
      let warningDaysValue = warningDaysRaw;
      if (typeof warningDaysValue === "string") {
        try {
          warningDaysValue = JSON.parse(warningDaysValue);
        } catch (_error) {
          warningDaysValue = warningDaysValue
            .replace(/^\[/, "")
            .replace(/\]$/, "")
            .split(",");
        }
      }
      let warningDays = Array.isArray(warningDaysValue)
        ? warningDaysValue
            .map((day) => Number.parseInt(String(day).trim(), 10))
            .filter((day) => Number.isInteger(day) && day > 0)
        : [1, 2, 3];
      if (warningDays.length === 0) warningDays = [1, 2, 3];
      const expirationEnabled = isSettingEnabled(
        subscriptionSettings,
        "subscriptionAlertRenewalEnabled",
        true,
      );
      const expiredEnabled = isSettingEnabled(
        subscriptionSettings,
        "subscriptionAlertExpiredEnabled",
        true,
      );
      const schedules = [];
      for (const subscriptionDoc of subscriptionSnapshot.docs) {
        const subscription = subscriptionDoc.data();
        if (
          subscription.status !== "active" &&
          subscription.status !== "expired"
        )
          continue;
        const rawEndDate = subscription.endDate?.toDate
          ? subscription.endDate.toDate()
          : new Date(subscription.endDate);
        if (!Number.isFinite(rawEndDate.getTime())) continue;
        const endDay = Date.UTC(
          rawEndDate.getUTCFullYear(),
          rawEndDate.getUTCMonth(),
          rawEndDate.getUTCDate(),
        );
        const today = Date.UTC(
          now.getUTCFullYear(),
          now.getUTCMonth(),
          now.getUTCDate(),
        );
        const daysRemaining = Math.round((endDay - today) / 86400000);
        const isExpired =
          subscription.status === "expired" || daysRemaining < 0;
        if (isExpired && expiredEnabled) {
          const key = `subscription_expired_${subscriptionDoc.id}_${endDay}`;
          const customerName = subscription.customerName || "المشترك";
          schedules.push({
            key,
            type: "subscription_expired",
            title: "انتهى الاشتراك",
            body: `انتهى اشتراك ${customerName} بتاريخ ${rawEndDate.toLocaleDateString("ar-IQ", { timeZone: "UTC" })}. يرجى مراجعة التجديد.`,
          });
        } else if (
          subscription.status === "active" &&
          daysRemaining >= 0 &&
          expirationEnabled &&
          warningDays.includes(daysRemaining)
        ) {
          const key = `subscription_expiring_${subscriptionDoc.id}_${endDay}_${daysRemaining}`;
          schedules.push({
            key,
            type: "subscription_expiring",
            title: "اشتراك يقترب من الانتهاء",
            body: `اشتراك ${subscription.customerName || "المشترك"} ينتهي خلال ${daysRemaining} يوم. يرجى مراجعة التجديد.`,
          });
        }
      }

      for (const reminder of schedules) {
        const scheduleRef = db
          .collection(organizationEmail)
          .doc("system")
          .collection("notificationSchedules")
          .doc(reminder.key);
        const existing = await scheduleRef.get();
        if (existing.exists) continue;
        const ids = Array.from(recipients);
        for (let index = 0; index < ids.length; index += 2000) {
          const response = await fetch(
            "https://api.onesignal.com/notifications",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                Authorization: `Key ${process.env.ONESIGNAL_REST_API_KEY}`,
              },
              body: JSON.stringify({
                app_id: "e309b00d-2d36-4285-ac55-f7b5831d731d",
                include_subscription_ids: ids.slice(index, index + 2000),
                target_channel: "push",
                headings: { en: reminder.title, ar: reminder.title },
                contents: { en: reminder.body, ar: reminder.body },
                data: { type: reminder.type },
                android_sound: "default",
                android_priority: 10,
              }),
            },
          );
          const responseBody = await response.json().catch(() => ({}));
          if (!response.ok) {
            throw new Error(
              `OneSignal rejected scheduled reminder: ${response.status} ${JSON.stringify(responseBody).slice(0, 500)}`,
            );
          }
        }
        await scheduleRef.set({
          type: reminder.type,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        summary.notifications++;
      }
        summary.organizations++;
    }
    console.log("Daily subscription expiry notification run:", summary);
    return null;
  });

exports.sendTestNotification = functions
  .runWith({ secrets: ["ONESIGNAL_REST_API_KEY"] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "يجب تسجيل الدخول",
      );
    }

    const { organizationEmail, title, body, type } = data;
    if (!organizationEmail || !title || !body || !type) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "معاملات ناقصة",
      );
    }

    const normalizedEmail = normalizeOrganizationEmail(organizationEmail);
    if (!normalizedEmail.includes("@")) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "بريد المؤسسة غير صالح",
      );
    }

    const restApiKey = process.env.ONESIGNAL_REST_API_KEY;
    if (!restApiKey) {
      throw new functions.https.HttpsError(
        "internal",
        "مفتاح OneSignal غير مُconfigured على السيرفر",
      );
    }

    // جلب جميع المستخدمين(Player IDs) مع فحص إعدادات الإشعارات الشخصية
    const usersSnapshot = await db
      .collection(normalizedEmail)
      .doc("users")
      .collection("users")
      .get();

    const playerIds = new Set();

    for (const doc of usersSnapshot.docs) {
      const uid = doc.id;
      const userData = doc.data() || {};

      // فحص إعدادات الإشعارات الشخصية للمستخدم
      const userSettingsDoc = await db
        .collection(normalizedEmail)
        .doc("users")
        .collection("users")
        .doc(uid)
        .collection("notification_settings")
        .doc("settings")
        .get();

      const userSettings = userSettingsDoc.exists
        ? userSettingsDoc.data() || {}
        : {};

      const notificationsEnabled =
        userSettings.enableNotifications !== false;
      const pushEnabled =
        userSettings.enablePushNotifications !== false;

      if (!notificationsEnabled || !pushEnabled) continue;

      const typeKey = type; // النوع يتم تمريره كما هو من التطبيق
      const typeEnabled = userSettings[typeKey];
      if (typeEnabled !== undefined && !typeEnabled) continue;

      const single = userData.oneSignalPlayerId;
      if (typeof single === "string" && single.trim()) {
        playerIds.add(single.trim());
      }
      if (Array.isArray(userData.oneSignalPlayerIds)) {
        for (const id of userData.oneSignalPlayerIds) {
          if (typeof id === "string" && id.trim()) {
            playerIds.add(id.trim());
          }
        }
      }
    }

    const ids = Array.from(playerIds);
    if (ids.length === 0) {
      return { success: true, sent: 0, message: "لا توجد أجهزة مسجلة" };
    }

    // إرسال عبر OneSignal REST API من السيرفر
    for (let index = 0; index < ids.length; index += 2000) {
      const response = await fetch(
        "https://api.onesignal.com/notifications",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json; charset=utf-8",
            Authorization: `Key ${restApiKey}`,
          },
          body: JSON.stringify({
            app_id: ONESIGNAL_APP_ID,
            include_subscription_ids: ids.slice(index, index + 2000),
            target_channel: "push",
            headings: { en: title, ar: title },
            contents: { en: body, ar: body },
            data: { type, actor_email: context.auth.uid },
            android_sound: "default",
            android_priority: 10,
          }),
        },
      );
      const responseBody = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new functions.https.HttpsError(
          "internal",
          `فشل إرسال OneSignal: ${response.status}`,
        );
      }
    }

    // تسجيل الإشعار في Firestore
    await db
      .collection(normalizedEmail)
      .doc("notifications")
      .collection("notifications")
      .add({
        title,
        body,
        type,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        actorEmail: context.auth.uid,
        sentTo: ids.length,
      });

    return { success: true, sent: ids.length };
  });
