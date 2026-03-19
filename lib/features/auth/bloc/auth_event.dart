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
