import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/models/web_account.dart';
import '../domain/services/web_companion_service.dart';

class WebAuthState {
  final WebAccount? user;
  final int revision;

  const WebAuthState({required this.user, this.revision = 0});

  WebAuthState copyWith({WebAccount? Function()? user, int? revision}) =>
      WebAuthState(
        user: user != null ? user() : this.user,
        revision: revision ?? this.revision,
      );
}

/// Manages web companion authentication state and delegates all auth actions
/// to [WebCompanionService].
class WebAuthCubit extends Cubit<WebAuthState> {
  final WebCompanionService _service;
  StreamSubscription<WebAccount?>? _authSub;

  WebAuthCubit({required WebCompanionService service})
    : _service = service,
      super(WebAuthState(user: service.currentUser)) {
    _authSub = _service.authChanges.listen((account) {
      emit(
        WebAuthState(
          user: _service.currentUser ?? account,
          revision: state.revision + 1,
        ),
      );
    });
  }

  WebAccount? get currentUser => _service.currentUser ?? state.user;

  Future<void> signInWithEmail(String email, String password) =>
      _service.signInWithEmail(email, password);

  Future<void> signInWithGoogle() => _service.signInWithGoogle();

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) => _service.signUpWithEmail(name: name, email: email, password: password);

  Future<void> sendPasswordReset(String email) =>
      _service.sendPasswordReset(email);

  Future<void> resendVerificationEmail() => _service.resendVerificationEmail();

  Future<bool> reloadEmailVerified() async {
    final verified = await _service.reloadEmailVerified();
    emit(
      WebAuthState(user: _service.currentUser, revision: state.revision + 1),
    );
    return verified;
  }

  Future<void> signOut() => _service.signOut();

  Future<void> deleteAccount() => _service.deleteAccount();

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
