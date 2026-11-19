import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/customer_entity.dart';
import '../entities/customer_group_entity.dart';
import '../entities/customer_groups_page.dart';
import '../entities/customer_log_entity.dart';
import '../entities/customer_stats_entity.dart';
import '../entities/customers_page.dart';

abstract class CustomerRepository {
  Future<Either<Failure, List<CustomerEntity>>> getCustomers(
    String organizationEmail, {
    bool forceRefresh = false,
  });

  /// الحصول على العملاء مع pagination
  ///
  /// ✅ ملاحظة للمبرمجين المستقبليين: تُرجع
  /// CustomersPage التي تحمل آخر مستند في
  /// الصفحة (snapshot.docs.last) كمؤشر
  /// startAfterDocument للصفحة التالية —
  /// إعادته مع العملاء يمنع جلب المستند
  /// مجدداً عبر getCustomerDocument (جولة
  /// شبكة زائدة بعد كل تحميل صفحة).
  Future<Either<Failure, CustomersPage>> getCustomersPaginated({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
    String? searchQuery,
  });

  // الطرق الجديدة للـ streams
  Stream<Either<Failure, List<CustomerEntity>>> getCustomersStream(
    String organizationEmail, {
    int? limit,
    String? searchQuery,
  });
  Stream<Either<Failure, CustomerStatsEntity>> getCustomerStatsStream(
    String organizationEmail, {
    int? limit,
  });
  Stream<Either<Failure, List<CustomerGroupEntity>>> getCustomerGroupsStream();

  Future<Either<Failure, CustomerEntity>> getCustomerById(
    String id, {
    bool forceRefresh = false,
  });
  Future<Either<Failure, CustomerEntity>> addCustomer(CustomerEntity customer);
  Future<Either<Failure, CustomerEntity>> addCustomerWithOpeningBalance({
    required CustomerEntity customer,
    required double openingBalance,
    required String createdBy,
  });
  Future<Either<Failure, void>> updateCustomer(CustomerEntity customer);
  Future<Either<Failure, void>> deleteCustomer(
    String id,
    String organizationEmail,
  );
  Future<Either<Failure, CustomerStatsEntity>> getCustomerStats(
    String organizationEmail,
  );
  Future<Either<Failure, List<String>>> searchCustomerNames({
    required String query,
  });
  Future<Either<Failure, List<String>>> searchCustomerEmails({
    required String query,
  });
  Future<Either<Failure, List<String>>> searchCustomerPhones({
    required String query,
  });
  Future<Either<Failure, bool>> checkCustomerExists({
    required String name,
    required String email,
    required String phone,
  });

  /// التحقق من وجود العميل مع تفاصيل التكرار
  Future<Either<Failure, Map<String, dynamic>>> checkCustomerExistsDetailed({
    required String name,
    required String email,
    required String phone,
  });

  /// ⚡ التحقق من تفرد بريد عميل عبر قراءة مستند واحد من فهرس
  /// customer_emails (معرف المستند = البريد المطبّع) — قراءة O(1)
  /// بدلاً من تحميل كل العملاء. excludeCustomerId يستثني العميل
  /// نفسه عند التعديل. فحص مسبق للواجهة فقط؛ الفحص الذري النهائي
  /// داخل runTransaction في addCustomer/updateCustomer يستخدم نفس
  /// الفهرس.
  Future<Either<Failure, bool>> isCustomerEmailUnique(
    String email,
    String organizationEmail, {
    String? excludeCustomerId,
  });

  /// ⚡ نفس نمط isCustomerEmailUnique مطبّقاً على فهرس
  /// customer_phones (معرف المستند = الهاتف).
  Future<Either<Failure, bool>> isCustomerPhoneUnique(
    String phone,
    String organizationEmail, {
    String? excludeCustomerId,
  });

  // ===== Customer Groups Methods =====

  /// الحصول على جميع مجموعات العملاء
  Future<Either<Failure, List<CustomerGroupEntity>>> getCustomerGroups(
    String organizationEmail,
  );

  /// الحصول على مجموعات العملاء بشكل تدريجي (pagination)
  Future<Either<Failure, CustomerGroupsPage>> getCustomerGroupsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  });

  /// إنشاء مجموعة عملاء جديدة
  Future<Either<Failure, void>> createCustomerGroup(CustomerGroupEntity group);

  /// تحديث مجموعة عملاء
  Future<Either<Failure, void>> updateCustomerGroup(CustomerGroupEntity group);

  /// حذف مجموعة عملاء
  Future<Either<Failure, void>> deleteCustomerGroup(
    String groupId,
    String organizationEmail,
  );

  /// البحث عن أسماء مجموعات العملاء المشابهة
  Future<Either<Failure, List<String>>> searchCustomerGroupNames({
    required String query,
  });

  // ===== Customer Logs Methods =====

  /// الحصول على سجل نشاطات العملاء
  Future<Either<Failure, List<CustomerLogEntity>>> getCustomerLogs({
    required String organizationEmail,
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// الحصول على سجل نشاطات العملاء مع التحديث الفوري
  /// نفس فلاتر getCustomerLogs لكن باستماع مستمر لتغيرات السجلات
  /// (يُضاف سجل عند كل عملية على العملاء/المجموعات لذلك تحتاج الصفحة
  /// إلى تحديث فوري بدلاً من التحميل مرة واحدة)
  Stream<Either<Failure, List<CustomerLogEntity>>> getCustomerLogsStream({
    required String organizationEmail,
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// إضافة سجل نشاط جديد للعملاء
  Future<Either<Failure, CustomerLogEntity>> addCustomerLog({
    required String organizationEmail,
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
  Future<Either<Failure, void>> deleteCustomerLog(String logId);

  /// مسح سجلات النشاطات
  Future<Either<Failure, void>> clearCustomerLogs({
    String? userId,
    DateTime? beforeDate,
  });

  /// التحقق من أن مجموعة العميل موجودة ونشطة
  Future<Either<Failure, bool>> isCustomerGroupValid(
    String groupId,
    String organizationEmail,
  );
}
