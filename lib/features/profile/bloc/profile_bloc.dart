import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/services/profile/profile_service.dart';

// States
abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfilePhotoUploading extends ProfileState {
  final Map<String, dynamic> userData;
  final bool isSelf;
  final bool isFriend;
  final bool isBlocked;
  final int friendCount;
  final int boardCount;
  final bool isOnline;
  final DateTime? lastActive;
  ProfilePhotoUploading({
    required this.userData,
    required this.isSelf,
    required this.isFriend,
    required this.isBlocked,
    this.friendCount = 0,
    this.boardCount = 0,
    this.isOnline = false,
    this.lastActive,
  });
}

class ProfileLoaded extends ProfileState {
  final Map<String, dynamic> userData;
  final bool isSelf;
  final bool isFriend;
  final bool isBlocked;
  final int friendCount;
  final int boardCount;
  final bool isOnline;
  final DateTime? lastActive;
  ProfileLoaded({
    required this.userData,
    required this.isSelf,
    required this.isFriend,
    required this.isBlocked,
    this.friendCount = 0,
    this.boardCount = 0,
    this.isOnline = false,
    this.lastActive,
  });
}

class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}

// Events
abstract class ProfileEvent {}

class LoadProfile extends ProfileEvent {
  final String userId;
  LoadProfile(this.userId);
}

class UpdateProfileRequested extends ProfileEvent {
  final String name;
  final String bio;
  UpdateProfileRequested({required this.name, required this.bio});
}

class UploadProfilePhotoRequested extends ProfileEvent {
  final String imageData; // Base64 encoded image
  final String filename;
  UploadProfilePhotoRequested({
    required this.imageData,
    required this.filename,
  });
}

class SaveProfileChangesRequested extends ProfileEvent {
  final String name;
  final String bio;
  final String? imageData;
  final String? filename;

  SaveProfileChangesRequested({
    required this.name,
    required this.bio,
    this.imageData,
    this.filename,
  });
}

