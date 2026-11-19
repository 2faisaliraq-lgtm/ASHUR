const assert = require("assert");
const {
  normalizeOrganizationEmail,
  getRecipientPlayerIds,
  canPerformNotificationAction,
  canPerformActingNotificationAction,
  isSettingEnabled,
} = require("./notification_utils");

const allowedNotificationTypes = new Set([
  "invoice_created", "invoice_updated", "invoice_deleted", "invoice_paid",
  "invoice_cash", "customer_cash_invoice", "inventory_product_created",
  "inventory_product_deleted", "inventory_quantity_updated", "customer_created",
  "customer_updated", "customer_deleted", "customer_zero_balance",
  "maintenance_created", "maintenance_updated", "maintenance_deleted",
  "maintenance_completed", "rental_created", "rental_updated", "rental_deleted",
  "rental_returned", "expense_created", "expense_updated", "expense_deleted",
  "subscription_created", "subscription_updated", "subscription_deleted",
  "subscription_renewed",
]);
const preferenceKeys = {
  invoice_created: "invoice_notify_new", invoice_updated: "invoice_notify_updated",
  invoice_deleted: "invoice_notify_deleted", invoice_paid: "invoice_notify_paid",
  invoice_cash: "invoice_notify_cash", customer_cash_invoice: "customer_notify_cash_invoice",
  inventory_product_created: "inventory_notify_new", inventory_product_deleted: "inventory_notify_deleted",
  inventory_quantity_updated: "inventory_notify_quantity_update", customer_created: "customer_notify_new",
  customer_updated: "customer_notify_updated", customer_deleted: "customer_notify_deleted",
  customer_zero_balance: "customer_notify_zero_balance", maintenance_created: "maintenance_notify_new",
  maintenance_updated: "maintenance_notify_updated", maintenance_deleted: "maintenance_notify_deleted",
  maintenance_completed: "maintenance_notify_completed", rental_created: "rental_notify_new",
  rental_updated: "rental_notify_updated", rental_deleted: "rental_notify_deleted",
  rental_returned: "rental_notify_returned", expense_created: "expenses_notify_new",
  expense_updated: "expenses_notify_updated", expense_deleted: "expenses_notify_deleted",
  subscription_created: "subscription_notify_new", subscription_updated: "subscription_notify_updated",
  subscription_deleted: "subscription_notify_deleted", subscription_renewed: "subscription_notify_renewed",
};
const emittedTypes = [
  "invoice_created", "invoice_updated", "invoice_deleted", "invoice_paid",
  "invoice_cash", "customer_cash_invoice", "customer_updated", "customer_deleted",
  "subscription_created", "subscription_deleted",
  "subscription_renewed", "expense_created", "expense_updated", "expense_deleted",
  "inventory_product_created", "inventory_product_deleted", "inventory_quantity_updated",
  "maintenance_created", "maintenance_updated", "maintenance_deleted", "rental_created",
  "rental_updated", "rental_deleted",
];
assert(emittedTypes.every((type) => allowedNotificationTypes.has(type)));
assert(emittedTypes.every((type) => preferenceKeys[type]));
assert([...allowedNotificationTypes].every((type) => preferenceKeys[type]));
console.log("Notification type and preference mapping checks passed.");

assert.strictEqual(
  normalizeOrganizationEmail(" A.Hmed+work@Gmail.com "),
  "ahmed@gmail.com",
);
assert.strictEqual(
  normalizeOrganizationEmail("User+team@outlook.com"),
  "user@outlook.com",
);
assert.strictEqual(
  normalizeOrganizationEmail("user.name@example.com"),
  "user.name@example.com",
);
assert.strictEqual(normalizeOrganizationEmail("not-an-email"), "");
console.log("Organization email normalization checks passed.");

const recipients = getRecipientPlayerIds([
  { id: "actor", data: { oneSignalPlayerId: "actor-old", oneSignalPlayerIds: ["actor-old", "actor-new"] } },
  { id: "switchedActor", data: { oneSignalPlayerIds: ["role-device"] } },
  { id: "enabled", data: { oneSignalPlayerId: "recipient-device" } },
  { id: "optedOut", data: { oneSignalPlayerIds: ["disabled-device"], notificationEnabled: false } },
], new Set(["actor", "switchedActor"]), new Set(["optedOut"]));
assert.deepStrictEqual([...recipients].sort(), ["recipient-device"]);
const optedOutAndActor = getRecipientPlayerIds([
  { id: "actor", data: { oneSignalPlayerIds: ["actor-device"], notificationEnabled: false } },
  { id: "recipient", data: { oneSignalPlayerId: "recipient-device" } },
], new Set(), new Set(["actor"]));
assert.deepStrictEqual([...optedOutAndActor], ["recipient-device"]);
assert.deepStrictEqual(
  [...getRecipientPlayerIds([
    { id: "actor", data: { oneSignalPlayerId: "only-device" } },
  ], new Set(["actor"]))],
  [],
);
console.log("Recipient filtering checks passed.");

const roles = new Map([
  ["cashier", { isActive: true, permissions: ["invoices_cash_manage"] }],
  ["disabled-role", { isActive: false, permissions: ["customers_delete"] }],
]);
assert.strictEqual(canPerformNotificationAction({ roleIds: ["cashier"] }, roles, ["invoices_cash_manage"]), true);
assert.strictEqual(canPerformNotificationAction({ roleIds: ["cashier"] }, roles, ["customers_delete"]), false);
assert.strictEqual(canPerformNotificationAction({ roleIds: ["disabled-role"] }, roles, ["customers_delete"]), false);
assert.strictEqual(canPerformNotificationAction({ customPermissions: ["customers_edit"] }, roles, ["customers_edit"]), true);
assert.strictEqual(canPerformActingNotificationAction(
  { roleIds: ["cashier"] }, { roleIds: ["cashier"] }, roles,
  ["invoices_cash_manage"], true,
), true);
assert.strictEqual(canPerformActingNotificationAction(
  { roleIds: ["cashier"] }, { roleIds: ["disabled-role"] }, roles,
  ["invoices_cash_manage"], true,
), false);
assert.strictEqual(canPerformActingNotificationAction(
  { roleIds: ["cashier"] }, { roleIds: ["disabled-role"] }, roles,
  ["invoices_cash_manage"], false,
), true);
assert.strictEqual(isSettingEnabled({ toggle: "false" }, "toggle", true), false);
assert.strictEqual(isSettingEnabled({}, "missing", true), true);
console.log("Permission resolution and settings parsing checks passed.");

const activeOnlyRecipients = getRecipientPlayerIds([
  { id: "active", data: { oneSignalPlayerId: "active-device" } },
  { id: "inactive", data: { oneSignalPlayerId: "inactive-device", isActive: false } },
], new Set());
assert.deepStrictEqual([...activeOnlyRecipients], ["active-device"]);
