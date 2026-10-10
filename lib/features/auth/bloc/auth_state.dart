import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final String userName;
  final String uid;
  final String? email;
  final String? photoUrl;
  final bool isPasswordProvider;

  Authenticated(
    this.userName, {
    required this.uid,
    this.email,
    this.photoUrl,
    this.isPasswordProvider = false,
  });
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

/// Emitted when a user has signed in/up with email/password but hasn't verified their email (FR01-05, FR01-06)
class AuthEmailUnverified extends AuthState {
  final User user;
  final String email;
  final String? message;
  final bool isChecking;

  AuthEmailUnverified({
    required this.user,
    required this.email,
    this.message,
    this.isChecking = false,
  });
}

/// Emitted when password reset email has been dispatched (FR01-07)
class PasswordResetSent extends AuthState {
  final String email;
  PasswordResetSent(this.email);
}

/// Emitted while cascade deletion of account and data is in progress
class AuthDeletingAccount extends AuthState {}

