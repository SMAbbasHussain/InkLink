import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/notification/in_app_notification.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/paper_card.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';

/// The in-app notification feed (newest 100, chat messages excluded, as on
/// mobile). Invites and requests are handled on their own pages.
class WebNotificationsPage extends StatefulWidget {
  const WebNotificationsPage({super.key});

  @override
  State<WebNotificationsPage> createState() => _WebNotificationsPageState();
}

class _WebNotificationsPageState extends State<WebNotificationsPage> {
  late final _repo = context.read<WebCompanionRepository>();
  late final Stream<List<InAppNotification>> _stream = _repo
      .watchNotifications();

  Future<void> _delete(InAppNotification n) async {
    try {
      await _repo.deleteNotification(n.id);
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s24),
      children: [
        WebReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WebPageHeader(
                title: 'Notifications',
                subtitle: 'Accept invites and friend requests on their own pages.',
              ),
              WebStreamList<InAppNotification>(
                stream: _stream,
                compactEmpty: false,
                emptyIcon: LucideIcons.bell,
                emptyText: "You're all caught up",
                builder: (context, items) {
                  final now = DateTime.now();
                  final groups = <NotificationGroup, List<InAppNotification>>{};
                  for (final n in items) {
                    groups.putIfAbsent(notificationGroupOf(n.timestamp, now: now), () => []).add(n);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final g in NotificationGroup.values)
                        if (groups[g] != null) ...[
                          WebSectionLabel(switch (g) {
                            NotificationGroup.today => 'Today',
                            NotificationGroup.thisWeek => 'This week',
                            NotificationGroup.earlier => 'Earlier',
                          }),
                          PaperCard(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                for (final n in groups[g]!)
                                  _NotificationRow(
                                    key: ValueKey(n.id),
                                    notification: n,
                                    onDelete: () => _delete(n),
                                  ),
                              ],
                            ),
                          ),
                        ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sender photo or initials when the sender is known; otherwise an icon for
/// the kind of notification (never initials guessed from the title).
class _NotificationAvatar extends StatelessWidget {
  final InAppNotification notification;
  const _NotificationAvatar({required this.notification});

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final name = notification.senderDisplayName?.trim() ?? '';
    final photo = notification.senderPhotoUrl?.trim() ?? '';
    if (name.isNotEmpty || photo.isNotEmpty) {
      return InkAvatar(
        id: notification.senderUid ?? notification.id,
        imageUrl: photo.isEmpty ? null : photo,
        initials: initialsOf(name.isEmpty ? null : name),
        size: 36,
      );
    }
    final icon = switch (notificationKindOf(notification.type)) {
      NotificationKind.invite => LucideIcons.mailOpen,
      NotificationKind.friend => LucideIcons.users,
      NotificationKind.mention => LucideIcons.atSign,
      NotificationKind.access => LucideIcons.keyRound,
      NotificationKind.board => LucideIcons.layoutGrid,
      NotificationKind.other => LucideIcons.bell,
    };
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: ink.accentSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: ink.accentText),
      ),
    );
  }
}

/// One notification: unread dot, avatar, title, details and time, with a
/// remove button. Highlights on hover.
class _NotificationRow extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onDelete;
  const _NotificationRow({super.key, required this.notification, required this.onDelete});

  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final n = widget.notification;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
        decoration: BoxDecoration(
          color: _hover ? ink.field : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 12,
              height: 36,
              child: Center(
                child: n.read
                    ? null
                    : Semantics(
                        label: 'Unread',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: ink.accent, shape: BoxShape.circle),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 6),
            _NotificationAvatar(notification: n),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: n.read ? InkType.body(ink.ink) : InkType.bodyStrong(ink.ink),
                  ),
                  if (n.body != null && n.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(n.body!, style: InkType.caption(ink.inkSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(timeAgo(n.timestamp), style: InkType.caption(ink.inkMuted)),
            ),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.x, size: 16, color: ink.inkMuted),
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
