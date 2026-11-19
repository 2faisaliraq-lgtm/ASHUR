import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/setting_entity.dart';
import '../../domain/repositories/setting_repository.dart';
import '../models/setting_model.dart';

class SettingRepositoryImpl implements SettingRepository {
  SettingRepositoryImpl({required this.firestore});
  final FirebaseFirestore firestore;
  final _emailService = EmailNormalizationService();

  /// إنشاء معرف قصير وقابل للقراءة
  String _generateShortId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final shortTimestamp = timestamp.toString().substring(8); // آخر 5 أرقام
    return '$prefix$shortTimestamp';
  }

  /// الحصول على مرجع مجموعة الإعدادات للمؤسسة
  CollectionReference _getSettingsCollection(String organizationEmail) {
    final normalizedEmail = _emailService.normalize(organizationEmail);
    return firestore
        .collection(normalizedEmail)
        .doc('settings')
        .collection('settings');
  }

  @override
  Future<Either<Failure, List<SettingEntity>>> getSettings(
    String organizationEmail,
  ) async {
    try {
      final snapshot = await _getSettingsCollection(organizationEmail).get();

      final settings = <SettingEntity>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) continue;
          final mapData = data as Map<String, dynamic>;
          // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
          if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
            mapData['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
          }
          final setting = SettingModel.fromJson(mapData);
          settings.add(setting);
        } on Exception {
          // تجاهل المستندات التي فشل تحويلها
        }
      }

      // ترتيب الإعدادات حسب الفئة ثم المفتاح
      settings.sort((a, b) {
        final categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) return categoryCompare;
        return a.key.compareTo(b.key);
      });

      return Right(settings);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, SettingEntity>> createSetting(
    SettingEntity setting,
  ) async {
    try {
      final settingModel = SettingModel.fromEntity(setting);

      // إنشاء ID قصير وقابل للقراءة
      final settingId = _generateShortId('ST'); // ST = Setting

      final data = settingModel.toJson();
      data['id'] = settingId;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _getSettingsCollection(
        setting.organizationEmail,
      ).doc(settingId).set(data);

      final updatedSetting = settingModel.copyWith(
        id: settingId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return Right(updatedSetting);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, SettingEntity>> updateSetting(
    SettingEntity setting,
  ) async {
    try {
      final settingModel = SettingModel.fromEntity(setting);
      final docRef = _getSettingsCollection(
        setting.organizationEmail,
      ).doc(setting.id);

      final data = settingModel.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.update(data);

      final updatedSetting = settingModel.copyWith(updatedAt: DateTime.now());

      return Right(updatedSetting);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSetting(
    String organizationEmail,
    String settingId,
  ) async {
    try {
      await _getSettingsCollection(organizationEmail).doc(settingId).delete();

      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, SettingEntity?>> getSettingByKey(
    String organizationEmail,
    String key,
  ) async {
    try {
      final snapshot = await _getSettingsCollection(
        organizationEmail,
      ).where('key', isEqualTo: key).limit(1).get();

      if (snapshot.docs.isEmpty) {
        return const Right(null);
      }

      final data = snapshot.docs.first.data()! as Map<String, dynamic>;
      data['id'] = snapshot.docs.first.id;
      final setting = SettingModel.fromJson(data);

      return Right(setting);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, List<SettingEntity>>> getSettingsByCategory(
    String organizationEmail,
    String category,
  ) async {
    try {
      final snapshot = await _getSettingsCollection(
        organizationEmail,
      ).where('category', isEqualTo: category).get();

      final settings = <SettingEntity>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          if (data == null) continue;
          final mapData = data as Map<String, dynamic>;
          // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
          if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
            mapData['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
          }
          final setting = SettingModel.fromJson(mapData);
          settings.add(setting);
        } on Exception {
          // تجاهل المستندات التي فشل تحويلها
        }
      }

      // ترتيب الإعدادات حسب المفتاح
      settings.sort((a, b) => a.key.compareTo(b.key));

      return Right(settings);
    } on Exception catch (e) {
      return Left(ServerFailure(message: _readableError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> initializeDefaultSettings(
    String organizationEmail,
  ) async {
    // لا نحتاج لإنشاء إعدادات افتراضية
    // سيتم إنشاء الإعدادات عند الحاجة من خلال واجهة المستخدم
    return const Right(null);
  }

  // ===== Stream Methods for Real-time Updates =====

  @override
  Stream<Either<Failure, List<SettingEntity>>> getSettingsStream(
    String organizationEmail, {
    int? limit,
  }) {
    try {
      var query = _getSettingsCollection(
        organizationEmail,
      ).orderBy('createdAt', descending: true);

      if (limit != null) query = query.limit(limit);

      return query.snapshots().map((snapshot) {
        try {
          final settings = <SettingEntity>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              if (data == null) continue;
              final mapData = data as Map<String, dynamic>;
              // استخدام المعرف المحفوظ في البيانات بدلاً من doc.id
              if (mapData['id'] == null || mapData['id'].toString().isEmpty) {
                mapData['id'] = doc.id; // فقط إذا لم يكن هناك معرف محفوظ
              }

              // التحقق من الحد قبل الإضافة
              if (limit != null && settings.length >= limit) {
                break;
              }

              final setting = SettingModel.fromJson(data);
              settings.add(setting);
            } on Exception {
              // تجاهل المستندات التي فشل تحويلها
            }
          }

          // التأكد من عدم تجاوز الحد (حماية إضافية)
          if (limit != null && settings.length > limit) {
            return Right<Failure, List<SettingEntity>>(
              settings.sublist(0, limit),
            );
          }

          return Right<Failure, List<SettingEntity>>(settings);
        } on Exception catch (e) {
          return Left<Failure, List<SettingEntity>>(
            ServerFailure(message: 'فشل في معالجة بيانات الإعدادات: $e'),
          );
        }
      });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب الإعدادات: $e')),
      );
    }
  }

  @override
  Stream<Either<Failure, Map<String, int>>> getSettingsStatsStream(
    String organizationEmail,
  ) {
    try {
      return _getSettingsCollection(organizationEmail).snapshots().map((
        snapshot,
      ) {
        try {
          // ✅ تحسين (2026-10-12): حساب
          // الإحصائيات مباشرة من بيانات
          // المستند الخام بدلاً من بناء
          // SettingModel كامل لكل إعداد —
          // الإحصائيات تحتاج 3 حقول فقط
          // (category، type، value) فبناء
          // النموذج كامل كان يهدر وقت
          // المعالج مع كثرة الإعدادات عند
          // كل لقطة. منطق الحساب مطابق
          // تماماً للسابق (value == 'true'
          // — وtrue.toString() هي 'true'
          // أيضاً فالشرط الأصلي المزدوج
          // يكافئه).
          var total = 0;
          var general = 0;
          var security = 0;
          var notifications = 0;
          var appearance = 0;
          var system = 0;
          var privacy = 0;
          var backup = 0;
          var integration = 0;
          var booleanSettings = 0;
          var enabledSettings = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data == null) continue;
            final mapData = data as Map<String, dynamic>;

            final category =
                mapData['category']?.toString() ??
                'general';
            final type =
                mapData['type']?.toString() ??
                'string';
            final value =
                mapData['value']?.toString() ?? '';

            total++;
            switch (category) {
              case 'general':
                general++;
                break;
              case 'security':
                security++;
                break;
              case 'notifications':
                notifications++;
                break;
              case 'appearance':
                appearance++;
                break;
              case 'system':
                system++;
                break;
              case 'privacy':
                privacy++;
                break;
              case 'backup':
                backup++;
                break;
              case 'integration':
                integration++;
                break;
            }
            if (type == 'boolean') {
              booleanSettings++;
              if (value == 'true') {
                enabledSettings++;
              }
            }
          }

          // حساب الإحصائيات
          final stats = <String, int>{
            'total': total,
            'general': general,
            'security': security,
            'notifications': notifications,
            'appearance': appearance,
            'system': system,
            'privacy': privacy,
            'backup': backup,
            'integration': integration,
          };

          stats['enabled'] = enabledSettings;
          stats['disabled'] =
              booleanSettings - enabledSettings;

          return Right<Failure, Map<String, int>>(stats);
        } on Exception catch (e) {
          return Left<Failure, Map<String, int>>(
            ServerFailure(message: 'فشل في حساب إحصائيات الإعدادات: ${_readableError(e)}'),
          );
        }
      });
    } on Exception catch (e) {
      return Stream.value(
        Left(ServerFailure(message: 'فشل في جلب إحصائيات الإعدادات: ${_readableError(e)}')),
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
