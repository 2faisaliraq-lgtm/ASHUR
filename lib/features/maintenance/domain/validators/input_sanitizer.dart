/// منظف المدخلات لحماية من الهجمات
// ignore: avoid_classes_with_only_static_members
class InputSanitizer {
  /// تنظيف النص من المحارف الخطيرة
  static String sanitizeText(String? input) {
    if (input == null || input.isEmpty) return '';

    return input
        .replaceAll(RegExp('<[^>]*>'), '') // إزالة HTML tags
        .replaceAll(RegExp('[<>&"\'`]'), '') // إزالة محارف خطيرة
        .replaceAll(RegExp(r'\s+'), ' ') // توحيد المسافات
        .trim();
  }

  /// تنظيف البريد الإلكتروني
  static String sanitizeEmail(String? email) {
    if (email == null || email.isEmpty) return '';

    return email.toLowerCase().replaceAll(RegExp('[^a-z0-9@._-]'), '').trim();
  }

  /// تنظيف رقم الهاتف
  static String sanitizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';

    return phone.replaceAll(RegExp(r'[^0-9+\-\s()]'), '').trim();
  }

  /// تنظيف الأرقام — يدعم الأرقام العربية والهندية ويحولها إلى إنجليزية
  static double? sanitizeNumber(dynamic number) {
    if (number == null) return null;

    if (number is double) return number;
    if (number is int) return number.toDouble();

    if (number is String) {
      // تحويل الأرقام العربية إلى إنجليزية قبل التنظيف
      final cleaned = number
          .replaceAll(RegExp('[^0-9.\u0660-\u0669\u06F0-\u06F9.-]'), '')
          .replaceAllMapped(
            RegExp(r'[\u0660-\u0669\u06F0-\u06F9]'),
            (match) {
              final ch = match.group(0)!;
              // أرقام عربية Extended Arabic-Indic digits (U+0660-U+0669)
              if (ch.codeUnitAt(0) >= 0x0660 && ch.codeUnitAt(0) <= 0x0669) {
                return (ch.codeUnitAt(0) - 0x0660).toString();
              }
              // أرقام هندية Extended Arabic-Indic digits (U+06F0-U+06F9)
              return (ch.codeUnitAt(0) - 0x06F0).toString();
            },
          )
          .replaceAll(RegExp('[^0-9.-]'), '');
      return double.tryParse(cleaned);
    }

    return null;
  }

  /// التحقق من طول النص
  static String limitTextLength(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }

  /// تنظيف شامل لطلب الصيانة
  static Map<String, dynamic> sanitizeMaintenanceRequest(
    Map<String, dynamic> data,
  ) {
    return {
      'title': limitTextLength(sanitizeText(data['title']), 100),
      'description': limitTextLength(sanitizeText(data['description']), 1000),
      'equipmentName': limitTextLength(
        sanitizeText(data['equipmentName']),
        100,
      ),
      'location': limitTextLength(sanitizeText(data['location']), 200),
      'notes': limitTextLength(sanitizeText(data['notes']), 500),
      'requestedBy': sanitizeEmail(data['requestedBy']),
      'assignedTo': sanitizeEmail(data['assignedTo']),
      'estimatedCost': sanitizeNumber(data['estimatedCost']),
      'actualCost': sanitizeNumber(data['actualCost']),
      'priority': _sanitizePriority(data['priority']),
      'status': _sanitizeStatus(data['status']),
      // الحقول الأخرى تمر كما هي بعد التحقق
      'organizationEmail': sanitizeEmail(data['organizationEmail']),
      'customerId': sanitizeText(data['customerId']),
      'customerName': sanitizeText(data['customerName']),
      'equipmentId': sanitizeText(data['equipmentId']),
      'requestDate': data['requestDate'],
      'scheduledDate': data['scheduledDate'],
      'completedDate': data['completedDate'],
      'createdAt': data['createdAt'],
      'updatedAt': data['updatedAt'],
      'createdBy': sanitizeText(data['createdBy']),
      'updatedBy': sanitizeText(data['updatedBy']),
    };
  }

  /// تنظيف الأولوية
  static String _sanitizePriority(dynamic priority) {
    const validPriorities = ['low', 'medium', 'high', 'urgent'];
    if (priority is String && validPriorities.contains(priority)) {
      return priority;
    }
    return 'medium'; // القيمة الافتراضية
  }

  /// تنظيف الحالة
  static String _sanitizeStatus(dynamic status) {
    const validStatuses = ['pending', 'in_progress', 'completed', 'cancelled'];
    if (status is String && validStatuses.contains(status)) {
      return status;
    }
    return 'pending'; // القيمة الافتراضية
  }
}
