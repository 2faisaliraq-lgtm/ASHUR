import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/permissions/permissions_manager.dart';
import '../../domain/entities/permission_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../../domain/entities/roles_page.dart';
import '../../domain/entities/user_log_entity.dart';
import '../../domain/entities/user_management_entity.dart';
import '../../domain/entities/users_page.dart';
import '../../domain/repositories/users_repository.dart';
import '../models/role_model.dart';
import '../models/user_log_model.dart';
import '../models/user_management_model.dart';

typedef UsersEither = Either<Failure, dynamic>;

/// تنفيذ مستودع المستخدمين
/// ╔══════════════════════════════════════════════════════════════╗
/// ║ ⚠️  ملاحظة هامة جداً للمبرمجين المستقبليين               ║
/// ║ هذه العمليات تعمل على بيانات المستخدمين (حساسة جداً). أي   ║
/// ║ تعديل غير صحيح قد يؤدي إلى دخول غير مصرح له أو تعطيل      ║
/// ║ حسابات المدراء أو فقدان سجلات النشاط أو تعارض في الصلاحيات.║
/// ║                                                            ║
/// ║ 🔒 نتيجة التحقق اليدوي من الذرية (2026-10-12):           ║
/// ║ ✅ جميع العمليات صحيحة - كل Transaction تقرأ كل بياناتها  ║
/// ║   قبل أي كتابة (القاعدة الحاسمة أدناه)، وكل عملية        ║
/// ║   متعددة المستندات ضمن حد Firestore (500 عملية) عبر       ║
/// ║   _maxBatchWrites = 450 لهامش الأمان، وسجل النشاط مدمج   ║
/// ║   في نفس المعاملة (يُسجل مع النجاح فقط). القيود الموثقة  ║
/// ║   أدناه (Auth و queries خارج المعاملة) قيود منصات لا       ║
/// ║   تُعدَّل هنا، والحل الأمثل: Cloud Function.             ║
/// ║ ⚠️ أي تعديل مستقبلي على هذه العمليات يجب أن يعيد هذا     ║
/// ║   التحقق قبل الاعتماد لتجنب كسر الذرية                   ║
/// ╚══════════════════════════════════════════════════════════════╝
///
/// ⚠️  ما يجب أن يكون ذرياً (All-or-Nothing) ولماذا - ملخص موحد:
/// كل عملية تعدّل أكثر من مستند يجب أن تكون في Transaction واحدة
/// (أو Batch واحد) لمنع: التحديث المفقود (مستخدمان يعدّلان نفس
/// المستخدم في وقت واحد)، تضارب البريد (مستخدمان بنفس البريد)،
/// البيانات الأيتمة (سجل نشاط دون مستخدم أو العكس)، وتكرار البريد.
///
/// ✅ ذري (Transaction واحدة):
///    - createUser: فحص فريدية البريد + قراءة الأدوار + إنشاء
///      المستند + قيد البريد + سجل النشاط. ⚠️ يُنشأ Firebase
///      Auth أولاً (خارج المعاملة) ثم المعاملة على مرحلتين
///      (المرحلة 1 كل القراءات، المرحلة 2 كل الكتابات)، ويُحذف
///      حساب Auth إذا فشلت المعاملة، ويُحدَّث اسم العرض بعد
///      نجاحها (أفضل جهد). ⚠️ هناك فترة قصيرة بين إنشاء Auth
///      والمعاملة - الحل الأمثل: Cloud Function.
///    - updateUser: فحص تعارض البريد + تحديث المستخدم + قيود
///      البريد + سجل النشاط. ⚠️ يشمل Firestore فقط ولا يُزامن
///      Firebase Auth (بريد/اسم تسجيل الدخول يبقيان كما هما -
///      مستودعات منفصلة).
///    - deleteUser: فحص الوجود + حذف المستخدم + قيد البريد +
///      سجلات النشاط + سجل الحذف. ⚠️ لا يحذف المستخدم من
///      Firebase Auth (الحل الموصى به: Cloud Function). ⚠️ سجلات
///      النشاط تُقرأ بـ query.get() (ليست transaction.get) لأن
///      Firestore لا تسمح بـ queries داخل transactions، وأول
///      450 سجل تُحذف داخل المعاملة والباقي في دفعات ذرية
///      منفصلة بعد نجاحها.
///    - toggleUserStatus: فحص الوجود + تحديث الحالة + سجل النشاط.
///    - updateUserNotificationSettings: فحص الوجود + التحديث +
///      إرجاع البيانات.
///    - createRole: فحص عدم الوجود + الإنشاء.
///    - updateRole: فحص الوجود + التحديث.
///    - deleteUserLog: فحص الوجود + الحذف.
///
/// ✅ ذري مع limitation (دفعات Batch - كل دفعة ذرية بمفردها):
///    - deleteRole: حذف المستخدمين الذين لديهم هذا الدور فقط +
///      قيود بريدهم + سجلات نشاطهم + الدور. ⚠️ البحث عن
///      المستخدمين وسجلاتهم يحدث خارج الدفعات (Firestore لا
///      تسمح بـ queries فيها)، فيُعاد التحقق
///      (roleIds.length == 1) لمنع حذف مستخدم لديه أدوار
///      إضافية، وقد لا يُحذف مستخدم حصل على الدور بعد البحث.
///      الحل الأمثل: Cloud Function.
///    - clearUserLogs: حذف جميع السجلات المطابقة (Query +
///      دفعات، والدفعات ليست ذرية مع بعضها).
///
/// ✅ ذري طبيعياً (كتابة واحدة): saveUsersSettings (set مع
///    merge: true)، addUserLog (add).
///
/// 📝 تسجيل النشاط: مدمج داخل Transaction للعمليات الناجحة
///    (يُسجل مع النجاح فقط). عند فشل العملية الأساسية يُسجل
///    منفصلاً كـ "فشل" عبر addUserLog (الفشل ليس جزءاً من
///    العملية الأساسية). ⚠️ userId في السجل = الفاعل (من قام
///    بالعملية) دائماً وفق توثيق UserLogEntity ولاتساق مع
///    _logUserActivity وtoggleUserStatus، والمستهدف يُسجل في
///    targetId وdetails وoldValues/newValues.
///
/// ⚠️  حد Firestore: 500 عملية كتابة لكل Transaction أو Batch.
///    العمليات التي قد تتجاوزه (deleteUser بكثرة سجلات،
///    deleteRole/clearUserLogs بكثرة مستندات) تُقسم عبر
///    _deleteRefsInBatches: كل دفعة ذرية بمفردها، لكن الدفعات
///    ليست ذرية مع بعضها (أفضل ما يمكن مع قيود Firestore).
///
/// ╔══════════════════════════════════════════════════════════════╗
/// ║ ⚠️  القاعدة الذهبية (للمبرمجين المستقبليين):                ║
/// ║ 1. استخدم transaction.get() لقراءة المستندات داخل المعاملة ║
/// ║ 2. استخدم transaction.set()/update()/delete() للكتابة      ║
/// ║ 3. لا تستخدم firestore.get() خارج المعاملة لقراءة بيانات   ║
/// ║    ستُستخدم داخل المعاملة                                   ║
/// ║ 4. استخدم FieldValue.increment() للعمليات الحسابية         ║
/// ║ 5. لا تقسم المعاملة إلى عمليات منفصلة!                      ║
/// ║ 6. ⚠️ قاعدة ذرية حاسمة: كل transaction.get() قبل كل        ║
/// ║    transaction.set()/update()/delete() في نفس runTransaction ║
/// ║    وإلا يسبب '_commands.isEmpty': Transactions require all   ║
/// ║    reads to be executed before all writes (لا تضع أي قراءة   ║
/// ║    بعد بدء الكتابة).                                        ║
/// ╚══════════════════════════════════════════════════════════════╝
class UsersRepositoryImpl implements UsersRepository {
  UsersRepositoryImpl({required this.firestore, required this.auth});
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final _emailService = EmailNormalizationService();

  // ✅ كاش خريطة الأدوار في الذاكرة: يمنع إعادة جلب الأدوار
  // في كل حدث من أحداث ستريم المستخدمين (getUsersStream)
  // وفي كل استدعاء (getUsers/getUsersPaginated). الأدوار
  // نادراً ما تتغير، لذا تُجلب مرة واحدة وتُخزن هنا
  // وتُبطل (تُصفَّر) عند أي تعديل عليها (createRole/
  // updateRole/deleteRole) لضمان حداثتها.
  Map<String, Map<String, dynamic>>? _rolesMapCache;
  String? _rolesMapCacheOrgId;

