import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/repositories/auth/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  Authenticated _toAuthenticated(User user, {String? fallbackName}) {
    return Authenticated(
      user.displayName ?? fallbackName ?? 'User',
      uid: user.uid,
      email: user.email,
      photoUrl: user.photoURL,
    );
  }

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      // FIX: Listen to the user stream instead of single snapshot
      // This ensures app updates when user logs in from another device/tab
      await emit.forEach<User?>(
        authRepository.user,
        onData: (user) {
          if (user != null) {
            authRepository.syncFcmToken();
            return _toAuthenticated(user);
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
        if (user == null) {
          emit(Unauthenticated());
          return;
        }
        emit(_toAuthenticated(user));
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
        if (user == null) {
          emit(Unauthenticated());
          return;
        }
        emit(_toAuthenticated(user, fallbackName: event.name));
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
          emit(_toAuthenticated(user, fallbackName: 'Creator'));
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
