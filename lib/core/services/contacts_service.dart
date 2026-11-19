import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// معلومات جهة الاتصال المبسطة
@immutable
class ContactInfo {
  const ContactInfo({required this.name, this.phone, this.email});

  final String name;
  final String? phone;
  final String? email;

  @override
  String toString() {
    return 'ContactInfo(name: $name, phone: $phone, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactInfo &&
        other.name == name &&
        other.phone == phone &&
        other.email == email;
  }

  @override
  int get hashCode => name.hashCode ^ phone.hashCode ^ email.hashCode;
}

/// خدمة إدارة جهات الاتصال
// ignore: avoid_classes_with_only_static_members
class ContactsImportService {
  /// طلب إذن الوصول لجهات الاتصال
  static Future<bool> requestContactsPermission() async {
    try {
      // استخدام flutter_contacts للتحقق من الإذن
      final status = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );
      return status == PermissionStatus.granted ||
          status == PermissionStatus.limited;
    } on Exception catch (_) {
      return false;
    }
  }

  /// التحقق من حالة إذن جهات الاتصال
  static Future<bool> hasContactsPermission() async {
    try {
      await requestContactsPermission();
      final status = await FlutterContacts.permissions.check(
        PermissionType.readWrite,
      );
      return status == PermissionStatus.granted ||
          status == PermissionStatus.limited;
    } on Exception catch (_) {
      return false;
    }
  }

  /// جلب جميع جهات الاتصال
  static Future<List<ContactInfo>> getAllContacts() async {
    try {
      // التحقق من الإذن أولاً
      final hasPermission = await hasContactsPermission();
      if (!hasPermission) {
        final granted = await requestContactsPermission();
        if (!granted) {
          throw Exception('لم يتم منح إذن الوصول لجهات الاتصال');
        }
      }

      // جلب جهات الاتصال باستخدام flutter_contacts
      final contacts = await FlutterContacts.getAll(
        properties: {
          ContactProperty.name,
          ContactProperty.phone,
          ContactProperty.email,
        },
      );

      // تحويل جهات الاتصال إلى تنسيق مبسط
      final contactInfoList = <ContactInfo>[];

      for (final contact in contacts) {
        // تجاهل جهات الاتصال بدون اسم
        if ((contact.displayName ?? '').trim().isEmpty) {
          continue;
        }

        final name = contact.displayName!.trim();

        // جلب أول رقم هاتف متاح
        String? phone;
        if (contact.phones.isNotEmpty) {
          phone = contact.phones.first.number.replaceAll(RegExp(r'[^\d+]'), '');
          // تنظيف رقم الهاتف من المسافات والرموز
          if (phone.isNotEmpty) {
            phone = phone
                .replaceAll(' ', '')
                .replaceAll('-', '')
                .replaceAll('(', '')
                .replaceAll(')', '');
          } else {
            phone = null;
          }
        }

        // جلب أول بريد إلكتروني متاح
        String? email;
        if (contact.emails.isNotEmpty) {
          email = contact.emails.first.address.trim();
          // التحقق من صحة البريد الإلكتروني
          if (!_isValidEmail(email)) {
            email = null;
          }
        }

        // إضافة جهة الاتصال فقط إذا كان لديها اسم وعلى الأقل رقم هاتف أو بريد إلكتروني
        if ((phone != null && phone.isNotEmpty) ||
            (email != null && email.isNotEmpty)) {
          contactInfoList.add(
            ContactInfo(name: name, phone: phone, email: email),
          );
        }
      }

      // ترتيب جهات الاتصال أبجدياً
      contactInfoList.sort((a, b) => a.name.compareTo(b.name));

      return contactInfoList;
    } on Exception catch (_) {
      rethrow;
    }
  }

  /// البحث في جهات الاتصال
  static Future<List<ContactInfo>> searchContacts(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final allContacts = await getAllContacts();
      final searchQuery = query.toLowerCase().trim();

      return allContacts.where((contact) {
        final name = contact.name.toLowerCase();
        final phone = contact.phone?.toLowerCase() ?? '';
        final email = contact.email?.toLowerCase() ?? '';

        return name.contains(searchQuery) ||
            phone.contains(searchQuery) ||
            email.contains(searchQuery);
      }).toList();
    } on Exception catch (_) {
      return [];
    }
  }

  /// اختبار الوصول لجهات الاتصال مع تفاصيل الأخطاء
  static Future<Map<String, dynamic>> testContactsAccess() async {
    final result = <String, dynamic>{
      'success': false,
      'error': null,
      'permissionStatus': null,
      'contactsCount': 0,
      'details': <String>[],
    };

    try {
      result['details'].add('بدء اختبار الوصول لجهات الاتصال...');

      // التحقق من توفر المنصة
      if (!isContactsServiceAvailable()) {
        result['error'] = 'المنصة غير مدعومة';
        result['details'].add('المنصة الحالية غير مدعومة لجهات الاتصال');
        return result;
      }
      result['details'].add('المنصة مدعومة ✓');

      // التحقق من حالة الإذن
      final status = await FlutterContacts.permissions.check(
        PermissionType.readWrite,
      );
      var hasPermission =
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited;
      result['permissionStatus'] = status.name;
      result['details'].add('حالة الإذن: ${status.name}');

      if (!hasPermission) {
        result['details'].add('محاولة طلب الإذن...');
        final requestResult = await requestContactsPermission();
        result['details'].add('نتيجة طلب الإذن: $requestResult');

        if (!requestResult) {
          result['error'] = 'لم يتم منح الإذن';
          result['details'].add('فشل في الحصول على الإذن');
          return result;
        }
      }
      result['details'].add('الإذن ممنوح ✓');

      // محاولة جلب جهات الاتصال
      result['details'].add('محاولة جلب جهات الاتصال...');
      final contacts = await FlutterContacts.getAll(
        properties: {
          ContactProperty.name,
          ContactProperty.phone,
          ContactProperty.email,
        },
      );
      result['contactsCount'] = contacts.length;
      result['details'].add('تم جلب ${contacts.length} جهة اتصال ✓');

      // معالجة جهات الاتصال
      var validContacts = 0;
      for (final contact in contacts) {
        if ((contact.displayName ?? '').trim().isNotEmpty &&
            (contact.phones.isNotEmpty || contact.emails.isNotEmpty)) {
          validContacts++;
        }
      }

      result['details'].add('عدد جهات الاتصال الصالحة: $validContacts');
      result['success'] = true;
    } on Exception catch (e) {
      result['error'] = e.toString();
      result['details'].add('خطأ: $e');
    }

    return result;
  }

  /// التحقق من صحة البريد الإلكتروني
  static bool _isValidEmail(String email) {
    return RegExp(
      r'^[\w\-\.\u0600-\u06FF]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(email);
  }

  /// التحقق من توفر خدمة جهات الاتصال على المنصة
  static bool isContactsServiceAvailable() {
    return Platform.isAndroid || Platform.isIOS;
  }
}
