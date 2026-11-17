import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/invitation/board_invitation.dart';
import '../../domain/models/workspace.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../glass/glass_tokens.dart';
import '../glass/glass_widgets.dart';
import '../widgets/web_widgets.dart';
import 'home_shell.dart' show GlassAvatarRing;

/// Pending board and workspace invites, accepted or declined through the
/// same Cloud Functions as the mobile app.
class WebInvitesPage extends StatefulWidget {
  const WebInvitesPage({super.key});

  @override
  State<WebInvitesPage> createState() => _WebInvitesPageState();
}

class _WebInvitesPageState extends State<WebInvitesPage> {
  late final _repo = context.read<WebCompanionRepository>();
  late final Stream<List<BoardInvitation>> _boardInvites = _repo.watchBoardInvites();
  late final Stream<List<WorkspaceInvite>> _workspaceInvites = _repo.watchWorkspaceInvites();

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
                title: 'Invites',
                subtitle: 'Boards and workspaces you were invited to.',
              ),
              const WebSectionLabel('Board invites'),
              WebStreamList<BoardInvitation>(
                stream: _boardInvites,
                emptyIcon: LucideIcons.mailOpen,
                emptyText: 'No board invites',
                emptySubtitle: 'When someone invites you to a board, it shows up here.',
                builder: (context, invites) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < invites.length; i++)
                      GlassEntrance(
                        key: ValueKey('b-${invites[i].id}'),
                        index: i,
                        child: _InviteRow(
                          avatarId: invites[i].fromUid,
                          avatarUrl: invites[i].senderPic,
                          name: invites[i].senderName,
                          text: 'invited you to "${invites[i].boardTitle}" as ${invites[i].targetRole}',
                          time: invites[i].timestamp,
                          onAccept: () => _repo.acceptBoardInvite(invites[i].id),
                          onDecline: () => _repo.declineBoardInvite(invites[i].id),
                          acceptedMessage: 'You joined "${invites[i].boardTitle}".',
                        ),
                      ),
                  ],
                ),
              ),
              const WebSectionLabel('Workspace invites'),
              WebStreamList<WorkspaceInvite>(
                stream: _workspaceInvites,
                emptyIcon: LucideIcons.briefcase,
                emptyText: 'No workspace invites',
                emptySubtitle: 'Workspace invitations from your team appear here.',
                builder: (context, invites) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < invites.length; i++)
                      GlassEntrance(
                        key: ValueKey('w-${invites[i].id}'),
                        index: i,
                        child: _InviteRow(
                          avatarId: invites[i].fromUid,
                          avatarUrl: invites[i].senderPhotoUrl,
                          name: invites[i].senderName,
                          text: 'invited you to the workspace "${invites[i].workspaceName}"',
                          time: invites[i].timestamp,
                          onAccept: () => _repo.acceptWorkspaceInvite(invites[i].id),
                          onDecline: () => _repo.declineWorkspaceInvite(invites[i].id),
                          acceptedMessage: 'You joined "${invites[i].workspaceName}".',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteRow extends StatelessWidget {
  final String avatarId;
  final String? avatarUrl;
  final String name;
  final String text;
  final DateTime time;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final String acceptedMessage;

  const _InviteRow({
    required this.avatarId,
    required this.avatarUrl,
    required this.name,
    required this.text,
    required this.time,
    required this.onAccept,
    required this.onDecline,
    required this.acceptedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassAvatarRing(
          child: InkAvatar(id: avatarId, imageUrl: avatarUrl, initials: initialsOf(name), size: 38),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$name ', style: Glass.strong()),
                    TextSpan(text: text, style: Glass.body()),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(timeAgo(time), style: Glass.small()),
            ],
          ),
        ),
      ],
    );
    final actions = WebAcceptDecline(
      onAccept: onAccept,
      onDecline: onDecline,
      acceptedMessage: acceptedMessage,
      declinedMessage: 'Invite declined.',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Side by side when there is room; stacked on narrow screens.
            if (constraints.maxWidth >= 520) {
              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          },
        ),
      ),
    );
  }
}
