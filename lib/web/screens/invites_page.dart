import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/theme/ink_colors.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/sticky_note.dart';
import '../bloc/web_social_cubit.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';
import 'web_shell_nav.dart';

/// Pending board and workspace invites as the phone shows them: tilted
/// sticky notes with Decline / Accept (same Cloud Functions as mobile).
class WebInvitesPage extends StatelessWidget {
  const WebInvitesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final social = context.read<WebSocialCubit>();
    final state = context.watch<WebSocialCubit>().state;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        const WebPageHeader(
          title: 'Invites',
          subtitle: 'Boards and workspaces you were invited to.',
        ),
        const WebSectionLabel('Board invites'),
        if (state.boardInvitesError != null)
          WebErrorBox(message: webErrorText(state.boardInvitesError!))
        else if (state.boardInvitesLoading)
          const WebLoading()
        else if (state.boardInvites.isEmpty)
          const WebEmptyHint(
            icon: LucideIcons.mail,
            text: 'No board invites',
            subtitle: 'When someone invites you to a board, it shows up here.',
          )
        else
          _StickyGrid(
            children: [
              for (var i = 0; i < state.boardInvites.length; i++)
                _InviteNote(
                  key: ValueKey('b-${state.boardInvites[i].id}'),
                  index: i,
                  color: InkColors.stickyButter,
                  avatarId: state.boardInvites[i].fromUid,
                  avatarUrl: state.boardInvites[i].senderPic,
                  name: state.boardInvites[i].senderName,
                  text: 'invited you to "${state.boardInvites[i].boardTitle}"',
                  detail:
                      'as ${state.boardInvites[i].targetRole} · '
                      '${timeAgo(state.boardInvites[i].timestamp)}',
                  onAccept: () =>
                      social.acceptBoardInvite(state.boardInvites[i].id),
                  onDecline: () =>
                      social.declineBoardInvite(state.boardInvites[i].id),
                  acceptedMessage:
                      'You joined "${state.boardInvites[i].boardTitle}".',
                ),
            ],
          ),
        const SizedBox(height: InkSpacing.s24),
        const WebSectionLabel('Workspace invites'),
        if (state.workspaceInvitesError != null)
          WebErrorBox(message: webErrorText(state.workspaceInvitesError!))
        else if (state.workspaceInvitesLoading)
          const WebLoading()
        else if (state.workspaceInvites.isEmpty)
          const WebEmptyHint(
            icon: LucideIcons.briefcase,
            text: 'No workspace invites',
            subtitle: 'Workspace invitations from your team appear here.',
          )
        else
          _StickyGrid(
            children: [
              for (var i = 0; i < state.workspaceInvites.length; i++)
                _InviteNote(
                  key: ValueKey('w-${state.workspaceInvites[i].id}'),
                  index: i,
                  color: InkColors.stickySky,
                  avatarId: state.workspaceInvites[i].fromUid,
                  avatarUrl: state.workspaceInvites[i].senderPhotoUrl,
                  name: state.workspaceInvites[i].senderName,
                  text:
                      'invited you to "${state.workspaceInvites[i].workspaceName}"',
                  detail:
                      'Workspace · '
                      '${timeAgo(state.workspaceInvites[i].timestamp)}',
                  onAccept: () => social.acceptWorkspaceInvite(
                    state.workspaceInvites[i].id,
                  ),
                  onDecline: () => social.declineWorkspaceInvite(
                    state.workspaceInvites[i].id,
                  ),
                  acceptedMessage:
                      'You joined "${state.workspaceInvites[i].workspaceName}".',
                ),
            ],
          ),
      ],
    );
  }
}

/// Sticky notes side by side, wrapping to new rows.
class _StickyGrid extends StatelessWidget {
  final List<Widget> children;
  const _StickyGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = InkSpacing.s24;
        final columns = (constraints.maxWidth / 340).floor().clamp(1, 3);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _InviteNote extends StatelessWidget {
  final int index;
  final Color color;
  final String avatarId;
  final String? avatarUrl;
  final String name;
  final String text;
  final String detail;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final String acceptedMessage;

  const _InviteNote({
    super.key,
    required this.index,
    required this.color,
    required this.avatarId,
    required this.avatarUrl,
    required this.name,
    required this.text,
    required this.detail,
    required this.onAccept,
    required this.onDecline,
    required this.acceptedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.stickyInkFor(color);
    // Alternate a slight tilt, as the phone does.
    final angleDeg = index.isEven ? 3.0 : -3.0;
    return Padding(
      padding: const EdgeInsets.all(InkSpacing.s8),
      child: Transform.rotate(
        angle: angleDeg * 3.1415926535 / 180,
        child: StickyNote(
          color: color,
          showTape: true,
          padding: const EdgeInsets.all(InkSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkAvatar(
                    imageUrl: avatarUrl,
                    initials: initialsOf(name),
                    id: avatarId,
                    size: 44,
                  ),
                  const SizedBox(width: InkSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: InkType.bodyStrong(ink)),
                        Text(text, style: InkType.cardTitle(ink)),
                        const SizedBox(height: InkSpacing.s4),
                        Text(detail, style: InkType.caption(ink)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: InkSpacing.s16),
              WebAcceptDecline(
                expand: true,
                onAccept: onAccept,
                onDecline: onDecline,
                acceptedMessage: acceptedMessage,
                declinedMessage: 'Invite declined.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
