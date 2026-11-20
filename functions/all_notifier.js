const admin = require("firebase-admin");
const crypto = require("node:crypto");

const ONESIGNAL_APP_ID = "e309b00d-2d36-4285-ac55-f7b5831d731d";
const MAX_WARNING_DAYS = 30;
const FIRESTORE_PAGE_SIZE = 10;
const FIRESTORE_READ_BATCH_SIZE = 10;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function normalizeOrganizationEmail(email) {
  if (typeof email !== "string") return "";
  const parts = email.trim().toLowerCase().split("@");
  if (parts.length !== 2 || !parts[0] || !parts[1]) return "";
  const [local, domain] = parts;
  let normalizedLocal = local;
  if (["gmail.com", "googlemail.com"].includes(domain)) {
    normalizedLocal = normalizedLocal.replace(/\./g, "");
  }
  if (
    [
      "gmail.com",
      "googlemail.com",
      "outlook.com",
      "hotmail.com",
      "live.com",
      "yahoo.com",
      "icloud.com",
      "me.com",
    ].includes(domain)
  ) {
    normalizedLocal = normalizedLocal.split("+")[0];
  }
  return `${normalizedLocal}@${domain}`;
}

function toDate(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  return null;
}

function baghdadDateParts(date) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    throw new TypeError("Expected a valid Date");
  }
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Baghdad",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const values = Object.fromEntries(
    parts.map(({ type, value }) => [type, value]),
  );
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
}

function utcDay(date) {
  const { year, month, day } = baghdadDateParts(date);
  return Date.UTC(year, month - 1, day);
}

