abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final String userName;
  final String uid;
  final String? email;
  final String? photoUrl;

  Authenticated(this.userName, {required this.uid, this.email, this.photoUrl});
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
