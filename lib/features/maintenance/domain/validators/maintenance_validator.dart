import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/maintenance_request_entity.dart';

/// مدقق بيانات طلبات الصيانة
// ignore: avoid_classes_with_only_static_members
class MaintenanceValidator {
  /// التحقق من صحة طلب الصيانة
  static Either<Failure, bool> validateMaintenanceRequest(
    MaintenanceRequestEntity request,
  ) {
    // التحقق من الحقول المطلوبة
    final requiredFieldsResult = _validateRequiredFields(request);
    if (requiredFieldsResult.isLeft()) return requiredFieldsResult;

    // التحقق من التواريخ
    final datesResult = _validateDates(request);
    if (datesResult.isLeft()) return datesResult;

    // التحقق من التكاليف
    final costsResult = _validateCosts(request);
    if (costsResult.isLeft()) return costsResult;

    // التحقق من طول النصوص
    final textLengthResult = _validateTextLengths(request);
    if (textLengthResult.isLeft()) return textLengthResult;

    // التحقق من القيم المسموحة
    final allowedValuesResult = _validateAllowedValues(request);
    if (allowedValuesResult.isLeft()) return allowedValuesResult;

    return const Right(true);
  }

  /// التحقق من الحقول المطلوبة
  static Either<Failure, bool> _validateRequiredFields(
    MaintenanceRequestEntity request,
  ) {
    if (request.title.isEmpty) {
      return const Left(ValidationFailure(message: 'عنوان طلب الصيانة مطلوب'));
    }

    if (request.description.isEmpty) {
      return const Left(ValidationFailure(message: 'وصف طلب الصيانة مطلوب'));
    }

    if (request.organizationEmail.isEmpty) {
      return const Left(ValidationFailure(message: 'بريد المؤسسة مطلوب'));
    }

    if (request.requestedBy.isEmpty) {
      return const Left(ValidationFailure(message: 'مقدم الطلب مطلوب'));
    }

    return const Right(true);
  }

  /// التحقق من التواريخ
  static Either<Failure, bool> _validateDates(
    MaintenanceRequestEntity request,
  ) {
    final now = DateTime.now();

    // التحقق من تاريخ الطلب
    if (request.requestDate.isAfter(now.add(const Duration(days: 1)))) {
      return const Left(
        ValidationFailure(
          message: 'تاريخ الطلب لا يمكن أن يكون بعد الغد بيوم واحد',
        ),
      );
    }

    // التحقق من تاريخ الجدولة
    if (request.scheduledDate != null) {
      if (request.scheduledDate!.isBefore(request.requestDate)) {
        return const Left(
          ValidationFailure(
            message: 'تاريخ الجدولة يجب أن يكون بعد تاريخ الطلب',
          ),
        );
      }

      // تحذير إذا كان التاريخ في الماضي
      if (request.scheduledDate!.isBefore(now) && request.status == 'pending') {
        return const Left(
          ValidationFailure(
            message: 'تاريخ الجدولة في الماضي، يرجى تحديث التاريخ أو الحالة',
          ),
        );
      }
    }

    // التحقق من تاريخ الإكمال
    if (request.completedDate != null) {
      if (request.scheduledDate != null &&
          request.completedDate!.isBefore(request.scheduledDate!)) {
        return const Left(
          ValidationFailure(
            message: 'تاريخ الإكمال يجب أن يكون بعد تاريخ الجدولة',
          ),
        );
      }

      if (request.completedDate!.isBefore(request.requestDate)) {
        return const Left(
          ValidationFailure(
            message: 'تاريخ الإكمال يجب أن يكون بعد تاريخ الطلب',
          ),
        );
      }

      // التحقق من تطابق الحالة مع تاريخ الإكمال
      if (request.status != 'completed') {
        return const Left(
          ValidationFailure(
            message: 'يجب تغيير الحالة إلى "مكتمل" عند وجود تاريخ إكمال',
          ),
        );
      }
    }

    return const Right(true);
  }

  /// التحقق من التكاليف
  static Either<Failure, bool> _validateCosts(
    MaintenanceRequestEntity request,
  ) {
    // التحقق من التكلفة المتوقعة
    if (request.estimatedCost != null) {
      if (request.estimatedCost! < 0) {
        return const Left(
          ValidationFailure(message: 'التكلفة المتوقعة لا يمكن أن تكون سالبة'),
        );
      }

      if (request.estimatedCost! > 1000000) {
        return const Left(
          ValidationFailure(
            message: 'التكلفة المتوقعة مرتفعة جداً، يرجى المراجعة',
          ),
        );
      }
    }

    // التحقق من التكلفة الفعلية
    if (request.actualCost != null) {
      if (request.actualCost! < 0) {
        return const Left(
          ValidationFailure(message: 'التكلفة الفعلية لا يمكن أن تكون سالبة'),
        );
      }

      if (request.actualCost! > 1000000) {
        return const Left(
          ValidationFailure(
            message: 'التكلفة الفعلية مرتفعة جداً، يرجى المراجعة',
          ),
        );
      }

      // تحذير إذا كانت التكلفة الفعلية أكبر بكثير من المتوقعة
      if (request.estimatedCost != null &&
          request.actualCost! > request.estimatedCost! * 2) {
        return const Left(
          ValidationFailure(
            message: 'التكلفة الفعلية أكبر بكثير من المتوقعة، يرجى المراجعة',
          ),
        );
      }
    }

    return const Right(true);
  }

