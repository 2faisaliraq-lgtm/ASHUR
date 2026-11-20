const admin = require("firebase-admin");
const crypto = require("node:crypto");

const ONESIGNAL_APP_ID = "e309b00d-2d36-4285-ac55-f7b5831d731d";
const FIRESTORE_PAGE_SIZE = 10;
const MAX_WARNING_DAYS = 7;

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
    await sleep(1000);
  }
}

const userSettingsCache = new Map();

async function readUsersAndSettings(db, organizationEmail) {
  const cached = userSettingsCache.get(organizationEmail);
  if (cached) return cached;

  const snapshot = await db.collection(organizationEmail).doc("users").collection("users").get();
  const users = snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
  const settingsById = new Map();
  const usersCollection = db.collection(organizationEmail).doc("users").collection("users");
  for (let index = 0; index < users.length; index += 10) {
    const userBatch = users.slice(index, index + 10);
    const settingsDocs = await Promise.all(userBatch.map((user) => usersCollection.doc(user.id).collection("notification_settings").doc("settings").get()));
    settingsDocs.forEach((settingsDoc, offset) => {
      if (settingsDoc.exists) settingsById.set(userBatch[offset].id, settingsDoc.data());
    });
    await sleep(1000);
  }
  const result = { users, settingsById };
  userSettingsCache.set(organizationEmail, result);
  return result;
}

async function getPlayerIds(db, orgEmail, typeKey) {
  const { users, settingsById } = await readUsersAndSettings(db, orgEmail);
  return eligiblePlayerIds(users, settingsById, typeKey);
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
  const orgSubscriptions = new Map();

  let lastDocument = null;
  while (true) {
    let query = db.collectionGroup("subscriptions").limit(FIRESTORE_PAGE_SIZE);
    if (lastDocument) query = query.startAfter(lastDocument);
    const page = await query.get();
    if (page.empty) break;
    lastDocument = page.docs[page.docs.length - 1];

    for (const doc of page.docs) {
      const item = doc.data();
      const oe = normalizeOrganizationEmail(item.organizationEmail || "");
      if (!oe.includes("@")) continue;

      orgEmails.add(oe);
      if (!orgSubscriptions.has(oe)) orgSubscriptions.set(oe, []);
      orgSubscriptions.get(oe).push({ doc, item });
    }

    await sleep(1000);
    if (page.size < FIRESTORE_PAGE_SIZE) break;
  }

  for (const orgEmail of orgEmails) {
    await sleep(5000);
    const subs = orgSubscriptions.get(orgEmail) || [];
    const { users, settingsById } = await readUsersAndSettings(db, orgEmail);

    for (const { doc, item } of subs) {
      try {
        const endDate = toDate(item.endDate);
        if (!endDate || ["cancelled", "suspended", "pending"].includes(item.status)) continue;
        const daysRemaining = Math.round((utcDay(endDate) - utcDay(today)) / 86400000);
        if (daysRemaining < 0) {
          await sendOneSignal(
            eligiblePlayerIds(users, settingsById, "subscription_alert_expired"),
            {
              title: "انتهى الاشتراك",
              body: `انتهى اشتراك ${item.customerName || "المشترك"} (${item.name || ""}). يرجى مراجعة التجديد.`,
              data: { type: "subscription_alert_expired", subscription_id: doc.id || "", organization_email: orgEmail },
            },
            apiKey
          );
        } else if (item.status === "active" && daysRemaining <= MAX_WARNING_DAYS) {
          await sendOneSignal(
            eligiblePlayerIds(users, settingsById, "subscription_alert_expiring_soon"),
            {
              title: "تذكير بانتهاء الاشتراك",
              body: `باقي ${daysRemaining} يوم على انتهاء اشتراك ${item.customerName || "المشترك"} (${item.name || ""}).`,
              data: { type: "subscription_alert_expiring_soon", subscription_id: doc.id || "", organization_email: orgEmail },
            },
            apiKey
          );
        }
        grandTotals.scanned++;
      } catch (error) {
        console.error(`Failed subscription ${doc.ref.path}:`, error.message);
        grandTotals.errors++;
      }
    }
  }

  console.log("All notifications run completed", grandTotals);
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
  asBool,
  eligiblePlayerIds,
};
