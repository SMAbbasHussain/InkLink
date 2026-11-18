import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/friends/friend.dart';
import '../../domain/models/friends/friend_request.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/paper_card.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';

/// Incoming friend requests (accept/decline) and the friends list, as the
/// phone shows them: paper cards with avatars.
class WebFriendsPage extends StatefulWidget {
  const WebFriendsPage({super.key});

  @override
  State<WebFriendsPage> createState() => _WebFriendsPageState();
}

class _WebFriendsPageState extends State<WebFriendsPage> {
  late final _repo = context.read<WebCompanionRepository>();
  late final Stream<List<FriendRequest>> _requests = _repo
      .watchIncomingFriendRequests();
  late final Stream<List<Friend>> _friends = _repo.watchFriends();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.s16,
        InkSpacing.s24,
        InkSpacing.s16,
        110,
      ),
      children: [
        WebReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WebPageHeader(
                title: 'Friends',
                subtitle:
                    'To add new friends or chat, use the InkLink mobile app.',
              ),
              const WebSectionLabel('Friend requests'),
              WebStreamList<FriendRequest>(
                stream: _requests,
                emptyIcon: LucideIcons.userPlus,
                emptyText: 'No pending requests',
                emptySubtitle: 'New friend requests will appear here.',
                builder: (context, requests) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in requests)
                      Padding(
                        key: ValueKey(r.id),
                        padding: const EdgeInsets.only(bottom: InkSpacing.s12),
                        child: PaperCard(
                          padding: const EdgeInsets.all(InkSpacing.s12),
                          child: Row(
                            children: [
                              InkAvatar(
                                imageUrl: r.senderPic,
                                initials: initialsOf(r.senderName),
                                id: r.fromUid,
                                size: 48,
                              ),
                              const SizedBox(width: InkSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.senderName,
                                      style: InkType.bodyStrong(tokens.ink),
                                    ),
                                    Text(
                                      'Wants to be friends · '
                                      '${timeAgo(r.timestamp)}',
                                      style: InkType.caption(tokens.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              WebAcceptDecline(
                                onAccept: () => _repo.acceptFriendRequest(r.id),
                                onDecline: () =>
                                    _repo.declineFriendRequest(r.id),
                                acceptedMessage:
                                    'You and ${r.senderName} are now friends.',
                                declinedMessage: 'Request declined.',
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: InkSpacing.s16),
              const WebSectionLabel('Your friends'),
              WebStreamList<Friend>(
                stream: _friends,
                emptyIcon: LucideIcons.users,
                emptyText: 'No friends yet',
                emptySubtitle: 'Add friends in the InkLink mobile app.',
                builder: (context, friends) => PaperCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: InkSpacing.s12,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < friends.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: tokens.glassStroke),
                        _FriendRow(
                          key: ValueKey(friends[i].uid),
                          friend: friends[i],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  final Friend friend;
  const _FriendRow({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final f = friend;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s12),
      child: Row(
        children: [
          InkAvatar(
            imageUrl: f.photoURL,
            initials: initialsOf(f.displayName),
            id: f.uid,
            size: 44,
          ),
          const SizedBox(width: InkSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InkType.bodyStrong(tokens.ink),
                ),
                Text(
                  '${f.boardCount} '
                  '${f.boardCount == 1 ? 'board' : 'boards'} · '
                  '${f.friendCount} '
                  '${f.friendCount == 1 ? 'friend' : 'friends'}',
                  style: InkType.caption(tokens.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
