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

/// Incoming friend requests (accept/decline) and the friends list.
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
    final ink = context.ink;
    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s24),
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
                builder: (context, requests) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in requests)
                      Padding(
                        key: ValueKey(r.id),
                        padding: const EdgeInsets.only(bottom: InkSpacing.s12),
                        child: PaperCard(
                          padding: const EdgeInsets.all(InkSpacing.s16),
                          child: Row(
                            children: [
                              InkAvatar(
                                id: r.fromUid,
                                imageUrl: r.senderPic,
                                initials: initialsOf(r.senderName),
                                size: 40,
                              ),
                              const SizedBox(width: InkSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.senderName,
                                      style: InkType.bodyStrong(ink.ink),
                                    ),
                                    Text(
                                      'wants to be friends · ${timeAgo(r.timestamp)}',
                                      style: InkType.caption(ink.inkMuted),
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
              const WebSectionLabel('Your friends'),
              WebStreamList<Friend>(
                stream: _friends,
                emptyIcon: LucideIcons.users,
                emptyText: 'No friends yet',
                builder: (context, friends) => LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 520 ? 2 : 1;
                    const gap = InkSpacing.s12;
                    final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final f in friends)
                          SizedBox(
                            key: ValueKey(f.uid),
                            width: width,
                            child: PaperCard(
                              padding: const EdgeInsets.all(InkSpacing.s16),
                              child: Row(
                                children: [
                                  InkAvatar(
                                    id: f.uid,
                                    imageUrl: f.photoURL,
                                    initials: initialsOf(f.displayName),
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
                                          style: InkType.bodyStrong(ink.ink),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(LucideIcons.layoutGrid,
                                                size: 13, color: ink.inkMuted),
                                            const SizedBox(width: 4),
                                            Text('${f.boardCount}',
                                                style: InkType.caption(ink.inkSecondary)),
                                            const SizedBox(width: 12),
                                            Icon(LucideIcons.users,
                                                size: 13, color: ink.inkMuted),
                                            const SizedBox(width: 4),
                                            Text('${f.friendCount}',
                                                style: InkType.caption(ink.inkSecondary)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
