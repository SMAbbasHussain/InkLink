import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/notification/in_app_notification.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../glass/glass_tokens.dart';
import '../glass/glass_widgets.dart';
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
  late final Stream<List<InAppNotification>> _stream = _repo.watchNotifications();

  /// The existing delete; rows animate out before calling it.
  Future<bool> _delete(InAppNotification n) async {
    try {
      await _repo.deleteNotification(n.id);
      return true;
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
      return false;
    }
  }

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
                title: 'Notifications',
                subtitle: 'Accept invites and friend requests on their own pages.',
              ),
              WebStreamList<InAppNotification>(
                stream: _stream,
                compactEmpty: false,
                emptyIcon: LucideIcons.bell,
                emptyText: "You're all caught up",
                emptySubtitle: 'New activity on your boards and friends shows up here.',
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
                          GlassPanel(
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
          color: const Color(0x268B5CF6),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x408B5CF6)),
        ),
        child: Icon(icon, size: 17, color: Glass.accentText),
      ),
    );
  }
}

/// One notification: glowing unread dot, avatar, title, details and time.
/// The remove button appears on hover or keyboard focus; the row collapses
/// and fades out before the (existing) delete runs, and comes back if the
/// delete fails.
class _NotificationRow extends StatefulWidget {
  final InAppNotification notification;
  final Future<bool> Function() onDelete;
  const _NotificationRow({super.key, required this.notification, required this.onDelete});

  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow> with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _focus = false;
  late final AnimationController _exit =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!Glass.reduceMotion(context)) await _exit.reverse();
    final ok = await widget.onDelete();
    if (!ok && mounted) _exit.value = 1; // Delete failed: show the row again.
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final showRemove = _hover || _focus;
    final curved = CurvedAnimation(parent: _exit, curve: Curves.easeOut);
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedContainer(
            duration: Glass.fast,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
            decoration: BoxDecoration(
              color: _hover
                  ? Glass.bgHover
                  : n.read
                      ? Colors.transparent
                      : const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(Glass.r14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 14,
                  height: 36,
                  child: Center(
                    child: n.read
                        ? null
                        : Semantics(
                            label: 'Unread',
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: Glass.accentGradient,
                                shape: BoxShape.circle,
                                boxShadow: Glass.glow(1.2),
                              ),
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
                        style: n.read ? Glass.body(color: Glass.text) : Glass.strong(),
                      ),
                      if (n.body != null && n.body!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(n.body!, style: Glass.small(color: Glass.textSecondary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(timeAgo(n.timestamp), style: Glass.small()),
                ),
                // Invisible until hover/focus, but always reachable by
                // keyboard and screen readers.
                Focus(
                  onFocusChange: (f) => setState(() => _focus = f),
                  canRequestFocus: false,
                  child: AnimatedOpacity(
                    duration: Glass.fast,
                    opacity: showRemove ? 1 : 0,
                    child: IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.x, size: 16, color: Glass.textSecondary),
                      onPressed: _dismiss,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
