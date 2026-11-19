import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/rental_entity.dart';
import '../entities/rental_log_entity.dart';
import '../entities/rental_payment_entity.dart';
import '../entities/rentals_page.dart';

/// واجهة مستودع الإيجارات
abstract class RentalRepository {
  /// جلب جميع عقود الإيجار
  Future<Either<Failure, List<RentalEntity>>> getRentals(
    String organizationEmail,
  );

  /// جلب عقود الإيجار بشكل تدريجي (pagination)
  Future<Either<Failure, RentalsPage>> getRentalsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  });

  /// جلب عقد إيجار محدد
  Future<Either<Failure, RentalEntity>> getRentalById(
    String id,
    String organizationEmail,
  );

  /// إنشاء عقد إيجار جديد
  Future<Either<Failure, void>> createRental(RentalEntity rental);

  /// تحديث عقد إيجار
  Future<Either<Failure, void>> updateRental(RentalEntity rental);

  /// حذف عقد إيجار
  Future<Either<Failure, void>> deleteRental(
    String id,
    String organizationEmail,
  );

  /// جلب دفعات الإيجار لعقد معين
  Future<Either<Failure, List<RentalPaymentEntity>>> getRentalPayments(
    String rentalId,
    String organizationEmail,
  );

  /// جلب إحصائيات الإيجارات
  Future<Either<Failure, Map<String, dynamic>>> getRentalStats(
    String organizationEmail,
  );

  // ===== Stream Methods for Real-time Updates =====

  /// جلب عقود الإيجار كـ Stream للتحديث الفوري
  Stream<Either<Failure, List<RentalEntity>>> getRentalsStream({
    int? limit,
    String? searchQuery,
    String? statusFilter,
    String? customerFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// جلب إحصائيات الإيجارات كـ Stream للتحديث الفوري
  Stream<Either<Failure, Map<String, dynamic>>> getRentalsStatisticsStream({
    int? limit,
  });

  // ===== Rental Logs Methods =====

  /// الحصول على سجل نشاطات الإيجارات
  Future<Either<Failure, List<RentalLogEntity>>> getRentalLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// جلب سجل نشاطات الإيجارات كـ Stream للتحديث الفوري
  Stream<Either<Failure, List<RentalLogEntity>>> getRentalLogsStream({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// إضافة سجل نشاط جديد للإيجارات
  Future<Either<Failure, RentalLogEntity>> addRentalLog({
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
  Future<Either<Failure, void>> deleteRentalLog(String logId);

  /// مسح سجلات النشاطات
  Future<Either<Failure, void>> clearRentalLogs({
    String? userId,
    DateTime? beforeDate,
  });
}
