const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeOrganizationEmail,
  getNotificationKind,
  dateKey,
  eligiblePlayerIds,
  makeNotification,
} = require("./subscription_expiry_notifier");

const today = new Date("2026-11-19T09:00:00.000Z");

test("normalizes organization email consistently with the app", () => {
  assert.equal(normalizeOrganizationEmail("a.hmed+shop@gmail.com"), "ahmed@gmail.com");
  assert.equal(normalizeOrganizationEmail("User@example.com"), "user@example.com");
});

test("uses Iraq local calendar day around UTC midnight", () => {
  assert.equal(dateKey(new Date("2026-11-19T21:30:00.000Z")), "2026-11-20");
  const result = getNotificationKind({
    status: "active",
    endDate: new Date("2026-11-20T21:30:00.000Z"),
  }, new Date("2026-11-19T21:30:00.000Z"));
  assert.equal(result.daysRemaining, 1);
});

test("finds a selected upcoming expiry day", () => {
  const result = getNotificationKind({
    status: "active",
    endDate: new Date("2026-11-22T00:00:00.000Z"),
  }, today);
  assert.equal(result.kind, "expiring");
  assert.equal(result.daysRemaining, 3);
});

test("marks a past active subscription expired for a one-time notice", () => {
  const result = getNotificationKind({
    status: "active",
    endDate: new Date("2026-11-18T00:00:00.000Z"),
  }, today);
  assert.equal(result.kind, "expired");
  assert.equal(result.daysRemaining, -1);
});

test("excludes cancelled subscriptions and respects per-user settings", () => {
  assert.equal(getNotificationKind({
    status: "cancelled",
    endDate: new Date("2026-11-22T00:00:00.000Z"),
  }, today), null);

  const users = [
    { id: "enabled", data: { oneSignalPlayerId: "player-1" } },
    { id: "disabled", data: { oneSignalPlayerId: "player-2" } },
  ];
  const settings = new Map([
    ["enabled", {
      enableNotifications: true,
      enablePushNotifications: true,
      subscription_alert_expiring_soon: true,
      warningDays: [3],
    }],
    ["disabled", {
      enableNotifications: false,
      enablePushNotifications: true,
      subscription_alert_expiring_soon: true,
      warningDays: [3],
    }],
  ]);
  assert.deepEqual(
    [...eligiblePlayerIds(users, settings, "expiring", 3)],
    ["player-1"],
  );
});

test("builds Arabic expiry notification and route data", () => {
  const result = makeNotification(
    { id: "sub-1", customerName: "علي", name: "شهري" },
    { kind: "expiring", daysRemaining: 3 },
    "ashur@example.com",
  );
  assert.equal(result.title, "تذكير بانتهاء الاشتراك");
  assert.match(result.body, /3 يوم/);
  assert.equal(result.data.subscription_id, "sub-1");
});
