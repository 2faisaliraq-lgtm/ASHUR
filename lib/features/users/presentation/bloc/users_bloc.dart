import 'dart:async';
import 'dart:collection'; // ✅ ملاحظة: مطلوب لـ listEquals المستخدم في السطر 1110

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/entities/user_management_entity.dart';
import '../../domain/repositories/users_repository.dart';
import '../../domain/usecases/create_user_usecase.dart';
import '../../domain/usecases/delete_user_usecase.dart';
import '../../domain/usecases/get_roles_stream.dart';
import '../../domain/usecases/get_roles_usecase.dart';
import '../../domain/usecases/get_user_logs.dart';
import '../../domain/usecases/get_users_paginated.dart';
import '../../domain/usecases/get_users_stats_stream.dart';
import '../../domain/usecases/get_users_stream.dart';
import '../../domain/usecases/get_users_usecase.dart';
import '../../domain/usecases/update_user_usecase.dart';
import 'users_event.dart';
import 'users_state.dart';

/// Bloc إدارة المستخدمين
/// ╔══════════════════════════════════════════════════════════════╗
/// ║ ⚠️  ملاحظة للمبرمجين المستقبليين: هذا الـ Bloc ينسق        ║
/// ║ عمليات المستخدمين عبر Use Cases ← Repository Implementation. ║
/// ║ ✅ ذرية تسجيل النشاط (_logUserActivity): نشاط النجاح       ║
/// ║   مدمج في Transaction مع العملية الأساسية داخل المستودع،    ║
/// ║   والفشل يُسجل منفصلاً كـ "فشل" (الفشل ليس جزءاً من        ║
/// ║   العملية الأساسية - مقبول). التفاصيل في الملاحظة الشاملة   ║
/// ║   أعلى ملف المستودع.                                        ║
/// ╚══════════════════════════════════════════════════════════════╝
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  UsersBloc({
    required this.getUsersUseCase,
    required this.getUsersPaginated,
    required this.getUsersStream,
    required this.getUsersStatsStream,
    required this.getRolesStream,
    required this.createUserUseCase,
    required this.updateUserUseCase,
    required this.deleteUserUseCase,
    required this.getRolesUseCase,
    required this.getUserLogs,
    required this.repository,
  }) : super(const UsersInitial()) {
    on<LoadUsersEvent>(_onLoadUsers);
    on<LoadUsersPaginatedEvent>(_onLoadUsersPaginated);
    on<LoadMoreUsersEvent>(_onLoadMoreUsers);
    on<GetUserByIdEvent>(_onGetUserById);
    on<SearchUsersEvent>(_onSearchUsers);
    on<FilterUsersEvent>(_onFilterUsers);
    on<CreateUserEvent>(_onCreateUser);
    on<UpdateUserEvent>(_onUpdateUser);
    on<DeleteUserEvent>(_onDeleteUser);
    on<ToggleUserStatusEvent>(_onToggleUserStatus);
    on<LoadRolesEvent>(_onLoadRoles);
    on<LoadMoreRolesEvent>(_onLoadMoreRoles);
    on<LoadPermissionsEvent>(_onLoadPermissions);
    on<LoadUsersStatisticsEvent>(_onLoadUsersStatistics);
    on<ResetUsersStateEvent>(_onResetState);
    on<CreateRoleEvent>(_onCreateRole);
    on<UpdateRoleEvent>(_onUpdateRole);
    on<DeleteRoleEvent>(_onDeleteRole);
    on<LoadUsersSettingsEvent>(_onLoadUsersSettings);
    on<SaveUsersSettingsEvent>(_onSaveUsersSettings);
    on<LoadUserLogsEvent>(_onLoadUserLogs);
    on<AddUserLogEvent>(_onAddUserLog);

    // Stream handlers
    on<StartUsersStreamEvent>(_onStartUsersStream);
    on<StopUsersStreamEvent>(_onStopUsersStream);
    on<StartUsersStatsStreamEvent>(_onStartUsersStatsStream);
    on<StopUsersStatsStreamEvent>(_onStopUsersStatsStream);
    on<UsersStreamDataReceived>(_onUsersStreamDataReceived);
    on<UsersStreamErrorReceived>(_onUsersStreamErrorReceived);
    on<UsersStatsStreamDataReceived>(_onUsersStatsStreamDataReceived);

    // Roles Stream handlers
    on<StartRolesStreamEvent>(_onStartRolesStream);
    on<StopRolesStreamEvent>(_onStopRolesStream);
    on<RolesStreamDataReceived>(_onRolesStreamDataReceived);
    on<RolesStreamErrorReceived>(_onRolesStreamErrorReceived);
  }
  final GetUsersUseCase getUsersUseCase;
  final GetUsersPaginated getUsersPaginated;
  final GetUsersStream getUsersStream;
  final GetUsersStatsStream getUsersStatsStream;
  final GetRolesStream getRolesStream;
  final CreateUserUseCase createUserUseCase;
  final UpdateUserUseCase updateUserUseCase;
  final DeleteUserUseCase deleteUserUseCase;
  final GetRolesUseCase getRolesUseCase;
  final GetUserLogs getUserLogs;
  final UsersRepository repository;

  StreamSubscription<Either<Failure, List<UserManagementEntity>>>?
  _usersStreamSubscription;
  StreamSubscription<Either<Failure, Map<String, int>>>?
  _usersStatsStreamSubscription;
  StreamSubscription<Either<Failure, List<RoleEntity>>>?
  _rolesStreamSubscription;
  Map<String, int>? _pendingStats; // ✅ تخزين الإحصائيات الواصلة قبل بيانات المستخدمين

  // متغيرات للتحكم في pagination
  dynamic _lastDocument;
  dynamic _lastDocumentRoles;
  static const int _pageSize = 20;
  bool _isOperating = false;
  bool _isLoadingMoreRoles = false;
  bool _hasMoreRolesData = true;

  /// تسجيل نشاط المستخدم (للفشل فقط - نشاط النجاح مدمج في
  /// Transaction داخل Repository، السبب الكامل في الملاحظة
  /// الشاملة أعلى هذا الملف)
  void _logUserActivity({
    required String actionType,
    String? details,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    bool isSuccess = true,
  }) {
    // استخدام repository لإضافة السجل مباشرة
    unawaited(
      repository
          .addUserLog(
            userId: _getCurrentUserId(), // استخدام معرف المستخدم الحالي
            actionType: actionType,
            details: details,
            targetId: targetId,
            targetType: targetType,
            oldValues: oldValues,
            newValues: newValues,
            isSuccess: isSuccess,
          )
          .then((_) {
            // تجاهل النتيجة لعدم تعطيل العمليات الأساسية
          })
          .catchError((e) {
            // تجاهل أخطاء تسجيل النشاطات لعدم تعطيل العمليات الأساسية
          }),
    );
  }

  /// الحصول على معرف المستخدم الحالي
  String _getCurrentUserId() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      return currentUser?.uid ?? 'system';
    } on Exception catch (_) {
      return 'system';
    }
  }

  /// الحصول على بريد المستخدم الحالي
  String _getCurrentUserEmail() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final email = currentUser?.email ?? '';
      return email;
    } on Exception catch (_) {
      return '';
    }
  }

  /// معالج تحميل المستخدمين
  Future<void> _onLoadUsers(
    LoadUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    // إذا كانت هناك بيانات محملة مسبقاً، نستخدم حالة التحديث
    if (state is UsersLoaded) {
      final currentState = state as UsersLoaded;
      emit(UsersRefreshing(currentState.users));
    } else if (state is UsersRefreshing) {
      // إذا كنا في حالة تحديث بالفعل، لا نفعل شيئاً لتجنب التداخل
      return;
    } else {
      // إذا لم تكن هناك بيانات، نستخدم حالة التحميل العادية
      emit(const UsersLoading());
    }

    final params = GetUsersParams(
      organizationEmail: event.organizationEmail,
      limit: event.limit,
      searchQuery: event.searchQuery,
      roleFilters: event.roleFilters,
      isActiveFilter: event.isActiveFilter,
    );

    // ✅ أداء: جلب المستخدمين والأدوار والإحصائيات
    // بشكل متوازٍ (ثلاثة استعلامات مستقلة تبدأ
    // معاً في رحلة شبكة واحدة بدلاً من ثلاث
    // رحلات متسلسلة).
    final usersFuture = getUsersUseCase(params);
    final rolesFuture = getRolesUseCase(NoParams());
    final statsFuture = repository.getUsersStatistics();

    final usersResult = await usersFuture;
    final rolesResult = await rolesFuture;
    final statsResult = await statsFuture;
    final statistics = statsResult.fold((l) => null, (r) => r);

    await usersResult.fold(
      (failure) async {
        // في حالة الخطأ، إذا كانت هناك بيانات سابقة، نحتفظ بها
        if (state is UsersRefreshing) {
          final refreshingState = state as UsersRefreshing;
          emit(
            UsersLoaded(
              users: refreshingState.currentUsers,
              currentSearchQuery: event.searchQuery,
              currentRoleFilters: event.roleFilters,
              currentActiveFilter: event.isActiveFilter,
            ),
          );
          // نعرض رسالة خطأ منفصلة
          emit(
            UsersError('${failure.message} - تم الاحتفاظ بالبيانات السابقة'),
          );
        } else {
          emit(UsersError(failure.message));
        }
      },
      (users) async {
        rolesResult.fold(
          (failure) => emit(
            UsersLoaded(
              users: users,
              statistics: statistics,
              currentSearchQuery: event.searchQuery,
              currentRoleFilters: event.roleFilters,
              currentActiveFilter: event.isActiveFilter,
            ),
          ),
          (roles) => emit(
            UsersLoaded(
              users: users,
              roles: roles,
              statistics: statistics,
              currentSearchQuery: event.searchQuery,
              currentRoleFilters: event.roleFilters,
              currentActiveFilter: event.isActiveFilter,
            ),
          ),
        );
      },
    );
  }

  /// معالج تحميل المستخدمين بشكل تدريجي
  Future<void> _onLoadUsersPaginated(
    LoadUsersPaginatedEvent event,
    Emitter<UsersState> emit,
  ) async {
    // إذا كان refresh، نعيد تعيين المتغيرات
    if (event.isRefresh) {
      _lastDocument = null;
      emit(const UsersLoading());
    }

    // تحميل أول دفعة من المستخدمين
    final result = await getUsersPaginated(
      organizationEmail: event.organizationEmail,
      limit: _pageSize,
    );

    await result.fold((failure) async => emit(UsersError(failure.message)), (
      page,
    ) async {
      // ✅ أداء: بدء جلب الأدوار أولاً ليجري
      // بالتوازي مع معالجة النتيجة بدلاً من
      // الانتظار متسلسلاً (استعلامان مستقلان
      // في رحلة شبكة واحدة).
      final rolesFuture = getRolesUseCase(NoParams());

      // ✅ تحسين (2026-10-12): مؤشر الصفحة يأتي من
      // نتيجة الاستعلام مباشرة (آخر مستند في الصفحة)
      // بدلاً من جلب المستند مجدداً عبر getUserDocument
      // — كان يضيف جولة شبكة زائدة بعد كل تحميل صفحة.
      if (page.users.isNotEmpty) {
        _lastDocument = page.lastDocument;
      }

      final rolesResult = await rolesFuture;

      emit(
        UsersLoaded(
          users: page.users,
          roles: rolesResult.fold((l) => [], (r) => r),
          hasMore: page.users.length >= _pageSize,
          lastDocument: _lastDocument,
        ),
      );
    });
  }

  /// معالج تحميل المزيد من المستخدمين
  Future<void> _onLoadMoreUsers(
    LoadMoreUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    if (state is! UsersLoaded) return;

    final currentState = state as UsersLoaded;

    // إذا لم يكن هناك المزيد أو جاري التحميل، لا نفعل شيء
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    // تحديث الحالة لإظهار مؤشر التحميل
    emit(currentState.copyWith(isLoadingMore: true));

    // تحميل المزيد من المستخدمين
    final result = await getUsersPaginated(
      organizationEmail: event.organizationEmail,
      limit: _pageSize,
      lastDocument: currentState.lastDocument,
    );

    await result.fold(
      (failure) async {
        emit(currentState.copyWith(isLoadingMore: false));
        emit(UsersError(failure.message));
      },
      (page) async {
        final newUsers = page.users;

        // ✅ تحسين (2026-10-12): مؤشر الصفحة من نتيجة
        // الاستعلام مباشرة بدلاً من جلب المستند مجدداً
        // عبر getUserDocument (جولة شبكة زائدة).
        if (newUsers.isNotEmpty) {
          _lastDocument = page.lastDocument;
        }

        // دمج المستخدمين الجدد مع القديمة
        final allUsers = [...currentState.users, ...newUsers];

        emit(
          currentState.copyWith(
            users: allUsers,
            hasMore: newUsers.length >= _pageSize,
            isLoadingMore: false,
            lastDocument: _lastDocument,
          ),
        );
      },
    );
  }

  /// معالج تحميل مستخدم بالمعرف
  Future<void> _onGetUserById(
    GetUserByIdEvent event,
    Emitter<UsersState> emit,
  ) async {
    emit(const UsersLoading());

    final result = await repository.getUserById(event.userId);

    result.fold(
      (failure) => emit(UsersError(failure.message)),
      (user) => emit(UserLoaded(user)),
    );
  }

  /// معالج البحث في المستخدمين
  Future<void> _onSearchUsers(
    SearchUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    // ✅ تحويل البحث من سيرفر إلى محلي (مثل الفواتير)
    List<String>? currentRoleFilters;
    bool? currentActiveFilter;
    List<UserManagementEntity>? allUsers;

    if (state is UsersLoaded) {
      final currentState = state as UsersLoaded;
      currentRoleFilters = currentState.currentRoleFilters;
      currentActiveFilter = currentState.currentActiveFilter;
      allUsers = currentState.users;
    } else if (state is UsersStreamActive) {
      final currentState = state as UsersStreamActive;
      currentRoleFilters = currentState.roleFilters;
      currentActiveFilter = currentState.isActiveFilter;
      allUsers = currentState.users;
    }

    // ✅ إذا كان لدينا بيانات، نطبق البحث محلياً
    if (allUsers != null) {
      var filteredUsers = allUsers;

      // تطبيق فلترة الأدوار
      if (currentRoleFilters != null && currentRoleFilters.isNotEmpty) {
        filteredUsers = filteredUsers
            .where(
              (user) => user.roles.any(
                (role) => currentRoleFilters!.contains(role.id),
              ),
            )
            .toList();
      }

      // تطبيق فلترة الحالة (نشط/غير نشط)
      if (currentActiveFilter != null) {
        filteredUsers = filteredUsers
            .where((user) => user.isActive == currentActiveFilter)
            .toList();
      }

      // تطبيق البحث النصي
      if (event.searchQuery.isNotEmpty) {
        final query = event.searchQuery.toLowerCase();
        filteredUsers = filteredUsers
            .where(
              (user) =>
                  (user.name?.toLowerCase().contains(query) ?? false) ||
                  (user.email?.toLowerCase().contains(query) ?? false) ||
                  (user.phoneNumber?.contains(event.searchQuery) ?? false) ||
                  (user.department?.toLowerCase().contains(query) ?? false) ||
                  (user.jobTitle?.toLowerCase().contains(query) ?? false),
            )
            .toList();
      }

      // إصدار الحالة الجديدة مع البيانات المصفاة
      if (state is UsersLoaded) {
        final currentState = state as UsersLoaded;
        emit(
          UsersStreamActive(
            users: currentState.users,
            filteredUsers: filteredUsers,
            roles: currentState.roles,
            permissions: currentState.permissions,
            statistics: currentState.statistics,
            searchQuery: event.searchQuery,
            roleFilters: currentRoleFilters,
            isActiveFilter: currentActiveFilter,
          ),
        );
      } else if (state is UsersStreamActive) {
        final currentState = state as UsersStreamActive;
        emit(
          currentState.copyWith(
            filteredUsers: filteredUsers,
            searchQuery: event.searchQuery,
          ),
        );
      }
    } else {
      // ✅ إذا لم يكن لدينا بيانات، نستخدم الطريقة القديمة (سيرفر)
      add(
        LoadUsersEvent(
          organizationEmail: _getCurrentUserEmail(),
          searchQuery: event.searchQuery,
          roleFilters: currentRoleFilters,
          isActiveFilter: currentActiveFilter,
        ),
      );
    }
  }

  /// معالج فلترة المستخدمين
  Future<void> _onFilterUsers(
    FilterUsersEvent event,
    Emitter<UsersState> emit,
  ) async {
    String? currentSearchQuery;

    if (state is UsersLoaded) {
      final currentState = state as UsersLoaded;
      currentSearchQuery = currentState.currentSearchQuery;
    }

    add(
      LoadUsersEvent(
        organizationEmail: _getCurrentUserEmail(),
        searchQuery: currentSearchQuery,
        roleFilters: event.roleFilters,
        isActiveFilter: event.isActiveFilter,
      ),
    );
  }

  /// معالج إنشاء مستخدم جديد
  Future<void> _onCreateUser(
    CreateUserEvent event,
    Emitter<UsersState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    try {
      // لا نغير الحالة إلى Loading لتجنب إخفاء البيانات الحالية
      final params = CreateUserParams(
      email: event.email,
      name: event.name,
      phoneNumber: event.phoneNumber,
      department: event.department,
      jobTitle: event.jobTitle,
      roleIds: event.roleIds,
      roleCode: event.roleCode,
      customPermissions: event.customPermissions,
      useCurrentUser: event.useCurrentUser,
      createdBy: event.createdBy,
      accountPassword: event.accountPassword,
      // ✅ إصلاح ذرية: ربط تسجيل النشاط بالعملية الأساسية
      logActionType: 'create',
      logDetails: 'تم إنشاء مستخدم جديد: ${event.name}',
      logTargetId: null,
      logTargetType: 'user',
      logNewValues: {
        'name': event.name,
        'email': event.email,
        'roles': event.roleIds.join(', '),
      },
      logIsSuccess: true,
    );

    final result = await createUserUseCase(params);

    result.fold(
      (failure) {
        emit(UsersError(failure.message));
        // ✅ ذرية: تسجيل الفشل منفصلاً (السبب في doc _logUserActivity)
        _logUserActivity(
          actionType: 'create',
          targetType: 'user',
          details: 'فشل في إنشاء مستخدم جديد: ${failure.message}',
          isSuccess: false,
        );
      },
      (user) {
        emit(const UsersOperationSuccess('تم إنشاء المستخدم بنجاح'));
        emit(UserCreated(user));
        // ✅ تم تسجيل النشاط بنجاح داخل الـ Transaction
        // إعادة تحميل المستخدمين
        add(LoadUsersEvent(organizationEmail: _getCurrentUserEmail()));
      },
    );
  } finally {
    _isOperating = false; // ✅ ملاحظة: إعادة التعيين في finally لمنع بقاء القفل صحيحاً عند الاستثناء
  }
  }

  /// معالج تحديث المستخدم
  Future<void> _onUpdateUser(
    UpdateUserEvent event,
    Emitter<UsersState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    try {
      // التحقق من الصلاحية
      final permissionChecker = PermissionChecker();
      final hasPermission = await permissionChecker.hasPermission('users_edit');
      if (!hasPermission) {
        emit(const UsersError('ليس لديك صلاحية لتعديل المستخدمين'));
        return;
      }

      // لا نغير الحالة إلى Loading لتجنب إخفاء البيانات الحالية

      // الحصول على البيانات القديمة للمقارنة
    final oldUserResult = await repository.getUserById(event.userId);
    Map<String, dynamic>? oldValues;

    oldUserResult.fold((failure) => null, (oldUser) {
      oldValues = {
        'name': oldUser.name,
        'email': oldUser.email,
        'phoneNumber': oldUser.phoneNumber,
        'department': oldUser.department,
        'jobTitle': oldUser.jobTitle,
      };
    });

    final params = UpdateUserParams(
      userId: event.userId,
      email: event.email,
      name: event.name,
      phoneNumber: event.phoneNumber,
      department: event.department,
      jobTitle: event.jobTitle,
      roleIds: event.roleIds,
      roleCode: event.roleCode,
      customPermissions: event.customPermissions,
      notificationEnabled: event.notificationEnabled,
      // ✅ إصلاح ذرية: ربط تسجيل النشاط بالعملية الأساسية
      logActionType: 'update',
      logDetails: 'تم تحديث بيانات المستخدم: ${event.name}',
      logTargetId: event.userId,
      logTargetType: 'user',
      logOldValues: oldValues,
      logNewValues: {
        'name': event.name,
        'email': event.email,
        'phoneNumber': event.phoneNumber,
        'department': event.department,
        'jobTitle': event.jobTitle,
      },
    );

    final result = await updateUserUseCase(params);

    result.fold(
      (failure) {
        emit(UsersError(failure.message));
        // ✅ ذرية: تسجيل الفشل منفصلاً (السبب في doc _logUserActivity)
        _logUserActivity(
          actionType: 'update',
          targetType: 'user',
          targetId: event.userId,
          details: 'فشل في تحديث المستخدم: ${failure.message}',
          isSuccess: false,
        );
      },
      (user) {
        // ✅ تحديث الصلاحيات فوراً
        final permissionChecker = PermissionChecker();
        permissionChecker.notifyPermissionsChanged();

        emit(const UsersOperationSuccess('تم تحديث بيانات المستخدم بنجاح'));
        emit(UserUpdated(user));
        // ✅ تم تسجيل النشاط بنجاح داخل الـ Transaction
        add(LoadUsersEvent(organizationEmail: _getCurrentUserEmail()));
      },
    );
  } finally {
    _isOperating = false; // ✅ ملاحظة: إعادة التعيين في finally لمنع بقاء القفل صحيحاً عند الاستثناء
  }
  }

  /// معالج حذف المستخدم
  Future<void> _onDeleteUser(
    DeleteUserEvent event,
    Emitter<UsersState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    try {
      // التحقق من الصلاحية
      final permissionChecker = PermissionChecker(); // ⚠️ ملاحظة: يُفضل حقن PermissionChecker عبر GetIt بدلاً من الت instantiation المباشر هنا
      final hasPermission = await permissionChecker.hasPermission('users_delete');

    if (!hasPermission) {
      emit(const UsersError('ليس لديك صلاحية لحذف المستخدمين'));
      return;
    }

    // لا نغير الحالة إلى Loading لتجنب إخفاء البيانات الحالية

    // الحصول على بيانات المستخدم قبل الحذف
    final userResult = await repository.getUserById(event.userId);
    String? userName;

    userResult.fold((failure) => null, (user) => userName = user.name);

    final params = DeleteUserParams(
      userId: event.userId,
      // ✅ إصلاح ذرية: ربط تسجيل النشاط بالعملية الأساسية
      logActionType: 'delete',
      logDetails: 'تم حذف المستخدم: ${userName ?? 'غير محدد'}',
      logTargetId: event.userId,
      logTargetType: 'user',
      logOldValues: {'name': userName},
    );
    final result = await deleteUserUseCase(params);

    result.fold(
      (failure) {
        emit(UsersError(failure.message));
        // ✅ ذرية: تسجيل الفشل منفصلاً (السبب في doc _logUserActivity)
        _logUserActivity(
          actionType: 'delete',
          targetType: 'user',
          targetId: event.userId,
          details: 'فشل في حذف المستخدم: ${failure.message}',
          isSuccess: false,
        );
      },
      (_) {
        emit(UserDeleted(event.userId));
        // ✅ تم تسجيل النشاط بنجاح داخل الـ Transaction
        // إعادة تحميل المستخدمين
        add(LoadUsersEvent(organizationEmail: _getCurrentUserEmail()));
      },
    );
  } finally {
    _isOperating = false; // ✅ ملاحظة: إعادة التعيين في finally لمنع بقاء القفل صحيحاً عند الاستثناء
  }
  }

  /// معالج تغيير حالة المستخدم
  Future<void> _onToggleUserStatus(
    ToggleUserStatusEvent event,
    Emitter<UsersState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    try {
      // التحقق من الصلاحية
      final permissionChecker = PermissionChecker();
      final hasPermission = await permissionChecker.hasPermission('users_manage_status');
      if (!hasPermission) {
        emit(const UsersError('ليس لديك صلاحية لإدارة حالة المستخدمين'));
        return;
      }

      // التحقق من أن المستخدم لا يحاول تغيير حالته الخاصة
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid == event.userId) {
        emit(const UsersError('لا يمكنك تغيير حالة حسابك الخاص'));
        return;
      }

      final result = await repository.toggleUserStatus(
        event.userId,
        isActive: event.isActive,
        // ✅ إصلاح ذرية: ربط تسجيل النشاط بالعملية الأساسية
        logActionType: 'toggle_user_status',
        logDetails: 'تم ${event.isActive ? 'تفعيل' : 'تعطيل'} المستخدم ${event.userId}',
        logTargetId: event.userId,
        logTargetType: 'user',
        logNewValues: {'isActive': event.isActive},
      );

      result.fold((failure) => emit(UsersError(failure.message)), (_) {
        emit(UserStatusToggled(userId: event.userId, isActive: event.isActive));

        // إعادة تحميل المستخدمين
        add(LoadUsersEvent(organizationEmail: _getCurrentUserEmail()));
      });
    } finally {
      _isOperating = false; // ✅ إعادة التعيين في finally لمنع بقاء القفل صحيحاً عند الاستثناء
    }
  }

  /// معالج تحميل الأدوار
  Future<void> _onLoadRoles(
    LoadRolesEvent event,
    Emitter<UsersState> emit,
  ) async {
    _lastDocumentRoles = null;
    _isLoadingMoreRoles = false;
    _hasMoreRolesData = true;
    final result = await getRolesUseCase(NoParams());

    result.fold((failure) => emit(UsersError(failure.message)), (roles) {
      if (state is UsersLoaded) {
        final currentState = state as UsersLoaded;
        emit(currentState.copyWith(roles: roles));
      } else if (state is UsersStreamActive) {
        final currentState = state as UsersStreamActive;
        emit(currentState.copyWith(roles: roles));
      } else {
        // إذا لم تكن هناك حالة UsersLoaded، ننشئ واحدة جديدة للأدوار فقط
        emit(UsersLoaded(users: const [], roles: roles));
      }
    });
  }

  Future<void> _onLoadMoreRoles(
    LoadMoreRolesEvent event,
    Emitter<UsersState> emit,
  ) async {
    if (_isLoadingMoreRoles || !_hasMoreRolesData) return;

    final currentState = state;
    if (currentState is! UsersLoaded && currentState is! UsersStreamActive) {
      return;
    }
    _isLoadingMoreRoles = true;
    if (currentState is UsersLoaded) {
      emit(currentState.copyWith(isLoadingMoreRoles: true));
    } else {
      emit((currentState as UsersStreamActive).copyWith(isLoadingMoreRoles: true));
    }

    try {
      final result = await repository.getRolesPaginated(
        organizationEmail: '', // سيتم جلبه من المستخدم الحالي
        limit: _pageSize,
        lastDocument: _lastDocumentRoles,
      );

      result.fold((failure) => emit(UsersError(failure.message)), (page) {
        if (page.roles.isNotEmpty) {
          _lastDocumentRoles = page.lastDocument;
          final currentRoles = <RoleEntity>[];
          if (state is UsersLoaded) {
            currentRoles.addAll((state as UsersLoaded).roles);
          } else if (state is UsersStreamActive) {
            currentRoles.addAll((state as UsersStreamActive).roles);
          }
          currentRoles.addAll(page.roles);
          _hasMoreRolesData = page.roles.length >= _pageSize;

          if (state is UsersLoaded) {
            final currentState = state as UsersLoaded;
            emit(currentState.copyWith(
              roles: currentRoles,
              hasMoreRolesData: _hasMoreRolesData,
              isLoadingMoreRoles: false,
            ));
          } else if (state is UsersStreamActive) {
            final currentState = state as UsersStreamActive;
            emit(currentState.copyWith(
              roles: currentRoles,
              hasMoreRolesData: _hasMoreRolesData,
              isLoadingMoreRoles: false,
            ));
          }
        } else {
          _hasMoreRolesData = false;
          if (state is UsersLoaded) {
            final currentState = state as UsersLoaded;
            emit(currentState.copyWith(
              hasMoreRolesData: false,
              isLoadingMoreRoles: false,
            ));
          } else if (state is UsersStreamActive) {
            final currentState = state as UsersStreamActive;
            emit(currentState.copyWith(
              hasMoreRolesData: false,
              isLoadingMoreRoles: false,
            ));
          }
        }
        _isLoadingMoreRoles = false;
      });
    } on Exception catch (_) {
      _isLoadingMoreRoles = false;
      if (state is UsersLoaded) {
        final currentState = state as UsersLoaded;
        emit(currentState.copyWith(isLoadingMoreRoles: false));
      } else if (state is UsersStreamActive) {
        final currentState = state as UsersStreamActive;
        emit(currentState.copyWith(isLoadingMoreRoles: false));
      }
      emit(UsersError('حدث خطأ غير متوقع'));
    }
  }

  /// معالج تحميل الصلاحيات
  Future<void> _onLoadPermissions(
    LoadPermissionsEvent event,
    Emitter<UsersState> emit,
  ) async {
    final result = await repository.getPermissions();

    result.fold(
      (failure) {
        emit(UsersError(failure.message));
      },
      (permissions) {
        // تحديث الصلاحيات في أي حالة
        if (state is UsersLoaded) {
          final currentState = state as UsersLoaded;
          emit(currentState.copyWith(permissions: permissions));
        } else if (state is UsersStreamActive) {
          final currentState = state as UsersStreamActive;
          emit(currentState.copyWith(permissions: permissions));
        } else if (state is UsersInitial || state is UsersLoading) {
          // إذا كانت الحالة أولية أو تحميل، ننشئ حالة UsersLoaded بالصلاحيات فقط
          emit(UsersLoaded(users: const [], permissions: permissions));
        } else {
          // لأي حالة أخرى، نحاول التحديث إذا أمكن
          try {
            if (state is UsersRefreshing) {
              final currentState = state as UsersRefreshing;
              emit(
                UsersLoaded(
                  users: currentState.currentUsers,
                  permissions: permissions,
                ),
              );
            }
          } on Exception catch (_) {
            // في حالة أي خطأ، ننشئ حالة جديدة
            emit(UsersLoaded(users: const [], permissions: permissions));
          }
        }
      },
    );
  }

  /// معالج تحميل إحصائيات المستخدمين
  Future<void> _onLoadUsersStatistics(
    LoadUsersStatisticsEvent event,
    Emitter<UsersState> emit,
  ) async {
    final result = await repository.getUsersStatistics();

    result.fold((failure) => emit(UsersError(failure.message)), (statistics) {
      if (state is UsersLoaded) {
        final currentState = state as UsersLoaded;
        emit(currentState.copyWith(statistics: statistics));
      }
      // لا نصدر حالة جديدة إذا لم تكن UsersLoaded موجودة
    });
  }

  /// معالج إعادة تعيين الحالة
  void _onResetState(ResetUsersStateEvent event, Emitter<UsersState> emit) {
    emit(const UsersInitial());
  }

  /// معالج إنشاء دور جديد
  Future<void> _onCreateRole(
    CreateRoleEvent event,
    Emitter<UsersState> emit,
  ) async {
    emit(const UsersLoading());

    final result = await repository.createRole(
      name: event.name,
      displayName: event.displayName,
      description: event.description,
      permissions: event.permissions,
    );

    result.fold(
      (failure) {
        emit(UsersError(failure.message));
      },
      (role) {
        emit(RoleCreated(role));
        // إعادة تحميل الأدوار
        add(const LoadRolesEvent());
      },
    );
  }

  /// معالج تحديث الدور
  Future<void> _onUpdateRole(
    UpdateRoleEvent event,
    Emitter<UsersState> emit,
  ) async {
    emit(const UsersLoading());

    final result = await repository.updateRole(
      roleId: event.roleId,
      displayName: event.displayName,
      description: event.description,
      permissions: event.permissions,
    );

    result.fold((failure) => emit(UsersError(failure.message)), (role) {
      emit(RoleUpdated(role));
      // إعادة تحميل الأدوار
      add(const LoadRolesEvent());
    });
  }

  /// معالج حذف الدور
  Future<void> _onDeleteRole(
    DeleteRoleEvent event,
    Emitter<UsersState> emit,
  ) async {
    // التحقق من الصلاحية
    final permissionChecker = PermissionChecker();
    final hasPermission = await permissionChecker.hasPermission('users_delete');

    if (!hasPermission) {
      emit(const UsersError('ليس لديك صلاحية لحذف الأدوار'));
      return;
    }

    emit(const UsersLoading());

    final result = await repository.deleteRole(event.roleId);

    result.fold((failure) => emit(UsersError(failure.message)), (_) {
      emit(RoleDeleted(event.roleId));
      // إعادة تحميل الأدوار
      add(const LoadRolesEvent());
    });
  }

  /// معالج تحميل إعدادات المستخدمين
  Future<void> _onLoadUsersSettings(
    LoadUsersSettingsEvent event,
    Emitter<UsersState> emit,
  ) async {
    emit(const UsersLoading());

    final result = await repository.getUsersSettings();

    result.fold(
      (failure) => emit(UsersError(failure.message)),
      (settings) => emit(UsersSettingsLoaded(settings)),
    );
  }

  /// معالج حفظ إعدادات المستخدمين
  Future<void> _onSaveUsersSettings(
    SaveUsersSettingsEvent event,
    Emitter<UsersState> emit,
  ) async {
    emit(const UsersLoading());

    final result = await repository.saveUsersSettings(event.settings);

    result.fold(
      (failure) => emit(UsersError(failure.message)),
      (settings) => emit(UsersSettingsSaved(settings)),
    );
  }

  /// معالج تحميل سجل نشاطات المستخدمين
  Future<void> _onLoadUserLogs(
    LoadUserLogsEvent event,
    Emitter<UsersState> emit,
  ) async {
    emit(const UsersLoading());

    final params = GetUserLogsParams(
      userId: event.userId,
      searchQuery: event.searchQuery,
      actionFilter: event.actionFilter,
      dateFilter: event.dateFilter,
      startDate: event.startDate,
      endDate: event.endDate,
      limit: event.limit,
    );

    final result = await getUserLogs(params);

    result.fold(
      (failure) => emit(UsersError(failure.message)),
      (logs) => emit(
        UserLogsLoaded(
          logs: logs,
          // ⚠️ ملاحظة: logs.length هو عدد السجلات المعادة في الصفحة الحالية (بعد تطبيق limit)،
          // وليس العدد الإجمالي لجميع السجلات المطابقة. الحصول على العدد الإجمالي يتطلب
          // تعديل getUserLogs في المستودع لإرجاع count منفصلاً عن القائمة.
          totalCount: logs.length,
          currentSearchQuery: event.searchQuery,
          currentActionFilter: event.actionFilter,
          currentDateFilter: event.dateFilter,
        ),
      ),
    );
  }

  /// معالج إضافة سجل نشاط جديد
  Future<void> _onAddUserLog(
    AddUserLogEvent event,
    Emitter<UsersState> emit,
  ) async {
    final result = await repository.addUserLog(
      userId: event.userId,
      actionType: event.actionType,
      userName: event.userName,
      userEmail: event.userEmail,
      details: event.details,
      targetId: event.targetId,
      targetType: event.targetType,
      oldValues: event.oldValues,
      newValues: event.newValues,
      ipAddress: event.ipAddress,
      userAgent: event.userAgent,
      sessionId: event.sessionId,
      deviceInfo: event.deviceInfo,
      isSuccess: event.isSuccess,
    );

    result.fold(
      (failure) => emit(UsersError(failure.message)),
      (log) => emit(UserLogAdded(log)),
    );
  }

  // Stream handlers
  Future<void> _onStartUsersStream(
    StartUsersStreamEvent event,
    Emitter<UsersState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _usersStreamSubscription?.cancel();

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is UsersStreamActive || state is UsersLoaded;
    if (!hasExistingData) {
      emit(const UsersLoading());
    }

    try {
      // استخدام البريد الإلكتروني المقدم أو الحصول على البريد الإلكتروني للمستخدم الحالي
      final organizationEmail =
          event.organizationEmail ?? _getCurrentUserEmail();

      if (organizationEmail.isEmpty) {
        emit(const UsersError('لا يمكن تحديد المؤسسة'));
        return;
      }

      final params = GetUsersStreamParams(
        organizationEmail: organizationEmail,
        limit: event.limit,
        searchQuery: event.searchQuery,
        roleFilters: event.roleFilters,
        isActiveFilter: event.isActiveFilter,
      );

      _usersStreamSubscription = getUsersStream(params).listen(
        (result) {
          result.fold(
            (failure) {
              add(UsersStreamErrorReceived(failure.message));
            },
            (users) {
              add(UsersStreamDataReceived(users));
            },
          );
        },
        onError: (error) {
          add(UsersStreamErrorReceived('حدث خطأ غير متوقع'));
        },
        onDone: () {},
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(UsersError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onStopUsersStream(
    StopUsersStreamEvent event,
    Emitter<UsersState> emit,
  ) async {
    await _usersStreamSubscription?.cancel();
    _usersStreamSubscription = null;
  }

  Future<void> _onStartUsersStatsStream(
    StartUsersStatsStreamEvent event,
    Emitter<UsersState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _usersStatsStreamSubscription?.cancel();

    try {
      _usersStatsStreamSubscription =
          getUsersStatsStream(
            GetUsersStatsStreamParams(
              organizationEmail: event.organizationEmail,
            ),
          ).listen(
            (result) {
              result.fold(
                (failure) {
                  add(UsersStreamErrorReceived(failure.message));
                },
                (stats) {
                  add(UsersStatsStreamDataReceived(stats));
                },
              );
            },
            onError: (error) {},
            onDone: () {},
          );
    } on Exception catch (_) {
      // تجاهل الأخطاء في إنشاء stream الإحصائيات
    }
  }

  Future<void> _onStopUsersStatsStream(
    StopUsersStatsStreamEvent event,
    Emitter<UsersState> emit,
  ) async {
    await _usersStatsStreamSubscription?.cancel();
    _usersStatsStreamSubscription = null;
  }

  void _onUsersStreamDataReceived(
    UsersStreamDataReceived event,
    Emitter<UsersState> emit,
  ) {
    // ✅ تطبيق الحد الأقصى للعرض (10 عناصر فقط في الداشبورد)
    final limitedUsers = event.users.length > 10
        ? event.users.sublist(0, 10)
        : event.users;

    if (state is UsersStreamActive) {
      final currentState = state as UsersStreamActive;

      // ✅ إعادة تطبيق الفلاتر من الحالة الحالية
      var filteredUsers = limitedUsers;

      // تطبيق فلترة الأدوار
      if (currentState.roleFilters != null &&
          currentState.roleFilters!.isNotEmpty) {
        filteredUsers = filteredUsers
            .where(
              (user) => user.roles.any(
                (role) => currentState.roleFilters!.contains(role.id),
              ),
            )
            .toList();
      }

      // تطبيق فلترة الحالة
      if (currentState.isActiveFilter != null) {
        filteredUsers = filteredUsers
            .where((user) => user.isActive == currentState.isActiveFilter)
            .toList();
      }

      // تطبيق البحث النصي
      if (currentState.searchQuery.isNotEmpty) {
        final query = currentState.searchQuery.toLowerCase();
        filteredUsers = filteredUsers
            .where(
              (user) =>
                  (user.name?.toLowerCase().contains(query) ?? false) ||
                  (user.email?.toLowerCase().contains(query) ?? false) ||
                  (user.phoneNumber?.contains(currentState.searchQuery) ??
                      false) ||
                  (user.department?.toLowerCase().contains(query) ?? false) ||
                  (user.jobTitle?.toLowerCase().contains(query) ?? false),
            )
            .toList();
      }

      // ✅ التحقق من تغير البيانات قبل emit لمنع إعادة البناء المستمر
      final usersChanged = !listEquals(currentState.users, limitedUsers);
      final filteredUsersChanged = !listEquals(
        currentState.filteredUsers,
        filteredUsers,
      );

      if (usersChanged || filteredUsersChanged) {
        emit(
          currentState.copyWith(
            users: limitedUsers,
            filteredUsers: filteredUsers,
            statistics: currentState.statistics, // ✅ حفظ الإحصائيات
          ),
        );
      }
    } else if (state is UsersLoaded) {
      // إذا كانت الحالة السابقة UsersLoaded، نحتفظ بالأدوار والصلاحيات
      final currentState = state as UsersLoaded;

      // ✅ إعادة تطبيق الفلاتر من الحالة الحالية
      var filteredUsers = limitedUsers;

      // تطبيق فلترة الأدوار
      if (currentState.currentRoleFilters != null &&
          currentState.currentRoleFilters!.isNotEmpty) {
        filteredUsers = filteredUsers
            .where(
              (user) => user.roles.any(
                (role) => currentState.currentRoleFilters!.contains(role.id),
              ),
            )
            .toList();
      }

      // تطبيق فلترة الحالة
      if (currentState.currentActiveFilter != null) {
        filteredUsers = filteredUsers
            .where((user) => user.isActive == currentState.currentActiveFilter)
            .toList();
      }

      // تطبيق البحث النصي
      final currentSearchQuery = currentState.currentSearchQuery;
      if (currentSearchQuery != null && currentSearchQuery.isNotEmpty) {
        final query = currentSearchQuery.toLowerCase();
        filteredUsers = filteredUsers
            .where(
              (user) =>
                  (user.name?.toLowerCase().contains(query) ?? false) ||
                  (user.email?.toLowerCase().contains(query) ?? false) ||
                  (user.phoneNumber?.contains(currentSearchQuery) ?? false) ||
                  (user.department?.toLowerCase().contains(query) ?? false) ||
                  (user.jobTitle?.toLowerCase().contains(query) ?? false),
            )
            .toList();
      }

      // ✅ التحقق من تغير البيانات قبل emit
      final usersChanged = !listEquals(currentState.users, limitedUsers);

      // UsersLoaded لا تحتوي على filteredUsers، لذا نقارن المستخدمين فقط
      if (usersChanged) {
        emit(
          UsersStreamActive(
            users: limitedUsers,
            filteredUsers: filteredUsers,
            roles: currentState.roles,
            permissions: currentState.permissions,
            roleFilters: currentState.currentRoleFilters ?? [], // ✅ حفظ الفلتر
            isActiveFilter: currentState.currentActiveFilter, // ✅ حفظ الفلتر
            searchQuery: currentState.currentSearchQuery ?? '', // ✅ حفظ البحث
            statistics: currentState.statistics, // ✅ حفظ الإحصائيات
          ),
        );
      }
    } else {
      // حالة جديدة - نحتاج لتحميل الأدوار والصلاحيات
      // ===== ملاحظة للمبرمجين المستقبليين =====
      // لماذا نستخدم _pendingStats هنا؟
      // لأنه في صفحة الداشبورد، يبدأ stream الإحصائيات
      // وstream المستخدمين في نفس الوقت. من المحتمل أن يصل
      // stream الإحصائيات قبل stream المستخدمين.
      // إذا لم نستخدم _pendingStats، سنفقد الإحصائيات الواصلة
      // أثناء حالة UsersLoading، وسيتم عرض أصفار في النظرة العامة.
      // ==========================================
      emit(UsersStreamActive(
        users: limitedUsers,
        filteredUsers: limitedUsers,
        statistics: _pendingStats,
      ));
      _pendingStats = null; // مسح بعد الاستخدام
      // تحميل الأدوار والصلاحيات
      add(const LoadRolesEvent());
      add(const LoadPermissionsEvent());
    }
  }

  void _onUsersStreamErrorReceived(
    UsersStreamErrorReceived event,
    Emitter<UsersState> emit,
  ) {
    if (state is UsersLoaded || state is UsersStreamActive) {
      return;
    }
    emit(UsersError(event.error));
  }

  void _onUsersStatsStreamDataReceived(
    UsersStatsStreamDataReceived event,
    Emitter<UsersState> emit,
  ) {
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا نقوم بتخزين الإحصائيات في _pendingStats عندما تكون
    // الحالة UsersLoading أو UsersInitial؟
    // لأنه في صفحة الداشبورد، يبدأ stream الإحصائيات
    // وstream المستخدمين في نفس الوقت. من المحتمل أن يصل
    // stream الإحصائيات قبل stream المستخدمين.
    // إذا تجاهلنا الإحصائيات في هذه الحالة، سنفقدها إلى الأبد
    // لأن stream الإحصائيات لن يعيد إرسالها ما لم يتغير
    // أي مستند في المجموعة.
    // ==========================================

    if (state is UsersStreamActive) {
      final currentState = state as UsersStreamActive;

      // ✅ التحقق من تغير الإحصائيات قبل emit
      final statisticsChanged = currentState.statistics != event.statistics;

      if (statisticsChanged) {
        emit(currentState.copyWith(statistics: event.statistics));
      }
    } else if (state is UsersLoaded) {
      final currentState = state as UsersLoaded;

      // ✅ التحقق من تغير الإحصائيات قبل emit
      final statisticsChanged = currentState.statistics != event.statistics;

      if (statisticsChanged) {
        emit(currentState.copyWith(statistics: event.statistics));
      }
    } else if (state is UsersLoading || state is UsersInitial) {
      // ✅ تخزين الإحصائيات مؤقتاً لاستخدامها عند وصول بيانات المستخدمين
      _pendingStats = event.statistics;
    }
  }

  // Roles Stream handlers
  Future<void> _onStartRolesStream(
    StartRolesStreamEvent event,
    Emitter<UsersState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _rolesStreamSubscription?.cancel();

    try {
      _rolesStreamSubscription = getRolesStream().listen(
        (result) {
          result.fold(
            (failure) {
              add(RolesStreamErrorReceived(failure.message));
            },
            (roles) {
              add(RolesStreamDataReceived(roles));
            },
          );
        },
        onError: (error) {
          add(RolesStreamErrorReceived('حدث خطأ غير متوقع'));
        },
        onDone: () {},
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(UsersError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onStopRolesStream(
    StopRolesStreamEvent event,
    Emitter<UsersState> emit,
  ) async {
    await _rolesStreamSubscription?.cancel();
    _rolesStreamSubscription = null;
  }

  void _onRolesStreamDataReceived(
    RolesStreamDataReceived event,
    Emitter<UsersState> emit,
  ) {
    if (state is UsersStreamActive) {
      final currentState = state as UsersStreamActive;
      emit(currentState.copyWith(roles: event.roles));
    } else if (state is UsersLoaded) {
      final currentState = state as UsersLoaded;
      emit(currentState.copyWith(roles: event.roles));
    } else {
      // حالة جديدة - إنشاء UsersLoaded مع الأدوار فقط
      emit(UsersLoaded(users: const [], roles: event.roles));
    }
  }

  void _onRolesStreamErrorReceived(
    RolesStreamErrorReceived event,
    Emitter<UsersState> emit,
  ) {
    // لا نعرض خطأ للمستخدم، فقط نسجله
    // يمكن إضافة logging هنا إذا لزم الأمر
  }

  @override
  Future<void> close() {
    _usersStreamSubscription?.cancel();
    _usersStatsStreamSubscription?.cancel();
    _rolesStreamSubscription?.cancel();
    return super.close();
  }
}
