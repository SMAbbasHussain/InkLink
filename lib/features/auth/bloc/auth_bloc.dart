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

  static Authenticated _toAuthenticated(User user, {String? fallbackName}) {
    final isPassword =
        user.providerData.any((p) => p.providerId == 'password');
    return Authenticated(
      user.displayName ?? fallbackName ?? 'User',
      uid: user.uid,
      email: user.email,
      photoUrl: user.photoURL,
      isPasswordProvider: isPassword,
    );
  }

  static AuthState _resolveInitialState(AuthSessionService authService) {
    final user = authService.currentUser;
    if (user == null) {
      return AuthInitial();
    }
    final isPasswordProvider =
        user.providerData.any((p) => p.providerId == 'password');
    if (isPasswordProvider && !user.emailVerified) {
      return AuthInitial();
    }
    return _toAuthenticated(user);
  }

  AuthBloc({required this.authService}) : super(_resolveInitialState(authService)) {
    on<AuthCheckRequested>((event, emit) async {
      developer.log('AuthCheckRequested: currentUser=${authService.currentUser?.uid}', name: 'AuthBloc');
      final user = authService.currentUser;
      if (user != null) {
        final isPasswordProvider = user.providerData.any((p) => p.providerId == 'password');
        if (isPasswordProvider && !user.emailVerified) {
          final status = await authService.reloadAndCheckEmailVerified();
          if (status == EmailVerificationStatus.unverified) {
            final refreshedUser = authService.currentUser ?? user;
            developer.log('AuthCheckRequested: unverified password account, emitting AuthEmailUnverified', name: 'AuthBloc');
            emit(AuthEmailUnverified(user: refreshedUser, email: refreshedUser.email ?? ''));
            return;
          }
          if (status == EmailVerificationStatus.unknown) {
            // Transient failure — never treat it as "unverified" (that would
            // trap verified users on the verification screen); surface a
            // retryable error instead.
            developer.log('AuthCheckRequested: verification status unknown', name: 'AuthBloc');
            emit(AuthError('Could not check your account status. Please check your connection and try again.'));
            return;
          }
        }
        final refreshedUser = authService.currentUser ?? user;
        if (state is! Authenticated) {
          developer.log('AuthCheckRequested: emitting Authenticated', name: 'AuthBloc');
          emit(_toAuthenticated(refreshedUser));
        }
        await authService.onAuthenticated(refreshedUser);
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

        // Enforce verified users only for email/password provider (FR01-06)
        final isPasswordProvider = user.providerData.any((p) => p.providerId == 'password');
        if (isPasswordProvider && !user.emailVerified) {
          final status = await authService.reloadAndCheckEmailVerified();
          final refreshedUser = authService.currentUser ?? user;
          if (status == EmailVerificationStatus.unverified) {
            developer.log('LoginRequested: user email unverified', name: 'AuthBloc');
            emit(AuthEmailUnverified(user: refreshedUser, email: refreshedUser.email ?? event.email));
            return;
          }
          if (status == EmailVerificationStatus.unknown) {
            developer.log('LoginRequested: verification status unknown', name: 'AuthBloc');
            emit(AuthError('Could not check your account status. Please check your connection and try again.'));
            return;
          }
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

        // New email/password registrations require verification (FR01-05, FR01-06)
        if (!user.emailVerified) {
          developer.log('RegisterRequested: emitting AuthEmailUnverified', name: 'AuthBloc');
          emit(AuthEmailUnverified(user: user, email: event.email));
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

    on<DeleteAccountRequested>((event, emit) async {
      developer.log('DeleteAccountRequested: start', name: 'AuthBloc');
      emit(AuthDeletingAccount());
      try {
        await authService.deleteAccount(password: event.password);
        developer.log('DeleteAccountRequested: account successfully deleted', name: 'AuthBloc');
        emit(Unauthenticated());
      } catch (e) {
        developer.log('DeleteAccountRequested: caught error=$e', name: 'AuthBloc');
        emit(AuthError(e.toString()));
      }
    });

    on<AuthenticatedUserAvailable>((event, emit) async {
      developer.log('AuthenticatedUserAvailable: uid=${event.user.uid}, state is Authenticated=${state is Authenticated}', name: 'AuthBloc');
      if (state is Authenticated ||
          state is AuthLoading ||
          state is AuthEmailUnverified ||
          state is AuthDeletingAccount) {
        developer.log('AuthenticatedUserAvailable: skipping (state=${state.runtimeType})', name: 'AuthBloc');
        return;
      }
      final isPasswordProvider = event.user.providerData.any((p) => p.providerId == 'password');
      if (isPasswordProvider && !event.user.emailVerified) {
        emit(AuthEmailUnverified(user: event.user, email: event.user.email ?? ''));
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

    on<PasswordResetRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authService.sendPasswordResetEmail(event.email);
        emit(PasswordResetSent(event.email));
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<SendEmailVerificationRequested>((event, emit) async {
      final current = state;
      if (current is AuthEmailUnverified) {
        emit(AuthEmailUnverified(
          user: current.user,
          email: current.email,
          isChecking: true,
        ));
      }
      try {
        await authService.sendEmailVerification();
        if (current is AuthEmailUnverified) {
          emit(AuthEmailUnverified(
            user: current.user,
            email: current.email,
            message: 'Verification link resent! Please check your inbox and spam folder.',
            isChecking: false,
          ));
        }
      } catch (e) {
        if (current is AuthEmailUnverified) {
          emit(AuthEmailUnverified(
            user: current.user,
            email: current.email,
            message: e.toString(),
            isChecking: false,
          ));
        } else {
          emit(AuthError(e.toString()));
        }
      }
    });

    on<CheckEmailVerificationRequested>((event, emit) async {
      final current = state;
      if (current is AuthEmailUnverified) {
        emit(AuthEmailUnverified(
          user: current.user,
          email: current.email,
          isChecking: true,
        ));
      } else {
        emit(AuthLoading());
      }

      try {
        final status = await authService.reloadAndCheckEmailVerified();
        final user = authService.currentUser;
        if (user != null && status == EmailVerificationStatus.verified) {
          developer.log('CheckEmailVerificationRequested: verified! Authenticating...', name: 'AuthBloc');
          await authService.onAuthenticated(user);
          emit(_toAuthenticated(user));
        } else if (user != null && status == EmailVerificationStatus.unknown) {
          developer.log('CheckEmailVerificationRequested: check failed (transient)', name: 'AuthBloc');
          emit(AuthEmailUnverified(
            user: user,
            email: user.email ?? (current is AuthEmailUnverified ? current.email : ''),
            message: 'Unable to check verification. Please check your connection and try again.',
            isChecking: false,
          ));
        } else if (user != null) {
          developer.log('CheckEmailVerificationRequested: not verified yet', name: 'AuthBloc');
          emit(AuthEmailUnverified(
            user: user,
            email: user.email ?? (current is AuthEmailUnverified ? current.email : ''),
            message: 'Email not verified yet. Please click the link in your email first.',
            isChecking: false,
          ));
        } else {
          emit(Unauthenticated());
        }
      } catch (e) {
        developer.log('CheckEmailVerificationRequested: error=$e', name: 'AuthBloc');
        if (current is AuthEmailUnverified) {
          emit(AuthEmailUnverified(
            user: current.user,
            email: current.email,
            message: 'Unable to check verification. Please try again.',
            isChecking: false,
          ));
        } else {
          emit(AuthError(e.toString()));
        }
      }
    });
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
