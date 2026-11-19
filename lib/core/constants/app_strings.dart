// ignore: avoid_classes_with_only_static_members
class AppStrings {
  // App Info
  static const String appName = 'اشور';
  static const String appSubtitle = 'نظام المحاسبة الشامل';

  // Authentication
  static const String login = 'تسجيل الدخول';
  static const String signup = 'إنشاء حساب جديد';
  static const String logout = 'تسجيل الخروج';
  static const String email = 'البريد الإلكتروني';
  static const String password = 'كلمة المرور';
  static const String confirmPassword = 'تأكيد كلمة المرور';
  static const String fullName = 'الاسم الكامل';
  static const String forgotPassword = 'نسيت كلمة المرور؟';
  static const String dontHaveAccount = 'ليس لديك حساب؟';
  static const String alreadyHaveAccount = 'لديك حساب بالفعل؟';
  static const String createAccount = 'إنشاء الحساب';

  // Validation Messages
  static const String emailRequired = 'البريد الإلكتروني مطلوب';
  static const String emailInvalid = 'البريد الإلكتروني غير صحيح';
  static const String passwordRequired = 'كلمة المرور مطلوبة';
  static const String passwordTooShort =
      'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
  static const String passwordMismatch = 'كلمة المرور غير متطابقة';
  static const String nameRequired = 'الاسم مطلوب';
  static const String nameInvalid = 'الاسم يجب أن يكون حرفين على الأقل';

  // Navigation
  static const String home = 'الصفحة الرئيسية';
  static const String transactions = 'المعاملات';
  static const String reports = 'التقارير';
  static const String settings = 'الإعدادات';
  static const String equity = 'حقوق الملكية';
  static const String revenue = 'الإيرادات';
  static const String expenses = 'المصروفات';
  static const String currentAssets = 'الأصول المتداولة';
  static const String fixedAssets = 'الأصول الثابتة';
  static const String currentLiabilities = 'الخصوم المتداولة';
  static const String longTermLiabilities = 'الخصوم طويلة الأجل';

  // Common Actions
  static const String save = 'حفظ';
  static const String cancel = 'إلغاء';
  static const String delete = 'حذف';
  static const String edit = 'تعديل';
  static const String add = 'إضافة';
  static const String refresh = 'تحديث';
  static const String search = 'بحث';
  static const String filter = 'تصفية';
  static const String sort = 'ترتيب';
  static const String ok = 'موافق';
  static const String yes = 'نعم';
  static const String no = 'لا';

  // Status Messages
  static const String loading = 'جاري التحميل...';
  static const String saving = 'جاري الحفظ...';
  static const String deleting = 'جاري الحذف...';
  static const String success = 'تم بنجاح';
  static const String error = 'حدث خطأ';
  static const String noData = 'لا توجد بيانات';
  static const String noInternet = 'لا يوجد اتصال بالإنترنت';
  static const String offlineMode = 'وضع عدم الاتصال';
  static const String syncInProgress = 'جاري المزامنة...';
  static const String syncComplete = 'تمت المزامنة';
  static const String syncFailed = 'فشلت المزامنة';

  // Connection Status
  static const String connected = 'متصل بالإنترنت';
  static const String disconnected = 'غير متصل - وضع عدم الاتصال';
  static const String offlineDataSaved =
      'وضع عدم الاتصال - البيانات محفوظة محلياً';

  // Confirmation Messages
  static const String confirmDelete = 'هل أنت متأكد من الحذف؟';
  static const String confirmLogout = 'هل أنت متأكد من تسجيل الخروج؟';
  static const String deleteAccountConfirm = 'هل أنت متأكد من حذف هذا الحساب؟';
  static const String cannotUndoAction = 'لا يمكن التراجع عن هذا الإجراء';

  // Features Coming Soon
  static const String comingSoon = 'سيتم تنفيذ هذه الميزة قريباً';
  static const String featureNotImplemented = 'هذه الميزة قيد التطوير';

  // Welcome Messages
  static const String welcomeMessage = 'مرحباً بك في تطبيق اشور';
  static const String welcomeSubtitle = 'نظام المحاسبة الشامل لجميع الأعمال';
  static const String getStarted = 'ابدأ الآن';

  // Device Types
  static const String mobileView = 'عرض الهاتف المحمول';
  static const String tabletView = 'عرض الجهاز اللوحي';
  static const String desktopView = 'عرض سطح المكتب';

  // Error Messages
  static const String loginFailed = 'فشل في تسجيل الدخول';
  static const String signupFailed = 'فشل في إنشاء الحساب';
  static const String logoutFailed = 'فشل في تسجيل الخروج';
  static const String loadDataFailed = 'فشل في تحميل البيانات';
  static const String saveDataFailed = 'فشل في حفظ البيانات';
  static const String deleteDataFailed = 'فشل في حذف البيانات';
  static const String networkError = 'خطأ في الشبكة';
  static const String serverError = 'خطأ في الخادم';
  static const String unknownError = 'خطأ غير معروف';

  // Firebase Auth Errors (Arabic)
  static const String userNotFound = 'لا يوجد مستخدم بهذا البريد الإلكتروني';
  static const String wrongPassword = 'كلمة المرور غير صحيحة';
  static const String emailAlreadyInUse = 'البريد الإلكتروني مستخدم بالفعل';
  static const String weakPassword = 'كلمة المرور ضعيفة جداً';
  static const String invalidEmail = 'البريد الإلكتروني غير صحيح';
  static const String userDisabled = 'تم تعطيل هذا الحساب';
  static const String tooManyRequests =
      'تم تجاوز عدد المحاولات المسموح، حاول لاحقاً';
  static const String networkRequestFailed = 'خطأ في الاتصال بالإنترنت';
}
