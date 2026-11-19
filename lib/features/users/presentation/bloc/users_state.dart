import 'package:equatable/equatable.dart';

import '../../domain/entities/permission_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/entities/user_log_entity.dart';
import '../../domain/entities/user_management_entity.dart';

/// حالات إدارة المستخدمين
abstract class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class UsersInitial extends UsersState {
  const UsersInitial();
}

/// حالة التحميل
class UsersLoading extends UsersState {
  const UsersLoading();
}

/// حالة التحديث (عندما تكون هناك بيانات محملة مسبقاً)
class UsersRefreshing extends UsersState {
  const UsersRefreshing(this.currentUsers);
  final List<UserManagementEntity> currentUsers;

  @override
  List<Object> get props => [currentUsers];
}

/// حالة تحميل المستخدمين بنجاح
class UsersLoaded extends UsersState {
  const UsersLoaded({
    required this.users,
    this.roles = const [],
    this.permissions = const [],
    this.statistics,
    this.currentSearchQuery,
    this.currentRoleFilters,
    this.currentActiveFilter,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.lastDocument,
    this.hasMoreRolesData = true,
    this.isLoadingMoreRoles = false,
    this.lastDocumentRoles,
  });
  final List<UserManagementEntity> users;
  final List<RoleEntity> roles;
  final List<PermissionEntity> permissions;
  final Map<String, int>? statistics;
  final String? currentSearchQuery;
  final List<String>? currentRoleFilters;
  final bool? currentActiveFilter;
  final bool hasMore;
  final bool isLoadingMore;
  final dynamic lastDocument;
  final bool hasMoreRolesData;
  final bool isLoadingMoreRoles;
  final dynamic lastDocumentRoles;

  @override
  List<Object?> get props => [
    users,
    roles,
    permissions,
    statistics,
    currentSearchQuery,
    currentRoleFilters,
    currentActiveFilter,
    hasMore,
    isLoadingMore,
    lastDocument,
    hasMoreRolesData,
    isLoadingMoreRoles,
    lastDocumentRoles,
  ];

  /// نسخ الحالة مع تحديث بعض القيم
  UsersLoaded copyWith({
    List<UserManagementEntity>? users,
    List<RoleEntity>? roles,
    List<PermissionEntity>? permissions,
    Map<String, int>? statistics,
    String? currentSearchQuery,
    List<String>? currentRoleFilters,
    bool? currentActiveFilter,
    bool? hasMore,
    bool? isLoadingMore,
    dynamic lastDocument,
    bool? hasMoreRolesData,
    bool? isLoadingMoreRoles,
    dynamic lastDocumentRoles,
  }) {
    return UsersLoaded(
      users: users ?? this.users,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      statistics: statistics ?? this.statistics,
      currentSearchQuery: currentSearchQuery ?? this.currentSearchQuery,
      currentRoleFilters: currentRoleFilters ?? this.currentRoleFilters,
      currentActiveFilter: currentActiveFilter ?? this.currentActiveFilter,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMoreRolesData: hasMoreRolesData ?? this.hasMoreRolesData,
      isLoadingMoreRoles: isLoadingMoreRoles ?? this.isLoadingMoreRoles,
      lastDocumentRoles: lastDocumentRoles ?? this.lastDocumentRoles,
    );
  }
}

/// حالة تحميل مستخدم واحد بنجاح
class UserLoaded extends UsersState {
  const UserLoaded(this.user);
  final UserManagementEntity user;

  @override
  List<Object> get props => [user];
}

/// حالة إنشاء المستخدم بنجاح
class UserCreated extends UsersState {
  const UserCreated(this.user);
  final UserManagementEntity user;

  @override
  List<Object> get props => [user];
}

/// حالة إنشاء الدور بنجاح
class RoleCreated extends UsersState {
  const RoleCreated(this.role);
  final RoleEntity role;

  @override
  List<Object> get props => [role];
}

/// حالة تحديث الدور بنجاح
class RoleUpdated extends UsersState {
  const RoleUpdated(this.role);
  final RoleEntity role;

  @override
  List<Object> get props => [role];
}

/// حالة حذف الدور بنجاح
class RoleDeleted extends UsersState {
  const RoleDeleted(this.roleId);
  final String roleId;

  @override
  List<Object> get props => [roleId];
}

/// حالة تحديث المستخدم بنجاح
class UserUpdated extends UsersState {
  const UserUpdated(this.user);
  final UserManagementEntity user;

  @override
  List<Object> get props => [user];
}

/// حالة حذف المستخدم بنجاح
class UserDeleted extends UsersState {
  const UserDeleted(this.userId);
  final String userId;

  @override
  List<Object> get props => [userId];
}

