import 'package:equatable/equatable.dart';

import '../../domain/entities/role_entity.dart';
import '../../domain/entities/user_management_entity.dart';

/// أحداث إدارة المستخدمين
abstract class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

/// حدث تحميل المستخدمين
class LoadUsersEvent extends UsersEvent {
  const LoadUsersEvent({
    required this.organizationEmail,
    this.limit,
    this.searchQuery,
    this.roleFilters,
    this.isActiveFilter,
  });
  final String organizationEmail;
  final int? limit;
  final String? searchQuery;
  final List<String>? roleFilters;
  final bool? isActiveFilter;

  @override
  List<Object?> get props => [
    organizationEmail,
    limit,
    searchQuery,
    roleFilters,
    isActiveFilter,
  ];
}

/// حدث لتحميل المستخدمين بشكل تدريجي (pagination)
class LoadUsersPaginatedEvent extends UsersEvent {
  const LoadUsersPaginatedEvent({
    required this.organizationEmail,
    this.isRefresh = false,
  });
  final String organizationEmail;
  final bool isRefresh;

  @override
  List<Object?> get props => [organizationEmail, isRefresh];
}

/// حدث لتحميل المزيد من المستخدمين
class LoadMoreUsersEvent extends UsersEvent {
  const LoadMoreUsersEvent(this.organizationEmail);
  final String organizationEmail;

  @override
  List<Object?> get props => [organizationEmail];
}

/// حدث تحميل مستخدم بالمعرف
class GetUserByIdEvent extends UsersEvent {
  const GetUserByIdEvent(this.userId);
  final String userId;

  @override
  List<Object> get props => [userId];
}

/// حدث البحث في المستخدمين
class SearchUsersEvent extends UsersEvent {
  const SearchUsersEvent(this.searchQuery);
  final String searchQuery;

  @override
  List<Object> get props => [searchQuery];
}

/// حدث فلترة المستخدمين
class FilterUsersEvent extends UsersEvent {
  const FilterUsersEvent({this.roleFilters, this.isActiveFilter});
  final List<String>? roleFilters;
  final bool? isActiveFilter;

  @override
  List<Object?> get props => [roleFilters, isActiveFilter];
}

/// حدث إنشاء مستخدم جديد
class CreateUserEvent extends UsersEvent {
  const CreateUserEvent({
    required this.name,
    required this.roleIds,
    required this.roleCode, // رمز الوصول للدور
    this.email, // إزالة required
    this.phoneNumber,
    this.department,
    this.jobTitle,
    this.customPermissions, // الصلاحيات المخصصة
    this.useCurrentUser = false, // القيمة الافتراضية false
    this.createdBy, // اسم المنشئ
    this.accountPassword, // كلمة مرور الحساب للمستخدمين الجدد
  });

  final String? email; // جعل البريد الإلكتروني اختياري
  final String name;
  final String? phoneNumber;
  final String? department;
  final String? jobTitle;
  final List<String> roleIds;
  final String roleCode; // رمز الوصول للدور
  final List<String>? customPermissions; // الصلاحيات المخصصة
  final bool useCurrentUser; // معامل للتحكم في استخدام المستخدم الحالي
  final String? createdBy; // اسم المستخدم الذي أنشأ هذا المستخدم
  final String? accountPassword; // كلمة مرور الحساب للمستخدمين الجدد

  @override
  List<Object?> get props => [
    email,
    name,
    phoneNumber,
    department,
    jobTitle,
    roleIds,
    roleCode, // إضافة إلى props
    customPermissions, // الصلاحيات المخصصة
    useCurrentUser, // إضافة المعامل الجديد
    createdBy, // إضافة المنشئ
    accountPassword, // إضافة كلمة مرور الحساب
  ];
}

/// حدث تحديث المستخدم
class UpdateUserEvent extends UsersEvent {
  const UpdateUserEvent({
    required this.userId,
    this.email,
    this.name,
    this.phoneNumber,
    this.department,
    this.jobTitle,
    this.roleIds,
    this.roleCode,
    this.customPermissions,
    this.notificationEnabled,
    this.updatedBy,
  });
  final String userId;
  final String? email;
  final String? name;
  final String? phoneNumber;
  final String? department;
  final String? jobTitle;
  final List<String>? roleIds;
  final String? roleCode;
  final List<String>? customPermissions;
  final bool? notificationEnabled;
  final String? updatedBy;

  @override
  List<Object?> get props => [
    userId,
    email,
    name,
    phoneNumber,
    department,
    jobTitle,
    roleIds,
    roleCode,
    customPermissions,
    notificationEnabled,
    updatedBy,
  ];
}

/// حدث حذف المستخدم
class DeleteUserEvent extends UsersEvent {
  const DeleteUserEvent(this.userId);
  final String userId;

  @override
  List<Object> get props => [userId];
}

/// حدث تغيير حالة المستخدم
class ToggleUserStatusEvent extends UsersEvent {
  const ToggleUserStatusEvent({required this.userId, required this.isActive});
  final String userId;
  final bool isActive;

  @override
  List<Object> get props => [userId, isActive];
}

/// حدث تحميل الأدوار
class LoadRolesEvent extends UsersEvent {
  const LoadRolesEvent();
}

/// حدث تحميل المزيد من الأدوار (pagination)
class LoadMoreRolesEvent extends UsersEvent {
  const LoadMoreRolesEvent();
}

/// حدث تحميل الصلاحيات
class LoadPermissionsEvent extends UsersEvent {
  const LoadPermissionsEvent();
}

