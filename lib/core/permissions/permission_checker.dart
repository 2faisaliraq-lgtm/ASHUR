import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../email/email_normalization_service.dart';
import '../services/session_service.dart';

/// خدمة للتحقق من صلاحيات المستخدم الحالي مع تحديث فوري عبر Stream
class PermissionChecker {
  factory PermissionChecker() => _instance;
  PermissionChecker._internal();
  static final PermissionChecker _instance = PermissionChecker._internal();

  // خدمة تطبيع البريد
  final _emailService = EmailNormalizationService();

  // StreamController لبث تغييرات الصلاحيات
  final _permissionsController = StreamController<List<String>>.broadcast();

  /// Stream لصلاحيات المستخدم - يُحدّث تلقائياً عند أي تغيير
  Stream<List<String>> get permissionsStream => _permissionsController.stream;

  // الصلاحيات الحالية
  List<String> _currentPermissions = [];

  // Timer للـ polling (اختياري - للتحديث الدوري)
  Timer? _pollingTimer;
  static const _pollingInterval = Duration(
    seconds: 30,
  ); // تحديث كل 30 ثانية لتقليل الاستعلامات غير الضرورية

  // StreamSubscription للاستماع لتغييرات المستخدم المبدل
  StreamSubscription? _switchedUserSubscription;

  // StreamSubscription للاستماع لتغييرات المستخدم في Firestore
  StreamSubscription? _firestoreSubscription;

  /// تهيئة الخدمة والبدء في الاستماع للتغييرات
  Future<void> initialize() async {
    await _startListeningToChanges();
  }

  /// البدء في الاستماع للتغييرات
  Future<void> _startListeningToChanges() async {
    // تحميل أولي
    await _loadPermissions();

    // الاستماع لتغييرات المستخدم المبدل
    _listenToSwitchedUserChanges();

    // الاستماع لتغييرات المستخدم في Firestore
    _listenToFirestoreChanges();

    // بدء polling للتحقق من التغييرات (اختياري)
    _startPolling();
  }

  /// الاستماع لتغييرات المستخدم المبدل
  void _listenToSwitchedUserChanges() {
    _switchedUserSubscription = SessionService.switchedUserStream.listen((_) {
      _loadPermissions();
    });
  }

  /// الاستماع لتغييرات المستخدم في Firestore
  void _listenToFirestoreChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // التحقق من وجود مستخدم مبدل أولاً
    final hasSwitchedUser = await SessionService.hasSwitchedUser();

    String? userId;
    String? organizationId;

    if (hasSwitchedUser) {
      // استخدام بيانات المستخدم المبدل
      final switchedUserData = await SessionService.getSwitchedUser();
      if (switchedUserData != null) {
        userId = switchedUserData['id'] as String?;
        // نستخدم البريد الإلكتروني للمستخدم الأصلي كـ organizationId
        organizationId = _emailService.normalize(user.email!);
      }
    } else {
      // استخدام المستخدم الأصلي
      if (user.email == null) return;
      userId = user.uid;
      organizationId = _emailService.normalize(user.email!);
    }

    if (userId == null || organizationId == null) return;

