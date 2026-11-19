import 'package:equatable/equatable.dart';

import 'role_entity.dart';

/// كيان إدارة المستخدم - يوسع كيان المستخدم الأساسي بمعلومات الإدارة
class UserManagementEntity extends Equatable {
  const UserManagementEntity({
    required this.id,
    required this.createdAt,
    this.email, // إزالة required
    this.name,
    this.phoneNumber,
    this.photoUrl,
    this.department,
    this.jobTitle,
    this.roles = const [],
    this.roleIds = const [], // إضافة معرفات الأدوار
    this.roleCode, // رمز الوصول للدور
    this.customPermissions = const [], // الصلاحيات المخصصة
    this.isActive = true,
    this.isEmailVerified = false,
    this.notificationEnabled = true,
    this.updatedAt,
    this.lastLoginAt,
    this.createdBy,
    this.updatedBy,
  });
  final String id;
  final String? email; // جعل البريد الإلكتروني اختياري
  final String? name;
  final String? phoneNumber;
  final String? photoUrl;
  final String? department;
  final String? jobTitle;
  final List<RoleEntity> roles;
  final List<String> roleIds; // إضافة معرفات الأدوار
  final String? roleCode; // رمز الوصول للدور
  final List<String> customPermissions; // الصلاحيات المخصصة
  final bool isActive;
  final bool isEmailVerified;
  final bool notificationEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final String? createdBy;
  final String? updatedBy;

  /// الحصول على جميع الصلاحيات من الأدوار المخصصة
  List<String> get allPermissions {
    // إذا كانت هناك صلاحيات مخصصة، نستخدمها فقط
    if (customPermissions.isNotEmpty) {
      return customPermissions;
    }
    // وإلا نستخدم صلاحيات الأدوار
    final permissions = <String>{};
    for (final role in roles) {
      permissions.addAll(role.permissions);
    }
    return permissions.toList();
  }

  /// التحقق من وجود صلاحية محددة
  bool hasPermission(String permission) {
    return allPermissions.contains(permission);
  }

  /// التحقق من وجود دور محدد
  bool hasRole(String roleName) {
    return roles.any((role) => role.name == roleName && role.isActive);
  }

  /// التحقق من وجود دور محدد بناءً على اسم العرض
  bool hasRoleByDisplayName(String displayName) {
    return roles.any(
      (role) => role.displayName == displayName && role.isActive,
    );
  }

  /// التحقق من وجود صلاحيات محددة (كلها)
  bool hasAllPermissions(List<String> permissions) {
    return permissions.every(hasPermission);
  }

  /// التحقق من وجود صلاحيات محددة (واحدة على الأقل)
  bool hasAnyPermission(List<String> permissions) {
    return permissions.any(hasPermission);
  }

  /// التحقق من أن الدور نشط قبل التحقق من الصلاحيات
  bool hasActiveRole(String roleName) {
    return roles.any(
      (role) =>
          role.name == roleName && role.isActive && role.permissions.isNotEmpty,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    phoneNumber,
    photoUrl,
    department,
    jobTitle,
    roles,
    roleIds, // إضافة معرفات الأدوار
    roleCode, // رمز الوصول للدور
    customPermissions, // الصلاحيات المخصصة
    isActive,
    isEmailVerified,
    notificationEnabled,
    createdAt,
    updatedAt,
    lastLoginAt,
    createdBy,
    updatedBy,
  ];

  UserManagementEntity copyWith({
    String? id,
    String? email,
    String? name,
    String? phoneNumber,
    String? photoUrl,
    String? department,
    String? jobTitle,
    List<RoleEntity>? roles,
    List<String>? roleIds,
    String? roleCode,
    List<String>? customPermissions,
    bool? isActive,
    bool? isEmailVerified,
    bool? notificationEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return UserManagementEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      roles: roles ?? this.roles,
      roleIds: roleIds ?? this.roleIds,
      roleCode: roleCode ?? this.roleCode,
      customPermissions: customPermissions ?? this.customPermissions,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
