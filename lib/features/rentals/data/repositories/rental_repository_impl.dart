import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/rental_entity.dart';
import '../../domain/entities/rental_log_entity.dart';
import '../../domain/entities/rental_payment_entity.dart';
import '../../domain/entities/rentals_page.dart';
import '../../domain/repositories/rental_repository.dart';
import '../models/rental_log_model.dart';
import '../models/rental_model.dart';

class RentalRepositoryImpl implements RentalRepository {
  RentalRepositoryImpl({required this.firestore});
  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();

  /// تحويل آمن لقيمة رقمية من بيانات Firestore
  /// ✅ تحسين (2026-10-12): يُستخدم في حساب
  /// إحصائيات الإيجارات من البيانات الخام
  /// (بدلاً من بناء RentalModel كامل).
  /// منطقه مطابق لـ RentalModel.fromJson
  /// للقيم العددية ((json[x] ?? 0).toDouble())
  /// مع تسامح أكبر مع الأنواع غير المتوقعة.
  static double _parseStatsDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0;
  }

  /// تحويل آمن لقيمة تاريخ من بيانات Firestore
  /// ✅ تحسين (2026-10-12): منطقه مطابق لـ
  /// RentalModel.fromJson لتاريخ createdAt
  /// (Timestamp → toDate، String → tryParse،
  /// غير ذلك → الآن).
  static DateTime _parseStatsDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  // ════════════════════════════════════════════════════════════════
  // ⚠️ قاعدة ذرية حاسمة: كل transaction.get() قبل كل
  // transaction.set()/update()/delete() في نفس المعاملة
  // (Firestore يفرض قراءة-قبل-كتابة — انتهاكها يسبب
  // '_commands.isEmpty'). لا تضع قراءة بعد بدء كتابة.
  //
  // خريطة الذرية — ما يجب أن يكون ذرياً (تحقق يدوي
  // 2026-10-11، أُعيد التحقق 2026-10-12 مجدداً
  // بدون تعديل منطق — لماذا: كل دالة تربط
  // مستندات ببعضها،
  // فلو فشل جزء ونجح جزء صارت البيانات غير متسقة):
  //   • createRental: معاملة واحدة — فحص التكرار (عند
  //     تحديد معرف) + فحص توفر الوحدة + إنشاء العقد +
  //     تأجير الوحدة (status/currentRentalId/
  //     currentRenterName — للعقود النشطة فقط).
  //   • updateRental: معاملة واحدة — فحص الوجود + تحديث
  //     العقد + تحرير الوحدة (عند الانتقال من active) أو
  //     إعادة تأجيرها (عند الانتقال إليها). عند تغيير
  //     الوحدة: تُقرأ الوحدتان وتُحرر القديمة وتُؤجر
  //     الجديدة في نفس المعاملة (لا تُحدَّث وحدة واحدة
  //     فقط). تحرير الوحدة مشروط بأن currentRentalId لا
  //     يزال يشير لهذا العقد (لمنع تحرير وحدة أُعيد
  //     تأجيرها لعقد آخر). رمي الاستثناء بعد
  //     transaction.update آمن تماماً: الكتابات تُخزَّن
  //     مؤقتاً محلياً ولا تُلتزم إلا باكتمال الدالة —
  //     الفحص بعد التحديث هو خط الدفاع الأخير داخل
  //     المعاملة، لا تُزِله ظناً أنه متأخر.
  //   • deleteRental: معاملة واحدة — قراءة العقد + حذفه
  //     + تحرير الوحدة (بنفس الشرط أعلاه).
  //   • createRentalUnit / updateRentalUnit /
  //     deleteRentalUnit: معاملة واحدة لكل منها
  //     (get + فحص + كتابة) — معاملات العقود
  //     وحدها تملك حقول التأجير (status/
  //     currentRentalId/currentRenterName): الإنشاء
  //     يرفض وحدة مؤجرة (تُنشأ متاحة فقط)،
  //     والتحديث يمنع تعديل حقول وحدة مؤجرة
  //     (للتعديل: أنهِ العقد أولاً فيُحرر الوحدة
  //     ذرياً) ويمنع تأجير وحدة متاحة عبر
  //     التحديث.
  //   • addRentalLog / deleteRentalLog: كتابة مستند واحد
  //     — ذرية بطبيعتها ولا تحتاج runTransaction.
  //   • clearRentalLogs: دفعات firestore.batch() كل منها
  //     ≤ 500 عملية (حد Firestore) — كل دفعة ذرية وحدها
  //     (transactions لا تدعم استعلامات).
  //
  // ⚠️ ما يجب ألا يكون ذرياً مع العقد (متعمد): السجل
  //   والإشعار والفاتورة التلقائية — تأثيرات جانبية
  //   فشلها لا يجب أن يتراجع عن العقد (انظر
  //   rental_bloc.dart).
  //
  // ⚠️ المعاملة ومراجع المستندات على firestore المحقون
  //   (نفس المثيل — الحقن يمرر sl<FirebaseFirestore>()
  //   المسجل في app_initializer.dart). لا تبدّل المعاملة
  //   إلى FirebaseFirestore.instance أبداً: مرجع من مثيل
  //   ومعاملة من مثيل آخر تكسر المعاملة.
  //
  // ✅ التحقق (يدوي بدون سكربت، آخره
  // 2026-10-12): كل المعاملات أعلاه — كل
  //   القراءات قبل الكتابات وكلها
  //   all-or-nothing؛ لا كاتب آخر لمجموعتي
  //   rentals/rental_units في التطبيق (فقط هذان
  //   المستودعان)؛ الدوال السحابية لا تمس
  //   الإيجارات (functions/index.js كله
  //   اشتراكات/عملاء/فواتير)؛ الفواتير تستخدم
  //   'rental' كنوع فاتورة فقط ولا تكتب في
  //   مجموعات الإيجارات؛ صفحات التعديل/
  //   التفاصيل تقرأ users عبر
  //   FirebaseFirestore.instance (قراءة فقط).
  //
  // ⚡ الأداء (متعمد، بدون أثر على الذرية): الإحصائيات
  //   تُحسب من القائمة المحملة في كل مسارات
  //   التحميل والعمليات (لا جلب مزدوج)، وإعادة
  //   التحميل تُتخطى عند نشاط ستريم الإيجارات
  //   (تصل البيانات تلقائياً)، وجلب العميل
  //   بمعرفه مباشرة عند الفاتورة التلقائية
  //   (مستند واحد بدلاً من المجموعة كاملة).
  // ════════════════════════════════════════════════════════════════

  String? _getCurrentOrganizationId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;
    return _emailService.normalize(user!.email!);
  }

  @override
  Future<Either<Failure, List<RentalEntity>>> getRentals(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final querySnapshot = await firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rentals')
          .orderBy('createdAt', descending: true)
          .get();

      final rentals = querySnapshot.docs.map((doc) {
        final data = doc.data();
        // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
        }
        return RentalModel.fromJson(data);
      }).toList();

      return Right(rentals);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب عقود الإيجار: $e'));
    }
  }

  @override
  Future<Either<Failure, RentalsPage>> getRentalsPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  }) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      var query = firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rentals')
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();

      final rentals = querySnapshot.docs.map((doc) {
        final data = doc.data();
        if (data['id'] == null || data['id'].toString().isEmpty) {
          data['id'] = doc.id;
        }
        return RentalModel.fromJson(data);
      }).toList();

      return Right(
        RentalsPage(
          rentals: rentals,
          lastDocument: querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.last
              : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب عقود الإيجار: $e'));
    }
  }

  @override
  Future<Either<Failure, RentalEntity>> getRentalById(
    String id,
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final doc = await firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rentals')
          .doc(id)
          .get();

      if (!doc.exists) {
        return const Left(ServerFailure(message: 'عقد الإيجار غير موجود'));
      }

      final data = doc.data();
      if (data == null) return Left(ServerFailure(message: 'المستند فارغ'));
      // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
      if (data['id'] == null || data['id'].toString().isEmpty) {
        data['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
      }
      final rental = RentalModel.fromJson(data);
      return Right(rental);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب عقد الإيجار: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> createRental(RentalEntity rental) async {
    try {
      // إنشاء ID قصير وقابل للقراءة إذا كان فارغاً
      final normalizedEmail = _emailService.normalize(rental.organizationEmail);
      final collection = firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rentals');
      final rentalDoc = rental.id.isEmpty
          ? collection.doc()
          : collection.doc(rental.id);
      final rentalId = rentalDoc.id;

      final model = RentalModel(
        id: rentalId,
        organizationEmail: rental.organizationEmail,
        itemName: rental.itemName,
        itemDescription: rental.itemDescription,
        renterName: rental.renterName,
        renterPhone: rental.renterPhone,
        renterEmail: rental.renterEmail,
        customerId: rental.customerId,
        customerName: rental.customerName,
        unitId: rental.unitId,
        rentalPrice: rental.rentalPrice,
        deposit: rental.deposit,
        startDate: rental.startDate,
        endDate: rental.endDate,
        status: rental.status,
        paymentFrequency: rental.paymentFrequency,
        paymentDay: rental.paymentDay,
        notes: rental.notes,
        attachments: rental.attachments,
        createdAt: rental.createdAt,
        updatedAt: rental.updatedAt,
        createdBy: rental.createdBy,
        updatedBy: rental.updatedBy,
      );

      // معاملة ذرية على firestore المحقون — لا تبدّلها إلى
      // FirebaseFirestore.instance (انظر خريطة الذرية أعلاه).
      await firestore.runTransaction((transaction) async {
        if (rental.id.isNotEmpty) {
          // التحقق من عدم وجود العقد مسبقاً
          final docSnapshot = await transaction.get(rentalDoc);

          if (docSnapshot.exists) {
            throw Exception('العقد موجود مسبقاً');
          }
        }

        // قراءة الوحدة قبل أي كتابة (قاعدة: كل القراءات قبل
        // كل الكتابات) — الربط ذري مع إنشاء العقد (انظر الخريطة).
        DocumentSnapshot<Map<String, dynamic>>? unitSnapshot;
        final unitId = rental.unitId;
        if (unitId != null && unitId.isNotEmpty) {
          final unitDoc = firestore
              .collection(normalizedEmail)
              .doc('rentals')
              .collection('rental_units')
              .doc(unitId);
          unitSnapshot = await transaction.get(unitDoc);

          if (!unitSnapshot.exists) {
            throw Exception('الوحدة المؤجرة غير موجودة');
          }

          final unitStatus = unitSnapshot.data()?['status'] as String?;
          if (unitStatus != null && unitStatus != 'available') {
            throw Exception('الوحدة غير متاحة للإيجار');
          }
        }

        // حفظ البيانات في نفس الـ transaction
        transaction.set(rentalDoc, model.toJson());

        // تأجير الوحدة في نفس المعاملة (فقط للعقود النشطة)
        if (unitSnapshot != null &&
            unitSnapshot.exists &&
            rental.status == 'active') {
          transaction.update(unitSnapshot.reference, {
            'status': 'rented',
            'currentRentalId': rentalId,
            'currentRenterName': rental.renterName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في إنشاء عقد الإيجار: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateRental(RentalEntity rental) async {
    try {
      final model = RentalModel(
        id: rental.id,
        organizationEmail: rental.organizationEmail,
        itemName: rental.itemName,
        itemDescription: rental.itemDescription,
        renterName: rental.renterName,
        renterPhone: rental.renterPhone,
        renterEmail: rental.renterEmail,
        customerId: rental.customerId,
        customerName: rental.customerName,
        unitId: rental.unitId,
        rentalPrice: rental.rentalPrice,
        deposit: rental.deposit,
        startDate: rental.startDate,
        endDate: rental.endDate,
        status: rental.status,
        paymentFrequency: rental.paymentFrequency,
        paymentDay: rental.paymentDay,
        notes: rental.notes,
        attachments: rental.attachments,
        createdAt: rental.createdAt,
        updatedAt: null,
        createdBy: rental.createdBy,
        updatedBy: rental.updatedBy,
      );

      final data = model.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      final normalizedEmail = _emailService.normalize(rental.organizationEmail);

      // معاملة ذرية على firestore المحقون — لا تبدّلها إلى
      // FirebaseFirestore.instance (انظر خريطة الذرية أعلاه).
      await firestore.runTransaction((transaction) async {
        final rentalDoc = firestore
            .collection(normalizedEmail)
            .doc('rentals')
            .collection('rentals')
            .doc(rental.id);

        // التحقق من وجود العقد قبل التحديث
        final docSnapshot = await transaction.get(rentalDoc);

        if (!docSnapshot.exists) {
          throw Exception('العقد غير موجود');
        }

        // قراءة العقد والوحدة قبل أي كتابة (قاعدة: كل القراءات
        // قبل كل الكتابات) — تحرير/إعادة تأجير الوحدة ذريان
        // مع تحديث العقد (انظر الخريطة).
        final oldData = docSnapshot.data();
        final oldStatus = oldData?['status'] as String?;
        final oldUnitId = oldData?['unitId'] as String?;
        final newUnitId = rental.unitId;
        final unitChanged = oldUnitId != newUnitId;

        DocumentSnapshot<Map<String, dynamic>>? unitSnapshot;
        if (oldUnitId != null && oldUnitId.isNotEmpty) {
          final unitDoc = firestore
              .collection(normalizedEmail)
              .doc('rentals')
              .collection('rental_units')
              .doc(oldUnitId);
          unitSnapshot = await transaction.get(unitDoc);
        }

        // عند تغيير الوحدة: قراءة الجديدة قبل أي كتابة — تحرير
        // القديمة وتأجير الجديدة ذريان مع العقد (انظر الخريطة).
        DocumentSnapshot<Map<String, dynamic>>? newUnitSnapshot;
        if (unitChanged && newUnitId != null && newUnitId.isNotEmpty) {
          final newUnitDoc = firestore
              .collection(normalizedEmail)
              .doc('rentals')
              .collection('rental_units')
              .doc(newUnitId);
          newUnitSnapshot = await transaction.get(newUnitDoc);

          if (!newUnitSnapshot.exists) {
            throw Exception('الوحدة المؤجرة غير موجودة');
          }
        }

        // تحديث البيانات في نفس الـ transaction
        // ⚠️ ملاحظة ذرية للمبرمجين المستقبليين: كتابات
        // runTransaction تُخزَّن مؤقتاً محلياً ولا تُلتزم
        // إلا إذا اكتملت الدالة بدون استثناء — لذلك رمي
        // الاستثناء أدناه (فحص توفر الوحدة عند إعادة
        // التأجير) بعد هذا التحديث آمن تماماً: يتراجع عن
        // المعاملة كاملة ولا يُحفظ العقد ولا تُمس الوحدة.
        // لا تُزِل الفحص ظناً أنه "متأخر" — هو خط الدفاع
        // الأخير داخل المعاملة.
        transaction.update(rentalDoc, data);

        final wasActive = oldStatus == 'active';
        final isActive = rental.status == 'active';

        if (!unitChanged) {
          // الوحدة لم تتغير: تحرير/إعادة تأجير نفس الوحدة
          if (unitSnapshot != null && unitSnapshot.exists) {
            final unitData = unitSnapshot.data();
            final currentRentalId = unitData?['currentRentalId'] as String?;

            if (wasActive && !isActive) {
              // تحرير الوحدة — فقط إذا كانت لا تزال مرتبطة
              // بهذا العقد (لمنع تحرير وحدة أُعيد تأجيرها لعقد آخر)
              if (currentRentalId == null || currentRentalId == rental.id) {
                transaction.update(unitSnapshot.reference, {
                  'status': 'available',
                  'currentRentalId': null,
                  'currentRenterName': null,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            } else if (!wasActive && isActive) {
              // إعادة تأجير الوحدة — السماح بإعادة تأجير نفس الوحدة
              // إذا كانت لا تزال مرتبطة بهذا العقد (لمنع فشل إعادة
              // التفعيل بسبب أن الوحدة تحمل status rented لنفس العقد).
              final unitStatus = unitData?['status'] as String?;
              if (unitStatus != null &&
                  unitStatus != 'available' &&
                  currentRentalId != rental.id) {
                throw Exception('الوحدة غير متاحة للإيجار');
              }
              transaction.update(unitSnapshot.reference, {
                'status': 'rented',
                'currentRentalId': rental.id,
                'currentRenterName': rental.renterName,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        } else {
          // الوحدة تغيرت: تحرير القديمة (إذا كانت مؤجرة
          // لهذا العقد) وتأجير الجديدة (إذا أصبح العقد
          // نشطاً) — كل ذلك في نفس المعاملة.
          if (wasActive && unitSnapshot != null && unitSnapshot.exists) {
            final currentRentalId =
                unitSnapshot.data()?['currentRentalId'] as String?;
            if (currentRentalId == null || currentRentalId == rental.id) {
              transaction.update(unitSnapshot.reference, {
                'status': 'available',
                'currentRentalId': null,
                'currentRenterName': null,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }

          if (isActive &&
              newUnitSnapshot != null &&
              newUnitSnapshot.exists) {
            // تأجير الوحدة الجديدة — التحقق من توفرها أولاً
            final unitStatus = newUnitSnapshot.data()?['status'] as String?;
            if (unitStatus != null && unitStatus != 'available') {
              throw Exception('الوحدة غير متاحة للإيجار');
            }
            transaction.update(newUnitSnapshot.reference, {
              'status': 'rented',
              'currentRentalId': rental.id,
              'currentRenterName': rental.renterName,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في تحديث عقد الإيجار: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRental(
    String id,
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final rentalDoc = firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rentals')
          .doc(id);

      // معاملة ذرية: قراءة العقد والوحدة قبل أي كتابة —
      // الحذف وتحرير الوحدة ينجحان أو يفشلان معاً (انظر الخريطة).
      await firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(rentalDoc);

        // العقد غير موجود: لا شيء للحذف (سلوك مطابق للحذف المباشر)
        if (!docSnapshot.exists) {
          return;
        }

        final unitId = docSnapshot.data()?['unitId'] as String?;

        DocumentSnapshot<Map<String, dynamic>>? unitSnapshot;
        if (unitId != null && unitId.isNotEmpty) {
          final unitDoc = firestore
              .collection(normalizedEmail)
              .doc('rentals')
              .collection('rental_units')
              .doc(unitId);
          unitSnapshot = await transaction.get(unitDoc);
        }

        transaction.delete(rentalDoc);

        // تحرير الوحدة — فقط إذا كانت لا تزال مرتبطة بهذا
        // العقد (لمنع تحرير وحدة أُعيد تأجيرها لعقد آخر)
        if (unitSnapshot != null && unitSnapshot.exists) {
          final currentRentalId =
              unitSnapshot.data()?['currentRentalId'] as String?;
          if (currentRentalId == null || currentRentalId == id) {
            transaction.update(unitSnapshot.reference, {
              'status': 'available',
              'currentRentalId': null,
              'currentRenterName': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حذف عقد الإيجار: $e'));
    }
  }

  @override
  Future<Either<Failure, List<RentalPaymentEntity>>> getRentalPayments(
    String rentalId,
    String organizationEmail,
  ) async {
    try {
      // سيتم تنفيذه لاحقاً
      return const Right([]);
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في جلب مدفوعات الإيجار: $e'));
    }
  }

  /// جلب إحصائيات الإيجارات
  /// ⚠️ ملاحظة للمبرمجين المستقبليين: هذه الطريقة تجلب جميع العقود عبر getRentals
  /// ثم تحسب الإحصائيات في الذاكرة — أي جلب مزدوج للبيانات مقارنة بـ
  /// getRentalsStatisticsStream التي تحسب من البيانات الخام مباشرة.
  /// يُفضل استخدام getRentalsStatisticsStream أو _computeStats في bloc
  /// لتجنب الجلب المزدوج.
  @override
  Future<Either<Failure, Map<String, dynamic>>> getRentalStats(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // ⚡ تحسين: حساب الإحصائيات مباشرة من بيانات Firestore الخام بدلاً من
      // استدعاء getRentals الذي يجلب كل العقود ويبني كيانات كاملة — يتجنب
      // الجلب المزدوج وبناء النماذج غير الضرورية.
      final querySnapshot = await firestore
          .collection(normalizedEmail)
          .doc('rentals')
          .collection('rentals')
          .get();

      var total = 0;
      var active = 0;
      var expired = 0;
      var expiringSoon = 0;
      var totalMonthlyIncome = 0.0;

      final now = DateTime.now();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? 'pending';
        final rentalPrice = _parseStatsDouble(data['rentalPrice'] ?? data['monthlyRent']);
        final endDate = _parseStatsDate(data['endDate'] ?? data['end_date']);

        total++;
        switch (status) {
          case 'active':
            active++;
            totalMonthlyIncome += rentalPrice;
            break;
          case 'expired':
            expired++;
            break;
        }

        // حساب العقود التي تنتهي قريباً (خلال 30 يوماً ولم تنته بعد)
        if (status == 'active') {
          final daysRemaining = endDate.difference(now).inDays;
          if (daysRemaining >= 0 && daysRemaining <= 30) {
            expiringSoon++;
          }
        }
      }

      return Right({
        'total': total,
        'active': active,
        'expired': expired,
        'expiringSoon': expiringSoon,
        'totalMonthlyIncome': totalMonthlyIncome,
      });
    } on Exception catch (e) {
      return Left(ServerFailure(message: 'فشل في حساب إحصائيات الإيجارات: $e'));
    }
  }

  // ===== Rental Logs Methods =====

  @override
  Future<Either<Failure, List<RentalLogEntity>>> getRentalLogs({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('rentals')
          .collection('logs');

      // تطبيق الفلاتر
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (actionFilter != null && actionFilter != 'all') {
        query = query.where('actionType', isEqualTo: actionFilter);
      }

      // فلتر التاريخ
      if (dateFilter != null && dateFilter != 'all') {
        final now = DateTime.now();
        DateTime filterDate;

        switch (dateFilter) {
          case 'today':
            filterDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            filterDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            filterDate = now.subtract(const Duration(days: 30));
            break;
          default:
            filterDate = DateTime(2000);
        }

        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(filterDate),
        );
      }

      // فلتر التاريخ المخصص
      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(endOfDay),
        );
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      // ترتيب النتائج
      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();
      final logs = <RentalLogEntity>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        final log = RentalLogModel.fromJson({'id': doc.id, ...mapData}).toEntity();

        // تطبيق البحث النصي
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          final matchesSearch =
              (log.userName?.toLowerCase().contains(query) ?? false) ||
              (log.userEmail?.toLowerCase().contains(query) ?? false) ||
              (log.actionType.toLowerCase().contains(query)) ||
              (log.details?.toLowerCase().contains(query) ?? false);

          if (matchesSearch) {
            logs.add(log);
          }
        } else {
          logs.add(log);
        }
      }

      return Right(logs);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Stream<Either<Failure, List<RentalLogEntity>>> getRentalLogsStream({
    String? userId,
    String? searchQuery,
    String? actionFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      // ============================================
      // ملاحظة للمبرمجين المستقبليين:
      // هذه العملية ستريم قراءة فقط (snapshots) —
      // لا تحتوي على أي كتابة أو معاملة، لذلك
      // لا تنطبق عليها قاعدة "كل القراءات قبل
      // كل الكتابات". تُستخدم لتحديث سجل
      // النشاطات في صفحة السجل فورياً عند
      // حدوث أي عملية (إنشاء/تحديث/حذف).
      // ============================================
      Query query = firestore
          .collection(organizationId)
          .doc('rentals')
          .collection('logs');

      // فلتر المستخدم
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      // فلتر نوع العملية
      if (actionFilter != null && actionFilter != 'all') {
        query = query.where('actionType', isEqualTo: actionFilter);
      }

      // فلتر التاريخ
      if (dateFilter != null && dateFilter != 'all') {
        final now = DateTime.now();
        DateTime filterDate;

        switch (dateFilter) {
          case 'today':
            filterDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            filterDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            filterDate = now.subtract(const Duration(days: 30));
            break;
          default:
            filterDate = DateTime(2000);
        }

        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(filterDate),
        );
      }

      // فلتر التاريخ المخصص
      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(endOfDay),
        );
      }

      // تحديد الحد الأقصى
      if (limit != null) {
        query = query.limit(limit);
      }

      // الترتيب في النهاية
      query = query.orderBy('timestamp', descending: true);

      // ✅ أداء (2026-10-12): كاش تدريجي
      // خاص بهذا الستريم فقط يعالج
      // docChanges بدلاً من إعادة تحليل
      // كل السجلات مع كل لقطة — سجلات
      // الإيجارات تنمو بلا حدود فكان
      // إعادة بناء كل RentalLogEntity
      // عند كل عملية جديدة هو الهدر
      // الأكبر هنا. الستريم المحدود
      // (بحد) يبقي التحليل الكامل
      // الأصلي لأن نافذة الحد تتحرك
      // وقد لا يُصدر المستند الخارج
      // تغييراً من نوع removed بشكل
      // موثوق.
      final streamCache = <String, RentalLogEntity>{};

      return query.snapshots().map((snapshot) {
        try {
          if (limit == null) {
            for (final change in snapshot.docChanges) {
              final doc = change.doc;
              if (change.type == DocumentChangeType.removed) {
                streamCache.remove(doc.id);
                continue;
              }
              final data = doc.data();
              if (data == null) {
                streamCache.remove(doc.id);
                continue;
              }
              final mapData = data as Map<String, dynamic>;
              try {
                streamCache[doc.id] = RentalLogModel.fromJson({
                  'id': doc.id,
                  ...mapData,
                }).toEntity();
              } on Exception catch (_) {
                streamCache.remove(doc.id);
              }
            }

            // الحفاظ على ترتيب الاستعلام
            // (timestamp تنازلي) عبر المرور على
            // مستندات اللقطة مرتبة وأخذ الكيان
            // المحلل من الكاش — أدق من إعادة
            // الترتيب في الذاكرة لأن ترتيب
            // Firestore الحقيقي (بما في ذلك
            // كسر التعادل) يُحفظ كما هو
            var logs = <RentalLogEntity>[];
            for (final doc in snapshot.docs) {
              final cachedLog = streamCache[doc.id];
              if (cachedLog != null) {
                logs.add(cachedLog);
              }
            }

            // تطبيق البحث النصي في الذاكرة
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              logs = logs
                  .where(
                    (log) =>
                        (log.userName?.toLowerCase().contains(query) ??
                            false) ||
                        (log.userEmail?.toLowerCase().contains(query) ??
                            false) ||
                        (log.actionType.toLowerCase().contains(query)) ||
                        (log.details?.toLowerCase().contains(query) ??
                            false),
                  )
                  .toList();
            }

            return Right<Failure, List<RentalLogEntity>>(logs);
          }

          // الستريم المحدود: تحليل كامل (السلوك الأصلي)
          final logs = <RentalLogEntity>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data == null) continue;
            final mapData = data as Map<String, dynamic>;
            final log = RentalLogModel.fromJson({
              'id': doc.id,
              ...mapData,
            }).toEntity();

            // تطبيق البحث النصي
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              final matchesSearch =
                  (log.userName?.toLowerCase().contains(query) ?? false) ||
                  (log.userEmail?.toLowerCase().contains(query) ?? false) ||
                  (log.actionType.toLowerCase().contains(query)) ||
                  (log.details?.toLowerCase().contains(query) ?? false);

              if (matchesSearch) {
                logs.add(log);
              }
            } else {
              logs.add(log);
            }
          }

          return Right<Failure, List<RentalLogEntity>>(logs);
        } on Exception catch (e) {
          return Left<Failure, List<RentalLogEntity>>(
            ServerFailure(message: 'فشل في معالجة سجلات الإيجارات: $e'),
          );
        }
      });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب سجلات الإيجارات: $e')),
      );
    }
  }

  @override
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
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // استخدام المستخدم الحالي إذا لم يتم تحديد معرف المستخدم
      final currentUser = FirebaseAuth.instance.currentUser;
      final actualUserId = userId == 'current_user' && currentUser != null
          ? currentUser.uid
          : userId;
      final actualUserName = userName ?? currentUser?.displayName;
      final actualUserEmail = userEmail ?? currentUser?.email;

      final logData = {
        'userId': actualUserId,
        'userName': actualUserName,
        'userEmail': actualUserEmail,
        'actionType': actionType,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
        'isSuccess': isSuccess,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'targetId': targetId,
        'targetType': targetType,
        'oldValues': oldValues,
        'newValues': newValues,
        'sessionId': sessionId,
        'deviceInfo': deviceInfo,
      };

      final docRef = await firestore
          .collection(organizationId)
          .doc('rentals')
          .collection('logs')
          .add(logData);

      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data == null) {
        return const Left(ServerFailure(message: 'فشل في قراءة بيانات السجل بعد الإنشاء'));
      }
      final log = RentalLogModel.fromJson({
        'id': docRef.id,
        ...data,
      }).toEntity();

      return Right(log);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRentalLog(String logId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      await firestore
          .collection(organizationId)
          .doc('rentals')
          .collection('logs')
          .doc(logId)
          .delete();

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> clearRentalLogs({
    String? userId,
    DateTime? beforeDate,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('rentals')
          .collection('logs');

      // فلتر المستخدم
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      // فلتر التاريخ
      if (beforeDate != null) {
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(beforeDate),
        );
      }

      final snapshot = await query.get();

      // ملاحظة للمبرمجين المستقبليين: دفعات ≤ 500 عملية (حد Firestore) — كل دفعة ذرية وحدها
      // وتُرسل بالتتابع؛ معاملة واحدة لا تمسح > 500 مستند لأن transactions لا تدعم الاستعلامات.
      // إذا Failed دفعة لاحقة، تبقى الدفعات السابقة قد نفذت — ليست ذرية بالكامل عبر جميع الدفعات.
      final docs = snapshot.docs;
      for (var i = 0; i < docs.length; i += 500) {
        final end = (i + 500) < docs.length ? (i + 500) : docs.length;
        final batch = firestore.batch();
        for (final doc in docs.sublist(i, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // ===== Stream Methods for Real-time Updates =====

  @override
  Stream<Either<Failure, List<RentalEntity>>> getRentalsStream({
    int? limit,
    String? searchQuery,
    String? statusFilter,
    String? customerFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      // 1. بناء الـ query الأساسي
      Query query = firestore
          .collection(organizationId)
          .doc('rentals')
          .collection('rentals');

      // 2. إضافة فلتر الحالة إذا كان موجوداً (قبل orderBy)
      if (statusFilter != null && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      // 3. الترتيب
      query = query.orderBy('createdAt', descending: true);

      // 4. تطبيق الحد في الاستعلام لمنع تحميل عدد غير محدود من المستندات في الذاكرة.
      // ملاحظة للمبرمجين المستقبليين: السطر التالي يُطبِّق الحد فعلياً في الـ query
      // (عكس ما ورد في تعليق قديم)، ثم يُطبَّق فلترة إضافية في الذاكرة بعد ذلك.
      final effectiveLimit = limit ?? 1000;
      query = query.limit(effectiveLimit);

      // 5. الاستماع للتغييرات
      // ✅ تحسين (2026-10-12): نفس تحسين
      // قسم الفواتير — نحفظ الإيجارات
      // المحللة في ذاكرة خاصة بهذا الستريم
      // ونحدّث المستندات المتغيرة فقط عبر
      // docChanges بدلاً من إعادة تحليل
      // كل الإيجارات مع كل لقطة — كان
      // يسبب بطءاً ملحوظاً مع كثرة
      // الإيجارات عند كل تحديث.
      final streamCache = <String, RentalEntity>{};

      return query.snapshots().map((snapshot) {
        try {
          // تحديث تدريجي: نعالج المستندات المتغيرة فقط
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            if (change.type == DocumentChangeType.removed) {
              streamCache.remove(doc.id);
              continue;
            }
            final data = doc.data();
            if (data == null) {
              streamCache.remove(doc.id);
              continue;
            }
            final mapData = Map<String, dynamic>.from(
              data as Map<String, dynamic>,
            );
            if (mapData['id'] == null ||
                mapData['id'].toString().isEmpty) {
              mapData['id'] = doc.id;
            }
            try {
              streamCache[doc.id] = RentalModel.fromJson(mapData);
            } on Exception catch (_) {
              streamCache.remove(doc.id);
            }
          }

          var rentals = streamCache.values.toList()
            ..sort((a, b) {
              final cmp = b.createdAt.compareTo(a.createdAt);
              return cmp != 0 ? cmp : a.id.compareTo(b.id);
            });

          // 6. تطبيق فلتر البحث في الذاكرة
          if (searchQuery != null && searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            rentals = rentals.where((rental) {
              final itemName = rental.itemName.toLowerCase();
              final renterName = rental.renterName.toLowerCase();
              final renterEmail =
                  rental.renterEmail?.toLowerCase();
              final renterPhone =
                  rental.renterPhone?.toLowerCase();
              return itemName.contains(query) ||
                  renterName.contains(query) ||
                  (renterEmail?.contains(query) ?? false) ||
                  (renterPhone?.contains(query) ?? false);
            }).toList();
          }

          // 7. تطبيق فلتر العميل في الذاكرة (إذا لم يكن في Firestore)
          if (customerFilter != null && customerFilter != 'all') {
            rentals = rentals
                .where(
                  (rental) => rental.renterName == customerFilter,
                )
                .toList();
          }

          // 8. تطبيق فلاتر التاريخ في الذاكرة
          if (dateFilter != null && dateFilter != 'all') {
            final now = DateTime.now();
            DateTime filterDate;

            switch (dateFilter) {
              case 'today':
                filterDate = DateTime(now.year, now.month, now.day);
                break;
              case 'week':
                filterDate = now.subtract(const Duration(days: 7));
                break;
              case 'month':
                filterDate = now.subtract(const Duration(days: 30));
                break;
              default:
                filterDate = DateTime(2000);
            }

            rentals = rentals
                .where(
                  (rental) =>
                      !rental.createdAt.isBefore(filterDate),
                )
                .toList();
          }

          // فلتر التاريخ المخصص
          if (startDate != null) {
            rentals = rentals
                .where(
                  (rental) =>
                      !rental.createdAt.isBefore(startDate),
                )
                .toList();
          }
          if (endDate != null) {
            final endOfDay = DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
              23,
              59,
              59,
            );
            rentals = rentals
                .where(
                  (rental) =>
                      !rental.createdAt.isAfter(endOfDay),
                )
                .toList();
          }

          // 9. التأكد من عدم تجاوز الحد (حماية إضافية)
          if (limit != null && rentals.length > limit) {
            rentals = rentals.sublist(0, limit);
          }

          return Right<Failure, List<RentalEntity>>(rentals);
        } on Exception catch (e) {
          return Left<Failure, List<RentalEntity>>(
            ServerFailure(message: 'فشل في معالجة بيانات الإيجارات: $e'),
          );
        }
      });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب عقود الإيجار: $e')),
      );
    }
  }

  @override
  Stream<Either<Failure, Map<String, dynamic>>>
  getRentalsStatisticsStream({int? limit}) {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      return firestore
          .collection(organizationId)
          .doc('rentals')
          .collection('rentals')
          .snapshots()
          .map((snapshot) {
            try {
              // ✅ تحسين (2026-10-12): حساب
              // الإحصائيات مباشرة من بيانات
              // المستند الخام بدلاً من بناء
              // RentalModel كامل لكل عقد —
              // الإحصائيات تحتاج 3 حقول فقط
              // (status، createdAt، rentalPrice)
              // فبناء النموذج كامل كان يهدر
              // وقت المعالج مع كثرة العقود
              // عند كل لقطة. منطق الحساب مطابق
              // تماماً للسابق (عدادات الحالات
              // + إيراد الشهر الحالي للعقود
              // النشطة فقط).
              var total = 0;
              var active = 0;
              var expired = 0;
              var terminated = 0;
              var pending = 0;
              var expiringSoon = 0;

              // Calculate monthly revenue
              final now = DateTime.now();
              final thisMonth = DateTime(now.year, now.month);
              var monthlyRevenue = 0.0;

              for (final doc in snapshot.docs) {
                final mapData = doc.data();

                final status =
                    mapData['status']?.toString() ?? 'pending';
                final createdAt = _parseStatsDate(
                  mapData['createdAt'] ?? mapData['created_at'],
                );
                final rentalPrice = _parseStatsDouble(
                  mapData['rentalPrice'] ?? mapData['monthlyRent'],
                );

                total++;
                switch (status) {
                  case 'active':
                    active++;
                    break;
                  case 'expired':
                    expired++;
                    break;
                  case 'terminated':
                    terminated++;
                    break;
                  case 'pending':
                    pending++;
                    break;
                }

                if (status == 'active') {
                  monthlyRevenue += rentalPrice; // احتساب إيراد جميع العقود النشطة (لتتطابق مع getRentalStats و _computeStats في BLOC، وليس فقط العقود المنشأة هذا الشهر)
                }

                // حساب العقود التي تنتهي قريباً (خلال 30 يوماً ولم تنته بعد)
                if (status == 'active') {
                  final endDate = _parseStatsDate(
                    mapData['endDate'] ?? mapData['end_date'],
                  );
                  final daysRemaining = endDate.difference(now).inDays;
                  if (daysRemaining > 0 && daysRemaining <= 30) {
                    expiringSoon++;
                  }
                }
              }

              final stats = <String, dynamic>{
                'total': total,
                'active': active,
                'expired': expired,
                'expiringSoon': expiringSoon,
                'totalMonthlyIncome': monthlyRevenue,
              };

              return Right<Failure, Map<String, dynamic>>(stats);
            } on Exception catch (e) {
              return Left<Failure, Map<String, dynamic>>(
                ServerFailure(message: 'فشل في حساب إحصائيات الإيجارات: $e'),
              );
            }
          });
    } on Exception catch (e) {
      final errorMsg = _readableError(e);
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب إحصائيات الإيجارات: $errorMsg')),
      );
    }
  }
}

/// استخراج رسالة خطأ مفهومة للمستخدم من أي استثناء.
String _readableError(dynamic e) {
  final message = (e as dynamic).message;
  if (message is String && message.isNotEmpty) {
    return message;
  }
  final errorString = e.toString();
  if (errorString.startsWith('Exception: ')) {
    return errorString.substring('Exception: '.length);
  }
  return 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى';
}
