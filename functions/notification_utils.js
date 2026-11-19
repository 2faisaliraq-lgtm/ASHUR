function normalizeOrganizationEmail(email) {
  if (typeof email !== "string") return "";
  const parts = email.trim().toLowerCase().split("@");
  if (parts.length !== 2) return "";
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

function playerIdsFor(userData) {
  const ids = new Set();
  const legacyId = userData.oneSignalPlayerId;
  if (typeof legacyId === "string" && legacyId.trim()) ids.add(legacyId.trim());
  if (Array.isArray(userData.oneSignalPlayerIds)) {
    for (const playerId of userData.oneSignalPlayerIds) {
      if (typeof playerId === "string" && playerId.trim()) {
        ids.add(playerId.trim());
      }
    }
  }
  return ids;
}

function getRecipientPlayerIds(users, excludedUserIds, optedOutUserIds = new Set()) {
  const excludedPlayerIds = new Set();
  const suppressedUserIds = new Set([...excludedUserIds, ...optedOutUserIds]);
  for (const user of users) {
    if (suppressedUserIds.has(user.id)) {
      for (const playerId of playerIdsFor(user.data)) {
        excludedPlayerIds.add(playerId);
      }
    }
  }

  const recipients = new Set();
  for (const user of users) {
    if (optedOutUserIds.has(user.id) || user.data.notificationEnabled === false ||
        user.data.isActive === false) continue;
    for (const playerId of playerIdsFor(user.data)) {
      if (!excludedPlayerIds.has(playerId)) recipients.add(playerId);
    }
  }
  return recipients;
}

function resolveUserPermissions(userData, rolesById) {
  const customPermissions = Array.isArray(userData.customPermissions)
    ? userData.customPermissions
    : Array.isArray(userData.additionalPermissions)
      ? userData.additionalPermissions
      : [];
  if (customPermissions.length > 0) return new Set(customPermissions);

  const roleIds = Array.isArray(userData.roleIds) && userData.roleIds.length > 0
    ? userData.roleIds
    : typeof userData.accessCode === "string" && userData.accessCode.trim()
      ? [userData.accessCode.trim()]
      : [];
  const permissions = new Set();
  for (const roleId of roleIds) {
    const role = rolesById.get(roleId);
    if (role && role.isActive !== false && Array.isArray(role.permissions)) {
      for (const permission of role.permissions) permissions.add(permission);
    }
  }
  return permissions;
}

function canPerformNotificationAction(userData, rolesById, allowedPermissions) {
  const permissions = resolveUserPermissions(userData, rolesById);
  return permissions.has("admin") || permissions.has("super_admin") ||
    allowedPermissions.some((permission) => permissions.has(permission));
}

function canPerformActingNotificationAction(
  actorData,
  authenticatedData,
  rolesById,
  allowedPermissions,
  isSwitchedActor,
) {
  if (!canPerformNotificationAction(actorData, rolesById, allowedPermissions)) {
    return false;
  }
  return !isSwitchedActor ||
    canPerformNotificationAction(authenticatedData, rolesById, allowedPermissions);
}

function isSettingEnabled(settings, key, defaultValue) {
  if (!settings || settings[key] === undefined || settings[key] === null) return defaultValue;
  return settings[key] === true || String(settings[key]).toLowerCase() === "true";
}

module.exports = {
  normalizeOrganizationEmail,
  playerIdsFor,
  getRecipientPlayerIds,
  resolveUserPermissions,
  canPerformNotificationAction,
  canPerformActingNotificationAction,
  isSettingEnabled,
};
