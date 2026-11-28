import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/user_model.dart';
import '../../../domain/services/web_companion_service.dart';

class WebProfileState {
  final UserModel? profile;
  final bool loading;
  final Object? error;

  const WebProfileState({this.profile, this.loading = true, this.error});

  WebProfileState copyWith({
    UserModel? Function()? profile,
    bool? loading,
    Object? Function()? error,
  }) => WebProfileState(
    profile: profile != null ? profile() : this.profile,
    loading: loading ?? this.loading,
    error: error != null ? error() : this.error,
  );
}

/// Manages the signed-in user's profile state and profile edits/avatar uploads
/// for the web companion via [WebCompanionService].
class WebProfileCubit extends Cubit<WebProfileState> {
  final WebCompanionService _service;
  StreamSubscription<UserModel?>? _sub;

  WebProfileCubit({required this._service}) : super(const WebProfileState()) {
    rebind();
  }

  void rebind() {
    _sub?.cancel();
    emit(const WebProfileState());
    _sub = _service.watchMyProfile().listen(
      (profile) {
        if (!isClosed) {
          emit(
            state.copyWith(
              profile: () => profile,
              loading: false,
              error: () => null,
            ),
          );
        }
      },
      onError: (Object error) {
        if (!isClosed) {
          emit(state.copyWith(loading: false, error: () => error));
        }
      },
    );
  }

  Future<void> updateProfile({required String name, required String bio}) =>
      _service.updateProfile(name: name, bio: bio);

  Future<void> uploadProfilePhoto(
    Uint8List bytes, {
    required String filename,
  }) => _service.uploadProfilePhoto(bytes, filename: filename);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
