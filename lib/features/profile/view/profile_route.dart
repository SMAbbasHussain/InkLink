import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/profile/profile_repository.dart';
import '../bloc/profile_bloc.dart';
import 'profile_screen.dart';

Route<void> buildProfileRoute(BuildContext context, {required String userId}) {
  return MaterialPageRoute(
    builder: (_) => BlocProvider(
      create: (_) =>
          ProfileBloc(profileRepo: context.read<ProfileRepository>())
            ..add(LoadProfile(userId)),
      child: ProfileScreen(userId: userId),
    ),
  );
}
