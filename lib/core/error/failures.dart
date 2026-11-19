import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {

  const Failure(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure({String message = 'خطأ في الخادم'}) : super(message);
}

class CacheFailure extends Failure {
  const CacheFailure({String message = 'خطأ في التخزين المحلي'})
    : super(message);
}

class NetworkFailure extends Failure {
  const NetworkFailure({String message = 'لا يوجد اتصال بالإنترنت'})
    : super(message);
}

class ValidationFailure extends Failure {
  const ValidationFailure({String message = 'خطأ في التحقق من البيانات'})
    : super(message);
}

// Auth failures
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

// Google Sign In failures
class GoogleSignInFailure extends Failure {
  const GoogleSignInFailure(super.message);
}
