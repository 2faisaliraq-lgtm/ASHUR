import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/session_service.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/expense_log_entity.dart';
import '../../domain/entities/expense_stats_entity.dart';
import '../../domain/repositories/expense_repository.dart';
import '../models/expense_log_model.dart';
import '../models/expense_model.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl({required this.firestore});
  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();

  /// تحويل آمن لقيمة رقمية من بيانات Firestore
  /// ✅ تحسين (2026-10-12): يُستخدم في حساب
  /// إحصائيات المصروفات من البيانات الخام
  /// (بدلاً من بناء ExpenseModel كامل).
  /// منطقه مطابق لـ ExpenseModel.fromJson
  /// للقيم العددية ((json[x] as num?)?
  /// .toDouble() ?? 0.0) مع تسامح أكبر
  /// مع الأنواع غير المتوقعة.
  static double _parseStatsDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0;
  }

  // ════════════════════════════════════════════════════════════════
  // 🔒 العمليات الذرية في قسم المصاريف (آخر تحقق: 2026-10-12 ✅)
  // هذا المستودع نقطة الكتابة الوحيدة لمستندات المصاريف وسجلاتها
  // (BLoC والصفحات والـ UseCases لا يكتبون — الإنشاء عبر BLoC
  // فقط، والتفاصيل/التعديل تقرأان أسماء المستخدمين فقط،
  // ومستودع الفواتير يتبع النمط نفسه).
  // ⚠️ الصندوق يُكتب من جهات أخرى آمنة أيضاً: مستودع التقارير
  // (increment أحادي لتصحيحات الرصيد + batch الحركات اليدوية)
  // والدوال السحابية (اشتراكات/فواتير) — كلها FieldValue.increment
  // ذري على الخادم فلا تتقاطع مع معاملات المصاريف ولا تمس
  // مستنداتها.
  //
  // ✅ القواعد الذهبية (لا تنتهكها أبداً):
  // 1. أي عملية تعدّل أكثر من مستند = runTransaction واحد
  //    (all-or-nothing) — ولا تنقل جزءاً منها إلى BLoC أو
  //    UseCase أو خدمة خارجية.
  // 2. كل transaction.get() قبل كل set/update/delete — Firestore
  //    يفرض "all reads must happen before all writes" وإلا رُمي
  //    خطأ '_commands.isEmpty'.
  // 3. لا استعلامات (where().get()) داخل المعاملة —
  //    transaction.get() على مرجع معروف فقط.
  // 4. للعدادات استخدم FieldValue.increment() (ذري على الخادم
  //    ويمنع مشكلة Read-Modify-Write).
  // 5. سجل النشاط داخل نفس المعاملة بلا شرط وبمسار
  //    normalizedEmail (نمط الفواتير: newValues يشمل
  //    paidAmount و remainingAmount، وعند الحذف يُسجل
  //    oldValues) — أُصلح 2026-10-11 بعد أن كان يُكتب
  //    من BLoC عبر unawaited خارج المعاملة فانفصل عن
  //    العملية المالية؛ لا تجعله مشروطاً بمستخدم حالي
  //    ولا ببريد خام وإلا انفصل عن مستند المصروف أو فُقد.
  // 6. نسب العملية (updatedBy في الصندوق و userId في السجل)
  //    للمستخدم الفعلي (_getEffectiveUser: المُبدّل إليه ثم
  //    الحالي، يُحسب قبل المعاملة لثباته عند إعادة محاولتها)
  //    — الثلاث عمليات تستخدم effectiveUser?['id'] مباشرة
  //    لاتساق الإسناد مع createdBy/updatedBy التي تعيّنها
  //    الصفحات.
  //
  // ✅ ما تم التحقق من أنه ذري (أُعيد التحقق 2026-10-12 ✅):
  // • addExpense: حفظ المصروف + خصم الصندوق (increment(-paidAmount))
  //   + سجل النشاط في نفس المعاملة.
  // • updateExpense: قراءة المستند + تحديثه + تحديث الصندوق بالفرق
  //   (الجديد − القديم لـ paidAmount) + سجل النشاط في نفس المعاملة.
  // • deleteExpense: قراءة المصروف + إرجاع paidAmount للصندوق
  //   (increment(+paidAmount)) + الحذف + سجل النشاط في نفس المعاملة.
  // • clearExpenseLogs: batch.delete جماعي على دفعات 500
  //   عملية (حد Firestore) — كل batch كله أو لا شيء، لكن
  //   الذرية لكل batch وحده لا عبر الدفعات: إن انقطع
  //   التنفيذ منتصف الطريق تبقى الدفعات السابقة محذوفة
  //   (لا بديل — حد Firestore يمنع معاملة أوسع).
  // • addExpenseLog / deleteExpenseLog (للاستخدام المباشر): عمليات
  //   مستند واحد (ذرية بطبيعتها).
  // لا عمليات موافقة/رفض منفصلة — تغيير الحالة يمر عبر
  // updateExpense (ذري) فلا يحتاج معاملة مستقلة.
  //
  // ⚠️ ترحيل: سجلات قديمة كُتبت بمسار البريد الخام (قبل
  // التطبيع) لا تظهر في getExpenseLogs إن كان البريد يحتوي
  // نقاطاً أو + (Gmail) — راجعها يدوياً.
  // ════════════════════════════════════════════════════════════════

  CollectionReference _getExpensesCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('expenses')
        .collection('expenses');
  }

  @override
  Future<Either<Failure, List<ExpenseEntity>>> getExpenses(
    String organizationEmail,
  ) async {
    try {
      // ملاحظة: _getExpensesCollection تتولى التnormalize داخلياً،
      // فلا يُمرر بريد مُنظم مسبقاً إليها لتجنب المسارات الخاطئة في Firestore.
      final snapshot = await _getExpensesCollection(organizationEmail).get();

      final expenses = <ExpenseEntity>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
        if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
          mapData['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
        }
        final expense = ExpenseModel.fromJson(mapData);
        expenses.add(expense);
      }

      // ترتيب المصاريف حسب التاريخ في الذاكرة
      expenses.sort((a, b) {
        return b.date.compareTo(a.date);
      });

      return Right(expenses);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, ExpensePage>> getExpensesPaginated({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
  }) async {
    try {
      // ملاحظة: _getExpensesCollection تتولى التnormalize داخلياً،
      // فلا يُمرر بريد مُنظم مسبقاً إليها لتجنب المسارات الخاطئة في Firestore.
      var query = _getExpensesCollection(
        organizationEmail,
      ).orderBy('createdAt', descending: true);

      // إذا كان هناك مستند أخير، نبدأ بعده
      if (lastDocument != null && lastDocument is DocumentSnapshot) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      final expenses = <ExpenseEntity>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
        // (متسق مع getExpenses — يُعيّن فقط إذا لم يكن هناك معرف محفوظ)
        if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
          mapData['id'] = doc.id;
        }
        final expense = ExpenseModel.fromJson(mapData);
        expenses.add(expense);
      }

        // آخر مستند من نتيجة الاستعلام مباشرة — بلا
        // قراءة إضافية (انظر ExpensePage في الواجهة)
        return Right(ExpensePage(
          expenses: expenses,
          lastSnapshot: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        ));
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  /// الحصول على DocumentSnapshot لمصروف محدد
  Future<DocumentSnapshot?> getExpenseDocument(
    String organizationEmail,
    String expenseId,
  ) async {
    try {
      // _getExpensesCollection تتولى التnormalize داخلياً، فلا يُنظم البريد هنا مرتين
      return await _getExpensesCollection(organizationEmail).doc(expenseId).get();
    } on Exception catch (_) {

      return null;
    }
  }

  @override
  Stream<Either<Failure, List<ExpenseEntity>>> getExpensesStream(
    String organizationEmail, {
    int? limit,
    String? searchQuery,
    String? statusFilter,
    String? categoryFilter,
    String? dateFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      // 1. بناء الـ query الأساسي
      Query query = _getExpensesCollection(normalizedEmail);

      // 2. إضافة فلتر الحالة إذا كان موجوداً (قبل orderBy)
      if (statusFilter != null && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      // 3. إضافة فلتر الفئة إذا كان موجوداً (قبل orderBy)
      if (categoryFilter != null && categoryFilter != 'all') {
        query = query.where('category', isEqualTo: categoryFilter);
      }

      // 4. الترتيب
      query = query.orderBy('createdAt', descending: true);

      // 5. ✅ عدم تطبيق الحد في الـ query - نريد كل البيانات للفلترة
      // التطبيق النهائي للحد سيكون في BLoC بعد الفلترة
      // if (limit != null) {
      //   query = query.limit(limit);
      // }

      // 6. الاستماع للتغييرات
      // ✅ تحسين (2026-10-12): نفس تحسين قسم
      // الفواتير — نحفظ المصروفات المحللة في
      // ذاكرة خاصة بهذا الستريم ونحدّث
      // المستندات المتغيرة فقط عبر docChanges
      // بدلاً من إعادة تحليل كل المصروفات مع
      // كل لقطة — كان يسبب بطءاً ملحوظاً مع
      // كثرة المصروفات عند كل تحديث. الحد لا
      // يُطبَّق في الـ query (نريد كل البيانات
      // للفلترة في الذاكرة) فالذاكرة تمثل
      // نتيجة الاستعلام كاملة ويُطبَّق الحد
      // في الذاكرة بعد الفلترة.
      final streamCache = <String, ExpenseEntity>{};

      return query
           .snapshots()
           .map((snapshot) {
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
                   streamCache[doc.id] = ExpenseModel.fromJson(mapData);
                 } on Exception catch (_) {
                   streamCache.remove(doc.id);
                 }
               }

               var expenses = streamCache.values.toList()
                 ..sort((a, b) {
                   final cmp = b.createdAt.compareTo(a.createdAt);
                   return cmp != 0 ? cmp : a.id.compareTo(b.id);
                 });

               // 6. تطبيق فلتر البحث في الذاكرة
               if (searchQuery != null && searchQuery.isNotEmpty) {
                 final query = searchQuery.toLowerCase();
                 expenses = expenses.where((expense) {
                   final description =
                       expense.description.toLowerCase();
                   final category = expense.category.toLowerCase();
                   final title = expense.title.toLowerCase();
                   return description.contains(query) ||
                       category.contains(query) ||
                       title.contains(query);
                 }).toList();
               }

               // 7. تطبيق فلاتر أخرى في الذاكرة (إذا لم تكن في Firestore)
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

                 expenses = expenses
                     .where((expense) =>
                         !expense.date.isBefore(filterDate))
                     .toList();
               }

               // فلتر التاريخ المخصص
               if (startDate != null) {
                 expenses = expenses
                     .where(
                       (expense) =>
                           !expense.date.isBefore(startDate),
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
                 expenses = expenses
                     .where(
                       (expense) =>
                           !expense.date.isAfter(endOfDay),
                     )
                     .toList();
               }

               // 8. التأكد من عدم تجاوز الحد (حماية إضافية)
               if (limit != null && expenses.length > limit) {
                 expenses = expenses.sublist(0, limit);
               }

               return Right<Failure, List<ExpenseEntity>>(expenses);
             } on Exception catch (e) {
               return Left<Failure, List<ExpenseEntity>>(
                 ServerFailure(message: _readableError(e)),
               );
             }
           })
           .handleError((error) {
             return Left<Failure, List<ExpenseEntity>>(
               ServerFailure(message: _readableError(error)),
             );
           });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Stream<Either<Failure, ExpenseStatsEntity>> getExpenseStatsStream(
    String organizationEmail, {
    int? limit,
  }) {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final collection = _getExpensesCollection(normalizedEmail);

      // ⚠️ ملاحظة للمبرمجين المستلمين — مشكلة أداء: collection.snapshots() يُعيد
      // إرسال كل مستندات المجموعة عند أي تغيير، ودالة الـ map تعيد تحليل وتصفية
      // كل المصاريف في الذاكرة عند كل لقطة. للمجموعات الكبيرة هذا يسبب بطءاً.
      // يُفضل استخدام استعلام أكثر تحديداً أو تحديث تدريجي للمستند المتغير فقط.
      // (ملاحظة توثيقية فقط، لا تعديل للمنطق)
      return collection
          .snapshots()
          .map((snapshot) {
            try {
              // ✅ تحسين (2026-10-12): حساب
              // الإحصائيات مباشرة من بيانات
              // المستند الخام بدلاً من بناء
              // ExpenseModel كامل لكل مصروف —
              // الإحصائيات تحتاج 3 حقول فقط
              // (status، amount، paidAmount) فبناء
              // النموذج كامل كان يهدر وقت
              // المعالج مع كثرة المصروفات عند
              // كل لقطة. منطق الحساب مطابق
              // تماماً للسابق (remainingAmount =
              // amount - paidAmount — انظر
              // ExpenseEntity.remainingAmount).
              var totalExpenses = 0;
              var pendingExpenses = 0;
              var approvedExpenses = 0;
              var rejectedExpenses = 0;
              double totalAmount = 0;
              double pendingAmount = 0;
              double approvedAmount = 0;
              double paidAmount = 0;
              double remainingAmount = 0;

              for (final doc in snapshot.docs) {
                final data = doc.data();
                if (data == null) continue;
                final mapData = data as Map<String, dynamic>;

                final status = mapData['status']?.toString() ?? 'draft';
                final amount = _parseStatsDouble(mapData['amount']);
                final paid =
                    _parseStatsDouble(mapData['paidAmount']);

                totalExpenses++;
                totalAmount += amount;
                paidAmount += paid;
                remainingAmount += amount - paid;

                switch (status) {
                  case 'pending':
                    pendingExpenses++;
                    pendingAmount += amount;
                    break;
                  case 'approved':
                    approvedExpenses++;
                    approvedAmount += amount;
                    break;
                  case 'rejected':
                    rejectedExpenses++;
                    break;
                  case 'draft':
                    // حالة 'draft' تُعامل كمعلقة للإحصائيات، لكن يجب التاكد من
                    // توافقها مع ExpenseEntity الذي لا يعرف حالة 'draft' (راجع expense_entity.dart).
                    pendingExpenses++;
                    pendingAmount += amount;
                    break;
                  default:
                    // ⚠️ ملاحظة للمبرمجين المستقبليين: الحالات غير المعروفة (غير pending/approved/rejected/draft)
                    // تُحسب ضمن 'pending' للحفاظ على تكامل الإحصائيات:
                    // total = pending + approved + rejected.
                    // هذا يتعارض قليلاً مع ExpenseEntity الذي لا يعرف حالة 'draft'
                    // (راجع expense_entity.dart السطور 42-44). إذا أُضيفت حالة جديدة
                    // مستقبلاً يجب تحديث المنطق هنا وفي getExpenseStats و computeExpenseStats.
                    pendingExpenses++;
                    pendingAmount += amount;
                    break;
                }
              }

              return Right<Failure, ExpenseStatsEntity>(
                ExpenseStatsEntity(
                  totalExpenses: totalExpenses,
                  pendingExpenses: pendingExpenses,
                  approvedExpenses: approvedExpenses,
                  rejectedExpenses: rejectedExpenses,
                  totalAmount: totalAmount,
                  pendingAmount: pendingAmount,
                  approvedAmount: approvedAmount,
                  paidAmount: paidAmount,
                  remainingAmount: remainingAmount,
                ),
              );
            } on Exception catch (e) {
              return Left<Failure, ExpenseStatsEntity>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, ExpenseStatsEntity>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Future<Either<Failure, void>> addExpense(ExpenseEntity expense) async {
    try {
      final model = ExpenseModel.fromEntity(expense);

      // إنشاء ID قصير وقابل للقراءة إذا كان فارغاً
      final normalizedEmail = _emailService.normalize(
        expense.organizationEmail,
      );
      final collection = _getExpensesCollection(normalizedEmail);
      final expenseDoc = expense.id.isEmpty
          ? collection.doc()
          : collection.doc(expense.id);
      final expenseId = expenseDoc.id;

      final data = model.toJson();
      data['id'] = expenseId;

      // المستخدم الفعلي المنفذ (القاعدة 6)
      final effectiveUser = await _getEffectiveUser();

      await firestore.runTransaction((transaction) async {
        if (expense.id.isNotEmpty) {
          final docSnapshot = await transaction.get(expenseDoc);

          if (docSnapshot.exists) {
            throw Exception('المصروف موجود مسبقاً');
          }
        }

        transaction.set(expenseDoc, data);

        // ✅ ذري: خصم الصندوق داخل نفس المعاملة (القاعدة 1 أعلى الملف).
        if (expense.paidAmount > 0) {
          final cashboxRef = firestore
              .collection(normalizedEmail)
              .doc('cashbox')
              .collection('balance')
              .doc('main');

          transaction.set(cashboxRef, {
            'currentBalance': FieldValue.increment(-expense.paidAmount),
            'lastUpdated': FieldValue.serverTimestamp(),
            // المستخدم الفعلي (القاعدة 6)
            'updatedBy': effectiveUser?['id'],
          }, SetOptions(merge: true));
        }

        // سجل النشاط ذري مع العملية بلا شرط (القاعدتان 5 و6)
        _createExpenseLogInTransaction(
          transaction,
          normalizedEmail,
          _buildExpenseLogData(
            actionType: 'add_expense',
            details: 'تم إضافة مصروف جديد: ${expense.title}',
            targetId: expenseId,
            effectiveUser: effectiveUser,
            newValues: {
              'title': expense.title,
              'description': expense.description,
              'amount': expense.amount,
              'paidAmount': expense.paidAmount,
              'remainingAmount': expense.remainingAmount,
              'category': expense.category,
              'status': expense.status,
              'date': expense.date.toIso8601String(),
              'paymentMethod': expense.paymentMethod,
              'receiptUrl': expense.receiptUrl,
            },
          ),
        );
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> updateExpense(ExpenseEntity expense) async {
    try {
      final model = ExpenseModel.fromEntity(expense);
      final normalizedEmail = _emailService.normalize(
        expense.organizationEmail,
      );

      // المستخدم الفعلي المنفذ (القاعدة 6)
      final effectiveUser = await _getEffectiveUser();

      // runTransaction واحد (all-or-nothing — انظر القاعدة 1 أعلى الملف)
      await firestore.runTransaction((transaction) async {
        final expenseDoc = _getExpensesCollection(
          normalizedEmail,
        ).doc(expense.id);

        // التحقق من وجود المصروف قبل التحديث
        final docSnapshot = await transaction.get(expenseDoc);

        if (!docSnapshot.exists) {
          throw Exception('المصروف غير موجود');
        }

        // قراءة المبلغ المدفوع القديم لحساب فرق الخصم/الإرجاع
        // للصندوق ذرياً مع التحديث (كل القراءات قبل كل الكتابات)
        final oldData = docSnapshot.data() as Map<String, dynamic>?;
        final oldPaidAmount =
            (oldData?['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final paidDelta = expense.paidAmount - oldPaidAmount;

        // تحديث البيانات في نفس الـ transaction باستخدام toUpdateJson()
        // الذي يستبعد الحقول غير القابلة للتغيير (id، createdAt، createdBy).
        transaction.update(expenseDoc, model.toUpdateJson());

        // ✅ ذري: تعديل الصندوق بالفرق (الجديد − القديم) في نفس المعاملة
        if (paidDelta != 0) {
          final cashboxRef = firestore
              .collection(normalizedEmail)
              .doc('cashbox')
              .collection('balance')
              .doc('main');

          transaction.set(cashboxRef, {
            'currentBalance': FieldValue.increment(-paidDelta),
            'lastUpdated': FieldValue.serverTimestamp(),
            // المستخدم الفعلي (القاعدة 6)
            'updatedBy': effectiveUser?['id'],
          }, SetOptions(merge: true));
        }

        // سجل النشاط ذري مع العملية بلا شرط (القاعدتان 5 و6)
        _createExpenseLogInTransaction(
          transaction,
          normalizedEmail,
          _buildExpenseLogData(
            actionType: 'update_expense',
            details: 'تم تحديث المصروف: ${expense.title}',
            targetId: expense.id,
            effectiveUser: effectiveUser,
            newValues: {
              'title': expense.title,
              'description': expense.description,
              'amount': expense.amount,
              'paidAmount': expense.paidAmount,
              'remainingAmount': expense.remainingAmount,
              'category': expense.category,
              'status': expense.status,
              'date': expense.date.toIso8601String(),
              'paymentMethod': expense.paymentMethod,
              'receiptUrl': expense.receiptUrl,
            },
          ),
        );
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExpense(
    String id,
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // المستخدم الفعلي المنفذ (القاعدة 6)
      final effectiveUser = await _getEffectiveUser();

      // ✅ ذري: إرجاع المبلغ المدفوع للصندوق + الحذف في runTransaction واحد
      await firestore.runTransaction((transaction) async {
        final expenseDoc = _getExpensesCollection(normalizedEmail).doc(id);

        // قراءة المصروف قبل الحذف لمعرفة المبلغ المدفوع
        // (كل القراءات قبل كل الكتابات)
        final docSnapshot = await transaction.get(expenseDoc);

        if (!docSnapshot.exists) {
          throw Exception('المصروف غير موجود');
        }

        final oldData = docSnapshot.data() as Map<String, dynamic>?;
        final paidAmount =
            (oldData?['paidAmount'] as num?)?.toDouble() ?? 0.0;

        // إرجاع المبلغ المدفوع إلى الصندوق ذرياً مع الحذف
        if (paidAmount > 0) {
          final cashboxRef = firestore
              .collection(normalizedEmail)
              .doc('cashbox')
              .collection('balance')
              .doc('main');

          transaction.set(cashboxRef, {
            'currentBalance': FieldValue.increment(paidAmount),
            'lastUpdated': FieldValue.serverTimestamp(),
            // المستخدم الفعلي (القاعدة 6)
            'updatedBy': effectiveUser?['id'],
          }, SetOptions(merge: true));
        }

        transaction.delete(expenseDoc);

        // سجل النشاط ذري مع العملية بلا شرط (القاعدتان 5 و6)
        _createExpenseLogInTransaction(
          transaction,
          normalizedEmail,
          _buildExpenseLogData(
            actionType: 'delete_expense',
            details: 'تم حذف المصروف',
            targetId: id,
            effectiveUser: effectiveUser,
            // oldValues: بيانات المصروف المحذوف (نمط
            // الفواتير) — بعد الحذف لا يبقى أثر للمستند
            // فالسجل هو المرجع الوحيد للتدقيق.
            oldValues: {
              'title': oldData?['title'],
              'description': oldData?['description'],
              'amount': oldData?['amount'],
              'paidAmount': oldData?['paidAmount'],
              'remainingAmount':
                  ((oldData?['amount'] as num?)?.toDouble() ?? 0.0) -
                  ((oldData?['paidAmount'] as num?)?.toDouble() ?? 0.0),
              'category': oldData?['category'],
              'status': oldData?['status'],
              'date': (oldData?['date'] as Timestamp?)
                  ?.toDate()
                  .toIso8601String(),
              'paymentMethod': oldData?['paymentMethod'],
            },
          ),
        );
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, ExpenseStatsEntity>> getExpenseStats(
    String organizationEmail,
  ) async {
    try {
      final normalizedEmail = _emailService.normalize(organizationEmail);
      final snapshot = await firestore
          .collection(normalizedEmail)
          .doc('expenses')
          .collection('expenses')
          .get();

      final expenses = snapshot.docs
          .map((doc) => ExpenseModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      final totalExpenses = expenses.length;
      final pendingExpenses = expenses
          .where((e) => e.status == 'pending' || e.status == 'draft')
          .length;
      final approvedExpenses = expenses
          .where((e) => e.status == 'approved')
          .length;
      final rejectedExpenses = expenses
          .where((e) => e.status == 'rejected')
          .length;

      final totalAmount = expenses.fold<double>(
        0,
        (total, e) => total + e.amount,
      );
      final pendingAmount = expenses
          .where((e) => e.status == 'pending' || e.status == 'draft')
          .fold<double>(0, (total, e) => total + e.amount);
      final approvedAmount = expenses
          .where((e) => e.status == 'approved')
          .fold<double>(0, (total, e) => total + e.amount);

      // ℹ️ ملاحظة للمبرمجين المستقبليين — لماذا يُحسب المدفوع/المتبقي
      // من paidAmount الفعلية وليس من المبلغ المعتمد؟ لأن المعتمد
      // لا يعني الدفع (مصروف معتمد قد يُدفع جزئياً أو لم يُدفع بعد)،
      // وتعريف الكيان: remainingAmount = amount - paidAmount.
      // يجب أن تتطابق هذه الحسابات مع getExpenseStatsStream.
      final paidAmount = expenses.fold<double>(
        0,
        (total, e) => total + e.paidAmount,
      );
      final remainingAmount = expenses.fold<double>(
        0,
        (total, e) => total + e.remainingAmount,
      );

      final stats = ExpenseStatsEntity(
        totalExpenses: totalExpenses,
        pendingExpenses: pendingExpenses,
        approvedExpenses: approvedExpenses,
        rejectedExpenses: rejectedExpenses,
        totalAmount: totalAmount,
        pendingAmount: pendingAmount,
        approvedAmount: approvedAmount,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
      );

      return Right(stats);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  ExpenseStatsEntity computeExpenseStats(List<ExpenseEntity> expenses) {
    // حساب محلي مباشر من القائمة المُحمّلة — نفس حسابات
    // getExpenseStats تماماً (عدادات الحالات + المبالغ)
    // ولكن بدون قراءة من Firestore (O(n) محلياً فقط).
    final totalExpenses = expenses.length;
    final pendingExpenses = expenses
        .where((e) => e.status == 'pending' || e.status == 'draft')
        .length;
    final approvedExpenses = expenses
        .where((e) => e.status == 'approved')
        .length;
    final rejectedExpenses = expenses
        .where((e) => e.status == 'rejected')
        .length;

    final totalAmount = expenses.fold<double>(
      0,
      (total, e) => total + e.amount,
    );
    final pendingAmount = expenses
        .where((e) => e.status == 'pending' || e.status == 'draft')
        .fold<double>(0, (total, e) => total + e.amount);
    final approvedAmount = expenses
        .where((e) => e.status == 'approved')
        .fold<double>(0, (total, e) => total + e.amount);

    final paidAmount = expenses.fold<double>(
      0,
      (total, e) => total + e.paidAmount,
    );
    final remainingAmount = expenses.fold<double>(
      0,
      (total, e) => total + e.remainingAmount,
    );

    return ExpenseStatsEntity(
      totalExpenses: totalExpenses,
      pendingExpenses: pendingExpenses,
      approvedExpenses: approvedExpenses,
      rejectedExpenses: rejectedExpenses,
      totalAmount: totalAmount,
      pendingAmount: pendingAmount,
      approvedAmount: approvedAmount,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
    );
  }

  // ===== Expense Logs Methods =====

  String? _getCurrentOrganizationId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;
    // تطبيع البريد ليتطابق مسار سجل النشاط مع مسار مستندات المصاريف
    return _emailService.normalize(user!.email!);
  }

  /// المستخدم الفعلي المنفذ: المُبدّل إليه إن وُجد، وإلا المستخدم الحالي
  /// — ليتطابق مع createdBy/updatedBy التي تعيّنها الصفحات (القاعدة 6).
  Future<Map<String, dynamic>?> _getEffectiveUser() async {
    try {
      final switched = await SessionService.getSwitchedUser();
      if (switched != null && switched['id'] != null) {
        return switched;
      }
    } on Exception catch (_) {
      // تجاهل خطأ قراءة الجلسة والرجوع للمستخدم الحالي
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;
    return {
      'id': currentUser.uid,
      'name': currentUser.displayName,
      'email': currentUser.email,
    };
  }

  /// بناء بيانات سجل نشاط المصروف — نفس حقول addExpenseLog لضمان
  /// تطابق السجلات مع ما كان يُكتب من BLoC، وبيانات المستخدم من
  /// المستخدم الفعلي ليتطابق مع updatedBy في الصندوق (القاعدة 6).
  Map<String, dynamic> _buildExpenseLogData({
    required String actionType,
    required String details,
    required String targetId,
    Map<String, dynamic>? effectiveUser,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) {
    return {
      'userId': effectiveUser?['id'],
      'userName': effectiveUser?['name'],
      'userEmail': effectiveUser?['email'],
      'actionType': actionType,
      'timestamp': FieldValue.serverTimestamp(),
      'details': details,
      'isSuccess': true,
      'ipAddress': null,
      'userAgent': null,
      'targetId': targetId,
      'targetType': 'expense',
      'oldValues': oldValues,
      'newValues': newValues,
      'sessionId': null,
      'deviceInfo': null,
    };
  }

  /// إنشاء سجل نشاط المصروف داخل نفس الـ transaction — all-or-nothing
  /// مع العملية المالية (نمط الفواتير، القاعدة 5).
  void _createExpenseLogInTransaction(
    Transaction transaction,
    String organizationId,
    Map<String, dynamic> logData,
  ) {
    final logDocRef = firestore
        .collection(organizationId)
        .doc('expenses')
        .collection('logs')
        .doc();
    transaction.set(logDocRef, logData);
  }

  @override
  Future<Either<Failure, List<ExpenseLogEntity>>> getExpenseLogs({
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
          .doc('expenses')
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
      final logs = <ExpenseLogEntity>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        final log = ExpenseLogModel.fromJson({
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

      return Right(logs);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Stream<Either<Failure, List<ExpenseLogEntity>>> getExpenseLogsStream({
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
        return Stream.value(const Left(
          ServerFailure(message: 'المستخدم غير مسجل دخول'),
        ));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('expenses')
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

      // ✅ أداء (2026-10-12): كاش تدريجي
      // خاص بهذا الستريم فقط يعالج docChanges
      // بدلاً من إعادة تحليل كل السجلات مع
      // كل لقطة — سجلات العمليات تنمو بلا
      // حدود فكان إعادة بناء كل
      // ExpenseLogEntity عند كل عملية جديدة
      // هو الهدر الأكبر هنا. الستريم المحدود
      // (بحد) يبقي التحليل الكامل الأصلي لأن
      // نافذة الحد تتحرك وقد لا يُصدر
      // المستند الخارج تغييراً من نوع
      // removed بشكل موثوق.
      final streamCache = <String, ExpenseLogEntity>{};

      return query
          .snapshots()
          .map((snapshot) {
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
                  streamCache[doc.id] = ExpenseLogModel.fromJson({
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
              var logs = <ExpenseLogEntity>[];
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

              return Right<Failure, List<ExpenseLogEntity>>(logs);
            }

            // الستريم المحدود: تحليل كامل (السلوك الأصلي)
            final logs = <ExpenseLogEntity>[];

            for (final doc in snapshot.docs) {
              final data = doc.data();
              if (data == null) continue;
              final mapData = data as Map<String, dynamic>;
              final log = ExpenseLogModel.fromJson({
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

            return Right<Failure, List<ExpenseLogEntity>>(logs);
          })
          .handleError((error) {
            return Left<Failure, List<ExpenseLogEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
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
          .doc('expenses')
          .collection('logs')
          .add(logData);

      final snapshot = await docRef.get();
      final log = ExpenseLogModel.fromJson({
        'id': docRef.id,
        ...snapshot.data()!,
      }).toEntity();

      return Right(log);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExpenseLog(String logId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      await firestore
          .collection(organizationId)
          .doc('expenses')
          .collection('logs')
          .doc(logId)
          .delete();

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> clearExpenseLogs({
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
          .doc('expenses')
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
      final docs = snapshot.docs;

      // ✅ ذري: كل batch يُنفَّذ كله أو لا شيء، على دفعات 500 عملية
      // (حد Firestore — الذرية لكل batch وحده، انظر كتلة التحقق).
      const maxBatchOps = 500;
      for (var start = 0; start < docs.length; start += maxBatchOps) {
        final end = start + maxBatchOps;
        final chunk = docs.sublist(start, end > docs.length ? docs.length : end);
        final batch = firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        // ⚠️ ملاحظة للمبرمجين المستقبليين: كل batch ذري بمفرده (كله أو لا شيء)،
        // لكن الذرية لا تمتد عبر الدفعات. إذا انقطع التنفيذ منتصف الطريق تبقى
        // الدفعات السابقة محذوفة والباقية كما هي. هذا unavoidable بسبب حد Firestore
        // البالغ 500 عملية في batch الواحد — لا توجد معاملة أوسع من ذلك.
      }
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
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
