import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/shelf_entity.dart';
import '../entities/shelves_page.dart';
/// واجهة مستودع الأرفف
abstract class ShelfRepository {
  /// الحصول على جميع الأرفف
  Future<Either<Failure, List<ShelfEntity>>> getShelves({
    required String organizationEmail,
    String? zone,
    bool? isActive,
  });

  /// الحصول على الأرفف بشكل تدريجي (pagination)
  Future<Either<Failure, ShelvesPage>> getShelvesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  });

  /// ستريم الأرفف للتحديث الفوري (صفحة الأرفف)
  /// ⚠️ ملاحظة للمبرمجين المستقبليين:
  /// بدونها تُقرأ الأرفف مرة واحدة فقط (Future)
  /// وتبقى عدادات currentItems ونسبة الامتلاء
  /// قديمة عند تسنيد/نقل/حذف منتجات لأن لا
  /// شيء يُعيد تحميلها.
  Stream<Either<Failure, List<ShelfEntity>>> getShelvesStream({
    required String organizationEmail,
    String? zone,
    bool? isActive,
  });

  /// الحصول على رف بالمعرف
  Future<Either<Failure, ShelfEntity>> getShelfById({
    required String id,
    required String organizationEmail,
  });

  /// الحصول على الأرفف حسب المنطقة
  Future<Either<Failure, List<ShelfEntity>>> getShelvesByZone({
    required String organizationEmail,
    required String zone,
    bool? isActive,
  });

  /// إضافة رف جديد
  Future<Either<Failure, ShelfEntity>> createShelf({
    required ShelfEntity shelf,
  });

  /// تحديث رف
  Future<Either<Failure, ShelfEntity>> updateShelf({
    required ShelfEntity shelf,
  });

  /// حذف رف
  Future<Either<Failure, void>> deleteShelf({
    required String id,
    required String organizationEmail,
  });

  /// البحث في الأرفف
  Future<Either<Failure, List<ShelfEntity>>> searchShelves({
    required String organizationEmail,
    required String query,
  });

  /// التحقق من وجود منتجات في الرف
  Future<Either<Failure, bool>> hasProducts({
    required String shelfId,
    required String organizationEmail,
  });

  /// تحديث عدد العناصر في الرف
  Future<Either<Failure, ShelfEntity>> updateShelfItemCount({
    required String id,
    required String organizationEmail,
    required int newCount,
  });

  /// إعادة حساب عدد عناصر كل رف من المنتجات الفعلية
  /// المرسنة إليه (تصحيح عدادات البيانات القديمة لمرة
  /// واحدة — تُقرأ كل المنتجات في لقطة متسقة ثم تُحدَّث
  /// العدادات في WriteBatch واحد)
  Future<Either<Failure, void>> recalculateShelfItemCounts({
    required String organizationEmail,
  });

  /// الحصول على الأرفف الممتلئة
  Future<Either<Failure, List<ShelfEntity>>> getFullShelves({
    required String organizationEmail,
  });

  /// الحصول على الأرفف الفارغة
  Future<Either<Failure, List<ShelfEntity>>> getEmptyShelves({
    required String organizationEmail,
  });

  /// الحصول على إحصائيات الأرفف
  Future<Either<Failure, Map<String, dynamic>>> getShelvesStats({
    required String organizationEmail,
  });
}
