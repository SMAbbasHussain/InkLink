import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/services/auth/auth_session_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthSessionService authService;
  StreamSubscription<User?>? _authSub;

  Authenticated _toAuthenticated(User user, {String? fallbackName}) {
    return Authenticated(
      user.displayName ?? fallbackName ?? 'User',
      uid: user.uid,
      email: user.email,
      photoUrl: user.photoURL,
    );
  }

  AuthBloc({required this.authService}) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      print('[AUTH] AuthCheckRequested: currentUser=${authService.currentUser?.uid}');
      final user = authService.currentUser;
      if (user != null) {
        await authService.onAuthenticated(user);
        print('[AUTH] AuthCheckRequested: emitting Authenticated');
        emit(_toAuthenticated(user));
      } else {
        print('[AUTH] AuthCheckRequested: emitting Unauthenticated');
        emit(Unauthenticated());
      }
    });

    // Listen for auth state changes (sign-in from another device, etc.)
    _authSub = authService.user.listen((user) {
      print('[AUTH] _authSub: authStateChanges fired, user=${user?.uid}');
      if (user != null) {
        add(AuthenticatedUserAvailable(user));
      } else {
        add(SignedOut());
      }
    });

    on<LoginRequested>((event, emit) async {
      print('[AUTH] LoginRequested: start');
      emit(AuthLoading());
      try {
        final user = await authService.signIn(event.email, event.password);
        print('[AUTH] LoginRequested: signIn returned user=${user?.uid}');
        if (user == null) {
          emit(Unauthenticated());
          return;
        }
        await authService.onAuthenticated(user);
        print('[AUTH] LoginRequested: emitting Authenticated');
        emit(_toAuthenticated(user));
      } catch (e) {
        print('[AUTH] LoginRequested: caught error=$e');
        emit(AuthError(e.toString()));
      }
    });

    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authService.signUp(
          event.name,
          event.email,
          event.password,
        );
        if (user == null) {
          emit(Unauthenticated());
          return;
        }
        await authService.onAuthenticated(user);
        emit(_toAuthenticated(user, fallbackName: event.name));
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<GoogleSignInRequested>((event, emit) async {
      print('[AUTH] GoogleSignInRequested: start');
      emit(AuthLoading());
      try {
        final user = await authService.signInWithGoogle();
        print('[AUTH] GoogleSignInRequested: signInWithGoogle returned user=${user?.uid}');

        if (user != null) {
          print('[AUTH] GoogleSignInRequested: calling onAuthenticated');
          await authService.onAuthenticated(user);
          print('[AUTH] GoogleSignInRequested: onAuthenticated done, emitting Authenticated');
          emit(_toAuthenticated(user, fallbackName: 'Creator'));
        } else {
          print('[AUTH] GoogleSignInRequested: user was null (cancelled)');
          emit(Unauthenticated());
        }
      } catch (e) {
        print('[AUTH] GoogleSignInRequested: caught error=$e');
        emit(AuthError("Login failed: ${e.toString()}"));
        emit(Unauthenticated());
      }
    });

    on<LogoutRequested>((event, emit) async {
      print('[AUTH] LogoutRequested: start');
      await authService.signOut();
      print('[AUTH] LogoutRequested: emitting Unauthenticated');
      emit(Unauthenticated());
    });

    on<AuthenticatedUserAvailable>((event, emit) async {
      print('[AUTH] AuthenticatedUserAvailable: uid=${event.user.uid}, state is Authenticated=${state is Authenticated}');
      if (state is Authenticated || state is AuthLoading) {
        print('[AUTH] AuthenticatedUserAvailable: skipping (state=${state.runtimeType})');
        return;
      }
      try {
        await authService.onAuthenticated(event.user);
        print('[AUTH] AuthenticatedUserAvailable: emitting Authenticated');
        emit(_toAuthenticated(event.user));
      } catch (e) {
        print('[AUTH] AuthenticatedUserAvailable: error=$e');
        emit(AuthError(e.toString()));
      }
    });

    on<SignedOut>((event, emit) async {
      print('[AUTH] SignedOut: emitting Unauthenticated');
      emit(Unauthenticated());
    });
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
