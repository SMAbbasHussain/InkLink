import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/repositories/auth/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      // FIX: Listen to the user stream instead of single snapshot
      // This ensures app updates when user logs in from another device/tab
      await emit.forEach<User?>(
        authRepository.user,
        onData: (user) {
          if (user != null) {
            return Authenticated(user.displayName ?? "User");
          } else {
            return Unauthenticated();
          }
        },
        onError: (error, stackTrace) {
          return AuthError(error.toString());
        },
      );
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authRepository.signIn(event.email, event.password);
        emit(Authenticated(user?.displayName ?? "User"));
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authRepository.signUp(
          event.name,
          event.email,
          event.password,
        );
        emit(Authenticated(user?.displayName ?? event.name));
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<GoogleSignInRequested>((event, emit) async {
      emit(AuthLoading()); // AppView will show spinner/splash
      try {
        final user = await authRepository.signInWithGoogle();

        if (user != null) {
          // Success: User picked an account and Firebase authed
          emit(Authenticated(user.displayName ?? "Creator"));
        } else {
          // Cancelled: User closed the selector
          emit(Unauthenticated());
        }
      } catch (e) {
        emit(AuthError("Login failed: ${e.toString()}"));
        emit(Unauthenticated());
      }
    });

    on<LogoutRequested>((event, emit) async {
      await authRepository.signOut();
      emit(Unauthenticated());
    });
  }
}
