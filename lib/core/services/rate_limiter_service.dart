/// خدمة حد المعدل لمنع الإفراط في الطلبات
class RateLimiterService {
  factory RateLimiterService() => _instance;
  RateLimiterService._internal();

  static final RateLimiterService _instance = RateLimiterService._internal();

  final Map<String, List<DateTime>> _userRequests = {};

  /// الحد الأقصى للطلبات لكل مستخدم في الدقيقة الواحدة
  static const int maxRequestsPerMinute = 30;

  /// الحد الأقصى للطلبات لكل مستخدم في الساعة الواحدة
  static const int maxRequestsPerHour = 200;

  /// التحقق من إمكانية تنفيذ الطلب
  bool canMakeRequest(String userId, {String? operation}) {
    final now = DateTime.now();
    final userKey = '$userId${operation != null ? '_$operation' : ''}';

    // إنشاء قائمة جديدة إذا لم تكن موجودة
    _userRequests[userKey] ??= [];

    final requests = _userRequests[userKey]!;

    // إزالة الطلبات القديمة (أكثر من ساعة)
    requests.removeWhere((request) => now.difference(request).inHours >= 1);

    // التحقق من الحد الأقصى في الساعة
    if (requests.length >= maxRequestsPerHour) {
      return false;
    }

    // التحقق من الحد الأقصى في الدقيقة
    final recentRequests = requests
        .where((request) => now.difference(request).inMinutes < 1)
        .length;

    if (recentRequests >= maxRequestsPerMinute) {
      return false;
    }

    // إضافة الطلب الحالي
    requests.add(now);

    return true;
  }

  /// الحصول على عدد الطلبات المتبقية في الدقيقة
  int getRemainingRequestsPerMinute(String userId, {String? operation}) {
    final now = DateTime.now();
    final userKey = '$userId${operation != null ? '_$operation' : ''}';

    if (!_userRequests.containsKey(userKey)) {
      return maxRequestsPerMinute;
    }

    final requests = _userRequests[userKey]!;
    final recentRequests = requests
        .where((request) => now.difference(request).inMinutes < 1)
        .length;

    return maxRequestsPerMinute - recentRequests;
  }

  /// الحصول على عدد الطلبات المتبقية في الساعة
  int getRemainingRequestsPerHour(String userId, {String? operation}) {
    final now = DateTime.now();
    final userKey = '$userId${operation != null ? '_$operation' : ''}';

    if (!_userRequests.containsKey(userKey)) {
      return maxRequestsPerHour;
    }

    final requests = _userRequests[userKey]!;
    final recentRequests = requests
        .where((request) => now.difference(request).inHours < 1)
        .length;

    return maxRequestsPerHour - recentRequests;
  }

  /// مسح سجلات المستخدم
  void clearUserRequests(String userId) {
    _userRequests.removeWhere((key, _) => key.startsWith(userId));
  }

  /// مسح جميع السجلات
  void clearAllRequests() {
    _userRequests.clear();
  }

  /// الحصول على الوقت المتبقي حتى إمكانية تنفيذ طلب جديد
  Duration? getTimeUntilNextRequest(String userId, {String? operation}) {
    final now = DateTime.now();
    final userKey = '$userId${operation != null ? '_$operation' : ''}';

    if (!_userRequests.containsKey(userKey)) {
      return null; // يمكن تنفيذ الطلب فوراً
    }

    final requests = _userRequests[userKey]!;

    // البحث عن أقدم طلب في الدقيقة الأخيرة
    // ignore: cascade_invitations
    final recentRequests =
        requests
            .where((request) => now.difference(request).inMinutes < 1)
            .toList()
          ..sort();

    if (recentRequests.length < maxRequestsPerMinute) {
      return null; // يمكن تنفيذ الطلب فوراً
    }

    // حساب الوقت المتبقي حتى انتهاء الدقيقة للطلب الأقدم
    final oldestRequest = recentRequests.first;
    final timeUntilExpiry =
        const Duration(minutes: 1) - now.difference(oldestRequest);

    return timeUntilExpiry;
  }
}
