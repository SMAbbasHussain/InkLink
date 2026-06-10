import 'dart:async';
import 'dart:developer' as developer;

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
      developer.log('AuthCheckRequested: currentUser=${authService.currentUser?.uid}', name: 'AuthBloc');
      final user = authService.currentUser;
      if (user != null) {
        await authService.onAuthenticated(user);
        developer.log('AuthCheckRequested: emitting Authenticated', name: 'AuthBloc');
        emit(_toAuthenticated(user));
      } else {
        developer.log('AuthCheckRequested: emitting Unauthenticated', name: 'AuthBloc');
        emit(Unauthenticated());
      }
    });

    // Listen for auth state changes (sign-in from another device, etc.)
    _authSub = authService.user.listen((user) {
      developer.log('_authSub: authStateChanges fired, user=${user?.uid}', name: 'AuthBloc');
      if (user != null) {
        add(AuthenticatedUserAvailable(user));
      } else {
        add(SignedOut());
      }
    });

    on<LoginRequested>((event, emit) async {
      developer.log('LoginRequested: start', name: 'AuthBloc');
      emit(AuthLoading());
      try {
        final user = await authService.signIn(event.email, event.password);
        developer.log('LoginRequested: signIn returned user=${user?.uid}', name: 'AuthBloc');
        if (user == null) {
          emit(Unauthenticated());
          return;
        }
        await authService.onAuthenticated(user);
        developer.log('LoginRequested: emitting Authenticated', name: 'AuthBloc');
        emit(_toAuthenticated(user));
      } catch (e) {
        developer.log('LoginRequested: caught error=$e', name: 'AuthBloc');
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
      developer.log('GoogleSignInRequested: start', name: 'AuthBloc');
      emit(AuthLoading());
      try {
        final user = await authService.signInWithGoogle();
        developer.log('GoogleSignInRequested: signInWithGoogle returned user=${user?.uid}', name: 'AuthBloc');

        if (user != null) {
          developer.log('GoogleSignInRequested: calling onAuthenticated', name: 'AuthBloc');
          await authService.onAuthenticated(user);
          developer.log('GoogleSignInRequested: onAuthenticated done, emitting Authenticated', name: 'AuthBloc');
          emit(_toAuthenticated(user, fallbackName: 'Creator'));
        } else {
          developer.log('GoogleSignInRequested: user was null (cancelled)', name: 'AuthBloc');
          emit(Unauthenticated());
        }
      } catch (e) {
        developer.log('GoogleSignInRequested: caught error=$e', name: 'AuthBloc');
        emit(AuthError("Login failed: ${e.toString()}"));
        emit(Unauthenticated());
      }
    });

    on<LogoutRequested>((event, emit) async {
      developer.log('LogoutRequested: start', name: 'AuthBloc');
      await authService.signOut();
      developer.log('LogoutRequested: emitting Unauthenticated', name: 'AuthBloc');
      emit(Unauthenticated());
    });

    on<AuthenticatedUserAvailable>((event, emit) async {
      developer.log('AuthenticatedUserAvailable: uid=${event.user.uid}, state is Authenticated=${state is Authenticated}', name: 'AuthBloc');
      if (state is Authenticated || state is AuthLoading) {
        developer.log('AuthenticatedUserAvailable: skipping (state=${state.runtimeType})', name: 'AuthBloc');
        return;
      }
      try {
        await authService.onAuthenticated(event.user);
        developer.log('AuthenticatedUserAvailable: emitting Authenticated', name: 'AuthBloc');
        emit(_toAuthenticated(event.user));
      } catch (e) {
        developer.log('AuthenticatedUserAvailable: error=$e', name: 'AuthBloc');
        emit(AuthError(e.toString()));
      }
    });

    on<SignedOut>((event, emit) async {
      developer.log('SignedOut: emitting Unauthenticated', name: 'AuthBloc');
      emit(Unauthenticated());
    });
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
