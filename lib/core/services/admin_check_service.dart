import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '../../features/users/domain/repositories/users_repository.dart';
import '../email/email_normalization_service.dart';
import '../middleware/admin_check_middleware.dart';

/// وصف إدارة الصلاحيات والتحقق من وجود مستخدم مسؤول
// ignore: avoid_classes_with_only_static_members
class AdminCheckService {
  factory AdminCheckService() => _instance;
  AdminCheckService._internal();
  static final AdminCheckService _instance = AdminCheckService._internal();

  final UsersRepository _usersRepository = GetIt.instance<UsersRepository>();
  final _emailService = EmailNormalizationService();

  /// التحقق من وجود مستخدم مسؤول
  Future<bool> hasAdminUser() async {
    try {
      // البحث عن مستخدم مسؤول في Firestore مباشرة (أول نتيجة)
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      // إذا لم يكن المستخدم مسجل الدخول أو البريد الإلكتروني فارغاً، لا يوجد مسؤول
      if (currentUser == null || currentUser.email == null) {
        return false;
      }

      // جلب النتيجة مباشرة من Firestore (المستخدم الأول)
      // مهلة انتظار 20 ثانية
      final directResult = await _checkAdminDirectly().timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );

      // إذا كانت النتيجة مباشرة غير فارغة، ارجعها (true أو false)
      if (directResult != null) {
        return directResult;
      }

      // إذا تأخرت الطريقة المباشرة، جلب المستخدمين من المستودع مع مهلة 25 ثانية
      final result = await _usersRepository
          .getUsers(organizationEmail: currentUser.email!)
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw Exception('انتهت مهلة جلب بيانات المستخدمين'),
          );

