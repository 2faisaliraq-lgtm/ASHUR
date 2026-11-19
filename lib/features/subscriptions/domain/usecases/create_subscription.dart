import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

/// حالة استخدام لإنشاء اشتراك جديد
class CreateSubscription {
  CreateSubscription(this.repository);
  final SubscriptionRepository repository;

  Future<Either<Failure, void>> call(
    SubscriptionEntity subscription,
    String type, {
    InvoiceEntity Function(SubscriptionEntity createdSubscription)?
        invoiceBuilder,
  }) async {
    final typedSubscription = subscription.copyWith(type: type);

    // التحقق من صحة البيانات

    final validationError = typedSubscription.validate();
    if (validationError != null) {
      return Left(ValidationFailure(message: validationError));
    }

    // التحقق من أن تاريخ النهاية محسوب بشكل صحيح

    final expectedEndDate = SubscriptionEntity.calculateEndDate(
      typedSubscription.startDate,
      typedSubscription.duration,
      typedSubscription.customDays,
    );

    // مقارنة التواريخ بدون الوقت
    final inputDateOnly = DateTime(
      typedSubscription.endDate.year,
      typedSubscription.endDate.month,
      typedSubscription.endDate.day,
    );
    final expectedDateOnly = DateTime(
      expectedEndDate.year,
      expectedEndDate.month,
      expectedEndDate.day,
    );

    if (inputDateOnly != expectedDateOnly) {
      return Left(
        ValidationFailure(
          message:
              'تاريخ النهاية غير صحيح. التاريخ المتوقع: ${expectedEndDate.toString().split(' ')[0]}',
        ),
      );
    }

    return repository.createSubscription(
      typedSubscription,
      invoiceBuilder: invoiceBuilder,
    );
  }
}

/// فشل في التحقق من صحة البيانات
class ValidationFailure extends Failure {
  const ValidationFailure({required String message}) : super(message);
}
