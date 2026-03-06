import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/social_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

// States
abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

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

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final SocialRepository socialRepo;
  ProfileBloc({required this.socialRepo}) : super(ProfileInitial()) {
    on<LoadProfile>((event, emit) async {
      emit(ProfileLoading());
      try {
        final currentUid = FirebaseAuth.instance.currentUser!.uid;
        final userData = await socialRepo.getUserById(event.userId);

        if (userData == null) {
          emit(ProfileError("User not found"));
          return;
        }

        final bool isSelf = currentUid == event.userId;
        bool isFriend = false;
        if (!isSelf) {
          isFriend = await socialRepo.checkFriendshipStatus(event.userId);
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
          await socialRepo.updateUserProfile(name: event.name, bio: event.bio);

          // Refresh the local state with new data
          add(LoadProfile(FirebaseAuth.instance.currentUser!.uid));
        } catch (e) {
          emit(ProfileError("Failed to update profile"));
          // Restore previous state if error occurs
          emit(currentState);
        }
      }
    });
  }
}
