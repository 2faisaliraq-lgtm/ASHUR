import '../entities/subscription_entity.dart';

/// فئة للتحقق من صحة بيانات الاشتراكات
// ignore: avoid_classes_with_only_static_members
class SubscriptionValidator {
  /// التحقق من صحة بيانات الاشتراك
  static String? validateSubscription(SubscriptionEntity subscription) {
    return subscription.validate();
  }

  /// التحقق من صحة السعر
  static String? validatePrice(double price) {
    if (price <= 0) return 'السعر يجب أن يكون أكبر من صفر';
    if (price > 1000000) return 'السعر كبير جداً';
    return null;
  }

  /// التحقق من صحة المدة المخصصة
  static String? validateCustomDays(int? customDays, String duration) {
    if (duration == 'custom') {
      if (customDays == null || customDays <= 0) {
        return 'عدد الأيام المخصصة يجب أن يكون أكبر من صفر';
      }
      if (customDays > 3650) {
        // أكثر من 10 سنوات
        return 'عدد الأيام المخصصة كبير جداً (الحد الأقصى 3650 يوم)';
      }
    }
    return null;
  }

  /// التحقق من صحة التواريخ
  static String? validateDates(DateTime startDate, DateTime endDate) {
    if (startDate.isAfter(endDate)) {
      return 'تاريخ البداية يجب أن يكون قبل تاريخ النهاية';
    }

    final now = DateTime.now().toUtc();
    final maxFutureDate = now.add(const Duration(days: 3650)); // 10 سنوات

    if (endDate.isAfter(maxFutureDate)) {
      return 'تاريخ النهاية بعيد جداً في المستقبل';
    }

    return null;
  }

  /// التحقق من صحة الحالة
  static String? validateStatus(String status) {
    const validStatuses = [
      'active',
      'expired',
      'cancelled',
      'suspended',
      'pending',
    ];
    if (!validStatuses.contains(status)) {
      return 'حالة الاشتراك غير صحيحة';
    }
    return null;
  }

  /// التحقق من صحة المدة
  static String? validateDuration(String duration) {
    const validDurations = [
      'daily',
      'weekly',
      'monthly',
      'quarterly',
      'yearly',
      'custom',
    ];
    if (!validDurations.contains(duration)) {
      return 'مدة الاشتراك غير صحيحة';
    }
    return null;
  }

  /// التحقق من صحة انتقال الحالة
  static String? validateStatusTransition(
    String currentStatus,
    String newStatus,
  ) {
    switch (currentStatus) {
      case 'pending':
        if (!['active', 'cancelled'].contains(newStatus)) {
          return 'لا يمكن تغيير حالة الاشتراك من معلق إلى $newStatus';
        }
        break;
      case 'active':
        if (!['expired', 'cancelled', 'suspended'].contains(newStatus)) {
          return 'لا يمكن تغيير حالة الاشتراك من نشط إلى $newStatus';
        }
        break;
      case 'suspended':
        if (!['active', 'cancelled'].contains(newStatus)) {
          return 'لا يمكن تغيير حالة الاشتراك من معلق إلى $newStatus';
        }
        break;
      case 'expired':
        if (!['active', 'cancelled'].contains(newStatus)) {
          return 'لا يمكن تغيير حالة الاشتراك من منتهي الصلاحية إلى $newStatus';
        }
        break;
      case 'cancelled':
        return 'لا يمكن تغيير حالة الاشتراك الملغي';
      default:
        return 'حالة الاشتراك الحالية غير صحيحة';
    }
    return null;
  }

  /// التحقق من صحة معلومات الدفع
  static String? validatePayment(
    double totalPaid,
    double price,
    double remainingAmount,
  ) {
    if (totalPaid < 0) {
      return 'إجمالي المدفوع لا يمكن أن يكون سالباً';
    }
    if (remainingAmount < 0) {
      return 'المبلغ المتبقي لا يمكن أن يكون سالباً';
    }
    if (totalPaid > price && remainingAmount != 0) {
      // السماح بدفع أكثر من السعر فقط إذا كان المبلغ المتبقي صفر
      return 'إجمالي المدفوع لا يمكن أن يكون أكبر من السعر';
    }

    // التحقق من صحة الحساب
    final expectedRemaining = price - totalPaid;
    if ((remainingAmount - expectedRemaining).abs() > 0.01) {
      // تسامح صغير للأرقام العشرية
      return 'المبلغ المتبقي غير صحيح';
    }

    return null;
  }