  String _getOrganizationId(String email) => _emailService.normalize(email);

  String? _getCurrentOrganizationId() {
    final user = auth.currentUser;
    if (user?.email == null) return null;
    return _getOrganizationId(user!.email!);
  }

  /// الحد الأقصى لعمليات الكتابة في Transaction أو Batch واحد
  /// ⚠️ لماذا 450: هامش أمان تحت حد Firestore (500 عملية -
  /// انظر الملاحظة الشاملة أعلى الملف) لتغطية العمليات
  /// الثابتة (المستخدم + قيد البريد + سجل الحذف = 3).
  /// عند تجاوز الحد تُقسم الحذف إلى دفعات: كل دفعة ذرية
  /// بمفردها، لكن الدفعات ليست ذرية مع بعضها.
  static const _maxBatchWrites = 450;

  /// حذف مراجع مستندات في دفعات ذرية منفصلة (انظر _maxBatchWrites)
  Future<void> _deleteRefsInBatches(List<DocumentReference> refs) async {
    for (var i = 0; i < refs.length; i += _maxBatchWrites) {
      final end = (i + _maxBatchWrites) < refs.length
          ? (i + _maxBatchWrites)
          : refs.length;
      final batch = firestore.batch();
      for (var j = i; j < end; j++) {
        batch.delete(refs[j]);
      }
      await batch.commit();
    }
  }

  /// جلب خريطة الأدوار المعرفة للمؤسسة
  Future<Map<String, Map<String, dynamic>>> _fetchRolesMap(
    String organizationId,
  ) async {
    // ✅ أداء: إرجاع الكاش إن وُجد لنفس المؤسسة (يُبطل
    // عند تعديل الأدوار أدناه) لتجنب إعادة الجلب في
    // كل حدث من أحداث الستريم وفي كل استدعاء.
    if (_rolesMapCache != null && _rolesMapCacheOrgId == organizationId) {
      return _rolesMapCache!;
    }

    final rolesSnapshot = await firestore
        .collection(organizationId)
        .doc('users')
        .collection('roles')
        .get();

    final rolesMap = <String, Map<String, dynamic>>{};
    for (final roleDoc in rolesSnapshot.docs) {
      rolesMap[roleDoc.id] = {'id': roleDoc.id, ...roleDoc.data()};
    }

    _rolesMapCache = rolesMap;
    _rolesMapCacheOrgId = organizationId;
    return rolesMap;
  }

  /// تحويل مستندات المستخدمين إلى كيانات مع ربط الأدوار
  List<UserManagementEntity> _mapUserDocsToEntities(
    List<QueryDocumentSnapshot> docs,
    Map<String, Map<String, dynamic>> rolesMap,
  ) {
    final users = <UserManagementEntity>[];
    for (final doc in docs) {
      final data = doc.data();
      if (data == null) continue;
      final mapData = data as Map<String, dynamic>;
      final roleIds = List<String>.from(mapData['roleIds'] ?? []);
      final userRoles = <Map<String, dynamic>>[];

      for (final roleId in roleIds) {
        if (rolesMap.containsKey(roleId)) {
          userRoles.add(rolesMap[roleId]!);
        }
      }

      users.add(
        UserManagementModel.fromJson({
          'id': doc.id,
          ...mapData,
          'roles': userRoles,
        }).toEntity(),
      );
    }
    return users;
  }

  /// تحليل مستند مستخدم واحد وربط أدواره من خريطة
  /// الأدوار — نفس منطق _mapUserDocsToEntities لمستند
  /// واحد (يُستخدم في البناء الكامل والتحديث التدريجي
  /// لكاش ستريم المستخدمين). يُرجع null عند بيانات
  /// فارغة أو فشل التحليل فيُستبعد المستخدم من النتيجة
  /// (أكثر متانة من إسقاط الستريم كاملاً لمستند واحد).
  /// ⚠️ المعامل DocumentSnapshot لا QueryDocumentSnapshot
  /// لأن change.doc في cloud_firestore 6.x يعيد
  /// DocumentSnapshot (انظر DocumentChange.doc).
  UserManagementEntity? _parseUserDocWithRoles(
    DocumentSnapshot doc,
    Map<String, Map<String, dynamic>> rolesMap,
  ) {
    final data = doc.data();
    if (data == null) return null;
    final mapData = data as Map<String, dynamic>;
    final roleIds = List<String>.from(mapData['roleIds'] ?? []);
    final userRoles = <Map<String, dynamic>>[];

    for (final roleId in roleIds) {
      if (rolesMap.containsKey(roleId)) {
        userRoles.add(rolesMap[roleId]!);
      }
    }

    try {
      return UserManagementModel.fromJson({
        'id': doc.id,
        ...mapData,
        'roles': userRoles,
      }).toEntity();
    } on Exception {
      return null;
    }
  }

  /// تصفية المستخدمين محلياً حسب استعلام البحث
  List<UserManagementEntity> _filterUsersByQuery(
    List<UserManagementEntity> users,
    String? searchQuery,
  ) {
    if (searchQuery == null || searchQuery.isEmpty) return users;
    final searchLower = searchQuery.toLowerCase();
    return users.where((user) {
      return (user.name?.toLowerCase().contains(searchLower) ?? false) ||
          (user.email?.toLowerCase().contains(searchLower) ?? false) ||
          (user.phoneNumber?.toLowerCase().contains(searchLower) ?? false);
    }).toList();
  }

  @override
  Future<Either<Failure, List<UserManagementEntity>>> getUsers({
    required String organizationEmail,
    int? limit,
    String? searchQuery,
    List<String>? roleFilters,
    bool? isActiveFilter,
  }) async {
    try {
      // ✅ استخدام معامل organizationEmail بدلاً من تجاهله؛ إذا كان فارغاً نعود لبريد المستخدم الحالي
      final organizationId = organizationEmail.isNotEmpty
          ? _getOrganizationId(organizationEmail)
          : _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('users')
          .collection('users');

      // إضافة فلتر isActive إذا كان موجوداً (قبل orderBy)
      if (isActiveFilter != null) {
        query = query.where('isActive', isEqualTo: isActiveFilter);
      }

      // إضافة فلتر الأدوار
      if (roleFilters != null && roleFilters.isNotEmpty) {
        query = query.where('roleIds', arrayContainsAny: roleFilters);
      }

      // ⚠️ ملاحظة: النطاق على الحقل name يتطلب أن يكون orderBy الأول على نفس الحقل (name).
      // بما أن الترتيب المطلوب هو createdAt descending، يُجرى البحث النصي محلياً عبر
      // _filterUsersByQuery بعد جلب النتائج، لتجنب خطأ Firestore في الاستعلام المركب.
      if (searchQuery != null && searchQuery.isNotEmpty) {
        // لا يُضاف where على name هنا؛ التصفية النصية تتم محلياً أدناه
      }

      // إضافة الترتيب حسب createdAt
      query = query.orderBy('createdAt', descending: true);

      // تطبيق الحد
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final rolesMap = await _fetchRolesMap(organizationId);
      final users = _mapUserDocsToEntities(snapshot.docs, rolesMap);
      final filteredUsers = _filterUsersByQuery(users, searchQuery);

      return Right(filteredUsers);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, UsersPage>> getUsersPaginated({
    required String organizationEmail,
    required int limit,
    dynamic lastDocument,
  }) async {
    try {
      // ✅ استخدام معامل organizationEmail بدلاً من تجاهله؛ إذا كان فارغاً نعود لبريد المستخدم الحالي
      final organizationId = organizationEmail.isNotEmpty
          ? _getOrganizationId(organizationEmail)
          : _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      Query query = firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .orderBy('createdAt', descending: true);

      // إذا كان هناك مستند أخير، نبدأ بعده
      if (lastDocument != null && lastDocument is DocumentSnapshot) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      final rolesMap = await _fetchRolesMap(organizationId);
      final users = _mapUserDocsToEntities(snapshot.docs, rolesMap);

      // ✅ تحسين (2026-10-12): نعيد مؤشر الصفحة
      // الأخيرة من نتيجة الاستعلام نفسها
      // (snapshot.docs.last) بدلاً من جلب المستند
      // مجدداً عبر getUserDocument — كان يضيف
      // جولة شبكة زائدة بعد كل تحميل صفحة
      // (نفس تحسين قسم الفواتير).
      return Right(
        UsersPage(
          users: users,
          lastDocument:
              snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        ),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  /// الحصول على DocumentSnapshot لمستخدم محدد
  Future<DocumentSnapshot?> getUserDocument(
    String organizationEmail,
    String userId,
  ) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) return null;

      return await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .doc(userId)
          .get();
    } on Exception catch (_) {
      // ⚠️ لا تُبتلع الاستثناءات بصمت — سجل الخطأ على الأقل للتصحيح
      // في بيئة الإنتاج، يُفضل استخدام خدمة تسجيل الأخطاء هنا
      return null;
    }
  }

  @override
  Future<Either<Failure, UserManagementEntity>> getUserById(
    String userId,
  ) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      final doc = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) throw Exception('المستخدم غير موجود');

      final data = doc.data();
      if (data == null) return Left(ServerFailure(message: 'المستند فارغ'));
      final roleIds = List<String>.from(data['roleIds'] ?? []);
      final roles = <RoleModel>[];

      // ✅ تحسين الأداء: جلب جميع الأدوار في استعلام واحد باستخدام whereIn
      // بدلاً من N+1 استعلام (استعلام منفصل لكل دور).
      if (roleIds.isNotEmpty) {
        // whereIn يدعم الحد الأقصى 10 قيم، لذا نقسم إذا لزم الأمر
        for (var i = 0; i < roleIds.length; i += 10) {
          final end = (i + 10) < roleIds.length ? (i + 10) : roleIds.length;
          final batchIds = roleIds.sublist(i, end);

          final rolesSnapshot = await firestore
              .collection(organizationId)
              .doc('users')
              .collection('roles')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();

          for (final roleDoc in rolesSnapshot.docs) {
            final roleData = roleDoc.data();
            roles.add(
              RoleModel.fromJson({'id': roleDoc.id, ...Map<String, dynamic>.from(roleData)}),
            );
          }
        }
      }

      return Right(
        UserManagementModel.fromJson({
          'id': doc.id,
          ...data,
          'roles': roles.map((role) => role.toJson()).toList(),
        }).toEntity(),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<String?> getUserNameById(String userId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) return null;

      final doc = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      final name = data['name'] as String?;
      if (name != null && name.isNotEmpty) return name;

      final email = data['email'] as String?;
      if (email != null && email.isNotEmpty) {
        final username = email.split('@')[0];
        return username
            .replaceAll('.', ' ')
            .replaceAll('_', ' ')
            .replaceAll('-', ' ')
            .split(' ')
            .map(
              (word) => word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                  : '',
            )
            .join(' ');
      }

      return null;
    } on Exception catch (_) {
      return null;
    }
  }