function dateKey(date) {
  const { year, month, day } = baghdadDateParts(date);
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function asBool(value, fallback = false) {
  if (value === undefined || value === null) return fallback;
  return value === true || String(value).toLowerCase() === "true";
}

function eligiblePlayerIds(users, userSettingsById, typeKey, daysRemaining) {
  const ids = new Set();
  for (const user of users) {
    const data = user.data || {};
    if (data.isActive === false || data.notificationEnabled === false) continue;
    const settings = userSettingsById.get(user.id) || {};
    if (
      !asBool(settings.enableNotifications, false) ||
      !asBool(settings.enablePushNotifications, false)
    ) {
      continue;
    }
    if (!asBool(settings[typeKey], false)) continue;

    if (daysRemaining !== undefined) {
      const configuredDays = Array.isArray(settings.warningDays)
        ? settings.warningDays
            .map((day) => Number(day))
            .filter((day) => Number.isInteger(day) && day > 0)
        : [];
      const reminderDays = Number(settings.reminderDaysBefore);
      if (Number.isInteger(reminderDays) && reminderDays > 0) {
        configuredDays.push(reminderDays);
      }
      if (configuredDays.length === 0) configuredDays.push(1, 2, 3);
      if (!configuredDays.includes(daysRemaining)) continue;
    }

    const single = data.oneSignalPlayerId;
    if (typeof single === "string" && single.trim()) ids.add(single.trim());
    if (Array.isArray(data.oneSignalPlayerIds)) {
      for (const id of data.oneSignalPlayerIds) {
        if (typeof id === "string" && id.trim()) ids.add(id.trim());
      }
    }
  }
  return ids;
}

function keyHash(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

async function readSettings(db, organizationEmail) {
  const snapshot = await db
    .collection(organizationEmail)
    .doc("settings")
    .collection("settings")
    .get();
  const categories = {};
  for (const doc of snapshot.docs) {
    const setting = doc.data();
    if (!setting.category || !setting.key) continue;
    categories[setting.category] = categories[setting.category] || {};
    categories[setting.category][setting.key] = setting.value;
  }
  return categories;
}

async function readUsersAndSettings(db, organizationEmail) {
  const snapshot = await db
    .collection(organizationEmail)
    .doc("users")
    .collection("users")
    .get();
  const users = snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
  const settingsById = new Map();
  const usersCollection = db
    .collection(organizationEmail)
    .doc("users")
    .collection("users");

  for (
    let index = 0;
    index < users.length;
    index += FIRESTORE_READ_BATCH_SIZE
  ) {
    const userBatch = users.slice(index, index + FIRESTORE_READ_BATCH_SIZE);
    const settingsDocs = await Promise.all(
      userBatch.map((user) =>
        usersCollection
          .doc(user.id)
          .collection("notification_settings")
          .doc("settings")
          .get(),
      ),
    );
    settingsDocs.forEach((settingsDoc, offset) => {
      if (settingsDoc.exists) {
        settingsById.set(userBatch[offset].id, settingsDoc.data());
      }
    });
  }
  return { users, settingsById };
}

async function sendOneSignal(ids, notification, apiKey) {
  const allIds = Array.from(ids);
  if (allIds.length === 0) return;
  for (let index = 0; index < allIds.length; index += 2000) {
    const response = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Key ${apiKey}`,
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_subscription_ids: allIds.slice(index, index + 2000),
        target_channel: "push",
        headings: { en: notification.title, ar: notification.title },
        contents: { en: notification.body, ar: notification.body },
        data: notification.data,
        android_sound: "default",
        android_priority: 10,
      }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || result.errors) {
      throw new Error(
        `OneSignal ${response.status}: ${JSON.stringify(result).slice(0, 500)}`,
      );
    }
  }
}

function makeNotification(kind, title, body, data, orgEmail) {
  return {
    title,
    body,
    data: {
      ...data,
      organization_email: orgEmail,
    },
  };
}

async function processCollection({
  db,
  orgEmail,
  settings,
  users,
  settingsById,
  collectionName,
  types,
  today,
  totals,
}) {
  const collectionSettings = settings[collectionName] || {};
  const alertsEnabledKey = `${collectionName}AlertsEnabled`;
  const pushEnabledKey = `${collectionName}AlertPushEnabled`;

  if (
    !asBool(collectionSettings[alertsEnabledKey], true) ||
    !asBool(collectionSettings[pushEnabledKey], true)
  ) {
    return totals;
  }

  let lastDocument = null;
  while (true) {
    await sleep(1000);
    let query = db.collectionGroup(collectionName).limit(FIRESTORE_PAGE_SIZE);
    if (lastDocument) query = query.startAfter(lastDocument);
    const page = await query.get();
    if (page.empty) break;
    lastDocument = page.docs[page.docs.length - 1];
    totals.scanned += page.size;

    for (const doc of page.docs) {
      try {
        const item = doc.data();
        const kindInfo = types.getNotificationKind(item, today);
        if (!kindInfo) {
          totals.skipped++;
          continue;
        }

        const typeKey = types.getTypeKey(kindInfo.kind);
        if (!asBool(collectionSettings[typeKey], true)) {
          totals.skipped++;
          continue;
        }

        const recipients = eligiblePlayerIds(
          users,
          settingsById,
          typeKey,
          kindInfo.daysRemaining,
        );
        if (recipients.size === 0) {
          totals.no_recipients++;
          continue;
        }

        const dateField = toDate(
          item[kindInfo.dateField || "createdAt"] || item.createdAt,
        );
        const endKey = dateKey(dateField || today);
        const eventKey = `${kindInfo.kind}_${keyHash(
          `${doc.id}_${endKey}_${orgEmail}`,
        )}`;
        const marker = db
          .collection(orgEmail)
          .doc("system")
          .collection("notificationSchedules")
          .doc(`${collectionName}_${eventKey}`);
        if ((await marker.get()).exists) {
          totals.duplicate++;
          continue;
        }

        await sendOneSignal(
          recipients,
          makeNotification(
            kindInfo.kind,
            kindInfo.title,
            kindInfo.body(item),
            {
              type: typeKey,
              [kindInfo.idField || "id"]: doc.id || "",
            },
            orgEmail,
          ),
          apiKey,
        );
        await marker.set({
          kind: kindInfo.kind,
          itemId: doc.id,
          date: admin.firestore.Timestamp.fromDate(dateField || today),
          organizationEmail: orgEmail,
          recipientCount: recipients.size,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        totals.sent++;
      } catch (error) {
        totals.errors++;
        console.error(
          `Failed ${collectionName} ${doc.ref.path}:`,
          error.message,
        );
      }
    }
    if (page.size < FIRESTORE_PAGE_SIZE) break;
  }
  return totals;
}

async function run() {
  const apiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!apiKey) {
    console.error("ONESIGNAL_REST_API_KEY environment variable is not set.");
    console.error("Please add it to GitHub Actions secrets.");
    process.exitCode = 1;
    return;
  }
  if (!admin.apps.length) {
    try {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
    } catch (err) {
      console.error("Failed to initialize Firebase Admin:", err.message);
      console.error(
        "Make sure GOOGLE_APPLICATION_CREDENTIALS is set or running on Google Cloud.",
      );
      process.exitCode = 1;
      return;
    }
  }
  const db = admin.firestore();
  const today = new Date();

  let grandTotals = {
    scanned: 0,
    sent: 0,
    skipped: 0,
    no_recipients: 0,
    duplicate: 0,
    errors: 0,
  };

  // ========== 1. SUBSCRIPTIONS ==========
  const subscriptionTypes = {
    getNotificationKind(item, today) {
      const endDate = toDate(item.endDate);
      if (
        !endDate ||
        ["cancelled", "suspended", "pending"].includes(item.status)
      ) {
        return null;
      }
      const daysRemaining = Math.round(
        (utcDay(endDate) - utcDay(today)) / 86400000,
      );
      if (daysRemaining < 0) {
        return {
          kind: "expired",
          daysRemaining,
          endDate,
          dateField: "endDate",
          title: "انتهى الاشتراك",
          body: (it) =>
            `انتهى اشتراك ${it.customerName || "المشترك"} (${
              it.name || ""
            }). يرجى مراجعة التجديد.`,
          idField: "id",
          typeKey: "subscription_alert_expired",
        };
      }
      if (item.status !== "active" || daysRemaining > MAX_WARNING_DAYS) {
        return null;
      }
      return {
        kind: "expiring",
        daysRemaining,
        endDate,
        dateField: "endDate",
        title: "تذكير بانتهاء الاشتراك",
        body: (it) =>
          `باقي ${daysRemaining} يوم على انتهاء اشتراك ${
            it.customerName || "المشترك"
          } (${it.name || ""}).`,
        idField: "id",
        typeKey: "subscription_alert_expiring_soon",
      };
    },
  };

  const orgEmails = new Set();
  let lastDoc = null;
  while (true) {
    await sleep(1000);
    let query = db.collectionGroup("subscriptions").limit(FIRESTORE_PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);
    const page = await query.get();
    if (page.empty) break;
    lastDoc = page.docs[page.docs.length - 1];
    grandTotals.scanned += page.size;
    for (const doc of page.docs) {
      const sub = doc.data();
      const oe = normalizeOrganizationEmail(sub.organizationEmail || "");
      if (oe.includes("@")) orgEmails.add(oe);
    }
    if (page.size < FIRESTORE_PAGE_SIZE) break;
  }

  for (const orgEmail of orgEmails) {
    await sleep(30000);
    const settings = await readSettings(db, orgEmail);
    const { users, settingsById } = await readUsersAndSettings(db, orgEmail);
    let lastDocument = null;
    while (true) {
    await sleep(1000);
      let query = db
        .collectionGroup("subscriptions")
        .limit(FIRESTORE_PAGE_SIZE);
      if (lastDocument) query = query.startAfter(lastDocument);
      const page = await query.get();
      if (page.empty) break;
      lastDocument = page.docs[page.docs.length - 1];

      for (const doc of page.docs) {
        const item = doc.data();
        if (
          normalizeOrganizationEmail(item.organizationEmail || "") !== orgEmail
        )
          continue;
        try {
          const kindInfo = subscriptionTypes.getNotificationKind(item, today);
          if (!kindInfo) {
            grandTotals.skipped++;
            continue;
          }
          const typeKey = kindInfo.typeKey;
          if (!asBool(settings.subscriptions[typeKey], true)) {
            grandTotals.skipped++;
            continue;
          }
          const recipients = eligiblePlayerIds(
            users,
            settingsById,
            typeKey,
            kindInfo.daysRemaining,
          );
          if (recipients.size === 0) {
            grandTotals.no_recipients++;
            continue;
          }
          const dateField = toDate(item.endDate);
          const endKey = dateKey(dateField || today);
          const eventKey = `${kindInfo.kind}_${keyHash(
            `${doc.id}_${endKey}_${orgEmail}`,
          )}`;
          const marker = db
            .collection(orgEmail)
            .doc("system")
            .collection("notificationSchedules")
            .doc(`subscription_${eventKey}`);
          if ((await marker.get()).exists) {
            grandTotals.duplicate++;
            continue;
          }
          await sendOneSignal(
            recipients,
            makeNotification(
              kindInfo.kind,
              kindInfo.title,
              kindInfo.body(item),
              { type: typeKey, subscription_id: doc.id || "" },
              orgEmail,
            ),
            apiKey,
          );
          await marker.set({
            kind: kindInfo.kind,
            subscriptionId: doc.id,
            endDate: admin.firestore.Timestamp.fromDate(dateField || today),
            daysRemaining: kindInfo.daysRemaining,
            organizationEmail: orgEmail,
            recipientCount: recipients.size,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          grandTotals.sent++;
        } catch (error) {
          grandTotals.errors++;
          console.error(`Failed subscription ${doc.ref.path}:`, error.message);
        }
      }
      if (page.size < FIRESTORE_PAGE_SIZE) break;
    }
  }

  // ========== 2. INVOICES ==========
  const invoiceTypes = [
    {
      name: "invoice_overdue",
      typeKey: "invoice_alert_overdue",
      collection: "invoices",
      dateField: "dueDate",
      kind: "overdue",
      title: "فاتورة متأخرة",
      bodyTemplate: (it) =>
        `فاتورة ${it.customerName || "العميل"} بمبلغ ${
          it.totalAmount || 0
        } د.ع متأخرة عن السداد.`,
    },
    {
      name: "invoice_new",
      typeKey: "invoice_notify_new",
      collection: "invoices",
      dateField: "createdAt",
      kind: "new",
      title: "فاتورة جديدة",
      bodyTemplate: (it) =>
        `تم إصدار فاتورة جديدة للعميل ${
          it.customerName || "العميل"
        } بمبلغ ${it.totalAmount || 0} د.ع.`,
    },
  ];

  for (const invType of invoiceTypes) {
    lastDoc = null;
    while (true) {
    await sleep(1000);
      let query = db.collectionGroup("invoices").limit(FIRESTORE_PAGE_SIZE);
      if (lastDoc) query = query.startAfter(lastDoc);
      const page = await query.get();
      if (page.empty) break;
      lastDoc = page.docs[page.docs.length - 1];
      grandTotals.scanned += page.size;

      for (const doc of page.docs) {
        try {
          const invoice = doc.data();
          const orgEmail = normalizeOrganizationEmail(
            invoice.organizationEmail || "",
          );
          if (!orgEmail.includes("@")) {
            grandTotals.skipped++;
            continue;
          }

          const settings = await readSettings(db, orgEmail);
          const invoiceSettings = settings.invoices || {};
          if (
            !asBool(invoiceSettings.invoiceAlertsEnabled, true) ||
            !asBool(invoiceSettings.invoiceAlertPushEnabled, true)
          ) {
            grandTotals.skipped++;
            continue;
          }

          if (invType.kind === "overdue") {
            if (!asBool(invoiceSettings.invoice_alert_overdue, true)) {
              grandTotals.skipped++;
              continue;
            }
          } else {
            if (!asBool(invoiceSettings.invoice_notify_new, true)) {
              grandTotals.skipped++;
              continue;
            }
          }

          const { users, settingsById } = await readUsersAndSettings(
            db,
            orgEmail,
          );
          const recipients = eligiblePlayerIds(
            users,
            settingsById,
            invType.typeKey,
            0,
          );
          if (recipients.size === 0) {
            grandTotals.no_recipients++;
            continue;
          }

          const dateField = toDate(invoice[invType.dateField]);
          const endKey = dateKey(dateField || today);
          const eventKey = `${invType.kind}_${keyHash(
            `${doc.id}_${endKey}_${orgEmail}`,
          )}`;
          const marker = db
            .collection(orgEmail)
            .doc("system")
            .collection("notificationSchedules")
            .doc(`invoice_${eventKey}`);
          if ((await marker.get()).exists) {
            grandTotals.duplicate++;
            continue;
          }

          await sendOneSignal(
            recipients,
            makeNotification(
              invType.typeKey,
              invType.title,
              invType.bodyTemplate(
                invoice.customerName || "العميل",
                invoice.totalAmount || 0,
              ),
              { type: invType.typeKey, invoice_id: doc.id || "" },
              orgEmail,
            ),
            apiKey,
          );
          await marker.set({
            kind: invType.kind,
            invoiceId: doc.id,
            date: admin.firestore.Timestamp.fromDate(dateField || today),
            organizationEmail: orgEmail,
            recipientCount: recipients.size,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          grandTotals.sent++;
        } catch (error) {
          grandTotals.errors++;
          console.error(`Failed invoice ${doc.ref.path}:`, error.message);
        }
      }
      if (page.size < FIRESTORE_PAGE_SIZE) break;
    }
  }

  // ========== 3. CUSTOMERS ==========
  const customerTypes = [
    {
      name: "customer_high_debt",
      typeKey: "customer_alert_high_debt",
      collection: "customers",
      title: "تنبيه ديون عميل",
      bodyTemplate: (it) =>
        `العميل "${it.name || "العميل"}" عليه مستحقات مرتفعة بمبلغ ${
          it.totalDebt || 0
        } د.ع`,
    },
    {
      name: "customer_credit_limit",
      typeKey: "customer_alert_credit_limit",
      collection: "customers",
      title: "تجاوز حد الائتمان",
      bodyTemplate: (it) =>
        `العميل "${it.name || "العميل"}" تجاوز حد الائتمان (${
          it.creditLimit || 0
        }). إجمالي الدين: ${it.totalDebt || 0}`,
    },
    {
      name: "customer_zero_balance",
      typeKey: "customer_notify_zero_balance",
      collection: "customers",
      title: "تصفير حساب عميل",
      bodyTemplate: (it) =>
        `تم تسديد كامل ديون العميل "${it.name || "العميل"}" وأصبح رصيد حسابه 0.00 د.ع`,
    },
    {
      name: "customer_new",
      typeKey: "customer_notify_new",
      collection: "customers",
      title: "تسجيل عميل جديد",
      bodyTemplate: (it) =>
        `تمت إضافة العميل "${it.name || "العميل"}" بنجاح إلى سجل العملاء`,
    },
  ];

  for (const custType of customerTypes) {
    lastDoc = null;
    while (true) {
    await sleep(1000);
      let query = db.collectionGroup("customers").limit(FIRESTORE_PAGE_SIZE);
      if (lastDoc) query = query.startAfter(lastDoc);
      const page = await query.get();
      if (page.empty) break;
      lastDoc = page.docs[page.docs.length - 1];
      grandTotals.scanned += page.size;

      for (const doc of page.docs) {
        try {
          const customer = doc.data();
          const orgEmail = normalizeOrganizationEmail(
            customer.organizationEmail || "",
          );
          if (!orgEmail.includes("@")) {
            grandTotals.skipped++;
            continue;
          }

          const settings = await readSettings(db, orgEmail);
          const customerSettings = settings.customers || {};
          if (
            !asBool(customerSettings.customerAlertsEnabled, true) ||
            !asBool(customerSettings.customerAlertPushEnabled, true)
          ) {
            grandTotals.skipped++;
            continue;
          }

          if (!asBool(customerSettings[custType.typeKey], true)) {
            grandTotals.skipped++;
            continue;
          }

          const { users, settingsById } = await readUsersAndSettings(
            db,
            orgEmail,
          );
          const recipients = eligiblePlayerIds(
            users,
            settingsById,
            custType.typeKey,
          );
          if (recipients.size === 0) {
            grandTotals.no_recipients++;
            continue;
          }

          const dateField = toDate(customer.createdAt || customer.updatedAt);
          const endKey = dateKey(dateField || today);
          const eventKey = `${custType.name}_${keyHash(
            `${doc.id}_${endKey}_${orgEmail}`,
          )}`;
          const marker = db
            .collection(orgEmail)
            .doc("system")
            .collection("notificationSchedules")
            .doc(`customer_${eventKey}`);
          if ((await marker.get()).exists) {
            grandTotals.duplicate++;
            continue;
          }

          await sendOneSignal(
            recipients,
            makeNotification(
              custType.typeKey,
              custType.title,
              custType.bodyTemplate(customer),
              { type: custType.typeKey, customer_id: doc.id || "" },
              orgEmail,
            ),
            apiKey,
          );
          await marker.set({
            kind: custType.name,
            customerId: doc.id,
            date: admin.firestore.Timestamp.fromDate(dateField || today),
            organizationEmail: orgEmail,
            recipientCount: recipients.size,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          grandTotals.sent++;
        } catch (error) {
          grandTotals.errors++;
          console.error(`Failed customer ${doc.ref.path}:`, error.message);
        }
      }
      if (page.size < FIRESTORE_PAGE_SIZE) break;
    }
  }

  // ========== 4. INVENTORY ==========
  const inventoryTypes = [
    {
      name: "inventory_out_of_stock",
      typeKey: "inventory_alert_out_of_stock",
      collection: "products",
      title: "نفاد كمية مادة",
      bodyTemplate: (it) =>
        `المادة "${it.name || "مادة"}" نفدت تماماً من المخزون!`,
    },
    {
      name: "inventory_low_stock",
      typeKey: "inventory_alert_low_stock",
      collection: "products",
      title: "تنبيه مخزون منخفض",
      bodyTemplate: (it) =>
        `المادة "${it.name || "مادة"}" متبقي منها كمية منخفضة من المخزون!`,
    },
    {
      name: "inventory_new",
      typeKey: "inventory_notify_new",
      collection: "products",
      title: "إضافة مادة جديدة",
      bodyTemplate: (it) =>
        `تمت إضافة المادة "${it.name || "مادة"}" إلى المخزون`,
    },
  ];

  for (const invType of inventoryTypes) {
    lastDoc = null;
    while (true) {
    await sleep(1000);
      let query = db.collectionGroup("products").limit(FIRESTORE_PAGE_SIZE);
      if (lastDoc) query = query.startAfter(lastDoc);
      const page = await query.get();
      if (page.empty) break;
      lastDoc = page.docs[page.docs.length - 1];
      grandTotals.scanned += page.size;

      for (const doc of page.docs) {
        try {
          const product = doc.data();
          const orgEmail = normalizeOrganizationEmail(
            product.organizationEmail || "",
          );
          if (!orgEmail.includes("@")) {
            grandTotals.skipped++;
            continue;
          }

          const settings = await readSettings(db, orgEmail);
          const inventorySettings = settings.inventory || {};
          if (
            !asBool(inventorySettings.inventoryAlertsEnabled, true) ||
            !asBool(inventorySettings.inventoryAlertPushEnabled, true)
          ) {
            grandTotals.skipped++;
            continue;
          }

          if (!asBool(inventorySettings[invType.typeKey], true)) {
            grandTotals.skipped++;
            continue;
          }

          const { users, settingsById } = await readUsersAndSettings(
            db,
            orgEmail,
          );
          const recipients = eligiblePlayerIds(
            users,
            settingsById,
            invType.typeKey,
          );
          if (recipients.size === 0) {
            grandTotals.no_recipients++;
            continue;
          }

          const dateField = toDate(product.createdAt || product.updatedAt);
          const endKey = dateKey(dateField || today);
          const eventKey = `${invType.name}_${keyHash(
            `${doc.id}_${endKey}_${orgEmail}`,
          )}`;
          const marker = db
            .collection(orgEmail)
            .doc("system")
            .collection("notificationSchedules")
            .doc(`inventory_${eventKey}`);
          if ((await marker.get()).exists) {
            grandTotals.duplicate++;
            continue;
          }

          await sendOneSignal(
            recipients,
            makeNotification(
              invType.typeKey,
              invType.title,
              invType.bodyTemplate(product.name || "مادة"),
              { type: invType.typeKey, product_id: doc.id || "" },
              orgEmail,
            ),
            apiKey,
          );
          await marker.set({
            kind: invType.name,
            productId: doc.id,
            date: admin.firestore.Timestamp.fromDate(dateField || today),
            organizationEmail: orgEmail,
            recipientCount: recipients.size,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          grandTotals.sent++;
        } catch (error) {
          grandTotals.errors++;
          console.error(`Failed product ${doc.ref.path}:`, error.message);
        }
      }
      if (page.size < FIRESTORE_PAGE_SIZE) break;
    }
  }

  // ========== 5. MAINTENANCE ==========
  const maintenanceTypes = [
    {
      name: "maintenance_overdue",
      typeKey: "maintenance_alert_overdue",
      collection: "maintenance_requests",
      title: "صيانة متأخرة",
      bodyTemplate: (it) =>
        `طلب الصيانة "${it.title || "طلب صيانة"}" للعميل ${
          it.customerName || "العميل"
        } متأخر عن موعده المجدول`,
    },
    {
      name: "maintenance_urgent",
      typeKey: "maintenance_alert_urgent",
      collection: "maintenance_requests",
      title: "طلب صيانة عاجل",
      bodyTemplate: (it) =>
        `طلب الصيانة "${it.title || "طلب صيانة"}" للعميل ${
          it.customerName || "العميل"
        } بحالة عاجلة وبحاجة للمتابعة`,
    },
    {
      name: "maintenance_new",
      typeKey: "maintenance_notify_new",
      collection: "maintenance_requests",
      title: "طلب صيانة جديد",
      bodyTemplate: (it) =>
        `تم تسجيل طلب صيانة جديد "${
          it.title || "طلب صيانة"
        }" للعميل ${it.customerName || "العميل"}`,
    },
    {
      name: "maintenance_completed",
      typeKey: "maintenance_notify_completed",
      collection: "maintenance_requests",
      title: "اكتمال صيانة",
      bodyTemplate: (it) =>
        `اكتملت أعمال الصيانة لطلب "${
          it.title || "طلب صيانة"
        }" للعميل ${it.customerName || "العميل"} وجاهز للتسليم`,
    },
  ];

  for (const maintType of maintenanceTypes) {
    lastDoc = null;
    while (true) {
    await sleep(1000);
      let query = db
        .collectionGroup("maintenance_requests")
        .limit(FIRESTORE_PAGE_SIZE);
      if (lastDoc) query = query.startAfter(lastDoc);
      const page = await query.get();
      if (page.empty) break;
      lastDoc = page.docs[page.docs.length - 1];
      grandTotals.scanned += page.size;

      for (const doc of page.docs) {
        try {
          const request = doc.data();
          const orgEmail = normalizeOrganizationEmail(
            request.organizationEmail || "",
          );
          if (!orgEmail.includes("@")) {
            grandTotals.skipped++;
            continue;
          }

          const settings = await readSettings(db, orgEmail);
          const maintenanceSettings = settings.maintenance || {};
          if (
            !asBool(maintenanceSettings.maintenanceAlertsEnabled, true) ||
            !asBool(maintenanceSettings.maintenanceAlertPushEnabled, true)
          ) {
            grandTotals.skipped++;
            continue;
          }

          if (!asBool(maintenanceSettings[maintType.typeKey], true)) {
            grandTotals.skipped++;
            continue;
          }

          const { users, settingsById } = await readUsersAndSettings(
            db,
            orgEmail,
          );
          const recipients = eligiblePlayerIds(
            users,
            settingsById,
            maintType.typeKey,
          );
          if (recipients.size === 0) {
            grandTotals.no_recipients++;
            continue;
          }

          const dateField = toDate(request.scheduledDate || request.createdAt);
          const endKey = dateKey(dateField || today);
          const eventKey = `${maintType.name}_${keyHash(
            `${doc.id}_${endKey}_${orgEmail}`,
          )}`;
          const marker = db
            .collection(orgEmail)
            .doc("system")
            .collection("notificationSchedules")
            .doc(`maintenance_${eventKey}`);
          if ((await marker.get()).exists) {
            grandTotals.duplicate++;
            continue;
          }

          await sendOneSignal(
            recipients,
            makeNotification(
              maintType.typeKey,
              maintType.title,
              maintType.bodyTemplate(
                request.customerName || "العميل",
                request.title || "طلب صيانة",
              ),
              { type: maintType.typeKey, request_id: doc.id || "" },
              orgEmail,
            ),
            apiKey,
          );
          await marker.set({
            kind: maintType.name,
            requestId: doc.id,
            date: admin.firestore.Timestamp.fromDate(dateField || today),
            organizationEmail: orgEmail,
            recipientCount: recipients.size,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          grandTotals.sent++;
        } catch (error) {
          grandTotals.errors++;
          console.error(`Failed maintenance ${doc.ref.path}:`, error.message);
        }
      }
      if (page.size < FIRESTORE_PAGE_SIZE) break;
    }
  }

  // ========== 6. RENTALS ==========
  const rentalTypes = [
    {
      name: "rental_expired",
      typeKey: "rental_alert_expired",
      collection: "rentals",
      title: "تأجير متأخر",
      bodyTemplate: (it) =>
        `عقد تأجير ${it.customerName || "المستأجر"} متأخر عن موعد الإرجاع`,
    },
    {
      name: "rental_expiring_soon",
      typeKey: "rental_alert_expiring_soon",
      collection: "rentals",
      title: "تنبيه انتهاء تأجير",
      bodyTemplate: (it) =>
        `عقد تأجير ${it.customerName || "المستأجر"} سينتهي قريباً`,
    },
    {
      name: "rental_new",
      typeKey: "rental_notify_new",
      collection: "rentals",
      title: "عقد تأجير جديد",
      bodyTemplate: (it) =>
        `تم إبرام عقد تأجير جديد للمستأجر ${it.customerName || "المستأجر"}`,
    },
    {
      name: "rental_returned",
      typeKey: "rental_notify_returned",
      collection: "rentals",
      title: "إرجاع تأجير",
      bodyTemplate: (it) =>
        `تم تأكيد إرجاع المادة للمستأجر ${it.customerName || "المستأجر"} بنجاح`,
    },
  ];

  for (const rentType of rentalTypes) {
    lastDoc = null;
    while (true) {
    await sleep(1000);
      let query = db.collectionGroup("rentals").limit(FIRESTORE_PAGE_SIZE);
      if (lastDoc) query = query.startAfter(lastDoc);
      const page = await query.get();
      if (page.empty) break;
      lastDoc = page.docs[page.docs.length - 1];
      grandTotals.scanned += page.size;

      for (const doc of page.docs) {
        try {
          const rental = doc.data();
          const orgEmail = normalizeOrganizationEmail(
            rental.organizationEmail || "",
          );
          if (!orgEmail.includes("@")) {
            grandTotals.skipped++;
            continue;
          }

          const settings = await readSettings(db, orgEmail);
          const rentalSettings = settings.rentals || {};
          if (
            !asBool(rentalSettings.rentalAlertsEnabled, true) ||
            !asBool(rentalSettings.rentalAlertPushEnabled, true)
          ) {
            grandTotals.skipped++;
            continue;
          }

          if (!asBool(rentalSettings[rentType.typeKey], true)) {
            grandTotals.skipped++;
            continue;
          }

          const { users, settingsById } = await readUsersAndSettings(
            db,
            orgEmail,
          );
          const recipients = eligiblePlayerIds(
            users,
            settingsById,
            rentType.typeKey,
          );
          if (recipients.size === 0) {
            grandTotals.no_recipients++;
            continue;
          }

          const dateField = toDate(rental.endDate || rental.createdAt);
          const endKey = dateKey(dateField || today);
          const eventKey = `${rentType.name}_${keyHash(
            `${doc.id}_${endKey}_${orgEmail}`,
          )}`;
          const marker = db
            .collection(orgEmail)
            .doc("system")
            .collection("notificationSchedules")
            .doc(`rental_${eventKey}`);
          if ((await marker.get()).exists) {
            grandTotals.duplicate++;
            continue;
          }

          await sendOneSignal(
            recipients,
            makeNotification(
              rentType.typeKey,
              rentType.title,
              rentType.bodyTemplate(rental),
              { type: rentType.typeKey, rental_id: doc.id || "" },
              orgEmail,
            ),
            apiKey,
          );
          await marker.set({
            kind: rentType.name,
            rentalId: doc.id,
            date: admin.firestore.Timestamp.fromDate(dateField || today),
            organizationEmail: orgEmail,
            recipientCount: recipients.size,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          grandTotals.sent++;
        } catch (error) {
          grandTotals.errors++;
          console.error(`Failed rental ${doc.ref.path}:`, error.message);
        }
      }
      if (page.size < FIRESTORE_PAGE_SIZE) break;
    }
  }

  // ========== 7. EXPENSES ==========
  const expenseTypes = [
    {
      name: "expense_pending",
      typeKey: "expenses_alert_pending",
      collection: "expenses",
      title: "تنبيه مصروفات معلقة",
      bodyTemplate: (it) =>
        `المصروف "${it.title || "مصروف"}" بمبلغ ${
          it.amount || 0
        } د.ع بانتظار المراجعة والاعتماد`,
    },
    {
      name: "expense_new",
      typeKey: "expenses_notify_new",
      collection: "expenses",
      title: "تسجيل سند صرف",
      bodyTemplate: (it) =>
        `تم تسجيل مصروف جديد "${
          it.title || "مصروف"
        }" بمبلغ ${it.amount || 0} د.ع`,
    },
    {
      name: "expense_overbudget",
      typeKey: "expenses_alert_overbudget",
      collection: "expenses",
      title: "تجاوز الميزانية",
      bodyTemplate: (it) =>
        `فئة "${it.category || ""}" تجاوزت الميزانية بـ ${
          it.exceeded || 0
        } د.ع (الميزانية: ${it.budget || 0} د.ع)`,
    },
  ];

  for (const expType of expenseTypes) {
    lastDoc = null;
    while (true) {
    await sleep(1000);
      let query = db.collectionGroup("expenses").limit(FIRESTORE_PAGE_SIZE);
      if (lastDoc) query = query.startAfter(lastDoc);
      const page = await query.get();
      if (page.empty) break;
      lastDoc = page.docs[page.docs.length - 1];
      grandTotals.scanned += page.size;

      for (const doc of page.docs) {
        try {
          const expense = doc.data();
          const orgEmail = normalizeOrganizationEmail(
            expense.organizationEmail || "",
          );
          if (!orgEmail.includes("@")) {
            grandTotals.skipped++;
            continue;
          }

          const settings = await readSettings(db, orgEmail);
          const expenseSettings = settings.expenses || {};
          if (
            !asBool(expenseSettings.expensesAlertsEnabled, true) ||
            !asBool(expenseSettings.expensesAlertPushEnabled, true)
          ) {
            grandTotals.skipped++;
            continue;
          }

          if (!asBool(expenseSettings[expType.typeKey], true)) {
            grandTotals.skipped++;
            continue;
          }

          const { users, settingsById } = await readUsersAndSettings(
            db,
            orgEmail,
          );
          const recipients = eligiblePlayerIds(
            users,
            settingsById,
            expType.typeKey,
          );
          if (recipients.size === 0) {
            grandTotals.no_recipients++;
            continue;
          }

          const dateField = toDate(expense.date || expense.createdAt);
          const endKey = dateKey(dateField || today);
          const eventKey = `${expType.name}_${keyHash(
            `${doc.id}_${endKey}_${orgEmail}`,
          )}`;
          const marker = db
            .collection(orgEmail)
            .doc("system")
            .collection("notificationSchedules")
            .doc(`expense_${eventKey}`);
          if ((await marker.get()).exists) {
            grandTotals.duplicate++;
            continue;
          }

          await sendOneSignal(
            recipients,
            makeNotification(
              expType.typeKey,
              expType.title,
              expType.bodyTemplate(expense),
              { type: expType.typeKey, expense_id: doc.id || "" },
              orgEmail,
            ),
            apiKey,
          );
          await marker.set({
            kind: expType.name,
            expenseId: doc.id,
            date: admin.firestore.Timestamp.fromDate(dateField || today),
            organizationEmail: orgEmail,
            recipientCount: recipients.size,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          grandTotals.sent++;
        } catch (error) {
          grandTotals.errors++;
          console.error(`Failed expense ${doc.ref.path}:`, error.message);
        }
      }
      if (page.size < FIRESTORE_PAGE_SIZE) break;
    }
  }

  console.log("All notifications run:", JSON.stringify(grandTotals));
  if (grandTotals.errors > 0) process.exitCode = 1;
}

if (require.main === module) {
  run().catch((error) => {
    console.error("All notifications job failed:", error);
    process.exitCode = 1;
  });
}

module.exports = {
  normalizeOrganizationEmail,
  toDate,
  utcDay,
  dateKey,
  asBool,
  eligiblePlayerIds,
  makeNotification,
};
