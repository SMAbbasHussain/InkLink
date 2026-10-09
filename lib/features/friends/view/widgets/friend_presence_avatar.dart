import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/services/presence/presence_service.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_initials.dart';

class FriendPresenceAvatar extends StatelessWidget {
  final String userId;
  final String displayName;
  final String? photoUrl;

  const FriendPresenceAvatar({
    super.key,
    required this.userId,
    required this.displayName,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final presenceService = context.read<PresenceService>();

    return StreamBuilder<UserPresence>(
      stream: presenceService.watchUserPresence(userId),
      initialData: UserPresence.offline(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data?.isOnline == true;
        return InkAvatar(
          imageUrl: photoUrl,
          initials: inkInitialsFor(displayName),
          id: userId,
          size: 50,
          online: isOnline,
        );
      },
    );
  }
}
