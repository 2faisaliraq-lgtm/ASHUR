/// ويدجتات مشتركة لصفحات المصادقة مع OTP
/// يمكن استخدام هذه الويدجتات في SignupPage و LoginPage و ForgotPasswordPage
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/loading_widget.dart';

/// Enum لطريقة المصادقة
enum AuthMethod { email, phone }

/// ويدجت أزرار التبديل بين البريد والهاتف
class AuthMethodToggleButtons extends StatelessWidget {
  final AuthMethod method;
  final Function(AuthMethod) onChanged;

  const AuthMethodToggleButtons({
    super.key,
    required this.method,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(AuthMethod.email),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                decoration: BoxDecoration(
                  color: method == AuthMethod.email
                      ? AssyrianTheme.primaryGold
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'البريد الإلكتروني',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: method == AuthMethod.email
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(AuthMethod.phone),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                decoration: BoxDecoration(
                  color: method == AuthMethod.phone
                      ? AssyrianTheme.primaryGold
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'رقم الهاتف',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: method == AuthMethod.phone
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ويدجت حقل إدخال البريد الإلكتروني
class EmailInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const EmailInputField({super.key, required this.controller, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'البريد الإلكتروني *',
          style: AssyrianTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 10.sp,
          ),
        ),
        SizedBox(height: 0.2.h),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16.sp,
            color: AssyrianTheme.deepBlue,
          ),
          decoration: InputDecoration(
            hintText: 'أدخل البريد الإلكتروني',
            prefixIcon: Container(
              margin: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Icon(
                Icons.email_outlined,
                size: 16.sp,
                color: AssyrianTheme.primaryGold,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(
                color: AssyrianTheme.primaryGold,
                width: 2.5,
              ),
            ),
            filled: true,
            fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 40.w,
              vertical: 1.h,
            ),
            hintStyle: TextStyle(
              color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
              fontFamily: 'Cairo',
              fontSize: 16.sp,
            ),
          ),
          validator:
              validator ??
              (value) {
                if (value == null || value.isEmpty) {
                  return 'البريد الإلكتروني مطلوب';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'البريد الإلكتروني غير صحيح';
                }
                return null;
              },
        ),
      ],
    );
  }
}

/// ويدجت حقل إدخال رقم الهاتف
class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const PhoneInputField({super.key, required this.controller, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'رقم الهاتف *',
          style: AssyrianTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 10.sp,
          ),
        ),
        SizedBox(height: 0.2.h),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.phone,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16.sp,
            color: AssyrianTheme.deepBlue,
          ),
          decoration: InputDecoration(
            hintText: '+964 770 000 0000',
            prefixIcon: Container(
              margin: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Icon(
                Icons.phone,
                size: 16.sp,
                color: AssyrianTheme.primaryGold,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(
                color: AssyrianTheme.primaryGold,
                width: 2.5,
              ),
            ),
            filled: true,
            fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 40.w,
              vertical: 1.h,
            ),
            hintStyle: TextStyle(
              color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
              fontFamily: 'Cairo',
              fontSize: 16.sp,
            ),
          ),
          validator:
              validator ??
              (value) {
                if (value == null || value.isEmpty) {
                  return 'رقم الهاتف مطلوب';
                }
                final cleanedValue = value.replaceAll(
                  RegExp(r'[\s\-\(\)]'),
                  '',
                );
                // يقبل: 07xxxxxxxxx (11 خانة) أو 9647xxxxxxxx (12 خانة) أو +9647xxxxxxxx
                if (!RegExp(
                  r'^(0[1-9][0-9]{9}|964[1-9][0-9]{9}|\+964[1-9][0-9]{9}|[1-9][0-9]{9,14})$',
                ).hasMatch(cleanedValue)) {
                  return 'رقم الهاتف غير صحيح';
                }
                return null;
              },
        ),
      ],
    );
  }
}

/// ويدجت حقل إدخال رمز OTP
class OTPInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const OTPInputField({super.key, required this.controller, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'رمز التحقق *',
          style: AssyrianTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 10.sp,
          ),
        ),
        SizedBox(height: 0.2.h),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: '******',
            prefixIcon: Icon(Icons.sms),
            counterText: '',
          ),
          validator:
              validator ??
              (value) {
                if (value == null || value.length != 6) {
                  return 'يرجى إدخال 6 أرقام';
                }
                return null;
              },
        ),
      ],
    );
  }
}

/// ويدجت كلمة المرور
class PasswordInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isNumeric;
  final String? Function(String?)? validator;

  const PasswordInputField({
    super.key,
    required this.controller,
    this.hintText = 'كلمة المرور',
    this.isNumeric = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$hintText *',
          style: AssyrianTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 10.sp,
          ),
        ),
        SizedBox(height: 0.2.h),
        TextFormField(
          controller: controller,
          obscureText: true,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16.sp,
            color: AssyrianTheme.deepBlue,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Container(
              margin: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 16.sp,
                color: AssyrianTheme.primaryGold,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(
                color: AssyrianTheme.primaryGold,
                width: 2.5,
              ),
            ),
            filled: true,
            fillColor: AssyrianTheme.ivoryWhite.withValues(alpha: 0.08),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 40.w,
              vertical: 1.h,
            ),
            hintStyle: TextStyle(
              color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
              fontFamily: 'Cairo',
              fontSize: 16.sp,
            ),
          ),
          validator:
              validator ??
              (value) {
                if (value == null || value.isEmpty) {
                  return '$hintText مطلوبة';
                }
                if (value.length < 6) {
                  return '$hintText يجب أن تكون 6 أرقام على الأقل';
                }
                if (isNumeric && !RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return '$hintText يجب أن تتكون من أرقام فقط';
                }
                return null;
              },
        ),
      ],
    );
  }
}

/// ويدجت زر إرسال OTP
class SendOTPButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const SendOTPButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AssyrianTheme.primaryGold,
          foregroundColor: AssyrianTheme.deepBlue,
          disabledBackgroundColor: AssyrianTheme.primaryGold.withValues(
            alpha: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
LoadingWidget(size: 16)
            else
              Icon(Icons.security_rounded, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              'إرسال رمز التحقق',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ويدجت زر التحقق
class VerifyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final String? text;
  final IconData? icon;

  const VerifyButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AssyrianTheme.primaryGold,
          foregroundColor: AssyrianTheme.deepBlue,
          disabledBackgroundColor: AssyrianTheme.primaryGold.withValues(
            alpha: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          padding: EdgeInsets.symmetric(vertical: 8.h),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
LoadingWidget(size: 16)
            else
              Icon(icon ?? Icons.verified_rounded, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              text ?? 'تحقق',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

