import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/friends/friend.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_dialog.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../../ui/widgets/paper_card.dart';
import '../bloc/web_social_cubit.dart';
import '../core/web_formatters.dart';
import '../ui/widgets/web_feedback_widgets.dart';
import '../ui/widgets/web_page_layout.dart';
import 'web_shell_nav.dart';

/// Incoming friend requests (accept/decline), the friends list with block and
/// unfriend actions, and the blocked users list — the phone's friends
/// workflow, without chat (chat is mobile-only).
class WebFriendsPage extends StatefulWidget {
  const WebFriendsPage({super.key});

  @override
  State<WebFriendsPage> createState() => _WebFriendsPageState();
}

class _WebFriendsPageState extends State<WebFriendsPage> {
  WebSocialCubit get _social => context.read<WebSocialCubit>();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final state = context.watch<WebSocialCubit>().state;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        WebReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebPageHeader(
                title: 'Friends',
                subtitle:
                    'Add people by email, answer requests and manage blocks. '
                    'Chat stays in the mobile app.',
                trailing: InkButton.primary(
                  label: 'Add friend',
                  compact: true,
                  expand: false,
                  icon: const Icon(LucideIcons.userPlus, size: 16),
                  onPressed: () => showAddFriendDialog(context),
                ),
              ),
              const WebSectionLabel('Friend requests'),
              if (state.friendRequestsError != null)
                WebErrorBox(message: webErrorText(state.friendRequestsError!))
              else if (state.friendRequestsLoading)
                const WebLoading()
              else if (state.friendRequests.isEmpty)
                const WebEmptyHint(
                  icon: LucideIcons.userPlus,
                  text: 'No pending requests',
                  subtitle: 'New friend requests will appear here.',
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in state.friendRequests)
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
                                onAccept: () =>
                                    _social.acceptFriendRequest(r.id),
                                onDecline: () =>
                                    _social.declineFriendRequest(r.id),
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
              const SizedBox(height: InkSpacing.s16),
              const WebSectionLabel('Your friends'),
              if (state.friendsError != null)
                WebErrorBox(message: webErrorText(state.friendsError!))
              else if (state.friendsLoading)
                const WebLoading()
              else if (state.friends.isEmpty)
                const WebEmptyHint(
                  icon: LucideIcons.users,
                  text: 'No friends yet',
                  subtitle: 'Add someone by email to get started.',
                )
              else
                PaperCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: InkSpacing.s12,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < state.friends.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: tokens.glassStroke),
                        _FriendRow(
                          key: ValueKey(state.friends[i].uid),
                          friend: state.friends[i],
                          onBlock: () => _block(state.friends[i]),
                          onUnfriend: () => _unfriend(state.friends[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: InkSpacing.s16),
              const WebSectionLabel('Blocked users'),
              if (state.blockedUsersError != null)
                WebErrorBox(message: webErrorText(state.blockedUsersError!))
              else if (state.blockedUsersLoading)
                const WebLoading()
              else if (state.blockedUsers.isEmpty)
                const WebEmptyHint(
                  icon: LucideIcons.shieldBan,
                  text: 'Nobody is blocked',
                  subtitle:
                      'Blocked people cannot message or add you as a friend.',
                )
              else
                PaperCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: InkSpacing.s12,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < state.blockedUsers.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: tokens.glassStroke),
                        _BlockedRow(
                          key: ValueKey(state.blockedUsers[i].uid),
                          friend: state.blockedUsers[i],
                          onUnblock: () => _unblock(state.blockedUsers[i]),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _block(Friend friend) async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Block ${friend.displayName}?',
      message:
          'They are removed from your friends and cannot send you requests '
          'or messages.',
      confirmLabel: 'Block',
    );
    if (!confirmed || !mounted) return;
    try {
      await _social.blockUser(friend.uid);
      if (mounted) {
        showWebMessage(context, '${friend.displayName} is blocked.');
      }
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _unfriend(Friend friend) async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Remove ${friend.displayName}?',
      message: 'You will no longer be friends on InkLink.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    try {
      await _social.unfriend(friend.uid);
      if (mounted) {
        showWebMessage(context, '${friend.displayName} was removed.');
      }
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _unblock(Friend friend) async {
    try {
      await _social.unblockUser(friend.uid);
      if (mounted) {
        showWebMessage(context, '${friend.displayName} is unblocked.');
      }
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }
}

/// "Add friend" by email: the phone's exact-email lookup, then a request.
Future<void> showAddFriendDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _AddFriendDialog(),
);

class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog();

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _email = TextEditingController();
  List<Friend>? _results;
  final _sent = <String>{};
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _email.text.trim();
    if (query.isEmpty || !query.contains('@')) {
      setState(() => _error = 'Enter the email address they signed up with.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _results = null;
    });
    try {
      final results = await context.read<WebSocialCubit>().searchUsersByEmail(
        query,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = webErrorText(e);
          _searching = false;
        });
      }
    }
  }

  Future<void> _send(Friend user) async {
    try {
      await context.read<WebSocialCubit>().sendFriendRequest(user.uid);
      if (!mounted) return;
      setState(() => _sent.add(user.uid));
      showWebMessage(context, 'Request sent to ${user.displayName}.');
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final results = _results;
    return InkDialog(
      title: 'Add a friend',
      icon: LucideIcons.userPlus,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkTextField(
              controller: _email,
              labelText: 'Their email',
              hintText: 'name@example.com',
              errorText: _error,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              enabled: !_searching,
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: InkSpacing.s12),
            Align(
              alignment: Alignment.centerRight,
              child: InkButton.primary(
                label: 'Search',
                compact: true,
                expand: false,
                isLoading: _searching,
                onPressed: _searching ? null : _search,
              ),
            ),
            if (results != null && results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: InkSpacing.s12),
                child: Text(
                  'No InkLink account uses that email.',
                  style: InkType.body(tokens.inkSecondary),
                ),
              ),
            for (final user in results ?? const <Friend>[])
              Padding(
                padding: const EdgeInsets.only(top: InkSpacing.s12),
                child: Row(
                  children: [
                    InkAvatar(
                      imageUrl: user.photoURL,
                      initials: initialsOf(user.displayName),
                      id: user.uid,
                      size: 40,
                    ),
                    const SizedBox(width: InkSpacing.s12),
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: InkType.bodyStrong(tokens.ink),
                      ),
                    ),
                    _sent.contains(user.uid)
                        ? Text(
                            'Requested',
                            style: InkType.caption(tokens.inkMuted),
                          )
                        : InkButton.secondary(
                            label: 'Send request',
                            compact: true,
                            expand: false,
                            onPressed: () => _send(user),
                          ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Close',
          compact: true,
          expand: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  final Friend friend;
  final VoidCallback onBlock;
  final VoidCallback onUnfriend;

  const _FriendRow({
    super.key,
    required this.friend,
    required this.onBlock,
    required this.onUnfriend,
  });

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
          PopupMenuButton<String>(
            tooltip: 'Friend options',
            icon: Icon(
              LucideIcons.ellipsisVertical,
              size: 18,
              color: tokens.ink,
            ),
            onSelected: (value) {
              if (value == 'unfriend') onUnfriend();
              if (value == 'block') onBlock();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'unfriend',
                child: Text('Remove friend', style: InkType.body(tokens.ink)),
              ),
              PopupMenuItem(
                value: 'block',
                child: Text('Block', style: InkType.body(tokens.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlockedRow extends StatelessWidget {
  final Friend friend;
  final VoidCallback onUnblock;

  const _BlockedRow({super.key, required this.friend, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s12),
      child: Row(
        children: [
          InkAvatar(
            imageUrl: friend.photoURL,
            initials: initialsOf(friend.displayName),
            id: friend.uid,
            size: 40,
          ),
          const SizedBox(width: InkSpacing.s12),
          Expanded(
            child: Text(
              friend.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: InkType.bodyStrong(tokens.ink),
            ),
          ),
          InkButton.secondary(
            label: 'Unblock',
            compact: true,
            expand: false,
            onPressed: onUnblock,
          ),
        ],
      ),
    );
  }
}
