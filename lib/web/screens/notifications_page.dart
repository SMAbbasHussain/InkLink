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
    final ink = context.ink;
    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s24),
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
          builder: (context, items) => WebReadableWidth(
            child: PaperCard(
              padding: const EdgeInsets.symmetric(vertical: InkSpacing.s8),
              child: Column(
                children: [
                  for (final n in items)
                    ListTile(
                      key: ValueKey(n.id),
                      leading: _NotificationAvatar(notification: n),
                      title: Text(
                        n.title,
                        style: n.read
                            ? InkType.body(ink.ink)
                            : InkType.bodyStrong(ink.ink),
                      ),
                      subtitle: Text(
                        [
                          if (n.body != null && n.body!.isNotEmpty) n.body!,
                          timeAgo(n.timestamp),
                        ].join(' · '),
                        style: InkType.caption(ink.inkMuted),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: ink.inkMuted,
                        ),
                        onPressed: () => _delete(n),
                      ),
                    ),
                ],
              ),
            ),
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