/// حدث تحميل إحصائيات المستخدمين
class LoadUsersStatisticsEvent extends UsersEvent {
  const LoadUsersStatisticsEvent({required this.organizationEmail});
  final String organizationEmail;

  @override
  List<Object> get props => [organizationEmail];
}

/// حدث إنشاء دور جديد
class CreateRoleEvent extends UsersEvent {
  const CreateRoleEvent({
    required this.name,
    required this.displayName,
    required this.permissions,
    this.description,
    this.createdBy,
  });
  final String name;
  final String displayName;
  final String? description;
  final List<String> permissions;
  final String? createdBy;

  @override
  List<Object?> get props => [
    name,
    displayName,
    description,
    permissions,
    createdBy,
  ];
}

/// حدث تحديث الدور
class UpdateRoleEvent extends UsersEvent {
  const UpdateRoleEvent({
    required this.roleId,
    this.displayName,
    this.description,
    this.permissions,
    this.updatedBy,
  });
  final String roleId;
  final String? displayName;
  final String? description;
  final List<String>? permissions;
  final String? updatedBy;

  @override
  List<Object?> get props => [
    roleId,
    displayName,
    description,
    permissions,
    updatedBy,
  ];
}

/// حدث إعادة تعيين الحالة
class ResetUsersStateEvent extends UsersEvent {
  const ResetUsersStateEvent();
}

/// حدث حذف دور
class DeleteRoleEvent extends UsersEvent {
  const DeleteRoleEvent(this.roleId);
  final String roleId;

  @override
  List<Object> get props => [roleId];
}

/// حدث تحميل إعدادات المستخدمين
class LoadUsersSettingsEvent extends UsersEvent {
  const LoadUsersSettingsEvent();
}

/// حدث حفظ إعدادات المستخدمين
class SaveUsersSettingsEvent extends UsersEvent {
  const SaveUsersSettingsEvent(this.settings);
  final Map<String, dynamic> settings;

  @override
  List<Object> get props => [settings];
}

/// حدث تحميل سجل نشاطات المستخدمين
class LoadUserLogsEvent extends UsersEvent {
  const LoadUserLogsEvent({
    this.userId,
    this.searchQuery,
    this.actionFilter,
    this.dateFilter,
    this.startDate,
    this.endDate,
    this.limit,
  });

  final String? userId;
  final String? searchQuery;
  final String? actionFilter;
  final String? dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  @override
  List<Object?> get props => [
    userId,
    searchQuery,
    actionFilter,
    dateFilter,
    startDate,
    endDate,
    limit,
  ];
}

/// حدث إضافة سجل نشاط جديد
class AddUserLogEvent extends UsersEvent {
  const AddUserLogEvent({
    required this.userId,
    required this.actionType,
    this.userName,
    this.userEmail,
    this.details,
    this.targetId,
    this.targetType,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.userAgent,
    this.sessionId,
    this.deviceInfo,
    this.isSuccess = true,
  });

  final String userId;
  final String actionType;
  final String? userName;
  final String? userEmail;
  final String? details;
  final String? targetId;
  final String? targetType;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? ipAddress;
  final String? userAgent;
  final String? sessionId;
  final Map<String, dynamic>? deviceInfo;
  final bool isSuccess;

  @override
  List<Object?> get props => [
    userId,
    actionType,
    userName,
    userEmail,
    details,
    targetId,
    targetType,
    oldValues,
    newValues,
    ipAddress,
    userAgent,
    sessionId,
    deviceInfo,
    isSuccess,
  ];
}

// Stream Events للتحديث الفوري
class StartUsersStreamEvent extends UsersEvent {
  const StartUsersStreamEvent({
    this.organizationEmail,
    this.limit,
    this.searchQuery,
    this.roleFilters,
    this.isActiveFilter,
  });

  final String? organizationEmail;
  final int? limit;
  final String? searchQuery;
  final List<String>? roleFilters;
  final bool? isActiveFilter;

  @override
  List<Object?> get props => [
    organizationEmail,
    limit,
    searchQuery,
    roleFilters,
    isActiveFilter,
  ];
}

class StopUsersStreamEvent extends UsersEvent {
  const StopUsersStreamEvent();
}

class StartUsersStatsStreamEvent extends UsersEvent {
  const StartUsersStatsStreamEvent({required this.organizationEmail, this.limit});
  final String organizationEmail;
  final int? limit;

  @override
  List<Object?> get props => [organizationEmail, limit];
}

class StopUsersStatsStreamEvent extends UsersEvent {
  const StopUsersStatsStreamEvent();
}

// Internal stream events
class UsersStreamDataReceived extends UsersEvent {
  const UsersStreamDataReceived(this.users);
  final List<UserManagementEntity> users;

  @override
  List<Object> get props => [users];
}

class UsersStreamErrorReceived extends UsersEvent {
  const UsersStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object> get props => [error];
}

class UsersStatsStreamDataReceived extends UsersEvent {
  const UsersStatsStreamDataReceived(this.statistics);
  final Map<String, int> statistics;

  @override
  List<Object> get props => [statistics];
}

// Roles Stream Events
class StartRolesStreamEvent extends UsersEvent {
  const StartRolesStreamEvent();
}

class StopRolesStreamEvent extends UsersEvent {
  const StopRolesStreamEvent();
}

class RolesStreamDataReceived extends UsersEvent {
  const RolesStreamDataReceived(this.roles);
  final List<RoleEntity> roles;

  @override
  List<Object> get props => [roles];
}

class RolesStreamErrorReceived extends UsersEvent {
  const RolesStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object> get props => [error];
}
