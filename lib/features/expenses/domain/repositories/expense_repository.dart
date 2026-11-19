import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense_entity.dart';
import '../entities/expense_log_entity.dart';
import '../entities/expense_stats_entity.dart';

/// نتيجة صفحة من المصاريف — تشمل القائمة وآخر مستند في الصفحة.
/// لماذا؟ كانت التجزئة تجلب المستند الأخير بقراءة
/// إضافية عبر getExpenseDocument رغم أن استعلام
/// الصفحة يعيده أصلاً — دُمج هنا لتسريع التحميل
/// (قراءة أقل من Firestore لكل صفحة) ولمنع تكرار
/// الصفحات: تلك القراءة الإضافية كانت تُصفَّر
/// lastDocument عند فشلها فتُعاد الصفحة الأولى.
class ExpensePage {
  const ExpensePage({required this.expenses, this.lastSnapshot});
  final List<ExpenseEntity> expenses;
  final dynamic lastSnapshot;
}

/// واجهة مستودع المصاريف
abstract class ExpenseRepository {
  /// الحصول على جميع المصاريف
  Future<Either<Failure, List<ExpenseEntity>>> getExpenses(
    String organizationEmail,
  );

  /// الحصول على المصاريف مع pagination
  Future<Either<Failure, ExpensePage>> getExpensesPaginated({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
  });

  // الطرق الجديدة للـ streams
  Stream<Either<Failure, List<ExpenseEntity>>> getExpensesStream(
    String organizationEmail, {
    int? limit,
    String? searchQuery,
  });
  Stream<Either<Failure, ExpenseStatsEntity>> getExpenseStatsStream(
    String organizationEmail, {
    int? limit,
  });

  /// إضافة مصروف جديد
  Future<Either<Failure, void>> addExpense(ExpenseEntity expense);

  /// تحديث مصروف
  Future<Either<Failure, void>> updateExpense(ExpenseEntity expense);

  /// حذف مصروف
  Future<Either<Failure, void>> deleteExpense(
    String id,
    String organizationEmail,
  );

  /// الحصول على إحصائيات المصاريف
  Future<Either<Failure, ExpenseStatsEntity>> getExpenseStats(
    String organizationEmail,
  );

  /// حساب الإحصائيات من قائمة مصاريف مُحمّلة مسبقاً —
  /// حساب محلي مباشر بلا قراءة من Firestore (نفس نتيجة
  /// getExpenseStats لكن بدون رحلة شبكة ثانية عندما
  /// تكون القائمة مُحمّلة أصلاً).
  ExpenseStatsEntity computeExpenseStats(List<ExpenseEntity> expenses);

  // ===== Expense Logs Methods =====

  /// الحصول على سجل نشاطات المصاريف
  Future<Either<Failure, List<ExpenseLogEntity>>> getExpenseLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// الحصول على سجل نشاطات المصاريف مع التحديث الفوري
  Stream<Either<Failure, List<ExpenseLogEntity>>> getExpenseLogsStream({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  });

  /// إضافة سجل نشاط جديد للمصاريف
  Future<Either<Failure, ExpenseLogEntity>> addExpenseLog({
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
  Future<Either<Failure, void>> deleteExpenseLog(String logId);

  /// مسح سجلات النشاطات
  Future<Either<Failure, void>> clearExpenseLogs({
    String? userId,
    DateTime? beforeDate,
  });
}
