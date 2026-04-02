import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/profile/profile_repository.dart';

// States
abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfilePhotoUploading extends ProfileState {
  final Map<String, dynamic> userData;
  final bool isSelf;
  final bool isFriend;
  ProfilePhotoUploading({
    required this.userData,
    required this.isSelf,
    required this.isFriend,
  });
}

class ProfileLoaded extends ProfileState {
  final Map<String, dynamic> userData;
  final bool isSelf;
  final bool isFriend;
  ProfileLoaded({
    required this.userData,
    required this.isSelf,
    required this.isFriend,
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

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository profileRepo;

  ProfileBloc({required this.profileRepo}) : super(ProfileInitial()) {
    on<LoadProfile>((event, emit) async {
      emit(ProfileLoading());
      try {
        final currentUid = profileRepo.getCurrentUserId();
        if (currentUid == null) {
          emit(ProfileError('User not authenticated'));
          return;
        }

        final userData = await profileRepo.getUserById(event.userId);

        if (userData == null) {
          emit(ProfileError("User not found"));
          return;
        }

        final bool isSelf = currentUid == event.userId;
        bool isFriend = false;
        if (!isSelf) {
          isFriend = await profileRepo.checkFriendshipStatus(event.userId);
        }

        emit(
          ProfileLoaded(userData: userData, isSelf: isSelf, isFriend: isFriend),
        );
      } catch (e) {
        emit(ProfileError(e.toString()));
      }
    });

    on<UpdateProfileRequested>((event, emit) async {
      final currentState = state;
      if (currentState is ProfileLoaded) {
        emit(ProfileLoading()); // Show spinner
        try {
          await profileRepo.updateUserProfile(name: event.name, bio: event.bio);

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
          ),
        );

        try {
          // Call repository to upload image and get the new photoURL
          final photoUrl = await profileRepo.uploadProfilePhoto(
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
        await profileRepo.updateUserProfile(name: event.name, bio: event.bio);

        String? photoUrl;
        final shouldUploadPhoto =
            event.imageData != null &&
            event.imageData!.isNotEmpty &&
            event.filename != null &&
            event.filename!.isNotEmpty;

        if (shouldUploadPhoto) {
          photoUrl = await profileRepo.uploadProfilePhoto(
            imageData: event.imageData!,
            filename: event.filename!,
          );
        }

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
}