  @override
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
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      // ✅ ذري بأفضل جهد: إنشاء Auth أولاً (خارج المعاملة) ثم Transaction.
      // إذا فشلت المعاملة يُحذف حساب Auth تلقائياً. التفاصيل والlimitations
      // في الملاحظة الشاملة أعلى الملف.
      UserCredential? userCredential;

      // إنشاء حساب Firebase Auth أولاً لضمان عدم وجود حسابات يتيمة
      if (!useCurrentUser && email != null) {
        try {
          userCredential = await auth.createUserWithEmailAndPassword(
            email: email,
            password: accountPassword ?? roleCode,
          );
        } on Exception catch (e) {
          return Left(ServerFailure(message: 'فشل إنشاء الحساب: ${_readableError(e)}'));
        }
      }

      String? generatedUserId;
      Map<String, dynamic>? preparedUserData;

      // تحديد حالة تحقق البريد الإلكتروني قبل المعاملة
      bool isEmailVerified;
      if (useCurrentUser) {
        isEmailVerified = auth.currentUser?.emailVerified ?? false;
      } else {
        final user = userCredential?.user;
        isEmailVerified = user?.emailVerified ?? false;
      }

      try {
        await firestore.runTransaction((transaction) async {
          // المرحلة 1: كل القراءات قبل كل الكتابات (القاعدة
          // الحاسمة أعلى الملف) — تُقرأ الأدوار هنا وتُكتب
          // الغير موجودة في المرحلة 2.
          final roleSnapshots = <String, DocumentSnapshot>{};
          for (final roleId in roleIds) {
            final roleDoc = firestore
                .collection(organizationId)
                .doc('users')
                .collection('roles')
                .doc(roleId);
            roleSnapshots[roleId] = await transaction.get(roleDoc);
          }

          // تحديد معرف المستخدم والبريد الفعلي أولاً: فحص
          // الفريدية وإنشاء القيد يجب أن يستخدما نفس البريد
          // (عند useCurrentUser يكون currentUser.email وليس
          // معامل email).
          final currentUser = auth.currentUser;
          String userId;
          String userEmail = email ?? '';

          if (useCurrentUser && currentUser != null) {
            userId = currentUser.uid;
            userEmail = currentUser.email ?? email ?? '';
          } else if (email != null) {
            userId = firestore
                .collection(organizationId)
                .doc('users')
                .collection('users')
                .doc()
                .id;
            userEmail = email;
          } else {
            userId = firestore
                .collection(organizationId)
                .doc('users')
                .collection('users')
                .doc()
                .id;
          }

          // فحص وجود المستخدم قبل فحص البريد: عند useCurrentUser
          // يكون userId هو uid الحالي، فإذا كان موجوداً (مع قيد
          // بريده) يكون الخطأ "المستخدم موجود مسبقاً" وليس
          // "البريد مستخدم من قبل" (رسالة مضللة). في الحالة
          // العادية (معرف جديد) الفحص ينجح دائماً ثم يُفحص البريد.
          final userDoc = firestore
              .collection(organizationId)
              .doc('users')
              .collection('users')
              .doc(userId);

          final docSnapshot = await transaction.get(userDoc);
          if (docSnapshot.exists) {
            throw Exception('المستخدم موجود مسبقاً');
          }

          // فحص فريدية البريد داخل المعاملة: الفحص والكتابة معاً
          // يمنعان إنشاء مستخدمين بنفس البريد في وقت متزامن (لو
          // فُحص خارجها قد يمرّ مستخدمان بالفحص قبل أن يكتب أي
          // منهما قيد البريد). يُستخدم البريد الفعلي (userEmail)
          // لأن القيد يُنشأ له وليس لمعامل email (عند
          // useCurrentUser قد يختلفان).
          if (userEmail.isNotEmpty) {
            final emailConstraintRef = firestore
                .collection(organizationId)
                .doc('users')
                .collection('unique_constraints')
                .doc('email:${userEmail.trim().toLowerCase()}');
            final emailSnapshot = await transaction.get(emailConstraintRef);
            if (emailSnapshot.exists) {
              throw Exception('البريد الإلكتروني مستخدم من قبل');
            }
          }

          // المرحلة 2: كل الكتابات (بعد كل القراءات)
          // ✅ ذري: إنشاء الأدوار التلقائية (بعد قراءتها في المرحلة 1)
          for (final roleId in roleIds) {
            if (!roleSnapshots[roleId]!.exists) {
              var rolePermissions = <String>[];
              if (roleId == 'admin') {
                final permissionsManager = PermissionsManager();
                final allPermissions = permissionsManager.getAllPermissions();
                rolePermissions = allPermissions.map((p) => p.id).toList();
              }

              transaction.set(
                firestore
                    .collection(organizationId)
                    .doc('users')
                    .collection('roles')
                    .doc(roleId),
                {
                  'name': roleId,
                  'displayName': roleId == 'admin' ? 'المدير' : roleId,
                  'description': roleId == 'admin'
                      ? 'دور المدير - يحصل على جميع الصلاحيات تلقائياً'
                      : 'دور تم إنشاؤه تلقائياً',
                  'permissions': rolePermissions,
                  'isActive': true,
                  'createdAt': Timestamp.fromDate(DateTime.now()),
                },
              );
            }
          }

          final now = DateTime.now();
          final userData = <String, dynamic>{
            'email': userEmail,
            'name': name,
            'phoneNumber': phoneNumber,
            'department': department,
            'jobTitle': jobTitle,
            'roleIds': roleIds,
            'accessCode': roleCode,
            'customPermissions': customPermissions ?? [],
            'isActive': true,
            'isEmailVerified': isEmailVerified,
            'createdAt': Timestamp.fromDate(now),
            'createdBy': createdBy,
          };

          transaction.set(userDoc, userData);

          // ✅ ذري: إنشاء قيد البريد الإلكتروني داخل نفس المعاملة
          if (userEmail.isNotEmpty) {
            final emailConstraintRef = firestore
                .collection(organizationId)
                .doc('users')
                .collection('unique_constraints')
                .doc('email:${userEmail.trim().toLowerCase()}');
            transaction.set(emailConstraintRef, {
              'type': 'email',
              'value': userEmail.trim().toLowerCase(),
              'userId': userId,
            });
          }

          // ✅ ذري: تسجيل نشاط الإنشاء داخل نفس المعاملة
          if (logActionType != null && logActionType.isNotEmpty) {
            final activityLogRef = firestore
                .collection(organizationId)
                .doc('users')
                .collection('logs')
                .doc();
            transaction.set(activityLogRef, {
              'userId': auth.currentUser?.uid ?? 'system',
              'userName': auth.currentUser?.displayName,
              'userEmail': auth.currentUser?.email,
              'actionType': logActionType,
              'targetType': logTargetType ?? 'user',
              'targetId': logTargetId ?? userId,
              'details': logDetails ?? 'تم إنشاء مستخدم جديد: $name',
              'timestamp': Timestamp.fromDate(DateTime.now()),
              'isSuccess': logIsSuccess,
              'oldValues': logOldValues,
              'newValues': logNewValues ?? {
                'name': name,
                'email': userEmail,
                'roles': roleIds.join(', '),
              },
            });
          }

          generatedUserId = userId;
          preparedUserData = userData;
        });

        // حفظ إعدادات الإشعارات الافتراضية للمستخدم الجديد (كلها مطفأة)
        // لضمان أن كل مستخدم جديد يبدأ بإعدادات إشعارات شخصية مطفأة
        // ويتم تفعيلها لاحقاً من خلال صفحة إعدادات الإشعارات الشخصية
        if (generatedUserId != null) {
          try {
            await FirebaseFirestore.instance
                .collection(organizationId)
                .doc('users')
                .collection('users')
                .doc(generatedUserId)
                .collection('notification_settings')
                .doc('settings')
                .set({
              'enableNotifications': false,
              'enablePushNotifications': false,
              'enableSound': false,
              'enableVibration': false,
              'enableSectionBadges': false,
              // الفواتير
              'invoice_notify_new': false,
              'invoice_notify_paid': false,
              'invoice_notify_updated': false,
              'invoice_notify_deleted': false,
              'invoice_notify_cash': false,
              'invoice_alert_overdue': false,
              'invoice_alert_unpaid': false,
              // العملاء
              'customer_notify_new': false,
              'customer_notify_zero_balance': false,
              'customer_notify_updated': false,
              'customer_notify_deleted': false,
              'customer_notify_cash_invoice': false,
              'customer_alert_credit_limit': false,
              'customer_alert_high_debt': false,
              // المخزون
              'inventory_notify_new': false,
              'inventory_notify_deleted': false,
              'inventory_notify_quantity_update': false,
              'inventory_alert_out_of_stock': false,
              'inventory_alert_low_stock': false,
              // الاشتراكات
              'subscription_notify_new': false,
              'subscription_notify_updated': false,
              'subscription_notify_renewed': false,
              'subscription_notify_deleted': false,
              'subscription_alert_expired': false,
              'subscription_alert_expiring_soon': false,
              // الصيانة
              'maintenance_notify_new': false,
              'maintenance_notify_updated': false,
              'maintenance_notify_deleted': false,
              'maintenance_notify_completed': false,
              'maintenance_alert_urgent': false,
              'maintenance_alert_overdue': false,
              // التأجير
              'rental_notify_new': false,
              'rental_notify_updated': false,
              'rental_notify_deleted': false,
              'rental_notify_returned': false,
              'rental_alert_expired': false,
              'rental_alert_expiring_soon': false,
            // المصروفات
            'expenses_notify_new': false,
            'expenses_notify_updated': false,
            'expenses_notify_deleted': false,
            'expenses_alert_pending': false,
            // أيام التنبيه (warning days) - شخصية لكل مستخدم
            'warningDays': [1, 2, 3],
            'reminderDaysBefore': 7,
          }, SetOptions(merge: true));
          } on Exception {
            // تجاهل الأخطاء - لا ينبغي أن يفشل إنشاء المستخدم بسبب إعدادات الإشعارات
          }
        }
      } on Exception catch (e) {
        // تنظيف: حذف حساب Auth إذا فشلت المعاملة
        final userToDelete = userCredential?.user;
        if (userToDelete != null) {
          try {
            await userToDelete.delete();
          } on Exception {
            // تجاهل خطأ الحذف
          }
        }
        return Left(ServerFailure(message: _readableError(e)));
      }