      return await result.fold(
        (failure) {
          // ✅ تم التنبيه: فشل في جلب بيانات المستخدمين من Firestore
          // تعيين حد أقصى لعدد مرات إعادة المحاولة لتجنب التكرار اللانهائي
          throw Exception('خطأ في فحص المسؤولين: ${failure.message}');
        },
        (users) {
          // إذا كانت قائمة المستخدمين فارغة، لا يوجد مسؤول
          if (users.isEmpty) {
            return false;
          }

          // فحص سريع: التحقق من وجود أي مستخدم مسؤول
          return _checkForAdminFast(users);
        },
      );
    } on Exception catch (_) {
      // ✅ تم التنبيه: حد أقصى لعدد مرات إعادة المحاولة لتجنب التكرار اللانهائي
      // يجب أن يكون hasAdmin: false
      throw Exception('خطأ في فحص المسؤولين');
    }
  }

  /// التحقق من وجود مستخدم مسؤول مع التفاصيل (التوجيه المقترح)
  Future<AdminCheckResult> checkAdminWithDetails() async {
    try {
      // البحث عن مستخدم مسؤول في Firestore مباشرة (أول نتيجة)
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      // إذا لم يكن المستخدم مسجل الدخول أو البريد الإلكتروني فارغاً، لا يوجد مسؤول
      if (currentUser == null || currentUser.email == null) {
        return const AdminCheckResult(
          hasAdmin: false,
          hasAnyUsers: false,
          usersCount: 0,
          adminsCount: 0,
          recommendedRoute: '/create-admin',
        );
      }

      // جلب النتيجة مباشرة من Firestore (المستخدم الأول)
      final directResult = await _checkAdminDirectlyWithDetails().timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );

      // إذا كانت النتيجة مباشرة غير فارغة، ارجعها
      if (directResult != null) {
        return directResult;
      }

      // إذا تأخرت الطريقة المباشرة، جلب المستخدمين من المستودع مع مهلة 25 ثانية
      final result = await _usersRepository
          .getUsers(organizationEmail: currentUser.email!)
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw Exception('انتهت مهلة جلب بيانات المستخدمين'),
          );

      return await result.fold(
        (failure) => const AdminCheckResult(
          hasAdmin: false,
          hasAnyUsers: false,
          usersCount: 0,
          adminsCount: 0,
          recommendedRoute: '/create-admin',
          checkFailed: true, // ✅ تم التنبيه: فشل في جلب بيانات المستخدمين من Firestore
        ),
        (users) {
          final adminsCount = users
              .where((u) => u.roleIds.contains('admin'))
              .length;
          final hasAdmin = adminsCount > 0;

          return AdminCheckResult(
            hasAdmin: hasAdmin,
            hasAnyUsers: users.isNotEmpty,
            usersCount: users.length,
            adminsCount: adminsCount,
            recommendedRoute: hasAdmin ? '/dashboard' : '/create-admin',
          );
        },
      );
    } on Exception catch (_) {
      // ✅ تم التنبيه: حد أقصى لعدد مرات إعادة المحاولة لتجنب التكرار اللانهائي
      // يجب أن يكون hasAdmin: false
      return const AdminCheckResult(
        hasAdmin: false,
        hasAnyUsers: false,
        usersCount: 0,
        adminsCount: 0,
        recommendedRoute: '/create-admin',
        checkFailed: true,
      );
    }
  }

  /// جلب المستخدمين مباشرة من Firestore مع التفاصيل
  Future<AdminCheckResult?> _checkAdminDirectlyWithDetails() async {
    try {
      // جلب معرّف المؤسسة من البريد الإلكتروني للمستخدم
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      if (currentUser?.email == null) {
        return const AdminCheckResult(
          hasAdmin: false,
          hasAnyUsers: false,
          usersCount: 0,
          adminsCount: 0,
          recommendedRoute: '/create-admin',
        );
      }

      // جلب معرّف المؤسسة من البريد الإلكتروني للمستخدم
      final organizationId = _emailService.normalize(currentUser!.email!);
      final firestore = FirebaseFirestore.instance;

      // جلب مستخدم المسؤول الأول من Firestore مع مهلة 15 ثانية
      final usersQuery = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .where('roleIds', arrayContains: 'admin')
          .limit(1)
          .get()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('انتهت مهلة التحقق من صلاحيات المسؤول'),
          );

      if (usersQuery.docs.isNotEmpty) {
        return const AdminCheckResult(
          hasAdmin: true,
          hasAnyUsers: true,
          usersCount: -1, // عدد غير محدد (يتم حسابه لاحقاً)
          adminsCount: 1,
          recommendedRoute: '/dashboard',
        );
      }

      // جلب جميع المستخدمين من Firestore (لتعريف المسؤولين)
      final allUsersQuery = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .get()
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('انتهت مهلة جلب بيانات المستخدمين'),
          );

      final usersCount = allUsersQuery.docs.length;
      final adminsCount = allUsersQuery.docs.where((doc) {
        final data = doc.data();
        final roleIds = data['roleIds'] as List<dynamic>? ?? [];
        return roleIds.contains('admin');
      }).length;

      return AdminCheckResult(
        hasAdmin: adminsCount > 0,
        hasAnyUsers: usersCount > 0,
        usersCount: usersCount,
        adminsCount: adminsCount,
        recommendedRoute: adminsCount > 0 ? '/dashboard' : '/create-admin',
      );
    } on Exception catch (_) {
      return null;
    }
  }

  /// جلب المستخدمين مباشرة من Firestore (نتيجة بسيطة)
  Future<bool?> _checkAdminDirectly() async {
    try {
      // جلب معرّف المؤسسة من البريد الإلكتروني للمستخدم
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      // إذا لم يكن المستخدم مسجل الدخول أو البريد الإلكتروني فارغاً، لا يوجد مسؤول
      if (currentUser?.email == null) {
        return false; // إذا لم يكن المستخدم مسجل الدخول أو البريد الإلكتروني فارغاً، لا يوجد مسؤول
      }

      // جلب معرّف المؤسسة من البريد الإلكتروني للمستخدم
      final organizationId = _emailService.normalize(currentUser!.email!);
      final firestore = FirebaseFirestore.instance;

      // جلب مستخدم المسؤول الأول من Firestore مع مهلة 15 ثانية
      final usersQuery = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .where('roleIds', arrayContains: 'admin')
          .limit(1)
          .get()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('انتهت مهلة التحقق من صلاحيات المسؤول'),
          );

      if (usersQuery.docs.isNotEmpty) {
        return true;
      }

      // جلب جميع المستخدمين من Firestore (لتعريف المسؤولين) - مهلة انتظار 20 ثانية
      final allUsersQuery = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('users')
          .get()
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('انتهت مهلة جلب بيانات المستخدمين'),
          );

      for (final doc in allUsersQuery.docs) {
        final data = doc.data();
        final roleIds = List<String>.from(data['roleIds'] ?? []);

        if (roleIds.contains('admin') || roleIds.contains('المدير')) {
          return true;
        }
      }

      // البحث عن مستخدم مسؤول في أدوار Firestore
      final rolesQuery = await firestore
          .collection(organizationId)
          .doc('users')
          .collection('roles')
          .doc('admin')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('انتهت مهلة جلب أدوار المستخدمين'),
          );

      if (rolesQuery.exists) {
        // إذا كان دور المسؤول موجوداً، جلب المستخدمين الذين لديهم هذا الدور
        // التحقق من أن معرف الدور موجود في قائمة roleIds للمستخدمين
        final adminUsersQuery = await firestore
            .collection(organizationId)
            .doc('users')
            .collection('users')
            .where('roleIds', arrayContains: 'admin')
            .get()
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw Exception('انتهت مهلة جلب المسؤولين والمستخدمين'),
            );

        return adminUsersQuery.docs.isNotEmpty;
      }

      return false;
    } on Exception catch (_) {
      // إذا كانت القيمة فارغة، إرجاع null (فشل في جلب البيانات)
      return null;
    }
  }

  /// التحقق من وجود أي مستخدمين
  Future<bool> hasAnyUsers() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) return false;

      final result = await _usersRepository
          .getUsers(organizationEmail: currentUser.email!)
          .timeout(const Duration(seconds: 2));

      return await result.fold((failure) => false, (users) => users.isNotEmpty);
    } on Exception catch (_) {
      return false;
    }
  }

  /// جلب عدد المستخدمين
  Future<int> getUsersCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) return 0;

      final result = await _usersRepository
          .getUsers(organizationEmail: currentUser.email!)
          .timeout(const Duration(seconds: 2));

      return await result.fold((failure) => 0, (users) => users.length);
    } on Exception catch (_) {
      return 0;
    }
  }

  /// جلب عدد المسؤولين
  Future<int> getAdminsCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) return 0;

      final result = await _usersRepository
          .getUsers(organizationEmail: currentUser.email!)
          .timeout(const Duration(seconds: 2));

      return await result.fold((failure) => 0, (users) {
        return users
            .where(
              (user) =>
                  user.roles.any(
                    (role) =>
                        role.name.toLowerCase() == 'admin' ||
                        role.name.toLowerCase() == 'المدير' ||
                        role.displayName.toLowerCase().contains('المدير') ||
                        role.displayName.toLowerCase().contains('admin'),
                  ) ||
                  user.roleIds.any(
                    (roleId) =>
                        roleId.toLowerCase() == 'admin' ||
                        roleId.toLowerCase() == 'المدير',
                  ),
            )
            .length;
      });
    } on Exception catch (_) {
      return 0;
    }
  }

  /// فحص سريع للتأكد من وجود مستخدم مسؤول في قائمة المستخدمين
  bool _checkForAdminFast(List<dynamic> users) {
      // فحص سريع: البحث في roleIds فقط (أداء عالي)
    for (var i = 0; i < users.length; i++) {
      final user = users[i];

      // البحث عن دور المسؤول في قائمة الأدوار (طريقة احتياطية)
      // التحقق من أن معرف الدور موجود في roleIds للمستخدم
      if (user.roleIds != null && user.roleIds.isNotEmpty) {
        for (final roleId in user.roleIds) {
          final roleIdStr = roleId.toString().toLowerCase();
          if (roleIdStr == 'admin' || roleIdStr == 'المدير') {
            return true;
          }
        }
      }
    }

    // فحص طريقة احتياطية: البحث في الأدوار (الأدوار المخصصة)
    // التحقق من أن معرف الدور موجود في list roles
    for (var i = 0; i < users.length; i++) {
      final user = users[i];
      if (user.roles != null && user.roles.isNotEmpty) {
        for (final role in user.roles) {
          final roleName = role.name?.toString().toLowerCase() ?? '';
          final roleDisplayName =
              role.displayName?.toString().toLowerCase() ?? '';
          final roleId = role.id?.toString().toLowerCase() ?? '';

          if (roleName == 'admin' ||
              roleName == 'المدير' ||
              roleDisplayName.contains('المدير') ||
              roleDisplayName.contains('admin') ||
              roleId == 'admin') {
            return true;
          }
        }
      }
    }

    return false;
  }
}
