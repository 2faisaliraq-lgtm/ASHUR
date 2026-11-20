const admin = require("firebase-admin");
const crypto = require("node:crypto");

const ONESIGNAL_APP_ID = "e309b00d-2d36-4285-ac55-f7b5831d731d";
const FIRESTORE_PAGE_SIZE = 3;

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
    ["gmail.com", "googlemail.com", "outlook.com", "hotmail.com", "live.com", "yahoo.com", "icloud.com", "me.com"].includes(domain)
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
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Baghdad", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(date);
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return { year: Number(values.year), month: Number(values.month), day: Number(values.day) };
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

function eligiblePlayerIds(users, userSettingsById, typeKey) {
  const ids = new Set();
  for (const user of users) {
    const data = user.data || {};
    if (data.isActive === false || data.notificationEnabled === false) continue;
    const settings = userSettingsById.get(user.id) || {};
    if (!asBool(settings.enableNotifications, false) || !asBool(settings.enablePushNotifications, false)) continue;
    if (!asBool(settings[typeKey], false)) continue;
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
  const snapshot = await db.collection(organizationEmail).doc("settings").collection("settings").get();
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
  const snapshot = await db.collection(organizationEmail).doc("users").collection("users").get();
  const users = snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
  const settingsById = new Map();
  const usersCollection = db.collection(organizationEmail).doc("users").collection("users");
  for (let index = 0; index < users.length; index += 5) {
    const userBatch = users.slice(index, index + 5);
    const settingsDocs = await Promise.all(userBatch.map((user) => usersCollection.doc(user.id).collection("notification_settings").doc("settings").get()));
    settingsDocs.forEach((settingsDoc, offset) => {
      if (settingsDoc.exists) settingsById.set(userBatch[offset].id, settingsDoc.data());
    });
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
  return { users, settingsById };
}

async function sendOneSignal(ids, notification, apiKey) {
  const allIds = Array.from(ids);
  if (allIds.length === 0) return;
  for (let index = 0; index < allIds.length; index += 10) {
    const response = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=utf-8", Authorization: `Key ${apiKey}` },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_player_ids: allIds.slice(index, index + 10),
        headings: { en: notification.title, ar: notification.title },
        contents: { en: notification.body, ar: notification.body },
        data: notification.data,
        android_sound: "default",
        android_priority: 10,
      }),
    });
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
}

async function run() {
  const apiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!apiKey) {
    console.error("ONESIGNAL_REST_API_KEY environment variable is not set.");
    process.exitCode = 1;
    return;
  }
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.applicationDefault() });
  const db = admin.firestore();
  const today = new Date();

  let grandTotals = { scanned: 0, sent: 0, skipped: 0, no_recipients: 0, duplicate: 0, errors: 0 };

  // Get unique organization emails from subscriptions
  const orgEmails = new Set();
  let lastDocument = null;
  while (true) {
    let query = db.collectionGroup("subscriptions").limit(5);
    if (lastDocument) query = query.startAfter(lastDocument);
    const page = await query.get();
    if (page.empty) break;
    lastDocument = page.docs[page.docs.length - 1];
    for (const doc of page.docs) {
      const sub = doc.data();
      const oe = normalizeOrganizationEmail(sub.organizationEmail || "");
      if (oe.includes("@")) orgEmails.add(oe);
    }
    await new Promise(resolve => setTimeout(resolve, 5000));
    if (page.size < FIRESTORE_PAGE_SIZE) break;
  }

  for (const orgEmail of orgEmails) {
    await sleep(30000);
    const settings = await readSettings(db, orgEmail);
    const { users, settingsById } = await readUsersAndSettings(db, orgEmail);
    
    let lastDocument = null;
    while (true) {
      await sleep(1000);
      let query = db.collectionGroup("subscriptions").limit(FIRESTORE_PAGE_SIZE);
      if (lastDocument) query = query.startAfter(lastDocument);
      const page = await query.get();
      if (page.empty) break;
      lastDocument = page.docs[page.docs.length - 1];
      
      for (const doc of page.docs) {
        const item = doc.data();
        if (normalizeOrganizationEmail(item.organizationEmail || "") !== orgEmail) continue;
        try {
          const endDate = toDate(item.endDate);
          if (!endDate || ["cancelled", "suspended", "pending"].includes(item.status)) continue;
          const daysRemaining = Math.round((utcDay(endDate) - utcDay(today)) / 86400000);
          if (daysRemaining < 0) {
            await sendOneSignal(
              await getPlayerIds(db, orgEmail, "subscription_alert_expired"),
              {
                title: "انتهى الاشتراك",
                body: `انتهى اشتراك ${item.customerName || "المشترك"} (${item.name || ""}). يرجى مراجعة التجديد.`,
                data: { type: "subscription_alert_expired", subscription_id: doc.id || "", organization_email: orgEmail },
              },
              apiKey
            );
          } else if (item.status === "active" && daysRemaining <= MAX_WARNING_DAYS) {
            await sendOneSignal(
              await getPlayerIds(db, orgEmail, "subscription_alert_expiring_soon"),
              {
                title: "تذكير بانتهاء الاشتراك",
                body: `باقي ${daysRemaining} يوم على انتهاء اشتراك ${item.customerName || "المشترك"} (${item.name || ""}).`,
                data: { type: "subscription_alert_expiring_soon", subscription_id: doc.id || "", organization_email: orgEmail },
              },
              apiKey
            );
          }
        } catch (error) {
          console.error(`Failed subscription ${doc.ref.path}:`, error.message);
        }
      }
      if (page.size < FIRESTORE_PAGE_SIZE) break;
    }
  }

  console.log("All notifications run completed");
}

