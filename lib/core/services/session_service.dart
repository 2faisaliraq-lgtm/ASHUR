import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/users/domain/entities/user_management_entity.dart';

/// خدمة إدارة الجلسة وتبديل الأدوار مع Stream للتحديث الفوري
class SessionService {
  static const String _boxName = 'session_box';
  static const String _currentUserKey = 'current_switched_user';
  static const String _persistentRoleKey = 'persistent_role_session';

  static Box? _box;

  // متغير في الذاكرة للاحتفاظ بالبيانات
  static Map<String, dynamic>? _cachedUserData;

  // StreamController لبث تغييرات المستخدم المبدل
  static StreamController<Map<String, dynamic>?>? _switchedUserController;

  static StreamController<Map<String, dynamic>?> get _controller {
    _switchedUserController ??=
        StreamController<Map<String, dynamic>?>.broadcast();
    return _switchedUserController!;
  }

  /// Stream لتغييرات المستخدم المبدل - يُحدّث عند أي تغيير
  static Stream<Map<String, dynamic>?> get switchedUserStream =>
      _controller.stream;

  /// تهيئة الخدمة
  static Future<void> initialize() async {
    _switchedUserController ??=
        StreamController<Map<String, dynamic>?>.broadcast();
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
  }

  /// حفظ المستخدم المبدل إليه بشكل دائم
  static Future<void> setSwitchedUser(UserManagementEntity user) async {
    await initialize();

    final firebaseUser = FirebaseAuth.instance.currentUser;

    final userData = {
      'id': user.id,
      'email': user.email,
      'name': user.name,
      'accessCode': user.roleCode,
      'customPermissions': user.customPermissions, // ✅ الصلاحيات المخصصة
      'roles': user.roles
          .map(
            (role) => {
              'id': role.id,
              'name': role.name,
              'displayName': role.displayName,
              'permissions': role.permissions,
            },
          )
          .toList(),
      'switchedAt': DateTime.now().toIso8601String(),
    };

    _cachedUserData = userData;
    await _box!.put(_currentUserKey, userData);
    await _box!.put(_persistentRoleKey, userData);

    // بث التغيير للـ Stream
    _broadcastSwitchedUserChange(userData);
  }

  /// الحصول على المستخدم المبدل إليه
  static Future<Map<String, dynamic>?> getSwitchedUser() async {
    await initialize();

    // التحقق من الذاكرة أولاً
    if (_cachedUserData != null) {
      return _cachedUserData;
    }

    // محاولة الحصول على الجلسة الحالية أولاً
    var userData = _box!.get(_currentUserKey);

    // إذا لم توجد، محاولة الحصول على الجلسة الدائمة
    if (userData == null) {
      userData = _box!.get(_persistentRoleKey);

      // إذا وجدت جلسة دائمة، استعادتها كجلسة حالية
      if (userData != null) {
        await _box!.put(_currentUserKey, userData);
        await _box!.flush();
      }
    }

    // تحويل البيانات إلى النوع الصحيح
    if (userData != null && userData is Map) {
      final convertedData = Map<String, dynamic>.from(userData);
      _cachedUserData = convertedData; // حفظ في الذاكرة
      return convertedData;
    }

    return null;
  }

  /// التحقق من وجود مستخدم مبدل
  static Future<bool> hasSwitchedUser() async {
    await initialize();

    if (_box!.containsKey(_currentUserKey)) {
      final userData = _box!.get(_currentUserKey);
      if (userData != null && userData is Map && _isValidUserData(userData)) {
        return true;
      }
    }

    if (_box!.containsKey(_persistentRoleKey)) {
      final userData = _box!.get(_persistentRoleKey);
      if (userData != null && userData is Map && _isValidUserData(userData)) {
        await _box!.put(_currentUserKey, userData);
        await _box!.flush();
        return true;
      }
    }

    return false;
  }

  /// التحقق من صحة بيانات المستخدم
  static bool _isValidUserData(Map userData) {
    try {
      // تحويل البيانات إلى النوع الصحيح أولاً
      final convertedData = Map<String, dynamic>.from(userData);

      return convertedData.containsKey('id') &&
          convertedData.containsKey('email') &&
          convertedData.containsKey('roles') &&
          convertedData['roles'] is List &&
          (convertedData['roles'] as List).isNotEmpty;
    } on Exception catch (_) {
      return false;
    }
  }

  /// إلغاء المستخدم المبدل (مسح الجلسة الحالية فقط)
  static Future<void> clearSwitchedUser() async {
    await initialize();
    await _box!.delete(_currentUserKey);
    _cachedUserData = null;
    // الاحتفاظ بالجلسة الدائمة

    // بث التغيير للـ Stream
    _broadcastSwitchedUserChange(null);
  }

  /// إلغاء المستخدم نهائياً (يحذف جميع الجلسات)
  static Future<void> clearRolePermanently() async {
    await initialize();
    await _box!.delete(_currentUserKey);
    await _box!.delete(_persistentRoleKey);
    await _box!.flush();
    _cachedUserData = null;

    // بث التغيير للـ Stream
    _broadcastSwitchedUserChange(null);
  }

  /// تنظيف جميع بيانات الجلسة
  static Future<void> clearAll() async {
    await initialize();
    _cachedUserData = null; // مسح البيانات من الذاكرة
    await _box!.delete(_currentUserKey);
    await _box!.delete(_persistentRoleKey);

    // بث التغيير للـ Stream
    _broadcastSwitchedUserChange(null);
  }

  /// الحصول على معلومات الجلسة الدائمة
  static Future<Map<String, dynamic>?> getPersistentRole() async {
    await initialize();

    final userData = _box!.get(_persistentRoleKey);

    if (userData != null) {
      // تحويل Map<dynamic, dynamic> إلى Map<String, dynamic>
      if (userData is Map) {
        final convertedData = Map<String, dynamic>.from(userData);
        return convertedData;
      }
    }

    return null;
  }

  /// التحقق من وجود جلسة دائمة
  static Future<bool> hasPersistentRole() async {
    await initialize();

    final userData = _box!.get(_persistentRoleKey);
    final isValid =
        userData != null && userData is Map && _isValidUserData(userData);

    return isValid;
  }

  /// بث تغيير المستخدم المبدل
  static void _broadcastSwitchedUserChange(Map<String, dynamic>? userData) {
    if (_switchedUserController != null && !_switchedUserController!.isClosed) {
      _switchedUserController!.add(userData);
    }
  }

  /// تحديث بيانات المستخدم المبدل (يُستخدم عند تحميل additionalPermissions من Firestore)
  static Future<void> setSwitchedUserFromData(
    Map<String, dynamic> userData,
  ) async {
    await initialize();

    _cachedUserData = userData;
    await _box!.put(_currentUserKey, userData);
    await _box!.put(_persistentRoleKey, userData);

    // بث التغيير للـ Stream
    _broadcastSwitchedUserChange(userData);
  }

  /// الاستماع لتغييرات المستخدم المبدل
  static StreamSubscription<Map<String, dynamic>?> listenToSwitchedUserChanges(
    Function(Map<String, dynamic>?) onData,
  ) {
    return switchedUserStream.listen(onData);
  }

  /// إيقاف الـ Stream وتنظيف الموارد
  static void dispose() {
    if (_switchedUserController != null && !_switchedUserController!.isClosed) {
      _switchedUserController!.close();
    }
    _switchedUserController = null;
  }
}
