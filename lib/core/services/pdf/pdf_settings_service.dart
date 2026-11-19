import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/settings/domain/entities/pdf_settings_entity.dart';
import '../../email/email_normalization_service.dart';

/// خدمة إدارة إعدادات PDF
class PdfSettingsService {
  static const String _localStorageKey = 'pdf_settings';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _emailService = EmailNormalizationService();

  /// الحصول على الإعدادات
  ///
  /// يحاول الحصول على الإعدادات بالترتيب التالي:
  /// 1. من Firestore (إعدادات المنظمة)
  /// 2. من SharedPreferences (نسخة محلية)
  /// 3. إعدادات افتراضية
  Future<PdfSettingsEntity> getSettings(String organizationEmail) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // 1. محاولة الحصول على الإعدادات من Firestore
      // المسار: {organizationEmail}/settings/pdf_settings
      final doc = await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('pdf_settings')
          .doc('default')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data == null) return PdfSettingsEntity.defaultSettings();
        return PdfSettingsEntity.fromJson(Map<String, dynamic>.from(data));
      }

      // 2. محاولة الحصول على الإعدادات من SharedPreferences
      final localSettings = await _getFromLocalStorage();
      if (localSettings != null) {
        return localSettings;
      }

      // 3. إرجاع إعدادات افتراضية
      return PdfSettingsEntity.defaultSettings();
    } on Exception catch (_) {
      // خطأ في تحميل إعدادات PDF

      // محاولة الحصول من التخزين المحلي
      final localSettings = await _getFromLocalStorage();
      if (localSettings != null) {
        return localSettings;
      }

      // إرجاع إعدادات افتراضية
      return PdfSettingsEntity.defaultSettings();
    }
  }

  /// حفظ الإعدادات
  Future<void> saveSettings(
    PdfSettingsEntity settings,
    String organizationEmail,
  ) async {
    try {
      // تطبيع البريد الإلكتروني
      final normalizedEmail = _emailService.normalize(organizationEmail);

      // 1. حفظ في Firestore
      // المسار: {organizationEmail}/settings/pdf_settings/default
      await _firestore
          .collection(normalizedEmail)
          .doc('settings')
          .collection('pdf_settings')
          .doc('default')
          .set(settings.toJson());

      // 2. حفظ نسخة محلية
      await _saveToLocalStorage(settings);
    } on Exception catch (_) {
      // خطأ في حفظ إعدادات PDF
      rethrow;
    }
  }

  /// حفظ في التخزين المحلي
  Future<void> _saveToLocalStorage(PdfSettingsEntity settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(settings.toJson());
      await prefs.setString(_localStorageKey, jsonString);
    } on Exception catch (_) {
      // خطأ في حفظ الإعدادات محلياً
    }
  }

  /// الحصول من التخزين المحلي
  Future<PdfSettingsEntity?> _getFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_localStorageKey);

      if (jsonString != null) {
        final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
        return PdfSettingsEntity.fromJson(jsonMap);
      }

      return null;
    } on Exception catch (_) {
      // خطأ في قراءة الإعدادات محلياً
      return null;
    }
  }

  /// مسح الإعدادات المحلية
  Future<void> clearLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localStorageKey);
    } on Exception catch (_) {
      // خطأ في مسح الإعدادات المحلية
    }
  }

  /// Stream للإعدادات (للتحديث الفوري)
  Stream<PdfSettingsEntity> settingsStream(String organizationEmail) {
    // تطبيع البريد الإلكتروني
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return _firestore
        .collection(normalizedEmail)
        .doc('settings')
        .collection('pdf_settings')
        .doc('default')
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data();
            if (data == null) return PdfSettingsEntity.defaultSettings();
            return PdfSettingsEntity.fromJson(Map<String, dynamic>.from(data));
          }
          return PdfSettingsEntity.defaultSettings();
        });
  }
}