  /// التحقق من صحة اسم الاشتراك
  static String? validateName(String name) {
    if (name.trim().isEmpty) return 'اسم الاشتراك مطلوب';
    if (name.trim().length < 2) return 'اسم الاشتراك قصير جداً';
    if (name.trim().length > 100) return 'اسم الاشتراك طويل جداً';
    return null;
  }

  /// التحقق من صحة نوع الاشتراك
  static String? validateType(String type) {
    if (type.trim().isEmpty) return 'نوع الاشتراك مطلوب';
    if (type.trim().length < 2) return 'نوع الاشتراك قصير جداً';
    if (type.trim().length > 50) return 'نوع الاشتراك طويل جداً';
    return null;
  }

  /// التحقق من صحة البريد الإلكتروني للمؤسسة
  static String? validateOrganizationEmail(String email) {
    if (email.trim().isEmpty) return 'بريد المؤسسة مطلوب';

    // تحقق بسيط من صيغة البريد الإلكتروني
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    return null;
  }

  /// التحقق من صحة معرف العميل
  static String? validateCustomerId(String? customerId) {
    if (customerId != null && customerId.isNotEmpty) {
      if (customerId.trim().length < 3) {
        return 'معرف العميل قصير جداً';
      }
      if (customerId.trim().length > 50) {
        return 'معرف العميل طويل جداً';
      }
    }
    return null;
  }

  /// التحقق من صحة اسم العميل
  static String? validateCustomerName(String? customerName) {
    if (customerName != null && customerName.isNotEmpty) {
      if (customerName.trim().length < 2) {
        return 'اسم العميل قصير جداً';
      }
      if (customerName.trim().length > 100) {
        return 'اسم العميل طويل جداً';
      }
    }
    return null;
  }

  /// التحقق من صحة الوصف
  static String? validateDescription(String? description) {
    if (description != null && description.isNotEmpty) {
      if (description.trim().length > 500) {
        return 'الوصف طويل جداً (الحد الأقصى 500 حرف)';
      }
    }
    return null;
  }

  /// التحقق من صحة عدد التجديدات
  static String? validateRenewalCount(int renewalCount) {
    if (renewalCount < 0) {
      return 'عدد التجديدات لا يمكن أن يكون سالباً';
    }
    if (renewalCount > 1000) {
      return 'عدد التجديدات كبير جداً';
    }
    return null;
  }

  /// التحقق الشامل من صحة الاشتراك
  static List<String> validateSubscriptionComprehensive(
    SubscriptionEntity subscription,
  ) {
    final errors = <String>[];

    // التحقق من الحقول الأساسية
    final nameError = validateName(subscription.name);
    if (nameError != null) errors.add(nameError);

    final typeError = validateType(subscription.type);
    if (typeError != null) errors.add(typeError);

    final priceError = validatePrice(subscription.price);
    if (priceError != null) errors.add(priceError);

    final durationError = validateDuration(subscription.duration);
    if (durationError != null) errors.add(durationError);

    final statusError = validateStatus(subscription.status);
    if (statusError != null) errors.add(statusError);

    final orgEmailError = validateOrganizationEmail(
      subscription.organizationEmail,
    );
    if (orgEmailError != null) errors.add(orgEmailError);

    // التحقق من الحقول الاختيارية
    final customerIdError = validateCustomerId(subscription.customerId);
    if (customerIdError != null) errors.add(customerIdError);

    final customerNameError = validateCustomerName(subscription.customerName);
    if (customerNameError != null) errors.add(customerNameError);

    final descriptionError = validateDescription(subscription.description);
    if (descriptionError != null) errors.add(descriptionError);

    // التحقق من التواريخ
    final datesError = validateDates(
      subscription.startDate,
      subscription.endDate,
    );
    if (datesError != null) errors.add(datesError);

    // التحقق من المدة المخصصة
    final customDaysError = validateCustomDays(
      subscription.customDays,
      subscription.duration,
    );
    if (customDaysError != null) errors.add(customDaysError);

    // التحقق من معلومات الدفع
    final paymentError = validatePayment(
      subscription.totalPaid,
      subscription.price,
      subscription.remainingAmount,
    );
    if (paymentError != null) errors.add(paymentError);

    // التحقق من عدد التجديدات
    final renewalCountError = validateRenewalCount(subscription.renewalCount);
    if (renewalCountError != null) errors.add(renewalCountError);

    return errors;
  }
}
