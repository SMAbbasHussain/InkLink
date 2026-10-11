import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);
}

class RegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  RegisterRequested(this.name, this.email, this.password);
}

class AuthCheckRequested extends AuthEvent {}

class GoogleSignInRequested extends AuthEvent {}

class LogoutRequested extends AuthEvent {}

class AuthenticatedUserAvailable extends AuthEvent {
  final User user;
  AuthenticatedUserAvailable(this.user);
}

class SignedOut extends AuthEvent {}

/// Dispatches a password reset email to the specified address (FR01-07)
class PasswordResetRequested extends AuthEvent {
  final String email;
  PasswordResetRequested(this.email);
}

/// Dispatches an email verification link to current unverified user (FR01-05)
class SendEmailVerificationRequested extends AuthEvent {}

/// Checks whether user has completed email verification (FR01-06)
class CheckEmailVerificationRequested extends AuthEvent {}

/// Cascade deletes the user account and purges user data (FR02-06, FR02-07)
class DeleteAccountRequested extends AuthEvent {
  final String? password;
  DeleteAccountRequested({this.password});
}

