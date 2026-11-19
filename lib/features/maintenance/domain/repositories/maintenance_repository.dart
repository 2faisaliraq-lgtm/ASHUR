import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/equipment_entity.dart';
import '../entities/maintenance_log_entity.dart';
import '../entities/maintenance_request_entity.dart';
import '../entities/maintenance_requests_page.dart';

/// واجهة مستودع الصيانة
abstract class MaintenanceRepository {
  /// جلب جميع طلبات الصيانة مع ترقيم الصفحات
  Future<Either<Failure, List<MaintenanceRequestEntity>>>
  getMaintenanceRequests(
    String organizationEmail, {
    dynamic lastDocument,
    int? limit,
  });

  /// جلب طلبات الصيانة مع pagination
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين: تُرجع
  /// MaintenanceRequestsPage التي تحمل آخر مستند
  /// في الصفحة (snapshot.docs.last) كمؤشر
  /// startAfterDocument للصفحة التالية — إعادته
  /// مع الطلبات يمنع جلب المستند مجدداً عبر
  /// معرفه (جولة شبكة زائدة بعد كل تحميل صفحة).
  Future<Either<Failure, MaintenanceRequestsPage>>
  getMaintenanceRequestsPaginated({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
  });

  /// البحث في طلبات الصيانة من جانب الخادم
  Future<Either<Failure, List<MaintenanceRequestEntity>>>
  searchMaintenanceRequests(
    String organizationEmail,
    String searchQuery, {
    dynamic lastDocument,
    int? limit,
  });

  /// جلب طلب صيانة محدد
  Future<Either<Failure, MaintenanceRequestEntity>> getMaintenanceRequestById(
    String id,
    String organizationEmail,
  );

  /// إنشاء طلب صيانة جديد
  Future<Either<Failure, String>> createMaintenanceRequest(
    MaintenanceRequestEntity request,
  );

  /// تحديث طلب صيانة
  Future<Either<Failure, void>> updateMaintenanceRequest(
    MaintenanceRequestEntity request,
  );

  /// حذف طلب صيانة
  Future<Either<Failure, void>> deleteMaintenanceRequest(
    String id,
    String organizationEmail,
  );

  /// جلب جميع المعدات
  Future<Either<Failure, List<EquipmentEntity>>> getEquipment(
    String organizationEmail,
  );

  /// جلب جميع المعدات كـ Stream للتحديث الفوري
  Stream<Either<Failure, List<EquipmentEntity>>> getEquipmentStream();

  // ===== Equipment CRUD Operations =====

  /// إضافة معدة جديدة
  Future<Either<Failure, String>> addEquipment(EquipmentEntity equipment);

  /// تحديث بيانات معدة
  Future<Either<Failure, void>> updateEquipment(EquipmentEntity equipment);

  /// حذف معدة
  Future<Either<Failure, void>> deleteEquipment(
    String id,
    String organizationEmail,
  );

  /// جلب إحصائيات الصيانة
  /// ⚡ requestsOverride/equipmentOverride: بيانات
  /// مجلوبة فعلاً (كاملة — كل الطلبات/المعدات)
  /// لتجنب جلبها مجدداً — تحسين أداء. لا تُمرَّر
  /// صفحة مرقّمة لأن الإحصائيات تحتاج الكل.
  Future<Either<Failure, Map<String, dynamic>>> getMaintenanceStats(
    String organizationEmail, {
    List<MaintenanceRequestEntity>? requestsOverride,
    List<EquipmentEntity>? equipmentOverride,
  });

  // ===== Stream Methods for Real-time Updates =====

  /// جلب طلبات الصيانة كـ Stream للتحديث الفوري
  Stream<Either<Failure, List<MaintenanceRequestEntity>>>
  getMaintenanceRequestsStream({
    int? limit,
    String? searchQuery,
    String? statusFilter,
    String? priorityFilter,
    String? equipmentFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// جلب إحصائيات الصيانة كـ Stream للتحديث الفوري
  Stream<Either<Failure, Map<String, dynamic>>> getMaintenanceStatisticsStream({
    int? limit,
  });

  // ===== Maintenance Logs Methods =====

  /// الحصول على سجل نشاطات الصيانة
  Future<Either<Failure, List<MaintenanceLogEntity>>> getMaintenanceLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// جلب سجل نشاطات الصيانة كـ Stream للتحديث الفوري
  Stream<Either<Failure, List<MaintenanceLogEntity>>>
  getMaintenanceLogsStream({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// إضافة سجل نشاط جديد للصيانة
  Future<Either<Failure, MaintenanceLogEntity>> addMaintenanceLog({
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

  /// حذف سجل نشاط محدد
  Future<Either<Failure, void>> deleteMaintenanceLog(String logId);

  /// مسح سجلات النشاطات
  Future<Either<Failure, void>> clearMaintenanceLogs({
    String? userId,
    DateTime? beforeDate,
  });
}