      // تحديث اسم العرض بعد نجاح المعاملة
      if (!useCurrentUser) {
        final userToUpdate = userCredential?.user;
        if (userToUpdate != null) {
          try {
            await userToUpdate.updateDisplayName(name);
          } on Exception {
            // تجاهل الخطأ
          }
        }
      } else {
        final currentUser = auth.currentUser;
        if (currentUser != null) {
          try {
            if (currentUser.displayName != name) {
              await currentUser.updateDisplayName(name);
            }
          } on Exception {
            // تجاهل الخطأ
          }
        }
      }

      final userId = generatedUserId!;
      final userData = preparedUserData!;

      return Right(
        UserManagementModel.fromJson({'id': userId, ...userData}).toEntity(),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
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
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      // ✅ ذري بالكامل: فحص تعارض البريد + تحديث المستخدم + قيود البريد + سجل
      // النشاط في Transaction واحدة (لا فحص منفصل للبريد خارجها). التفاصيل في
      // الملاحظة الشاملة أعلى الملف.
      UserManagementEntity? updatedUser;

      await firestore.runTransaction((transaction) async {
        final userDoc = firestore
            .collection(organizationId)
            .doc('users')
            .collection('users')
            .doc(userId);

        // التحقق من وجود المستخدم قبل التحديث
        final docSnapshot = await transaction.get(userDoc);
        if (!docSnapshot.exists) {
          throw Exception('المستخدم غير موجود');
        }

        // ✅ ذري: التحقق من عدم تعارض البريد الإلكتروني داخل المعاملة
        if (email != null && email.isNotEmpty) {
          final emailConstraintRef = firestore
              .collection(organizationId)
              .doc('users')
              .collection('unique_constraints')
               .doc('email:${email.trim().toLowerCase()}');
          final emailSnapshot = await transaction.get(emailConstraintRef);
          if (emailSnapshot.exists && emailSnapshot.data()?['userId'] != userId) {
            throw Exception('البريد الإلكتروني مستخدم من قبل مستخدم آخر');
          }
        }

        final updateData = <String, dynamic>{
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };
        if (email != null) updateData['email'] = email;
        if (name != null) updateData['name'] = name;
        if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
        if (department != null) updateData['department'] = department;
        if (jobTitle != null) updateData['jobTitle'] = jobTitle;
        if (roleIds != null) updateData['roleIds'] = roleIds;
        if (roleCode != null) updateData['accessCode'] = roleCode;
        if (customPermissions != null) {
          updateData['customPermissions'] = customPermissions;
        }
        if (notificationEnabled != null) {
          updateData['notificationEnabled'] = notificationEnabled;
        }

        transaction.update(userDoc, updateData);

        // ✅ ذري: تحديث قيد البريد الإلكتروني داخل المعاملة
        final oldEmail = docSnapshot.data()?['email'] ?? '';
        final newEmail = email ?? oldEmail;
        if (newEmail != oldEmail && oldEmail.isNotEmpty) {
          transaction.delete(
            firestore
                .collection(organizationId)
                .doc('users')
                .collection('unique_constraints')
                .doc('email:${oldEmail.trim().toLowerCase()}'),
          );
        }
        if (email != null && email.isNotEmpty) {
          final emailConstraintRef = firestore
              .collection(organizationId)
              .doc('users')
              .collection('unique_constraints')
              .doc('email:${email.trim().toLowerCase()}');
          transaction.set(emailConstraintRef, {
            'type': 'email',
            'value': email.trim().toLowerCase(),
            'userId': userId,
          }, SetOptions(merge: true));
        }

        // ✅ ذري: تسجيل نشاط التحديث داخل نفس المعاملة
        if (logActionType != null && logActionType.isNotEmpty) {
          final activityLogRef = firestore
              .collection(organizationId)
              .doc('users')
              .collection('logs')
              .doc();
          transaction.set(activityLogRef, {
            'userId': auth.currentUser?.uid ?? 'system',
            'userName': auth.currentUser?.displayName,
            'userEmail': auth.currentUser?.email,
            'actionType': logActionType,
            'targetType': logTargetType ?? 'user',
            'targetId': logTargetId ?? userId,
            'details': logDetails ?? 'تم تحديث بيانات المستخدم',
            'timestamp': Timestamp.fromDate(DateTime.now()),
            'isSuccess': logIsSuccess,
            'oldValues': logOldValues,
            'newValues': logNewValues,
          });
        }

        final updatedData = Map<String, dynamic>.from(docSnapshot.data() ?? {});
        updatedData.addAll(updateData);
        updatedUser = UserManagementModel.fromJson({
          'id': userId,
          ...updatedData,
        }).toEntity();
      });

      // تهيئة إعدادات الإشعارات الشخصية للمستخدم إذا لم تكن موجودة (كلها مطفأة)
      try {
        final existingSettings = await FirebaseFirestore.instance
            .collection(organizationId)
            .doc('users')
            .collection('users')
            .doc(userId)
            .collection('notification_settings')
            .doc('settings')
            .get();

        if (!existingSettings.exists) {
          await FirebaseFirestore.instance
              .collection(organizationId)
              .doc('users')
              .collection('users')
              .doc(userId)
              .collection('notification_settings')
              .doc('settings')
              .set({
            'enableNotifications': false,
            'enablePushNotifications': false,
            'enableSound': false,
            'enableVibration': false,
            'enableSectionBadges': false,
            // الفواتير
            'invoice_notify_new': false,
            'invoice_notify_paid': false,
            'invoice_notify_updated': false,
            'invoice_notify_deleted': false,
            'invoice_notify_cash': false,
            'invoice_alert_overdue': false,
            'invoice_alert_unpaid': false,
            // العملاء
            'customer_notify_new': false,
            'customer_notify_zero_balance': false,
            'customer_notify_updated': false,
            'customer_notify_deleted': false,
            'customer_notify_cash_invoice': false,
            'customer_alert_credit_limit': false,
            'customer_alert_high_debt': false,
            // المخزون
            'inventory_notify_new': false,
            'inventory_notify_deleted': false,
            'inventory_notify_quantity_update': false,
            'inventory_alert_out_of_stock': false,
            'inventory_alert_low_stock': false,
            // الاشتراكات
            'subscription_notify_new': false,
            'subscription_notify_updated': false,
            'subscription_notify_renewed': false,
            'subscription_notify_deleted': false,
            'subscription_alert_expired': false,
            'subscription_alert_expiring_soon': false,
            // الصيانة
            'maintenance_notify_new': false,
            'maintenance_notify_updated': false,
            'maintenance_notify_deleted': false,
            'maintenance_notify_completed': false,
            'maintenance_alert_urgent': false,
            'maintenance_alert_overdue': false,
            // التأجير
            'rental_notify_new': false,
            'rental_notify_updated': false,
            'rental_notify_deleted': false,
            'rental_notify_returned': false,
            'rental_alert_expired': false,
            'rental_alert_expiring_soon': false,
            // المصروفات
            'expenses_notify_new': false,
            'expenses_notify_updated': false,
            'expenses_notify_deleted': false,
            'expenses_alert_pending': false,
            // أيام التنبيه (warning days) - شخصية لكل مستخدم
            'warningDays': [1, 2, 3],
            'reminderDaysBefore': 7,
          });
        }
      } on Exception {
        // تجاهل الأخطاء - لا ينبغي أن يفشل تحديث المستخدم بسبب إعدادات الإشعارات
      }

      if (updatedUser != null) {
        return Right(updatedUser!);
      }

      return await getUserById(userId);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(
    String userId, {
    String? logActionType,
    String? logDetails,
    String? logTargetId,
    String? logTargetType,
    Map<String, dynamic>? logOldValues,
    Map<String, dynamic>? logNewValues,
    bool logIsSuccess = true,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      // ✅ ذري بالكامل: فحص الوجود + حذف المستخدم + قيد البريد + سجلات
      // النشاط + سجل الحذف في Transaction واحدة (إذا لم يوجد المستند تفشل
      // المعاملة ولا يُحذف). ⚠️ حد Firestore (500 عملية): السجلات الزائدة
      // عن _maxBatchWrites تُحذف في دفعات ذرية منفصلة بعد نجاح المعاملة
      // (انظر _deleteRefsInBatches). التفاصيل في الملاحظة الشاملة أعلى الملف.
      final userDoc = firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .doc(userId);

      // حذف جميع سجلات النشاط المرتبطة بالمستخدم
      final logsQuery = firestore
          .collection(organizationId)
          .doc('users')
          .collection('logs')
          .where('userId', isEqualTo: userId);

      // ⚠️ Firestore لا تسمح بـ queries داخل transactions،
      // لذا نقرأ بـ query.get() ثم نحذف المستندات داخل
      // المعاملة (أفضل ما يمكن مع قيود Firestore).
      final logsSnapshot = await logsQuery.get();

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        if (!snapshot.exists) {
          throw Exception('المستخدم غير موجود');
        }

        final userData = snapshot.data()!;
        final userEmail = userData['email'] as String?;

        transaction.delete(userDoc);

        // قيد البريد (unique_constraints) إذا كان البريد موجوداً
        if (userEmail != null && userEmail.isNotEmpty) {
          final emailConstraintRef = firestore
              .collection(organizationId)
              .doc('users')
              .collection('unique_constraints')
              .doc('email:${userEmail.trim().toLowerCase()}');
          transaction.delete(emailConstraintRef);
        }

        // سجلات النشاط داخل المعاملة (ضمن حد 500 عملية)
        final logsInTransaction = logsSnapshot.docs.length > _maxBatchWrites
            ? logsSnapshot.docs.sublist(0, _maxBatchWrites)
            : logsSnapshot.docs;
        for (final logDoc in logsInTransaction) {
          transaction.delete(logDoc.reference);
        }

        // سجل نشاط الحذف
        final logDocRef = firestore
            .collection(organizationId)
            .doc('users')
            .collection('logs')
            .doc();
        transaction.set(logDocRef, {
          'userId': auth.currentUser?.uid ?? 'system',
          'userName': auth.currentUser?.displayName,
          'userEmail': auth.currentUser?.email,
          'actionType': logActionType ?? 'delete',
          'targetType': logTargetType ?? 'user',
          'targetId': logTargetId ?? userId,
          'details': logDetails ?? 'تم حذف المستخدم: ${userData['name']}',
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'isSuccess': logIsSuccess,
          // حفظ بريد المستخدم المحذوف في oldValues لأن مستنده
          // يُحذف مع العملية (userEmail الآن = بريد الفاعل)
          'oldValues': {
            ...?logOldValues,
            'email': userEmail,
          },
          'newValues': logNewValues,
        });
      });

      // سجلات النشاط المتبقية (إذا تجاوزت حد المعاملة)
      // في دفعات ذرية منفصلة بعد نجاح المعاملة
      if (logsSnapshot.docs.length > _maxBatchWrites) {
        await _deleteRefsInBatches(
          logsSnapshot.docs
              .sublist(_maxBatchWrites)
              .map((doc) => doc.reference)
              .toList(),
        );
      }

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
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
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      // ✅ ذري: فحص الوجود + تحديث الحالة + سجل النشاط في
      // Transaction واحدة (إذا لم يوجد المستخدم تفشل المعاملة
      // ولا يُحدَّث). التفاصيل في الملاحظة الشاملة أعلى الملف.
      final userDoc = firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .doc(userId);

      final currentUser = auth.currentUser;

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        if (!snapshot.exists) {
          throw Exception('المستخدم غير موجود');
        }

        final userData = snapshot.data()!;
        final userName = userData['name'] as String?;

        transaction.update(userDoc, {
          'isActive': isActive,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        // سجل نشاط التحديث داخل نفس Transaction
        final logDocRef = firestore
            .collection(organizationId)
            .doc('users')
            .collection('logs')
            .doc();
        transaction.set(logDocRef, {
          'userId': currentUser?.uid ?? 'system',
          'userName': currentUser?.displayName,
          'userEmail': currentUser?.email,
          'actionType': logActionType ?? 'toggle_user_status',
          'targetType': logTargetType ?? 'user',
          'targetId': logTargetId ?? userId,
          'details': logDetails ?? 'تم ${isActive ? 'تفعيل' : 'تعطيل'} المستخدم: ${userName ?? userId}',
          'newValues': logNewValues ?? {'isActive': isActive},
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'isSuccess': logIsSuccess,
          'oldValues': logOldValues,
        });
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, UserManagementEntity>> updateUserNotificationSettings({
    required String userId,
    required bool notificationEnabled,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      // ✅ ذري: فحص الوجود + التحديث + إرجاع البيانات المحدثة
      // في Transaction واحدة. التفاصيل في الملاحظة الشاملة أعلى الملف.
      final userDoc = firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .doc(userId);

      return await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        if (!snapshot.exists) {
          throw Exception('المستخدم غير موجود');
        }

        final now = Timestamp.fromDate(DateTime.now());
        transaction.update(userDoc, {
          'notificationEnabled': notificationEnabled,
          'updatedAt': now,
        });

        // دمج التحديث في البيانات المرجعة لتعكس القيمة الجديدة
        // بدلاً من إرجاع بيانات اللقطة القديمة (قبل التحديث)
        final updatedData = Map<String, dynamic>.from(snapshot.data()!);
        updatedData['notificationEnabled'] = notificationEnabled;
        updatedData['updatedAt'] = now;
        final userModel = UserManagementModel.fromJson({
          'id': userId,
          ...updatedData,
        });

        return Right(userModel.toEntity());
      });
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<RoleEntity>>> getRoles() async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) return const Right([]);

      final snapshot = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('roles')
          .get();

      final roles = snapshot.docs.map((doc) {
        return RoleModel.fromJson({'id': doc.id, ...doc.data()}).toEntity();
      }).toList();

      return Right(roles);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, RolesPage>> getRolesPaginated({
    required String organizationEmail,
    required int limit,
    DocumentSnapshot<Object?>? lastDocument,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) return const Right(RolesPage(roles: [], lastDocument: null));

      var query = firestore
          .collection(organizationId)
          .doc('users')
          .collection('roles')
          .orderBy('name');

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      final roles = snapshot.docs.map((doc) {
        return RoleModel.fromJson({'id': doc.id, ...doc.data()}).toEntity();
      }).toList();

      return Right(RolesPage(roles: roles, lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null));
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Stream<Either<Failure, List<RoleEntity>>> getRolesStream() {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(const Right([]));
      }

      return firestore
          .collection(organizationId)
          .doc('users')
          .collection('roles')
          .snapshots()
          .map((snapshot) {
            try {
              final roles = snapshot.docs.map((doc) {
                return RoleModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }).toEntity();
              }).toList();
              return Right<Failure, List<RoleEntity>>(roles);
            } on Exception catch (e) {
              return Left<Failure, List<RoleEntity>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          });
    } on Exception catch (e) {
      return Stream.value(
        Left<Failure, List<RoleEntity>>(ServerFailure(message: _readableError(e))),
      );
    }
  }

