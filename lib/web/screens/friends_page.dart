import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/friends/friend.dart';
import '../../domain/models/friends/friend_request.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../glass/glass_tokens.dart';
import '../glass/glass_widgets.dart';
import '../widgets/web_widgets.dart';
import 'home_shell.dart' show GlassAvatarRing;

/// Incoming friend requests (accept/decline) and the friends list.
class WebFriendsPage extends StatefulWidget {
  const WebFriendsPage({super.key});

  @override
  State<WebFriendsPage> createState() => _WebFriendsPageState();
}

class _WebFriendsPageState extends State<WebFriendsPage> {
  late final _repo = context.read<WebCompanionRepository>();
  late final Stream<List<FriendRequest>> _requests = _repo.watchIncomingFriendRequests();
  late final Stream<List<Friend>> _friends = _repo.watchFriends();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      children: [
        WebReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WebPageHeader(
                title: 'Friends',
                subtitle: 'To add new friends or chat, use the InkLink mobile app.',
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
                    for (var i = 0; i < requests.length; i++)
                      GlassEntrance(
                        key: ValueKey(requests[i].id),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassPanel(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                GlassAvatarRing(
                                  child: InkAvatar(
                                    id: requests[i].fromUid,
                                    imageUrl: requests[i].senderPic,
                                    initials: initialsOf(requests[i].senderName),
                                    size: 38,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(requests[i].senderName, style: Glass.strong()),
                                      Text(
                                        'wants to be friends · ${timeAgo(requests[i].timestamp)}',
                                        style: Glass.small(),
                                      ),
                                    ],
                                  ),
                                ),
                                WebAcceptDecline(
                                  onAccept: () => _repo.acceptFriendRequest(requests[i].id),
                                  onDecline: () => _repo.declineFriendRequest(requests[i].id),
                                  acceptedMessage:
                                      'You and ${requests[i].senderName} are now friends.',
                                  declinedMessage: 'Request declined.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const WebSectionLabel('Your friends'),
              WebStreamList<Friend>(
                stream: _friends,
                emptyIcon: LucideIcons.users,
                emptyText: 'No friends yet',
                emptySubtitle: 'Add friends in the InkLink mobile app.',
                builder: (context, friends) => LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 520 ? 2 : 1;
                    const gap = 12.0;
                    final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var i = 0; i < friends.length; i++)
                          SizedBox(
                            key: ValueKey(friends[i].uid),
                            width: width,
                            child: GlassEntrance(index: i, child: _FriendCard(friend: friends[i])),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FriendCard extends StatefulWidget {
  final Friend friend;
  const _FriendCard({required this.friend});

  @override
  State<_FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<_FriendCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: Glass.fast,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        child: GlassPanel(
          padding: const EdgeInsets.all(16),
          borderColor: _hover ? Glass.borderBright : null,
          shadow: _hover ? Glass.shadow : null,
          child: Row(
            children: [
              GlassAvatarRing(
                child: InkAvatar(
                  id: f.uid,
                  imageUrl: f.photoURL,
                  initials: initialsOf(f.displayName),
                  size: 42,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Glass.strong(),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(LucideIcons.layoutGrid, size: 13, color: Glass.textMuted),
                        const SizedBox(width: 4),
                        Text('${f.boardCount}', style: Glass.small(color: Glass.textSecondary)),
                        const SizedBox(width: 12),
                        const Icon(LucideIcons.users, size: 13, color: Glass.textMuted),
                        const SizedBox(width: 4),
                        Text('${f.friendCount}', style: Glass.small(color: Glass.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
