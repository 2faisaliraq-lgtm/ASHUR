import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_otp_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;

  // حالة التبديل بين البريد والهاتف
  AuthMethod _loginMethod = AuthMethod.email;
  bool _isOTPStep = false;
  String _verificationId = '';
  bool _isLoading = false;

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
            _loginMethod = AuthMethod.email;
            _emailController.text = value;
          } else if (method == 'phone') {
            _loginMethod = AuthMethod.phone;
            _phoneController.text = value;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        return current is EmailOTPSent ||
            current is PhoneOTPSent ||
            current is AuthAuthenticated ||
            current is AuthError;
      },
      listener: _handleAuthStateChange,
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
                              child: _buildLoginFormLandscape(),
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
                            child: _buildLoginForm(),
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

  Widget _buildLoginForm() {
    if (_isOTPStep) {
      return _buildOTPLoginStep();
    }
    return _buildCredentialLoginStep();
  }

  Widget _buildLoginFormLandscape() {
    if (_isOTPStep) {
      return _buildOTPLoginStepLandscape();
    }
    return _buildCredentialLoginStepLandscape();
  }

  Widget _buildCredentialLoginStep() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 1.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              'تسجيل الدخول إلى حسابك',
              style: AssyrianTheme.titleStyle.copyWith(fontSize: 18.sp),
            ),
            SizedBox(height: 1.h),

            // أزرار التبديل
            AuthMethodToggleButtons(
              method: _loginMethod,
              onChanged: (method) {
                setState(() {
                  _loginMethod = method;
                  _isOTPStep = false;
                });
              },
            ),
            SizedBox(height: 1.h),

            // البريد أو الهاتف
            if (_loginMethod == AuthMethod.email)
              EmailInputField(controller: _emailController)
            else
              PhoneInputField(controller: _phoneController),
            SizedBox(height: 1.h),

            // كلمة المرور
            PasswordInputField(
              controller: _passwordController,
              hintText: 'كلمة المرور',
              isNumeric: false,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'كلمة المرور مطلوبة';
                }
                if (value.length < 6) {
                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                }
                return null;
              },
            ),
            SizedBox(height: 0.5.h),

            // تذكرني ونسيت كلمة المرور
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      activeColor: AssyrianTheme.primaryGold,
                    ),
                    Text(
                      'تذكرني',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/forgot-password'),
                  child: Text(
                    'نسيت كلمة المرور؟',
                    style: TextStyle(
                      color: AssyrianTheme.primaryGold,
                      fontSize: 10.sp,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),

            // زر تسجيل الدخول
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AssyrianTheme.primaryGold,
                  foregroundColor: AssyrianTheme.deepBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading)
LoadingWidget(size: 16)
                    else
                      Icon(Icons.login_rounded, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 1.h),

            // فاصل
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    'أو',
                    style: TextStyle(
                      color: AssyrianTheme.deepBlue,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),

            // زر تسجيل الدخول بـ Google
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AssyrianTheme.deepBlue,
                  side: BorderSide(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  backgroundColor: AssyrianTheme.ivoryWhite.withValues(
                    alpha: 0.1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                ),
                icon: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Image.asset(
                    'assets/images/google_logo.png',
                    width: 20.w,
                    height: 20.h,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.g_mobiledata_rounded,
                        size: 20.sp,
                        color: Colors.red,
                      );
                    },
                  ),
                ),
                label: Text(
                  'تسجيل الدخول عبر جوجل',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 1.h),

            // إنشاء حساب
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/signup'),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                  children: const [
                    TextSpan(text: 'ليس لديك حساب؟ '),
                    TextSpan(
                      text: 'إنشاء حساب جديد',
                      style: TextStyle(
                        color: AssyrianTheme.primaryGold,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
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

  Widget _buildCredentialLoginStepLandscape() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0.5.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              'تسجيل الدخول',
              style: AssyrianTheme.bodyStyle.copyWith(fontSize: 12.sp),
            ),
            SizedBox(height: 0.5.h),
            AuthMethodToggleButtons(
              method: _loginMethod,
              onChanged: (m) => setState(() => _loginMethod = m),
            ),
            SizedBox(height: 0.5.h),
            if (_loginMethod == AuthMethod.email)
              EmailInputField(controller: _emailController)
            else
              PhoneInputField(controller: _phoneController),
            SizedBox(height: 0.5.h),
            PasswordInputField(
              controller: _passwordController,
              hintText: 'كلمة المرور',
              isNumeric: false,
            ),
            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                child: Text('تسجيل الدخول'),
              ),
            ),
            SizedBox(height: 2.h),
            // زر Google
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: Icon(
                  Icons.g_mobiledata_rounded,
                  size: 20.sp,
                  color: Colors.red,
                ),
                label: Text('تسجيل الدخول عبر جوجل'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPLoginStep() {
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
            _loginMethod == AuthMethod.email
                ? 'أرسلنا رمز التحقق إلى: ${_emailController.text}'
                : 'أرسلنا رمز التحقق إلى: ${_phoneController.text}',
            style: TextStyle(fontSize: 10.sp, color: AssyrianTheme.deepBlue),
          ),
          SizedBox(height: 1.h),

          OTPInputField(controller: _otpController),
          SizedBox(height: 1.h),

          VerifyButton(
            onPressed: _verifyOTP,
            isLoading: _isLoading,
            text: 'تحقق وتسجيل الدخول',
            icon: Icons.login_rounded,
          ),
          SizedBox(height: 0.5.h),

          TextButton(
            onPressed: _sendOTP,
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
                _otpController.clear();
              });
            },
            child: Text('تغيير طريقة الدخول'),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPLoginStepLandscape() {
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
            onPressed: _verifyOTP,
            isLoading: _isLoading,
            text: 'تحقق وتسجيل الدخول',
            icon: Icons.login_rounded,
          ),
        ],
      ),
    );
  }

  void _signIn() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    if (_loginMethod == AuthMethod.email) {
      // تسجيل الدخول بالبريد
      context.read<AuthBloc>().add(
        SignInRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    } else {
      // تسجيل الدخول بالهاتف - إرسال OTP أولاً
      _sendOTP();
    }
  }

  void _signInWithGoogle() {
    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(GoogleSignInRequested());
  }

  void _sendOTP() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    if (_loginMethod == AuthMethod.email) {
      context.read<AuthBloc>().add(
        SendEmailOTPRequested(
          email: _emailController.text.trim(),
          isSignup: false, // تسجيل الدخول - يجب أن يكون الحساب موجوداً
        ),
      );
    } else {
      context.read<AuthBloc>().add(
        SendPhoneOTPRequested(
          phoneNumber: _phoneController.text.trim(),
          isSignup: false, // تسجيل الدخول - يجب أن يكون الحساب موجوداً
        ),
      );
    }
  }

  void _verifyOTP() {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى إدخال 6 أرقام')));
      return;
    }

    setState(() => _isLoading = true);

    if (_loginMethod == AuthMethod.email) {
      // ملاحظة: تحتاج إضافة VerifyEmailOTPForLogin في BLoC
      // هذا مثال فقط
      context.read<AuthBloc>().add(
        VerifyEmailOTPRequested(
          email: _emailController.text.trim(),
          otpCode: _otpController.text.trim(),
          name: '',
          password: '',
        ),
      );
    } else {
      context.read<AuthBloc>().add(
        VerifyPhoneOTPRequested(
          verificationId: _verificationId,
          smsCode: _otpController.text.trim(),
        ),
      );
    }
  }

  void _handleAuthStateChange(BuildContext context, AuthState state) {
    if (state is EmailOTPSent || state is PhoneOTPSent) {
      setState(() {
        _isLoading = false;
        _isOTPStep = true;
      });
      if (state is PhoneOTPSent) {
        _verificationId = state.verificationId;
      }
      // عرض رسالة للمستخدم
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _loginMethod == AuthMethod.email
                  ? 'تم إرسال رمز التحقق إلى البريد\n\n📧 تحقق من Console'
                  : 'تم إرسال رمز التحقق إلى الهاتف',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (state is AuthAuthenticated) {
      setState(() => _isLoading = false);
      if (mounted && context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/splash', (route) => false);
      }
    } else if (state is AuthError) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getAuthErrorMessage(state.message)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

