import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/paper_card.dart';
import '../data/web_mappers.dart';

/// Shows a short message at the bottom of the page.
void showWebMessage(BuildContext context, String message, {bool isError = false}) {
  final ink = context.ink;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 420,
        backgroundColor: isError ? ink.danger : ink.ink,
        content: Text(message, style: InkType.body(ink.paper)),
      ),
    );
}

/// Turns any thrown value into a readable message.
String webErrorText(Object error) {
  if (error is String) return error;
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

/// Page title row used at the top of every section.
class WebPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const WebPageHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: InkType.headline(ink.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: InkSpacing.s4),
                  Text(subtitle!, style: InkType.body(ink.inkSecondary)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small section label inside a page.
class WebSectionLabel extends StatelessWidget {
  final String text;
  const WebSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: InkSpacing.s16, bottom: InkSpacing.s8),
        child: Text(text.toUpperCase(), style: InkType.label(context.ink.inkMuted)),
      );
}

/// Builds a live list with loading, error and empty states.
class WebStreamList<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final Widget Function(BuildContext context, List<T> items) builder;
  final IconData emptyIcon;
  final String emptyText;
  final String? emptySubtitle;

  const WebStreamList({
    super.key,
    required this.stream,
    required this.builder,
    required this.emptyIcon,
    required this.emptyText,
    this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return WebErrorBox(message: webErrorText(snapshot.error!));
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(InkSpacing.s32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: InkSpacing.s24),
            child: EmptyState(icon: emptyIcon, text: emptyText, subtitle: emptySubtitle),
          );
        }
        return builder(context, items);
      },
    );
  }
}

class WebErrorBox extends StatelessWidget {
  final String message;
  const WebErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Padding(
      padding: const EdgeInsets.all(InkSpacing.s16),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, color: ink.danger, size: 18),
          const SizedBox(width: InkSpacing.s8),
          Expanded(child: Text(message, style: InkType.body(ink.danger))),
        ],
      ),
    );
  }
}

/// One board in a grid: title, tags, members and visibility.
class WebBoardTile extends StatelessWidget {
  final Board board;
  final bool isOwner;
  final VoidCallback onTap;

  const WebBoardTile({
    super.key,
    required this.board,
    required this.isOwner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: PaperCard(
          tiltId: board.id,
          padding: const EdgeInsets.all(InkSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    board.visibility == 'public' ? LucideIcons.globe : LucideIcons.lock,
                    size: 16,
                    color: ink.inkMuted,
                  ),
                  const SizedBox(width: InkSpacing.s8),
                  Expanded(
                    child: Text(
                      board.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: InkType.cardTitle(ink.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: InkSpacing.s8),
              Text(
                '${isOwner ? 'Owner' : 'Member'} · ${board.membersCount} '
                '${board.membersCount == 1 ? 'member' : 'members'} · '
                'updated ${timeAgo(board.updatedAt)}',
                style: InkType.caption(ink.inkSecondary),
              ),
              if (board.tags.isNotEmpty) ...[
                const SizedBox(height: InkSpacing.s8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in board.tags.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ink.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('#$tag', style: InkType.caption(ink.accentText)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive grid for board tiles.
class WebBoardGrid extends StatelessWidget {
  final List<Board> boards;
  final String? currentUid;
  final ValueChanged<Board> onOpen;

  const WebBoardGrid({
    super.key,
    required this.boards,
    required this.currentUid,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 300).floor().clamp(1, 4);
        const gap = InkSpacing.s16;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final board in boards)
              SizedBox(
                width: width,
                child: WebBoardTile(
                  board: board,
                  isOwner: board.ownerId == currentUid,
                  onTap: () => onOpen(board),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Details for a board, with links that open it in the phone app.
Future<void> showOpenInAppDialog(BuildContext context, Board board) {
  final ink = context.ink;
  final link = boardAppLink(board.id);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: ink.paper,
      title: Text(board.title, style: InkType.title(ink.ink)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drawing and editing happen in the InkLink mobile app. '
              'Open this link on your phone to jump straight into the board.',
              style: InkType.body(ink.inkSecondary),
            ),
            const SizedBox(height: InkSpacing.s16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ink.field,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ink.glassStroke),
              ),
              child: Row(
                children: [
                  Expanded(child: SelectableText(link, style: InkType.body(ink.ink))),
                  IconButton(
                    tooltip: 'Copy link',
                    icon: Icon(LucideIcons.copy, size: 18, color: ink.inkSecondary),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (dialogContext.mounted) {
                        showWebMessage(dialogContext, 'Link copied');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: InkSpacing.s12),
            Text(
              '${board.membersCount} ${board.membersCount == 1 ? 'member' : 'members'}'
              ' · ${board.visibility == 'public' ? 'Public' : 'Private'}'
              '${board.isArchived ? ' · Archived' : ''}',
              style: InkType.caption(ink.inkMuted),
            ),
          ],
        ),
      ),
      actions: [
        InkButton(
          label: 'Close',
          expand: false,
          compact: true,
          variant: InkButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

/// Accept / Decline pair used by invites and friend requests.
class WebAcceptDecline extends StatefulWidget {
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final String acceptedMessage;
  final String declinedMessage;

  const WebAcceptDecline({
    super.key,
    required this.onAccept,
    required this.onDecline,
    required this.acceptedMessage,
    required this.declinedMessage,
  });

  @override
  State<WebAcceptDecline> createState() => _WebAcceptDeclineState();
}

class _WebAcceptDeclineState extends State<WebAcceptDecline> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showWebMessage(context, doneMessage);
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkButton(
          label: 'Decline',
          expand: false,
          compact: true,
          variant: InkButtonVariant.secondary,
          onPressed: _busy ? null : () => _run(widget.onDecline, widget.declinedMessage),
        ),
        const SizedBox(width: InkSpacing.s8),
        InkButton(
          label: 'Accept',
          expand: false,
          compact: true,
          isLoading: _busy,
          onPressed: _busy ? null : () => _run(widget.onAccept, widget.acceptedMessage),
        ),
      ],
    );
  }
}
