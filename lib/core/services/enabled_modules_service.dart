import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../email/email_normalization_service.dart';

/// خدمة إدارة الأقسام المفعلة
class EnabledModulesService {
  factory EnabledModulesService() => _instance;
  EnabledModulesService._internal();

  static final EnabledModulesService _instance =
      EnabledModulesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _emailService = EmailNormalizationService();

  // Cache
  Map<String, bool>? _cachedModules;
  String? _cachedOrgEmail;

  /// الأقسام الأساسية التي لا يمكن إيقافها
  static const List<String> coreModules = [
    'dashboard_view',
    'users_view',
    'settings_view',
  ];

  /// جميع الأقسام المتاحة
  static const Map<String, String> availableModules = {
    'dashboard_view': 'لوحة التحكم',
    'users_view': 'المستخدمين',
    'customers_view': 'العملاء',
    'inventory_view': 'المخزون',
    'subscriptions_view': 'الاشتراكات',
    'maintenance_view': 'الصيانة',
    'rentals_view': 'الإيجارات',
    'invoices_sales_manage': 'فواتير المبيعات',
    'invoices_purchase_manage': 'فواتير المشتريات',
    'invoices_cash_manage': 'الفواتير النقدية',
    'invoices_subscription_manage': 'فواتير الاشتراكات',
    'invoices_sales_return_manage': 'فواتير مرجع البيع',
    'expenses_view': 'المصروفات',
    'reports_view': 'التقارير',
    'settings_view': 'الإعدادات',
  };

  /// الحصول على حالة الأقسام المفعلة
  Future<Map<String, bool>> getEnabledModules() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        return _getDefaultModules();
      }

      final orgEmail = _emailService.normalize(user!.email!);

      // استخدام cache
      if (_cachedModules != null && _cachedOrgEmail == orgEmail) {
        return _cachedModules!;
      }

      // جلب من Firestore
      final doc = await _firestore
          .collection(orgEmail)
          .doc('settings')
          .collection('app_settings')
          .doc('enabled_modules')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data == null) return <String, bool>{};
        final modules = Map<String, bool>.from(data['modules'] ?? {});

        // تحويل الصلاحيات القديمة إلى الجديدة تلقائيًا
        // ⚠️ ملاحظة للمبرمجين المستقبليين: هذه عملية ترحيل أحادية."
        // بعد الترحيل الأول، يتم إزالة المفتاح القديم 'invoices_view' لذا
        // لا يتم الكتبة إلى Firestore إلا مرة واحدة فقط.
        bool needsUpdate = false;
        if (modules.containsKey('invoices_view')) {
          modules.remove('invoices_view');
          modules['invoices_sales_manage'] = true;
          modules['invoices_purchase_manage'] = true;
          modules['invoices_cash_manage'] = true;
          modules['invoices_subscription_manage'] = true;
          modules['invoices_sales_return_manage'] = true;
          needsUpdate = true;
        }

        // حفظ التحديثات إذا لزم الأمر (مرة واحدة فقط أثناء الترحيل)
        if (needsUpdate) {
          await _firestore
              .collection(orgEmail)
              .doc('settings')
              .collection('app_settings')
              .doc('enabled_modules')
              .update({'modules': modules});
        }

        // التأكد من وجود الأقسام الأساسية
        for (final core in coreModules) {
          modules[core] = true;
        }

        _cachedModules = modules;
        _cachedOrgEmail = orgEmail;
        return modules;
      }

      // افتراضياً جميع الأقسام مفعلة
      final defaultModules = _getDefaultModules();
      _cachedModules = defaultModules;
      _cachedOrgEmail = orgEmail;
      return defaultModules;
    } on Exception catch (_) {
      return _getDefaultModules();
    }
  }

  /// الحصول على الأقسام الافتراضية (كلها مفعلة)
  Map<String, bool> _getDefaultModules() {
    return Map.fromEntries(
      availableModules.keys.map((key) => MapEntry(key, true)),
    );
  }

  /// الحصول على الأقسام الافتراضية (public method)
  Map<String, bool> getDefaultModules() {
    return _getDefaultModules();
  }

  /// حفظ حالة الأقسام
  Future<bool> saveEnabledModules(Map<String, bool> modules) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return false;

      // تطبيع البريد الإلكتروني
      final orgEmail = _emailService.normalize(user!.email!);

      // التأكد من تفعيل الأقسام الأساسية
      for (final core in coreModules) {
        modules[core] = true;
      }

      await _firestore
          .collection(orgEmail)
          .doc('settings')
          .collection('app_settings')
          .doc('enabled_modules')
          .set({
            'modules': modules,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': user.email,
          });

      _cachedModules = modules;
      _cachedOrgEmail = orgEmail;

      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  /// التحقق من تفعيل قسم معين
  Future<bool> isModuleEnabled(String moduleId) async {
    final modules = await getEnabledModules();
    return modules[moduleId] ?? false;
  }

  /// مسح الـ cache
  void clearCache() {
    _cachedModules = null;
    _cachedOrgEmail = null;
  }
}
