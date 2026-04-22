import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../domain/services/presence/presence_service.dart';

class FriendPresenceAvatar extends StatelessWidget {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final Gradient gradient;
  final bool isDark;

  const FriendPresenceAvatar({
    super.key,
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.gradient,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final presenceService = context.read<PresenceService>();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: photoUrl == null ? gradient : null,
            image: photoUrl != null
                ? DecorationImage(
                    image: NetworkImage(photoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: photoUrl == null
              ? Center(
                  child: Text(
                    displayName.isEmpty ? '?' : displayName[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: StreamBuilder<UserPresence>(
            stream: presenceService.watchUserPresence(userId),
            initialData: UserPresence.offline(),
            builder: (context, snapshot) {
              final isOnline = snapshot.data?.isOnline == true;
              return Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? Colors.green : Colors.grey,
                  border: Border.all(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    width: 2,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
