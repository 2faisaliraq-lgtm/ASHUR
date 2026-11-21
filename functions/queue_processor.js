const admin = require("firebase-admin");
const crypto = require("node:crypto");

const ONESIGNAL_APP_ID = "e309b00d-2d36-4285-ac55-f7b5831d731d";
const FIRESTORE_PAGE_SIZE = 10;
const QUEUE_COLLECTION = "notifications";
const QUEUE_SUBCOLLECTION = "queue";

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
  if (allIds.length === 0) return { sent: 0, skipped: 0 };
  let sent = 0;
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
    if (response.ok) {
      sent += allIds.slice(index, index + 10).length;
    }
    await sleep(1000);
  }
  return { sent, skipped: allIds.length - sent };
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

async function processQueue(db, orgEmail, apiKey, totals) {
  const queueRef = db.collection(orgEmail).doc(QUEUE_COLLECTION).collection(QUEUE_SUBCOLLECTION);
  let lastDocument = null;
  let processed = 0;

  while (true) {
    let query = queueRef.limit(FIRESTORE_PAGE_SIZE).orderBy("createdAt", "asc");
    if (lastDocument) query = query.startAfter(lastDocument);
    const page = await query.get();
    if (page.empty) break;
    lastDocument = page.docs[page.docs.length - 1];

    const batch = db.batch();
    let batchCount = 0;

    for (const doc of page.docs) {
      const item = doc.data();
      try {
        const scheduledAt = toDate(item.scheduledAt);
        const now = new Date();
        if (scheduledAt && scheduledAt > now) continue;

        const { users, settingsById } = await readUsersAndSettings(db, orgEmail);
        const result = await sendOneSignal(
          eligiblePlayerIds(users, settingsById, item.type || "test_notification"),
          {
            title: item.title || "إشعار",
            body: item.body || "",
            data: item.data || { type: item.type || "test_notification", organization_email: orgEmail },
          },
          apiKey
        );
        totals.sent += result.sent;
        totals.skipped += result.skipped;
        processed++;

        batch.delete(doc.reference);
        batchCount++;
      } catch (error) {
        console.error(`Failed queue item ${doc.ref.path}:`, error.message);
        totals.errors++;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    await sleep(1000);
    if (page.size < FIRESTORE_PAGE_SIZE) break;
  }

  totals.processed += processed;
  return processed;
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

  let grandTotals = { scanned: 0, sent: 0, skipped: 0, no_recipients: 0, duplicate: 0, errors: 0, processed: 0 };

  const orgEmails = new Set();

  let lastDocument = null;
  while (true) {
    let query = db.collectionGroup(QUEUE_SUBCOLLECTION).limit(FIRESTORE_PAGE_SIZE);
    if (lastDocument) query = query.startAfter(lastDocument);
    const page = await query.get();
    if (page.empty) break;
    lastDocument = page.docs[page.docs.length - 1];

    for (const doc of page.docs) {
      const item = doc.data();
      const oe = normalizeOrganizationEmail(item.organizationEmail || "");
      if (!oe.includes("@")) continue;
      orgEmails.add(oe);
    }

    await sleep(1000);
    if (page.size < FIRESTORE_PAGE_SIZE) break;
  }

  for (const orgEmail of orgEmails) {
    await sleep(5000);
    await processQueue(db, orgEmail, apiKey, grandTotals);
  }

  console.log("Queue processor run completed", grandTotals);
}

if (require.main === module) {
  run().catch((error) => {
    console.error("Queue processor job failed:", error);
    process.exitCode = 1;
  });
}

module.exports = {
  normalizeOrganizationEmail,
  toDate,
  asBool,
  eligiblePlayerIds,
};