class _ProfileDocUpdated extends ProfileEvent {
  final Map<String, dynamic> userData;
  _ProfileDocUpdated(this.userData);
}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileService profileService;
  StreamSubscription<Map<String, dynamic>?>? _liveProfileSubscription;

  ProfileBloc({required this.profileService}) : super(ProfileInitial()) {
    on<LoadProfile>((event, emit) async {
      emit(ProfileLoading());
      try {
        final profile = await profileService.loadProfile(event.userId);

        emit(
          ProfileLoaded(
            userData: profile.userData,
            isSelf: profile.isSelf,
            isFriend: profile.isFriend,
            isBlocked: profile.isBlocked,
            friendCount: profile.friendCount,
            boardCount: profile.boardCount,
            isOnline: profile.isOnline,
            lastActive: profile.lastActive,
          ),
        );

        await _startLiveProfileListener(event.userId);
      } catch (e) {
        emit(ProfileError(e.toString()));
      }
    });

    on<_ProfileDocUpdated>((event, emit) {
      final currentState = state;

      if (currentState is ProfileLoaded) {
        final mergedUserData = {...currentState.userData, ...event.userData};
        final isOnline = mergedUserData['isOnline'] == true;
        final lastActive = _toDateTime(mergedUserData['lastActive']);

        emit(
          ProfileLoaded(
            userData: mergedUserData,
            isSelf: currentState.isSelf,
            isFriend: currentState.isFriend,
            isBlocked: currentState.isBlocked,
            friendCount: currentState.friendCount,
            boardCount: currentState.boardCount,
            isOnline: isOnline,
            lastActive: lastActive,
          ),
        );
      } else if (currentState is ProfilePhotoUploading) {
        final mergedUserData = {...currentState.userData, ...event.userData};
        final isOnline = mergedUserData['isOnline'] == true;
        final lastActive = _toDateTime(mergedUserData['lastActive']);

        emit(
          ProfilePhotoUploading(
            userData: mergedUserData,
            isSelf: currentState.isSelf,
            isFriend: currentState.isFriend,
            isBlocked: currentState.isBlocked,
            friendCount: currentState.friendCount,
            boardCount: currentState.boardCount,
            isOnline: isOnline,
            lastActive: lastActive,
          ),
        );
      }
    });

    on<UpdateProfileRequested>((event, emit) async {
      final currentState = state;
      if (currentState is ProfileLoaded) {
        emit(ProfileLoading()); // Show spinner
        try {
          await profileService.updateProfile(name: event.name, bio: event.bio);

          // IMPROVEMENT: Instead of reloading the entire profile from Firestore,
          // update the local state immediately with the new values.
          // This is more efficient and provides instant UI feedback.
          // Current approach: add(LoadProfile(...)) - causes unnecessary Firestore read
          // Better approach: emit(ProfileLoaded(...)) with updated userData directly
          final updatedUserData = {...currentState.userData};
          updatedUserData['displayName'] = event.name;
          updatedUserData['bio'] = event.bio;

          emit(
            ProfileLoaded(
              userData: updatedUserData,
              isSelf: currentState.isSelf,
              isFriend: currentState.isFriend,
              isBlocked: currentState.isBlocked,
              friendCount: currentState.friendCount,
              boardCount: currentState.boardCount,
              isOnline: currentState.isOnline,
              lastActive: currentState.lastActive,
            ),
          );
        } catch (e) {
          emit(ProfileError("Failed to update profile"));
          // Restore previous state if error occurs
          emit(currentState);
        }
      }
    });

    on<UploadProfilePhotoRequested>((event, emit) async {
      final currentState = state;
      if (currentState is ProfileLoaded) {
        // Emit uploading state (shows loading indicator while keeping UI responsive)
        emit(
          ProfilePhotoUploading(
            userData: currentState.userData,
            isSelf: currentState.isSelf,
            isFriend: currentState.isFriend,
            isBlocked: currentState.isBlocked,
            friendCount: currentState.friendCount,
            boardCount: currentState.boardCount,
            isOnline: currentState.isOnline,
            lastActive: currentState.lastActive,
          ),
        );

        try {
          // Call repository to upload image and get the new photoURL
          final photoUrl = await profileService.uploadProfilePhoto(
            imageData: event.imageData,
            filename: event.filename,
          );

          // Update local state immediately with the new photoURL
          final updatedUserData = {...currentState.userData};
          updatedUserData['photoURL'] = photoUrl;

          emit(
            ProfileLoaded(
              userData: updatedUserData,
              isSelf: currentState.isSelf,
              isFriend: currentState.isFriend,
              isBlocked: currentState.isBlocked,
              friendCount: currentState.friendCount,
              boardCount: currentState.boardCount,
              isOnline: currentState.isOnline,
              lastActive: currentState.lastActive,
            ),
          );
        } catch (e) {
          emit(ProfileError("Failed to upload photo: ${e.toString()}"));
          // Restore previous state if error occurs
          emit(currentState);
        }
      }
    });

    on<SaveProfileChangesRequested>((event, emit) async {
      final currentState = state;
      if (currentState is! ProfileLoaded) return;

      emit(ProfileLoading());
      try {
        final photoUrl = await profileService.saveProfileChanges(
          name: event.name,
          bio: event.bio,
          imageData: event.imageData,
          filename: event.filename,
        );

        final updatedUserData = {...currentState.userData};
        updatedUserData['displayName'] = event.name;
        updatedUserData['bio'] = event.bio;
        if (photoUrl != null) {
          updatedUserData['photoURL'] = photoUrl;
        }

        emit(
          ProfileLoaded(
            userData: updatedUserData,
            isSelf: currentState.isSelf,
            isFriend: currentState.isFriend,
            isBlocked: currentState.isBlocked,
            friendCount: currentState.friendCount,
            boardCount: currentState.boardCount,
            isOnline: currentState.isOnline,
            lastActive: currentState.lastActive,
          ),
        );
      } catch (e) {
        // Profile text changes (name/bio) were already persisted before photo upload.
        // If photo upload failed, emit state with updated name/bio to preserve those
        // changes in the UI instead of rolling back, then show error.
        final updatedUserData = {...currentState.userData};
        updatedUserData['displayName'] = event.name;
        updatedUserData['bio'] = event.bio;

        emit(
          ProfileLoaded(
            userData: updatedUserData,
            isSelf: currentState.isSelf,
            isFriend: currentState.isFriend,
            isBlocked: currentState.isBlocked,
            friendCount: currentState.friendCount,
            boardCount: currentState.boardCount,
            isOnline: currentState.isOnline,
            lastActive: currentState.lastActive,
          ),
        );
        emit(
          ProfileError(
            'Name and bio updated, but failed to upload photo: ${e.toString()}',
          ),
        );
      }
    });
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;

    try {
      return value.toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  Future<void> _startLiveProfileListener(String userId) async {
    await _liveProfileSubscription?.cancel();
    _liveProfileSubscription = profileService.watchUserById(userId).listen((
      userData,
    ) {
      if (userData != null) {
        add(_ProfileDocUpdated(userData));
      }
    });
  }

  @override
  Future<void> close() async {
    await _liveProfileSubscription?.cancel();
    return super.close();
  }
}
