import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/retry_helper.dart';
import '../../core/permissions/permissions_initializer.dart';
import '../../core/services/formatting_service.dart';
import '../../core/services/pdf/pdf_settings_service.dart';
import '../../core/services/role_request_settings_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/subscription_notification_service.dart';
import '../../core/services/notification_foreground_service.dart';
import '../../core/services/one_signal_notification_service.dart';
import '../../features/auth/auth_injection.dart';
import '../../features/customers/injection_container.dart';
import '../../features/invoices/injection_container.dart';
import '../../features/subscriptions/injection_container.dart';
import '../../features/users/users_injection.dart';
import '../../firebase_options.dart';

final sl = GetIt.instance;

/// تهيئة التطبيق
// ignore: avoid_classes_with_only_static_members
class AppInitializer {
  static Completer<void>? _initCompleter;

  /// تهيئة التطبيق الكاملة فائقة السرعة
  static Future<void> initialize() async {
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      await Hive.initFlutter();
      await Future.wait([SessionService.initialize(), _initFirebaseCore()]);
      _initFirebaseServicesSync();
      _initCoreDependencies();
      PermissionsInitializer.initialize();
      SettingsService.initialize();
      await Future.wait([
        AuthInjection.init(),
        initUsersInjection(),
        initInvoices(),
        initCustomers(),
        initSubscriptionDependencies(),
      ]);

      _initCompleter!.complete();
    } on Exception catch (e) {
      _initCompleter!.completeError(e);
    }

    return _initCompleter!.future;
  }

  /// التحقق من انتهاء التهيئة
  static bool get isInitialized =>
      _initCompleter != null && _initCompleter!.isCompleted;

  /// انتظار انتهاء التهيئة إن كانت جارية
  static Future<void> ensureInitialized() async {
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }
  }

  /// تهيئة Firebase Core فقط
  static Future<void> _initFirebaseCore() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (_) {
      // تم التهيئة مسبقاً، تجاهل الخطأ
    }
  }

  /// تهيئة خدمة التنسيق
  static Future<void> _initFormattingService() async {
    final formattingService = FormattingService();
    await formattingService.initialize();
    if (!sl.isRegistered<FormattingService>()) {
      sl.registerSingleton<FormattingService>(formattingService);
    }
  }

  /// تشغيل الخدمات غير الحرجة في الخلفية بعد انتهاء التهيئة الأساسية
  static Future<void> initializeBackground() async {
    try {
      await Future.wait([
        _initFormattingService(),
        RoleRequestSettingsService.initialize(),
        _initFirebaseAppCheck(),
        OneSignalNotificationService.initialize(),
        NotificationForegroundService.initialize(),
      ]);
    } on Exception catch (_) {
      // تهيئة الخدمات الخلفية اختيارية ولا توقف تشغيل التطبيق.
    }
  }

  /// إعادة تعيين علامات فحص الإشعارات عند بدء التطبيق
  // ✅ تم إزالة استدعاء resetSessionCheck() لأن قفل الجلسة أُزل من
  // SubscriptionNotificationService — الإشعارات تُفحص الآن في كل مرة دون قفل.
  static void resetNotificationChecks() {
    // لا حاجة لإجراء أي إجراء هنا — القفل أُزيل.
  }

  /// تهيئة Firebase App Check في الخلفية
  static Future<void> _initFirebaseAppCheck() async {
    try {
      if (kDebugMode) {
        return;
      }

      if (Platform.isAndroid) {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: const AndroidPlayIntegrityProvider(),
        );
      } else if (Platform.isIOS) {
        await FirebaseAppCheck.instance.activate(
          providerApple: const AppleDeviceCheckProvider(),
        );
      } else {
        await FirebaseAppCheck.instance.activate();
      }
    } on FirebaseException catch (_) {
      // سيستمر التطبيق حتى إذا تعذر تفعيل App Check.
    } on Exception catch (_) {
      // سيستمر التطبيق حتى إذا تعذر تفعيل App Check.
    }
  }

  /// تهيئة وتوزيع خدمات Firebase المشتركة بشكل فوري
  static void _initFirebaseServicesSync() {
    if (!sl.isRegistered<FirebaseFirestore>()) {
      final firestore = FirebaseFirestore.instance;
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      sl.registerLazySingleton<FirebaseFirestore>(() => firestore);
    }

    if (!sl.isRegistered<FirebaseAuth>()) {
      final auth = FirebaseAuth.instance;
      if (kIsWeb) {
        unawaited(auth.setPersistence(Persistence.LOCAL));
      }
      sl.registerLazySingleton<FirebaseAuth>(() => auth);
    }
  }

  /// تهيئة التبعيات الأساسية
  static Future<void> _initCoreDependencies() async {
    // تسجيل خدمة إعدادات PDF
    if (!sl.isRegistered<PdfSettingsService>()) {
      sl.registerLazySingleton<PdfSettingsService>(PdfSettingsService.new);
    }
  }
}
