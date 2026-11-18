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
/// mobile), drawn like the phone: one paper card per notification.
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
                title: 'Notifications',
                subtitle:
                    'Accept invites and friend requests on their own pages.',
              ),
              WebStreamList<InAppNotification>(
                stream: _stream,
                compactEmpty: false,
                emptyIcon: LucideIcons.bell,
                emptyText: "You're all caught up",
                emptySubtitle:
                    'New activity on your boards and friends shows up here.',
                builder: (context, items) {
                  final now = DateTime.now();
                  final groups = <NotificationGroup, List<InAppNotification>>{};
                  for (final n in items) {
                    groups
                        .putIfAbsent(
                          notificationGroupOf(n.timestamp, now: now),
                          () => [],
                        )
                        .add(n);
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
                          for (final n in groups[g]!)
                            Padding(
                              key: ValueKey(n.id),
                              padding: const EdgeInsets.only(
                                bottom: InkSpacing.s12,
                              ),
                              child: _NotificationCard(
                                notification: n,
                                onDelete: () => _delete(n),
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

class _NotificationCard extends StatelessWidget {
  final InAppNotification notification;
  final VoidCallback onDelete;

  const _NotificationCard({required this.notification, required this.onDelete});

  IconData get _kindIcon => switch (notificationKindOf(notification.type)) {
    NotificationKind.invite => LucideIcons.mailOpen,
    NotificationKind.friend => LucideIcons.users,
    NotificationKind.mention => LucideIcons.atSign,
    NotificationKind.access => LucideIcons.keyRound,
    NotificationKind.board => LucideIcons.layoutGrid,
    NotificationKind.other => LucideIcons.bell,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final n = notification;
    final unread = !n.read;
    final name = n.senderDisplayName?.trim() ?? '';
    final photo = n.senderPhotoUrl?.trim() ?? '';
    final hasSender = name.isNotEmpty || photo.isNotEmpty;
    final kindColor = unread ? tokens.pending : tokens.accent;

    return PaperCard(
      padding: const EdgeInsets.all(InkSpacing.s16 - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unread)
            Semantics(
              label: 'Unread',
              child: Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6, right: InkSpacing.s8),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            const SizedBox(width: 6 + InkSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hasSender) ...[
                      InkAvatar(
                        imageUrl: photo.isEmpty ? null : photo,
                        initials: initialsOf(name.isEmpty ? null : name),
                        id: n.senderUid ?? n.id,
                        size: 40,
                      ),
                      const SizedBox(width: InkSpacing.s12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasSender && name.isNotEmpty ? name : 'InkLink',
                            style: InkType.bodyStrong(tokens.ink),
                          ),
                          Text(
                            timeAgo(n.timestamp),
                            style: InkType.caption(tokens.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    ExcludeSemantics(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: kindColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_kindIcon, size: 16, color: kindColor),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: tokens.inkMuted,
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s12),
                Text(n.title, style: InkType.bodyStrong(tokens.ink)),
                if (n.body != null && n.body!.isNotEmpty) ...[
                  const SizedBox(height: InkSpacing.s4),
                  Text(
                    n.body!,
                    style: InkType.body(
                      tokens.inkSecondary,
                    ).copyWith(height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