async function getPlayerIds(db, orgEmail, typeKey) {
  const ids = new Set();
  const snapshot = await db.collection(organizationEmail).doc("users").collection("users").get();
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    if (data.isActive === false || data.notificationEnabled === false) continue;
    const settingsDoc = await db.collection(organizationEmail).doc("users").collection("users").doc(doc.id).collection("notification_settings").doc("settings").get();
    const settings = settingsDoc.exists ? settingsDoc.data() || {} : {};
    if (!asBool(settings.enableNotifications, false) || !asBool(settings.enablePushNotifications, false)) continue;
    if (!asBool(settings[typeKey], false)) continue;
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

async function run() {
  const apiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!apiKey) {
    console.error("ONESIGNAL_REST_API_KEY environment variable is not set.");
    process.exitCode = 1;
    return;
  }
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.applicationDefault() });
  const db = admin.firestore();
  const today = new Date();

  let grandTotals = { scanned: 0, sent: 0, skipped: 0, no_recipients: 0, duplicate: 0, errors: 0 };

  const orgEmails = new Set();
  let lastDocument = null;
  while (true) {
    let query = db.collectionGroup("subscriptions").limit(5);
    if (lastDocument) query = query.startAfter(lastDocument);
    const page = await query.get();
    if (page.empty) break;
    lastDocument = page.docs[page.docs.length - 1];
    for (const doc of page.docs) {
      const sub = doc.data();
      const oe = normalizeOrganizationEmail(sub.organizationEmail || "");
      if (oe.includes("@")) orgEmails.add(oe);
    }
    await new Promise(resolve => setTimeout(resolve, 5000));
    if (page.size < FIRESTORE_PAGE_SIZE) break;
  }

  for (const orgEmail of orgEmails) {
    await sleep(30000);
    const settings = await readSettings(db, orgEmail);
    const { users, settingsById } = await readUsersAndSettings(db, orgEmail);
    
    let lastDocument = null;
    while (true) {
      await sleep(1000);
      let query = db.collectionGroup("subscriptions").limit(FIRESTORE_PAGE_SIZE);
      if (lastDocument) query = query.startAfter(lastDocument);
      const page = await query.get();
      if (page.empty) break;
      lastDocument = page.docs[page.docs.length - 1];
      
      for (const doc of page.docs) {
        const item = doc.data();
        if (normalizeOrganizationEmail(item.organizationEmail || "") !== orgEmail) continue;
        try {
          const endDate = toDate(item.endDate);
          if (!endDate || ["cancelled", "suspended", "pending"].includes(item.status)) continue;
          const daysRemaining = Math.round((utcDay(endDate) - utcDay(today)) / 86400000);
          if (daysRemaining < 0) {
            await sendOneSignal(
              await getPlayerIds(db, orgEmail, "subscription_alert_expired"),
              {
                title: "انتهى الاشتراك",
                body: `انتهى اشتراك ${item.customerName || "المشترك"} (${item.name || ""}). يرجى مراجعة التجديد.`,
                data: { type: "subscription_alert_expired", subscription_id: doc.id || "", organization_email: orgEmail },
              },
              apiKey
            );
          } else if (item.status === "active" && daysRemaining <= MAX_WARNING_DAYS) {
            await sendOneSignal(
              await getPlayerIds(db, orgEmail, "subscription_alert_expiring_soon"),
              {
                title: "تذكير بانتهاء الاشتراك",
                body: `باقي ${daysRemaining} يوم على انتهاء اشتراك ${item.customerName || "المشترك"} (${item.name || ""}).`,
                data: { type: "subscription_alert_expiring_soon", subscription_id: doc.id || "", organization_email: orgEmail },
              },
              apiKey
            );
          }
        } catch (error) {
          console.error(`Failed subscription ${doc.ref.path}:`, error.message);
        }
      }
      if (page.size < FIRESTORE_PAGE_SIZE) break;
    }
  }

  console.log("All notifications run completed");
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