/// حالة تغيير حالة المستخدم بنجاح
class UserStatusToggled extends UsersState {
  const UserStatusToggled({required this.userId, required this.isActive});
  final String userId;
  final bool isActive;

  @override
  List<Object> get props => [userId, isActive];
}

/// حالة الخطأ
class UsersError extends UsersState {
  const UsersError(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

/// حالة تحميل إعدادات المستخدمين بنجاح
class UsersSettingsLoaded extends UsersState {
  const UsersSettingsLoaded(this.settings);
  final Map<String, dynamic> settings;

  @override
  List<Object> get props => [settings];
}

/// حالة حفظ إعدادات المستخدمين بنجاح
class UsersSettingsSaved extends UsersState {
  const UsersSettingsSaved(this.settings);
  final Map<String, dynamic> settings;

  @override
  List<Object> get props => [settings];
}

/// حالة تحميل سجل نشاطات المستخدمين بنجاح
class UserLogsLoaded extends UsersState {
  const UserLogsLoaded({
    required this.logs,
    this.totalCount = 0,
    this.currentSearchQuery,
    this.currentActionFilter,
    this.currentDateFilter,
  });

  final List<UserLogEntity> logs;
  final int totalCount;
  final String? currentSearchQuery;
  final String? currentActionFilter;
  final String? currentDateFilter;

  @override
  List<Object?> get props => [
    logs,
    totalCount,
    currentSearchQuery,
    currentActionFilter,
    currentDateFilter,
  ];

  /// نسخ الحالة مع تحديث بعض القيم
  UserLogsLoaded copyWith({
    List<UserLogEntity>? logs,
    int? totalCount,
    String? currentSearchQuery,
    String? currentActionFilter,
    String? currentDateFilter,
  }) {
    return UserLogsLoaded(
      logs: logs ?? this.logs,
      totalCount: totalCount ?? this.totalCount,
      currentSearchQuery: currentSearchQuery ?? this.currentSearchQuery,
      currentActionFilter: currentActionFilter ?? this.currentActionFilter,
      currentDateFilter: currentDateFilter ?? this.currentDateFilter,
    );
  }
}

/// حالة إضافة سجل نشاط بنجاح
class UserLogAdded extends UsersState {
  const UserLogAdded(this.log);

  final UserLogEntity log;

  @override
  List<Object> get props => [log];
}

/// حالة نجاح عملية على المستخدم
class UsersOperationSuccess extends UsersState {
  const UsersOperationSuccess(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}

/// حالة المستخدمين النشطة مع التحديث الفوري
class UsersStreamActive extends UsersState {
  const UsersStreamActive({
    required this.users,
    required this.filteredUsers,
    this.roles = const [],
    this.permissions = const [],
    this.statistics,
    this.searchQuery = '',
    this.roleFilters,
    this.isActiveFilter,
    this.hasMoreRolesData = true,
    this.isLoadingMoreRoles = false,
    this.lastDocumentRoles,
  });

  final List<UserManagementEntity> users;
  final List<UserManagementEntity> filteredUsers;
  final List<RoleEntity> roles;
  final List<PermissionEntity> permissions;
  final Map<String, int>? statistics;
  final String searchQuery;
  final List<String>? roleFilters;
  final bool? isActiveFilter;
  final bool hasMoreRolesData;
  final bool isLoadingMoreRoles;
  final dynamic lastDocumentRoles;

  UsersStreamActive copyWith({
    List<UserManagementEntity>? users,
    List<UserManagementEntity>? filteredUsers,
    List<RoleEntity>? roles,
    List<PermissionEntity>? permissions,
    Map<String, int>? statistics,
    String? searchQuery,
    List<String>? roleFilters,
    bool? isActiveFilter,
    bool? hasMoreRolesData,
    bool? isLoadingMoreRoles,
    dynamic lastDocumentRoles,
  }) {
    return UsersStreamActive(
      users: users ?? this.users,
      filteredUsers: filteredUsers ?? this.filteredUsers,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      statistics: statistics ?? this.statistics,
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilters: roleFilters ?? this.roleFilters,
      isActiveFilter: isActiveFilter ?? this.isActiveFilter,
      hasMoreRolesData: hasMoreRolesData ?? this.hasMoreRolesData,
      isLoadingMoreRoles: isLoadingMoreRoles ?? this.isLoadingMoreRoles,
      lastDocumentRoles: lastDocumentRoles ?? this.lastDocumentRoles,
    );
  }

  @override
  List<Object?> get props => [
    users,
    filteredUsers,
    roles,
    permissions,
    statistics,
    searchQuery,
    roleFilters,
    isActiveFilter,
    hasMoreRolesData,
    isLoadingMoreRoles,
    lastDocumentRoles,
  ];
}
