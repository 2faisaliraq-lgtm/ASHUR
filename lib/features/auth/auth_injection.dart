// ملف حقن التبعيات لقسم المصادقة
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '../../core/email/email_normalization_service.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/check_if_account_exists_usecase.dart';
import 'domain/usecases/get_current_user_usecase.dart';
import 'domain/usecases/google_sign_in_usecase.dart';
import 'domain/usecases/reset_password_by_email_usecase.dart';
import 'domain/usecases/reset_password_by_phone_usecase.dart';
import 'domain/usecases/send_email_otp_usecase.dart';
import 'domain/usecases/send_phone_otp_usecase.dart';
import 'domain/usecases/sign_in_usecase.dart';
import 'domain/usecases/sign_out_usecase.dart';
import 'domain/usecases/sign_up_usecase.dart';
import 'domain/usecases/verify_email_otp_usecase.dart';
import 'domain/usecases/verify_phone_otp_usecase.dart';
import 'presentation/bloc/auth_bloc.dart';

final sl = GetIt.instance;

/// حقن التبعيات لقسم المصادقة
// ignore: avoid_classes_with_only_static_members
class AuthInjection {
  static Future<void> init() async {
    // Repository
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(firebaseAuth: sl<FirebaseAuth>()),
    );

    // Use cases - Email
    sl.registerLazySingleton(() => SignInUseCase(sl<AuthRepository>()));
    sl.registerLazySingleton(() => SignUpUseCase(sl<AuthRepository>()));
    sl.registerLazySingleton(() => SignOutUseCase(sl<AuthRepository>()));
    sl.registerLazySingleton(() => GetCurrentUserUseCase(sl<AuthRepository>()));
    sl.registerLazySingleton(() => GoogleSignInUseCase(sl<AuthRepository>()));

    // Use cases - Phone OTP
    sl.registerLazySingleton(() => SendPhoneOTPUseCase(sl<AuthRepository>()));
    sl.registerLazySingleton(() => VerifyPhoneOTPUseCase(sl<AuthRepository>()));
    sl.registerLazySingleton(
      () => ResetPasswordByPhoneUseCase(sl<AuthRepository>()),
    );

    // Use cases - Email OTP
    sl.registerLazySingleton(() => SendEmailOTPUseCase(sl<AuthRepository>()));
    sl.registerLazySingleton(() => VerifyEmailOTPUseCase(sl<AuthRepository>()));
    sl.registerLazySingleton(
      () => ResetPasswordByEmailUseCase(sl<AuthRepository>()),
    );

    // Use cases - Check Account Exists
    sl.registerLazySingleton(
      () => CheckIfAccountExistsUseCase(sl<AuthRepository>()),
    );

    // BLoC - register as a singleton so all parts of the app share the same instance
    sl.registerLazySingleton(
      () => AuthBloc(
        signInUseCase: sl<SignInUseCase>(),
        signUpUseCase: sl<SignUpUseCase>(),
        signOutUseCase: sl<SignOutUseCase>(),
        getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
        googleSignInUseCase: sl<GoogleSignInUseCase>(),
        sendPhoneOTPUseCase: sl<SendPhoneOTPUseCase>(),
        verifyPhoneOTPUseCase: sl<VerifyPhoneOTPUseCase>(),
        resetPasswordByPhoneUseCase: sl<ResetPasswordByPhoneUseCase>(),
        sendEmailOTPUseCase: sl<SendEmailOTPUseCase>(),
        verifyEmailOTPUseCase: sl<VerifyEmailOTPUseCase>(),
        resetPasswordByEmailUseCase: sl<ResetPasswordByEmailUseCase>(),
        checkIfAccountExistsUseCase: sl<CheckIfAccountExistsUseCase>(),
      ),
    );
  }
}
