import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/invitation/board_invitation.dart';
import '../../domain/models/workspace.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/paper_card.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';

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
      padding: const EdgeInsets.all(InkSpacing.s24),
      children: [
        const WebPageHeader(title: 'Invites', subtitle: 'Boards and workspaces you were invited to.'),
        const WebSectionLabel('Board invites'),
        WebStreamList<BoardInvitation>(
          stream: _boardInvites,
          emptyIcon: LucideIcons.mailOpen,
          emptyText: 'No board invites',
          builder: (context, invites) => Column(
            children: [
              for (final i in invites)
                _InviteRow(
                  key: ValueKey('b-${i.id}'),
                  avatarId: i.fromUid,
                  avatarUrl: i.senderPic,
                  name: i.senderName,
                  text: 'invited you to "${i.boardTitle}" as ${i.targetRole}',
                  time: i.timestamp,
                  onAccept: () => _repo.acceptBoardInvite(i.id),
                  onDecline: () => _repo.declineBoardInvite(i.id),
                  acceptedMessage: 'You joined "${i.boardTitle}".',
                ),
            ],
          ),
        ),
        const WebSectionLabel('Workspace invites'),
        WebStreamList<WorkspaceInvite>(
          stream: _workspaceInvites,
          emptyIcon: LucideIcons.briefcase,
          emptyText: 'No workspace invites',
          builder: (context, invites) => Column(
            children: [
              for (final i in invites)
                _InviteRow(
                  key: ValueKey('w-${i.id}'),
                  avatarId: i.fromUid,
                  avatarUrl: i.senderPhotoUrl,
                  name: i.senderName,
                  text: 'invited you to the workspace "${i.workspaceName}"',
                  time: i.timestamp,
                  onAccept: () => _repo.acceptWorkspaceInvite(i.id),
                  onDecline: () => _repo.declineWorkspaceInvite(i.id),
                  acceptedMessage: 'You joined "${i.workspaceName}".',
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
    super.key,
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
    final ink = context.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s12),
      child: PaperCard(
        padding: const EdgeInsets.all(InkSpacing.s16),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          runSpacing: InkSpacing.s12,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkAvatar(id: avatarId, imageUrl: avatarUrl, initials: initialsOf(name), size: 40),
                const SizedBox(width: InkSpacing.s12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: '$name ', style: InkType.bodyStrong(ink.ink)),
                        TextSpan(text: text, style: InkType.body(ink.inkSecondary)),
                      ])),
                      const SizedBox(height: 2),
                      Text(timeAgo(time), style: InkType.caption(ink.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
            WebAcceptDecline(
              onAccept: onAccept,
              onDecline: onDecline,
              acceptedMessage: acceptedMessage,
              declinedMessage: 'Invite declined.',
            ),
          ],
        ),
      ),
    );
  }
}
