import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/presence/presence_service.dart';
import '../../../domain/services/profile/profile_service.dart';
import '../bloc/profile_bloc.dart';
import 'profile_screen.dart';

Route<void> buildProfileRoute(BuildContext context, {required String userId}) {
  return MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (_) => ProfileBloc(
        profileService: context.read<ProfileService>(),
        presenceService: context.read<PresenceService>(),
      )..add(LoadProfile(userId)),
      child: ProfileScreen(userId: userId),
    ),
  );
}