  @override
  Future<Either<Failure, RoleEntity>> getRoleById(String roleId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      final doc = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('roles')
          .doc(roleId)
          .get();
      if (!doc.exists) throw Exception('الدور غير موجود');

      final data = doc.data();
      if (data == null) return Left(ServerFailure(message: 'المستند فارغ'));
      final mapData = Map<String, dynamic>.from(data);
      return Right(
        RoleModel.fromJson({'id': doc.id, ...mapData}).toEntity(),
      );
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, RoleEntity>> createRole({
    required String name,
    required String displayName,
    required List<String> permissions,
    String? description,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      final currentUser = auth.currentUser;
      final roleData = {
        'name': name,
        'displayName': displayName,
        'description': description,
        'permissions': permissions,
        'isActive': true,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'createdBy': currentUser?.uid,
      };

      // ✅ ذري: فحص عدم وجود الدور + إنشائه في Transaction واحدة.
      // التفاصيل في الملاحظة الشاملة أعلى الملف.
      await firestore.runTransaction((transaction) async {
        final roleDoc = firestore
            .collection(organizationId)
            .doc('users')
            .collection('roles')
            .doc(name);

        // التحقق من عدم وجود الدور مسبقاً
        final docSnapshot = await transaction.get(roleDoc);

        if (docSnapshot.exists) {
          throw Exception('الدور موجود مسبقاً');
        }

        transaction.set(roleDoc, roleData);
      });

      // ✅ إبطال كاش الأدوار (أُنشئ دور جديد)
      _rolesMapCache = null;

      return Right(RoleModel.fromJson({'id': name, ...roleData}).toEntity());
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, RoleEntity>> updateRole({
    required String roleId,
    String? displayName,
    String? description,
    List<String>? permissions,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (displayName != null) updateData['displayName'] = displayName;
      if (description != null) updateData['description'] = description;
      if (permissions != null) updateData['permissions'] = permissions;

      // ✅ ذري: فحص وجود الدور + تحديثه في Transaction واحدة.
      // التفاصيل في الملاحظة الشاملة أعلى الملف.
      await firestore.runTransaction((transaction) async {
        final roleDoc = firestore
            .collection(organizationId)
            .doc('users')
            .collection('roles')
            .doc(roleId);

        // التحقق من وجود الدور قبل التحديث
        final docSnapshot = await transaction.get(roleDoc);

        if (!docSnapshot.exists) {
          throw Exception('الدور غير موجود');
        }

        transaction.update(roleDoc, updateData);
      });

      // ✅ إبطال كاش الأدوار (تُحدِّث الدور)
      _rolesMapCache = null;

      return await getRoleById(roleId);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRole(String roleId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) throw Exception('لم يتم العثور على المؤسسة');

      // ✅ ذري مع limitation (دفعات Batch): حذف المستخدمين الذين لديهم
      // هذا الدور فقط + قيود بريدهم + سجلات نشاطهم + الدور (إذا كان
      // العدد ضمن حد Firestore تُنفذ كل العمليات في Batch واحد ذري).
      // ⚠️ البحث خارج الدفعات (Firestore لا يسمح بـ queries فيها)،
      // فنعيد التحقق (userRoleIds.length == 1) لمنع حذف مستخدم لديه
      // أدوار إضافية. limitation: مستخدم حصل على الدور بعد البحث لن
      // يُحذف (الحل الأمثل: Cloud Function). التفاصيل في الملاحظة
      // الشاملة أعلى الملف.
      // البحث عن المستخدمين الذين لديهم هذا الدور فقط (arrayContains)
      final usersSnapshot = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .where('roleIds', arrayContains: roleId)
          .get();

      // جمع مراجع كل ما سيُحذف: المستخدمين الذين لديهم هذا
      // الدور فقط + قيود بريدهم + سجلات نشاطهم + الدور
      final refsToDelete = <DocumentReference>[];
      final deletedUserIds = <String>[];

      // حذف المستخدمين الذين لديهم هذا الدور فقط (إعادة
      // التحقق: userRoleIds.length == 1 يمنع حذف مستخدم
      // لديه أدوار إضافية)
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userRoleIds = List<String>.from(userData['roleIds'] ?? []);

        if (userRoleIds.length == 1 && userRoleIds.contains(roleId)) {
          refsToDelete.add(userDoc.reference);
          deletedUserIds.add(userDoc.id);

          // قيد البريد مع المستخدم (كما في deleteUser) لمنع
          // ترك قيود يتيمة تمنع إعادة استخدام البريد
          final userEmail = userData['email'] as String?;
          if (userEmail != null && userEmail.isNotEmpty) {
            refsToDelete.add(
              firestore
                  .collection(organizationId)
                  .doc('users')
                  .collection('unique_constraints')
                  .doc('email:${userEmail.trim().toLowerCase()}'),
            );
          }
        }
      }

      // سجلات نشاط المستخدمين المحذوفين (نفس نمط deleteUser)
      // لمنع ترك سجلات يتيمة. ⚠️ whereIn تدعم 10 قيم كحد
      // أقصى لكل استعلام.
      for (var i = 0; i < deletedUserIds.length; i += 10) {
        final end = (i + 10) < deletedUserIds.length
            ? (i + 10)
            : deletedUserIds.length;
        final logsSnapshot = await firestore
            .collection(organizationId)
            .doc('users')
            .collection('logs')
            .where('userId', whereIn: deletedUserIds.sublist(i, end))
            .get();
        for (final logDoc in logsSnapshot.docs) {
          refsToDelete.add(logDoc.reference);
        }
      }

      // حذف الدور
      refsToDelete.add(
        firestore
            .collection(organizationId)
            .doc('users')
            .collection('roles')
            .doc(roleId),
      );

      // تنفيذ جميع العمليات في دفعات ذرية (انظر _deleteRefsInBatches)
      await _deleteRefsInBatches(refsToDelete);

      // ✅ إبطال كاش الأدوار (حُذف الدور)
      _rolesMapCache = null;

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<PermissionEntity>>> getPermissions() async {
    try {
      // استخدام مدير الصلاحيات للحصول على جميع الصلاحيات من أقسام التطبيق
      final permissionsManager = PermissionsManager();
      final permissions = permissionsManager.getAllPermissions();
      return Right(permissions);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<PermissionEntity>>> getPermissionsByCategory(
    String category,
  ) async {
    try {
      // استخدام مدير الصلاحيات للحصول على صلاحيات قسم معين
      final permissionsManager = PermissionsManager();
      final permissions = permissionsManager.getPermissionsBySection(category);
      return Right(permissions);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getUsersStatistics() async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) return const Right({});

      // ✅ تحسين الأداء: استخدام count() بدلاً من جلب جميع المستندات
      // هذا يقلل من عرض النطاق الترددي واستخدام الذاكرة بشكل كبير.
      final usersRef = firestore
          .collection(organizationId)
          .doc('users')
          .collection('users');

      final totalSnapshot = await usersRef.count().get();
      final activeSnapshot = await usersRef.where('isActive', isEqualTo: true).count().get();
      final inactiveSnapshot = await usersRef.where('isActive', isEqualTo: false).count().get();
      final adminsSnapshot = await usersRef.where('roleIds', arrayContains: 'admin').count().get();

      final totalUsers = totalSnapshot.count ?? 0;
      final activeUsers = activeSnapshot.count ?? 0;
      final inactiveUsers = inactiveSnapshot.count ?? 0;
      final admins = adminsSnapshot.count ?? 0;

      final stats = {
        'total': totalUsers,
        'active': activeUsers,
        'inactive': inactiveUsers,
        'admins': admins,
      };

      return Right(stats);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, bool>> checkUserExists({
    required String name,
    required String roleCode,
    String? email,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) return const Right(false);

      Query query = firestore
          .collection(organizationId)
          .doc('users')
          .collection('users');

      // التحقق من اسم المستخدم ورمز الوصول
      query = query
          .where('name', isEqualTo: name)
          .where('accessCode', isEqualTo: roleCode);

      // التحقق من البريد الإلكتروني إذا تم توفيره
      if (email != null && email.isNotEmpty) {
        query = query.where('email', isEqualTo: email);
      }

      final snapshot = await query.limit(1).get();

      return Right(snapshot.docs.isNotEmpty);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  /// دالة مساعدة عامة للبحث في حقول المستخدمين
  Future<Either<Failure, List<String>>> _searchUserField({
    required String fieldName,
    required String query,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) return const Right([]);

      final queryLower = query.toLowerCase();

      // استخدام Firestore query مع where للبحث
      final snapshot = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .where(fieldName, isGreaterThanOrEqualTo: queryLower)
          .where(fieldName, isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(20)
          .get();

      final results =
          snapshot.docs
              .map((doc) => doc.data()[fieldName] as String?)
              .where(
                (value) =>
                    value != null && value.toLowerCase().contains(queryLower),
              )
              .cast<String>()
              .toSet()
              .toList()
            ..sort();

      return Right(results);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<String>>> searchUserNames({
    required String query,
  }) => _searchUserField(fieldName: 'name', query: query);

  @override
  Future<Either<Failure, List<String>>> searchUserEmails({
    required String query,
  }) => _searchUserField(fieldName: 'email', query: query);

  @override
  Future<Either<Failure, List<String>>> searchUserPhones({
    required String query,
  }) => _searchUserField(fieldName: 'phoneNumber', query: query);

  @override
  Future<Either<Failure, List<String>>> searchRoleCodes({
    required String query,
  }) => _searchUserField(fieldName: 'accessCode', query: query);

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUsersSettings() async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      final doc = await firestore
          .collection(organizationId)
          .doc('settings')
          .collection('users')
          .doc('config')
          .get();

      if (doc.exists) {
        return Right(doc.data() ?? {});
      } else {
        // إرجاع الإعدادات الافتراضية
        final defaultSettings = {
          'allowUserRegistration': true,
          'requireEmailVerification': true,
          'enableTwoFactorAuth': false,
          'allowPasswordReset': true,
          'enableUserProfilePictures': true,
          'enableUserNotifications': true,
          'minPasswordLength': 8,
          'requireUppercase': true,
          'requireLowercase': true,
          'requireNumbers': true,
          'requireSpecialChars': false,
          'passwordExpiryDays': 90,
          'sessionTimeoutMinutes': 30,
          'allowMultipleSessions': false,
          'logoutOnInactivity': true,
          'allowRoleInheritance': true,
          'enableRoleHierarchy': false,
          'requireRoleApproval': true,
        };
        return Right(defaultSettings);
      }
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  /// ✅ ذري طبيعياً: كتابة واحدة بـ set() مع merge: true
  /// (ذرية تلقائياً، لا تحتاج Transaction). التفاصيل في
  /// الملاحظة الشاملة أعلى الملف.
  @override
  Future<Either<Failure, Map<String, dynamic>>> saveUsersSettings(
    Map<String, dynamic> settings,
  ) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // إضافة معلومات التحديث
      final updatedSettings = Map<String, dynamic>.from(settings);
      updatedSettings['updatedAt'] = FieldValue.serverTimestamp();
      updatedSettings['updatedBy'] = auth.currentUser?.email ?? 'unknown';

      await firestore
          .collection(organizationId)
          .doc('settings')
          .collection('users')
          .doc('config')
          .set(updatedSettings, SetOptions(merge: true));

      return Right(updatedSettings);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<UserLogEntity>>> getUserLogs({
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
          .doc('users')
          .collection('logs');

      // تطبيق الفلاتر أولاً
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

      // ثم الترتيب في النهاية
      query = query.orderBy('timestamp', descending: true);

      // ⚠️ ملاحظة للأداء: يتم جلب جميع السجلات المطابقة للفلاتر ثم فلترة البحث النصي محلياً.
      // يجب نقل searchQuery إلى استعلام Firestore (مثلاً باستخدام range query على الحقول النصية).
      final snapshot = await query.get();
      final logs = <UserLogEntity>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        final mapData = data as Map<String, dynamic>;
        final log = UserLogModel.fromJson({'id': doc.id, ...mapData}).toEntity();

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

  /// ✅ ذري طبيعياً: كتابة واحدة بـ add() ولا تقرأ
  /// بيانات (ذرية تلقائياً، لا تحتاج Transaction).
  /// التفاصيل في الملاحظة الشاملة أعلى الملف.
  @override
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
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // استخدام المستخدم الحالي إذا لم يتم تحديد معرف المستخدم
      final currentUser = auth.currentUser;
      final actualUserId = userId == 'current_user' && currentUser != null
          ? currentUser.uid
          : userId;
      final actualUserName = userName ?? currentUser?.displayName;
      final actualUserEmail = userEmail ?? currentUser?.email;

      final now = DateTime.now();
      final logData = {
        'userId': actualUserId,
        'userName': actualUserName,
        'userEmail': actualUserEmail,
        'actionType': actionType,
        'timestamp': Timestamp.fromDate(now),
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
          .doc('users')
          .collection('logs')
          .add(logData);

      final log = UserLogModel.fromJson({
        'id': docRef.id,
        ...logData,
      }).toEntity();

      return Right(log);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUserLog(String logId) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // ✅ ذري: فحص وجود السجل + حذفه في Transaction
      // واحدة (إذا لم يوجد السجل تفشل المعاملة ولا يُحذف).
      // التفاصيل في الملاحظة الشاملة أعلى الملف.
      final logDoc = firestore
          .collection(organizationId)
          .doc('users')
          .collection('logs')
          .doc(logId);

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(logDoc);
        if (!snapshot.exists) {
          throw Exception('السجل غير موجود');
        }
        transaction.delete(logDoc);
      });

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> clearUserLogs({
    String? userId,
    DateTime? beforeDate,
  }) async {
    try {
      final organizationId = _getCurrentOrganizationId();
      if (organizationId == null) {
        return const Left(ServerFailure(message: 'المستخدم غير مسجل دخول'));
      }

      // ✅ ذري مع limitation (دفعات Batch): حذف جميع السجلات
      // المطابقة، كل دفعة ذرية بمفردها (Firestore لا يسمح
      // بمعاملات على استعلامات، لذا Query + دفعات - التفاصيل
      // في الملاحظة الشاملة أعلى الملف).
      Query query = firestore
          .collection(organizationId)
          .doc('users')
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

      // تنفيذ الحذف في دفعات ذرية (انظر _deleteRefsInBatches)
      await _deleteRefsInBatches(
        snapshot.docs.map((doc) => doc.reference).toList(),
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  // Stream Methods للتحديث الفوري
  @override
  Stream<Either<Failure, List<UserManagementEntity>>> getUsersStream({
    required String organizationEmail,
    int? limit,
    String? searchQuery,
    List<String>? roleFilters,
    bool? isActiveFilter,
  }) {
    try {
      final organizationId = organizationEmail.isNotEmpty
          ? organizationEmail
          : _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(
          const Left(ServerFailure(message: 'المستخدم غير مسجل دخول')),
        );
      }

      Query query = firestore
          .collection(organizationId)
          .doc('users')
          .collection('users');

      // إضافة فلتر isActive إذا كان موجوداً (قبل orderBy)
      if (isActiveFilter != null) {
        query = query.where('isActive', isEqualTo: isActiveFilter);
      }

      // إضافة الترتيب حسب createdAt
      query = query.orderBy('createdAt', descending: true);

      // تطبيق الحد
      if (limit != null) {
        query = query.limit(limit);
      }

      // ✅ أداء (2026-10-12): كاش تدريجي خاص بهذا
      // الستريم فقط يعالج docChanges بدلاً من إعادة
      // بناء كل المستخدمين مع كل لقطة — كان بناء
      // UserManagementEntity كامل (مع ربط الأدوار
      // من مجموعة منفصلة) يُعاد لكل مستخدم عند كل
      // تغيير في أي مستخدم، وهو الهدر الأكبر في
      // هذا الستريم مع كثرة المستخدمين.
      // ⚠️ إعادة البناء الكامل عند تغير خريطة
      // الأدوار: الأدوار تُجلب من مجموعة منفصلة
      // وتُخزن في _rolesMapCache التي تُبطل (تُصفَّر)
      // عند أي تعديل عليها (createRole/updateRole/
      // deleteRole) — فإذا تغير مثيل الخريطة بين
      // لقطتين (identical يفشل) نعيد البناء الكامل
      // لربط الأدوار المحدثة بجميع المستخدمين (نفس
      // سلوك الستريم الأصلي الذي كان يبني الكيانات
      // من جديد عند كل لقطة).
      final streamCache = <String, UserManagementEntity>{};
      Map<String, Map<String, dynamic>>? cachedRolesMap;

      return query
          .snapshots()
          .asyncMap((snapshot) async {
            try {
              // جلب خريطة الأدوار وربطها بالمستخدمين
              // ⚠️ لماذا: مستند المستخدم يحتوي فقط على
              // roleIds والأدوار في مجموعة منفصلة، لذا يجب
              // جلب الأدوار وربطها هنا مثل getUsers، وإلا
              // تظهر الأدوار فارغة في الستريم.
              final rolesMap = await _fetchRolesMap(organizationId);

              if (limit == null) {
                // الستريم غير المحدود: تحديث تدريجي
                // (بناء كامل فقط عند أول لقطة أو بعد
                // تعديل الأدوار — انظر الملاحظة أعلاه)
                if (cachedRolesMap == null ||
                    !identical(cachedRolesMap, rolesMap)) {
                  cachedRolesMap = rolesMap;
                  streamCache.clear();
                  for (final doc in snapshot.docs) {
                    final user = _parseUserDocWithRoles(doc, rolesMap);
                    if (user == null) {
                      streamCache.remove(doc.id);
                    } else {
                      streamCache[doc.id] = user;
                    }
                  }
                } else {
                  for (final change in snapshot.docChanges) {
                    final doc = change.doc;
                    if (change.type == DocumentChangeType.removed) {
                      streamCache.remove(doc.id);
                      continue;
                    }
                    final user = _parseUserDocWithRoles(doc, rolesMap);
                    if (user == null) {
                      streamCache.remove(doc.id);
                    } else {
                      streamCache[doc.id] = user;
                    }
                  }
                }

                // الحفاظ على ترتيب الاستعلام (createdAt
                // تنازلي) عبر المرور على مستندات اللقطة
                // مرتبة وأخذ الكيان المحلل من الكاش —
                // أدق من إعادة الترتيب في الذاكرة لأن
                // ترتيب Firestore الحقيقي (بما في ذلك
                // كسر التعادل) يُحفظ كما هو
                var users = <UserManagementEntity>[];
                for (final doc in snapshot.docs) {
                  final cachedUser = streamCache[doc.id];
                  if (cachedUser != null) {
                    users.add(cachedUser);
                  }
                }

                // تطبيق فلتر البحث محلياً
                users = _filterUsersByQuery(users, searchQuery);

                // تطبيق فلتر الأدوار محلياً (بمعرفات الأدوار)
                if (roleFilters != null && roleFilters.isNotEmpty) {
                  users = users
                      .where(
                        (user) => user.roleIds
                            .any((roleId) => roleFilters.contains(roleId)),
                      )
                      .toList();
                }

                return Right<Failure, List<UserManagementEntity>>(users);
              }

              // الستريم المحدود: تحليل كامل (السلوك
              // الأصلي) — نافذة الحد تتحرك وقد لا
              // يُصدر المستند الخارج تغييراً من نوع
              // removed بشكل موثوق (نفس سبب قسم
              // الفواتير)
              var users = _mapUserDocsToEntities(snapshot.docs, rolesMap);

              // تطبيق فلتر البحث محلياً
              users = _filterUsersByQuery(users, searchQuery);

              // تطبيق فلتر الأدوار محلياً (بمعرفات الأدوار)
              if (roleFilters != null && roleFilters.isNotEmpty) {
                users = users
                    .where(
                      (user) => user.roleIds
                          .any((roleId) => roleFilters.contains(roleId)),
                    )
                    .toList();
              }

              // التأكد من عدم تجاوز الحد
              if (users.length > limit) {
                users = users.sublist(0, limit);
              }

              return Right<Failure, List<UserManagementEntity>>(users);
            } on Exception catch (e) {
              return Left<Failure, List<UserManagementEntity>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, List<UserManagementEntity>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
    }
  }

  @override
  Stream<Either<Failure, Map<String, int>>> getUsersStatisticsStream({
    required String organizationEmail,
    int? limit,
  }) {
    try {
      final organizationId = organizationEmail.isNotEmpty
          ? organizationEmail
          : _getCurrentOrganizationId();
      if (organizationId == null) {
        return Stream.value(const Right({}));
      }

      return firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .snapshots()
          .asyncMap((snapshot) async {
            try {
              // ✅ أداء: استخدام count() بدلاً من تجميع كل المستندات في الذاكرة
              // هذا يقلل من استهلاك bandwidth والذاكرة بشكل كبير عند كثرة المستخدمين.
              final usersRef = firestore
                  .collection(organizationId)
                  .doc('users')
                  .collection('users');

              final totalSnapshot = await usersRef.count().get();
              final activeSnapshot = await usersRef.where('isActive', isEqualTo: true).count().get();
              final inactiveSnapshot = await usersRef.where('isActive', isEqualTo: false).count().get();
              final adminsSnapshot = await usersRef.where('roleIds', arrayContains: 'admin').count().get();

              final totalUsers = totalSnapshot.count ?? 0;
              final activeUsers = activeSnapshot.count ?? 0;
              final inactiveUsers = inactiveSnapshot.count ?? 0;
              final admins = adminsSnapshot.count ?? 0;

              final stats = {
                'total': totalUsers,
                'active': activeUsers,
                'inactive': inactiveUsers,
                'admins': admins,
              };

              return Right<Failure, Map<String, int>>(stats);
            } on Exception catch (e) {
              return Left<Failure, Map<String, int>>(
                ServerFailure(message: _readableError(e)),
              );
            }
          })
          .handleError((error) {
            return Left<Failure, Map<String, int>>(
              ServerFailure(message: _readableError(error)),
            );
          });
    } on Exception catch (e) {
      return Stream.value(Left(ServerFailure(message: _readableError(e))));
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
