import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/notification/in_app_notification.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/paper_card.dart';
import '../../../core/web_formatters.dart';
import '../../../domain/models/web_notification_rules.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../../../ui/widgets/web_page_layout.dart';
import '../../navigation/view/web_shell_section.dart';
import '../bloc/web_notifications_cubit.dart';

/// In-app notification feed with browser-persisted read state, category filter
/// chips, and time-grouped paper cards.
class WebNotificationsPage extends StatefulWidget {
  const WebNotificationsPage({super.key});

  @override
  State<WebNotificationsPage> createState() => _WebNotificationsPageState();
}

class _WebNotificationsPageState extends State<WebNotificationsPage> {
  NotificationFilter _filter = NotificationFilter.all;

  WebNotificationsCubit get _cubit => context.read<WebNotificationsCubit>();

  Future<void> _delete(InAppNotification n) async {
    try {
      await _cubit.deleteNotification(n.id);
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _open(InAppNotification n) async {
    try {
      await _cubit.markNotificationRead(n.id);
    } catch (_) {
      // Navigating takes priority over persisting read state.
    }
    if (!mounted) return;
    final nav = WebShellNav.maybeOf(context);
    if (nav == null) return;
    nav.goTo(switch (notificationTargetOf(n.type)) {
      NotificationTarget.invites => WebSection.invites,
      NotificationTarget.friends => WebSection.friends,
      NotificationTarget.workspace => WebSection.workspaces,
      NotificationTarget.profile => WebSection.profile,
      NotificationTarget.boards => WebSection.boards,
    });
  }

  Future<void> _markAllRead(List<InAppNotification> items) async {
    try {
      await _cubit.markAllNotificationsRead(items.map((n) => n.id));
      if (mounted) showWebMessage(context, 'All notifications marked as read.');
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WebNotificationsCubit>().state;
    final items = state.notifications;
    final unread = state.unreadCount;
    final visible = items
        .where((n) => notificationMatchesFilter(n.type, _filter))
        .toList();

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
                title: 'Notifications',
                subtitle:
                    'Accept invites and friend requests on their own pages.',
                trailing: items.isEmpty
                    ? null
                    : TextButton.icon(
                        onPressed: unread == 0
                            ? null
                            : () => _markAllRead(items),
                        icon: Icon(
                          LucideIcons.checkCheck,
                          size: 16,
                          color: unread == 0
                              ? context.ink.inkMuted
                              : context.ink.ink,
                        ),
                        label: Text(
                          unread == 0 ? 'All read' : 'Mark all read',
                          style: InkType.bodyStrong(
                            unread == 0
                                ? context.ink.inkMuted
                                : context.ink.ink,
                          ),
                        ),
                      ),
              ),
              if (items.isNotEmpty) ...[
                _FilterChips(
                  selected: _filter,
                  counts: {
                    for (final filter in NotificationFilter.values)
                      filter: items
                          .where(
                            (n) => notificationMatchesFilter(n.type, filter),
                          )
                          .length,
                  },
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: InkSpacing.s16),
              ],
              if (state.error != null)
                WebErrorBox(message: webErrorText(state.error!))
              else if (state.loading)
                const WebLoading()
              else if (items.isEmpty)
                const WebEmptyHint(
                  icon: LucideIcons.bell,
                  text: "You're all caught up",
                  subtitle:
                      'New activity on your boards and friends shows up '
                      'here.',
                )
              else if (visible.isEmpty)
                const WebEmptyHint(
                  icon: LucideIcons.filterX,
                  text: 'No notifications in this filter.',
                )
              else
                _NotificationGroups(
                  items: visible,
                  onDelete: _delete,
                  onOpen: _open,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final NotificationFilter selected;
  final Map<NotificationFilter, int> counts;
  final ValueChanged<NotificationFilter> onChanged;

  const _FilterChips({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  static const _labels = {
    NotificationFilter.all: 'All',
    NotificationFilter.requests: 'Requests',
    NotificationFilter.boards: 'Boards',
    NotificationFilter.friends: 'Friends',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: InkSpacing.s8,
      runSpacing: InkSpacing.s8,
      children: [
        for (final filter in NotificationFilter.values)
          WebChoiceChip(
            label: '${_labels[filter]} (${counts[filter] ?? 0})',
            selected: selected == filter,
            onSelected: () => onChanged(filter),
          ),
      ],
    );
  }
}

class _NotificationGroups extends StatelessWidget {
  final List<InAppNotification> items;
  final Future<void> Function(InAppNotification n) onDelete;
  final Future<void> Function(InAppNotification n) onOpen;

  const _NotificationGroups({
    required this.items,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final groups = <NotificationGroup, List<InAppNotification>>{};
    for (final n in items) {
      groups
          .putIfAbsent(notificationGroupOf(n.timestamp, now: now), () => [])
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
                padding: const EdgeInsets.only(bottom: InkSpacing.s12),
                child: _NotificationCard(
                  notification: n,
                  onDelete: () => onDelete(n),
                  onOpen: () => onOpen(n),
                ),
              ),
          ],
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final InAppNotification notification;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _NotificationCard({
    required this.notification,
    required this.onDelete,
    required this.onOpen,
  });

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

    return Semantics(
      button: true,
      label: unread ? 'Unread notification: ${n.title}' : n.title,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(InkRadii.card),
          child: PaperCard(
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
                      margin: const EdgeInsets.only(
                        top: 6,
                        right: InkSpacing.s8,
                      ),
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
                                  hasSender && name.isNotEmpty
                                      ? name
                                      : 'InkLink',
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
                              child: Icon(
                                _kindIcon,
                                size: 16,
                                color: kindColor,
                              ),
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
          ),
        ),
      ),
    );
  }
}
