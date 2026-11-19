import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_otp_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // حالة التبديل بين البريد والهاتف
  AuthMethod _resetMethod = AuthMethod.email;
  bool _isOTPStep = false;
  bool _isOTPSent = false;
  String _verificationId = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
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
                              child: _buildResetFormLandscape(),
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
                            child: _buildResetForm(),
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

  Widget _buildResetForm() {
    if (_isOTPStep) {
      return _buildOTPAndNewPasswordStep();
    }
    return _buildContactInputStep();
  }

  Widget _buildResetFormLandscape() {
    if (_isOTPStep) {
      return _buildOTPAndNewPasswordStepLandscape();
    }
    return _buildContactInputStepLandscape();
  }

  Widget _buildContactInputStep() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 1.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    gradient: AssyrianTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_reset,
                    size: 50.w,
                    color: AssyrianTheme.ivoryWhite,
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),

            Text(
              'نسيت كلمة المرور؟',
              style: AssyrianTheme.titleStyle.copyWith(fontSize: 18.sp),
            ),
            SizedBox(height: 1.h),

            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                'أدخل بريدك الإلكتروني أو رقم هاتفك وسنرسل لك رمز التحقق',
                textAlign: TextAlign.center,
                style: AssyrianTheme.bodyStyle.copyWith(fontSize: 16.sp),
              ),
            ),
            SizedBox(height: 1.h),

            // أزرار التبديل
            AuthMethodToggleButtons(
              method: _resetMethod,
              onChanged: (method) {
                setState(() {
                  _resetMethod = method;
                  _isOTPSent = false;
                  _otpController.clear();
                });
              },
            ),
            SizedBox(height: 1.h),

            // البريد أو الهاتف
            if (_resetMethod == AuthMethod.email)
              EmailInputField(controller: _emailController)
            else
              PhoneInputField(controller: _phoneController),
            SizedBox(height: 1.h),

            // زر إرسال الرمز
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isOTPSent ? null : _sendOTPCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AssyrianTheme.primaryGold,
                  foregroundColor: AssyrianTheme.deepBlue,
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
                          Icon(Icons.send_rounded, size: 20.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'إرسال الرمز',
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

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'العودة لتسجيل الدخول',
                style: TextStyle(color: AssyrianTheme.deepBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInputStepLandscape() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0.5.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Column(
        children: [
          Text(
            'نسيت كلمة المرور؟',
            style: AssyrianTheme.bodyStyle.copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 0.5.h),
          AuthMethodToggleButtons(
            method: _resetMethod,
            onChanged: (m) => setState(() => _resetMethod = m),
          ),
          SizedBox(height: 0.5.h),
          if (_resetMethod == AuthMethod.email)
            EmailInputField(controller: _emailController)
          else
            PhoneInputField(controller: _phoneController),
          SizedBox(height: 0.5.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isOTPSent ? null : _sendOTPCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
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
                        Icon(Icons.send_rounded, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'إرسال',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPAndNewPasswordStep() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 1.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Column(
        children: [
          Text(
            'أدخل رمز التحقق وكلمة المرور الجديدة',
            style: AssyrianTheme.titleStyle.copyWith(fontSize: 16.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 0.5.h),

          Text(
            _resetMethod == AuthMethod.email
                ? 'أرسلنا رمز التحقق إلى: ${_emailController.text}'
                : 'أرسلنا رمز التحقق إلى: ${_phoneController.text}',
            style: TextStyle(fontSize: 10.sp, color: AssyrianTheme.deepBlue),
          ),
          SizedBox(height: 1.h),

          OTPInputField(controller: _otpController),
          SizedBox(height: 1.h),

          // حقل كلمة المرور الجديدة
          PasswordInputField(
            controller: _newPasswordController,
            hintText: 'كلمة المرور الجديدة',
            isNumeric: true,
          ),
          SizedBox(height: 1.h),

          // حقل تأكيد كلمة المرور
          PasswordInputField(
            controller: _confirmPasswordController,
            hintText: 'تأكيد كلمة المرور',
            isNumeric: true,
          ),
          SizedBox(height: 1.h),

          VerifyButton(
            onPressed: _verifyOTPAndResetPassword,
            isLoading: _isLoading,
            text: 'تحقق وإعادة تعيين كلمة المرور',
            icon: Icons.lock_reset,
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
                _newPasswordController.clear();
                _confirmPasswordController.clear();
              });
            },
            child: Text('تغيير البريد/الهاتف'),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPAndNewPasswordStepLandscape() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0.5.w),
      decoration: AssyrianTheme.assyrianBorder,
      child: Column(
        children: [
          Text(
            'أدخل رمز التحقق وكلمة المرور الجديدة',
            style: AssyrianTheme.bodyStyle.copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 0.5.h),
          OTPInputField(controller: _otpController),
          SizedBox(height: 0.5.h),
          PasswordInputField(
            controller: _newPasswordController,
            hintText: 'كلمة المرور الجديدة',
            isNumeric: true,
          ),
          SizedBox(height: 0.5.h),
          PasswordInputField(
            controller: _confirmPasswordController,
            hintText: 'تأكيد كلمة المرور',
            isNumeric: true,
          ),
          SizedBox(height: 0.5.h),
          VerifyButton(
            onPressed: _verifyOTPAndResetPassword,
            isLoading: _isLoading,
            text: 'تحقق وإعادة تعيين',
            icon: Icons.lock_reset,
          ),
        ],
      ),
    );
  }

  void _sendOTPCode() {
    // التحقق من الحقل فقط
    bool isValid = false;
    String errorMessage = '';

    if (_resetMethod == AuthMethod.email) {
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

    if (_resetMethod == AuthMethod.email) {
      context.read<AuthBloc>().add(
        SendEmailOTPRequested(
          email: _emailController.text.trim(),
          isSignup: false, // نسيان كلمة المرور - يجب أن يكون الحساب موجوداً
        ),
      );
    } else {
      context.read<AuthBloc>().add(
        SendPhoneOTPRequested(
          phoneNumber: _phoneController.text.trim(),
          isSignup: false, // نسيان كلمة المرور - يجب أن يكون الحساب موجوداً
        ),
      );
    }
  }

  void _verifyOTPAndResetPassword() {
    // التحقق من رمز OTP
    final otpError = validateOTP(_otpController.text.trim());
    if (otpError != null) {
      _showErrorSnackBar(otpError);
      return;
    }

    // التحقق من كلمة المرور (6 أرقام)
    final passwordError = validateNumericPassword(_newPasswordController.text.trim());
    if (passwordError != null) {
      _showErrorSnackBar(passwordError);
      return;
    }

    // التحقق من تأكيد كلمة المرور
    final confirmError = validateConfirmPassword(
      _confirmPasswordController.text.trim(),
      _newPasswordController.text.trim(),
    );
    if (confirmError != null) {
      _showErrorSnackBar(confirmError);
      return;
    }

    setState(() => _isLoading = true);

    if (_resetMethod == AuthMethod.email) {
      context.read<AuthBloc>().add(
        VerifyEmailOTPAndResetPasswordRequested(
          email: _emailController.text.trim(),
          otpCode: _otpController.text.trim(),
          newPassword: _newPasswordController.text.trim(),
        ),
      );
    } else {
      // التحقق من وجود verificationId قبل الاستخدام
      if (_verificationId.isEmpty) {
        _showErrorSnackBar(
          'خطأ: معرف التحقق غير موجود. يرجى إعادة إرسال الرمز',
        );
        setState(() => _isLoading = false);
        return;
      }

      context.read<AuthBloc>().add(
        VerifyPhoneOTPAndResetPasswordRequested(
          verificationId: _verificationId,
          smsCode: _otpController.text.trim(),
          newPassword: _newPasswordController.text.trim(),
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
      if (mounted) {
        _showSuccessSnackBar(
          _resetMethod == AuthMethod.email
              ? 'تم إرسال رمز التحقق إلى البريد (${_emailController.text})\n\n📧 تحقق من Console في وضع التطوير'
              : 'تم إرسال رمز التحقق إلى الهاتف (${_phoneController.text})',
        );
      }
    } else if (state is PasswordResetSuccessfully) {
      _showSuccessSnackBar(
        '✅ تم إعادة تعيين كلمة المرور بنجاح!\n\n'
        'يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة.',
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
            arguments: {
              'method': _resetMethod == AuthMethod.email ? 'email' : 'phone',
              'value': _resetMethod == AuthMethod.email
                  ? _emailController.text
                  : _phoneController.text,
            },
          );
        }
      });
    } else if (state is AuthError) {
      // التحقق من نوع الخطأ
      final errorMessage = state.message.toLowerCase();

      if (errorMessage.contains('not found') ||
          errorMessage.contains('غير موجود') ||
          errorMessage.contains('لا يوجد')) {
        // الحساب غير موجود - عرض SnackBar مع خيار إنشاء حساب
        _showAccountNotFoundSnackBar();
      } else {
        // عرض رسالة الخطأ العادية
        _showErrorSnackBar(state.message);
      }
    }
  }

  // عرض SnackBar للنجاح
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 24.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  // عرض SnackBar للخطأ
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 24.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  // عرض SnackBar عند عدم وجود الحساب
  void _showAccountNotFoundSnackBar() {
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
                Icon(Icons.info_outline, color: Colors.white, size: 24.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'الحساب غير موجود',
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
              _resetMethod == AuthMethod.email
                  ? 'لا يوجد حساب مرتبط بـ ${_emailController.text}'
                  : 'لا يوجد حساب مرتبط بـ ${_phoneController.text}',
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
                    // نقل البريد/الهاتف إلى شاشة تسجيل الدخول
                    Navigator.of(context).pushReplacementNamed(
                      '/login',
                      arguments: {
                        'method': _resetMethod == AuthMethod.email
                            ? 'email'
                            : 'phone',
                        'value': _resetMethod == AuthMethod.email
                            ? _emailController.text.trim()
                            : _phoneController.text.trim(),
                      },
                    );
                  },
                  child: Text(
                    'تسجيل الدخول',
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
                    // نقل البريد/الهاتف إلى شاشة إنشاء الحساب
                    Navigator.of(context).pushReplacementNamed(
                      '/signup',
                      arguments: {
                        'method': _resetMethod == AuthMethod.email
                            ? 'email'
                            : 'phone',
                        'value': _resetMethod == AuthMethod.email
                            ? _emailController.text.trim()
                            : _phoneController.text.trim(),
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'إنشاء حساب',
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
        backgroundColor: Colors.orange.shade700,
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

