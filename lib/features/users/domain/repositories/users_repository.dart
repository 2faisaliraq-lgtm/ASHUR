import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/permission_entity.dart';
import '../entities/role_entity.dart';
import '../entities/roles_page.dart';
import '../entities/user_log_entity.dart';
import '../entities/user_management_entity.dart';
import '../entities/users_page.dart';

/// مستودع المستخدمين - يحدد العمليات المطلوبة لإدارة المستخدمين
///
/// ملاحظة ذرية موحدة: عمليات الكتابة (createUser/updateUser/deleteUser/
/// toggleUserStatus) تقبل معاملات تسجيل نشاط اختيارية (logActionType،
/// logDetails، logTargetId، logTargetType، logOldValues، logNewValues،
/// logIsSuccess) تُدمج داخل نفس Transaction مع العملية الأساسية، لأن
/// سجل النشاط يجب أن يُسجل فقط إذا نجحت العملية لتجنب سجلات مضللة.
/// عند فشل العملية الأساسية يُسجل الفشل بشكل منفصل عبر addUserLog.
abstract class UsersRepository {
  // عمليات المستخدمين
  Future<Either<Failure, List<UserManagementEntity>>> getUsers({
    required String organizationEmail,
    int? limit,
    String? searchQuery,
    List<String>? roleFilters,
    bool? isActiveFilter,
  });

  /// الحصول على المستخدمين مع pagination
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين: تُرجع
  /// UsersPage التي تحمل آخر مستند في
  /// الصفحة (snapshot.docs.last) كمؤشر
  /// startAfterDocument للصفحة التالية —
  /// إعادته مع المستخدمين يمنع جلب المستند
  /// مجدداً عبر getUserDocument (جولة
  /// شبكة زائدة بعد كل تحميل صفحة).
  Future<Either<Failure, UsersPage>> getUsersPaginated({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
  });

  // الطرق الجديدة للـ streams
  Stream<Either<Failure, List<UserManagementEntity>>> getUsersStream({
    required String organizationEmail,
    int? limit,
    String? searchQuery,
    List<String>? roleFilters,
    bool? isActiveFilter,
  });

  Stream<Either<Failure, Map<String, int>>> getUsersStatisticsStream({
    required String organizationEmail,
    int? limit,
  });

  Future<Either<Failure, UserManagementEntity>> getUserById(String userId);

  Future<Either<Failure, UserManagementEntity>> createUser({
    required String name,
    required List<String> roleIds,
    required String roleCode,
    String? email,
    String? phoneNumber,
    String? department,
    String? jobTitle,
    List<String>? customPermissions,
    bool useCurrentUser = false,
    String? createdBy,
    String? accountPassword,
    String? logActionType,
    String? logDetails,
    String? logTargetId,
    String? logTargetType,
    Map<String, dynamic>? logOldValues,
    Map<String, dynamic>? logNewValues,
    bool logIsSuccess = true,
  });

  Future<Either<Failure, UserManagementEntity>> updateUser({
    required String userId,
    String? email,
    String? name,
    String? phoneNumber,
    String? department,
    String? jobTitle,
    List<String>? roleIds,
    String? roleCode,
    List<String>? customPermissions,
    bool? notificationEnabled,
    String? logActionType,
    String? logDetails,
    String? logTargetId,
    String? logTargetType,
    Map<String, dynamic>? logOldValues,
    Map<String, dynamic>? logNewValues,
    bool logIsSuccess = true,
  });

  Future<Either<Failure, void>> deleteUser(
    String userId, {
    String? logActionType,
    String? logDetails,
    String? logTargetId,
    String? logTargetType,
    Map<String, dynamic>? logOldValues,
    Map<String, dynamic>? logNewValues,
    bool logIsSuccess = true,
  });

  Future<Either<Failure, void>> toggleUserStatus(
    String userId, {
    required bool isActive,
    String? logActionType,
    String? logDetails,
    String? logTargetId,
    String? logTargetType,
    Map<String, dynamic>? logOldValues,
    Map<String, dynamic>? logNewValues,
    bool logIsSuccess = true,
  });

  // عمليات الأدوار
  Future<Either<Failure, List<RoleEntity>>> getRoles();

  /// الحصول على الأدوار بشكل تدريجي (pagination)
  Future<Either<Failure, RolesPage>> getRolesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  });

  Stream<Either<Failure, List<RoleEntity>>> getRolesStream();

  Future<Either<Failure, RoleEntity>> getRoleById(String roleId);

  Future<Either<Failure, RoleEntity>> createRole({
    required String name,
    required String displayName,
    required List<String> permissions,
    String? description,
  });

  Future<Either<Failure, RoleEntity>> updateRole({
    required String roleId,
    String? displayName,
    String? description,
    List<String>? permissions,
  });

  Future<Either<Failure, void>> deleteRole(String roleId);

  // عمليات الصلاحيات
  Future<Either<Failure, List<PermissionEntity>>> getPermissions();

  Future<Either<Failure, List<PermissionEntity>>> getPermissionsByCategory(
    String category,
  );

  // إحصائيات
  Future<Either<Failure, Map<String, int>>> getUsersStatistics();

  // التحقق من وجود مستخدم
  Future<Either<Failure, bool>> checkUserExists({
    required String name,
    required String roleCode,
  });

  // البحث عن أسماء المستخدمين
  Future<Either<Failure, List<String>>> searchUserNames({
    required String query,
  });

  // البحث عن بريد المستخدمين الإلكتروني
  Future<Either<Failure, List<String>>> searchUserEmails({
    required String query,
  });

  // البحث عن أرقام هواتف المستخدمين
  Future<Either<Failure, List<String>>> searchUserPhones({
    required String query,
  });

  // البحث عن رموز الوصول
  Future<Either<Failure, List<String>>> searchRoleCodes({
    required String query,
  });

  Future<String?> getUserNameById(String userId);

  // إعدادات المستخدمين
  Future<Either<Failure, Map<String, dynamic>>> getUsersSettings();

  Future<Either<Failure, Map<String, dynamic>>> saveUsersSettings(
    Map<String, dynamic> settings,
  );

  // إعدادات الإشعارات لكل مستخدم
  Future<Either<Failure, UserManagementEntity>> updateUserNotificationSettings({
    required String userId,
    required bool notificationEnabled,
  });

  // سجل نشاطات المستخدمين
  Future<Either<Failure, List<UserLogEntity>>> getUserLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  Future<Either<Failure, UserLogEntity>> addUserLog({
    required String userId,
    required String actionType,
    String? userName,
    String? userEmail,
    String? details,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
    Map<String, dynamic>? deviceInfo,
    bool isSuccess = true,
  });

  Future<Either<Failure, void>> deleteUserLog(String logId);

  Future<Either<Failure, void>> clearUserLogs({
    String? userId,
    DateTime? beforeDate,
  });
}