  /// التحقق من طول النصوص
  static Either<Failure, bool> _validateTextLengths(
    MaintenanceRequestEntity request,
  ) {
    if (request.title.length > 100) {
      return const Left(
        ValidationFailure(
          message: 'عنوان طلب الصيانة طويل جداً (الحد الأقصى 100 حرف)',
        ),
      );
    }

    if (request.description.length > 1000) {
      return const Left(
        ValidationFailure(
          message: 'وصف طلب الصيانة طويل جداً (الحد الأقصى 1000 حرف)',
        ),
      );
    }

    if (request.equipmentName != null && request.equipmentName!.length > 100) {
      return const Left(
        ValidationFailure(
          message: 'اسم المعدة طويل جداً (الحد الأقصى 100 حرف)',
        ),
      );
    }

    if (request.location != null && request.location!.length > 200) {
      return const Left(
        ValidationFailure(message: 'الموقع طويل جداً (الحد الأقصى 200 حرف)'),
      );
    }

    if (request.notes != null && request.notes!.length > 500) {
      return const Left(
        ValidationFailure(
          message: 'الملاحظات طويلة جداً (الحد الأقصى 500 حرف)',
        ),
      );
    }

    return const Right(true);
  }

  /// التحقق من القيم المسموحة
  static Either<Failure, bool> _validateAllowedValues(
    MaintenanceRequestEntity request,
  ) {
    // التحقق من الأولوية
    const validPriorities = ['low', 'medium', 'high', 'urgent'];
    if (!validPriorities.contains(request.priority)) {
      return const Left(
        ValidationFailure(
          message:
              'أولوية غير صحيحة، القيم المسموحة: منخفضة، متوسطة، عالية، عاجلة',
        ),
      );
    }

    // التحقق من الحالة
    const validStatuses = ['pending', 'in_progress', 'completed', 'cancelled'];
    if (!validStatuses.contains(request.status)) {
      return const Left(
        ValidationFailure(
          message:
              'حالة غير صحيحة، القيم المسموحة: معلق، قيد التنفيذ، مكتمل، ملغي',
        ),
      );
    }

    // التحقق من صحة البريد الإلكتروني
    if (!_isValidEmail(request.organizationEmail)) {
      return const Left(ValidationFailure(message: 'بريد المؤسسة غير صحيح'));
    }

    if (!_isValidEmail(request.requestedBy)) {
      return const Left(ValidationFailure(message: 'بريد مقدم الطلب غير صحيح'));
    }

    if (request.assignedTo != null && !_isValidEmail(request.assignedTo!)) {
      return const Left(
        ValidationFailure(message: 'بريد المكلف بالصيانة غير صحيح'),
      );
    }

    return const Right(true);
  }

  /// التحقق من صحة البريد الإلكتروني
  static bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// التحقق من انتقالات الحالة
  static Either<Failure, bool> validateStatusTransition(
    String currentStatus,
    String newStatus,
  ) {
    // ============================================
    // ملاحظة للمبرمجين المستقبليين:
    // هذه الدالة للتحقق من صحة انتقالات الحالة.
    // ✅ تُستخدم فعلاً في updateMaintenanceRequest في
    // المستودع (داخل Transaction) لمنع انتقالات الحالة
    // غير الصحيحة — ويُستدعى التحقق فقط عندما تتغير
    // الحالة فعلاً (currentStatus != newStatus) لأن
    // الانتقال من حالة إلى نفسها ليس انتقالاً حقيقياً.
    //
    // ✅ مصدر الحقيقة الوحيد: MaintenanceRequestEntity.allowedTransitions.
    // لا تُعرّف القواعد هنا مباشرة لتجنب التكرار وعدم المزامنة.
    // ============================================
    final allowedTransitions = MaintenanceRequestEntity.allowedTransitions;

    final allowed = allowedTransitions[currentStatus] ?? [];
    if (!allowed.contains(newStatus)) {
      return Left(
        ValidationFailure(
          message: 'لا يمكن تغيير الحالة من $currentStatus إلى $newStatus',
        ),
      );
    }

    return const Right(true);
  }
}
