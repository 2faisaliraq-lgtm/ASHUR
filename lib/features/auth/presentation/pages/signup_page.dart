import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_otp_widgets.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _acceptTerms = false;

  // حالة التبديل بين البريد والهاتف
  AuthMethod _authMethod = AuthMethod.email;
  bool _isOTPStep = false;
  bool _isOTPSent = false;
  String _verificationId = '';
  bool _isLoading = false;

  // لمنع تكرار الرسائل
  String? _lastErrorMessage;
  DateTime? _lastErrorTime;

  @override
  void initState() {
    super.initState();
    // تأخير بسيط للسماح بتحميل الـ context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArgumentsIfAvailable();
    });
  }

  void _loadArgumentsIfAvailable() {
    // استقبال البيانات من الشاشة السابقة
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      final method = args['method'] as String?;
      final value = args['value'] as String?;

      if (method != null && value != null) {
        setState(() {
          if (method == 'email') {
            _authMethod = AuthMethod.email;
            _emailController.text = value;
          } else if (method == 'phone') {
            _authMethod = AuthMethod.phone;
            _phoneController.text = value;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        _handleAuthStateChange(context, state);
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AssyrianTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isLandscape =
                      MediaQuery.of(context).orientation ==
                      Orientation.landscape;

                  if (isLandscape) {
                    return Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: AssyrianTheme.getSimpleLamassuForAuth(
                              isDarkBackground: true,
                              isLandscape: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: _buildSignupFormLandscape(),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.translate(
                            offset: Offset(0, -80.h),
                            child: SizedBox(
                              width: double.infinity,
                              height: constraints.maxHeight * 0.7,
                              child: Center(
                                child: AssyrianTheme.getSimpleLamassuForAuth(
                                  isDarkBackground: true,
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(0, -200.h),
                            child: _buildSignupForm(),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupForm() {
    if (_isOTPStep) {
      return _buildOTPVerificationStep();
    }
    return _buildDataInputStep();
  }

  Widget _buildSignupFormLandscape() {
    if (_isOTPStep) {
      return _buildOTPVerificationStepLandscape();
    }
    return _buildDataInputStepLandscape();
  }

  Widget _buildDataInputStep() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 1.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              'إنشاء حساب جديد',
              style: AssyrianTheme.titleStyle.copyWith(fontSize: 18.sp),
            ),
            SizedBox(height: 1.h),

            // أزرار التبديل
            AuthMethodToggleButtons(
              method: _authMethod,
              onChanged: (method) {
                setState(() {
                  _authMethod = method;
                  _isOTPSent = false;
                  _otpController.clear();
                });
              },
            ),
            SizedBox(height: 1.h),

            // الاسم
            TextFormField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16.sp,
                color: AssyrianTheme.deepBlue,
              ),
              decoration: InputDecoration(
                hintText: 'الاسم الكامل',
                prefixIcon: Container(
                  margin: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 16.sp,
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
              ),
              validator: (value) {
                return validateName(value);
              },
            ),
            SizedBox(height: 0.5.h),

            // البريد أو الهاتف
            if (_authMethod == AuthMethod.email)
              EmailInputField(controller: _emailController)
            else
              PhoneInputField(controller: _phoneController),
            SizedBox(height: 0.5.h),

            // كلمة المرور
            PasswordInputField(
              controller: _passwordController,
              hintText: 'كلمة المرور',
              isNumeric: true,
              validator: (value) {
                // استخدام كلمة مرور رقمية بسيطة للتوافق مع النظام الحالي
                return validateNumericPassword(value);
              },
            ),
            SizedBox(height: 0.5.h),

            // تأكيد كلمة المرور
            PasswordInputField(
              controller: _confirmPasswordController,
              hintText: 'تأكيد كلمة المرور',
              isNumeric: true,
              validator: (value) {
                return validateConfirmPassword(value, _passwordController.text);
              },
            ),
            SizedBox(height: 0.5.h),

            // الموافقة على الشروط
            Row(
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptTerms = value ?? false;
                    });
                  },
                  activeColor: AssyrianTheme.primaryGold,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _acceptTerms = !_acceptTerms;
                      });
                    },
                    child: Text(
                      'أوافق على الشروط والأحكام',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.sp,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),

            // زر إنشاء الحساب
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _acceptTerms && !_isLoading ? _createAccount : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _acceptTerms
                      ? AssyrianTheme.primaryGold
                      : AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                  foregroundColor: _acceptTerms
                      ? AssyrianTheme.deepBlue
                      : AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                  disabledBackgroundColor: AssyrianTheme.primaryGold.withValues(
                    alpha: 0.3,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: _isLoading
                    ? LoadingWidget(size: 16)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_rounded,
                            size: 20.sp,
                            color: _acceptTerms
                                ? AssyrianTheme.deepBlue
                                : AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'إنشاء الحساب',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: _acceptTerms
                                  ? AssyrianTheme.deepBlue
                                  : AssyrianTheme.deepBlue.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 1.h),

            // زر التبديل
            TextButton(
              onPressed: () {
                setState(() {
                  _authMethod = _authMethod == AuthMethod.email
                      ? AuthMethod.phone
                      : AuthMethod.email;
                  _isOTPSent = false;
                  _otpController.clear();
                });
              },
              child: Text(
                _authMethod == AuthMethod.email
                    ? 'إنشاء حساب برقم الهاتف'
                    : 'إنشاء حساب بالبريد الإلكتروني',
                style: TextStyle(
                  color: AssyrianTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataInputStepLandscape() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0.5.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              'إنشاء حساب جديد',
              style: AssyrianTheme.bodyStyle.copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 0.5.h),
            AuthMethodToggleButtons(
              method: _authMethod,
              onChanged: (m) => setState(() => _authMethod = m),
            ),
            SizedBox(height: 0.5.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(hintText: 'الاسم'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'الاسم مطلوب' : null,
            ),
            SizedBox(height: 0.5.h),
            Row(
              children: [
                Expanded(
                  child: _authMethod == AuthMethod.email
                      ? EmailInputField(controller: _emailController)
                      : PhoneInputField(controller: _phoneController),
                ),
                SizedBox(width: 2.w),
                ElevatedButton(
                  onPressed: _isOTPSent ? null : _sendOTPCode,
                  child: Text('إرسال'),
                ),
              ],
            ),
            SizedBox(height: 0.5.h),
            PasswordInputField(
              controller: _passwordController,
              hintText: 'كلمة المرور',
            ),
            SizedBox(height: 0.5.h),
            PasswordInputField(
              controller: _confirmPasswordController,
              hintText: 'التأكيد',
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                ),
                Expanded(child: Text('أوافق')),
              ],
            ),
            SizedBox(height: 2.h),
            // زر إنشاء الحساب - Landscape
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _acceptTerms && !_isLoading ? _createAccount : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _acceptTerms
                      ? AssyrianTheme.primaryGold
                      : AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                  foregroundColor: _acceptTerms
                      ? AssyrianTheme.deepBlue
                      : AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                  disabledBackgroundColor: AssyrianTheme.primaryGold.withValues(
                    alpha: 0.3,
                  ),
                ),
                child: _isLoading
                    ? LoadingWidget(size: 16)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_rounded,
                            size: 16.sp,
                            color: _acceptTerms
                                ? AssyrianTheme.deepBlue
                                : AssyrianTheme.deepBlue.withValues(alpha: 0.5),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'إنشاء الحساب',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: _acceptTerms
                                  ? AssyrianTheme.deepBlue
                                  : AssyrianTheme.deepBlue.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPVerificationStep() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 1.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Column(
        children: [
          Text(
            'أدخل رمز التحقق',
            style: AssyrianTheme.titleStyle.copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 0.5.h),

          Text(
            _authMethod == AuthMethod.email
                ? 'أرسلنا رمز التحقق إلى: ${_emailController.text}'
                : 'أرسلنا رمز التحقق إلى: ${_phoneController.text}',
            style: TextStyle(fontSize: 10.sp, color: AssyrianTheme.deepBlue),
          ),
          SizedBox(height: 1.h),

          OTPInputField(controller: _otpController),
          SizedBox(height: 1.h),

          // زر التحقق - بدون Form
          VerifyButton(
            onPressed: () {
              _verifyAndCreateAccount();
            },
            isLoading: _isLoading,
            text: 'تحقق وإنشاء الحساب',
            icon: Icons.how_to_reg_rounded,
          ),
          SizedBox(height: 0.5.h),

          TextButton(
            onPressed: _sendOTPCode,
            child: Text(
              'إعادة إرسال الرمز',
              style: TextStyle(color: AssyrianTheme.primaryGold),
            ),
          ),
          SizedBox(height: 0.5.h),

          TextButton(
            onPressed: () {
              setState(() {
                _isOTPStep = false;
                _isOTPSent = false;
                _otpController.clear();
              });
            },
            child: Text('تغيير البيانات'),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPVerificationStepLandscape() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0.5.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Column(
        children: [
          Text(
            'أدخل رمز التحقق',
            style: AssyrianTheme.bodyStyle.copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 0.5.h),
          OTPInputField(controller: _otpController),
          SizedBox(height: 4.h),
          VerifyButton(
            onPressed: _verifyAndCreateAccount,
            isLoading: _isLoading,
            text: 'تحقق وإنشاء الحساب',
            icon: Icons.how_to_reg_rounded,
          ),
        ],
      ),
    );
  }

  void _sendOTPCode() {
    // التحقق من الحقل فقط (البريد أو الهاتف)
    bool isValid = false;
    String errorMessage = '';

    if (_authMethod == AuthMethod.email) {
      final emailError = validateEmail(_emailController.text.trim());
      if (emailError != null) {
        errorMessage = emailError;
      } else {
        isValid = true;
      }
    } else {
      final phoneError = validatePhoneNumber(_phoneController.text.trim());
      if (phoneError != null) {
        errorMessage = phoneError;
      } else {
        isValid = true;
      }
    }

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_authMethod == AuthMethod.email) {
      context.read<AuthBloc>().add(
        SendEmailOTPRequested(email: _emailController.text.trim()),
      );
    } else {
      context.read<AuthBloc>().add(
        SendPhoneOTPRequested(phoneNumber: _phoneController.text.trim()),
      );
    }
  }

  Future<void> _createAccount() async {
    // التحقق من صحة النموذج أولاً
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    // إرسال OTP مباشرة - التحقق من وجود الحساب سيتم في UseCase
    setState(() => _isLoading = true);

    if (_authMethod == AuthMethod.email) {
      context.read<AuthBloc>().add(
        SendEmailOTPRequested(email: _emailController.text.trim()),
      );
    } else {
      context.read<AuthBloc>().add(
        SendPhoneOTPRequested(phoneNumber: _phoneController.text.trim()),
      );
    }
  }

  void _verifyAndCreateAccount() {
    // التحقق من أن الرمز 6 أرقام
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رمز التحقق المكون من 6 أرقام'),
        ),
      );
      return;
    }

    // التحقق من صحة البيانات الأساسية
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الاسم مطلوب')));
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('كلمة المرور مطلوبة')));
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('كلمة المرور غير متطابقة')));
      return;
    }

    setState(() => _isLoading = true);

    // التحقق من الرمز وإنشاء الحساب مباشرة
    // Firebase سيرفض إذا كان البريد مستخدم بالفعل
    if (_authMethod == AuthMethod.email) {
      context.read<AuthBloc>().add(
        VerifyEmailOTPRequested(
          email: _emailController.text.trim(),
          otpCode: _otpController.text.trim(),
          name: _nameController.text.trim(),
          password: _passwordController.text,
        ),
      );
    } else {
      context.read<AuthBloc>().add(
        VerifyPhoneOTPRequested(
          verificationId: _verificationId,
          smsCode: _otpController.text.trim(),
          name: _nameController.text.trim(),
        ),
      );
    }
  }

  void _handleAuthStateChange(BuildContext context, AuthState state) {
    setState(() => _isLoading = false);

    if (state is EmailOTPSent || state is PhoneOTPSent) {
      setState(() {
        _isOTPStep = true;
        _isOTPSent = true;
        // حفظ verificationId للهاتف
        if (state is PhoneOTPSent) {
          _verificationId = state.verificationId;
        }
      });
      // عرض رسالة للمستخدم - مرة واحدة فقط
      _showSnackBarOnce(
        _authMethod == AuthMethod.email
            ? 'تم إرسال رمز التحقق إلى البريد (${_emailController.text})\n\n📧 تحقق من Console في وضع التطوير'
            : 'تم إرسال رمز التحقق إلى الهاتف (${_phoneController.text})',
        Colors.green,
      );
    } else if (state is AuthAuthenticated) {
      // تم إنشاء الحساب بنجاح
      _showSnackBarOnce('✅ تم إنشاء الحساب بنجاح', Colors.green);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && context.mounted) {
          // التحقق مما إذا كان هناك مدير في النظام
          // إذا لم يكن هناك مدير، الانتقال إلى شاشة إنشاء المدير
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/create-admin', (route) => false);
        }
      });
    } else if (state is AuthError) {
      // التحقق من نوع الخطأ
      final errorMessage = state.message.toLowerCase();

      if (errorMessage.contains('already in use') ||
          errorMessage.contains('مستخدم بالفعل') ||
          errorMessage.contains('email address is already')) {
        // الحساب موجود بالفعل
        // التأكد من أننا في شاشة إنشاء الحساب وليس في شاشة OTP
        if (!_isOTPStep) {
          // في شاشة إنشاء الحساب - عرض dialog مباشرة
          _showAccountExistsDialog();
        } else {
          // في شاشة OTP - العودة لشاشة إنشاء الحساب وعرض dialog
          setState(() {
            _isOTPStep = false;
            _isOTPSent = false;
          });
          // تأخير بسيط للسماح بتحديث الواجهة
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _showAccountExistsDialog();
            }
          });
        }
      } else {
        // عرض رسالة الخطأ العادية
        _showSnackBarOnce(
          '❌ ${ErrorHandler.getAuthErrorMessage(state.message)}',
          Colors.red,
          duration: const Duration(seconds: 5),
        );
      }
    } else if (state is AccountExistsError) {
      // الحساب موجود بالفعل - عرض dialog
      setState(() {
        _isOTPStep = false;
        _isOTPSent = false;
      });
      // تأخير بسيط للسماح بتحديث الواجهة
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _showAccountExistsDialog();
        }
      });
    } else if (state is AccountNotExistsState) {
      // الحساب غير موجود - الانتقال لشاشة OTP وإرسال الرمز
      setState(() {
        _isOTPStep = true;
        _isOTPSent = true;
      });
      _sendOTPCode();
    } else if (state is PasswordResetSuccessfully) {
      _showSnackBarOnce('✅ تم إعادة تعيين كلمة المرور بنجاح', Colors.green);
    }
  }

  // دالة مساعدة لعرض SnackBar مرة واحدة فقط
  void _showSnackBarOnce(String message, Color color, {Duration? duration}) {
    final now = DateTime.now();
    final isDuplicate =
        _lastErrorMessage == message &&
        _lastErrorTime != null &&
        now.difference(_lastErrorTime!).inMilliseconds < 3000;

    if (!isDuplicate && mounted) {
      // إخفاء جميع الـ SnackBars الحالية أولاً
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();

      _lastErrorMessage = message;
      _lastErrorTime = now;

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: duration ?? const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // عرض SnackBar مع خيارات عند وجود حساب بالفعل
  void _showAccountExistsDialog() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 24.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'الحساب موجود بالفعل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              _authMethod == AuthMethod.email
                  ? 'يوجد حساب مرتبط بـ ${_emailController.text}'
                  : 'يوجد حساب مرتبط بـ ${_phoneController.text}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.sp,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    // نقل البريد/الهاتف إلى شاشة نسيان كلمة المرور
                    Navigator.of(context).pushReplacementNamed(
                      '/forgot-password',
                      arguments: {
                        'method': _authMethod == AuthMethod.email
                            ? 'email'
                            : 'phone',
                        'value': _authMethod == AuthMethod.email
                            ? _emailController.text.trim()
                            : _phoneController.text.trim(),
                      },
                    );
                  },
                  child: Text(
                    'نسيت كلمة المرور',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    // نقل البريد/الهاتف إلى شاشة تسجيل الدخول
                    Navigator.of(context).pushReplacementNamed(
                      '/login',
                      arguments: {
                        'method': _authMethod == AuthMethod.email
                            ? 'email'
                            : 'phone',
                        'value': _authMethod == AuthMethod.email
                            ? _emailController.text.trim()
                            : _phoneController.text.trim(),
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.all(16.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }
}