    // الاستماع لتغييرات وثيقة المستخدم
    _firestoreSubscription = FirebaseFirestore.instance
        .collection(organizationId)
        .doc('users')
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            _loadPermissions();
          }
        });
  }

  /// بدء التحقق الدوري من التغييرات
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      await _loadPermissions();
    });
  }

  /// إيقاف الـ polling
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// تحميل الصلاحيات وبثها للـ Stream
  Future<List<String>> _loadPermissions() async {
    final permissions = <String>[];

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.email == null) {
        _updatePermissions(permissions);
        return permissions;
      }

      // تطبيع البريد الإلكتروني
      final organizationId = _emailService.normalize(user.email!);
      final firestore = FirebaseFirestore.instance;

      // التحقق من وجود مستخدم مبدل أولاً
      final hasSwitchedUser = await SessionService.hasSwitchedUser();

      if (hasSwitchedUser) {
        final switchedUserData = await SessionService.getSwitchedUser();
        if (switchedUserData != null && switchedUserData['roles'] != null) {
          final roles = switchedUserData['roles'] as List<dynamic>;

          // ✅ قراءة الصلاحيات المخصصة من Firestore مباشرة (مثل RoleSwitchDialog)
          final userId = switchedUserData['id'] as String;

          var customPermissions = <String>[];
          try {
            final userDoc = await firestore
                .collection(organizationId)
                .doc('users')
                .collection('users')
                .doc(userId)
                .get();

            if (userDoc.exists) {
              final userData = userDoc.data();
              customPermissions = List<String>.from(
                userData?['customPermissions'] ??
                    userData?['additionalPermissions'] ??
                    [],
              );
            }
          } on Exception catch (_) {
            // تجاهل الأخطاء والاستمرار
          }

          // ✅ استخدام الصلاحيات المخصصة إذا كانت موجودة
          // إذا كانت فارغة، نستخدم صلاحيات الدور (مثل شاشة تفاصيل المستخدم)
          if (customPermissions.isNotEmpty) {
            permissions.addAll(customPermissions);
          } else {
            // لا توجد صلاحيات مخصصة، نستخدم صلاحيات الأدوار
            for (final role in roles) {
              final rolePermissions = List<String>.from(
                role['permissions'] ?? [],
              );
              permissions.addAll(rolePermissions);
            }
          }

          // إزالة التكرار
          final uniquePermissions = permissions.toSet().toList();
          permissions.clear();
          permissions.addAll(uniquePermissions);
        }
      } else {
        // تحميل صلاحيات المستخدم الأصلي
        final userQuery = await firestore
            .collection(organizationId)
            .doc('users')
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          final userData = userDoc.data();

          // ✅ التحقق من وجود customPermissions
          final customPermissions = List<String>.from(
            userData['customPermissions'] ??
                userData['additionalPermissions'] ??
                [],
          );

          // إذا كانت هناك صلاحيات مخصصة، نستخدمها فقط
          if (customPermissions.isNotEmpty) {
            permissions.addAll(customPermissions);
          } else {
            // لا توجد صلاحيات مخصصة، نستخدم صلاحيات الأدوار
            final roleIds = List<String>.from(userData['roleIds'] ?? []);

            if (roleIds.isNotEmpty) {
              if (roleIds.length <= 10) {
                final rolesSnapshot = await firestore
                    .collection(organizationId)
                    .doc('users')
                    .collection('roles')
                    .get();

                for (final roleDoc in rolesSnapshot.docs) {
                  if (roleIds.contains(roleDoc.id)) {
                    final roleData = roleDoc.data();
                    final rolePermissions = List<String>.from(
                      roleData['permissions'] ?? [],
                    );
                    permissions.addAll(rolePermissions);
                  }
                }
              } else {
                // تقسيم معرّفات الأدوار إلى دفعات من 10 لأن Firestore يحد whereIn بـ 10 عناصر
                for (int i = 0; i < roleIds.length; i += 10) {
                  final batch = roleIds.sublist(i, min(i + 10, roleIds.length));
                  final rolesSnapshot = await firestore
                      .collection(organizationId)
                      .doc('users')
                      .collection('roles')
                      .where(FieldPath.documentId, whereIn: batch)
                      .get();

                  for (final roleDoc in rolesSnapshot.docs) {
                    final roleData = roleDoc.data();
                    final rolePermissions = List<String>.from(
                      roleData['permissions'] ?? [],
                    );
                    permissions.addAll(rolePermissions);
                  }
                }
              }
            }
          }
        }
      }

      // إزالة التكرار
      final uniquePermissions = permissions.toSet().toList();

      // بث التغييرات
      _updatePermissions(uniquePermissions);

      return uniquePermissions;
    } on Exception catch (_) {
      _updatePermissions(permissions);
      return permissions;
    }
  }

  /// تحديث الصلاحيات وبثها
  void _updatePermissions(List<String> newPermissions) {
    // التحقق من التغيير
    if (!_arePermissionsEqual(_currentPermissions, newPermissions)) {
      _currentPermissions = newPermissions;
      if (!_permissionsController.isClosed) {
        _permissionsController.add(newPermissions);
      }
    }
  }

  /// التحقق من تساوي قائمتي الصلاحيات
  bool _arePermissionsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.difference(setB).isEmpty && setB.difference(setA).isEmpty;
  }

  /// الحصول على صلاحيات المستخدم الحالي (للحفاظ على التوافق مع الكود القديم)
  Future<List<String>> getUserPermissions() async {
    // إذا كانت الصلاحيات محملة مسبقاً، نعود بها مباشرة
    if (_currentPermissions.isNotEmpty) {
      return _currentPermissions;
    }

    // ✅ ملاحظة للمبرمجين المستقبليين:
    // نضيف timeout لمنع البقاء في حالة تحميل لا نهائية.
    // السبب: _loadPermissions() تستدعي Firestore قد يتأخر.
    // إذا كان هناك خطأ في الشبكة أو Firestore، لن تكتمل العملية أبداً.
    // الحل: إضافة timeout ثانيتين ثم استخدام صلاحيات فارغة.
    try {
      return await _loadPermissions().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <String>[],
      );
    } on Exception catch (_) {
      return <String>[];
    }
  }

  /// تحميل مسبق للصلاحيات بشكل متزامن (للاستخدام في build لتجنب الانتظار)
  List<String> getCurrentPermissionsSync() {
    return List.from(_currentPermissions);
  }

  /// التحقق من وجود صلاحية محددة
  Future<bool> hasPermission(String permission) async {
    final permissions = await getUserPermissions();
    final hasPermission = permissions.contains(permission);
    return hasPermission;
  }

  /// التحقق من وجود أي صلاحية من قائمة
  Future<bool> hasAnyPermission(List<String> permissionList) async {
    final permissions = await getUserPermissions();
    final result = permissionList.any(permissions.contains);
    return result;
  }

  /// التحقق من وجود جميع الصلاحيات من قائمة
  Future<bool> hasAllPermissions(List<String> permissionList) async {
    final permissions = await getUserPermissions();
    final result = permissionList.every(permissions.contains);
    return result;
  }

  Future<Map<String, bool>> hasPermissions(List<String> permissionList) async {
    final permissions = await getUserPermissions();
    return {
      for (final permission in permissionList)
        permission: permissions.contains(permission),
    };
  }

  /// تحديث فوري للصلاحيات (يُستخدم عند تبديل المستخدم أو تغيير الصلاحيات)
  Future<void> refreshPermissions() async {
    await _loadPermissions();
  }

  /// تحديث الصلاحيات بعد تعديل مستخدم (يُستخدم في UsersBloc)
  void notifyPermissionsChanged() {
    _loadPermissions();
  }

  /// الاستماع لتغييرات الصلاحيات
  StreamSubscription<List<String>> listen(Function(List<String>) onData) {
    return permissionsStream.listen(onData);
  }

  /// إيقاف الخدمة وتنظيف الموارد
  void dispose() {
    _stopPolling();
    _switchedUserSubscription?.cancel();
    _firestoreSubscription?.cancel();
    _permissionsController.close();
    _currentPermissions = [];
  }

  /// مسح الكاش (للحفاظ على التوافق مع الكود القديم)
  Future<void> clearCache() async {
    _currentPermissions = [];
    // تحميل فوري بعد المسح
    await _loadPermissions();
  }
}
